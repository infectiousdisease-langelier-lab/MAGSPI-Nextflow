#!/usr/bin/env python3
"""Prefix every contig header with its MAG ID (MAGSPI script 24).

Unlike the original, `.fasta` and `.fna` inputs are accepted (dRep emits the
extension of its input genomes) and output filenames are normalised to `.fa`.
"""
import argparse
import os
import sys

FASTA_EXT = (".fa", ".fasta", ".fna")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--indir", required=True)
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    names = sorted(f for f in os.listdir(args.indir) if f.endswith(FASTA_EXT))
    if not names:
        sys.exit("No FASTA files (%s) in %s" % ("/".join(FASTA_EXT), args.indir))

    for name in names:
        mag = name
        for ext in FASTA_EXT:
            if mag.endswith(ext):
                mag = mag[: -len(ext)]
                break
        src = os.path.join(args.indir, name)
        dst = os.path.join(args.outdir, mag + ".fa")
        with open(src) as fin, open(dst, "w") as fout:
            for line in fin:
                if line.startswith(">"):
                    contig = line[1:].strip()
                    fout.write(">%s_%s\n" % (mag, contig))
                else:
                    fout.write(line)
        sys.stderr.write("renamed %s -> %s\n" % (name, os.path.basename(dst)))


if __name__ == "__main__":
    main()
