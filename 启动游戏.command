#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$ROOT/builds/Road Rage.app" ]; then
    open "$ROOT/builds/Road Rage.app"
else
    GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
    if [ ! -x "$GODOT" ]; then echo '请先安装 Godot 4 标准版到「应用程序」，或设置 GODOT_BIN。'; exit 1; fi
    exec "$GODOT" --path "$ROOT"
fi
