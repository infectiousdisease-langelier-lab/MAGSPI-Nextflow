//
// MAGSPI 02/03 -- align QC'd paired and unpaired reads to the host reference.
// Both alignments happen in one task; the original pipeline used two SLURM
// job arrays whose input paths disagreed.
//
process BOWTIE2_HOST {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::bowtie2=2.5.4 bioconda::htslib=1.21 bioconda::samtools=1.21 conda-forge::pigz=2.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b4/b41b403e81883126c3227fc45840015538e8e2212f13abc9ae84e4b98891d51c/data' :
        'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6' }"

    input:
    tuple val(meta), path(reads), path(unpaired)
    path index

    output:
    tuple val(meta), path("*_paired_aligned_sorted.bam"), path("*_unpaired_aligned_sorted.bam"), emit: bam
    tuple val(meta), path("*.bowtie2.log")                                                     , emit: log
    path "versions.yml"                                                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    IDX_FILE=\$(find -L . -name '*.rev.1.bt2' | head -n1)
    IDX_EXT=bt2
    if [ -z "\$IDX_FILE" ]; then
        IDX_FILE=\$(find -L . -name '*.rev.1.bt2l' | head -n1)
        IDX_EXT=bt2l
    fi
    if [ -z "\$IDX_FILE" ]; then
        echo "ERROR: no bowtie2 index (*.rev.1.bt2[l]) found among the staged files" >&2
        exit 1
    fi
    INDEX=\$(echo "\$IDX_FILE" | sed "s/\\.rev\\.1\\.\$IDX_EXT\\\$//")

    # paired reads
    bowtie2 \\
        -x "\$INDEX" \\
        -1 ${reads[0]} \\
        -2 ${reads[1]} \\
        --threads ${task.cpus} \\
        ${args} \\
        2> ${prefix}_host_paired.bowtie2.log \\
        | samtools view -bS -@ 2 - \\
        | samtools sort -@ 2 -o ${prefix}_paired_aligned_sorted.bam -

    # orphaned reads from QC, as one stream
    cat ${unpaired} > ${prefix}_qc_unpaired.fastq.gz

    bowtie2 \\
        -x "\$INDEX" \\
        -U ${prefix}_qc_unpaired.fastq.gz \\
        --threads ${task.cpus} \\
        ${args} \\
        2> ${prefix}_host_unpaired.bowtie2.log \\
        | samtools view -bS -@ 2 - \\
        | samtools sort -@ 2 -o ${prefix}_unpaired_aligned_sorted.bam -

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$(bowtie2 --version 2>&1 | sed -n '1s/^.*version //p')
        samtools: \$(samtools --version | sed -n '1s/samtools //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_paired_aligned_sorted.bam ${prefix}_unpaired_aligned_sorted.bam
    touch ${prefix}_host_paired.bowtie2.log ${prefix}_host_unpaired.bowtie2.log
    echo '"${task.process}": {bowtie2: stub}' > versions.yml
    """
}
