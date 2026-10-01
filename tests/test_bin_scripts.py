#!/usr/bin/env python3
"""Unit tests for the MAGSPI bin/ helper scripts.

Builds synthetic fixtures in a temporary directory, runs each script as a
subprocess exactly as the Nextflow processes do, and asserts on the output
tables. Run with:  python3 tests/test_bin_scripts.py
"""
import csv
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.join(os.path.dirname(HERE), "bin")
FAILURES = []


def run(script, *args):
    cmd = [sys.executable, os.path.join(BIN, script)] + [str(a) for a in args]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise AssertionError("%s failed (%d):\n%s" % (script, proc.returncode, proc.stderr))
    return proc


def read_tsv(path):
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def check(name, fn):
    try:
        fn()
        print("PASS  %s" % name)
    except AssertionError as exc:
        FAILURES.append((name, str(exc)))
        print("FAIL  %s\n      %s" % (name, exc))


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(text)


# ---------------------------------------------------------------- seqkit ----
def test_combine_seqkit(tmp):
    d = os.path.join(tmp, "seqkit")
    hdr = "sample\tfile\tformat\ttype\tnum_seqs\tsum_len\tmin_len\tavg_len\tmax_len\n"
    write(os.path.join(d, "s1.tsv"), hdr +
          "s1\ts1_non_host_R1_formeta.fastq.gz\tFASTQ\tDNA\t1000\t150000\t150\t150\t150\n"
          "s1\ts1_non_host_R2_formeta.fastq.gz\tFASTQ\tDNA\t1000\t150000\t150\t150\t150\n"
          "s1\ts1_non_host_unpaired_formeta.fastq.gz\tFASTQ\tDNA\t50\t7500\t150\t150\t150\n")
    write(os.path.join(d, "s2.tsv"), hdr +
          "s2\ts2_non_host_R1_formeta.fastq.gz\tFASTQ\tDNA\t200\t30000\t150\t150\t150\n"
          "s2\ts2_non_host_R2_formeta.fastq.gz\tFASTQ\tDNA\t200\t30000\t150\t150\t150\n"
          "s2\ts2_non_host_unpaired_formeta.fastq.gz\tFASTQ\tDNA\t0\t0\t0\t0\t0\n")

    run("combine_seqkit.py", "--inputs", os.path.join(d, "s1.tsv"), os.path.join(d, "s2.tsv"),
        "--out-all", os.path.join(d, "all.tsv"), "--out-summary", os.path.join(d, "bysample.tsv"))

    all_rows = read_tsv(os.path.join(d, "all.tsv"))
    assert len(all_rows) == 6, "expected 6 concatenated rows, got %d" % len(all_rows)

    summary = {r["sample"]: r for r in read_tsv(os.path.join(d, "bysample.tsv"))}
    assert set(summary) == {"s1", "s2"}, "samples: %s" % sorted(summary)
    assert summary["s1"]["total_reads"] == "2050", summary["s1"]
    assert summary["s1"]["r1_plus_unpaired_reads"] == "1050", summary["s1"]
    assert summary["s1"]["r1_only_reads"] == "1000", summary["s1"]
    assert summary["s2"]["total_reads"] == "400", summary["s2"]
    assert summary["s2"]["r1_plus_unpaired_reads"] == "200", summary["s2"]


# ----------------------------------------------------------------- quast ----
def test_combine_quast(tmp):
    d = os.path.join(tmp, "quast")
    write(os.path.join(d, "a.tsv"),
          "Assembly\ts1_contigs\n# contigs\t120\nTotal length\t3500000\nN50\t12000\n")
    write(os.path.join(d, "b.tsv"),
          "Assembly\ts2_contigs\n# contigs\t80\nTotal length\t2100000\nN50\t9000\nL50\t55\n")

    run("combine_quast.py", "--inputs", os.path.join(d, "a.tsv"), os.path.join(d, "b.tsv"),
        "--out", os.path.join(d, "summary.tsv"))

    rows = {r["assembly"]: r for r in read_tsv(os.path.join(d, "summary.tsv"))}
    assert set(rows) == {"s1_contigs", "s2_contigs"}, sorted(rows)
    assert rows["s1_contigs"]["N50"] == "12000", rows["s1_contigs"]
    assert rows["s2_contigs"]["L50"] == "55", rows["s2_contigs"]
    assert rows["s1_contigs"]["L50"] == "NA", "missing metrics must be NA, got %r" % rows["s1_contigs"]["L50"]


