# Containers

## Default: one pinned image per process

Every process in `modules/local/` declares its own container, so a run pulls
only the images it needs and each tool keeps the version it was tested
against. Nothing has to be built — pick an engine profile:

```bash
nextflow run . -profile docker     ...
nextflow run . -profile apptainer  ...   # or singularity
nextflow run . -profile conda      ...   # no containers at all
```

The images are the ones nf-core uses for the same tools, so they are widely
mirrored and frequently already cached on HPC systems. `containers/README.md`
lists them, and shows how to override one process's image.

On HPC, set the cache once so images are pulled a single time:

```bash
export NXF_APPTAINER_CACHEDIR=/shared/apptainer_cache
```

All images are linux/amd64. On Apple silicon add the `arm` profile to run them
under emulation.

## Alternative: a single image containing every tool

`containers/Dockerfile` and `envs/mags_pipeline.yml` build one image with the
whole toolchain. This is useful on an air-gapped cluster, or where policy
allows only a single reviewed image. It is **not** what the default profiles
use, and it carries a real cost.

```bash
./scripts/build_container.sh magspi:0.3.0
./scripts/check_container.sh magspi:0.3.0
nextflow run . -profile docker -process.container magspi:0.3.0 ...
```

`-process.container` overrides the per-process images, because configuration
directives take precedence over the ones declared in a process body.

### The cost, measured

The 16 tools cannot all be installed at the versions the modules pin — the
solver has to move several of them. Resolving the toolchain as one linux-64
conda environment (`micromamba create --dry-run --platform linux-64`) yields:

| Tool | Per-process pin | Forced in a single environment |
|---|---:|---:|
| inStrain | 1.7.1 | **1.3.4** |
| CheckM | 1.2.5 | 1.2.4 |
| MetaBAT2 | 2.17 | 2.18_23_gc869c52 |
| dRep | 3.6.2 | 3.7.1 |
| SPAdes | 4.1.0 | 4.3.0 |
| fastp | 1.3.6 | 1.3.7 |
| SeqKit | 2.13.0 | 2.14.0 |

The inStrain downgrade is the one that matters: it is four minor releases
behind, and the strain-comparison stage is the point of this pipeline. If you
use the single image, say so in your methods and record the versions from
`results/pipeline_info/software_versions.yml`.

`envs/mags_pipeline.yml` is pinned to the versions above — the set that
actually co-installs. The version list committed before this release did not
resolve at all, so that image could not be built.

> Neither the Dockerfile nor the single-image profile has been executed; no
> container runtime was available where this release was prepared. See
> `docs/validation.md` for what has and has not been run.
