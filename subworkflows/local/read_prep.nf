//
// Read QC, host depletion, read repair and read statistics.
// Ports MAGSPI scripts 01-09.
//

include { FASTP             } from '../../modules/local/fastp'
include { BOWTIE2_HOST      } from '../../modules/local/bowtie2_host'
include { SAMTOOLS_NONHOST  } from '../../modules/local/samtools_nonhost'
include { BBMAP_REPAIR      } from '../../modules/local/bbmap_repair'
include { SEQKIT_STATS      } from '../../modules/local/seqkit_stats'
include { COMBINE_SEQKIT    } from '../../modules/local/combine_seqkit'

workflow READ_PREP {

    take:
    ch_reads        // channel: [ val(meta), [ fastq_1, fastq_2 ] ]
    ch_host_index   // channel: [ bowtie2 index files ] (value channel)

    main:
    ch_versions = Channel.empty()
    ch_multiqc  = Channel.empty()

    // 01 -- fastp
    FASTP(ch_reads)
    ch_versions = ch_versions.mix(FASTP.out.versions.first())
    ch_multiqc  = ch_multiqc.mix(FASTP.out.json.map { meta, json -> json })

    if (!params.skip_host_depletion) {
        // 02/03 -- align QC'd paired and unpaired reads to the host reference
        BOWTIE2_HOST(FASTP.out.reads.join(FASTP.out.unpaired), ch_host_index)
        ch_versions = ch_versions.mix(BOWTIE2_HOST.out.versions.first())
        ch_multiqc  = ch_multiqc.mix(BOWTIE2_HOST.out.log.map { meta, log -> log }.flatten())

        // 04/05 -- pull the unmapped (non-host) reads back out as FASTQ
        SAMTOOLS_NONHOST(BOWTIE2_HOST.out.bam)
        ch_versions = ch_versions.mix(SAMTOOLS_NONHOST.out.versions.first())
        ch_nonhost  = SAMTOOLS_NONHOST.out.reads
    }
    else {
        // concatenate the two fastp orphan files so the shape matches
        ch_nonhost = FASTP.out.reads
            .join(FASTP.out.unpaired)
            .map { meta, reads, unpaired -> [ meta, reads, unpaired ] }
    }

    // 06 -- repair pairing and fold orphans into one singleton file
    BBMAP_REPAIR(ch_nonhost)
    ch_versions = ch_versions.mix(BBMAP_REPAIR.out.versions.first())

    // 07/08/09 -- read statistics
    SEQKIT_STATS(BBMAP_REPAIR.out.reads)
    ch_versions = ch_versions.mix(SEQKIT_STATS.out.versions.first())

    COMBINE_SEQKIT(SEQKIT_STATS.out.stats.map { meta, tsv -> tsv }.collect())
    ch_versions = ch_versions.mix(COMBINE_SEQKIT.out.versions)

    emit:
    reads         = BBMAP_REPAIR.out.reads       // [ meta, [r1, r2], single ]
    read_stats    = COMBINE_SEQKIT.out.summary
    multiqc_files = ch_multiqc
    versions      = ch_versions
}
