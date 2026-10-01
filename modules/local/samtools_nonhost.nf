//
// MAGSPI 04/05 -- extract unmapped (non-host) reads back to FASTQ.
//
process SAMTOOLS_NONHOST {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::htslib=1.24 bioconda::samtools=1.24"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e9/e994bf4eb3731150511a14f5706b7bdfd64df1b6d40898fff334286c027e0859/data' :
        'community.wave.seqera.io/library/htslib_samtools:1.24--d697cfb9dce007cd' }"

    input:
    tuple val(meta), path(bam_paired), path(bam_unpaired)

    output:
    tuple val(meta), path("*_non_host_R{1,2}.fastq.gz"), path("*_non_host_unpaired.fastq.gz"), emit: reads
    path "versions.yml"                                                                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools view -b -f 4 -@ ${task.cpus} ${bam_paired} > non_host_paired.bam
    samtools fastq \\
        -@ ${task.cpus} \\
        -f 4 \\
        -1 ${prefix}_non_host_R1.fastq.gz \\
        -2 ${prefix}_non_host_R2.fastq.gz \\
        -0 /dev/null \\
        -s /dev/null \\
        non_host_paired.bam

    samtools view -b -f 4 -@ ${task.cpus} ${bam_unpaired} > non_host_unpaired.bam
    samtools fastq \\
        -@ ${task.cpus} \\
        -0 ${prefix}_non_host_unpaired.fastq.gz \\
        non_host_unpaired.bam

    for f in ${prefix}_non_host_R1.fastq.gz ${prefix}_non_host_R2.fastq.gz ${prefix}_non_host_unpaired.fastq.gz; do
        [ -f "\$f" ] || printf '' | gzip > "\$f"
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | sed -n '1s/samtools //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    for f in ${prefix}_non_host_R1.fastq.gz ${prefix}_non_host_R2.fastq.gz ${prefix}_non_host_unpaired.fastq.gz; do
        printf '' | gzip > "\$f"
    done
    echo '"${task.process}": {samtools: stub}' > versions.yml
    """
}
