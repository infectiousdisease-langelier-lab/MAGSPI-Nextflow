# Containers

MAGSPI is designed to run from one software container containing the complete command-line toolchain. Large reference databases are mounted separately.

## Build

```bash
./scripts/build_container.sh
```

## Smoke test

```bash
./scripts/check_container.sh
```

## Docker

```bash
docker run --rm -it magspi:0.2.0
```

Run MAGSPI with:

```bash
nextflow run . -profile docker --input examples/samplesheet.csv ...
```

## Apptainer/Singularity

On an HPC system, the same Docker image can be pulled or converted to an Apptainer image. The Nextflow profile enables automatic bind mounts for the Nextflow work directory and explicitly mounts CheckM/GTDB-Tk databases read-only.

```bash
nextflow run . -profile slurm,apptainer --input /path/to/samplesheet.csv ...
```

## Publishing

For a public release, publish versioned images to a registry such as GHCR. Update `params.container_image` or pass `--container_image` to reference the release image.

For maximum reproducibility, record or pin an image digest in the publication configuration.
