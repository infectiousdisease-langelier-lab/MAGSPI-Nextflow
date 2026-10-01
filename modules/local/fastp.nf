//
// MAGSPI 01 -- read quality control with fastp.
//
process FASTP {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::fastp=1.3.6"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d0/d013aad5427d824afe472e6607ea47685ff0181f1fb09e52a179e0ec39e43e88/data' :
        'community.wave.seqera.io/library/fastp:1.3.6--4df8d6c11b471bde' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_QC_R{1,2}.fastq.gz")     , emit: reads
    tuple val(meta), path("*_unpaired{1,2}.fastq.gz") , emit: unpaired
    tuple val(meta), path("*_failedqc.fastq.gz")      , emit: failed
    tuple val(meta), path("*.fastp.json")             , emit: json
    tuple val(meta), path("*.fastp.html")             , emit: html
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    fastp \\
        -i ${reads[0]} \\
        -I ${reads[1]} \\
        -o ${prefix}_QC_R1.fastq.gz \\
        -O ${prefix}_QC_R2.fastq.gz \\
        --unpaired1 ${prefix}_unpaired1.fastq.gz \\
        --unpaired2 ${prefix}_unpaired2.fastq.gz \\
        --failed_out ${prefix}_failedqc.fastq.gz \\
        -h ${prefix}.fastp.html \\
        -j ${prefix}.fastp.json \\
        -w ${task.cpus} \\
        ${args}

    # fastp omits these files when the corresponding category is empty
    for f in ${prefix}_unpaired1.fastq.gz ${prefix}_unpaired2.fastq.gz ${prefix}_failedqc.fastq.gz; do
        [ -f "\$f" ] || printf '' | gzip > "\$f"
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e 's/fastp //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    for f in ${prefix}_QC_R1.fastq.gz ${prefix}_QC_R2.fastq.gz \\
             ${prefix}_unpaired1.fastq.gz ${prefix}_unpaired2.fastq.gz ${prefix}_failedqc.fastq.gz; do
        printf '' | gzip > "\$f"
    done
    echo '{}' > ${prefix}.fastp.json
    touch ${prefix}.fastp.html
    echo '"${task.process}": {fastp: stub}' > versions.yml
    """
}
