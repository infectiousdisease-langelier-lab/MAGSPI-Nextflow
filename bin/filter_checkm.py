#!/usr/bin/env python3
"""Filter CheckM QA output and copy passing MAG FASTA files."""
from __future__ import annotations
import argparse
import shutil
from pathlib import Path
import pandas as pd


def find_col(df, needle):
    for c in df.columns:
        if needle in str(c).strip().lower().replace(' ', '_'):
            return c
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--checkm', type=Path, required=True)
    ap.add_argument('--bins', type=Path, required=True)
    ap.add_argument('--outdir', type=Path, required=True)
    ap.add_argument('--completeness', type=float, required=True)
    ap.add_argument('--contamination', type=float, required=True)
    args = ap.parse_args()

    # CheckM's table can contain comment/blank lines. Whitespace-separated output is also accepted.
    try:
        df = pd.read_csv(args.checkm, sep='\t', comment='#')
        if len(df.columns) < 3:
            raise ValueError
    except Exception:
        df = pd.read_csv(args.checkm, sep=r'\s+', comment='#', engine='python')
    if df.empty:
        raise SystemExit('CheckM produced an empty table')
    comp = find_col(df, 'completeness')
    cont = find_col(df, 'contamination')
    if comp is None or cont is None:
        raise SystemExit(f'Could not identify completeness/contamination columns in {args.checkm}')
    id_col = df.columns[0]
    df[comp] = pd.to_numeric(df[comp], errors='coerce')
    df[cont] = pd.to_numeric(df[cont], errors='coerce')
    keep = df[(df[comp] >= args.completeness) & (df[cont] <= args.contamination)]
    args.outdir.mkdir(parents=True, exist_ok=True)
    rows = []
    for _, row in keep.iterrows():
        genome = Path(str(row[id_col]).strip()).name
        candidates = [args.bins / genome, args.bins / f'{genome}.fa', args.bins / f'{genome}.fasta']
        candidates += list(args.bins.rglob(genome)) + list(args.bins.rglob(f'{genome}.fa')) + list(args.bins.rglob(f'{genome}.fasta'))
        src = next((p for p in candidates if p.is_file()), None)
        if src is None:
            continue
        shutil.copy2(src, args.outdir / (src.stem + '.fa'))
        rows.append(row.to_dict())
    pd.DataFrame(rows).to_csv(args.outdir / 'hq_checkm.tsv', sep='\t', index=False)
    if not rows:
        raise SystemExit('No bins passed CheckM thresholds or could be copied')


if __name__ == '__main__':
    main()
