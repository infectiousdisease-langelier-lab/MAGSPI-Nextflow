#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profiles_dir', type=Path, required=True)
    ap.add_argument('--reference_dir', type=Path, required=True)
    ap.add_argument('--outdir', type=Path, required=True)
    ap.add_argument('--threads', type=int, default=8)
    args = ap.parse_args()
    profiles = sorted(str(p) for p in args.profiles_dir.iterdir() if p.is_dir() and p.name.endswith('_IS'))
    if not profiles:
        raise SystemExit('No inStrain profile directories found')
    lists = args.reference_dir / 'mag_scaffold_lists'
    args.outdir.mkdir(parents=True, exist_ok=True)
    mag_ids = [p.stem for p in lists.glob('*.scaffolds.txt')]
    for mag in mag_ids:
        scaffold_file = lists / f'{mag}.scaffolds.txt'
        if scaffold_file.stat().st_size == 0:
            continue
        out = args.outdir / f'{mag}.IS.compare'
        cmd = ['inStrain','compare','-i',*profiles,'-sc',str(scaffold_file),'-p',str(args.threads),'-o',str(out)]
        subprocess.run(cmd, check=True)


if __name__ == '__main__':
    main()
