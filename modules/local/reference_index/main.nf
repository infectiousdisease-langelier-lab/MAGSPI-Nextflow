process REFERENCE_INDEX {
    tag 'MAG-reference-index'
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/14_reference", mode: 'copy'
    input:
    path reference_dir
    output:
    path 'mag_index', emit: index
    script:
    """
    set -euo pipefail
    mkdir -p mag_index
    bowtie2-build ${reference_dir}/mag_reference.fna mag_index/mag
    """
}
