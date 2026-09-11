process INSTRAIN_PROFILE {
    tag "${sample}"
    label 'process_very_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/15_instrain/profiles", mode: 'copy'
    input:
    tuple val(sample), path(reads_dir)
    path index_dir
    path reference_dir
    output:
    tuple val(sample), path("${sample}_IS"), emit: profiles
    script:
    """
    set -euo pipefail
    mkdir -p ${sample}_IS
    R1=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_R1.fastq.gz' -print -quit)
    R2=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_R2.fastq.gz' -print -quit)
    UP=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_unpaired.fastq.gz' -print -quit)
    bowtie2 -x ${index_dir}/mag -1 \$R1 -2 \$R2 --very-sensitive-local -U \$UP -p ${task.cpus} | samtools view -b - | samtools sort -@ ${task.cpus} -o ${sample}.mag.bam
    samtools index ${sample}.mag.bam
    inStrain profile ${sample}.mag.bam ${reference_dir}/mag_reference.fna -o ${sample}_IS --processes ${task.cpus}
    """
}
