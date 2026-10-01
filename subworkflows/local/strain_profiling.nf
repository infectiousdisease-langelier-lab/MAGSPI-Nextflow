//
// inStrain profiling, MAG detection and per-MAG strain comparison.
// Ports MAGSPI scripts 26, 30 and 31.
//

include { BOWTIE2_BUILD       } from '../../modules/local/bowtie2_build'
include { MAP_TO_MAGS         } from '../../modules/local/map_to_mags'
include { INSTRAIN_PROFILE    } from '../../modules/local/instrain_profile'
include { AGGREGATE_DETECTION } from '../../modules/local/aggregate_detection'
include { INSTRAIN_COMPARE    } from '../../modules/local/instrain_compare'

workflow STRAIN_PROFILING {

    take:
    ch_reads            // channel: [ val(meta), [r1, r2], single ]
    ch_catalogue        // channel: [ val(meta), catalogue.fasta ]
    ch_stb              // channel: [ val(meta), contigs2bins.stb ]
    ch_scaffold_to_mag  // channel: [ val(meta), scaffold_to_mag.tsv ]
    ch_scaffold_lists   // channel: [ val(meta), [ <MAG>.scaffolds.txt ] ]

    main:
    ch_versions = Channel.empty()

    // 25 -- one bowtie2 index over the whole MAG catalogue
    BOWTIE2_BUILD(ch_catalogue)
    ch_versions = ch_versions.mix(BOWTIE2_BUILD.out.versions)

    ch_index     = BOWTIE2_BUILD.out.index.map { meta, idx -> idx }.collect()
    ch_cat_fasta = ch_catalogue.map { meta, fa -> fa }.collect()
    ch_stb_file  = ch_stb.map { meta, stb -> stb }.collect()

    // 26 -- map reads to the catalogue, then profile
    MAP_TO_MAGS(ch_reads, ch_index)
    ch_versions = ch_versions.mix(MAP_TO_MAGS.out.versions.first())

    INSTRAIN_PROFILE(MAP_TO_MAGS.out.bam, ch_cat_fasta, ch_stb_file)
    ch_versions = ch_versions.mix(INSTRAIN_PROFILE.out.versions.first())

    // 30 -- sample x MAG detection table
    AGGREGATE_DETECTION(
        INSTRAIN_PROFILE.out.profile.map { meta, prof -> prof }.collect(),
        ch_scaffold_to_mag.map { meta, tsv -> tsv }.collect()
    )
    ch_versions = ch_versions.mix(AGGREGATE_DETECTION.out.versions)

    // 31 -- one inStrain compare per MAG, over all profiles
    if (!params.skip_instrain_compare) {
        ch_per_mag = ch_scaffold_lists
            .map { meta, lists -> lists }
            .flatten()
            .map { list -> [ [ id: list.name.replaceAll(/\.scaffolds\.txt$/, '') ], list ] }

        INSTRAIN_COMPARE(
            ch_per_mag,
            INSTRAIN_PROFILE.out.profile.map { meta, prof -> prof }.collect(),
            ch_stb_file
        )
        ch_versions = ch_versions.mix(INSTRAIN_COMPARE.out.versions.first())
        ch_compare  = INSTRAIN_COMPARE.out.compare
    }
    else {
        ch_compare = Channel.empty()
    }

    emit:
    profiles     = INSTRAIN_PROFILE.out.profile
    detection    = AGGREGATE_DETECTION.out.per_sample
    mag_summary  = AGGREGATE_DETECTION.out.per_mag
    comparisons  = ch_compare
    versions     = ch_versions
}
