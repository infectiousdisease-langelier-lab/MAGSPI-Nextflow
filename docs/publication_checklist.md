# Publication validation checklist

Before treating MAGSPI as a production/publication release:

- Run the complete pipeline on a representative subset of the original project data.
- Compare QC read counts against the original workflow.
- Compare assembly statistics against the original workflow.
- Compare MetaBAT2, MaxBin2, and CONCOCT bin counts.
- Confirm DAS Tool-selected bins are extracted as expected.
- Compare CheckM completeness and contamination for the selected MAGs.
- Compare GTDB-Tk assignments.
- Confirm dRep representatives and clustering are sensible.
- Validate scaffold-to-MAG mappings after contig renaming.
- Validate inStrain detection against a known sample subset.
- Record the exact MAGSPI version, container digest, database releases, and Nextflow version.
- Run both a local/container test and the target HPC/Apptainer configuration.
