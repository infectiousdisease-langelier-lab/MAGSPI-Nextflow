#!/usr/bin/env python3
"""Combine and filter CheckM `qa -o 2 --tab_table` output (MAGSPI script 19).

The bash version selected columns by position (`$7`, `$8`) from CheckM's
human-formatted table and kept only bins whose name matched `bin.`, which
silently dropped every MaxBin2 and CONCOCT bin.
"""
import argparse
import csv
import sys


def pick(fieldnames, candidates):
    lower = {f.strip().lower(): f for f in fieldnames}
    for cand in candidates:
        if cand in lower:
            return lower[cand]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", nargs="+", required=True)
    ap.add_argument("--min-completeness", type=float, default=50.0)
    ap.add_argument("--max-contamination", type=float, default=10.0)
    ap.add_argument("--out-all", required=True)
    ap.add_argument("--out-filtered", required=True)
    args = ap.parse_args()

    rows = []
    fields = None
    for path in args.inputs:
        with open(path, newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            if reader.fieldnames is None:
                continue
            if fields is None:
                fields = [f for f in reader.fieldnames if f is not None]
            for row in reader:
                rows.append(row)

    if not rows or fields is None:
        sys.exit("No CheckM rows parsed from: %s" % ", ".join(args.inputs))

    comp_col = pick(fields, ["completeness"])
    cont_col = pick(fields, ["contamination"])
    if comp_col is None or cont_col is None:
        sys.exit("CheckM table is missing Completeness/Contamination columns; found: %s" % fields)

    def write(path, selected):
        with open(path, "w", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=fields, delimiter="\t", extrasaction="ignore")
            writer.writeheader()
            writer.writerows(selected)

    kept = []
    for row in rows:
        try:
            comp = float(row[comp_col])
            cont = float(row[cont_col])
        except (TypeError, ValueError):
            continue
        if comp >= args.min_completeness and cont <= args.max_contamination:
            kept.append(row)

    write(args.out_all, rows)
    write(args.out_filtered, kept)
    sys.stderr.write("CheckM bins: %d total, %d passing completeness>=%s contamination<=%s\n"
                     % (len(rows), len(kept), args.min_completeness, args.max_contamination))


if __name__ == "__main__":
    main()
