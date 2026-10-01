#!/usr/bin/env python3
"""Build the MAGSPI test dataset: a simulated three-sample mini-metagenome.

Downloads four reference sequences from NCBI, trims the three microbial
genomes to a fixed-length slice, and simulates paired-end Illumina-like reads
for three samples at different relative abundances. A small number of
strain-level SNPs is introduced per sample so that the inStrain stages have
something to compare.

    python3 tests/make_test_data.py --outdir tests/data

Writes tests/data/*.fastq.gz, tests/data/host_mt.fasta, the reference slices
(for provenance) and assets/samplesheet_test.csv.

Deterministic: the same seed produces the same reads on every machine.
"""
import argparse
import gzip
import os
import random
import sys
import urllib.parse
import urllib.request

EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

# (accession, label, slice length) -- small, low-GC-to-mid-GC bacterial genomes
GENOMES = [
    ("NC_000908.2", "Mycoplasmoides_genitalium", 300_000),   # GC ~32%
    ("NC_000117.1", "Chlamydia_trachomatis", 300_000),       # GC ~41%
    ("NC_004572.3", "Tropheryma_whipplei", 300_000),         # GC ~46%
]
HOST = ("NC_012920.1", "human_mitochondrion")

# sample -> per-genome fold coverage
ABUNDANCE = {
    "testA": [35, 25, 15],
    "testB": [15, 35, 25],
    "testC": [25, 15, 35],
}
HOST_PAIRS = 2000          # host reads spiked into every sample
READ_LEN = 150
FRAG_MEAN = 320
FRAG_SD = 40
ERROR_RATE = 0.002
SNPS_PER_GENOME = 40       # strain-level differences, re-drawn per sample
SEED = 20240101

COMPLEMENT = str.maketrans("ACGTNacgtn", "TGCANtgcan")


def efetch(accession, email=None):
    params = {"db": "nuccore", "id": accession, "rettype": "fasta", "retmode": "text"}
    if email:
        params["email"] = email
    url = EUTILS + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=120) as fh:
        text = fh.read().decode()
    lines = [l.strip() for l in text.splitlines()]
    if not lines or not lines[0].startswith(">"):
        raise RuntimeError("unexpected response for %s: %r" % (accession, text[:200]))
    return "".join(l for l in lines[1:] if l and not l.startswith(">")).upper()


def revcomp(seq):
    return seq.translate(COMPLEMENT)[::-1]


def mutate(seq, n, rng):
    seq = list(seq)
    for _ in range(n):
        i = rng.randrange(len(seq))
        ref = seq[i]
        alt = rng.choice([b for b in "ACGT" if b != ref])
        seq[i] = alt
    return "".join(seq)


def simulate_pairs(seq, n_pairs, rng, name, r1, r2, start_index):
    """Append n_pairs reads from seq to the open gzip handles r1/r2."""
    for i in range(n_pairs):
        frag = max(READ_LEN + 10, int(rng.gauss(FRAG_MEAN, FRAG_SD)))
        if frag >= len(seq):
            frag = len(seq) - 1
        pos = rng.randrange(0, len(seq) - frag)
        fragment = seq[pos:pos + frag]
        if rng.random() < 0.5:
            fragment = revcomp(fragment)
        fwd = fragment[:READ_LEN]
        rev = revcomp(fragment)[:READ_LEN]
        fwd = add_errors(fwd, rng)
        rev = add_errors(rev, rng)
        rid = "%s_%d" % (name, start_index + i)
        r1.write("@%s/1\n%s\n+\n%s\n" % (rid, fwd, quality_string(len(fwd), rng)))
        r2.write("@%s/2\n%s\n+\n%s\n" % (rid, rev, quality_string(len(rev), rng)))
    return start_index + n_pairs


def quality_string(length, rng):
    """Phred+33 qualities that decline along the read.

    A spread of values is required, not a constant: SPAdes cannot determine
    the quality offset when every base carries the same character (a constant
    'I' is Q40 under Phred+33 and Q9 under Phred+64, and BayesHammer aborts
    with "Failed to determine offset").
    """
    out = []
    for i in range(length):
        centre = 38 - int(8.0 * i / length)
        q = int(rng.gauss(centre, 3))
        q = max(2, min(40, q))
        out.append(chr(33 + q))
    return "".join(out)


