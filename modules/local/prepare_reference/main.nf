process PREPARE_REFERENCE {
    tag 'MAG-reference'
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/14_reference", mode: 'copy'
    input:
    path drep_dir
    output:
    path 'reference', emit: reference
    script:
    """
    set -euo pipefail
    mkdir -p reference
    python ${projectDir}/bin/prepare_mag_reference.py --derep_dir ${drep_dir} --outdir reference
    """
}
