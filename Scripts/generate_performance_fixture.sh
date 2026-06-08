#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-"$ROOT_DIR/.build/perf-audit"}"
IMAGE_COUNT="${OPENMARKED_PERF_IMAGE_COUNT:-40}"
SECTION_COUNT="${OPENMARKED_PERF_SECTION_COUNT:-12}"
IMAGE_SIZE="${OPENMARKED_PERF_IMAGE_SIZE:-2400}"

mkdir -p "$OUTPUT_DIR/images"

fixture="$OUTPUT_DIR/large-images.md"
source_svg="$ROOT_DIR/Fixtures/Assets/sample-mark.svg"

for i in $(seq -w 1 "$IMAGE_COUNT"); do
  image_path="$OUTPUT_DIR/images/large-$i.png"
  if [[ ! -f "$image_path" ]]; then
    if ! sips -s format png -z "$IMAGE_SIZE" "$IMAGE_SIZE" "$source_svg" --out "$image_path" >/dev/null 2>&1; then
      cp "$source_svg" "$OUTPUT_DIR/images/large-$i.svg"
    fi
  fi
done

{
  printf '# Large Image Performance Fixture\n\n'
  printf 'This generated fixture is intentionally large and image-heavy.\n\n'
  for section in $(seq 1 "$SECTION_COUNT"); do
    printf '## Section %s\n\n' "$section"
    for i in $(seq -w 1 "$IMAGE_COUNT"); do
      if [[ -f "$OUTPUT_DIR/images/large-$i.png" ]]; then
        printf '![Large image %s.%s](images/large-%s.png)\n\n' "$section" "$i" "$i"
      else
        printf '![Large image %s.%s](images/large-%s.svg)\n\n' "$section" "$i" "$i"
      fi
      printf 'Caption paragraph for image %s.%s with enough text to force normal Markdown layout and status calculations.\n\n' "$section" "$i"
    done
  done
} >"$fixture"

printf 'Generated %s\n' "$fixture"
printf 'Images: %s\n' "$(find "$OUTPUT_DIR/images" -type f | wc -l | tr -d ' ')"
printf 'Markdown bytes: %s\n' "$(wc -c <"$fixture" | tr -d ' ')"
