# Changelog

## 0.3.0 — complete Nextflow DSL2 implementation

The SLURM script collection in `src/` is reimplemented as a Nextflow DSL2
pipeline. `docs/port_map.md` has the full script-to-process table and the
detailed defect list; this is the short version.

### Added

* Single-command execution of the whole workflow with `-resume`, replacing
  the "run script N, inspect, run script N+1" loop.
* Pinned containers for every process, with `docker`, `singularity`,
  `apptainer`, `conda`, `mamba` and `micromamba` profiles.
* `slurm` profile; per-process CPU/memory/time taken from the original
  `#SBATCH` requests, capped by `--max_cpus`/`--max_memory`/`--max_time`.
* CSV samplesheet input with validation (duplicate and malformed sample IDs
  fail the run immediately), replacing eight different `basename | sed`
  sample-name derivations.
* Every hard-coded path, threshold and database location is a parameter.
* Stage switches (`--skip_*`, `--stop_after`) and `--checkm_on` to choose
  between the DAS Tool and MetaBAT2 bin sets.
* MultiQC report over fastp, bowtie2 and QUAST output.
* `tests/test_bin_scripts.py` (helper-script unit tests on synthetic
  fixtures), `tests/make_test_data.py` (simulated three-sample
  mini-metagenome) and a `test_stub` profile that exercises every process.
* `mags.saf` is produced as part of the reference build rather than by a
  separate manual script.

### Fixed

* MetaBAT2 ran `jgi_summarize_bam_contig_depths --outputDepth $DEPTH_FILE`
  with `$DEPTH_FILE` never assigned (the variable was named `DEPTH`).
* `&& \ <command>` in the MetaBAT2 and BBMap scripts escaped a space rather
  than a newline, so the following command became an argument.
* Unpaired reads were passed to bowtie2 as a bare positional argument in the
  MetaBAT2 and CONCOCT scripts, where bowtie2 consumes them as the output-SAM
  path: the singletons were never aligned and the alignment stream was written
  over the singleton FASTQ. Now passed with `-U`.
* `12_slurm_combine_quast.sh` was a byte-for-byte copy of
  `09_combine_seqkit_files.sh` and never read QUAST output.
* `07_extract_read_counts.sh` counted reads with
  `zcat f | echo $(( $(wc -l) / 4 ))`, which ignores stdin and reports 0 for
  every sample. Superseded by the seqkit-derived summary.
* The CONCOCT chain stopped after `concoct`, so the per-bin FASTA files and
  `merged_clustering.csv` that later scripts read were never created
  (`merge_cutup_clustering.py` and `extract_fasta_bins.py` were missing).
* MaxBin2 received the full `jgi_summarize_bam_contig_depths` table instead of
  the two-column abundance file `-abund` expects.
* `16_slurm_build_dastool_input.sh` processed only samples matching a
  hard-coded `^p23220` prefix, used `basename`-relative bin directories, and
  globbed MaxBin2 bins at a path the MaxBin2 script never wrote to.
* CheckM was run on the raw MetaBAT2 bins rather than the DAS Tool bin set
  (the old behaviour is available as `--checkm_on metabat2`).
* `19_combine_checkm.sh` selected columns positionally from CheckM's
  human-formatted output and kept only bins matching `bin.`, excluding every
  MaxBin2 and CONCOCT bin. Now parsed by column name from `--tab_table`
  output, with no name filter.
* `25_slurm_index.sh` built one bowtie2 index per dereplicated genome while
  script 26 mapped against a single concatenated `ALLMAGS710.fasta` index that
  no script in the repository created; the concatenation is now a pipeline
  step. Its `--array=1-1331` also re-ran a loop over all genomes in every
  array task.
* Script 26 derived sample names from `*_R1_formeta.fastq.gz` but the files
  written by script 06 are `*_non_host_R1_formeta.fastq.gz`, so `$SAMPLE`
  retained a `_non_host` suffix and the singleton reads were never profiled.
* `29_derived_scaffolds.sh` and `make_stb.py` derived the MAG ID with
  `basename(path).split(".")[0]`, truncating any MAG ID containing a dot.
* Generated SLURM array wrappers ran `eval $COMMAND` without `set -e`, so a
  task whose first `&&`-chained command failed still exited 0 and the next
  stage consumed truncated input. Nextflow fails the task instead.

### Changed

* Reads are mapped to each assembly **once** and the BAM is shared by
  MetaBAT2, MaxBin2 and CONCOCT; the script version built the index and
  remapped three times.
* Host alignment and non-host extraction handle paired and unpaired reads in a
  single task per sample (scripts 02/03 and 04/05 were duplicate pairs that
  disagreed about input directories).
* `inStrain profile` is given the scaffold-to-bin file with `-s`, so inStrain
  reports genome-level results directly in addition to the aggregated
  detection table.
* `30_aggregate_instrain_detection.py` was reimplemented without
  pandas/numpy (identical arithmetic) so it runs in a minimal container.
* The per-MAG `inStrain compare` fan-out comes from `mag_ids.txt` instead of a
  hard-coded array size.
