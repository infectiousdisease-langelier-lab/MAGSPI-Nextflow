//
// MAGSPI 12 -- combine QUAST reports into one assembly x metric table.
// The committed script 12 was a duplicate of the seqkit combiner and never
// read QUAST output; this is a reimplementation.
//
process COMBINE_QUAST {
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    path reports

    output:
    path "quast_summary.tsv", emit: summary
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    combine_quast.py --inputs ${reports} --out quast_summary.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    printf 'assembly\\t# contigs\\tTotal length\\tN50\\n' > quast_summary.tsv
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
