# Usage

## Samplesheet

```csv
sample,fastq_1,fastq_2
p23220_A,/data/raw/p23220_A_R1_combined.fastq.gz,/data/raw/p23220_A_R2_combined.fastq.gz
p23220_B,reads/p23220_B_R1.fastq.gz,reads/p23220_B_R2.fastq.gz
```

* Header must be exactly `sample,fastq_1,fastq_2`.
* Paired-end reads only — both columns are required.
* Relative paths resolve against the directory containing the samplesheet;
  absolute paths and `s3://` / `gs://` / `https://` URIs are used verbatim.
* Sample IDs must match `[A-Za-z0-9][A-Za-z0-9._-]*` and be unique. The run
  fails immediately on a duplicate or malformed ID rather than silently
  overwriting outputs.

## Minimal commands

```bash
# local machine, Docker
nextflow run . -profile docker \
    --input samplesheet.csv --outdir results \
    --host_fasta /ref/hg38.fa \
    --checkm_db /ref/CheckM_db --gtdbtk_db /ref/gtdb/release226

# HPC, Apptainer + SLURM
nextflow run . -profile apptainer,slurm \
    --input samplesheet.csv --outdir results \
    --host_bowtie2_index /ref/bowtie2/hg38 \
    --checkm_db /ref/CheckM_db --gtdbtk_db /ref/gtdb/release226 \
    -process.queue compute -process.clusterOptions '--account=myaccount'
```

## Running on SLURM with Apptainer

1. **Cache the images once**, on a filesystem all compute nodes can read:

   ```bash
   export NXF_APPTAINER_CACHEDIR=/shared/apptainer_cache
   mkdir -p "$NXF_APPTAINER_CACHEDIR"
   ```

   Add that export to your shell profile, or to a `-c` config, so every run
   reuses the same SIF files. Without it each run re-pulls into `work/`.

2. **Point Nextflow's work directory at scratch**, not your home quota:

   ```bash
   nextflow run . -profile apptainer,slurm -w /scratch/$USER/magspi_work ...
   ```

3. **Set the partition and account** with `-process.queue` and
   `-process.clusterOptions`, or write them into a site config:

   ```groovy
   // site.config
   process {
       executor       = 'slurm'
       queue          = 'compute'
       clusterOptions = '--account=react'
   }
   singularity.runOptions = '-B /hpc,/scratch'   // bind any non-default mounts
   ```

   then `nextflow run . -profile apptainer -c site.config ...`.

4. **Bind the database paths** if they live outside your home or the launch
   directory. Apptainer's `autoMounts` handles the work directory; databases
   elsewhere need an explicit bind, e.g.
   `apptainer.runOptions = '-B /hpc/reference'`.

5. **Keep the driver alive.** The `nextflow` process must outlive the jobs it
   submits — run it under `tmux`/`screen`, or submit it as a small long-walltime
   job of its own (1 CPU, 4 GB, the longest walltime any stage needs).

6. **Resume rather than restart.** Add `-resume` after any failure; completed
   tasks are reused from the work directory. This replaces the
   "run script 14, check the output, then run script 15" loop.

## Resources

`conf/base.config` carries the SLURM requests of the original scripts
(metaSPAdes 16 CPU / 128 GB, DAS Tool 32 CPU / 128 GB, CheckM 16 CPU / 64 GB,
dRep and GTDB-Tk 64 CPU / 512 GB, inStrain 32 CPU / 256 GB). Cap them for your
cluster with `--max_cpus`, `--max_memory`, `--max_time`, or override one
process:

```groovy
process {
    withName: SPADES_META { cpus = 32; memory = '256.GB'; time = '48.h' }
}
```

metaSPAdes and dRep retry with 128 → 256 → 500 GB on an out-of-memory exit.

## Stage control

| Flag | Effect |
|---|---|
| `--skip_host_depletion` | assemble the fastp output directly |
| `--skip_quast` | no assembly QC |
| `--skip_maxbin2`, `--skip_concoct` | run DAS Tool on fewer binners |
| `--skip_checkm` | no CheckM (no `--checkm_db` needed) |
| `--skip_gtdbtk` | no taxonomy (no `--gtdbtk_db` needed) |
| `--skip_drep` | profile against the full, non-dereplicated MAG set |
| `--skip_instrain` | stop after MAG curation |
| `--skip_instrain_compare` | profile and call detection, but no strain comparison |
| `--checkm_on metabat2` | evaluate the raw MetaBAT2 bins, as script `18` did |
| `--stop_after <stage>` | `read_prep`, `assembly`, `binners` (binners but not DAS Tool), `binning`, `mags`, `all` |

## Parameters

Run `nextflow run . --help` for the summary; `nextflow config .` prints every
resolved value for the chosen profile. The full set lives in the `params`
block of `nextflow.config`, grouped as: input/output, host depletion, fastp,
assembly, binning, MAG quality, taxonomy, dereplication, strain profiling,
stage control, reporting and resource ceilings.

## Databases

**CheckM** (~1.4 GB):

```bash
mkdir -p /ref/CheckM_db && cd /ref/CheckM_db
curl -O https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz
tar xzf checkm_data_2015_01_16.tar.gz
# then --checkm_db /ref/CheckM_db
```

**GTDB-Tk** (~110 GB for R226): download the release matching the GTDB-Tk
version in the container (2.7.2 → R220/R226 era). Point `--gtdbtk_db` at the
directory that contains `metadata/`; the process locates `GTDBTK_DATA_PATH`
from it. Check the GTDB-Tk release notes for the version/database pairing
before a production run — a mismatch is the most common failure at this step.

## Troubleshooting

* **`no bowtie2 index (*.rev.1.bt2[l]) found`** — `--host_bowtie2_index` must
  be the directory holding the index files, or their path prefix
  (`/ref/bowtie2/hg38` for `hg38.1.bt2`). Pass `--host_fasta` instead to let
  the pipeline build it.
* **metaSPAdes "assembly is empty"** — the sample has too few non-host reads.
  Check `results/04_read_stats/seqkit_bysample.tsv` and drop the sample from
  the samplesheet.
* **MaxBin2 exits with "cannot find marker genes"** — a low-complexity sample
  with no recoverable markers. Rerun with `--skip_maxbin2`, or exclude the
  sample.
* **A container pull fails on a login node** — pull interactively once with
  `apptainer pull` into `NXF_APPTAINER_CACHEDIR`, then rerun.
* **Image architecture errors on Apple silicon** — add the `arm` profile.
