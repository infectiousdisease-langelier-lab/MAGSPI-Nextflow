# MAGSPI script → Nextflow port map

Source: `infectiousdisease-langelier-lab/MAGSPI` @ `src/` (33 files: `01`–`31`
plus `make_saf.py` and `make_stb.py`).
Target: `magspi` Nextflow DSL2 pipeline (this repository).

Every original script is accounted for below. "Process" names are the Nextflow
process identifiers; "Module" is the file under `modules/local/`.

## 1. Read QC and host depletion

| Original | Process | Module | Notes |
|---|---|---|---|
| `01_slurm_fastp.sh` | `FASTP` | `fastp.nf` | Same args (`-c --detect_adapter_for_pe -e 20 -l 50 -3`), now `params.fastp_args`. Sample identity comes from the samplesheet instead of `sed`-stripping `_R1_combined.fastq.gz`. |
| `02_slurm_host_align.sh` | `BOWTIE2_HOST` | `bowtie2_host.nf` | Paired **and** unpaired alignment in one task per sample; emits two sorted BAMs plus the bowtie2 logs for MultiQC. |
| `03_slurm_host_align_unpaired.sh` | `BOWTIE2_HOST` | `bowtie2_host.nf` | Folded into the above — script 03 was the unpaired half of 02 re-run because 02 looked for `*_unpaired{1,2}.fastq.gz` in the wrong directory (its `INPUT_DIR` was the fastp *output* dir for R1/R2 but the `UP1`/`UP2` paths were built from `OUTPUT_DIR`). |
| `04_slurm_host_extract.sh` | `SAMTOOLS_NONHOST` | `samtools_nonhost.nf` | `samtools view -b -f 4` → `samtools fastq`, paired and singleton in one task. |
| `05_slurm_host_extract_unpaired.sh` | `SAMTOOLS_NONHOST` | `samtools_nonhost.nf` | Folded into the above (same reason as 03). |
| `06_slurm_bbmap.sh` | `BBMAP_REPAIR` | `bbmap_repair.nf` | `repair.sh` + concatenation of pre-existing and newly orphaned singletons. |

## 2. Read statistics

| Original | Process | Module | Notes |
|---|---|---|---|
| `07_extract_read_counts.sh` | `SEQKIT_STATS` / `COMBINE_SEQKIT` | `seqkit_stats.nf`, `combine_seqkit.nf` | Dropped as a separate stage: its read counts are a strict subset of the seqkit output, and its counting loop was broken (see fixes). Total reads per sample now come from the seqkit table. |
| `08_slurm_seqkit.sh` | `SEQKIT_STATS` | `seqkit_stats.nf` | One task per sample over R1/R2/unpaired together (`seqkit stats -T` for machine-readable output). |
| `09_combine_seqkit_files.sh` | `COMBINE_SEQKIT` | `combine_seqkit.nf` + `bin/combine_seqkit.py` | Re-implemented in Python against column *names*; the bash version read `awk 'NR==2 {print $4}'` from human-formatted output with thousands separators. |

## 3. Assembly and assembly QC

| Original | Process | Module | Notes |
|---|---|---|---|
| `10_slurm_assemble.sh` | `SPADES_META` | `spades.nf` | `metaspades.py --meta -1 -2 -s`; threads/memory from `task.cpus`/`task.memory` instead of the hard-coded `-t 16 -m 128`. |
| `11_slurm_quast.sh` | `QUAST` | `quast.nf` | Unchanged invocation. |
| `12_slurm_combine_quast.sh` | `COMBINE_QUAST` | `combine_quast.nf` + `bin/combine_quast.py` | **The original file is a byte-for-byte copy of `09_combine_seqkit_files.sh`** and never touched QUAST output. Written from scratch: merges every `report.tsv` into one sample × metric table. |

## 4. Binning

