# Refactor notes

MAGSPI was generalized from a project-specific collection of numbered shell and Python scripts.

## Major changes

- hard-coded project paths were removed from the production execution path
- numbered SLURM wrappers were replaced by Nextflow DSL2 processes
- samples are supplied through a CSV samplesheet
- host depletion is optional and uses a supplied host reference
- read-to-assembly mapping is performed once per sample and shared by MetaBAT2, MaxBin2, and CONCOCT
- BBMap read repair is represented as an explicit workflow process
- DAS Tool bin integration and extraction are separate processes
- CheckM evaluates the MAG candidates selected by DAS Tool rather than an independent binning directory
- MAG filenames are namespaced by sample/tool/bin so dereplication inputs cannot collide across samples
- software is packaged in one container image; databases remain external
- Docker and Apptainer profiles are provided alongside a Conda fallback
- legacy scripts are retained only for provenance
