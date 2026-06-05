#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_DIR="${1:-Docs/Screenshots/visual-qa}"

swift run OpenMarkedSnapshotter --output "$OUTPUT_DIR"

echo "Visual snapshots written to $OUTPUT_DIR"
