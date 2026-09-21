#!/usr/bin/env bash
# Installs a JDK (unless one is found), the Android SDK and one emulator, all in
# user space. Set API and NDK to match node_modules/react-native/gradle/libs.versions.toml.
set -euo pipefail
. "$(dirname "$0")/env.sh"
API="${API:-36}"; NDK="${NDK:-27.1.12297006}"

if [ ! -x "$JAVA_HOME/bin/java" ]; then
  curl -fsSL -o /tmp/jdk17.tgz "https://api.adoptium.net/v3/binary/latest/17/ga/$HOST/$JDK_ARCH/jdk/hotspot/normal/eclipse"
  mkdir -p "$JDK_DIR" && tar -xzf /tmp/jdk17.tgz -C "$JDK_DIR" --strip-components=1 && rm /tmp/jdk17.tgz
fi
"$JAVA_HOME/bin/java" -version

mkdir -p "$ANDROID_HOME/cmdline-tools"
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  ZIP=$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml \
    | grep -o "commandlinetools-$HOST-[0-9]*_latest.zip" \
    | awk -F- '{ split($3, a, "_"); if (a[1] + 0 > max) { max = a[1] + 0; f = $0 } } END { print f }')
  curl -fsSL -o /tmp/cmdtools.zip "https://dl.google.com/android/repository/$ZIP"
  rm -rf /tmp/cmdtools && mkdir /tmp/cmdtools && unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools
  mv /tmp/cmdtools/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest" && rm -rf /tmp/cmdtools /tmp/cmdtools.zip
fi

SM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
# `yes` dies of SIGPIPE when sdkmanager stops reading; with pipefail that aborts the script.
(yes | "$SM" --sdk_root="$ANDROID_HOME" --licenses >/dev/null) || true
"$SM" --sdk_root="$ANDROID_HOME" "platform-tools" "emulator" "platforms;android-$API" \
  "build-tools;$API.0.0" "ndk;$NDK" "cmake;3.22.1" "system-images;android-$API;google_apis;$ABI"
echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd -n "$AVD" \
  -k "system-images;android-$API;google_apis;$ABI" -d pixel_7 --force
echo "SETUP_DONE host=$HOST abi=$ABI sdk=$ANDROID_HOME java=$JAVA_HOME"
