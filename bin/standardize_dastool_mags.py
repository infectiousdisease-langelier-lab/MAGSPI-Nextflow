#!/usr/bin/env python3
"""Standardise DAS Tool bins into MAG files (MAGSPI scripts 20 and 21).

Bin-ID grammar, unchanged from the original scripts:
    bin.<N>            -> metabat2
    maxbin2_bins.<N>   -> maxbin2
    <integer>          -> concoct
A trailing `_sub` (DAS Tool's re-partitioned bins) is stripped before parsing
but retained in the `raw_bin` column.

Output MAG name: <sample>_<tool>_<bin_number>.fa
"""
import argparse
import csv
import os
import re
import shutil
import sys

SUB_RE = re.compile(r"_sub$")
INT_RE = re.compile(r"^\d+$")
FASTA_EXT = (".fa", ".fasta", ".fna", ".contigs.fa")


def parse_bin(raw_bin):
    rb = SUB_RE.sub("", str(raw_bin).strip())
    if rb.startswith("bin."):
        return "metabat2", rb[len("bin."):]
    if rb.startswith("maxbin2_bins."):
        return "maxbin2", rb[len("maxbin2_bins."):]
    if INT_RE.match(rb):
        return "concoct", rb
    return None, None


def find_bin_file(bins_dir, raw_bin):
    """DAS Tool writes <bin id>.fa; tolerate the _sub variant and other suffixes."""
    candidates = [raw_bin, SUB_RE.sub("", raw_bin)]
    for base in candidates:
        for ext in FASTA_EXT:
            path = os.path.join(bins_dir, base + ext)
            if os.path.exists(path):
                return path
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", required=True)
    ap.add_argument("--bins-dir", required=True)
    ap.add_argument("--summary", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--out-summary", required=True)
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    with open(args.summary, newline="") as fh:
        lines = [l for l in fh if not l.startswith("#")]
    reader = csv.DictReader(lines, delimiter="\t")
    if reader.fieldnames is None:
        sys.exit("Empty DAS Tool summary: %s" % args.summary)
    bin_col = reader.fieldnames[0]

    out_rows = []
    warnings = []
    for row in reader:
        raw = str(row[bin_col]).strip()
        if not raw:
            continue
        tool, bin_number = parse_bin(raw)
        if tool is None:
            warnings.append("could not parse bin ID %r" % raw)
            continue

        mag_id = "%s_%s_%s" % (args.sample, tool, bin_number)
        src = find_bin_file(args.bins_dir, raw)
        if src is None:
            warnings.append("no FASTA found for bin %r (expected %s/%s.fa)" % (raw, args.bins_dir, raw))
        else:
            shutil.copy(src, os.path.join(args.outdir, mag_id + ".fa"))

        out = dict(row)
        out[bin_col] = mag_id
        out["MAG_ID"] = mag_id
        out["sample"] = args.sample
        out["tool"] = tool
        out["bin_number"] = str(bin_number)
        out["raw_bin"] = raw
        out["mag_fasta"] = (mag_id + ".fa") if src else "NA"
        out_rows.append(out)

    if not out_rows:
        sys.exit("No usable bins in %s" % args.summary)

    first = ["MAG_ID", "sample", "tool", "bin_number", "raw_bin", "mag_fasta"]
    rest = [c for c in out_rows[0] if c not in first]
    with open(args.out_summary, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=first + rest, delimiter="\t",
                                extrasaction="ignore", restval="NA")
        writer.writeheader()
        writer.writerows(out_rows)

    for w in warnings:
        sys.stderr.write("WARNING: %s\n" % w)


if __name__ == "__main__":
    main()