# ---------------------------------------------------------------- checkm ----
def test_combine_checkm(tmp):
    d = os.path.join(tmp, "checkm")
    hdr = "sample\tBin Id\tMarker lineage\tCompleteness\tContamination\tStrain heterogeneity\n"
    write(os.path.join(d, "s1.tsv"), hdr +
          "s1\tbin.1\tk__Bacteria\t92.50\t1.20\t0.00\n"            # keep
          "s1\tmaxbin2_bins.001\tk__Bacteria\t74.00\t3.40\t0.00\n"  # keep (not matched by the old grep)
          "s1\t7\tk__Bacteria\t55.00\t9.90\t0.00\n"                # keep (concoct, integer name)
          "s1\tbin.4\tk__Bacteria\t49.90\t1.00\t0.00\n"            # drop: completeness
          "s1\tbin.5\tk__Bacteria\t80.00\t10.10\t0.00\n")           # drop: contamination
    write(os.path.join(d, "s2.tsv"), hdr +
          "s2\tbin.1\tk__Bacteria\t50.00\t10.00\t0.00\n")           # keep: boundary values

    run("combine_checkm.py", "--inputs", os.path.join(d, "s1.tsv"), os.path.join(d, "s2.tsv"),
        "--min-completeness", 50, "--max-contamination", 10,
        "--out-all", os.path.join(d, "all.tsv"), "--out-filtered", os.path.join(d, "hq.tsv"))

    assert len(read_tsv(os.path.join(d, "all.tsv"))) == 6
    kept = read_tsv(os.path.join(d, "hq.tsv"))
    ids = sorted((r["sample"], r["Bin Id"]) for r in kept)
    assert ids == [("s1", "7"), ("s1", "bin.1"), ("s1", "maxbin2_bins.001"), ("s2", "bin.1")], ids


# ------------------------------------------------------- standardize MAGs ----
def test_standardize_mags(tmp):
    d = os.path.join(tmp, "std")
    bins = os.path.join(d, "dastool_bins")
    write(os.path.join(bins, "bin.3.fa"), ">NODE_1\nACGT\n")
    write(os.path.join(bins, "maxbin2_bins.001.fa"), ">NODE_2\nACGT\n")
    write(os.path.join(bins, "7_sub.fa"), ">NODE_3\nACGT\n")
    write(os.path.join(d, "summary.tsv"),
          "bin\tbin_set\tSCG_completeness\tsize\n"
          "bin.3\tmetabat2\t90.0\t2000\n"
          "maxbin2_bins.001\tmaxbin2\t75.0\t1600\n"
          "7_sub\tconcoct\t60.0\t1700\n"
          "garbage_name\tunknown\t10.0\t100\n")

    proc = run("standardize_dastool_mags.py", "--sample", "p23001",
               "--bins-dir", bins, "--summary", os.path.join(d, "summary.tsv"),
               "--outdir", os.path.join(d, "mags"),
               "--out-summary", os.path.join(d, "mag_summary.tsv"))

    mags = sorted(os.listdir(os.path.join(d, "mags")))
    assert mags == ["p23001_concoct_7.fa", "p23001_maxbin2_001.fa", "p23001_metabat2_3.fa"], mags

    rows = {r["MAG_ID"]: r for r in read_tsv(os.path.join(d, "mag_summary.tsv"))}
    assert set(rows) == {"p23001_metabat2_3", "p23001_maxbin2_001", "p23001_concoct_7"}, sorted(rows)
    assert rows["p23001_concoct_7"]["raw_bin"] == "7_sub", rows["p23001_concoct_7"]
    assert rows["p23001_concoct_7"]["tool"] == "concoct"
    assert rows["p23001_metabat2_3"]["bin"] == "p23001_metabat2_3", "bin column must be replaced by MAG_ID"
    assert "garbage_name" in proc.stderr, "unparsable bin IDs must be reported"


