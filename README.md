# MAGSPI

**MAGSPI** is a modular Nextflow workflow for recovering, evaluating, dereplicating, taxonomically classifying, and profiling metagenome-assembled genomes (MAGs) from paired-end shotgun metagenomic sequencing data.

MAGSPI was refactored from a project-specific collection of SLURM scripts into a portable workflow with:

- Nextflow DSL2 modules
- container-first execution with Docker or Apptainer
- optional Conda fallback
- SLURM/HPC support
- resumable execution with `-resume`
- centralized configuration
- samplesheet-based inputs
- automatic execution reports, traces, and timelines
- optional downstream taxonomy, dereplication, and inStrain analyses

> **Status:** generalized release candidate. Validate the full workflow on a representative dataset before using results for publication.

## Workflow

```text
Paired FASTQ
   |
   v
 fastp ----------------------------- Read QC
   |
   +---- optional host depletion ---- Bowtie2 + SAMtools
   |
   v
 Read repair / normalization -------- BBMap
   |
   +---- SeqKit --------------------- Read statistics
   |
   v
 metaSPAdes ------------------------- Assembly
   |
   +---- QUAST ---------------------- Assembly QC
   |
   v
 Read-to-contig mapping ------------ Bowtie2 + SAMtools
   |
   v
 Shared BAM/depth
   |
   +---------+---------+
   |         |         |
 MetaBAT2 MaxBin2  CONCOCT
   |         |         |
   +---------+---------+
             |
             v
          DAS Tool ------------------ Bin integration
             |
             v
         MAG candidates
             |
             v
           CheckM ------------------ Quality filtering
             |
       +-----+----------+
       |                |
       v                v
    GTDB-Tk             dRep -------- Dereplication
    (optional)            |
                          v
                   MAG reference/index
                          |
                          v
                       inStrain
                          |
               +----------+----------+
               |                     |
               v                     v
        MAG detection          strain comparison
```

A key refactoring is that each sample is mapped back to its own assembly **once**. The resulting BAM/depth information is shared by MetaBAT2, MaxBin2, and CONCOCT rather than recomputed independently.

## Requirements

### Required

- Nextflow 25.10+ recommended
- Docker **or** Apptainer/Singularity
- a Linux environment
- paired-end FASTQ files

### Optional external resources

- host FASTA for host depletion
- CheckM database
- GTDB-Tk database

Large biological databases are deliberately **not** stored in the Git repository or Docker image. They should be installed once on the analysis system and passed to MAGSPI as paths.

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR-ORG/MAGSPI.git
cd MAGSPI
```

Build the MAGSPI container:

```bash
./scripts/build_container.sh
```

Check that the expected command-line tools are present:

```bash
./scripts/check_container.sh
```

For a public release, publish the image to a registry such as GHCR and set `--container_image` to that immutable release tag or digest. The default local image is `magspi:0.2.0`.

## Input samplesheet

MAGSPI accepts a CSV samplesheet with exactly these required columns:

```csv
sample,fastq_1,fastq_2
SAMPLE_001,/data/SAMPLE_001_R1.fastq.gz,/data/SAMPLE_001_R2.fastq.gz
SAMPLE_002,/data/SAMPLE_002_R1.fastq.gz,/data/SAMPLE_002_R2.fastq.gz
```

Relative FASTQ paths are resolved relative to the samplesheet.

Sample IDs must be unique and may contain only letters, numbers, `.`, `_`, and `-`.

## Running MAGSPI

### Local + Docker

```bash
nextflow run . \\
  -profile docker \\
  --input examples/samplesheet.csv \\
  --checkm_db /path/to/checkm_db \\
  --gtdbtk_db /path/to/gtdbtk_db \\
  --host_reference /path/to/host.fa \\
  --outdir results
```

### SLURM + Apptainer

```bash
nextflow run . \\
  -profile slurm,apptainer \\
  --input examples/samplesheet.csv \\
  --checkm_db /path/to/checkm_db \\
  --gtdbtk_db /path/to/gtdbtk_db \\
  --host_reference /path/to/host.fa \\
  --outdir results
