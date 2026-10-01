//
// MAGSPI 16 -- convert a binner's FASTA bins into the contig<TAB>bin table
// DAS Tool consumes. Uses DAS Tool's own converter for all three binners,
// replacing the per-binner awk/sed conversions (and the hard-coded sample
// filter) of the original script.
//
process CONTIG2BIN {
    tag "${meta.id}:${binner}"
    label 'process_single'

    conda "bioconda::das_tool=1.1.7"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/das_tool:1.1.7--r44hdfd78af_1' :
        'quay.io/biocontainers/das_tool:1.1.7--r44hdfd78af_1' }"

    input:
    tuple val(meta), val(binner), path(bins, stageAs: 'bins/*')
    val extension

    output:
    tuple val(meta), val(binner), path("*.contig2bin.tsv"), emit: contig2bin
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    Fasta_to_Contig2Bin.sh \\
        -i bins \\
        -e ${extension} \\
        > ${prefix}_${binner}.contig2bin.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        das_tool: \$(DAS_Tool --version 2>&1 | sed -n 's/^DAS Tool //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf 'NODE_1_length_2000_cov_10.0\\tbin.1\\n' > ${prefix}_${binner}.contig2bin.tsv
    echo '"${task.process}": {das_tool: stub}' > versions.yml
    """
}
