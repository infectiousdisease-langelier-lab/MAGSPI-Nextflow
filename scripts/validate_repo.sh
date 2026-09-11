#!/usr/bin/env bash
set -euo pipefail

python -m py_compile bin/*.py
python -m json.tool nextflow_schema.json >/dev/null

grep -q "nextflow.enable.dsl=2" main.nf
for required in main.nf nextflow.config nextflow_schema.json containers/Dockerfile envs/mags_pipeline.yml examples/samplesheet.csv; do
  test -f "$required" || { echo "Missing: $required" >&2; exit 1; }
done

echo "Repository validation checks passed."
