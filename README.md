# MAGSPI (Nextflow)

**MAG-based Strain Profiling and Identification** — a Nextflow DSL2
implementation of the MAGSPI workflow for recovering, evaluating,
dereplicating, classifying and strain-profiling metagenome-assembled genomes
(MAGs) from shotgun metagenomic sequencing.

```
raw paired-end FASTQ
   → fastp QC
   → bowtie2/samtools host depletion
   → BBMap read repair
   → seqkit read statistics
   → metaSPAdes assembly  → QUAST
   → MetaBAT2 + MaxBin2 + CONCOCT binning
   → DAS Tool bin refinement
   → CheckM quality assessment
   → MAG standardisation → GTDB-Tk taxonomy
   → dRep dereplication
   → MAG catalogue / .stb / scaffold maps
   → inStrain profile → sample × MAG detection
   → per-MAG inStrain compare
```

This replaces the collection of SLURM scripts in `src/`: one command runs the
whole workflow, every step is containerised, and `-resume` restarts from the
last successful task instead of from a hand-edited stage number.
`docs/port_map.md` maps every original script to its process and lists the
defects fixed along the way.

## Quick start

```bash
# 1. a samplesheet
cat > samplesheet.csv <<'CSV'
sample,fastq_1,fastq_2
p23220_A,/data/p23220_A_R1_combined.fastq.gz,/data/p23220_A_R2_combined.fastq.gz
p23220_B,/data/p23220_B_R1_combined.fastq.gz,/data/p23220_B_R2_combined.fastq.gz
CSV

# 2. run it
nextflow run infectiousdisease-langelier-lab/MAGSPI \
    -profile apptainer,slurm \
    --input samplesheet.csv \
    --outdir results \
    --host_bowtie2_index /ref/bowtie2/hg38 \
    --checkm_db /ref/CheckM_db \
    --gtdbtk_db /ref/GTDB_Tk_db/release226 \
    -process.queue your_partition
```

`--help` prints the parameter summary. See `docs/usage.md` for the full list,
database setup and HPC guidance, and `docs/output.md` for the result layout.

## Inputs

A CSV samplesheet with the header `sample,fastq_1,fastq_2`. One row per
sample; paired-end reads are required. Relative paths are resolved against the
directory holding the samplesheet, so a samplesheet and its FASTQ files can be
moved together. Sample IDs must be unique and restricted to letters, digits,
`.`, `_` and `-`; they are used verbatim in output filenames and MAG IDs, which
removes the per-script `basename | sed` sample-name derivation of the script
version.

## Execution profiles

| Profile | Effect |
|---|---|
| `docker` | run every process in its pinned container |
| `apptainer` / `singularity` | same images, pulled as SIF (set `NXF_APPTAINER_CACHEDIR` to a shared path) |
| `conda` / `mamba` / `micromamba` | build a conda environment per process instead of using containers |
| `slurm` | submit each task as a SLURM job (combine with a container profile) |
| `arm` | add to `docker` on Apple silicon to run the x86-64 images under emulation |
| `test` | three-sample simulated mini-metagenome (see below) |
| `test_stub` | run every process's stub — no tools, containers or databases needed |

Profiles compose: `-profile apptainer,slurm`.

## Databases

| Stage | Parameter | Notes |
|---|---|---|
| CheckM | `--checkm_db` | `CHECKM_DATA_PATH` directory (~1.4 GB). Skip with `--skip_checkm`. |
| GTDB-Tk | `--gtdbtk_db` | `GTDBTK_DATA_PATH` release directory (~110 GB for R226). Skip with `--skip_gtdbtk`. |
| host | `--host_bowtie2_index` or `--host_fasta` | index directory/prefix, or a FASTA the pipeline indexes itself. Skip with `--skip_host_depletion`. |

DAS Tool's DIAMOND database is built inside its container; no external copy is
needed.

## Key parameters

Defaults reproduce the thresholds hard-coded in the original scripts:

| Parameter | Default | Original source |
|---|---|---|
| `--fastp_args` | `-c --detect_adapter_for_pe -e 20 -l 50 -3` | `01_slurm_fastp.sh` |
| `--metabat2_min_contig` | `1500` | `13_slurm_metabat.sh` |
| `--concoct_chunk_size` | `10000` | `15_slurm_concoct.sh` |
| `--dastool_search_engine` | `diamond` | `17_slurm_dastool.sh` |
| `--min_completeness` | `50` | `19_combine_checkm.sh`, `23_slurm_drep.sh` |
| `--max_contamination` | `10` | `19_combine_checkm.sh`, `23_slurm_drep.sh` |
| `--drep_ani` | `0.97` | `23_slurm_drep.sh` (`-sa 0.97`) |
| `--instrain_breadth_thresh` | `0.5` | `30_aggregate_instrain_detection.py` |
| `--instrain_cov_thresh` | `1.0` | `30_aggregate_instrain_detection.py` |

Stage control: `--skip_maxbin2`, `--skip_concoct`, `--skip_checkm`,
`--skip_gtdbtk`, `--skip_drep`, `--skip_instrain`,
`--skip_instrain_compare`, `--skip_quast`, `--skip_multiqc`, and
`--stop_after read_prep|assembly|binners|binning|mags|all`.

## Testing

```bash
# helper-script unit tests (no dependencies)
python3 tests/test_bin_scripts.py

# whole-DAG smoke test: every process runs its stub
nextflow run . -profile test_stub -stub-run --outdir results_stub

# real tools on a simulated three-sample mini-metagenome
python3 tests/make_test_data.py --outdir tests/data
nextflow run . -profile test,docker --outdir results_test
```

`docs/validation.md` records what has been run and verified so far, and what
still needs a first run on an HPC system with the reference databases in place.

## Citing

MAGSPI wraps fastp, Bowtie 2, SAMtools, BBMap, SeqKit, metaSPAdes, QUAST,
MetaBAT2, MaxBin2, CONCOCT, DAS Tool, DIAMOND, CheckM, GTDB-Tk, dRep and
inStrain. Please cite the individual tools alongside this repository;
`results/pipeline_info/software_versions.yml` records the exact versions used
in a run.
