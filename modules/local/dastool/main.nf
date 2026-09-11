process DASTOOL {
    tag "${sample}"
    label 'process_very_high'
    conda "${projectDir}/envs/mags_pipeline.yml"
    publishDir "${params.outdir}/09_dastool", mode: 'copy'

    input:
    tuple val(sample), path(meta_dir), path(maxbin_dir), path(concoct_dir), path(assembly_dir)

    output:
    tuple val(sample), path('dastool'), emit: dastool

    script:
    """
    set -euo pipefail
    mkdir -p dastool

    python ${projectDir}/bin/build_dastool_maps.py \\
      --contigs ${assembly_dir}/${sample}_assembly/contigs.fasta \\
      --metabat2 ${meta_dir} \\
      --maxbin2 ${maxbin_dir} \\
      --concoct ${concoct_dir} \\
      --outdir dastool/maps

    DAS_Tool \\
      -i dastool/maps/metabat2.tsv,dastool/maps/maxbin2.tsv,dastool/maps/concoct.tsv \\
      -l metabat2,maxbin2,concoct \\
      -c ${assembly_dir}/${sample}_assembly/contigs.fasta \\
      -o dastool/${sample} \\
      --write_bins \\
      --search_engine=diamond \\
      --threads ${task.cpus}
    """
}
