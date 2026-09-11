nextflow.enable.dsl=2

include { FASTP } from './modules/local/fastp'
include { HOST_INDEX } from './modules/local/host_index'
include { HOST_DEPLETION } from './modules/local/host_depletion'
include { NORMALIZE_READS } from './modules/local/normalize_reads'
include { REPAIR_READS } from './modules/local/repair_reads'
include { SEQKIT_STATS } from './modules/local/seqkit_stats'
include { ASSEMBLE } from './modules/local/assemble'
include { QUAST } from './modules/local/quast'
include { MAP_CONTIGS } from './modules/local/map_contigs'
include { CALC_DEPTH } from './modules/local/calc_depth'
include { METABAT2 } from './modules/local/metabat2'
include { MAXBIN2 } from './modules/local/maxbin2'
include { CONCOCT } from './modules/local/concoct'
include { DASTOOL } from './modules/local/dastool'
include { EXTRACT_DASTOOL_MAGS } from './modules/local/extract_dastool_mags'
include { CHECKM } from './modules/local/checkm'
include { GTDBTK } from './modules/local/gtdbtk'
include { DREP } from './modules/local/drep'
include { PREPARE_REFERENCE } from './modules/local/prepare_reference'
include { REFERENCE_INDEX } from './modules/local/reference_index'
include { INSTRAIN_PROFILE } from './modules/local/instrain_profile'
include { AGGREGATE_DETECTION } from './modules/local/aggregate_detection'
include { INSTRAIN_COMPARE } from './modules/local/instrain_compare'

params.input = null
params.outdir = 'results'
params.host_reference = null
params.checkm_db = null
params.gtdbtk_db = null
params.run_seqkit = true
params.run_quast = true
params.run_checkm = true
params.run_taxonomy = true
params.run_dereplication = true
params.run_instrain = false
params.run_instrain_compare = false
params.completeness = 50.0
params.contamination = 10.0
params.drep_ani = 0.97
params.metabat_min_contig = 1500
params.concoct_chunk = 10000
params.assembly_memory_gb = 128
params.instrain_breadth = 0.5
params.instrain_coverage = 1.0
params.help = false
params.version = false

