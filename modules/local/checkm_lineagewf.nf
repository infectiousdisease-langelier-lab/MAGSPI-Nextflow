//
// MAGSPI 18 -- CheckM quality assessment.
// Runs on the DAS Tool bin set by default (params.checkm_on); the original
// script evaluated the raw MetaBAT2 bins instead.
//
process CHECKM_LINEAGEWF {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::checkm-genome=1.2.5"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6e/6e77f70239b60110da040c4307b8048749ed1fc86262e07d27f1eb12a314d14f/data' :
        'community.wave.seqera.io/library/checkm-genome:1.2.5--8d1d1a2477a013ce' }"

    input:
    tuple val(meta), path(bins, stageAs: 'input_bins/*')
    path db

    output:
    tuple val(meta), path("*_checkm_qa.tsv")      , emit: qa
    tuple val(meta), path("*_checkm_lineage.tsv") , emit: lineage
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    export CHECKM_DATA_PATH="\$(readlink -f ${db})"

    checkm lineage_wf \\
        -t ${task.cpus} \\
        --pplacer_threads ${task.cpus} \\
        -x fa \\
        --tab_table \\
        -f ${prefix}_checkm_lineage.tsv \\
        ${args} \\
        input_bins/ \\
        checkm_out

    checkm qa \\
        --threads ${task.cpus} \\
        -o 2 \\
        --tab_table \\
        -f checkm_qa_raw.tsv \\
        checkm_out/lineage.ms \\
        checkm_out

    awk -v s="${prefix}" 'BEGIN{FS=OFS="\\t"} NR==1{print "sample", \$0; next} NF>1{print s, \$0}' \\
        checkm_qa_raw.tsv > ${prefix}_checkm_qa.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        checkm: \$(checkm 2>&1 | sed -n 's/.*CheckM v\\([0-9.]*\\).*/\\1/p' | head -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf 'sample\\tBin Id\\tMarker lineage\\t# genomes\\t# markers\\t# marker sets\\tCompleteness\\tContamination\\tStrain heterogeneity\\n' > ${prefix}_checkm_qa.tsv
    printf '${prefix}\\tbin.1\\tk__Bacteria\\t5656\\t56\\t24\\t92.50\\t1.20\\t0.00\\n'            >> ${prefix}_checkm_qa.tsv
    printf '${prefix}\\tmaxbin2_bins.001\\tk__Bacteria\\t5656\\t56\\t24\\t74.00\\t3.40\\t0.00\\n' >> ${prefix}_checkm_qa.tsv
    printf '${prefix}\\t2\\tk__Bacteria\\t5656\\t56\\t24\\t31.00\\t12.00\\t0.00\\n'               >> ${prefix}_checkm_qa.tsv
    printf 'Bin Id\\tCompleteness\\tContamination\\n' > ${prefix}_checkm_lineage.tsv
    echo '"${task.process}": {checkm: stub}' > versions.yml
    """
}
