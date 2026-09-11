process QUAST {
    tag "${sample}"
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/06_quast", mode: 'copy'
    input:
    tuple val(sample), path(assembly_dir)
    output:
    tuple val(sample), path('quast'), emit: quast
    script:
    """
    set -euo pipefail
    quast.py -o quast -t ${task.cpus} ${assembly_dir}/${sample}_assembly/contigs.fasta
    """
}
