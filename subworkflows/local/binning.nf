//
// Genome binning (MetaBAT2 / MaxBin2 / CONCOCT), DAS Tool refinement
// and CheckM quality assessment.
// Ports MAGSPI scripts 13-19.
//
// Unlike the script version, reads are mapped to the assembly ONCE and the
// resulting BAM is shared by all three binners.
//

include { MAP_TO_ASSEMBLY                  } from '../../modules/local/map_to_assembly'
include { JGI_DEPTH                        } from '../../modules/local/jgi_depth'
include { METABAT2                         } from '../../modules/local/metabat2'
include { MAXBIN2                          } from '../../modules/local/maxbin2'
include { CONCOCT                          } from '../../modules/local/concoct'
include { CONTIG2BIN as CONTIG2BIN_METABAT2 } from '../../modules/local/contig2bin'
include { CONTIG2BIN as CONTIG2BIN_MAXBIN2  } from '../../modules/local/contig2bin'
include { CONTIG2BIN as CONTIG2BIN_CONCOCT  } from '../../modules/local/contig2bin'
include { DASTOOL                          } from '../../modules/local/dastool'
include { CHECKM_LINEAGEWF                 } from '../../modules/local/checkm_lineagewf'
include { COMBINE_CHECKM                   } from '../../modules/local/combine_checkm'

workflow BINNING {

    take:
    ch_contigs   // channel: [ val(meta), contigs.fasta ]
    ch_reads     // channel: [ val(meta), [r1, r2], single ]
    run_dastool  // boolean: run DAS Tool + CheckM (false stops after the binners)

    main:
    ch_versions = Channel.empty()

    // 13/14/15 (mapping part) -- one bowtie2 index + one alignment per sample
    MAP_TO_ASSEMBLY(ch_contigs.join(ch_reads))
    ch_versions = ch_versions.mix(MAP_TO_ASSEMBLY.out.versions.first())

    // 13/14 (depth part) -- one depth table, plus a 2-column MaxBin2 abundance file
    JGI_DEPTH(MAP_TO_ASSEMBLY.out.bam)
    ch_versions = ch_versions.mix(JGI_DEPTH.out.versions.first())

    // 13 -- MetaBAT2
    METABAT2(ch_contigs.join(JGI_DEPTH.out.depth))
    ch_versions = ch_versions.mix(METABAT2.out.versions.first())
    ch_metabat2 = METABAT2.out.bins.filter { meta, bins -> bins }

    // 14 -- MaxBin2
    if (!params.skip_maxbin2) {
        MAXBIN2(ch_contigs.join(JGI_DEPTH.out.abundance))
        ch_versions = ch_versions.mix(MAXBIN2.out.versions.first())
        ch_maxbin2  = MAXBIN2.out.bins.filter { meta, bins -> bins }
    }
    else {
        ch_maxbin2 = Channel.empty()
    }

    // 15 -- CONCOCT
    if (!params.skip_concoct) {
        CONCOCT(ch_contigs.join(MAP_TO_ASSEMBLY.out.bam))
        ch_versions = ch_versions.mix(CONCOCT.out.versions.first())
        ch_concoct  = CONCOCT.out.bins.filter { meta, bins -> bins }
    }
    else {
        ch_concoct = Channel.empty()
    }

    if (run_dastool) {
        // 16 -- contig-to-bin tables, one per binner
        CONTIG2BIN_METABAT2(ch_metabat2.map { meta, bins -> [ meta, 'metabat2', bins ] }, 'fa')
        ch_versions = ch_versions.mix(CONTIG2BIN_METABAT2.out.versions.first())

        CONTIG2BIN_MAXBIN2(ch_maxbin2.map { meta, bins -> [ meta, 'maxbin2', bins ] }, 'fasta')
        CONTIG2BIN_CONCOCT(ch_concoct.map { meta, bins -> [ meta, 'concoct', bins ] }, 'fa')

        // collect them in a deterministic binner order
        ch_c2b = CONTIG2BIN_METABAT2.out.contig2bin
            .mix(CONTIG2BIN_MAXBIN2.out.contig2bin, CONTIG2BIN_CONCOCT.out.contig2bin)
            .map { meta, binner, tsv -> [ meta, binner, tsv ] }
            .groupTuple(by: 0)
            .map { meta, binners, tsvs ->
                def rank  = [ metabat2: 0, maxbin2: 1, concoct: 2 ]
                def pairs = [ binners, tsvs ].transpose().sort { a, b -> rank[a[0]] <=> rank[b[0]] }
                [ meta, pairs.collect { it[0] }, pairs.collect { it[1] } ]
            }

        // 17 -- DAS Tool
        DASTOOL(ch_c2b.join(ch_contigs))
        ch_versions   = ch_versions.mix(DASTOOL.out.versions.first())
        ch_bins       = DASTOOL.out.bins
        ch_summary    = DASTOOL.out.summary
        ch_contig2bin = DASTOOL.out.contig2bin

        // 18/19 -- CheckM
        if (!params.skip_checkm) {
            ch_checkm_in = params.checkm_on == 'metabat2' ? ch_metabat2
                                                          : DASTOOL.out.bins.filter { meta, bins -> bins }
            CHECKM_LINEAGEWF(ch_checkm_in, Channel.fromPath(params.checkm_db, type: 'dir', checkIfExists: true).collect())
            ch_versions = ch_versions.mix(CHECKM_LINEAGEWF.out.versions.first())

            COMBINE_CHECKM(CHECKM_LINEAGEWF.out.qa.map { meta, tsv -> tsv }.collect())
            ch_versions   = ch_versions.mix(COMBINE_CHECKM.out.versions)
            ch_checkm_all = COMBINE_CHECKM.out.all
            ch_checkm_hq  = COMBINE_CHECKM.out.filtered
        }
        else {
            ch_checkm_all = Channel.empty()
            ch_checkm_hq  = Channel.empty()
        }
    }
    else {
        ch_bins       = Channel.empty()
        ch_summary    = Channel.empty()
        ch_contig2bin = Channel.empty()
        ch_checkm_all = Channel.empty()
        ch_checkm_hq  = Channel.empty()
    }

    emit:
    metabat2_bins = ch_metabat2
    maxbin2_bins  = ch_maxbin2
    concoct_bins  = ch_concoct
    bins        = ch_bins
    summary     = ch_summary
    contig2bin  = ch_contig2bin
    checkm      = ch_checkm_all
    checkm_hq   = ch_checkm_hq
    versions    = ch_versions
}
