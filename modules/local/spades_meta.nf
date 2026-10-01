//
// MAGSPI 10 -- metaSPAdes assembly.
//
process SPADES_META {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::spades=4.1.0"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7b/7b7b68c7f8471d9111841dbe594c00a41cdd3b713015c838c4b22705cfbbdfb2/data' :
        'community.wave.seqera.io/library/spades:4.1.0--77799c52e1d1054a' }"

    input:
    tuple val(meta), path(reads), path(unpaired)

    output:
    tuple val(meta), path("*_contigs.fasta")     , emit: contigs
    tuple val(meta), path("*_scaffolds.fasta.gz"), emit: scaffolds, optional: true
    tuple val(meta), path("*_assembly_graph.gfa.gz"), emit: graph , optional: true
    tuple val(meta), path("*.spades.log")        , emit: log
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def maxmem = task.memory ? "-m ${task.memory.toGiga() as int}" : ''
    """
    # metaSPAdes refuses an empty single-end library, so only pass it when used
    SPADES_SINGLE=""
    if [ -s ${unpaired} ]; then
        NLINES=\$(gzip -cd ${unpaired} 2>/dev/null | wc -l || true)
        if [ "\${NLINES:-0}" -gt 0 ]; then
            SPADES_SINGLE="-s ${unpaired}"
        fi
    fi

    metaspades.py \\
        --meta \\
        -1 ${reads[0]} \\
        -2 ${reads[1]} \\
        \$SPADES_SINGLE \\
        -o spades \\
        -t ${task.cpus} \\
        ${maxmem} \\
        ${args}

    mv spades/contigs.fasta  ${prefix}_contigs.fasta
    mv spades/spades.log     ${prefix}.spades.log
    if [ -f spades/scaffolds.fasta ]; then
        gzip -cn spades/scaffolds.fasta > ${prefix}_scaffolds.fasta.gz
    fi
    if [ -f spades/assembly_graph_with_scaffolds.gfa ]; then
        gzip -cn spades/assembly_graph_with_scaffolds.gfa > ${prefix}_assembly_graph.gfa.gz
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spades: \$(metaspades.py --version 2>&1 | sed -n 's/^SPAdes genome assembler v//p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '>NODE_1_length_2000_cov_10.0\\n' > ${prefix}_contigs.fasta
    awk 'BEGIN{for(i=0;i<40;i++) printf "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTAC"; print ""}' >> ${prefix}_contigs.fasta
    touch ${prefix}.spades.log
    echo '"${task.process}": {spades: stub}' > versions.yml
    """
}
