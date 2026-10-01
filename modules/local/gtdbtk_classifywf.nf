//
// MAGSPI 22 -- GTDB-Tk taxonomic classification of the full MAG set.
//
process GTDBTK_CLASSIFYWF {
    tag "${meta.id}"
    label 'process_high_mem'

    conda "bioconda::gtdbtk=2.7.2"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fa/fa734cc7e63b0f7d0c04788ec61de5e6a101a07e966d3dde24384d54a9d75e85/data' :
        'community.wave.seqera.io/library/gtdbtk:2.7.2--64b0fd171db01270' }"

    input:
    tuple val(meta), path(mags, stageAs: 'mags/*')
    path db

    output:
    tuple val(meta), path("gtdbtk_out")                      , emit: results
    tuple val(meta), path("gtdbtk_out/classify/*summary.tsv"), emit: summary, optional: true
    path "versions.yml"                                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def scratch = params.gtdbtk_pplacer_scratch ? "--scratch_dir pplacer_tmp" : ""
    """
    export GTDBTK_DATA_PATH="\$(find -L ${db} -name 'metadata' -type d -exec dirname {} \\; | head -n1)"
    if [ -z "\$GTDBTK_DATA_PATH" ]; then
        export GTDBTK_DATA_PATH="\$(readlink -f ${db})"
    fi
    mkdir -p pplacer_tmp

    gtdbtk classify_wf \\
        --genome_dir mags \\
        --out_dir gtdbtk_out \\
        --extension fa \\
        --prefix ${prefix} \\
        --cpus ${task.cpus} \\
        ${scratch} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gtdbtk: \$(gtdbtk --version 2>&1 | sed -n 's/^gtdbtk: version //p' | cut -d' ' -f1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p gtdbtk_out/classify
    printf 'user_genome\\tclassification\\n' > gtdbtk_out/classify/${prefix}.bac120.summary.tsv
    printf 'sampleA_metabat2_1\\td__Bacteria;p__Firmicutes\\n' >> gtdbtk_out/classify/${prefix}.bac120.summary.tsv
    echo '"${task.process}": {gtdbtk: stub}' > versions.yml
    """
}
