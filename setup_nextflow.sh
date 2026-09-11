#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a recent stable Nextflow release without requiring a package manager.
# Override NXF_VER to pin a different release for a study.
NXF_VER="${NXF_VER:-26.04.6}"
PREFIX="${PREFIX:-$HOME/.local/bin}"
mkdir -p "$PREFIX"
cd "$PREFIX"
curl -fsSL https://get.nextflow.io | bash
mv nextflow "nextflow-${NXF_VER}"
ln -sfn "nextflow-${NXF_VER}" nextflow
printf 'Installed Nextflow at %s/nextflow\n' "$PREFIX"
