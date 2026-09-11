# Reference database setup

MAGSPI keeps large biological reference databases outside the container. This avoids making the software image unnecessarily large and allows users to choose the appropriate reference/database release for their study.

## Host reference

Provide a host FASTA file with `--host_reference`. MAGSPI builds the Bowtie2 index automatically during the workflow.

## CheckM

Install a CheckM database appropriate for the CheckM version in `envs/mags_pipeline.yml`. Supply the database root with `--checkm_db`.

The Docker and Apptainer profiles mount the supplied database read-only rather than copying it into each task.

## GTDB-Tk

Install the GTDB-Tk reference package appropriate for the GTDB-Tk version in `envs/mags_pipeline.yml`. Supply the database root with `--gtdbtk_db`.

The Docker and Apptainer profiles mount the supplied database read-only.

For reproducibility, record database release/version identifiers alongside the MAGSPI release used for an analysis.
