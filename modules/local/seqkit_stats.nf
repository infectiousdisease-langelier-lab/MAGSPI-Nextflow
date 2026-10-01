//
// MAGSPI 07/08 -- per-sample read statistics.
// `seqkit stats -T` is used so the output is machine-readable (the original
// parsed the human-formatted table with thousands separators).
//
process SEQKIT_STATS {
    tag "${meta.id}"
    label 'process_single'

    conda "bioconda::seqkit=2.13.0"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4f/4fe272ab9a519cf418160471a485b5ef50ea3f571a8e4555a826f70a4d8243ae/data' :
        'community.wave.seqera.io/library/seqkit:2.13.0--05c0a96bf9fb2751' }"

    input:
    tuple val(meta), path(reads), path(unpaired)

    output:
    tuple val(meta), path("*_seqkit_stats.tsv"), emit: stats
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqkit stats -T -j ${task.cpus} ${reads[0]} ${reads[1]} ${unpaired} > raw_seqkit.tsv

    awk -v s="${prefix}" 'BEGIN{FS=OFS="\\t"} NR==1{print "sample", \$0; next} {print s, \$0}' \\
        raw_seqkit.tsv > ${prefix}_seqkit_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version | sed 's/seqkit v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf 'sample\\tfile\\tformat\\ttype\\tnum_seqs\\tsum_len\\tmin_len\\tavg_len\\tmax_len\\n' > ${prefix}_seqkit_stats.tsv
    printf '${prefix}\\t${prefix}_R1.fastq.gz\\tFASTQ\\tDNA\\t100\\t15000\\t150\\t150\\t150\\n' >> ${prefix}_seqkit_stats.tsv
    echo '"${task.process}": {seqkit: stub}' > versions.yml
    """
}
