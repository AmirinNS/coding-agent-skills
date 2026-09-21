#!/usr/bin/env bash
# usage: shot.sh <name> [wait-seconds]   saves $OUT/<name>.png and prints the path
. "$(dirname "$0")/env.sh"
sleep "${2:-0}"
$ADB exec-out screencap -p > "$OUT/$1.png"
echo "$OUT/$1.png"
