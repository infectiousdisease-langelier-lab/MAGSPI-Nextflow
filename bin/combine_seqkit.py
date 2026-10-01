#!/usr/bin/env python3
"""Combine per-sample `seqkit stats -T` tables (MAGSPI script 09).

Replaces the bash/awk version, which read column 4 of the *human-formatted*
seqkit output (values carrying thousands separators) and whose sample-name
regex left the `_non_host` suffix attached.
"""
import argparse
import csv
import os
import re
import sys

R1_RE = re.compile(r"_R1(_|\.)")
R2_RE = re.compile(r"_R2(_|\.)")
UP_RE = re.compile(r"unpaired", re.IGNORECASE)


def read_table(path):
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", nargs="+", required=True)
    ap.add_argument("--out-all", required=True)
    ap.add_argument("--out-summary", required=True)
    args = ap.parse_args()

    rows = []
    for path in args.inputs:
        for row in read_table(path):
            rows.append(row)

    if not rows:
        sys.exit("No seqkit rows found in: %s" % ", ".join(args.inputs))

    fields = list(rows[0].keys())
    with open(args.out_all, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    totals = {}
    for row in rows:
        sample = row.get("sample") or "unknown"
        fname = os.path.basename(row.get("file", ""))
        try:
            n = int(float(row.get("num_seqs", 0) or 0))
        except ValueError:
            n = 0
        rec = totals.setdefault(sample, {"total": 0, "r1_up": 0, "r1": 0})
        rec["total"] += n
        is_unpaired = bool(UP_RE.search(fname))
        is_r1 = bool(R1_RE.search(fname)) and not is_unpaired
        if is_r1:
            rec["r1"] += n
            rec["r1_up"] += n
        elif is_unpaired:
            rec["r1_up"] += n

    with open(args.out_summary, "w", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t", lineterminator="\n")
        writer.writerow(["sample", "total_reads", "r1_plus_unpaired_reads", "r1_only_reads"])
        for sample in sorted(totals):
            rec = totals[sample]
            writer.writerow([sample, rec["total"], rec["r1_up"], rec["r1"]])


if __name__ == "__main__":
    main()
