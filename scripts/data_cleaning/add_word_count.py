#!/usr/bin/env python3
"""
Add a `word count` column to french_5000.csv: number of whitespace-separated
tokens in `example_french` (the French example sentence used for dictation).

Usage:
  python scripts/data_cleaning/add_word_count.py [path/to/french_5000.csv]

Default path: data_seed/french_5000.csv when run from project root.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


def french_example_word_count(example_french: str) -> int:
    """Count words as runs separated by any whitespace (empty -> 0)."""
    s = (example_french or "").strip()
    if not s:
        return 0
    return len(s.split())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "csv_path",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "data_seed" / "french_5000.csv",
        help="CSV file to read/update (default: ../../data_seed/french_5000.csv)",
    )
    args = parser.parse_args()
    path: Path = args.csv_path
    if not path.is_file():
        print(f"Not found: {path}", file=sys.stderr)
        return 1

    with path.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
        fieldnames_in = list(rows[0].keys()) if rows else []

    if "example_french" not in fieldnames_in:
        print("CSV must contain column `example_french`.", file=sys.stderr)
        return 1

    col = "word count"
    # Migrate legacy header `word_count` → `word count`
    if "word_count" in fieldnames_in and col not in fieldnames_in:
        for row in rows:
            row[col] = row.pop("word_count", "")
        fieldnames_in = [col if c == "word_count" else c for c in fieldnames_in]

    if col in fieldnames_in:
        out_fields = fieldnames_in
    else:
        i = fieldnames_in.index("example_french") + 1
        out_fields = fieldnames_in[:i] + [col] + fieldnames_in[i:]

    for row in rows:
        row[col] = str(french_example_word_count(row.get("example_french", "")))

    with path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=out_fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

    print(f"Updated {len(rows)} rows: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