| Original | Process | Module | Notes |
|---|---|---|---|
| (read mapping inside 13/14/15) | `MAP_TO_ASSEMBLY` | `map_to_assembly.nf` | The three binning scripts each re-built a bowtie2 index of the assembly and re-mapped the reads. Done **once** per sample here and shared by all three binners (~3× less mapping compute). Unpaired reads are now passed with `-U` (see fixes). |
| (depth inside 13/14) | `JGI_DEPTH` | `jgi_depth.nf` | Single `jgi_summarize_bam_contig_depths` call; MetaBAT2 gets the full table, MaxBin2 gets a 2-column abundance file derived from it. |
| `13_slurm_metabat.sh` | `METABAT2` | `metabat2.nf` | `metabat2 -m ${params.metabat2_min_contig}` (default 1500) `--unbinned`. |
| `14_slurm_maxbin.sh` | `MAXBIN2` | `maxbin2.nf` | `run_MaxBin.pl -contig -abund -thread`. |
| `15_slurm_concoct.sh` | `CONCOCT` | `concoct.nf` | Full CONCOCT chain including the two steps the original omitted: `merge_cutup_clustering.py` and `extract_fasta_bins.py`. |
| `16_slurm_build_dastool_input.sh` | `FASTA_TO_CONTIG2BIN` | `fasta_to_contig2bin.nf` | Uses DAS Tool's own `Fasta_to_Contig2Bin.sh` for MetaBAT2/MaxBin2 bins and a CSV→TSV conversion for the merged CONCOCT clustering. The hard-coded `if [[ $SAMPLE =~ ^p23220 ]]` sample filter and the unused `reg="^(3279_)"` are gone. |
| `17_slurm_dastool.sh` | `DASTOOL` | `dastool.nf` | `DAS_Tool -i … -l metabat2,maxbin2,concoct -c contigs --write_bins --search_engine diamond`; the binner list is built from whichever binners actually produced bins, so `--skip_maxbin2` / `--skip_concoct` work. |

## 5. MAG quality, extraction, taxonomy, dereplication

| Original | Process | Module | Notes |
|---|---|---|---|
| `18_slurm_checkm.sh` | `CHECKM_LINEAGEWF` | `checkm.nf` | `checkm lineage_wf` + `checkm qa -o 2 --tab_table`. Input is the **DAS Tool** bin set, not the raw MetaBAT2 `bins/` directory (see fixes). |
| `19_combine_checkm.sh` | `COMBINE_CHECKM` | `combine_checkm.nf` + `bin/combine_checkm.py` | Same thresholds (completeness ≥ `params.min_completeness` = 50, contamination ≤ `params.max_contamination` = 10) but resolved by column name from the tab table rather than `awk '$7 … $8'`, and applied to bins from all three binners rather than only names matching `bin.`. |
| `20_extract_hq_genomes.py` | `STANDARDIZE_MAGS` | `standardize_mags.nf` + `bin/standardize_dastool_mags.py` | Same bin-ID grammar (`bin.N` → metabat2, `maxbin2_bins.N` → maxbin2, bare integer → concoct, trailing `_sub` stripped) but reads DAS Tool's own `_DASTool_bins/` output directory, so no guessing of per-binner bin paths is required. |
| `21_summmarize_hq_genomes.py` | `SUMMARIZE_MAGS` | `summarize_mags.nf` | Same `MAG_ID` / `sample` / `tool` / `bin_number` / `raw_bin` columns; concatenation now happens over the channel rather than a directory glob. |
| `22_slurm_gtdbtk_taxonomy.slurm` | `GTDBTK_CLASSIFYWF` | `gtdbtk.nf` | `classify_wf --extension fa --skip_ani_screen`; `GTDBTK_DATA_PATH` from `params.gtdbtk_db`. |
| `23_slurm_drep.sh` | `DREP_DEREPLICATE` | `drep.nf` | `dRep dereplicate -comp 50 -con 10 -sa ${params.drep_ani}` (default 0.97). Completeness/contamination are wired to the same params as CheckM filtering. |

## 6. MAG reference preparation

