#!/usr/bin/env python3
"""Aggregate inStrain scaffold-level output into sample x MAG detection calls.

Port of MAGSPI script 30 with identical arithmetic, implemented without
pandas/numpy so it runs in a plain python container:

    MAG breadth  = sum(covered bases) / sum(scaffold length)
    MAG coverage = length-weighted mean of scaffold coverage
    detected     = breadth >= --breadth-thresh and coverage >= --cov-thresh
"""
import argparse
import csv
import glob
import os
import sys

SCAFFOLD_CANDIDATES = ["scaffold", "scaffold_name", "contig", "contig_name", "reference"]
LENGTH_CANDIDATES = ["length", "len"]
BREADTH_CANDIDATES = ["breadth", "breadth_0", "covered_fraction"]
COVERAGE_CANDIDATES = ["coverage", "mean_coverage", "coverage_mean", "avg_coverage"]
COVERED_BP_CANDIDATES = ["covered_bases", "covered_bp", "covered"]


def pick(fieldnames, candidates):
    lower = {f.strip().lower(): f for f in fieldnames if f}
    for cand in candidates:
        if cand in lower:
            return lower[cand]
    return None


def sample_id_from_dir(path):
    base = os.path.basename(path.rstrip("/"))
    for suffix in (".IS", "_IS"):
        if base.endswith(suffix):
            return base[: -len(suffix)]
    return base


def find_scaffold_info(profile_dir):
    for pattern in ("output/*scaffold_info.tsv", "*scaffold_info.tsv"):
        hits = sorted(glob.glob(os.path.join(profile_dir, pattern)))
        if hits:
            return hits[0]
    return None


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profiles-dir", required=True)
    ap.add_argument("--scaffold-to-mag", required=True)
    ap.add_argument("--breadth-thresh", type=float, default=0.5)
    ap.add_argument("--cov-thresh", type=float, default=1.0)
    ap.add_argument("--out-prefix", default="mag_detection")
    args = ap.parse_args()

    with open(args.scaffold_to_mag, newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        scaffold_col = pick(reader.fieldnames or [], ["scaffold"]) or "scaffold"
        mag_col = pick(reader.fieldnames or [], ["mag"]) or "mag"
        scaffold_to_mag = {row[scaffold_col]: row[mag_col] for row in reader if row.get(scaffold_col)}
    if not scaffold_to_mag:
        sys.exit("Empty scaffold-to-MAG mapping: %s" % args.scaffold_to_mag)

    profile_dirs = sorted(
        d for pattern in ("*.IS", "*_IS")
        for d in glob.glob(os.path.join(args.profiles_dir, pattern))
        if os.path.isdir(d)
    )
    if not profile_dirs:
        sys.exit("No inStrain profile directories (*.IS) under %s" % args.profiles_dir)

    per_sample = []
    missing = 0
    unmapped_scaffolds = 0

    for profile_dir in profile_dirs:
        sample = sample_id_from_dir(profile_dir)
        info_path = find_scaffold_info(profile_dir)
        if info_path is None:
            missing += 1
            continue

        with open(info_path, newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            fields = reader.fieldnames or []
            scaf_col = pick(fields, SCAFFOLD_CANDIDATES)
            len_col = pick(fields, LENGTH_CANDIDATES)
            br_col = pick(fields, BREADTH_CANDIDATES)
            cov_col = pick(fields, COVERAGE_CANDIDATES)
            covbp_col = pick(fields, COVERED_BP_CANDIDATES)
            if scaf_col is None or len_col is None or br_col is None:
                sys.exit("Missing required columns in %s; need scaffold/length/breadth, found %s"
                         % (info_path, fields))

            agg = {}
            for row in reader:
                scaffold = row[scaf_col]
                mag = scaffold_to_mag.get(scaffold)
                if mag is None:
                    unmapped_scaffolds += 1
                    continue
                length = to_float(row.get(len_col))
                breadth = to_float(row.get(br_col))
                if length is None or breadth is None:
                    continue
                covered = to_float(row.get(covbp_col)) if covbp_col else None
                if covered is None:
                    covered = breadth * length
                coverage = to_float(row.get(cov_col)) if cov_col else None

                rec = agg.setdefault(mag, {"length": 0.0, "covered": 0.0, "cov_weighted": 0.0})
                rec["length"] += length
                rec["covered"] += covered
                rec["cov_weighted"] += (coverage or 0.0) * length

        for mag in sorted(agg):
            rec = agg[mag]
            breadth = rec["covered"] / rec["length"] if rec["length"] else 0.0
            if cov_col is not None:
                coverage = rec["cov_weighted"] / rec["length"] if rec["length"] else 0.0
                detected = breadth >= args.breadth_thresh and coverage >= args.cov_thresh
            else:
                coverage = None
                detected = breadth >= args.breadth_thresh
            per_sample.append({
                "sample": sample,
                "mag": mag,
                "breadth": breadth,
                "coverage": coverage,
                "detected": detected,
            })

    if not per_sample:
        sys.exit("No MAG-level rows produced; check that the scaffold names in the "
                 "inStrain output match the scaffold-to-MAG mapping")

    out_per_sample = "%s_per_sample.tsv" % args.out_prefix
    with open(out_per_sample, "w", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t", lineterminator="\n")
        writer.writerow(["sample", "mag", "breadth", "coverage", "detected"])
        for row in per_sample:
            writer.writerow([
                row["sample"], row["mag"],
                "%.6f" % row["breadth"],
                "NA" if row["coverage"] is None else "%.6f" % row["coverage"],
                "True" if row["detected"] else "False",
            ])

    by_mag = {}
    for row in per_sample:
        rec = by_mag.setdefault(row["mag"], {"samples": set(), "detected": 0,
                                             "breadths": [], "coverages": []})
        rec["samples"].add(row["sample"])
        rec["detected"] += 1 if row["detected"] else 0
        rec["breadths"].append(row["breadth"])
        if row["coverage"] is not None:
            rec["coverages"].append(row["coverage"])

    def mean(values):
        return sum(values) / len(values) if values else None

    out_per_mag = "%s_per_mag_summary.tsv" % args.out_prefix
    rows = []
    for mag, rec in by_mag.items():
        rows.append((mag, len(rec["samples"]), rec["detected"],
                     mean(rec["breadths"]), mean(rec["coverages"])))
    rows.sort(key=lambda r: (-r[2], -(r[3] or 0.0)))

    with open(out_per_mag, "w", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t", lineterminator="\n")
        writer.writerow(["mag", "n_samples", "n_detected", "mean_breadth", "mean_coverage"])
        for mag, n_samples, n_detected, mb, mc in rows:
            writer.writerow([mag, n_samples, n_detected,
                             "%.6f" % mb if mb is not None else "NA",
                             "%.6f" % mc if mc is not None else "NA"])

    sys.stderr.write("profiles: %d, missing scaffold_info: %d, scaffolds not in mapping: %d\n"
                     % (len(profile_dirs), missing, unmapped_scaffolds))
    sys.stderr.write("wrote %s and %s\n" % (out_per_sample, out_per_mag))


if __name__ == "__main__":
    main()
