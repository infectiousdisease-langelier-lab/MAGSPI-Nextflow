#!/usr/bin/env python3
"""Extract DAS Tool-selected source bins into standardized MAG FASTA files."""
from __future__ import annotations
import argparse
import re
import shutil
from pathlib import Path
import pandas as pd


def parse_bin(raw: str):
    rb = re.sub(r'_sub$', '', str(raw).strip())
    if rb.startswith('bin.'):
        return 'metabat2', rb, 'metabat2'
    if rb.startswith('maxbin2_') or rb.startswith('maxbin2.') or rb.startswith('maxbin2_bins.'):
        return 'maxbin2', rb, 'maxbin2'
    if re.fullmatch(r'\d+', rb):
        return 'concoct', rb, 'concoct'
    return None


def resolve(source_dir: Path, tool: str, key: str):
    if tool == 'metabat2':
        candidates = list(source_dir.glob('bin.*.fa'))
        return next((p for p in candidates if p.stem == key), None)
    if tool == 'maxbin2':
        candidates = list(source_dir.glob('*.fasta'))
        if key.startswith('maxbin2_bins.'):
            suffix = key[len('maxbin2_bins.'): ]
        elif key.startswith('maxbin2.'):
            suffix = key[len('maxbin2.'): ]
        elif key.startswith('maxbin2_'):
            suffix = key[len('maxbin2_'): ]
        else:
            suffix = key
        return next((p for p in candidates if p.stem.endswith(suffix) or p.stem == key), None)
    candidates = list(source_dir.rglob(f'fasta_bins/{key}.fa')) + list(source_dir.rglob(f'fasta_bins/{key}.fasta')) + list(source_dir.rglob(f'{key}.fa')) + list(source_dir.rglob(f'{key}.fasta'))
    return candidates[0] if candidates else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dastool_dir', type=Path, required=True)
    ap.add_argument('--metabat2', type=Path, required=True)
    ap.add_argument('--maxbin2', type=Path, required=True)
    ap.add_argument('--concoct', type=Path, required=True)
    ap.add_argument('--outdir', type=Path, required=True)
    ap.add_argument('--sample', required=True)
    args = ap.parse_args()
    summaries = list(args.dastool_dir.rglob('*_DASTool_summary.tsv'))
    if not summaries:
        raise SystemExit(f'No DAS Tool summary found under {args.dastool_dir}')
    df = pd.read_csv(summaries[0], sep='\t', comment='#')
    args.outdir.mkdir(parents=True, exist_ok=True)
    roots = {'metabat2': args.metabat2, 'maxbin2': args.maxbin2, 'concoct': args.concoct}
    copied = 0
    for raw in df.iloc[:, 0].astype(str):
        parsed = parse_bin(raw)
        if not parsed:
            continue
        tool, key, _ = parsed
        src = resolve(roots[tool], tool, key)
        if src is None:
            continue
        clean_key = key
        for prefix in ('maxbin2_bins.', 'maxbin2_', 'maxbin2.'):
            if clean_key.startswith(prefix):
                clean_key = clean_key[len(prefix):]
                break
        dst = args.outdir / f'{args.sample}_{tool}_{clean_key}.fa'
        shutil.copy2(src, dst)
        copied += 1
    if copied == 0:
        raise SystemExit('No DAS Tool-selected source bins could be resolved')


if __name__ == '__main__':
    main()
