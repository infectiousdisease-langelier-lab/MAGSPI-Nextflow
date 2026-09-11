#!/usr/bin/env python3
"""Create contig-to-bin TSVs for MetaBAT2, MaxBin2 and CONCOCT."""
from __future__ import annotations
import argparse
from pathlib import Path
import csv
import re


def fasta_ids(path: Path):
    with path.open() as handle:
        for line in handle:
            if line.startswith('>'):
                yield line[1:].strip().split()[0]


def metabat_map(bin_dir: Path):
    rows = []
    for fp in sorted(bin_dir.glob('bin.*.fa')):
        bin_id = fp.stem
        rows.extend((c, bin_id) for c in fasta_ids(fp))
    return rows


def maxbin_map(bin_dir: Path):
    rows = []
    for fp in sorted(bin_dir.glob('*.fasta')):
        if fp.name.endswith('.toBin.fasta'):
            continue
        bin_id = f'maxbin2_{fp.stem}'
        rows.extend((c, bin_id) for c in fasta_ids(fp))
    return rows


def concoct_map(bin_dir: Path):
    merged = bin_dir / 'merged_clustering.csv'
    if not merged.exists():
        candidates = list(bin_dir.rglob('merged_clustering.csv'))
        if candidates:
            merged = candidates[0]
    if not merged.exists():
        return []
    rows = []
    with merged.open() as handle:
        for row in csv.reader(handle):
            if not row or row[0].lower() in {'contig_id', 'contig'}:
                continue
            if len(row) >= 2:
                rows.append((row[0], row[1]))
    return rows


def write_rows(path: Path, rows):
    with path.open('w', newline='') as handle:
        writer = csv.writer(handle, delimiter='\t', lineterminator='\n')
        writer.writerows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--contigs', type=Path, required=True)
    ap.add_argument('--metabat2', type=Path, required=True)
    ap.add_argument('--maxbin2', type=Path, required=True)
    ap.add_argument('--concoct', type=Path, required=True)
    ap.add_argument('--outdir', type=Path, required=True)
    args = ap.parse_args()
    if not args.contigs.exists():
        raise SystemExit(f'Missing contigs: {args.contigs}')
    args.outdir.mkdir(parents=True, exist_ok=True)
    write_rows(args.outdir / 'metabat2.tsv', metabat_map(args.metabat2))
    write_rows(args.outdir / 'maxbin2.tsv', maxbin_map(args.maxbin2))
    rows = concoct_map(args.concoct)
    if not rows:
        raise SystemExit(f'Could not find CONCOCT merged_clustering.csv under {args.concoct}')
    write_rows(args.outdir / 'concoct.tsv', rows)


if __name__ == '__main__':
    main()
