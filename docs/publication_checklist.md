# Publication validation checklist

`docs/validation.md` records what has already been run. The checks below are
what remains before treating a MAGSPI release as production/publication grade.

## Pipeline validation

- [ ] Run the complete pipeline, all stages enabled, on the simulated test
      data (`tests/make_test_data.py`) with the real databases in place.
- [ ] Run the complete pipeline on a representative subset of real project
      samples.
- [ ] Compare QC and non-host read counts against the script workflow
      (`04_read_stats/seqkit_bysample.tsv`).
- [ ] Compare assembly statistics (`06_assembly_stats/quast_summary.tsv`).
- [ ] Compare MetaBAT2, MaxBin2 and CONCOCT bin counts per sample.
- [ ] Confirm the DAS Tool bin set is extracted and renamed as expected
      (`10_mags/combined_DASTool_summary.tsv`).
- [ ] Compare CheckM completeness/contamination for the selected MAGs
      (`09_checkm/checkm_filtered.tsv`).
- [ ] Compare GTDB-Tk assignments.
- [ ] Confirm dRep representatives and cluster structure are sensible.
- [ ] Validate scaffold-to-MAG mappings after contig renaming: every scaffold
      in the inStrain output must appear in `scaffold_to_mag.tsv`
      (`AGGREGATE_DETECTION` reports the count that does not).
- [ ] Validate MAG detection against samples with a known expected result.
- [ ] Confirm the strain comparison discriminates: on the simulated data,
      popANI should sit just below 1, not at 1.

Expect the port and the script workflow **not** to agree exactly. The defects
listed in `CHANGELOG.md` — CONCOCT bins the scripts never created, the MaxBin2
abundance format, the singleton reads that were never mapped, CheckM applied
to the wrong bin set — all change the result. The port should recover at least
as many MAGs, not identical ones.

## Reproducibility record

- [ ] MAGSPI git commit or tag, and `VERSION`.
- [ ] `results/pipeline_info/software_versions.yml` from the production run.
- [ ] Any container overridden from the pinned default, with its digest.
- [ ] Host reference assembly, CheckM database release, GTDB-Tk database
      release.
- [ ] Nextflow version and the execution profile used.
- [ ] Both a container run and the target HPC/Apptainer configuration
      exercised.
