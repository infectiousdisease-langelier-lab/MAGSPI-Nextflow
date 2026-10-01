//
// MAGSPI 06 -- restore read pairing after host depletion and fold the newly
// orphaned reads into the existing singleton file.
//
process BBMAP_REPAIR {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::bbmap=39.18 conda-forge::pigz=2.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5a/5aae5977ff9de3e01ff962dc495bfa23f4304c676446b5fdf2de5c7edfa2dc4e/data' :
        'community.wave.seqera.io/library/bbmap_pigz:07416fe99b090fa9' }"

    input:
    tuple val(meta), path(reads), path(unpaired)

    output:
    tuple val(meta), path("*_non_host_R{1,2}_formeta.fastq.gz"), path("*_non_host_unpaired_formeta.fastq.gz"), emit: reads
    path "versions.yml"                                                                                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def xmx    = task.memory ? "-Xmx${(task.memory.toGiga() * 0.8) as int}g" : ''
    """
    repair.sh \\
        ${xmx} \\
        in1=${reads[0]} \\
        in2=${reads[1]} \\
        out1=${prefix}_non_host_R1_formeta.fastq.gz \\
        out2=${prefix}_non_host_R2_formeta.fastq.gz \\
        outsingle=repaired_singletons.fastq.gz \\
        overwrite=t \\
        ${args}

    # concatenated gzip members are a valid gzip stream
    cat ${unpaired} repaired_singletons.fastq.gz > ${prefix}_non_host_unpaired_formeta.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$(bbversion.sh 2>/dev/null | tail -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    for f in ${prefix}_non_host_R1_formeta.fastq.gz ${prefix}_non_host_R2_formeta.fastq.gz ${prefix}_non_host_unpaired_formeta.fastq.gz; do
        printf '' | gzip > "\$f"
    done
    echo '"${task.process}": {bbmap: stub}' > versions.yml
    """
}
