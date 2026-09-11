process NORMALIZE_READS {
    tag "${sample}"
    label 'process_low'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/02_host_depletion", mode: 'copy'
    input:
    tuple val(sample), path(qc_dir)
    output:
    tuple val(sample), path('reads'), emit: reads
    script:
    """
    set -euo pipefail
    mkdir -p reads
    cp ${qc_dir}/${sample}_R1.fastq.gz reads/${sample}_R1.fastq.gz
    cp ${qc_dir}/${sample}_R2.fastq.gz reads/${sample}_R2.fastq.gz
    zcat ${qc_dir}/${sample}_unpaired1.fastq.gz ${qc_dir}/${sample}_unpaired2.fastq.gz 2>/dev/null | gzip -c > reads/${sample}_unpaired.fastq.gz || true
    """
}
