# Local modules

Each subdirectory contains one Nextflow process. Processes use a single shared Conda environment as a fallback; container profiles are the recommended production mode.

Where practical, computationally expensive tasks reuse shared upstream outputs rather than recomputing the same alignment or depth information.
