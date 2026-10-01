#!/usr/bin/env bash
set -euo pipefail

python3 -m py_compile bin/*.py
python3 -m json.tool nextflow_schema.json > /dev/null

grep -qE "nextflow\.enable\.dsl\s*=\s*2" main.nf

for required in \
    main.nf \
    nextflow.config \
    nextflow_schema.json \
    conf/base.config \
    conf/modules.config \
    assets/samplesheet_stub.csv \
    tests/test_bin_scripts.py \
    tests/make_test_data.py \
    docs/port_map.md \
    docs/validation.md
do
  test -f "$required" || { echo "Missing: $required" >&2; exit 1; }
done

# every subworkflow a module is included from must exist
missing=0
for sw in subworkflows/local/*.nf; do
  while read -r mod; do
    path="$(dirname "$sw")/$mod.nf"
    if [ ! -f "$path" ]; then echo "Missing module: $path (from $sw)" >&2; missing=1; fi
  done < <(grep -oE "from '\.\./\.\./modules/local/[a-z0-9_]+'" "$sw" | sed "s#from '##;s#'##")
done
[ "$missing" -eq 0 ] || exit 1

echo "Repository validation checks passed."
