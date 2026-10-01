//
// MAGSPI 13/14/15 (mapping step) -- map the sample's reads back to its own
// assembly. Done once and shared by all three binners; the original scripts
// each rebuilt the index and remapped.
//
process MAP_TO_ASSEMBLY {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::bowtie2=2.5.4 bioconda::htslib=1.21 bioconda::samtools=1.21 conda-forge::pigz=2.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b4/b41b403e81883126c3227fc45840015538e8e2212f13abc9ae84e4b98891d51c/data' :
        'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6' }"

    input:
    tuple val(meta), path(contigs), path(reads), path(unpaired)

    output:
    tuple val(meta), path("*.sorted.bam"), path("*.sorted.bam.bai"), emit: bam
    tuple val(meta), path("*.bowtie2.log")                         , emit: log
    path "versions.yml"                                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    bowtie2-build --threads ${task.cpus} ${contigs} contigs_index

    UNPAIRED_ARG=""
    if [ -s ${unpaired} ]; then
        NLINES=\$(gzip -cd ${unpaired} 2>/dev/null | wc -l || true)
        if [ "\${NLINES:-0}" -gt 0 ]; then
            UNPAIRED_ARG="-U ${unpaired}"
        fi
    fi

    bowtie2 \\
        -x contigs_index \\
        -1 ${reads[0]} \\
        -2 ${reads[1]} \\
        \$UNPAIRED_ARG \\
        -p ${task.cpus} \\
        ${args} \\
        2> ${prefix}.assembly.bowtie2.log \\
        | samtools view -bS -@ 2 - \\
        | samtools sort -@ 2 -o ${prefix}.sorted.bam -

    samtools index -@ ${task.cpus} ${prefix}.sorted.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$(bowtie2 --version 2>&1 | sed -n '1s/^.*version //p')
        samtools: \$(samtools --version | sed -n '1s/samtools //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.sorted.bam ${prefix}.sorted.bam.bai ${prefix}.assembly.bowtie2.log
    echo '"${task.process}": {bowtie2: stub}' > versions.yml
    """
}