workflow {
    if (params.help || !params.input) {
        log.info '''
MAGSPI - modular MAG recovery and strain profiling

Required:
  --input <samplesheet.csv>       CSV: sample,fastq_1,fastq_2

Databases/references:
  --host_reference <host.fa>      Optional; enables host depletion
  --checkm_db <directory>         Required when CheckM is enabled
  --gtdbtk_db <directory>         Required when taxonomy is enabled

Examples:
  nextflow run main.nf -profile slurm,conda --input samplesheet.csv \\
      --host_reference host.fa --checkm_db /db/checkm --gtdbtk_db /db/gtdbtk
'''
    } else {

    if (!file(params.input).exists()) error "Samplesheet not found: ${params.input}"
    if (params.run_instrain_compare && !params.run_instrain) error "--run_instrain_compare requires --run_instrain=true"
    if (params.run_instrain && !params.run_dereplication) error "--run_instrain requires --run_dereplication=true"
    if (params.run_taxonomy && !params.gtdbtk_db) error "--gtdbtk_db is required when --run_taxonomy=true"
    if (params.run_checkm && !params.checkm_db) error "--checkm_db is required when --run_checkm=true"

    def sheet_dir = file(params.input).parent
    def resolve_input = { String p -> p.startsWith('/') ? file(p, checkIfExists: true) : file("${sheet_dir}/${p}", checkIfExists: true) }
    def seen = [] as Set
    samples = Channel.fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            def sample = row.sample?.toString()?.trim()
            def r1 = row.fastq_1?.toString()?.trim()
            def r2 = row.fastq_2?.toString()?.trim()
            if (!sample || !r1 || !r2) error "Samplesheet requires sample, fastq_1, fastq_2: ${row}"
            if (!sample.matches('[A-Za-z0-9._-]+')) error "Invalid sample name '${sample}'. Use letters, numbers, '.', '_' or '-'."
            if (seen.contains(sample)) error "Duplicate sample ID in samplesheet: ${sample}"
            seen << sample
            def r1f = resolve_input(r1)
            def r2f = resolve_input(r2)
            tuple(sample, r1f, r2f)
        }

    qc_ch = FASTP(samples)

    if (params.host_reference) {
        if (!file(params.host_reference).exists()) error "Host reference not found: ${params.host_reference}"
        host_idx = HOST_INDEX(file(params.host_reference)).index.first()
        host_reads_ch = HOST_DEPLETION(qc_ch, host_idx)
    } else {
        host_reads_ch = NORMALIZE_READS(qc_ch)
    }

    reads_ch = REPAIR_READS(host_reads_ch)

    if (params.run_seqkit) {
        SEQKIT_STATS(reads_ch)
    }

    // Join channels by sample so independent process inputs cannot become mispaired.
    assembly_ch = ASSEMBLE(reads_ch)
    if (params.run_quast) QUAST(assembly_ch)

    assembly_reads_ch = assembly_ch.join(reads_ch, by: 0)
        .map { sample, assembly_dir, reads_dir -> tuple(sample, assembly_dir, reads_dir) }
    mapping_ch = MAP_CONTIGS(assembly_reads_ch)
    depth_ch = CALC_DEPTH(mapping_ch)

    assembly_depth_ch = assembly_ch.join(depth_ch, by: 0)
        .map { sample, assembly_dir, depth_file -> tuple(sample, assembly_dir, depth_file) }
    assembly_mapping_ch = assembly_ch.join(mapping_ch, by: 0)
        .map { sample, assembly_dir, mapping_dir -> tuple(sample, assembly_dir, mapping_dir) }

    meta_ch = METABAT2(assembly_depth_ch)
    max_ch = MAXBIN2(assembly_depth_ch)
    con_ch = CONCOCT(assembly_mapping_ch)

    bins_ch = meta_ch
        .join(max_ch, by: 0)
        .join(con_ch, by: 0)
        .map { sample, meta_dir, maxbin_dir, concoct_dir -> tuple(sample, meta_dir, maxbin_dir, concoct_dir) }

    dastool_input_ch = bins_ch.join(assembly_ch, by: 0)
        .map { sample, meta_dir, maxbin_dir, concoct_dir, assembly_dir -> tuple(sample, meta_dir, maxbin_dir, concoct_dir, assembly_dir) }
    dastool_ch = DASTOOL(dastool_input_ch)

    extraction_input_ch = dastool_ch.dastool.join(bins_ch, by: 0)
        .map { sample, dastool_dir, meta_dir, maxbin_dir, concoct_dir -> tuple(sample, dastool_dir, meta_dir, maxbin_dir, concoct_dir) }
    candidate_ch = EXTRACT_DASTOOL_MAGS(extraction_input_ch).mags

    if (params.run_checkm) {
        hq_ch = CHECKM(candidate_ch)
            .checkm
            .map { sample, hq_dir, checkm_table -> tuple(sample, hq_dir) }
    } else {
        hq_ch = candidate_ch
    }

    if (params.run_taxonomy) {
        gtdbtk_ch = GTDBTK(hq_ch)
    }

    if (params.run_dereplication) {
        derep_ch = DREP(hq_ch.map { sample, hq_dir -> hq_dir }.collect())
        reference_ch = PREPARE_REFERENCE(derep_ch)
        if (params.run_instrain) {
            index_ch = REFERENCE_INDEX(reference_ch.first())
            // Static reference/index outputs are converted to reusable value channels.
            profile_ch = INSTRAIN_PROFILE(
                reads_ch,
                index_ch.first(),
                reference_ch.first()
            )
            if (params.run_instrain_compare) {
                INSTRAIN_COMPARE(profile_ch.profiles.map { sample, dir -> dir }.collect(), reference_ch.first())
            }
            AGGREGATE_DETECTION(profile_ch.profiles.map { sample, dir -> dir }.collect(), reference_ch.first())
        }
    }
    }
}
