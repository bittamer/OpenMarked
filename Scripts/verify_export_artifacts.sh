#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WORK_DIR="${OPENMARKED_EXPORT_WORK_DIR:-.build/openmarked-export-artifacts}"
SNAPSHOT_DIR="$WORK_DIR/png"
PDF_DIR="$WORK_DIR/pdf"

rm -rf "$WORK_DIR"
swift run OpenMarkedSnapshotter --output "$SNAPSHOT_DIR" --pdf-output "$PDF_DIR"

if [[ ! -f "$SNAPSHOT_DIR/manifest.json" ]]; then
  echo "Snapshot manifest missing at $SNAPSHOT_DIR/manifest.json" >&2
  exit 1
fi

python3 - "$SNAPSHOT_DIR/manifest.json" "$SNAPSHOT_DIR" "$PDF_DIR" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
snapshot_dir = pathlib.Path(sys.argv[2])
pdf_dir = pathlib.Path(sys.argv[3])
manifest = json.loads(manifest_path.read_text())
entries = manifest.get("snapshots", [])

if len(entries) < 8:
    raise SystemExit(f"Expected at least eight export fixture entries, found {len(entries)}")

required_ids = {entry["id"] for entry in entries}
for required_id in sorted(required_ids):
    png_path = snapshot_dir / f"{required_id}.png"
    pdf_path = pdf_dir / f"{required_id}.pdf"
    if not png_path.exists():
        raise SystemExit(f"Missing PNG export artifact: {png_path}")
    if not pdf_path.exists():
        raise SystemExit(f"Missing PDF export artifact: {pdf_path}")

    pdf_size = pdf_path.stat().st_size
    if pdf_size < 10_000:
        raise SystemExit(f"PDF export artifact is too small: {pdf_path} ({pdf_size} bytes)")

for rich_id in ("github-rich-markdown-light", "github-rich-markdown-dark"):
    if rich_id not in required_ids:
        raise SystemExit(f"Missing rich Markdown export fixture: {rich_id}")

    rich_pdf_path = pdf_dir / f"{rich_id}.pdf"
    rich_pdf_size = rich_pdf_path.stat().st_size
    if rich_pdf_size < 60_000:
        raise SystemExit(f"Rich Markdown PDF looks too small: {rich_pdf_path} ({rich_pdf_size} bytes)")

broken_links_entry = next((entry for entry in entries if entry["id"] == "github-broken-links-light"), None)
if not broken_links_entry:
    raise SystemExit("Missing broken-links export fixture")

broken_link_kinds = set(broken_links_entry.get("diagnosticKinds", []))
required_broken_link_kinds = {"missingHeadingFragment", "missingLocalLink", "unsupportedLinkScheme", "malformedLink"}
missing_broken_link_kinds = sorted(required_broken_link_kinds - broken_link_kinds)
if missing_broken_link_kinds:
    raise SystemExit(f"Broken link export fixture did not record diagnostics: {', '.join(missing_broken_link_kinds)}")

print("Export artifact verification passed.")
PY