| Original | Process | Module | Notes |
|---|---|---|---|
| `24_rename_MAG_contigs.py` | `RENAME_MAG_CONTIGS` | `rename_mag_contigs.nf` + `bin/rename_mag_contigs.py` | Unchanged logic (`>contig` → `>MAG_contig`); now accepts `.fa`/`.fasta`/`.fna` rather than `.fa` only, which is what dRep actually emits when inputs were `.fa`. |
| `25_slurm_index.sh` | `MAG_CATALOGUE`, `BOWTIE2_BUILD` | `mag_catalogue.nf`, `bowtie2_build.nf` | The original built a per-MAG index, but `26` then used a single concatenated `ALLMAGS710.fasta` index that no script in the repo created. The port concatenates the renamed dereplicated MAGs into one catalogue FASTA and builds one bowtie2 index from it. |
| `27_build_stb.sh` | `MAG_CATALOGUE` | `mag_catalogue.nf` + `bin/build_mag_references.py` | `contigs2bins.stb` built from the renamed MAG headers. |
| `28_build_maglist.sh` | `MAG_CATALOGUE` | same | `mag_ids.txt` + one `<MAG>.scaffolds.txt` per MAG. |
| `29_derived_scaffolds.sh` | `MAG_CATALOGUE` | same | `scaffold_to_mag.tsv`. Derived directly from the `.stb` instead of re-parsing the per-MAG list files and splitting the filename on `.` (which truncated any MAG ID containing a dot). |
| `make_stb.py` | `MAG_CATALOGUE` | same | Duplicate of 29 with a different output filename; folded in. |
| `make_saf.py` | `MAG_CATALOGUE` | same | `mags.saf` (`GeneID/Chr/Start/End/Strand`) emitted alongside the other reference files. |

## 7. Strain-level profiling

| Original | Process | Module | Notes |
|---|---|---|---|
| `26_InStrain_profile_97.slurm` | `MAP_TO_MAGS`, `INSTRAIN_PROFILE` | `map_to_mags.nf`, `instrain_profile.nf` | `bowtie2 --very-sensitive-local` → sorted/indexed BAM → `inStrain profile`. The `.stb` is now passed to `inStrain profile -s`, so inStrain itself reports genome-level results; the SLURM array indexing over `ls` output is replaced by the sample channel. |
| `30_aggregate_instrain_detection.py` | `AGGREGATE_DETECTION` | `instrain_detection.nf` + `bin/aggregate_instrain_detection.py` | Same arithmetic: MAG breadth = Σ covered bases / Σ scaffold length, MAG coverage = length-weighted mean scaffold coverage, detection at breadth ≥ 0.5 and coverage ≥ 1.0 (both params). Reads the profile directories staged by the channel. |
| `31_instrain_compare_710magarray.sbatch` | `INSTRAIN_COMPARE` | `instrain_compare.nf` | One task per MAG (`-sc <MAG>.scaffolds.txt`) over all profiles, fanned out from `mag_ids.txt` instead of a hard-coded `--array=1-710%6`. |

## 8. Dropped

Nothing is dropped silently. `03`, `05`, `make_stb.py` are folded into the
processes noted above; `07` is superseded by the seqkit summary; `12` had to be
rewritten because the committed file did not implement its documented purpose.

---

# Defects found in the script version

These were found while porting. Each is listed with what the port does.

1. **`13_slurm_metabat.sh` — undefined variable.** The script sets
   `DEPTH="${DIR}/depth.txt"` but then calls
   `jgi_summarize_bam_contig_depths --outputDepth $DEPTH_FILE` and
   `metabat2 -a $DEPTH_FILE`. `$DEPTH_FILE` is never assigned in that script, so
   it expands to the empty string. **Fixed** — the depth table is an explicit
   process output.

2. **`13_slurm_metabat.sh`, `06_slurm_bbmap.sh` — stray line continuations.**
   Both contain `&& \ <next command>` (backslash followed by a space), so the
   backslash escapes a space instead of the newline and the next token is
   treated as an argument. **Fixed** — each command is a separate line in the
   process script.

3. **Unpaired reads passed to bowtie2 without `-U`.** `13` and `15` call
   `bowtie2 -x idx -1 $R1 -2 $R2 $UP -p 16 | samtools view -bS - > …`. With
   `-1/-2` already given, the bare `$UP` is consumed as bowtie2's positional
   output-SAM argument, not as input reads: the singletons are never aligned,
   and the alignment stream is written to the `$UP` path instead of to the pipe.
   **Fixed** — `-U` is used, and singletons contribute to the depth table.

4. **`12_slurm_combine_quast.sh` does not combine QUAST output.** It is an exact
   duplicate of `09_combine_seqkit_files.sh`, pointed at the `sample_stats`
   directory. **Fixed** — rewritten.

5. **`07_extract_read_counts.sh` — read counting is a no-op.**
   `zcat "$file" | echo $(( $(wc -l) / 4 ))`: `echo` ignores stdin and the
   command substitution runs `wc -l` with no input, so it reads from the script's
   own stdin and returns 0. Every sample's count was wrong. **Superseded** by the
   seqkit-derived summary.

