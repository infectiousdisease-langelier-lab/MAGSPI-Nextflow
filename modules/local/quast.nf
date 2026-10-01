//
// MAGSPI 11 -- assembly QC with QUAST.
//
process QUAST {
    tag "${meta.id}"
    label 'process_low'

    conda "python=3.11 bioconda::quast=5.3.0"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a5/a515d04307ea3e0178af75132105cd36c87d0116c6f9daecf81650b973e870fd/data' :
        'community.wave.seqera.io/library/quast:5.3.0--755a216045b6dbdd' }"

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), path("*_quast")            , emit: results
    tuple val(meta), path("*_quast_report.tsv") , emit: report
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    quast.py \\
        -o ${prefix}_quast \\
        -t ${task.cpus} \\
        ${args} \\
        ${contigs}

    cp ${prefix}_quast/report.tsv ${prefix}_quast_report.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | sed -n 's/^QUAST v//p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_quast
    printf 'Assembly\\t${prefix}_contigs\\n# contigs\\t10\\nTotal length\\t20000\\nN50\\t2500\\n' > ${prefix}_quast/report.tsv
    cp ${prefix}_quast/report.tsv ${prefix}_quast_report.tsv
    echo '"${task.process}": {quast: stub}' > versions.yml
    """
}
