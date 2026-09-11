process FASTP {
    tag "${sample}"
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/01_fastp", mode: 'copy'
    input:
    tuple val(sample), path(r1), path(r2)
    output:
    tuple val(sample), path('qc'), emit: qc
    script:
    """
    set -euo pipefail
    mkdir -p qc
    fastp -i ${r1} -I ${r2} -o qc/${sample}_R1.fastq.gz -O qc/${sample}_R2.fastq.gz \\
      --unpaired1 qc/${sample}_unpaired1.fastq.gz --unpaired2 qc/${sample}_unpaired2.fastq.gz \\
      --failed_out qc/${sample}_failedqc.fastq.gz --html qc/${sample}_fastp.html --json qc/${sample}_fastp.json \\
      --detect_adapter_for_pe -e 20 -l 50 -3 -w ${task.cpus}
    """
}