def add_errors(read, rng):
    if ERROR_RATE <= 0:
        return read
    out = list(read)
    n_err = rng.binomialvariate(len(out), ERROR_RATE) if hasattr(rng, "binomialvariate") else \
        sum(1 for _ in range(len(out)) if rng.random() < ERROR_RATE)
    for _ in range(n_err):
        i = rng.randrange(len(out))
        out[i] = rng.choice([b for b in "ACGT" if b != out[i]])
    return "".join(out)


def write_fasta(path, name, seq, width=70):
    with open(path, "w") as fh:
        fh.write(">%s\n" % name)
        for i in range(0, len(seq), width):
            fh.write(seq[i:i + width] + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", default="tests/data")
    ap.add_argument("--samplesheet", default="assets/samplesheet_test.csv")
    ap.add_argument("--email", default=None,
                    help="contact address sent to NCBI E-utilities (optional)")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    refdir = os.path.join(args.outdir, "references")
    os.makedirs(refdir, exist_ok=True)

    rng = random.Random(SEED)

    sys.stderr.write("fetching references from NCBI\n")
    refs = []
    for accession, label, length in GENOMES:
        seq = efetch(accession, args.email)
        if len(seq) < length:
            raise RuntimeError("%s is shorter (%d) than the requested slice (%d)"
                               % (accession, len(seq), length))
        sliced = seq[:length]
        gc = 100.0 * sum(sliced.count(b) for b in "GC") / len(sliced)
        sys.stderr.write("  %-28s %s  %d bp slice, GC %.1f%%\n" % (label, accession, length, gc))
        write_fasta(os.path.join(refdir, label + ".fasta"), "%s_%s" % (label, accession), sliced)
        refs.append((label, sliced))

    host_seq = efetch(HOST[0], args.email)
    sys.stderr.write("  %-28s %s  %d bp\n" % (HOST[1], HOST[0], len(host_seq)))
    host_path = os.path.join(args.outdir, "host_mt.fasta")
    write_fasta(host_path, "%s_%s" % (HOST[1], HOST[0]), host_seq)

    rows = []
    for sample in sorted(ABUNDANCE):
        r1_path = os.path.join(args.outdir, "%s_R1.fastq.gz" % sample)
        r2_path = os.path.join(args.outdir, "%s_R2.fastq.gz" % sample)
        total = 0
        with gzip.open(r1_path, "wt") as r1, gzip.open(r2_path, "wt") as r2:
            for (label, seq), depth in zip(refs, ABUNDANCE[sample]):
                strain = mutate(seq, SNPS_PER_GENOME, rng)
                n_pairs = int(len(seq) * depth / (2 * READ_LEN))
                total = simulate_pairs(strain, n_pairs, rng, "%s_%s" % (sample, label),
                                       r1, r2, total)
                sys.stderr.write("  %s: %-28s %dx -> %d pairs\n" % (sample, label, depth, n_pairs))
            total = simulate_pairs(host_seq, HOST_PAIRS, rng, "%s_host" % sample, r1, r2, total)
        sys.stderr.write("  %s: %d pairs total (%.1f MB + %.1f MB)\n"
                         % (sample, total,
                            os.path.getsize(r1_path) / 1e6, os.path.getsize(r2_path) / 1e6))
        rows.append((sample, os.path.basename(r1_path), os.path.basename(r2_path)))

    sheet_dir = os.path.dirname(os.path.abspath(args.samplesheet))
    os.makedirs(sheet_dir, exist_ok=True)
    rel = os.path.relpath(os.path.abspath(args.outdir), sheet_dir)
    with open(args.samplesheet, "w") as fh:
        fh.write("sample,fastq_1,fastq_2\n")
        for sample, r1, r2 in rows:
            fh.write("%s,%s/%s,%s/%s\n" % (sample, rel, r1, rel, r2))
    sys.stderr.write("wrote %s\n" % args.samplesheet)
    sys.stderr.write("host reference: %s\n" % host_path)


if __name__ == "__main__":
    main()
