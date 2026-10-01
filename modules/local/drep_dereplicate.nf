//
// MAGSPI 23 -- dRep dereplication of the MAG collection.
//
process DREP_DEREPLICATE {
    tag "${meta.id}"
    label 'process_high_mem'

    conda "bioconda::drep=3.6.2 conda-forge::pandas=2.3"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/drep:3.6.2--pyhdfd78af_0' :
        'quay.io/biocontainers/drep:3.6.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(mags, stageAs: 'input_mags/*')

    output:
    tuple val(meta), path("dereplicated_genomes/*"), emit: fastas
    tuple val(meta), path("data_tables/*.csv")     , emit: tables , optional: true
    tuple val(meta), path("drep.log")              , emit: log    , optional: true
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # a path list avoids the shell-glob length limits the original hit with *.fa
    find -L input_mags/ -type f \\( -name '*.fa' -o -name '*.fasta' -o -name '*.fna' \\) > mag_paths.txt

    dRep dereplicate \\
        drep_out \\
        -p ${task.cpus} \\
        -g mag_paths.txt \\
        ${args}

    mkdir -p dereplicated_genomes data_tables
    cp drep_out/dereplicated_genomes/* dereplicated_genomes/
    cp drep_out/data_tables/*.csv data_tables/ 2>/dev/null || true
    cp drep_out/log/logger.log drep.log 2>/dev/null || true

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        drep: \$(dRep 2>&1 | sed -n 's/.*v\\([0-9][0-9.]*\\).*/\\1/p' | head -n1)
    END_VERSIONS
    """

    stub:
    """
    mkdir -p dereplicated_genomes data_tables
    printf '>NODE_1_length_2000_cov_10.0\\nACGTACGTAC\\n' > dereplicated_genomes/sampleA_metabat2_1.fa
    printf '>NODE_3_length_1600_cov_6.0\\nACGTACGTAC\\n'  > dereplicated_genomes/sampleB_maxbin2_001.fa
    printf 'genome,completeness\\n' > data_tables/Widb.csv
    touch drep.log
    echo '"${task.process}": {drep: stub}' > versions.yml
    """
}
