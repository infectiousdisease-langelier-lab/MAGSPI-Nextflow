//
// MAGSPI 21 -- concatenate the per-sample MAG summaries.
//
process SUMMARIZE_MAGS {
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    path summaries

    output:
    path "combined_DASTool_summary.tsv", emit: summary
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    combine_tables.py --inputs ${summaries} --out combined_DASTool_summary.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    printf 'MAG_ID\\tsample\\ttool\\tbin_number\\traw_bin\\n' > combined_DASTool_summary.tsv
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
