#!/usr/bin/env python3
from __future__ import annotations
import argparse, glob, os
import pandas as pd
import numpy as np


def sample_id(d):
    b = os.path.basename(d.rstrip('/'))
    return b[:-3] if b.endswith('_IS') else b


def find_info(d):
    matches = glob.glob(os.path.join(d, 'output', '*scaffold_info.tsv'))
    return matches[0] if matches else None


def pick(df, names):
    lower = {str(c).lower(): c for c in df.columns}
    for n in names:
        if n in lower:
            return lower[n]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profiles_dir', required=True)
    ap.add_argument('--scaffold_to_mag', required=True)
    ap.add_argument('--breadth_thresh', type=float, default=0.5)
    ap.add_argument('--cov_thresh', type=float, default=1.0)
    ap.add_argument('--out_prefix', default='mag_detection')
    args = ap.parse_args()
    mapping = pd.read_csv(args.scaffold_to_mag, sep='\t')
    mapping['scaffold'] = mapping['scaffold'].astype(str)
    rows = []
    for d in sorted(glob.glob(os.path.join(args.profiles_dir, '*_IS'))):
        sid = sample_id(d)
        fp = find_info(d)
        if not fp:
            continue
        df = pd.read_csv(fp, sep='\t', low_memory=False)
        scaf = pick(df, ['scaffold', 'scaffold_name', 'contig', 'contig_name', 'reference'])
        leng = pick(df, ['length', 'len'])
        breadth = pick(df, ['breadth', 'breadth_0', 'covered_fraction'])
        coverage = pick(df, ['coverage', 'mean_coverage', 'coverage_mean', 'avg_coverage'])
        covered = pick(df, ['covered_bases', 'covered_bp', 'covered'])
        if scaf is None or leng is None or breadth is None:
            continue
        df[scaf] = df[scaf].astype(str)
        df[leng] = pd.to_numeric(df[leng], errors='coerce')
        df[breadth] = pd.to_numeric(df[breadth], errors='coerce')
        if coverage is not None:
            df[coverage] = pd.to_numeric(df[coverage], errors='coerce')
        if covered is not None:
            df[covered] = pd.to_numeric(df[covered], errors='coerce')
        df = df.merge(mapping, how='left', left_on=scaf, right_on='scaffold').dropna(subset=['mag', leng, breadth])
        df['_len'] = df[leng]
        df['_covered'] = df[covered] if covered is not None else df[breadth] * df[leng]
        mag = df.groupby('mag', as_index=False).agg(mag_length=('_len','sum'), mag_covered=('_covered','sum'))
        mag['breadth'] = mag['mag_covered'] / mag['mag_length']
        if coverage is not None:
            cov = df.groupby('mag').apply(lambda x: np.average(x[coverage].fillna(0), weights=x['_len']))
            mag['coverage'] = mag['mag'].map(cov.to_dict())
            mag['detected'] = (mag['breadth'] >= args.breadth_thresh) & (mag['coverage'] >= args.cov_thresh)
        else:
            mag['coverage'] = np.nan
            mag['detected'] = mag['breadth'] >= args.breadth_thresh
        mag.insert(0, 'sample', sid)
        rows.append(mag[['sample','mag','breadth','coverage','detected']])
    if not rows:
        raise SystemExit('No inStrain scaffold profiles found')
    per_sample = pd.concat(rows, ignore_index=True)
    per_mag = per_sample.groupby('mag', as_index=False).agg(n_samples=('sample','nunique'), n_detected=('detected','sum'), mean_breadth=('breadth','mean'), mean_coverage=('coverage','mean')).sort_values(['n_detected','mean_breadth'], ascending=False)
    per_sample.to_csv(f'{args.out_prefix}_per_sample.tsv', sep='\t', index=False)
    per_mag.to_csv(f'{args.out_prefix}_per_mag_summary.tsv', sep='\t', index=False)


if __name__ == '__main__':
    main()
