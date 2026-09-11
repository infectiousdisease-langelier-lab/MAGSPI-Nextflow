process HOST_DEPLETION {
    tag "${sample}"
    label 'process_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/02_host_depletion", mode: 'copy'
    input:
    tuple val(sample), path(qc_dir)
    path host_index
    output:
    tuple val(sample), path('reads'), emit: reads
    script:
    """
    set -euo pipefail
    mkdir -p reads
    R1=\$(find ${qc_dir} -maxdepth 1 -name '${sample}_R1.fastq.gz' -print -quit)
    R2=\$(find ${qc_dir} -maxdepth 1 -name '${sample}_R2.fastq.gz' -print -quit)
    bowtie2 -x ${host_index}/host -1 \$R1 -2 \$R2 -S paired.sam --threads ${task.cpus}
    samtools view -b -f 4 paired.sam | samtools collate -u -O - | samtools fastq -@ ${task.cpus} -f 4 - -1 reads/${sample}_R1.fastq.gz -2 reads/${sample}_R2.fastq.gz -0 /dev/null -s reads/${sample}_paired_singletons.fastq.gz
    rm -f paired.sam paired.unmapped.bam

    UP1=\$(find ${qc_dir} -maxdepth 1 -name '${sample}_unpaired1.fastq.gz' -print -quit)
    UP2=\$(find ${qc_dir} -maxdepth 1 -name '${sample}_unpaired2.fastq.gz' -print -quit)
    gzip -c /dev/null > reads/${sample}_unpaired.fastq.gz
    gzip -cd reads/${sample}_unpaired.fastq.gz > reads/${sample}_unpaired.tmp.fastq
    if [[ -s "\$UP1" ]]; then gzip -cd "\$UP1" >> reads/${sample}_unpaired.tmp.fastq; fi
    if [[ -s "\$UP2" ]]; then gzip -cd "\$UP2" >> reads/${sample}_unpaired.tmp.fastq; fi
    gzip -c reads/${sample}_unpaired.tmp.fastq > reads/${sample}_unpaired_input.fastq.gz
    bowtie2 -x ${host_index}/host -U reads/${sample}_unpaired_input.fastq.gz -S unpaired.sam --threads ${task.cpus}
    samtools view -b -f 4 unpaired.sam | samtools fastq -@ ${task.cpus} - > reads/${sample}_unpaired.nonhost.fastq
    gzip -c reads/${sample}_unpaired.nonhost.fastq > reads/${sample}_unpaired.fastq.gz.tmp
    mv reads/${sample}_unpaired.fastq.gz.tmp reads/${sample}_unpaired.fastq.gz
    rm -f reads/${sample}_unpaired_input.fastq.gz reads/${sample}_unpaired.nonhost.fastq reads/${sample}_unpaired.tmp.fastq unpaired.sam
    if [[ -s reads/${sample}_paired_singletons.fastq.gz ]]; then
        if [[ -s reads/${sample}_unpaired.fastq.gz ]]; then
            zcat reads/${sample}_unpaired.fastq.gz reads/${sample}_paired_singletons.fastq.gz | gzip -c > reads/${sample}_unpaired.merged.gz
            mv reads/${sample}_unpaired.merged.gz reads/${sample}_unpaired.fastq.gz
        else
            mv reads/${sample}_paired_singletons.fastq.gz reads/${sample}_unpaired.fastq.gz
        fi
    fi
    rm -f reads/${sample}_paired_singletons.fastq.gz
    """
}
