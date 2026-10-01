//
// MAGSPI 24 -- prefix every contig header with its MAG ID.
//
process RENAME_MAG_CONTIGS {
    tag "${meta.id}"
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    tuple val(meta), path(mags, stageAs: 'input_mags/*')

    output:
    tuple val(meta), path("renamed_mags/*"), emit: mags
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    rename_mag_contigs.py --indir input_mags --outdir renamed_mags

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p renamed_mags
    printf '>sampleA_metabat2_1_NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > renamed_mags/sampleA_metabat2_1.fa
    printf '>sampleB_maxbin2_001_NODE_3_length_1600_cov_6.0\\nACGTACGTAC\\n' > renamed_mags/sampleB_maxbin2_001.fa
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
