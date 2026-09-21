#!/usr/bin/env bash
# usage: tap.sh "<exact visible text>" [wait-seconds]
# Taps the first element whose text matches, found through a uiautomator dump.
. "$(dirname "$0")/env.sh"
b=$($ADB exec-out uiautomator dump /dev/tty 2>/dev/null | grep -o "text=\"$1\"[^>]*bounds=\"[^\"]*\"" \
  | head -1 | grep -o 'bounds="[^"]*"' | grep -o '[0-9][0-9]*')
[ -z "$b" ] && { echo "NOT FOUND: $1"; exit 1; }
set -- "$1" "${2:-5}" $b
$ADB shell input tap $(( ($3 + $5) / 2 )) $(( ($4 + $6) / 2 ))
sleep "$2"
