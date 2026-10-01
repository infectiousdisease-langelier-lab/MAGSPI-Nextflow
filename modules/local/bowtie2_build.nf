//
// MAGSPI 25 -- build a bowtie2 index (used for the host reference and for the
// dereplicated MAG catalogue).
//
process BOWTIE2_BUILD {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::bowtie2=2.5.4 bioconda::htslib=1.21 bioconda::samtools=1.21 conda-forge::pigz=2.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b4/b41b403e81883126c3227fc45840015538e8e2212f13abc9ae84e4b98891d51c/data' :
        'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("bowtie2_index/*"), emit: index
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p bowtie2_index
    bowtie2-build \\
        --threads ${task.cpus} \\
        ${args} \\
        ${fasta} \\
        bowtie2_index/${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$(bowtie2 --version 2>&1 | sed -n '1s/^.*version //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p bowtie2_index
    touch bowtie2_index/${prefix}.{1,2,3,4}.bt2
    touch bowtie2_index/${prefix}.rev.{1,2}.bt2
    echo '"${task.process}": {bowtie2: stub}' > versions.yml
    """
}
