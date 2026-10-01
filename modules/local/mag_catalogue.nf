//
// MAGSPI 25/27/28/29 + make_stb.py + make_saf.py --
// build every reference file the inStrain stage needs from the renamed MAGs.
//
process MAG_CATALOGUE {
    tag "${meta.id}"
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    tuple val(meta), path(mags, stageAs: 'renamed_mags/*')

    output:
    tuple val(meta), path("mag_catalogue.fasta")        , emit: catalogue
    tuple val(meta), path("contigs2bins.stb")           , emit: stb
    tuple val(meta), path("mag_ids.txt")                , emit: mag_ids
    tuple val(meta), path("scaffold_to_mag.tsv")        , emit: scaffold_to_mag
    tuple val(meta), path("mag_scaffold_lists/*")       , emit: scaffold_lists
    tuple val(meta), path("mags.saf")                   , emit: saf
    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    build_mag_references.py \\
        --indir renamed_mags \\
        --catalogue mag_catalogue.fasta \\
        --stb contigs2bins.stb \\
        --mag-ids mag_ids.txt \\
        --scaffold-to-mag scaffold_to_mag.tsv \\
        --scaffold-list-dir mag_scaffold_lists \\
        --saf mags.saf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p mag_scaffold_lists
    printf '>sampleA_metabat2_1_NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > mag_catalogue.fasta
    printf '>sampleB_maxbin2_001_NODE_3_length_1600_cov_6.0\\nACGTACGTAC\\n' >> mag_catalogue.fasta
    printf 'sampleA_metabat2_1_NODE_1_length_2000_cov_10.0\\tsampleA_metabat2_1\\n'  > contigs2bins.stb
    printf 'sampleB_maxbin2_001_NODE_3_length_1600_cov_6.0\\tsampleB_maxbin2_001\\n' >> contigs2bins.stb
    printf 'sampleA_metabat2_1\\nsampleB_maxbin2_001\\n' > mag_ids.txt
    printf 'scaffold\\tmag\\n' > scaffold_to_mag.tsv
    printf 'sampleA_metabat2_1_NODE_1_length_2000_cov_10.0\\tsampleA_metabat2_1\\n'  >> scaffold_to_mag.tsv
    printf 'sampleB_maxbin2_001_NODE_3_length_1600_cov_6.0\\tsampleB_maxbin2_001\\n' >> scaffold_to_mag.tsv
    printf 'sampleA_metabat2_1_NODE_1_length_2000_cov_10.0\\n' > mag_scaffold_lists/sampleA_metabat2_1.scaffolds.txt
    printf 'sampleB_maxbin2_001_NODE_3_length_1600_cov_6.0\\n' > mag_scaffold_lists/sampleB_maxbin2_001.scaffolds.txt
    printf 'GeneID\\tChr\\tStart\\tEnd\\tStrand\\n' > mags.saf
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
