//
// MAGSPI 09 -- combine per-sample seqkit tables.
//
process COMBINE_SEQKIT {
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'quay.io/biocontainers/python:3.12' }"

    input:
    path stats

    output:
    path "seqkit_summary.tsv" , emit: all
    path "seqkit_bysample.tsv", emit: summary
    path "versions.yml"       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    combine_seqkit.py --inputs ${stats} --out-all seqkit_summary.tsv --out-summary seqkit_bysample.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    printf 'sample\\tfile\\tnum_seqs\\n' > seqkit_summary.tsv
    printf 'sample\\ttotal_reads\\tr1_plus_unpaired_reads\\tr1_only_reads\\n' > seqkit_bysample.tsv
    echo '"${task.process}": {python: stub}' > versions.yml
    """
}