6. **CONCOCT chain is incomplete.** `15` stops after `concoct`, which writes
   `*_clustering_gt1000.csv` over 10 kb *chunks*. `16` then reads
   `${CONCOCT_DIR}/merged_clustering.csv` and `20` reads
   `concoct_bins/extracted/${bin}.fa`, neither of which any script produces —
   `merge_cutup_clustering.py` and `extract_fasta_bins.py` are missing.
   **Fixed** — both steps are in the `CONCOCT` process.

7. **MaxBin2 abundance file format.** `run_MaxBin.pl -abund` expects two columns
   (contig, mean coverage). `14` passes the raw
   `jgi_summarize_bam_contig_depths` table, which has a header line and
   ≥4 columns. **Fixed** — a 2-column, header-less abundance file is derived
   from the depth table.

8. **`16_slurm_build_dastool_input.sh` — paths and a hard-coded sample filter.**
   `DIR` is a `basename`, so `${DIR}/bins` is a relative path that only resolves
   if the script happens to be run from the metaSPAdes output directory; and the
   body is wrapped in `if [[ $SAMPLE =~ ^p23220 ]]`, so every other sample was
   skipped with a `skipping` message. Also, MaxBin2 bins are globbed as
   `${DIR}/maxbin2_bins*.fasta` while `14` wrote them under
   `${DIR}/maxbin2_bins/${SAMPLE}_maxbin2.*.fasta`. **Fixed** — staged inputs,
   no sample filter.

9. **CheckM evaluates the wrong bin set.** `18` runs
   `checkm lineage_wf … ${DIR}/bins`, i.e. the raw MetaBAT2 bins, even though the
   pipeline's MAG set is DAS Tool's refined output and `19`'s filter is described
   as MAG quality filtering. **Fixed** — CheckM runs on the DAS Tool bins.
   (If you want the old behaviour for comparison, `--checkm_on metabat2` is
   available.)

10. **`19_combine_checkm.sh` — positional columns and a name filter.** It parses
    `checkm qa -o 2` *human* output with `awk '$7 >= 50 && $8 <= 10'` and only
    keeps lines matching `grep "bin."`, which excludes every MaxBin2 and CONCOCT
    bin. It also prints `$file` (lowercase, unset) in its progress message.
    **Fixed** — `--tab_table` output parsed by column name, no name filter.

11. **`25_slurm_index.sh` builds indices nothing uses.** It builds one bowtie2
    index per dereplicated `.fna` under a `99/` prefix, while `26` maps against a
    single `ALLMAGS710.fasta` index. The concatenation step is absent from the
    repository. It also carries `#SBATCH --array=1-1331` but loops over all files
    inside each array task, so the loop would have run 1331 times. **Fixed** —
    one catalogue FASTA, one index.

12. **`26_InStrain_profile_97.slurm` — read filename mismatch.** Sample names are
    derived from `*_R1_formeta.fastq.gz` and reads are then rebuilt as
    `${SAMPLE}_R1_formeta.fastq.gz`; the files written by `06` are
    `${SAMPLE}_non_host_R1_formeta.fastq.gz`, so `$SAMPLE` retains the
    `_non_host` suffix. It works by accident for paired reads, but the singleton
    file is never used in profiling. **Fixed** — channel-provided filenames;
    singletons are mapped with `-U`.

13. **`29_derived_scaffolds.sh` / `make_stb.py` — MAG ID truncation.**
    `os.path.basename(fp).split(".")[0]` on `<MAG>.scaffolds.txt` truncates any
    MAG ID containing a dot (dRep output names such as
    `sample_metabat2_bin.3.fa` do). **Fixed** — IDs come from the `.stb`.

14. **No `set -euo pipefail` in the array wrappers.** Every generated SLURM
    script runs `eval $COMMAND` without failing on error, so a task whose first
    `&&`-chained command failed still exited 0 and the next stage consumed
    truncated or absent files. **Fixed** — Nextflow fails the task on a non-zero
    exit and `errorStrategy`/`-resume` handle retries.

15. **Non-deterministic sample identity.** Eight scripts derive `SAMPLE` with a
    different `sed` expression over a different glob (`p23*`, `*`,
    `*_R1*.fastq*`), and `09`'s regex
    `s/(_R1|_R2|_unpaired)?_formeta_seqkit_stats\.txt$//` leaves `_non_host` on
    the sample name. **Fixed** — one samplesheet, one `meta.id`.
