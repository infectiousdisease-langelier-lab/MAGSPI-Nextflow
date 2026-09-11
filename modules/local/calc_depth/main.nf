process CALC_DEPTH {
    tag "${sample}"
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    input:
    tuple val(sample), path(mapping_dir)
    output:
    tuple val(sample), path('depth.txt'), emit: depth
    script:
    """
    set -euo pipefail
    jgi_summarize_bam_contig_depths --outputDepth depth.txt ${mapping_dir}/${sample}.sorted.bam
    """
}
