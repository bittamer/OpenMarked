#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WORK_DIR="${OPENMARKED_EXPORT_WORK_DIR:-.build/openmarked-export-artifacts}"
SNAPSHOT_DIR="$WORK_DIR/png"
PDF_DIR="$WORK_DIR/pdf"

rm -rf "$WORK_DIR"
swift run OpenMarkedSnapshotter --output "$SNAPSHOT_DIR" --pdf-output "$PDF_DIR"

pdf_count="$(find "$PDF_DIR" -type f -name '*.pdf' | wc -l | tr -d ' ')"
if [[ "$pdf_count" -lt 5 ]]; then
  echo "Expected at least five PDF export artifacts, found $pdf_count." >&2
  exit 1
fi

while IFS= read -r pdf; do
  size="$(stat -f '%z' "$pdf")"
  if [[ "$size" -lt 10000 ]]; then
    echo "PDF export artifact is too small: $pdf ($size bytes)" >&2
    exit 1
  fi
done < <(find "$PDF_DIR" -type f -name '*.pdf')

echo "Export artifact verification passed."
