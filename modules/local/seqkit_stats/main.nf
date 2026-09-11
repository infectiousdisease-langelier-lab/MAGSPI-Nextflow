process SEQKIT_STATS {
    tag "${sample}"
    label 'process_low'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/03_read_stats", mode: 'copy'
    input:
    tuple val(sample), path(reads_dir)
    output:
    tuple val(sample), path('seqkit_stats.tsv'), emit: stats
    script:
    """
    set -euo pipefail
    seqkit stats -T ${reads_dir}/*.fastq.gz > seqkit_stats.tsv
    """
}
