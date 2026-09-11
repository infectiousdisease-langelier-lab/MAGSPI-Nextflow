# MAGSPI methods summary

MAGSPI is a modular workflow for paired-end shotgun metagenomic MAG recovery and downstream population profiling.

1. Paired-end reads are quality filtered with fastp.
2. When a host reference is supplied, paired and singleton reads are aligned to that reference with Bowtie2; unmapped reads are retained with SAMtools.
3. BBMap repair is used to normalize paired/singleton read files for downstream analysis.
4. Optional SeqKit statistics are generated for the processed reads.
5. Each sample is assembled independently with metaSPAdes.
6. Assemblies can be assessed with QUAST.
7. Each assembly is mapped back to its reads once. The resulting BAM is sorted/indexed and contig depth is calculated once.
8. The shared mapping/depth outputs are reused by MetaBAT2, MaxBin2, and CONCOCT.
9. DAS Tool integrates the three independent binning assignments.
10. DAS Tool-selected candidate MAGs are extracted into sample-specific filenames.
11. CheckM can filter candidate MAGs using configurable completeness and contamination thresholds.
12. Passing MAGs can be classified with GTDB-Tk and dereplicated with dRep.
13. A namespaced dereplicated MAG reference and scaffold-to-MAG mapping can be generated for optional inStrain profiling.
14. MAG-level breadth and coverage can be aggregated across samples, followed by optional inStrain comparisons.

The default MAG quality thresholds are 50% completeness and 10% contamination. The default dRep secondary ANI threshold is 0.97. These defaults reproduce the principal thresholds of the original project workflow while exposing them as user parameters.
