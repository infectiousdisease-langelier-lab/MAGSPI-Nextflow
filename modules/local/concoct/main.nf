process CONCOCT {
    tag "${sample}"
    label 'process_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/08_binning/concoct", mode: 'copy'
    input:
    tuple val(sample), path(assembly_dir), path(mapping_dir)
    output:
    tuple val(sample), path('concoct'), emit: bins
    script:
    """
    set -euo pipefail
    mkdir -p concoct/work concoct/fasta_bins
    CONTIGS=${assembly_dir}/${sample}_assembly/contigs.fasta
    cut_up_fasta.py \$CONTIGS -c ${params.concoct_chunk} -o 0 --merge_last -b concoct/work/contigs_10K.bed > concoct/work/contigs_10K.fa
    concoct_coverage_table.py concoct/work/contigs_10K.bed ${mapping_dir}/${sample}.sorted.bam > concoct/work/coverage_table.tsv
    concoct --composition_file concoct/work/contigs_10K.fa --coverage_file concoct/work/coverage_table.tsv -b concoct/work/concoct -t ${task.cpus}
    merge_cut_up_clustering.py concoct/work/concoct_clustering_gt1000.csv > concoct/work/clustering_merged.csv
    extract_fasta_bins.py \$CONTIGS concoct/work/clustering_merged.csv --output_path concoct/fasta_bins
    cp concoct/work/clustering_merged.csv concoct/merged_clustering.csv
    """
}
