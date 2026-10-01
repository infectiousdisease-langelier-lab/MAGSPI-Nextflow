//
// MAGSPI 13 -- MetaBAT2 binning.
// Bins are written as bins/bin.<N>.fa so DAS Tool bin IDs keep the
// `bin.N` grammar the MAG-standardisation step expects.
//
process METABAT2 {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::metabat2=2.17"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metabat2:2.17--hd498684_0' :
        'quay.io/biocontainers/metabat2:2.17--hd498684_0' }"

    input:
    tuple val(meta), path(contigs), path(depth)

    output:
    tuple val(meta), path("bins/bin.[0-9]*.fa"), emit: bins    , optional: true
    tuple val(meta), path("bins/bin.unbinned.fa"), emit: unbinned, optional: true
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p bins

    metabat2 \\
        -i ${contigs} \\
        -a ${depth} \\
        -o bins/bin \\
        -t ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: \$(metabat2 --help 2>&1 | sed -n 's/.*version [0-9]*:\\([0-9.]*\\).*/\\1/p' | head -n1)
    END_VERSIONS
    """

    stub:
    """
    mkdir -p bins
    printf '>NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > bins/bin.1.fa
    printf '>NODE_2_length_1800_cov_8.0\\nACGTACGTAC\\n'  > bins/bin.2.fa
    printf '>NODE_9_length_600_cov_1.0\\nACGTACGTAC\\n'   > bins/bin.unbinned.fa
    echo '"${task.process}": {metabat2: stub}' > versions.yml
    """
}
