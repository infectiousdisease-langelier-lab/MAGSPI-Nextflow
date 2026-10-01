#!/usr/bin/env python3
"""Build every MAG reference file the inStrain stage needs.

Replaces MAGSPI scripts 25 (catalogue), 27 (.stb), 28 (per-MAG scaffold
lists), 29 / make_stb.py (scaffold->MAG table) and make_saf.py (SAF).

The MAG ID comes from the FASTA filename, not from splitting a list filename
on '.', so MAG IDs containing dots survive intact.
"""
import argparse
import os
import sys

FASTA_EXT = (".fa", ".fasta", ".fna")


def mag_id_from_name(name):
    for ext in FASTA_EXT:
        if name.endswith(ext):
            return name[: -len(ext)]
    return name


def iter_fasta(path):
    name, length = None, 0
    with open(path) as fh:
        for line in fh:
            if line.startswith(">"):
                if name is not None:
                    yield name, length
                name = line[1:].strip().split()[0]
                length = 0
            else:
                length += len(line.strip())
    if name is not None:
        yield name, length


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--indir", required=True)
    ap.add_argument("--catalogue", required=True)
    ap.add_argument("--stb", required=True)
    ap.add_argument("--mag-ids", required=True)
    ap.add_argument("--scaffold-to-mag", required=True)
    ap.add_argument("--scaffold-list-dir", required=True)
    ap.add_argument("--saf", required=True)
    args = ap.parse_args()

    names = sorted(f for f in os.listdir(args.indir) if f.endswith(FASTA_EXT))
    if not names:
        sys.exit("No FASTA files in %s" % args.indir)

    os.makedirs(args.scaffold_list_dir, exist_ok=True)

    mags = []
    seen_scaffolds = {}
    with open(args.catalogue, "w") as cat, \
         open(args.stb, "w") as stb, \
         open(args.scaffold_to_mag, "w") as s2m, \
         open(args.saf, "w") as saf:

        s2m.write("scaffold\tmag\n")
        saf.write("GeneID\tChr\tStart\tEnd\tStrand\n")

        for name in names:
            mag = mag_id_from_name(name)
            mags.append(mag)
            path = os.path.join(args.indir, name)

            # catalogue: straight concatenation of the renamed MAGs
            with open(path) as fin:
                for line in fin:
                    cat.write(line)

            scaffolds = []
            for scaffold, length in iter_fasta(path):
                if scaffold in seen_scaffolds:
                    sys.exit("Duplicate scaffold %r in %s and %s -- contig headers must be "
                             "MAG-prefixed before this step" % (scaffold, seen_scaffolds[scaffold], mag))
                seen_scaffolds[scaffold] = mag
                scaffolds.append(scaffold)
                stb.write("%s\t%s\n" % (scaffold, mag))
                s2m.write("%s\t%s\n" % (scaffold, mag))
                saf.write("%s\t%s\t1\t%d\t.\n" % (mag, scaffold, length))

            with open(os.path.join(args.scaffold_list_dir, mag + ".scaffolds.txt"), "w") as lst:
                for scaffold in scaffolds:
                    lst.write("%s\n" % scaffold)

    with open(args.mag_ids, "w") as fh:
        for mag in mags:
            fh.write("%s\n" % mag)

    sys.stderr.write("catalogue: %d MAGs, %d scaffolds\n" % (len(mags), len(seen_scaffolds)))


if __name__ == "__main__":
    main()
