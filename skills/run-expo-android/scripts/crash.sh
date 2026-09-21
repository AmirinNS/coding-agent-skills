#!/usr/bin/env bash
# Symbolises the last native crash in logcat against the unstripped debug libraries.
. "$(dirname "$0")/env.sh"
NDK_DIR=$(ls -d "$ANDROID_HOME"/ndk/* | tail -1)
$ADB logcat -d | grep "F DEBUG" > "$OUT/tomb.txt"
[ -s "$OUT/tomb.txt" ] || { echo "no native crash in logcat"; exit 0; }
"$NDK_DIR/ndk-stack" -sym "$APP_DIR/android/app/build/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/$ABI" \
  -i "$OUT/tomb.txt" | grep -E "#[0-9]+" | head -30
