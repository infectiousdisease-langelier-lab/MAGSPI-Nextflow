//
// MAGSPI 15 -- CONCOCT binning.
// The original stopped after `concoct`; merge_cutup_clustering.py and
// extract_fasta_bins.py (which produce the per-bin FASTA files every later
// stage reads) are restored here.
//
process CONCOCT {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::concoct=1.1.0 conda-forge::setuptools=70"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/concoct:1.1.0--py39h8907335_8' :
        'quay.io/biocontainers/concoct:1.1.0--py39h8907335_8' }"

    input:
    tuple val(meta), path(contigs), path(bam), path(bai)

    output:
    tuple val(meta), path("concoct_bins/*.fa")    , emit: bins      , optional: true
    tuple val(meta), path("*_merged_clustering.csv"), emit: clustering, optional: true
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p concoct_out concoct_bins

    cut_up_fasta.py \\
        ${contigs} \\
        -c ${params.concoct_chunk_size} \\
        -o ${params.concoct_overlap} \\
        --merge_last \\
        -b contigs_chunks.bed \\
        > contigs_chunks.fa

    concoct_coverage_table.py contigs_chunks.bed ${bam} > coverage_table.tsv

    concoct \\
        --composition_file contigs_chunks.fa \\
        --coverage_file coverage_table.tsv \\
        --threads ${task.cpus} \\
        ${args} \\
        -b concoct_out/

    CLUSTERING=\$(ls concoct_out/clustering_gt*.csv 2>/dev/null | head -n1)
    if [ -z "\$CLUSTERING" ]; then
        echo "ERROR: CONCOCT produced no clustering file" >&2
        exit 1
    fi

    merge_cutup_clustering.py "\$CLUSTERING" > ${prefix}_merged_clustering.csv
    extract_fasta_bins.py ${contigs} ${prefix}_merged_clustering.csv --output_path concoct_bins

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        concoct: \$(concoct --version 2>&1 | sed -n 's/^concoct //p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p concoct_bins
    printf '>NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > concoct_bins/1.fa
    printf '>NODE_4_length_1700_cov_7.0\\nACGTACGTAC\\n'  > concoct_bins/2.fa
    printf 'contig_id,cluster_id\\nNODE_1_length_2000_cov_10.0,1\\n' > ${prefix}_merged_clustering.csv
    echo '"${task.process}": {concoct: stub}' > versions.yml
    """
}
