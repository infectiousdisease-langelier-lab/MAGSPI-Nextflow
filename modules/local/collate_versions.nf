//
// Collate the per-process versions.yml fragments into one file.
//
process COLLATE_VERSIONS {
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    path versions

    output:
    path "software_versions.yml", emit: versions

    script:
    """
    collate_versions.py --input ${versions} --out software_versions.yml
    """

    stub:
    """
    echo 'MAGSPI: stub' > software_versions.yml
    """
}
