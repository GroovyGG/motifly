#!/usr/bin/env python3
"""Add `thematic` column to french_5000.csv using Routledge PDF thematic vocabulary lists."""
import csv
import re
import sys
from pathlib import Path

try:
    import pdfplumber
except ImportError:
    sys.exit("pip install pdfplumber")

THEMATIC_ENTRY_MF = re.compile(
    r"^([a-zàâäéèêëïîôùûçœæ][a-zàâäéèêëïîôùûçœæA-Za-z\-']*)\s+(\d{1,5})\s+([MF])\s+(.+)$"
)
THEMATIC_ENTRY_PLAIN = re.compile(
    r"^([a-zàâäéèêëïîôùûçœæ][a-zàâäéèêëïîôùûçœæA-Za-z\-']*)\s+(\d{1,5})\s+(.+)$"
)
MAIN_ENTRY_START = re.compile(
    r"^(\d{1,4})\s+([a-zàâäéèêëïîôùûçœæ][a-zàâäéèêëïîôùûçœæA-Za-z\-']*)\s+"
)
THEME_FIRST_WORD = {
    "Animals", "Body", "Food", "Clothing", "Transportation", "Family", "Materials", "Time",
    "Sports", "Natural", "Weather", "Professions", "Creating", "Relationships", "Nouns",
    "Colors", "Opposites", "Nationalities", "Emotions", "Adjectives", "Verbs", "Adverbs",
    "Word", "Use",
}


def is_theme_header_line(line: str) -> bool:
    m = re.match(r"^(?:[1-9]|1\d|2[0-7])\s+(\S+)", line.strip())
    return bool(m and m.group(1) in THEME_FIRST_WORD)


def normalize_theme_title(line: str) -> str:
    m = re.match(r"^(?:[1-9]|1\d|2[0-7])\s+(.+)$", line.strip())
    if not m:
        t = line.strip()
    else:
        t = m.group(1).strip().replace("--", "–")
    t = re.sub(r"(?<![–\-])\s+\d{1,3}\s*$", "", t)
    return t.strip()


def is_plausible_thematic_plain(lemma: str, rank: int, gloss: str) -> bool:
    if not (1 <= rank <= 5000):
        return False
    g = gloss.strip()
    if len(g) < 2:
        return False
    if re.match(r"^(nm|nf|nv|v|adv|prep|conj|det|pro|nadj|nmi)\b", g):
        return False
    return True


def build_rank_to_theme(pdf_path: Path) -> dict[int, str]:
    rank_theme: dict[int, str] = {}
    current: str | None = None
    with pdfplumber.open(pdf_path) as pdf:
        lines = []
        for page in pdf.pages:
            lines.extend((page.extract_text() or "").splitlines())
    for raw in lines:
        line = raw.strip()
        if not line or re.match(r"^Page\s+\d+", line, re.I):
            continue
        if is_theme_header_line(line):
            current = normalize_theme_title(line)
            continue
        if MAIN_ENTRY_START.match(line):
            current = None
            continue
        if not current:
            continue
        m = THEMATIC_ENTRY_MF.match(line)
        if m:
            rank = int(m.group(2))
            if 1 <= rank <= 5000:
                rank_theme[rank] = current
            continue
        m = THEMATIC_ENTRY_PLAIN.match(line)
        if m:
            lemma, rank_s, gloss = m.group(1), int(m.group(2)), m.group(3)
            if is_plausible_thematic_plain(lemma, rank_s, gloss):
                rank_theme[rank_s] = current
    return rank_theme


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf", type=Path, nargs="?", default=Path("data_seed/frequency-dict-french.pdf"))
    ap.add_argument("-c", "--csv", type=Path, default=Path("data_seed/french_5000.csv"))
    args = ap.parse_args()
    m = build_rank_to_theme(args.pdf)
    with args.csv.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    fieldnames = list(rows[0].keys())
    if "thematic" not in fieldnames:
        if "french_lemma" in fieldnames:
            i = fieldnames.index("french_lemma") + 1
            fieldnames = fieldnames[:i] + ["thematic"] + fieldnames[i:]
        else:
            fieldnames.append("thematic")
    for row in rows:
        row["thematic"] = m.get(int(row["number"]), "none")
    with args.csv.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"thematic: {sum(1 for r in rows if r['thematic'] != 'none')} / {len(rows)} rows; themes: {len(set(m.values()))}")


if __name__ == "__main__":
    main()
