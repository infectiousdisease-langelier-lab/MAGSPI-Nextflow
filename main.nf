#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 MAGSPI -- MAG-based Strain Profiling and Identification
 github.com/infectiousdisease-langelier-lab/MAGSPI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

include { BOWTIE2_BUILD as BOWTIE2_BUILD_HOST } from './modules/local/bowtie2_build'
include { MULTIQC                             } from './modules/local/multiqc'
include { COLLATE_VERSIONS                    } from './modules/local/collate_versions'
include { READ_PREP                           } from './subworkflows/local/read_prep'
include { ASSEMBLY                            } from './subworkflows/local/assembly'
include { BINNING                             } from './subworkflows/local/binning'
include { MAG_CURATION                        } from './subworkflows/local/mag_curation'
include { STRAIN_PROFILING                    } from './subworkflows/local/strain_profiling'

/*
 * ------------------------------------------------------------------------------
 *  Help and parameter validation
 * ------------------------------------------------------------------------------
 */

def helpMessage() {
    log.info """
    MAGSPI ${workflow.manifest.version}

    Usage:
      nextflow run . -profile <docker|apptainer|singularity|conda>[,slurm] \\
          --input samplesheet.csv --outdir results \\
          --host_bowtie2_index /ref/hg38_bt2 \\
          --checkm_db /ref/CheckM_db --gtdbtk_db /ref/gtdb/release226

    Required:
      --input                   CSV samplesheet with columns: sample,fastq_1,fastq_2
      --outdir                  Output directory

    Host depletion (one of):
      --host_bowtie2_index      Directory (or path prefix) of a bowtie2 index
      --host_fasta              Host FASTA; the index is built by the pipeline
      --skip_host_depletion     Skip host depletion entirely

    Databases:
      --checkm_db               CHECKM_DATA_PATH (required unless --skip_checkm)
      --gtdbtk_db               GTDBTK_DATA_PATH (required unless --skip_gtdbtk)

    Key thresholds (defaults match the original scripts):
      --metabat2_min_contig     ${params.metabat2_min_contig}
      --min_completeness        ${params.min_completeness}
      --max_contamination       ${params.max_contamination}
      --drep_ani                ${params.drep_ani}
      --instrain_breadth_thresh ${params.instrain_breadth_thresh}
      --instrain_cov_thresh     ${params.instrain_cov_thresh}

    Stage switches:
      --skip_maxbin2 --skip_concoct --skip_checkm --skip_gtdbtk --skip_drep
      --skip_instrain --skip_instrain_compare --skip_quast --skip_multiqc
      --stop_after              read_prep|assembly|binners|binning|mags|all
                                ('binners' stops before DAS Tool integration)

    See docs/usage.md for the full parameter list.
    """.stripIndent()
}

def stageLevels() {
    return [ read_prep: 1, assembly: 2, binners: 3, binning: 4, mags: 5, all: 6 ]
}

def stopLevel() {
    return stageLevels()[params.stop_after] ?: 6
}

def validateParameters() {
    def errors = []

    if (!stageLevels().containsKey(params.stop_after)) {
        errors << "--stop_after must be one of ${stageLevels().keySet().join(', ')} (got '${params.stop_after}')"
    }

    if (!params.input) {
        errors << "--input is required (CSV samplesheet with columns sample,fastq_1,fastq_2)"
    }
    else if (!file(params.input).exists()) {
        errors << "--input samplesheet not found: ${params.input}"
    }

    if (!params.skip_host_depletion && !params.host_bowtie2_index && !params.host_fasta) {
        errors << "Host depletion needs --host_bowtie2_index or --host_fasta (or pass --skip_host_depletion)"
    }
    if (params.host_bowtie2_index && params.host_fasta) {
        errors << "Pass only one of --host_bowtie2_index / --host_fasta"
    }
    if (!params.skip_checkm && !params.checkm_db) {
        errors << "CheckM needs --checkm_db (CHECKM_DATA_PATH) or --skip_checkm"
    }
    if (!params.skip_gtdbtk && !params.gtdbtk_db) {
        errors << "GTDB-Tk needs --gtdbtk_db (GTDBTK_DATA_PATH) or --skip_gtdbtk"
    }
    if (!(params.checkm_on in ['dastool', 'metabat2'])) {
        errors << "--checkm_on must be 'dastool' or 'metabat2' (got '${params.checkm_on}')"
    }
    if (params.skip_maxbin2 && params.skip_concoct) {
        log.warn "Both MaxBin2 and CONCOCT are skipped: DAS Tool will run on MetaBAT2 bins only."
    }
    if (!(params.drep_ani instanceof Number) || params.drep_ani <= 0 || params.drep_ani > 1) {
        errors << "--drep_ani must be a fraction in (0,1]; got '${params.drep_ani}'"
    }

    if (errors) {
        error "Parameter validation failed:\n  - " + errors.join("\n  - ")
    }
}

/*
 * ------------------------------------------------------------------------------
 *  Samplesheet
 * ------------------------------------------------------------------------------
 *  sample,fastq_1,fastq_2
 *  Sample IDs must be unique and filename-safe; they replace the per-script
 *  `basename | sed` sample-name derivation of the original pipeline.
 */

def resolveReadPath(sheetDir, value) {
    // absolute paths and remote URIs are used verbatim; relative paths are
    // resolved against the directory holding the samplesheet
    if (value ==~ /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/.*/ || value.startsWith('/')) {
        return file(value, checkIfExists: true)
    }
    return file(sheetDir.resolve(value).toString(), checkIfExists: true)
}

