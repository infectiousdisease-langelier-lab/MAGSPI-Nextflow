# Containers

Every process declares a pinned image; nothing needs to be built here. The
images are the same ones nf-core uses for these tools, so they are widely
mirrored and pre-cached on many HPC systems:

| Process group | Image |
|---|---|
| fastp | `community.wave.seqera.io/library/fastp:1.3.6--4df8d6c11b471bde` |
| bowtie2 + samtools | `community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6` |
| samtools | `community.wave.seqera.io/library/htslib_samtools:1.24--d697cfb9dce007cd` |
| BBMap | `community.wave.seqera.io/library/bbmap_pigz:07416fe99b090fa9` |
| SeqKit | `community.wave.seqera.io/library/seqkit:2.13.0--05c0a96bf9fb2751` |
| SPAdes | `community.wave.seqera.io/library/spades:4.1.0--77799c52e1d1054a` |
| QUAST | `community.wave.seqera.io/library/quast:5.3.0--755a216045b6dbdd` |
| MetaBAT2 | `quay.io/biocontainers/metabat2:2.17--hd498684_0` |
| MaxBin2 | `quay.io/biocontainers/maxbin2:2.2.7--he1b5a44_2` |
| CONCOCT | `quay.io/biocontainers/concoct:1.1.0--py39h8907335_8` |
| DAS Tool | `quay.io/biocontainers/das_tool:1.1.7--r44hdfd78af_1` |
| CheckM | `community.wave.seqera.io/library/checkm-genome:1.2.5--8d1d1a2477a013ce` |
| GTDB-Tk | `community.wave.seqera.io/library/gtdbtk:2.7.2--64b0fd171db01270` |
| dRep | `quay.io/biocontainers/drep:3.6.2--pyhdfd78af_0` |
| inStrain | `quay.io/biocontainers/instrain:1.7.1--pyhdfd78af_0` |
| MultiQC | `community.wave.seqera.io/library/multiqc:1.35--c17fb751507e9dfc` |
| helper scripts | `quay.io/biocontainers/python:3.12` |

Under `-profile singularity` / `-profile apptainer` the equivalent SIF is
pulled instead (the `https://depot.galaxyproject.org/singularity/...` or
`https://community-cr-prod.seqera.io/...` URL in each module).

To pin a different build, override the container for one process:

```groovy
process {
    withName: GTDBTK_CLASSIFYWF {
        container = 'quay.io/biocontainers/gtdbtk:2.4.0--pyhdfd78af_1'
    }
}
```

All images are linux/amd64. On Apple silicon add the `arm` profile to run them
under emulation.
