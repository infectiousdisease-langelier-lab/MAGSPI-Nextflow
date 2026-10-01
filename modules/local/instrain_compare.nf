//
// MAGSPI 31 -- inStrain compare, one task per MAG, restricted to that MAG's
// scaffolds. Replaces the fixed `--array=1-710%6` SLURM array.
//
process INSTRAIN_COMPARE {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::instrain=1.7.1 bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/instrain:1.7.1--pyhdfd78af_0' :
        'quay.io/biocontainers/instrain:1.7.1--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(scaffold_list)
    path profiles
    path stb

    output:
    tuple val(meta), path("*.IS_compare")                                      , emit: compare
    tuple val(meta), path("*.IS_compare/output/*comparisonsTable.tsv")         , emit: comparisons, optional: true
    path "versions.yml"                                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [ ! -s ${scaffold_list} ]; then
        echo "Empty scaffold list for ${prefix}; nothing to compare" >&2
        mkdir -p ${prefix}.IS_compare
        echo '"${task.process}": {instrain: skipped}' > versions.yml
        exit 0
    fi

    inStrain compare \\
        -i ${profiles} \\
        -sc ${scaffold_list} \\
        -s ${stb} \\
        -o ${prefix}.IS_compare \\
        -p ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        instrain: \$(inStrain compare --version 2>&1 | sed -n 's/.*inStrain version //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}.IS_compare/output
    printf 'scaffold\\tname1\\tname2\\tpopANI\\tconANI\\tpercent_genome_compared\\n' > ${prefix}.IS_compare/output/${prefix}.IS_compare_comparisonsTable.tsv
    echo '"${task.process}": {instrain: stub}' > versions.yml
    """
}
