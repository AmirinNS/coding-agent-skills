#!/usr/bin/env bash
# Checks dependency alignment, then prebuilds, compiles and installs the
# development build. The first run takes 20 minutes or more.
. "$(dirname "$0")/env.sh"
cd "$APP_DIR" || exit 1
npx expo install --check || echo "WARNING: fix the version mismatches above with 'npx expo install --fix' before trusting a runtime crash"
CI=1 npx expo run:android --no-bundler > "$OUT/build.log" 2>&1
code=$?; tail -5 "$OUT/build.log"; exit $code
