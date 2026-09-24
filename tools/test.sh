#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
mkdir -p "$ROOT/builds/test-logs"
"$GODOT" --headless --path "$ROOT" --editor --import --quit > "$ROOT/builds/test-logs/import.log" 2>&1
"$GODOT" --headless --path "$ROOT" --script tests/test_game.gd 2>&1 | tee "$ROOT/builds/test-logs/logic.log"
grep -q 'TEST_RESULTS passed=29 failed=0' "$ROOT/builds/test-logs/logic.log"
"$GODOT" --path "$ROOT" --script tests/test_ui.gd 2>&1 | tee "$ROOT/builds/test-logs/ui.log"
grep -q 'UI_TEST_RESULTS passed=13 failed=0' "$ROOT/builds/test-logs/ui.log"
if grep -E '^(SCRIPT ERROR:|ERROR:)' "$ROOT/builds/test-logs/logic.log" "$ROOT/builds/test-logs/ui.log"; then exit 1; fi
printf '\nAll 42 assertions passed.\n'
