process DREP {
    tag 'MAG-collection'
    label 'process_very_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/13_drep", mode: 'copy'
    input:
    path mag_dirs
    output:
    path 'drep', emit: derep
    script:
    """
    set -euo pipefail
    mkdir -p input_mags drep
    for d in ${mag_dirs}; do cp \$d/*.fa input_mags/; done
    shopt -s nullglob
    mags=(input_mags/*.fa)
    (( \${#mags[@]} > 0 )) || { echo 'No HQ MAG FASTA files found' >&2; exit 1; }
    dRep dereplicate drep -g input_mags/*.fa -p ${task.cpus} -comp ${params.completeness} -con ${params.contamination} -sa ${params.drep_ani}
    """
}
