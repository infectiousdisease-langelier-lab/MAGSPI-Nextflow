//
// MAGSPI 13/14 (depth step) -- contig depth table.
// Also emits the 2-column abundance file MaxBin2 expects; the original passed
// MaxBin2 the full jgi table, which it cannot parse.
//
process JGI_DEPTH {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::metabat2=2.17"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metabat2:2.17--hd498684_0' :
        'quay.io/biocontainers/metabat2:2.17--hd498684_0' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*_depth.txt")    , emit: depth
    tuple val(meta), path("*_abundance.txt"), emit: abundance
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    export OMP_NUM_THREADS=${task.cpus}

    jgi_summarize_bam_contig_depths \\
        --outputDepth ${prefix}_depth.txt \\
        ${args} \\
        ${bam}

    # contig <tab> mean coverage, no header -- the format run_MaxBin.pl wants
    awk 'BEGIN{OFS="\\t"} NR>1 {print \$1, \$3}' ${prefix}_depth.txt > ${prefix}_abundance.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: \$(metabat2 --help 2>&1 | sed -n 's/.*version [0-9]*:\\([0-9.]*\\).*/\\1/p' | head -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf 'contigName\\tcontigLen\\ttotalAvgDepth\\t${prefix}.sorted.bam\\t${prefix}.sorted.bam-var\\n' > ${prefix}_depth.txt
    printf 'NODE_1_length_2000_cov_10.0\\t2000\\t10.0\\t10.0\\t1.0\\n' >> ${prefix}_depth.txt
    printf 'NODE_1_length_2000_cov_10.0\\t10.0\\n' > ${prefix}_abundance.txt
    echo '"${task.process}": {metabat2: stub}' > versions.yml
    """
}
