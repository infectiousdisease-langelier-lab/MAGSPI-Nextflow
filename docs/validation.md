# Validation record

What has actually been run, and what has not. Updated 2026-10-01.

Environment used for these checks: macOS/arm64 laptop-class host (8 cores,
16 GB RAM), Nextflow 26.04.6, no container runtime available. Tools for the
real run came from a conda environment on `PATH`; the container profiles were
therefore config-validated but not executed.

## 1. Helper-script unit tests — PASS

```
python3 tests/test_bin_scripts.py
PASS  combine_seqkit.py
PASS  combine_quast.py
PASS  combine_checkm.py
PASS  standardize_dastool_mags.py
PASS  rename_mag_contigs.py + build_mag_references.py
PASS  aggregate_instrain_detection.py
PASS  collate_versions.py
7/7 test groups passed
```

These exercise the logic that was rewritten rather than ported verbatim, on
synthetic fixtures with hand-computed expected values:

* seqkit per-sample totals, including the R1/R2/unpaired classification that
  the original regex got wrong.
* QUAST metric union across reports with differing metric sets.
* CheckM filtering at the completeness/contamination boundary (50.00 and
  10.00 are both kept), and over MaxBin2/CONCOCT bin names that the original
  `grep "bin."` excluded.
* DAS Tool bin-ID grammar, including `_sub` stripping, with an unparsable bin
  ID asserted to produce a warning rather than silent loss.
* Contig renaming, `.stb`, per-MAG scaffold lists, `scaffold_to_mag.tsv` and
  SAF contig lengths.
* MAG detection arithmetic: for a MAG with scaffolds (1000 bp, 900 covered,
  10x) and (1000 bp, 100 covered, 1x) the test asserts breadth 0.5 and
  length-weighted coverage 5.5, and that a scaffold absent from the mapping is
  counted and reported.

## 2. Configuration — PASS

`nextflow config` resolves cleanly for `standard`, `docker`, `apptainer`,
`singularity`, `conda`, `slurm`, `test` and `test_stub`.

Parameter validation rejects bad input, e.g.

```
$ nextflow run . -profile test_stub -stub-run --stop_after nonsense
Parameter validation failed:
  - --stop_after must be one of read_prep, assembly, binners, binning, mags, all (got 'nonsense')
```

Duplicate and malformed sample IDs, a missing samplesheet, a single-end row,
and missing `--checkm_db` / `--gtdbtk_db` / host reference are all caught
before any task is submitted.

## 3. Full-DAG stub run — PASS

```
nextflow run . -profile test_stub -stub-run --outdir results_stub
```

Exit 0; 75 tasks over 34 distinct process invocations across three samples.
This confirms channel wiring end to end: per-sample fan-out, the
`groupTuple` that assembles the three contig-to-bin tables per sample in a
fixed binner order, the cross-sample `collect` points (seqkit, QUAST, CheckM,
MAG summary, dRep, GTDB-Tk), and the per-MAG fan-out of `INSTRAIN_COMPARE`
driven by the scaffold-list channel. `--stop_after binners` was verified to
stop the DAG before `CONTIG2BIN`/`DASTOOL`.

Stub runs do not execute any tool, so they prove the graph, not the commands.

## 4. Real-tool run on a simulated mini-metagenome — PASS (front half)

Data: `tests/make_test_data.py` — 300 kb slices of *Mycoplasmoides
genitalium* NC_000908.2 (GC 32.9%), *Chlamydia trachomatis* NC_000117.1
(GC 40.7%) and *Tropheryma whipplei* NC_004572.3 (GC 46.6%), simulated at
rotating 35x/25x/15x coverage across three samples, with 40 strain-level SNPs
re-drawn per sample and 2000 read pairs of human mitochondrial DNA
(NC_012920.1) spiked in as host contamination. 77,000 pairs per sample.

```
nextflow run . -profile test --stop_after binners --skip_quast --skip_multiqc
```

Exit 0. Observed results:

| Check | Result |
|---|---|
| Host depletion | 2.60% of pairs aligned concordantly to the host reference in every sample — exactly the 2000 spiked pairs |
| Reads surviving QC + depletion + repair | 149,960 / 149,936 / 149,930 (testA/B/C) |
| Assembly | 23 / 21 / 17 contigs, 896,113 / 895,549 / 895,636 bp — against 900,000 bp of input genome |
| Depth table | `contigName/contigLen/totalAvgDepth/...`, depths 34.9x, 25.0x, 15.0x matching the simulated abundances |
| MaxBin2 abundance file | two columns, no header, as `-abund` requires |
| MetaBAT2 bins | 3 / 4 / 3 |
| MaxBin2 bins | 2 / 2 / 2 |
| CONCOCT bins | 5 / 4 / 5, produced by the restored `merge_cutup_clustering.py` + `extract_fasta_bins.py` steps |
| Version capture | all 14 executed processes reported a version into `pipeline_info/software_versions.yml` |
| `-resume` | 26 of 36 tasks reused from cache on re-run |

