process REPAIR_READS {
    tag "${sample}"
    label 'process_medium'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/02_read_preparation", mode: 'copy'

    input:
    tuple val(sample), path(reads_dir)

    output:
    tuple val(sample), path('reads'), emit: reads

    script:
    """
    set -euo pipefail
    mkdir -p reads

    R1="${reads_dir}/${sample}_R1.fastq.gz"
    R2="${reads_dir}/${sample}_R2.fastq.gz"
    UNPAIRED="${reads_dir}/${sample}_unpaired.fastq.gz"

    test -s "\$R1"
    test -s "\$R2"

    repair.sh \\
        in1="\$R1" \\
        in2="\$R2" \\
        out1="reads/${sample}_R1.fastq.gz" \\
        out2="reads/${sample}_R2.fastq.gz" \\
        outsingle="reads/${sample}_repair_singletons.fastq.gz" \\
        overwrite=t \\
        threads=${task.cpus}

    if [[ -s "\$UNPAIRED" && -s "reads/${sample}_repair_singletons.fastq.gz" ]]; then
        zcat "\$UNPAIRED" "reads/${sample}_repair_singletons.fastq.gz" | gzip -c > "reads/${sample}_unpaired.fastq.gz"
    elif [[ -s "\$UNPAIRED" ]]; then
        cp "\$UNPAIRED" "reads/${sample}_unpaired.fastq.gz"
    elif [[ -s "reads/${sample}_repair_singletons.fastq.gz" ]]; then
        cp "reads/${sample}_repair_singletons.fastq.gz" "reads/${sample}_unpaired.fastq.gz"
    else
        gzip -c /dev/null > "reads/${sample}_unpaired.fastq.gz"
    fi

    rm -f "reads/${sample}_repair_singletons.fastq.gz"
    """
}
