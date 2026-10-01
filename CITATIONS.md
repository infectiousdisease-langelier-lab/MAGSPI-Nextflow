# Software and database citations

MAGSPI executes the software below. Versions are the ones pinned in
`modules/local/*.nf` — each process declares its own container and conda spec,
so these are the versions a run actually uses unless you override a container.
`results/pipeline_info/software_versions.yml` records what a given run
reported at runtime; cite that, not this table, for a specific analysis.

| Software | Pinned version | Used by |
|---|---:|---|
| fastp | 1.3.6 | `FASTP` |
| Bowtie 2 | 2.5.4 | `BOWTIE2_BUILD`, `BOWTIE2_HOST`, `MAP_TO_ASSEMBLY`, `MAP_TO_MAGS` |
| SAMtools | 1.21 / 1.24 | alignment processes / `SAMTOOLS_NONHOST` |
| BBMap (BBTools) | 39.18 | `BBMAP_REPAIR` |
| SeqKit | 2.13.0 | `SEQKIT_STATS` |
| SPAdes (metaSPAdes) | 4.1.0 | `SPADES_META` |
| QUAST | 5.3.0 | `QUAST` |
| MetaBAT2 | 2.17 | `METABAT2`, `JGI_DEPTH` |
| MaxBin2 | 2.2.7 | `MAXBIN2` |
| CONCOCT | 1.1.0 | `CONCOCT` |
| DAS Tool | 1.1.7 | `DASTOOL`, `CONTIG2BIN` |
| DIAMOND | bundled with DAS Tool | DAS Tool search backend |
| CheckM | 1.2.5 | `CHECKM_LINEAGEWF` |
| GTDB-Tk | 2.7.2 | `GTDBTK_CLASSIFYWF` |
| dRep | 3.6.2 | `DREP_DEREPLICATE` |
| inStrain | 1.7.1 | `INSTRAIN_PROFILE`, `INSTRAIN_COMPARE` |
| MultiQC | 1.35 | `MULTIQC` |
| Python | 3.12 | `bin/` helper scripts |
| Nextflow | record the execution version | workflow manager |

Also record for every publication analysis:

- host reference assembly and version
- CheckM database release
- GTDB-Tk database release (must match the GTDB-Tk version above)
- the MAGSPI git commit or tag
- any container overridden via `-c` or `--`

Formal bibliographic references should be added here before publication
rather than inferred from package names.
