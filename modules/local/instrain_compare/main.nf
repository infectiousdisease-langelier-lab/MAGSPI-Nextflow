process INSTRAIN_COMPARE {
    tag 'MAG-comparisons'
    label 'process_very_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/15_instrain/comparisons", mode: 'copy'
    input:
    path profile_dirs
    path reference_dir
    output:
    path 'comparisons', emit: comparisons
    script:
    """
    set -euo pipefail
    mkdir -p profiles comparisons
    for d in ${profile_dirs}; do cp -a "\$d" profiles/; done
    python ${projectDir}/bin/run_instrain_compare.py --profiles_dir profiles --reference_dir ${reference_dir} --outdir comparisons --threads ${task.cpus}
    """
}
