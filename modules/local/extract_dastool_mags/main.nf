process EXTRACT_DASTOOL_MAGS {
    tag "${sample}"
    label 'process_low'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/10_mag_candidates", mode: 'copy'

    input:
    tuple val(sample), path(dastool_dir), path(meta_dir), path(maxbin_dir), path(concoct_dir)

    output:
    tuple val(sample), path('mags'), emit: mags

    script:
    """
    set -euo pipefail
    python ${projectDir}/bin/extract_dastool_mags.py \\
      --dastool_dir ${dastool_dir} \\
      --metabat2 ${meta_dir} \\
      --maxbin2 ${maxbin_dir} \\
      --concoct ${concoct_dir} \\
      --outdir mags \\
      --sample ${sample}
    """
}
