#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASELINE_DIR="${OPENMARKED_VISUAL_BASELINE_DIR:-Docs/Screenshots/visual-qa}"
WORK_DIR="${OPENMARKED_VISUAL_WORK_DIR:-.build/openmarked-visual-snapshots}"
STRICT_HASHES="${OPENMARKED_STRICT_VISUAL_HASHES:-0}"

rm -rf "$WORK_DIR"
swift run OpenMarkedSnapshotter --output "$WORK_DIR"

if [[ ! -f "$WORK_DIR/manifest.json" ]]; then
  echo "Visual snapshot manifest missing at $WORK_DIR/manifest.json" >&2
  exit 1
fi

python3 - "$WORK_DIR/manifest.json" "$BASELINE_DIR/manifest.json" "$STRICT_HASHES" <<'PY'
import json
import pathlib
import sys

work_manifest = pathlib.Path(sys.argv[1])
baseline_manifest = pathlib.Path(sys.argv[2])
strict_hashes = sys.argv[3] == "1"

work = json.loads(work_manifest.read_text())
entries = work.get("snapshots", [])
if len(entries) < 5:
    raise SystemExit("Expected at least five visual snapshots")

for entry in entries:
    image_path = work_manifest.parent / entry["file"]
    if not image_path.exists():
        raise SystemExit(f"Missing snapshot image: {image_path}")
    if image_path.stat().st_size < 10_000:
        raise SystemExit(f"Snapshot looks too small to be useful: {image_path}")

if baseline_manifest.exists():
    baseline = json.loads(baseline_manifest.read_text())
    baseline_ids = {entry["id"] for entry in baseline.get("snapshots", [])}
    work_ids = {entry["id"] for entry in entries}
    if baseline_ids != work_ids:
        raise SystemExit(f"Snapshot case mismatch. baseline={sorted(baseline_ids)} work={sorted(work_ids)}")

    if strict_hashes:
        baseline_hashes = {entry["id"]: entry["sha256"] for entry in baseline.get("snapshots", [])}
        work_hashes = {entry["id"]: entry["sha256"] for entry in entries}
        changed = [snapshot_id for snapshot_id in sorted(work_hashes) if work_hashes[snapshot_id] != baseline_hashes.get(snapshot_id)]
        if changed:
            raise SystemExit(f"Visual snapshot hashes changed: {', '.join(changed)}")

print("Visual snapshot verification passed.")
PY
