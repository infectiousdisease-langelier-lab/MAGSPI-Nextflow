//
// MAGSPI 14 -- MaxBin2 binning.
// `-out maxbin2_bins` keeps the `maxbin2_bins.<N>` bin-ID grammar.
//
process MAXBIN2 {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::maxbin2=2.2.7"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/maxbin2:2.2.7--he1b5a44_2' :
        'quay.io/biocontainers/maxbin2:2.2.7--he1b5a44_2' }"

    input:
    tuple val(meta), path(contigs), path(abundance)

    output:
    tuple val(meta), path("maxbin2_bins/maxbin2_bins.[0-9]*.fasta"), emit: bins, optional: true
    tuple val(meta), path("maxbin2_bins/*.summary")               , emit: summary, optional: true
    tuple val(meta), path("maxbin2_bins/*.log")                   , emit: log    , optional: true
    path "versions.yml"                                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p maxbin2_bins

    run_MaxBin.pl \\
        -contig ${contigs} \\
        -abund ${abundance} \\
        -thread ${task.cpus} \\
        -out maxbin2_bins/maxbin2_bins \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        maxbin2: \$(run_MaxBin.pl -version 2>&1 | sed -n 's/^MaxBin //p' | head -n1)
    END_VERSIONS
    """

    stub:
    """
    mkdir -p maxbin2_bins
    printf '>NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > maxbin2_bins/maxbin2_bins.001.fasta
    printf '>NODE_3_length_1600_cov_6.0\\nACGTACGTAC\\n'  > maxbin2_bins/maxbin2_bins.002.fasta
    touch maxbin2_bins/maxbin2_bins.summary maxbin2_bins/maxbin2_bins.log
    echo '"${task.process}": {maxbin2: stub}' > versions.yml
    """
}
