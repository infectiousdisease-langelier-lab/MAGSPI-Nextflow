//
// MAGSPI 19 -- combine and filter CheckM results.
// Thresholds: completeness >= params.min_completeness,
//             contamination <= params.max_contamination.
//
process COMBINE_CHECKM {
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    path qa_tables

    output:
    path "checkm_all.tsv"     , emit: all
    path "checkm_filtered.tsv", emit: filtered
    path "versions.yml"       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    combine_checkm.py \\
        --inputs ${qa_tables} \\
        --min-completeness ${params.min_completeness} \\
        --max-contamination ${params.max_contamination} \\
        --out-all checkm_all.tsv \\
        --out-filtered checkm_filtered.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    printf 'sample\\tBin Id\\tCompleteness\\tContamination\\n' > checkm_all.tsv
    printf 'sample\\tBin Id\\tCompleteness\\tContamination\\n' > checkm_filtered.tsv
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
