#!/usr/bin/env python3
"""Collate per-process versions.yml fragments into one deduplicated file."""
import argparse


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    blocks = {}
    current = None
    with open(args.input) as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip():
                continue
            if not line.startswith((" ", "\t")):
                current = line.strip()
                blocks.setdefault(current, [])
            elif current is not None:
                entry = line.strip()
                if entry not in blocks[current]:
                    blocks[current].append(entry)

    with open(args.out, "w") as fh:
        for process in sorted(blocks):
            fh.write("%s\n" % process)
            for entry in blocks[process]:
                fh.write("    %s\n" % entry)


if __name__ == "__main__":
    main()
