#!/usr/bin/env python3
"""
Split french_5000.csv into noun / adjective / verb seed CSVs by POS tagging rules.

Rule order (per row, after splitting `pos` on commas):
1. If `v` present -> verb
2. Else if any adj-like AND any of nm, nf, nm(pl), nf(pl) -> adjective
3. Else if any adj-like -> adjective
4. Else if any noun token (nm, nf, nmi, nm(pl), nf(pl)) -> noun
5. Else -> unclassified (written with pos_tokens + reason columns)
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

VERB = frozenset({"v"})

NOUN = frozenset({"nm", "nf", "nmi", "nm(pl)", "nf(pl)"})

# Subset used only for the "adj + nm/nf" combo rule (plan step 2)
NOUN_FOR_ADJ_COMBO = frozenset({"nm", "nf", "nm(pl)", "nf(pl)"})

ADJ_LIKE = frozenset(
    {
        "adj",
        "adj(f)",
        "adj(pl)",
        "adji",
        "adji(pl)",
        "nadj",
        "nadj(f)",
        "nadj(pl)",
    }
)


def parse_pos_tokens(pos: str) -> list[str]:
    return [t.strip() for t in (pos or "").split(",") if t.strip()]


def classify(tokens: list[str]) -> tuple[str, str]:
    """Return (bucket, reason). bucket in verb|adjective|noun|unclassified."""
    tset = set(tokens)
    if tset & VERB:
        return "verb", "has_v"
    if tset & ADJ_LIKE and tset & NOUN_FOR_ADJ_COMBO:
        return "adjective", "adj_like_with_nm_or_nf"
    if tset & ADJ_LIKE:
        return "adjective", "adj_like_only_or_without_nm_nf_combo"
    if tset & NOUN:
        return "noun", "noun_token_only"
    return "unclassified", "no_noun_verb_adj_bucket"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--input",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "data_seed" / "french_5000.csv",
        help="Source CSV (default: ../../data_seed/french_5000.csv)",
    )
    ap.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "data_seed",
        help="Output directory (default: ../../data_seed)",
    )
    ap.add_argument(
        "--prefix",
        type=str,
        default="seed_",
        help="Prefix for output filenames (default: seed_)",
    )
    args = ap.parse_args()

    in_path: Path = args.input
    if not in_path.is_file():
        print(f"Not found: {in_path}", file=sys.stderr)
        return 1

    out_dir: Path = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    pfx = args.prefix

    with in_path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        if not fieldnames:
            print("Empty CSV header", file=sys.stderr)
            return 1
        rows = list(reader)

    buckets: dict[str, list[dict]] = {
        "noun": [],
        "adjective": [],
        "verb": [],
        "unclassified": [],
    }

    unclassified_extra = ("pos_tokens", "reason")
    unclassified_fields = fieldnames + list(unclassified_extra)

    for row in rows:
        tokens = parse_pos_tokens(row.get("pos", ""))
        bucket, reason = classify(tokens)
        if bucket == "unclassified":
            out = dict(row)
            out["pos_tokens"] = "|".join(tokens)
            out["reason"] = reason
            buckets["unclassified"].append(out)
        else:
            buckets[bucket].append(row)

    paths = {
        "noun": out_dir / f"{pfx}nouns.csv",
        "adjective": out_dir / f"{pfx}adjectives.csv",
        "verb": out_dir / f"{pfx}verbs.csv",
        "unclassified": out_dir / f"{pfx}pos_unclassified.csv",
    }

    for key in ("noun", "adjective", "verb"):
        path = paths[key]
        with path.open("w", encoding="utf-8-sig", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
            w.writeheader()
            w.writerows(buckets[key])

    with paths["unclassified"].open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=unclassified_fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(buckets["unclassified"])

    total = len(rows)
    n_n = len(buckets["noun"])
    n_a = len(buckets["adjective"])
    n_v = len(buckets["verb"])
    n_u = len(buckets["unclassified"])
    print(f"Read {total} rows from {in_path}")
    print(f"  noun: {n_n} -> {paths['noun']}")
    print(f"  adjective: {n_a} -> {paths['adjective']}")
    print(f"  verb: {n_v} -> {paths['verb']}")
    print(f"  unclassified: {n_u} -> {paths['unclassified']}")
    print(f"  sum check: {n_n + n_a + n_v + n_u} (expected {total})")
    if n_n + n_a + n_v + n_u != total:
        print("ERROR: bucket counts do not sum to input rows", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
