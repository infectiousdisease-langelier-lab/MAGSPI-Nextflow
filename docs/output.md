# Outputs

All paths are relative to `--outdir`. Directories are numbered in workflow
order, mirroring the staged directories the script version wrote by hand.

| Directory | Contents | From |
|---|---|---|
| `01_fastp/` | `<sample>_QC_R{1,2}.fastq.gz`, `<sample>_unpaired{1,2}.fastq.gz`, `<sample>_failedqc.fastq.gz`, `<sample>.fastp.{html,json}` | script 01 |
| `02_host_depletion/` | bowtie2 alignment logs; `index/` if the host index was built here | 02/03 |
| `03_nonhost/` | `<sample>_non_host_R{1,2}_formeta.fastq.gz`, `<sample>_non_host_unpaired_formeta.fastq.gz` | 04/05/06 |
| `04_read_stats/` | `<sample>_seqkit_stats.tsv`, `seqkit_summary.tsv`, `seqkit_bysample.tsv` | 07/08/09 |
| `05_metaspades/` | `<sample>_contigs.fasta`, `<sample>_scaffolds.fasta.gz`, `<sample>_assembly_graph.gfa.gz`, `<sample>.spades.log` | 10 |
| `06_assembly_stats/` | `<sample>_quast/`, `<sample>_quast_report.tsv`, `quast_summary.tsv` | 11/12 |
| `07_binning/coverage/` | `<sample>_depth.txt`, `<sample>_abundance.txt`, mapping logs | 13/14 |
| `07_binning/metabat2/` | `bins/bin.<N>.fa`, `bins/bin.unbinned.fa` | 13 |
| `07_binning/maxbin2/` | `maxbin2_bins/maxbin2_bins.<N>.fasta`, `.summary`, `.log` | 14 |
| `07_binning/concoct/` | `concoct_bins/<N>.fa`, `<sample>_merged_clustering.csv` | 15 |
| `07_binning/contig2bin/` | `<sample>_<binner>.contig2bin.tsv` | 16 |
| `08_dastool/` | `<sample>_DASTool_bins/`, `<sample>_DASTool_summary.tsv`, `<sample>_DASTool_contig2bin.tsv` | 17 |
| `09_checkm/` | `<sample>_checkm_qa.tsv`, `<sample>_checkm_lineage.tsv`, `checkm_all.tsv`, `checkm_filtered.tsv` | 18/19 |
| `10_mags/` | `mags/<sample>_<tool>_<bin>.fa`, `<sample>_mag_summary.tsv`, `combined_DASTool_summary.tsv` | 20/21 |
| `11_gtdbtk/` | `gtdbtk_out/` including `classify/*.summary.tsv` | 22 |
| `12_drep/` | `dereplicated_genomes/`, `data_tables/*.csv`, `drep.log` | 23 |
| `13_mag_references/` | `renamed_mags/`, `mag_catalogue.fasta`, `contigs2bins.stb`, `mag_ids.txt`, `scaffold_to_mag.tsv`, `mag_scaffold_lists/<MAG>.scaffolds.txt`, `mags.saf`, `bowtie2_index/` | 24/25/27/28/29, `make_stb.py`, `make_saf.py` |
| `14_instrain/profiles/` | `<sample>.IS/` inStrain profile directories | 26 |
| `15_mag_detection/` | `mag_detection_per_sample.tsv`, `mag_detection_per_mag_summary.tsv` | 30 |
| `16_instrain_compare/` | `<MAG>.IS_compare/` per-MAG comparisons | 31 |
| `multiqc/` | `multiqc_report.html` over fastp, bowtie2 and QUAST | new |
| `pipeline_info/` | `software_versions.yml`, execution report/timeline/trace/DAG | new |

## The two tables most runs are about

`15_mag_detection/mag_detection_per_sample.tsv`

| column | meaning |
|---|---|
| `sample` | sample ID from the samplesheet |
| `mag` | dereplicated MAG ID |
| `breadth` | Σ covered bases / Σ scaffold length across the MAG |
| `coverage` | length-weighted mean scaffold coverage (`NA` if inStrain reported none) |
| `detected` | `breadth >= --instrain_breadth_thresh` and `coverage >= --instrain_cov_thresh` |

`15_mag_detection/mag_detection_per_mag_summary.tsv` carries `n_samples`,
`n_detected`, `mean_breadth` and `mean_coverage` per MAG, sorted by detection
count.

`16_instrain_compare/<MAG>.IS_compare/output/*comparisonsTable.tsv` holds the
pairwise popANI/conANI values used for transmission calls.

## MAG naming

MAGs are named `<sample>_<binner>_<bin>` throughout, e.g.
`p23220_A_metabat2_12`, `p23220_A_maxbin2_003`, `p23220_A_concoct_7`. After
`RENAME_MAG_CONTIGS` every contig header is prefixed with its MAG ID, so
scaffold names in the inStrain output map unambiguously back to a MAG — this
is what `contigs2bins.stb` and `scaffold_to_mag.tsv` encode.
