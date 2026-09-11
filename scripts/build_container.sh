#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-magspi:0.2.0}"

echo "Building ${IMAGE}"
docker build -f containers/Dockerfile -t "${IMAGE}" .
