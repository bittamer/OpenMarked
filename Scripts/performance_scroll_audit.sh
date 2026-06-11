#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_DIR="${OPENMARKED_PERF_OUTPUT_DIR:-"$ROOT_DIR/.build/perf-audit"}"
FIXTURE_PATH="${OPENMARKED_PERF_FIXTURE:-"$OUTPUT_DIR/large-images.md"}"
APP_PATH="${OPENMARKED_PERF_APP:-"$ROOT_DIR/dist/OpenMarked-0.5.2/OpenMarked.app"}"
SAMPLE_SECONDS="${OPENMARKED_PERF_SAMPLE_SECONDS:-3}"
SCROLL_STEPS="${OPENMARKED_PERF_SCROLL_STEPS:-120}"
SCROLL_DELAY="${OPENMARKED_PERF_SCROLL_DELAY:-0.025}"
CPU_SAMPLES="${OPENMARKED_PERF_CPU_SAMPLES:-12}"
IDLE_CPU_SAMPLES="${OPENMARKED_PERF_IDLE_CPU_SAMPLES:-6}"
SETTLE_SECONDS="${OPENMARKED_PERF_SETTLE_SECONDS:-8}"
REPORT_PATH="$OUTPUT_DIR/performance-scroll-report.md"
SAMPLE_PATH="$OUTPUT_DIR/openmarked-scroll-sample.txt"
IDLE_SAMPLE_PATH="$OUTPUT_DIR/openmarked-idle-sample.txt"
CPU_PATH="$OUTPUT_DIR/openmarked-scroll-cpu.tsv"
IDLE_CPU_PATH="$OUTPUT_DIR/openmarked-idle-cpu.tsv"

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$FIXTURE_PATH" ]]; then
  Scripts/generate_performance_fixture.sh "$OUTPUT_DIR"
fi

if [[ ! -d "$APP_PATH" ]]; then
  Scripts/package_release.sh
fi

pkill -x OpenMarked >/dev/null 2>&1 || true
sleep 1

open -n -a "$APP_PATH" "$FIXTURE_PATH"
sleep 8

pid="$(pgrep -x OpenMarked | tail -n 1 || true)"
if [[ -z "$pid" ]]; then
  echo "OpenMarked did not launch." >&2
  exit 1
fi

printf 'sample\tcpu\trss_kb\n' >"$CPU_PATH"
ps -p "$pid" -o %cpu=,rss= | awk -v sample=0 '{ print sample "\t" $1 "\t" $2 }' >>"$CPU_PATH"

osascript <<APPLESCRIPT &
tell application "System Events"
  tell process "OpenMarked"
    set frontmost to true
    repeat $SCROLL_STEPS times
      key code 121
      delay $SCROLL_DELAY
    end repeat
  end tell
end tell
APPLESCRIPT
scroll_pid=$!

sample "$pid" "$SAMPLE_SECONDS" -file "$SAMPLE_PATH" >/dev/null 2>&1 || true

for i in $(seq 1 "$CPU_SAMPLES"); do
  ps -p "$pid" -o %cpu=,rss= | awk -v sample="$i" '{ print sample "\t" $1 "\t" $2 }' >>"$CPU_PATH"
  sleep 0.5
done

wait "$scroll_pid" || true
sleep "$SETTLE_SECONDS"

printf 'sample\tcpu\trss_kb\n' >"$IDLE_CPU_PATH"
for i in $(seq 1 "$IDLE_CPU_SAMPLES"); do
  ps -p "$pid" -o %cpu=,rss= | awk -v sample="$i" '{ print sample "\t" $1 "\t" $2 }' >>"$IDLE_CPU_PATH"
  sleep 1
done

sample "$pid" "$SAMPLE_SECONDS" -file "$IDLE_SAMPLE_PATH" >/dev/null 2>&1 || true

idle_cpu="$(tail -n 1 "$IDLE_CPU_PATH" | awk '{ print $2 }' || true)"
idle_rss="$(tail -n 1 "$IDLE_CPU_PATH" | awk '{ print $3 }' || true)"
pkill -x OpenMarked >/dev/null 2>&1 || true

forbidden_stats_count="$(rg -c 'DocumentStatisticsCalculator\\.calculate|StatusBar\\.currentStatistics' "$SAMPLE_PATH" || printf '0')"
forbidden_theme_count="$(rg -c 'PreviewThemeStore\\.loadCSS' "$SAMPLE_PATH" || printf '0')"
idle_forbidden_stats_count="$(rg -c 'DocumentStatisticsCalculator\\.calculate|StatusBar\\.currentStatistics' "$IDLE_SAMPLE_PATH" || printf '0')"
idle_forbidden_theme_count="$(rg -c 'PreviewThemeStore\\.loadCSS' "$IDLE_SAMPLE_PATH" || printf '0')"

{
  printf '# OpenMarked Performance Scroll Audit\n\n'
  printf -- '- Fixture: `%s`\n' "$FIXTURE_PATH"
  printf -- '- App: `%s`\n' "$APP_PATH"
  printf -- '- Scroll-time sample: `%s`\n' "$SAMPLE_PATH"
  printf -- '- Post-settle sample: `%s`\n' "$IDLE_SAMPLE_PATH"
  printf -- '- Scroll-time CPU/RSS samples: `%s`\n' "$CPU_PATH"
  printf -- '- Post-settle CPU/RSS samples: `%s`\n' "$IDLE_CPU_PATH"
  printf -- '- Settle wait after scroll: `%s seconds`\n' "$SETTLE_SECONDS"
  printf -- '- Idle CPU after scroll: `%s%%`\n' "${idle_cpu:-unknown}"
  printf -- '- Idle RSS after scroll: `%s KB`\n' "${idle_rss:-unknown}"
  printf -- '- Scroll hot stack statistics recalculation matches: `%s`\n' "$forbidden_stats_count"
  printf -- '- Scroll hot stack theme CSS reload matches: `%s`\n' "$forbidden_theme_count"
  printf -- '- Idle hot stack statistics recalculation matches: `%s`\n' "$idle_forbidden_stats_count"
  printf -- '- Idle hot stack theme CSS reload matches: `%s`\n' "$idle_forbidden_theme_count"
  printf '\n## Scroll-Time CPU/RSS Samples\n\n'
  printf '```tsv\n'
  cat "$CPU_PATH"
  printf '```\n'
  printf '\n## Post-Settle CPU/RSS Samples\n\n'
  printf '```tsv\n'
  cat "$IDLE_CPU_PATH"
  printf '```\n'
} >"$REPORT_PATH"

printf 'Performance scroll report: %s\n' "$REPORT_PATH"
printf 'Scroll-time sample report: %s\n' "$SAMPLE_PATH"
printf 'Post-settle sample report: %s\n' "$IDLE_SAMPLE_PATH"

if [[ "$forbidden_stats_count" != "0" || "$forbidden_theme_count" != "0" || "$idle_forbidden_stats_count" != "0" || "$idle_forbidden_theme_count" != "0" ]]; then
  echo "Performance audit found forbidden hot-stack work." >&2
  exit 1
fi