```

The biological software itself does not need to be installed on the host when using the container profiles.

### Resume an interrupted run

```bash
nextflow run . <same options> -resume
```

Successful processes are reused from the Nextflow work directory instead of being recomputed.

## Optional stages

Skip host depletion by omitting `--host_reference`.

Skip SeqKit statistics:

```bash
--run_seqkit false
```

Skip QUAST:

```bash
--run_quast false
```

Skip CheckM:

```bash
--run_checkm false
```

Skip GTDB-Tk:

```bash
--run_taxonomy false
```

Skip dereplication:

```bash
--run_dereplication false
```

Enable inStrain profiling:

```bash
--run_instrain true
```

Enable the optional strain-comparison branch:

```bash
--run_instrain true --run_instrain_compare true
```

## Main parameters

| Parameter | Default | Description |
|---|---:|---|
| `input` | required | CSV samplesheet |
| `outdir` | `results` | Output directory |
| `container_image` | `magspi:0.2.0` | Docker/Apptainer image |
| `host_reference` | none | Host FASTA; enables host depletion |
| `checkm_db` | none | CheckM database root |
| `gtdbtk_db` | none | GTDB-Tk database root |
| `run_seqkit` | `true` | Run read statistics |
| `run_quast` | `true` | Run assembly QC |
| `run_checkm` | `true` | Run MAG quality filtering |
| `run_taxonomy` | `true` | Run GTDB-Tk |
| `run_dereplication` | `true` | Run dRep |
| `run_instrain` | `false` | Run inStrain profiling |
| `run_instrain_compare` | `false` | Run inStrain comparisons |
| `completeness` | `50` | Minimum MAG completeness (%) |
| `contamination` | `10` | Maximum MAG contamination (%) |
| `drep_ani` | `0.97` | dRep secondary ANI threshold |
| `metabat_min_contig` | `1500` | Minimum MetaBAT2 contig length |
| `concoct_chunk` | `10000` | CONCOCT cut-up chunk length |
| `assembly_memory_gb` | `128` | Memory passed to metaSPAdes |
| `instrain_breadth` | `0.5` | MAG breadth detection threshold |
| `instrain_coverage` | `1.0` | MAG coverage detection threshold |

Full parameter metadata are also provided in `nextflow_schema.json`.

## Output structure

```text
results/
├── 01_fastp/
├── 02_host_depletion/
├── 02_read_preparation/
├── 03_read_stats/
├── 05_assembly/
├── 06_quast/
├── 07_mapping/
├── 08_binning/
│   ├── metabat2/
│   ├── maxbin2/
│   └── concoct/
├── 09_dastool/
├── 10_mag_candidates/
├── 11_checkm/
├── 12_gtdbtk/
├── 13_drep/
├── 14_reference/
├── 15_instrain/
└── pipeline_info/
    ├── execution_trace.tsv
    ├── execution_report.html
    └── timeline.html
```

## Software environment

The production container is built from `envs/mags_pipeline.yml`, which contains the workflow's pinned bioinformatics tools. The same manifest can be used as a Conda fallback:

```bash
nextflow run . \\
  -profile slurm,conda \\
  --input examples/samplesheet.csv
```

The recommended deployment mode is Docker locally and Apptainer on HPC systems.

## Reference databases

### Host reference

Provide the appropriate host FASTA with:

```bash
--host_reference /path/to/host.fa
```

MAGSPI builds the Bowtie2 index once and reuses it across samples.

### CheckM

Provide the CheckM database root with:

```bash
--checkm_db /path/to/checkm_db
```

The database remains outside the container and is mounted read-only during CheckM execution.

### GTDB-Tk

Provide the GTDB-Tk database root with:

```bash
--gtdbtk_db /path/to/gtdbtk_db
```

The database remains outside the container and is mounted read-only during GTDB-Tk execution.

Record the database/release versions for publication reproducibility.

## Quality filtering and dereplication defaults

The generalized pipeline retains the principal thresholds from the original project workflow:

```text
MAG completeness >= 50%
MAG contamination <= 10%
dRep secondary ANI = 97%
```

All are configurable from the command line.

## Repository structure

```text
main.nf                     # top-level DSL2 workflow
nextflow.config             # execution profiles and resources
nextflow_schema.json        # parameter schema
conf/                       # Docker, Apptainer, SLURM, Conda, and test profiles
modules/local/              # workflow processes
bin/                        # Python helper utilities
envs/mags_pipeline.yml      # single fallback Conda environment
containers/Dockerfile       # production container definition
scripts/                    # container/build and development helpers
examples/                   # example input files
assets/fastq/               # tiny test inputs
legacy/                     # historical project scripts for provenance
docs/                       # methods, databases, validation, and refactor notes
tests/                      # workflow tests
```

## Testing

The repository contains a small test profile that exercises the workflow structure without requiring large biological reference databases:

```bash
nextflow run . -profile test -stub-run
```

Python helper syntax can be checked with:

```bash
make check
```

Container command availability can be checked with:

```bash
./scripts/check_container.sh
```

A full biological end-to-end test with real assembly/binning/database workloads should be run on representative test data before release.

## Error handling and reproducibility

Nextflow manages task scheduling, staging, caching, retries, and resume behavior. MAGSPI is configured to retry likely resource-related failures and terminate immediately on ordinary process errors so that genuine failures are visible rather than silently skipped.

Each execution writes a trace, HTML execution report, and timeline to `results/pipeline_info/`.

## Provenance

The `legacy/original_project_scripts/` directory contains the original scripts from the project from which MAGSPI was generalized. They are retained for provenance and are **not** part of the production execution path.

See `docs/refactor_notes.md` for the major architectural changes and `docs/publication_checklist.md` for validation steps before a publication release.

## Citation

See `CITATIONS.md` for software citations and `docs/methods.md` for a concise methods description.

## License

MIT. See `LICENSE`.
