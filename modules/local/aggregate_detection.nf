//
// MAGSPI 30 -- aggregate inStrain scaffold-level results into sample x MAG
// detection calls.
//   breadth  = sum(covered bases) / sum(scaffold length)
//   coverage = length-weighted mean scaffold coverage
//
process AGGREGATE_DETECTION {
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    path profiles, stageAs: 'profiles/*'
    path scaffold_to_mag

    output:
    path "mag_detection_per_sample.tsv"     , emit: per_sample
    path "mag_detection_per_mag_summary.tsv", emit: per_mag
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    aggregate_instrain_detection.py \\
        --profiles-dir profiles \\
        --scaffold-to-mag ${scaffold_to_mag} \\
        --breadth-thresh ${params.instrain_breadth_thresh} \\
        --cov-thresh ${params.instrain_cov_thresh} \\
        --out-prefix mag_detection

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    printf 'sample\\tmag\\tbreadth\\tcoverage\\tdetected\\n' > mag_detection_per_sample.tsv
    printf 'mag\\tn_samples\\tn_detected\\tmean_breadth\\tmean_coverage\\n' > mag_detection_per_mag_summary.tsv
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
