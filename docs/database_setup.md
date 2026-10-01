# Reference database setup

MAGSPI keeps large reference databases outside the containers: the images stay
small, and you choose the release appropriate for your study. Record the
release identifiers alongside the MAGSPI commit for any published analysis.

## Host reference

Either supply a prebuilt bowtie2 index:

```
--host_bowtie2_index /ref/bowtie2/hg38      # directory, or the index prefix
```

or a FASTA, which the pipeline indexes itself (`BOWTIE2_BUILD_HOST`):

```
--host_fasta /ref/hg38.fa
```

Pass exactly one of the two, or `--skip_host_depletion` to assemble the fastp
output directly. The original scripts used an hg38 index; replace it with the
appropriate host for non-human samples.

## CheckM (~1.4 GB)

```bash
mkdir -p /ref/CheckM_db && cd /ref/CheckM_db
curl -O https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz
tar xzf checkm_data_2015_01_16.tar.gz
```

Then `--checkm_db /ref/CheckM_db`, which the process exports as
`CHECKM_DATA_PATH`. Skip the stage with `--skip_checkm`.

## GTDB-Tk (~110 GB)

Download the GTDB release that matches the GTDB-Tk version pinned in
`modules/local/gtdbtk_classifywf.nf` (2.7.2 — see `CITATIONS.md`). Point
`--gtdbtk_db` at the directory containing `metadata/`; the process derives
`GTDBTK_DATA_PATH` from it. Skip with `--skip_gtdbtk`.

A GTDB-Tk/database version mismatch is the most common failure at this step —
check the GTDB-Tk release notes for the supported pairing before a production
run.

## DAS Tool

No external database. The DIAMOND database DAS Tool needs is built inside its
container during the run.

## Binding the paths into containers

Under `-profile apptainer` / `-profile singularity`, `autoMounts` covers the
Nextflow work directory but not databases elsewhere on the filesystem. Add an
explicit bind in a site config:

```groovy
apptainer.runOptions = '-B /hpc/reference,/scratch'
```

See `docs/usage.md` for the full HPC walkthrough.
