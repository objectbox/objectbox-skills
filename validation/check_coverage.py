#!/usr/bin/env python3
"""Fails when the "Quick reference" table of a skill file and the binding's
COVERAGE.md disagree on their first column (verbatim).

  check_coverage.py <skill file> <COVERAGE.md>
"""
import sys, pathlib


def first_cells(text, header):
    out, in_table = set(), False
    for line in text.split("\n"):
        if line.startswith(header):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|"):
            break
        if line.startswith("|---"):
            continue
        out.add(line.split("|")[1].strip())
    return out


def main():
    skill, coverage = (pathlib.Path(p).read_text() for p in sys.argv[1:3])
    rows = first_cells(skill, "| Mistake | Why")
    cov = first_cells(coverage, "| Mistake | Type")
    for m in sorted(rows - cov):
        print(f"no coverage row for: {m}", file=sys.stderr)
    for s in sorted(cov - rows):
        print(f"coverage row without a skill row: {s}", file=sys.stderr)
    if rows != cov:
        sys.exit(1)
    print(f"coverage check passed ({len(rows)} rows)")


if __name__ == "__main__":
    main()
