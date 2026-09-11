process MAXBIN2 {
    tag "${sample}"
    label 'process_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/08_binning/maxbin2", mode: 'copy'
    input:
    tuple val(sample), path(assembly_dir), path(depth_file)
    output:
    tuple val(sample), path('maxbin2'), emit: bins
    script:
    """
    set -euo pipefail
    mkdir -p maxbin2
    run_MaxBin.pl -contig ${assembly_dir}/${sample}_assembly/contigs.fasta -abund ${depth_file} -out maxbin2/${sample}_maxbin2 -thread ${task.cpus}
    """
}
