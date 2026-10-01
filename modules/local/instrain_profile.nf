//
// MAGSPI 26 (profiling step) -- inStrain profile.
// The scaffold-to-bin file is passed with -s so inStrain also reports
// genome-level results directly.
//
process INSTRAIN_PROFILE {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::instrain=1.7.1 bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/instrain:1.7.1--pyhdfd78af_0' :
        'quay.io/biocontainers/instrain:1.7.1--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(bam), path(bai)
    path catalogue
    path stb

    output:
    tuple val(meta), path("*.IS")                           , emit: profile
    tuple val(meta), path("*.IS/output/*scaffold_info.tsv") , emit: scaffold_info, optional: true
    tuple val(meta), path("*.IS/output/*genome_info.tsv")   , emit: genome_info  , optional: true
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    inStrain profile \\
        ${bam} \\
        ${catalogue} \\
        -o ${prefix}.IS \\
        -p ${task.cpus} \\
        -s ${stb} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        instrain: \$(inStrain profile --version 2>&1 | sed -n 's/.*inStrain version //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}.IS/output
    printf 'scaffold\\tlength\\tbreadth\\tcoverage\\tcovered_bases\\n' > ${prefix}.IS/output/${prefix}.IS_scaffold_info.tsv
    printf 'sampleA_metabat2_1_NODE_1_length_2000_cov_10.0\\t2000\\t0.9\\t12.0\\t1800\\n' >> ${prefix}.IS/output/${prefix}.IS_scaffold_info.tsv
    printf 'sampleB_maxbin2_001_NODE_3_length_1600_cov_6.0\\t1600\\t0.2\\t0.4\\t320\\n'   >> ${prefix}.IS/output/${prefix}.IS_scaffold_info.tsv
    printf 'genome\\tbreadth\\tcoverage\\n' > ${prefix}.IS/output/${prefix}.IS_genome_info.tsv
    echo '"${task.process}": {instrain: stub}' > versions.yml
    """
}
