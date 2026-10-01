//
// metaSPAdes assembly and QUAST assembly QC.
// Ports MAGSPI scripts 10-12.
//

include { SPADES_META   } from '../../modules/local/spades_meta'
include { QUAST         } from '../../modules/local/quast'
include { COMBINE_QUAST } from '../../modules/local/combine_quast'

workflow ASSEMBLY {

    take:
    ch_reads     // channel: [ val(meta), [r1, r2], single ]

    main:
    ch_versions = Channel.empty()
    ch_multiqc  = Channel.empty()

    SPADES_META(ch_reads)
    ch_versions = ch_versions.mix(SPADES_META.out.versions.first())

    // metaSPAdes can return an empty assembly for very shallow libraries;
    // drop those samples rather than failing the whole run downstream.
    ch_contigs = SPADES_META.out.contigs
        .filter { meta, contigs -> contigs.size() > 0 }

    if (!params.skip_quast) {
        QUAST(ch_contigs)
        ch_versions = ch_versions.mix(QUAST.out.versions.first())
        ch_multiqc  = ch_multiqc.mix(QUAST.out.report.map { meta, tsv -> tsv })

        COMBINE_QUAST(QUAST.out.report.map { meta, tsv -> tsv }.collect())
        ch_versions = ch_versions.mix(COMBINE_QUAST.out.versions)
        ch_quast    = COMBINE_QUAST.out.summary
    }
    else {
        ch_quast = Channel.empty()
    }

    emit:
    contigs       = ch_contigs
    quast_summary = ch_quast
    multiqc_files = ch_multiqc
    versions      = ch_versions
}
