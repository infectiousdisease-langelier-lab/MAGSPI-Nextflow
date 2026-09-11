process METABAT2 {
    tag "${sample}"
    label 'process_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/08_binning/metabat2", mode: 'copy'
    input:
    tuple val(sample), path(assembly_dir), path(depth_file)
    output:
    tuple val(sample), path('metabat2'), emit: bins
    script:
    """
    set -euo pipefail
    mkdir -p metabat2
    metabat2 -i ${assembly_dir}/${sample}_assembly/contigs.fasta -a ${depth_file} -o metabat2/bin -m ${params.metabat_min_contig} --unbinned
    """
}
