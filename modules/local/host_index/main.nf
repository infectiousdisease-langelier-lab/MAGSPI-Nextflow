process HOST_INDEX {
    tag 'host-reference'
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    input:
    path host_fasta
    output:
    path 'host_index', emit: index
    script:
    """
    set -euo pipefail
    mkdir -p host_index
    cp ${host_fasta} host_index/host.fa
    bowtie2-build host_index/host.fa host_index/host
    """
}
