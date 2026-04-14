#!/usr/bin/env python3
"""
Extract the 5000-word frequency list from Routledge "A Frequency Dictionary of French" PDF
into a CSV. Cleans OCR noise, skips thematic insert blocks, merges cross-page entries.

Usage:
  pip install pdfplumber
  python scripts/data_cleaning/extract_frequency_dictionary.py /path/to/book.pdf -o data_seed/french_5000.csv
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

try:
    import pdfplumber
except ImportError:
    print("Please: pip install pdfplumber", file=sys.stderr)
    raise

# POS: comma-separated gram codes; allow spaces after commas (e.g. "det, pro")
POS_ENG_RE = re.compile(
    r"^((?:[a-z]+(?:\([a-z]+\))?(?:\s+[a-z])?)(?:,\s*(?:[a-z]+(?:\([a-z]+\))?(?:\s+[a-z])?))*)\s+(.+)$",
    re.I | re.DOTALL,
)
ENTRY_HEADER_RE = re.compile(r"^(\d{1,4})\s+(\S+)\s+(.+)$")
STATS_RE = re.compile(r"^(\d+)\s*\|\s*(.+)$")
JUNK_LINE_RE = re.compile(r"^[0-9]{6,}[0-9b]*$", re.I)
PAGE_LINE_RE = re.compile(r"^Page\s+\d+\s*$", re.I)
SECTION_TITLE_RE = re.compile(
    r"^\d+\s+(Animals|Body|Food|Clothing|Transportation|Family|Materials|Time|Sports|"
    r"Natural features and plants|Weather|Professions|Creating nouns|Relationships|Nouns|Colors|"
    r"Opposites|Nationalities|Emotions|Adjectives|Verbs|Adverbs|Word length)[^\n]*$",
    re.I,
)

STAT_SUFFIX_RE = re.compile(
    r"(\s)(\d{1,3})\s*\|\s*([\d\-+ns]+(?:\s*\+\s*s)?)\s*$"
)


def extract_stats_from_example_tail(entry: dict) -> None:
    """When stats ended up on the * line (PDF line wrap), split range | frequency off the end."""
    if entry.get("stats"):
        return
    j = " ".join(entry.get("example_lines") or [])
    m = STAT_SUFFIX_RE.search(j)
    if not m:
        return
    body = j[: m.start(1)].strip()
    rng, fr = m.group(2), m.group(3)
    entry["example_lines"] = [body] if body else []
    entry["range_count"] = rng
    entry["frequency_raw"] = fr
    entry["stats"] = f"{rng} | {fr}"
    entry["in_example"] = False



THEMATIC_LINE_RE = re.compile(
    r"^[a-zàâäéèêëïîôùûçœæA-Z][a-zàâäéèêëïîôùûçœæA-Z\-']*\s+\d+\s+[MF]\s+",
)


def strip_html(s: str) -> str:
    return re.sub(r"</?B>", "", s, flags=re.I)


def split_pos_english(rest: str) -> tuple[str, str]:
    rest = rest.strip()
    m = POS_ENG_RE.match(rest)
    if m:
        return strip_html(m.group(1).strip()), strip_html(m.group(2).strip())
    return "", strip_html(rest)


def extract_full_text(pdf_path: Path) -> str:
    parts: list[str] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            t = page.extract_text()
            if t:
                parts.append(t)
    return "\n".join(parts)


def preprocess_raw_text(text: str) -> str:
    """Join split 'range |\\nfrequency' lines common in PDF extraction."""
    text = re.sub(r"(\d+)\s*\|\s*\n\s*(\d[\d\-+ns]*)", r"\1 | \2", text)
    return text


def normalize_line(line: str) -> str:
    line = line.replace("\u00ad", "")
    line = re.sub(r"\(cid:\d+\)", "", line)
    return line.strip()


def should_skip_standalone_line(line: str) -> bool:
    if not line:
        return True
    if JUNK_LINE_RE.match(line):
        return True
    if PAGE_LINE_RE.match(line):
        return True
    if line.startswith("Frequency index") or line.startswith("rank frequency"):
        return True
    if SECTION_TITLE_RE.match(line):
        return True
    if THEMATIC_LINE_RE.match(line) and line and not line[0].isdigit():
        return True
    return False



# Routledge sample sentences: French gloss, then "--" or spaced "-", then English.
# Order matters: prefer full " -- " before tight "--" or single " - ".
_EXAMPLE_FR_EN_PATTERNS = (
    r"\s+--\s+",  # standard
    r"\s+--(?=\S)",  # e.g. choisie --it's
    r"(?<=\S)--\s+",  # e.g. blocage -- as a result
    r"(?<=\S)--(?=\S)",  # e.g. scandaleux--the
    r"\s+-\s+",  # single hyphen (less common in book)
)


def split_example_french_english(example: str) -> tuple[str, str]:
    """Split French vs English; strip optional leading `*` from the French side."""
    s = example.strip()
    if not s:
        return "", ""
    for pat in _EXAMPLE_FR_EN_PATTERNS:
        m = re.search(pat, s)
        if not m:
            continue
        left, right = s[: m.start()].strip(), s[m.end() :].strip()
        fr = re.sub(r"^\*\s*", "", left).strip()
        return fr, right.strip()
    fr = re.sub(r"^\*\s*", "", s).strip()
    return fr, ""

def clean_example_text(s: str) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"\s+\d{6,}[0-9b]*\s*$", "", s)
    return s.strip()


def parse_entries(text: str) -> list[dict]:
    text = preprocess_raw_text(text)
    lines = [normalize_line(l) for l in text.splitlines()]
    entries: list[dict] = []
    current: dict | None = None

    def flush():
        nonlocal current
        if current:
            extract_stats_from_example_tail(current)
            if current.get("stats"):
                entries.append(current)
        current = None

    i = 0
    while i < len(lines):
        line = lines[i]
        in_ex = bool(current and current.get("in_example"))

        if should_skip_standalone_line(line) and not in_ex:
            i += 1
            continue

        sm = STATS_RE.match(line)
        if sm:
            if current:
                current["range_count"] = sm.group(1).strip()
                current["frequency_raw"] = sm.group(2).strip()
                current["stats"] = f"{current['range_count']} | {current['frequency_raw']}"
                current["in_example"] = False
                flush()
            i += 1
            continue

        hm = ENTRY_HEADER_RE.match(line)
        if hm:
            num_s, lemma, rest = hm.groups()
            num = int(num_s)
            if 1 <= num <= 5000 and lemma and not lemma[0].isupper():
                flush()
                pos, english = split_pos_english(rest)
                current = {
                    "number": num,
                    "lemma": lemma,
                    "pos": pos,
                    "english": english,
                    "example_lines": [],
                    "stats": "",
                    "range_count": "",
                    "frequency_raw": "",
                    "in_example": False,
                }
                i += 1
                continue

        if current:
            if line.startswith("*"):
                current["in_example"] = True
                current["example_lines"].append(line)
                i += 1
                continue
            if current.get("in_example") and line and not ENTRY_HEADER_RE.match(line):
                if JUNK_LINE_RE.match(line):
                    i += 1
                    continue
                current["example_lines"].append(line)
                i += 1
                continue

        i += 1

    if current:
        extract_stats_from_example_tail(current)
        if current.get("stats"):
            entries.append(current)

    return entries


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf", nargs="?", type=Path, default=Path("data_seed/frequency-dict-french.pdf"))
    ap.add_argument("-o", "--output", type=Path, default=Path("data_seed/french_5000.csv"))
    ap.add_argument("--zh-headers", action="store_true", help="Use Chinese CSV header row")
    args = ap.parse_args()

    if not args.pdf.is_file():
        print(f"PDF not found: {args.pdf}", file=sys.stderr)
        sys.exit(1)

    rows = parse_entries(extract_full_text(args.pdf))
    by_num: dict[int, dict] = {}
    for r in rows:
        n = r["number"]
        if n not in by_num or (r.get("stats") and not by_num[n].get("stats")):
            by_num[n] = r

    ordered = [by_num[k] for k in sorted(by_num.keys())]
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.output.open("w", newline="", encoding="utf-8-sig") as f:
        if args.zh_headers:
            headers = [
                "编号",
                "法语词条",
                "词性",
                "英文翻译",
                "例句",
                "例句法语",
                "例句英语",
                "range_count",
                "raw_frequency_total",
                "range_pipe_frequency",
            ]
        else:
            headers = [
                "number",
                "french_lemma",
                "pos",
                "english",
                "example",
                "example_french",
                "example_english",
                "range_count",
                "frequency_raw",
                "range_pipe_frequency",
            ]
        w = csv.writer(f)
        w.writerow(headers)
        for r in ordered:
            ex = clean_example_text(" ".join(r.get("example_lines") or []))
            ex_fr, ex_en = split_example_french_english(ex)
            w.writerow(
                [
                    r["number"],
                    r.get("lemma", ""),
                    r.get("pos", ""),
                    r.get("english", ""),
                    ex,
                    ex_fr,
                    ex_en,
                    r.get("range_count", ""),
                    r.get("frequency_raw", ""),
                    r.get("stats", ""),
                ]
            )

    print(f"Wrote {len(ordered)} rows to {args.output.resolve()}")
    missing = [n for n in range(1, 5001) if n not in by_num]
    if missing:
        print(f"Warning: missing {len(missing)} numbers, first 40: {missing[:40]}", file=sys.stderr)


if __name__ == "__main__":
    main()