# ------------------------------------------------------- rename + catalogue ----
def test_rename_and_catalogue(tmp):
    d = os.path.join(tmp, "refs")
    derep = os.path.join(d, "derep")
    write(os.path.join(derep, "p23001_metabat2_3.fa"), ">NODE_1 len=10\nACGTACGTAC\n>NODE_2\nACGTA\n")
    write(os.path.join(derep, "p23002_maxbin2_001.fasta"), ">NODE_1\nACGT\n")

    run("rename_mag_contigs.py", "--indir", derep, "--outdir", os.path.join(d, "renamed"))
    renamed = sorted(os.listdir(os.path.join(d, "renamed")))
    assert renamed == ["p23001_metabat2_3.fa", "p23002_maxbin2_001.fa"], renamed
    with open(os.path.join(d, "renamed", "p23001_metabat2_3.fa")) as fh:
        heads = [l.strip() for l in fh if l.startswith(">")]
    assert heads == [">p23001_metabat2_3_NODE_1 len=10", ">p23001_metabat2_3_NODE_2"], heads

    run("build_mag_references.py", "--indir", os.path.join(d, "renamed"),
        "--catalogue", os.path.join(d, "catalogue.fasta"),
        "--stb", os.path.join(d, "contigs2bins.stb"),
        "--mag-ids", os.path.join(d, "mag_ids.txt"),
        "--scaffold-to-mag", os.path.join(d, "scaffold_to_mag.tsv"),
        "--scaffold-list-dir", os.path.join(d, "lists"),
        "--saf", os.path.join(d, "mags.saf"))

    stb = [l.split("\t") for l in open(os.path.join(d, "contigs2bins.stb")).read().splitlines()]
    assert stb == [["p23001_metabat2_3_NODE_1", "p23001_metabat2_3"],
                   ["p23001_metabat2_3_NODE_2", "p23001_metabat2_3"],
                   ["p23002_maxbin2_001_NODE_1", "p23002_maxbin2_001"]], stb

    mag_ids = open(os.path.join(d, "mag_ids.txt")).read().split()
    assert mag_ids == ["p23001_metabat2_3", "p23002_maxbin2_001"], mag_ids

    lists = sorted(os.listdir(os.path.join(d, "lists")))
    assert lists == ["p23001_metabat2_3.scaffolds.txt", "p23002_maxbin2_001.scaffolds.txt"], lists
    first = open(os.path.join(d, "lists", "p23001_metabat2_3.scaffolds.txt")).read().split()
    assert first == ["p23001_metabat2_3_NODE_1", "p23001_metabat2_3_NODE_2"], first

    saf = read_tsv(os.path.join(d, "mags.saf"))
    lens = {r["Chr"]: r["End"] for r in saf}
    assert lens["p23001_metabat2_3_NODE_1"] == "10", saf
    assert lens["p23001_metabat2_3_NODE_2"] == "5", saf
    assert all(r["GeneID"].startswith("p23") and r["Strand"] == "." for r in saf), saf

    cat = open(os.path.join(d, "catalogue.fasta")).read()
    assert cat.count(">") == 3, cat


