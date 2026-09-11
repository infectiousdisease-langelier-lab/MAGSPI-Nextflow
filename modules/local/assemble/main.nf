process ASSEMBLE {
    tag "${sample}"
    label 'process_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/05_assembly", mode: 'copy'
    input:
    tuple val(sample), path(reads_dir)
    output:
    tuple val(sample), path('assembly'), emit: assembly
    script:
    """
    set -euo pipefail
    mkdir -p assembly
    R1=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_R1.fastq.gz' -print -quit)
    R2=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_R2.fastq.gz' -print -quit)
    UP=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_unpaired.fastq.gz' -print -quit)
    metaspades.py --meta -1 \$R1 -2 \$R2 -s \$UP -o assembly/${sample}_assembly -t ${task.cpus} -m 128
    """
}