def parseSamplesheet(samplesheet) {
    def sheetDir = file(samplesheet).parent

    Channel
        .fromPath(samplesheet, checkIfExists: true)
        .splitCsv(header: true, strip: true)
        .map { row ->
            def required = ['sample', 'fastq_1', 'fastq_2']
            def missing  = required.findAll { !row.containsKey(it) }
            if (missing) {
                error "Samplesheet is missing required column(s): ${missing.join(', ')}. " +
                      "Header must be: sample,fastq_1,fastq_2"
            }
            def id = row.sample
            if (!id) {
                error "Samplesheet contains a row with an empty 'sample' value: ${row}"
            }
            if (!(id ==~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/)) {
                error "Sample ID '${id}' is not filename-safe. Use letters, digits, '.', '_' and '-' only."
            }
            if (!row.fastq_1 || !row.fastq_2) {
                error "Sample '${id}': MAGSPI requires paired-end reads; both fastq_1 and fastq_2 must be set."
            }
            def meta = [ id: id, single_end: false ]
            [ meta, [ resolveReadPath(sheetDir, row.fastq_1), resolveReadPath(sheetDir, row.fastq_2) ] ]
        }
}

/*
 * ------------------------------------------------------------------------------
 *  Workflow
 * ------------------------------------------------------------------------------
 */

workflow MAGSPI {

    main:
    ch_versions = Channel.empty()
    ch_multiqc  = Channel.empty()

    ch_reads_in = parseSamplesheet(params.input)

    // fail fast on duplicate sample IDs
    ch_reads_in
        .map { meta, reads -> meta.id }
        .collect()
        .subscribe { ids ->
            def dups = ids.countBy { it }.findAll { k, v -> v > 1 }.keySet()
            if (dups) { error "Duplicate sample ID(s) in samplesheet: ${dups.join(', ')}" }
        }

    //
    // Host bowtie2 index: supplied, or built from --host_fasta
    //
    if (params.skip_host_depletion) {
        ch_host_index = Channel.value([])
    }
    else if (params.host_bowtie2_index) {
        def idx     = file(params.host_bowtie2_index)
        def idxGlob = idx.isDirectory() ? "${params.host_bowtie2_index}/*.bt2*"
                                        : "${params.host_bowtie2_index}*.bt2*"
        ch_host_index = Channel.fromPath(idxGlob, checkIfExists: true).collect()
    }
    else {
        BOWTIE2_BUILD_HOST(
            Channel.fromPath(params.host_fasta, checkIfExists: true).map { [ [id: 'host'], it ] }
        )
        ch_host_index = BOWTIE2_BUILD_HOST.out.index.map { meta, idx -> idx }.collect()
        ch_versions   = ch_versions.mix(BOWTIE2_BUILD_HOST.out.versions)
    }

    //
    // 1-4. Read QC, host depletion, read repair, read statistics
    //
    READ_PREP(ch_reads_in, ch_host_index)
    ch_versions = ch_versions.mix(READ_PREP.out.versions)
    ch_multiqc  = ch_multiqc.mix(READ_PREP.out.multiqc_files)

    //
    // 5-6. Assembly and assembly QC
    //
    if (stopLevel() >= 2) {
        ASSEMBLY(READ_PREP.out.reads)
        ch_versions = ch_versions.mix(ASSEMBLY.out.versions)
        ch_multiqc  = ch_multiqc.mix(ASSEMBLY.out.multiqc_files)
    }

    //
    // 7-9. Binning, bin refinement, MAG quality
    //   stop_after = 'binners' runs the three binners and stops before DAS Tool
    //
    if (stopLevel() >= 3) {
        BINNING(ASSEMBLY.out.contigs, READ_PREP.out.reads, stopLevel() >= 4)
        ch_versions = ch_versions.mix(BINNING.out.versions)
    }

    //
    // 10-13. MAG standardisation, taxonomy, dereplication, reference build
    //
    if (stopLevel() >= 5) {
        MAG_CURATION(BINNING.out.bins, BINNING.out.summary)
        ch_versions = ch_versions.mix(MAG_CURATION.out.versions)
    }

    //
    // 14-16. Strain-level profiling
    //
    if (stopLevel() >= 6 && !params.skip_instrain) {
        STRAIN_PROFILING(
            READ_PREP.out.reads,
            MAG_CURATION.out.catalogue,
            MAG_CURATION.out.stb,
            MAG_CURATION.out.scaffold_to_mag,
            MAG_CURATION.out.scaffold_lists
        )
        ch_versions = ch_versions.mix(STRAIN_PROFILING.out.versions)
    }

    //
    // Reporting
    //
    COLLATE_VERSIONS(ch_versions.unique().collectFile(name: 'collated_versions.yml'))

    if (!params.skip_multiqc) {
        ch_mqc_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true)
                                              : Channel.fromPath("${projectDir}/assets/multiqc_config.yml")
        MULTIQC(ch_multiqc.collect().ifEmpty([]), ch_mqc_config.collect().ifEmpty([]))
    }
}

workflow {
    if (params.help) {
        helpMessage()
        return
    }
    if (params.validate_params) {
        validateParameters()
    }
    log.info """
    -------------------------------------------------
      MAGSPI v${workflow.manifest.version}
      input   : ${params.input}
      outdir  : ${params.outdir}
      profile : ${workflow.profile}
    -------------------------------------------------
    """.stripIndent()

    MAGSPI()
}
