#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/mobile/prayer_times"

# Preserve each standalone check's existing fixture base directory.
for test_file in "$APP_DIR"/test/*_smoke.dart; do
  test_name="$(basename "$test_file")"
  echo "Running $test_name"
  case "$test_name" in
    countdown_format_smoke.dart)
      (
        cd "$APP_DIR"
        dart "$test_file"
        temp_dir="$(mktemp -d)"
        trap 'rm -rf "$temp_dir"' EXIT
        dart compile js "$test_file" -o "$temp_dir/countdown.js"
        node "$temp_dir/countdown.js"
      )
      ;;
    adhan_playback_smoke.dart)
      # The native progress store imports path_provider, which requires the
      # Flutter engine's dart:ui library even when a temporary file is supplied.
      (cd "$APP_DIR" && flutter test "$test_file")
      ;;
    evening_adhkar_smoke.dart|hadith_timing_smoke.dart|post_prayer_adhkar_smoke.dart|recitation_colors_smoke.dart)
      (cd "$ROOT_DIR" && dart "$test_file")
      ;;
    *)
      (cd "$APP_DIR" && dart "$test_file")
      ;;
  esac
done
