# Assets

| File | Purpose |
|---|---|
| `samplesheet_stub.csv` | three samples pointing at the tiny FASTQ fixtures in `tests/fixtures/fastq/`. Used by `-profile test_stub` for graph/stub testing only — not biologically meaningful and must not be used for analysis. |
| `samplesheet_test.csv` | three samples of the simulated mini-metagenome. Written by `tests/make_test_data.py`; the referenced FASTQ files are generated, not committed. |
| `multiqc_config.yml` | section ordering for the MultiQC report. |

Samplesheet format is `sample,fastq_1,fastq_2`. Relative FASTQ paths resolve
against the directory holding the samplesheet, which is why both files above
work from `assets/`.
