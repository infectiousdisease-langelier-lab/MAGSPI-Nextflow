#!/usr/bin/env python3
"""Combine dereplicated genomes, namespace contigs by MAG, and build mappings."""
from __future__ import annotations
import argparse
from pathlib import Path


def fasta_records(path: Path):
    name = None
    seq = []
    with path.open() as fh:
        for line in fh:
            line = line.rstrip()
            if line.startswith('>'):
                if name is not None:
                    yield name, ''.join(seq)
                name = line[1:].split()[0]
                seq = []
            else:
                seq.append(line)
        if name is not None:
            yield name, ''.join(seq)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--derep_dir', type=Path, required=True)
    ap.add_argument('--outdir', type=Path, required=True)
    args = ap.parse_args()
    # dRep stores representative genomes beneath dereplicated_genomes.
    genomes = sorted((args.derep_dir / 'derep_out' / 'dereplicated_genomes').glob('*.fna'))
    if not genomes:
        genomes = sorted(args.derep_dir.rglob('*.fna'))
    if not genomes:
        genomes = sorted(args.derep_dir.rglob('*.fa'))
    if not genomes:
        raise SystemExit(f'No dereplicated FASTA files found under {args.derep_dir}')
    args.outdir.mkdir(parents=True, exist_ok=True)
    ref = args.outdir / 'mag_reference.fna'
    mapping = args.outdir / 'scaffold_to_mag.tsv'
    with ref.open('w') as out_fa, mapping.open('w') as out_map:
        out_map.write('scaffold\tmag\n')
        for genome in genomes:
            mag = genome.stem
            for contig, seq in fasta_records(genome):
                new = f'{mag}__{contig}'
                out_fa.write(f'>{new}\n')
                for i in range(0, len(seq), 80):
                    out_fa.write(seq[i:i+80] + '\n')
                out_map.write(f'{new}\t{mag}\n')
    (args.outdir / 'mag_ids.txt').write_text('\n'.join(g.stem for g in genomes) + '\n')
    lists = args.outdir / 'mag_scaffold_lists'
    lists.mkdir(exist_ok=True)
    mapping_rows = mapping.read_text().splitlines()[1:]
    by_mag = {}
    for row in mapping_rows:
        scaffold, mag = row.split('\t')
        by_mag.setdefault(mag, []).append(scaffold)
    for mag, scaffolds in by_mag.items():
        (lists / f'{mag}.scaffolds.txt').write_text('\n'.join(scaffolds) + '\n')


if __name__ == '__main__':
    main()
