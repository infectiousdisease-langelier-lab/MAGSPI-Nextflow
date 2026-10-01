#!/usr/bin/env python3
"""Combine QUAST `report.tsv` files into one assembly x metric table.

MAGSPI script 12 was a byte-for-byte copy of the seqkit combiner and never
touched QUAST output; this implements the documented behaviour.
"""
import argparse
import csv
import sys


def parse_report(path):
    """QUAST report.tsv is metric-per-row: first row is `Assembly <name>`."""
    with open(path, newline="") as fh:
        rows = [line.rstrip("\n").split("\t") for line in fh if line.strip()]
    if not rows:
        return None, {}
    name = rows[0][1] if len(rows[0]) > 1 else path
    metrics = {}
    order = []
    for row in rows[1:]:
        if len(row) < 2:
            continue
        metrics[row[0]] = row[1]
        order.append(row[0])
    return name, (metrics, order)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", nargs="+", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    assemblies = []
    metric_order = []
    for path in args.inputs:
        name, parsed = parse_report(path)
        if name is None:
            continue
        metrics, order = parsed
        assemblies.append((name, metrics))
        for m in order:
            if m not in metric_order:
                metric_order.append(m)

    if not assemblies:
        sys.exit("No QUAST reports parsed from: %s" % ", ".join(args.inputs))

    with open(args.out, "w", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t", lineterminator="\n")
        writer.writerow(["assembly"] + metric_order)
        for name, metrics in sorted(assemblies):
            writer.writerow([name] + [metrics.get(m, "NA") for m in metric_order])


if __name__ == "__main__":
    main()
