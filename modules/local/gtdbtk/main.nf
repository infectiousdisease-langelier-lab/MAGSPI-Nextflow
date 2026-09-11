process GTDBTK {
    tag "${sample}"
    label 'process_very_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/12_gtdbtk", mode: 'copy'

    input:
    tuple val(sample), path(mags_dir)

    output:
    tuple val(sample), path('gtdbtk'), emit: taxonomy

    script:
    if (!params.gtdbtk_db) error 'params.gtdbtk_db is required for GTDB-Tk'
    """
    set -euo pipefail
    mkdir -p gtdbtk
    export GTDBTK_DATA_PATH="${params.gtdbtk_db}"
    gtdbtk classify_wf \\
      --genome_dir ${mags_dir} \\
      --out_dir gtdbtk \\
      --cpus ${task.cpus} \\
      --extension .fa
    """
}
