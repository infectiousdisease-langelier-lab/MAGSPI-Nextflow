//
// MAGSPI 17 -- DAS Tool bin integration/refinement.
// The -l binner list is built from whichever binners actually produced bins,
// so --skip_maxbin2 / --skip_concoct work without editing the command.
//
process DASTOOL {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::das_tool=1.1.7"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/das_tool:1.1.7--r44hdfd78af_1' :
        'quay.io/biocontainers/das_tool:1.1.7--r44hdfd78af_1' }"

    input:
    tuple val(meta), val(binners), path(contig2bin), path(contigs)

    output:
    tuple val(meta), path("*_DASTool_bins/*.fa")      , emit: bins      , optional: true
    tuple val(meta), path("*_DASTool_summary.tsv")    , emit: summary    , optional: true
    tuple val(meta), path("*_DASTool_contig2bin.tsv") , emit: contig2bin , optional: true
    tuple val(meta), path("*.log")                    , emit: log        , optional: true
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def bin_list = contig2bin.collect { it.toString() }.join(',')
    def lbl_list = binners.join(',')
    """
    DAS_Tool \\
        -i ${bin_list} \\
        -l ${lbl_list} \\
        -c ${contigs} \\
        -o ${prefix} \\
        -t ${task.cpus} \\
        ${args} \\
        > ${prefix}_dastool.log 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        das_tool: \$(DAS_Tool --version 2>&1 | sed -n 's/^DAS Tool //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_DASTool_bins
    printf '>NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > ${prefix}_DASTool_bins/bin.1.fa
    printf '>NODE_3_length_1600_cov_6.0\\nACGTACGTAC\\n'  > ${prefix}_DASTool_bins/maxbin2_bins.001.fa
    printf '>NODE_4_length_1700_cov_7.0\\nACGTACGTAC\\n'  > ${prefix}_DASTool_bins/2.fa
    printf 'bin\\tbin_set\\tunique_SCGs\\tredundant_SCGs\\tSCG_completeness\\tSCG_redundancy\\tsize\\tcontigs\\tN50\\tbin_score\\n' > ${prefix}_DASTool_summary.tsv
    printf 'bin.1\\tmetabat2\\t50\\t1\\t90.0\\t1.0\\t2000\\t1\\t2000\\t0.9\\n'            >> ${prefix}_DASTool_summary.tsv
    printf 'maxbin2_bins.001\\tmaxbin2\\t40\\t0\\t75.0\\t0.0\\t1600\\t1\\t1600\\t0.8\\n'  >> ${prefix}_DASTool_summary.tsv
    printf '2\\tconcoct\\t30\\t2\\t60.0\\t2.0\\t1700\\t1\\t1700\\t0.6\\n'                 >> ${prefix}_DASTool_summary.tsv
    printf 'NODE_1_length_2000_cov_10.0\\tbin.1\\n' > ${prefix}_DASTool_contig2bin.tsv
    touch ${prefix}_dastool.log
    echo '"${task.process}": {das_tool: stub}' > versions.yml
    """
}
