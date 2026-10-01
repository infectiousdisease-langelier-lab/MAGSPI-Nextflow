# MAGSPI methods summary

MAGSPI is a modular Nextflow DSL2 workflow for paired-end shotgun metagenomic
MAG recovery and downstream strain-level population profiling. Samples are
supplied through a CSV samplesheet; every path, threshold and database
location is a parameter.

1. Paired-end reads are quality filtered with **fastp** (adapter detection for
   PE, minimum length 50 bp), which also writes the reads orphaned during QC.
2. When a host reference is supplied, paired and orphaned reads are aligned to
   it with **Bowtie 2**; **SAMtools** retains the unmapped (non-host) fraction
   as FASTQ.
3. **BBMap** `repair.sh` restores pairing after host depletion and folds the
   newly orphaned reads into the existing singleton file.
4. **SeqKit** read statistics are generated per sample and combined into a
   per-sample read-count table.
5. Each sample is assembled independently with **metaSPAdes**.
6. Assemblies are assessed with **QUAST** and the reports combined into one
   assembly × metric table.
7. Reads are mapped back to their own assembly **once** with Bowtie 2; the
   sorted, indexed BAM and the `jgi_summarize_bam_contig_depths` depth table
   are computed once and shared.
8. **MetaBAT2** (minimum contig length 1500 bp), **MaxBin2** and **CONCOCT**
   (10 kb chunks) each bin the assembly from those shared inputs.
9. **DAS Tool** integrates the three independent bin sets using DIAMOND as the
   search backend, over contig-to-bin tables built with DAS Tool's own
   converter.
10. **CheckM** `lineage_wf` + `qa` evaluates the DAS Tool bin set, and results
    are filtered by completeness and contamination.
11. DAS Tool bins are renamed to `<sample>_<binner>_<bin>` and combined into
    one MAG metadata table.
12. The full MAG set is classified with **GTDB-Tk** `classify_wf` and
    dereplicated with **dRep**.
13. Contig headers of the dereplicated MAGs are prefixed with their MAG ID,
    then concatenated into one catalogue FASTA with a scaffold-to-bin (`.stb`)
    mapping, per-MAG scaffold lists, a scaffold→MAG table and a SAF annotation.
14. Reads are mapped to the catalogue and profiled with **inStrain**
    (`--very-sensitive-local` alignment, `.stb` passed to `inStrain profile`).
15. MAG-level breadth and coverage are aggregated into a sample × MAG
    detection table, and **inStrain compare** is run once per MAG, restricted
    to that MAG's scaffolds.

## Default thresholds

MAG quality 50% completeness / 10% contamination; dRep secondary ANI 0.97;
MAG detection at breadth ≥ 0.5 and coverage ≥ 1.0, where breadth is
Σ covered bases / Σ scaffold length and coverage is the length-weighted mean
of scaffold coverage. These reproduce the thresholds of the original script
workflow while exposing them as parameters
(`--min_completeness`, `--max_contamination`, `--drep_ani`,
`--instrain_breadth_thresh`, `--instrain_cov_thresh`).

## Provenance

`docs/port_map.md` maps every original numbered script to its process and
records the behavioural differences; `CHANGELOG.md` summarises them;
`docs/validation.md` states which stages have been executed and which have
not.
