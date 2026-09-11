process MAP_CONTIGS {
    tag "${sample}"
    label 'process_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/07_mapping", mode: 'copy'
    input:
    tuple val(sample), path(assembly_dir), path(reads_dir)
    output:
    tuple val(sample), path('mapping'), emit: mapping
    script:
    """
    set -euo pipefail
    mkdir -p mapping
    CONTIGS=${assembly_dir}/${sample}_assembly/contigs.fasta
    R1=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_R1.fastq.gz' -print -quit)
    R2=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_R2.fastq.gz' -print -quit)
    UP=\$(find ${reads_dir} -maxdepth 1 -name '${sample}_unpaired.fastq.gz' -print -quit)
    bowtie2-build \$CONTIGS mapping/contigs
    bowtie2 -x mapping/contigs -1 \$R1 -2 \$R2 --very-sensitive-local -U \$UP -p ${task.cpus} | samtools view -b - | samtools sort -@ ${task.cpus} -o mapping/${sample}.sorted.bam
    samtools index mapping/${sample}.sorted.bam
    """
}