Per-task runtimes on this host: fastp ~27 s, bowtie2 host alignment ~1 s,
metaSPAdes ~23 s, read-to-assembly mapping ~4.5 s, MetaBAT2 ~50 ms, MaxBin2
~2 s, CONCOCT ~5 s per sample.

Processes executed with real tools (14):

`BOWTIE2_BUILD_HOST`, `FASTP`, `BOWTIE2_HOST`, `SAMTOOLS_NONHOST`,
`BBMAP_REPAIR`, `SEQKIT_STATS`, `COMBINE_SEQKIT`, `SPADES_META`,
`MAP_TO_ASSEMBLY`, `JGI_DEPTH`, `METABAT2`, `MAXBIN2`, `CONCOCT`,
`COLLATE_VERSIONS`.

### Two defects in the port were found by this run and fixed

1. MetaBAT2/MaxBin2/CONCOCT bins from different samples published to the same
   directory and overwrote each other (`07_binning/concoct/0.fa` for all three
   samples). The publish path now includes `${meta.id}`.
2. The MetaBAT2 version string (`version 2:2.18`) was parsed as `2`.

## 5. Not yet run — needs the cluster

| Process | Why |
|---|---|
| `QUAST`, `COMBINE_QUAST` | QUAST has no osx-arm64 conda build on this host |
| `CONTIG2BIN`, `DASTOOL` | DAS Tool depends on `pullseq`, which has no osx-arm64 build |
| `CHECKM_LINEAGEWF`, `COMBINE_CHECKM` | needs the ~1.4 GB CheckM database |
| `GTDBTK_CLASSIFYWF` | needs the ~110 GB GTDB release |
| `DREP_DEREPLICATE` | reachable only downstream of DAS Tool |
| `STANDARDIZE_MAGS`, `SUMMARIZE_MAGS`, `RENAME_MAG_CONTIGS`, `MAG_CATALOGUE` | reachable only downstream of DAS Tool; their logic is covered by the unit tests in §1 |
| `BOWTIE2_BUILD`, `MAP_TO_MAGS`, `INSTRAIN_PROFILE`, `AGGREGATE_DETECTION`, `INSTRAIN_COMPARE` | reachable only downstream of dRep |
| `MULTIQC` | not installed on this host |
| all container profiles | no container runtime available in this environment |

These 20 process invocations are stub-verified (channel wiring, input/output
contracts) and their commands are taken from the upstream nf-core modules for
the same tools, but they have not been executed against real data here.

### Recommended first run on the cluster

```bash
export NXF_APPTAINER_CACHEDIR=/shared/apptainer_cache

# generate the same test data on the cluster
python3 tests/make_test_data.py --outdir tests/data

# full pipeline, real tools, real databases, 3 simulated samples
nextflow run . -profile test,apptainer,slurm \
    --outdir results_test \
    --checkm_db  /hpc/reference/seq_databases/microbes/CheckM_db \
    --gtdbtk_db  /hpc/reference/seq_databases/microbes/GTDB_Tk_db/release226 \
    -w /scratch/$USER/magspi_work \
    -process.queue <partition> \
    -process.clusterOptions '--account=<account>'
```

Expected from that run, given the simulated input: three MAGs per sample
(one per source genome), three dereplicated MAGs at `-sa 0.97`, GTDB-Tk
assignments of *Mycoplasmoides*, *Chlamydia* and *Tropheryma*, all three MAGs
detected in all three samples in `mag_detection_per_sample.tsv`, and
`16_instrain_compare/` populated with one comparison directory per MAG. Since
each sample carries 40 private SNPs per genome, popANI in the comparison
tables should sit just below 1 rather than at 1 — a useful sanity check that
the strain-comparison stage is discriminating at all.

Then repeat on a handful of real samples before running the full cohort, and
compare `09_checkm/checkm_filtered.tsv` and
`10_mags/combined_DASTool_summary.tsv` against the equivalent tables from the
script version for the same samples. The fixes listed in `CHANGELOG.md`
(notably the CONCOCT bins that the script version never created, the MaxBin2
abundance format, and the singleton reads that were never mapped) mean the two
should **not** be expected to agree exactly: the port should recover at least
as many MAGs, not identical ones.
