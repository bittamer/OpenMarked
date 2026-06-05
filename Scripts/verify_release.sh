#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build
swift build --product OpenMarked
swift build -c release --product OpenMarked
swift run OpenMarkedVerifier
swift run OpenMarkedVerifier --performance-smoke
Scripts/verify_visual_snapshots.sh
Scripts/verify_export_artifacts.sh
swift test
swift package describe >/dev/null
git diff --check

if LC_ALL=C rg -n "[^[:ascii:]]" --glob '!.build/**' --glob '!.git/**' --glob '!dist/**' .; then
  echo "Non-ASCII text found outside generated build output." >&2
  exit 1
fi

Scripts/package_release.sh

echo "Release verification completed."
