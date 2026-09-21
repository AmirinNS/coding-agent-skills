# Shared settings for the run-expo-android scripts. Works on Linux (x86_64) and
# macOS (Apple Silicon or Intel). Override any variable in the environment.
#   APP_DIR     Expo project directory (default: current directory)
#   APP_PKG     Android package id (default: read from `npx expo config`)
#   APP_SCHEME  deep-link scheme (default: read from `npx expo config`)
#   AVD         emulator name (default: expo-dev)
#   OUT         logs and screenshots (default: ${TMPDIR:-/tmp}/run-expo-android)

case "$(uname -s)" in
  Darwin) HOST=mac;   SDK_DEFAULT="$HOME/Library/Android/sdk" ;;
  Linux)  HOST=linux; SDK_DEFAULT="$HOME/Android/Sdk" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ABI=arm64-v8a; JDK_ARCH=aarch64 ;;
  x86_64|amd64)  ABI=x86_64;    JDK_ARCH=x64 ;;
  *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$SDK_DEFAULT}}"

# Java: an existing JAVA_HOME wins, then Android Studio's bundled runtime, then
# the JDK 17 that setup.sh installs under ~/.local/jdk-17.
JDK_DIR="$HOME/.local/jdk-17"
if [ -z "${JAVA_HOME:-}" ]; then
  STUDIO_JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  if [ "$HOST" = mac ] && [ -x "$STUDIO_JBR/bin/java" ]; then JAVA_HOME="$STUDIO_JBR"
  elif [ "$HOST" = mac ]; then JAVA_HOME="$JDK_DIR/Contents/Home"
  else JAVA_HOME="$JDK_DIR"; fi
fi
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

APP_DIR="${APP_DIR:-$PWD}"
AVD="${AVD:-expo-dev}"
OUT="${OUT:-${TMPDIR:-/tmp}/run-expo-android}"
mkdir -p "$OUT"
ADB="$ANDROID_HOME/platform-tools/adb"

# Read the package and scheme from the Expo config once, then cache them.
load_app_ids() {
  if [ -z "${APP_PKG:-}" ] || [ -z "${APP_SCHEME:-}" ]; then
    local ids
    ids=$(cd "$APP_DIR" && npx expo config --json --type public 2>/dev/null | node -e '
      let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
        const c = JSON.parse(s);
        console.log((c.android && c.android.package) || "", [].concat(c.scheme || "")[0]);
      })')
    APP_PKG="${APP_PKG:-${ids%% *}}"
    APP_SCHEME="${APP_SCHEME:-${ids##* }}"
  fi
  [ -n "$APP_PKG" ] && [ -n "$APP_SCHEME" ] || {
    echo "Set android.package and scheme in app.json, or export APP_PKG and APP_SCHEME." >&2; exit 1; }
}
