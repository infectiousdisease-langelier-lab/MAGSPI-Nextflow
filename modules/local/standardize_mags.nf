//
// MAGSPI 20/21 -- give every DAS Tool bin a standardised MAG name
// (<sample>_<tool>_<bin>) and emit per-sample MAG metadata.
//
process STANDARDIZE_MAGS {
    tag "${meta.id}"
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    tuple val(meta), path(bins, stageAs: 'dastool_bins/*'), path(summary)

    output:
    tuple val(meta), path("mags/*.fa")       , emit: mags   , optional: true
    tuple val(meta), path("*_mag_summary.tsv"), emit: summary
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    standardize_dastool_mags.py \\
        --sample ${prefix} \\
        --bins-dir dastool_bins \\
        --summary ${summary} \\
        --outdir mags \\
        --out-summary ${prefix}_mag_summary.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p mags
    printf '>NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > mags/${prefix}_metabat2_1.fa
    printf '>NODE_3_length_1600_cov_6.0\\nACGTACGTAC\\n'  > mags/${prefix}_maxbin2_001.fa
    printf 'MAG_ID\\tsample\\ttool\\tbin_number\\traw_bin\\n' > ${prefix}_mag_summary.tsv
    printf '${prefix}_metabat2_1\\t${prefix}\\tmetabat2\\t1\\tbin.1\\n' >> ${prefix}_mag_summary.tsv
    printf '${prefix}_maxbin2_001\\t${prefix}\\tmaxbin2\\t001\\tmaxbin2_bins.001\\n' >> ${prefix}_mag_summary.tsv
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
