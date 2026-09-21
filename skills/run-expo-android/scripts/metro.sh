#!/usr/bin/env bash
# Restarts Metro and relaunches the app, then reports a native or JS crash.
# Restart after every batch of edits: when the file watcher runs out of inotify
# watches, Metro keeps serving the old bundle to the device without a warning.
. "$(dirname "$0")/env.sh"
load_app_ids
# Stop whatever holds the Metro port. Do not use `pkill -f "expo start"`: the
# pattern also matches the calling shell's command line and kills it.
pids=$(lsof -ti tcp:8081 2>/dev/null); [ -n "$pids" ] && kill $pids
sleep 2
cd "$APP_DIR" || exit 1
CI=1 nohup npx expo start --dev-client --port 8081 > "$OUT/metro.log" 2>&1 &
until curl -s localhost:8081/status | grep -q running; do sleep 2; done
$ADB reverse tcp:8081 tcp:8081 >/dev/null
$ADB logcat -c
$ADB shell am force-stop "$APP_PKG"
$ADB shell am start -a android.intent.action.VIEW \
  -d "$APP_SCHEME://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8081" >/dev/null
until grep -q "Android Bundled" "$OUT/metro.log"; do sleep 3; done
sleep 25
$ADB logcat -d | grep -A3 -E "Fatal signal|FATAL EXCEPTION" || echo NO_CRASH
