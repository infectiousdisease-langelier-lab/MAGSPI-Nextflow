//
// MAG standardisation, taxonomy, dereplication and reference preparation.
// Ports MAGSPI scripts 20-25, 27-29 and make_stb.py / make_saf.py.
//

include { STANDARDIZE_MAGS    } from '../../modules/local/standardize_mags'
include { SUMMARIZE_MAGS      } from '../../modules/local/summarize_mags'
include { GTDBTK_CLASSIFYWF   } from '../../modules/local/gtdbtk_classifywf'
include { DREP_DEREPLICATE    } from '../../modules/local/drep_dereplicate'
include { RENAME_MAG_CONTIGS  } from '../../modules/local/rename_mag_contigs'
include { MAG_CATALOGUE       } from '../../modules/local/mag_catalogue'

workflow MAG_CURATION {

    take:
    ch_bins      // channel: [ val(meta), [ DAS Tool bin fastas ] ]
    ch_summary   // channel: [ val(meta), DASTool_summary.tsv ]

    main:
    ch_versions = Channel.empty()

    // 20/21 -- rename DAS Tool bins to <sample>_<tool>_<bin>.fa and emit metadata
    STANDARDIZE_MAGS(ch_bins.join(ch_summary))
    ch_versions = ch_versions.mix(STANDARDIZE_MAGS.out.versions.first())

    SUMMARIZE_MAGS(STANDARDIZE_MAGS.out.summary.map { meta, tsv -> tsv }.collect())
    ch_versions = ch_versions.mix(SUMMARIZE_MAGS.out.versions)

    // all MAGs from all samples, as one flat collection
    ch_all_mags = STANDARDIZE_MAGS.out.mags
        .map { meta, mags -> mags }
        .flatten()
        .collect()
        .map { mags -> [ [ id: 'all_mags' ], mags ] }

    // 22 -- GTDB-Tk taxonomy on the full (pre-dereplication) MAG set
    if (!params.skip_gtdbtk) {
        GTDBTK_CLASSIFYWF(ch_all_mags, Channel.fromPath(params.gtdbtk_db, type: 'dir', checkIfExists: true).collect())
        ch_versions = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions)
        ch_taxonomy = GTDBTK_CLASSIFYWF.out.summary
    }
    else {
        ch_taxonomy = Channel.empty()
    }

    // 23 -- dRep dereplication
    if (!params.skip_drep) {
        DREP_DEREPLICATE(ch_all_mags)
        ch_versions = ch_versions.mix(DREP_DEREPLICATE.out.versions)
        ch_for_rename = DREP_DEREPLICATE.out.fastas
    }
    else {
        ch_for_rename = ch_all_mags
    }

    // 24 -- prefix contig headers with the MAG ID
    RENAME_MAG_CONTIGS(ch_for_rename)
    ch_versions = ch_versions.mix(RENAME_MAG_CONTIGS.out.versions)

    // 25/27/28/29 -- catalogue FASTA, .stb, scaffold lists, scaffold->MAG table, SAF
    MAG_CATALOGUE(RENAME_MAG_CONTIGS.out.mags)
    ch_versions = ch_versions.mix(MAG_CATALOGUE.out.versions)

    emit:
    mags            = ch_all_mags
    mag_summary     = SUMMARIZE_MAGS.out.summary
    taxonomy        = ch_taxonomy
    renamed_mags    = RENAME_MAG_CONTIGS.out.mags
    catalogue       = MAG_CATALOGUE.out.catalogue
    stb             = MAG_CATALOGUE.out.stb
    mag_ids         = MAG_CATALOGUE.out.mag_ids
    scaffold_lists  = MAG_CATALOGUE.out.scaffold_lists
    scaffold_to_mag = MAG_CATALOGUE.out.scaffold_to_mag
    saf             = MAG_CATALOGUE.out.saf
    versions        = ch_versions
}