# ----------------------------------------------------- inStrain detection ----
def test_aggregate_detection(tmp):
    d = os.path.join(tmp, "detect")
    write(os.path.join(d, "scaffold_to_mag.tsv"),
          "scaffold\tmag\n"
          "m1_s1\tm1\nm1_s2\tm1\nm2_s3\tm2\n")

    hdr = "scaffold\tlength\tbreadth\tcoverage\tcovered_bases\n"
    # m1: breadth = (900+100)/2000 = 0.5 ; coverage = (10*1000 + 1*1000)/2000 = 5.5 -> detected
    # m2: breadth = 100/500 = 0.2        ; coverage = 0.5                          -> not detected
    write(os.path.join(d, "profiles", "sampleA.IS", "output", "sampleA.IS_scaffold_info.tsv"), hdr +
          "m1_s1\t1000\t0.9\t10.0\t900\n"
          "m1_s2\t1000\t0.1\t1.0\t100\n"
          "m2_s3\t500\t0.2\t0.5\t100\n"
          "orphan_scaffold\t999\t1.0\t50.0\t999\n")
    # sampleB: m1 absent-ish, m2 well covered
    write(os.path.join(d, "profiles", "sampleB.IS", "output", "sampleB.IS_scaffold_info.tsv"), hdr +
          "m1_s1\t1000\t0.05\t0.2\t50\n"
          "m1_s2\t1000\t0.05\t0.2\t50\n"
          "m2_s3\t500\t0.8\t4.0\t400\n")

    proc = run("aggregate_instrain_detection.py",
               "--profiles-dir", os.path.join(d, "profiles"),
               "--scaffold-to-mag", os.path.join(d, "scaffold_to_mag.tsv"),
               "--breadth-thresh", 0.5, "--cov-thresh", 1.0,
               "--out-prefix", os.path.join(d, "det"))

    rows = {(r["sample"], r["mag"]): r for r in read_tsv(os.path.join(d, "det_per_sample.tsv"))}
    assert len(rows) == 4, sorted(rows)
    a1 = rows[("sampleA", "m1")]
    assert abs(float(a1["breadth"]) - 0.5) < 1e-9, a1
    assert abs(float(a1["coverage"]) - 5.5) < 1e-9, a1
    assert a1["detected"] == "True", a1
    a2 = rows[("sampleA", "m2")]
    assert abs(float(a2["breadth"]) - 0.2) < 1e-9, a2
    assert abs(float(a2["coverage"]) - 0.5) < 1e-9, a2
    assert a2["detected"] == "False", a2
    b2 = rows[("sampleB", "m2")]
    assert abs(float(b2["breadth"]) - 0.8) < 1e-9, b2
    assert abs(float(b2["coverage"]) - 4.0) < 1e-9, b2
    assert b2["detected"] == "True", "breadth 0.8 and coverage 4.0 should be a detection: %s" % b2

    summary = {r["mag"]: r for r in read_tsv(os.path.join(d, "det_per_mag_summary.tsv"))}
    assert summary["m1"]["n_samples"] == "2", summary["m1"]
    assert summary["m1"]["n_detected"] == "1", summary["m1"]
    assert summary["m2"]["n_detected"] == "1", summary["m2"]
    assert abs(float(summary["m1"]["mean_breadth"]) - 0.275) < 1e-9, summary["m1"]
    assert "scaffolds not in mapping: 1" in proc.stderr, proc.stderr


# ------------------------------------------------------------- versions ----
def test_collate_versions(tmp):
    d = os.path.join(tmp, "ver")
    write(os.path.join(d, "collated.yml"),
          '"MAGSPI:FASTP":\n    fastp: 1.3.6\n'
          '"MAGSPI:FASTP":\n    fastp: 1.3.6\n'
          '"MAGSPI:SPADES_META":\n    spades: 4.1.0\n')
    run("collate_versions.py", "--input", os.path.join(d, "collated.yml"),
        "--out", os.path.join(d, "software_versions.yml"))
    text = open(os.path.join(d, "software_versions.yml")).read()
    assert text.count("fastp: 1.3.6") == 1, text
    assert "spades: 4.1.0" in text, text


def main():
    tmp = tempfile.mkdtemp(prefix="magspi_tests_")
    try:
        check("combine_seqkit.py", lambda: test_combine_seqkit(tmp))
        check("combine_quast.py", lambda: test_combine_quast(tmp))
        check("combine_checkm.py", lambda: test_combine_checkm(tmp))
        check("standardize_dastool_mags.py", lambda: test_standardize_mags(tmp))
        check("rename_mag_contigs.py + build_mag_references.py", lambda: test_rename_and_catalogue(tmp))
        check("aggregate_instrain_detection.py", lambda: test_aggregate_detection(tmp))
        check("collate_versions.py", lambda: test_collate_versions(tmp))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("\n%d/%d test groups passed" % (7 - len(FAILURES), 7))
    if FAILURES:
        sys.exit(1)


if __name__ == "__main__":
    main()
