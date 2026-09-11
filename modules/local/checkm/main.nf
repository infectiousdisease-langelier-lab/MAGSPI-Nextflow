process CHECKM {
    tag "${sample}"
    label 'process_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/11_checkm", mode: 'copy'

    input:
    tuple val(sample), path(mags_dir)

    output:
    tuple val(sample), path("${sample}_hq_mags"), path('checkm.tsv'), emit: checkm

    script:
    if (!params.checkm_db) error 'params.checkm_db is required for CHECKM'
    """
    set -euo pipefail
    mkdir -p checkm ${sample}_hq_mags
    export CHECKM_DATA_PATH="${params.checkm_db}"
    checkm lineage_wf -x fa -t ${task.cpus} --pplacer_threads ${task.cpus} ${mags_dir} checkm
    checkm qa checkm/lineage.ms checkm -o 2 > checkm.tsv
    python ${projectDir}/bin/filter_checkm.py \\
      --checkm checkm.tsv \\
      --bins ${mags_dir} \\
      --outdir ${sample}_hq_mags \\
      --completeness ${params.completeness} \\
      --contamination ${params.contamination}
    """
}
