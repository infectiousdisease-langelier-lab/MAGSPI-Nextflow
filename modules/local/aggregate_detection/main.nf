process AGGREGATE_DETECTION {
    tag 'MAG-detection'
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/15_instrain/detection", mode: 'copy'
    input:
    path profile_dirs
    path reference_dir
    output:
    path 'mag_detection_per_sample.tsv'
    path 'mag_detection_per_mag_summary.tsv'
    script:
    """
    set -euo pipefail
    mkdir -p profiles
    for d in ${profile_dirs}; do cp -a "\$d" profiles/; done
    python ${projectDir}/bin/aggregate_instrain_detection.py \\
      --profiles_dir profiles \\
      --scaffold_to_mag ${reference_dir}/scaffold_to_mag.tsv \\
      --breadth_thresh ${params.instrain_breadth} \\
      --cov_thresh ${params.instrain_coverage} \\
      --out_prefix mag_detection
    """
}
