#!/usr/bin/env python3
"""Concatenate TSV files that share a header (union of columns)."""
import argparse
import csv
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", nargs="+", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    rows = []
    fields = []
    for path in args.inputs:
        with open(path, newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            if reader.fieldnames is None:
                continue
            for f in reader.fieldnames:
                if f is not None and f not in fields:
                    fields.append(f)
            rows.extend(list(reader))

    if not fields:
        sys.exit("No parsable tables in: %s" % ", ".join(args.inputs))

    with open(args.out, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, delimiter="\t",
                                extrasaction="ignore", restval="NA")
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
