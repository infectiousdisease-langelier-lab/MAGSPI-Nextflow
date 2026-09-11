#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-magspi:0.2.0}"

docker run --rm "${IMAGE}" bash -lc '
  set -euo pipefail
  for tool in fastp bowtie2 bowtie2-build samtools repair.sh seqkit metaspades.py quast.py metabat2 run_MaxBin.pl concoct DAS_Tool diamond checkm gtdbtk dRep inStrain; do
    command -v "${tool}" >/dev/null || { echo "Missing tool: ${tool}" >&2; exit 1; }
  done
  python --version
  echo "All MAGSPI command-line tools are available."
'
