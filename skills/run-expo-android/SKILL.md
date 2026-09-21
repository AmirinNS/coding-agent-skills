---
name: run-expo-android
description: "Build an Expo or React Native app as an Android development build, run it on a headless emulator, and drive it by visible text and screenshots to verify it works. Use this skill when a change to an Expo app must be proven in the running app, when orchestrate-implementation reaches its Run it check, or when the user asks to test on an Android emulator or simulator. Triggers: 'test on android', 'run it on the emulator', 'android simulator', 'check it on a device', 'does the app actually work'. Works on Linux x86_64 and macOS (Apple Silicon or Intel), with no sudo and no Android Studio required."
---

# Run Expo Android

Typecheck, unit tests and a bundle export can all pass while the app crashes on launch or its buttons do nothing. This skill builds the real app, runs it on an emulator, and gives you scripts to tap through it and read the screen.

## When to use

- Verifying an Expo app change before calling it done or committing it.
- The Run it check of `orchestrate-implementation`, for an Expo app.
- The user asks to test on an Android emulator.

It does not cover iOS, physical camera scanning or tests that need two real devices. Record those as pending for the owner.

## Scripts

All scripts are in `scripts/` next to this file and read `scripts/env.sh`. Call them with bash from anywhere. Set `APP_DIR` to the Expo project and `OUT` to your scratchpad directory when one exists.

| Script | Does |
|---|---|
| `setup.sh` | Installs a JDK if none is found, the Android SDK, and an emulator named `$AVD`. Idempotent. About 7 GB the first time. |
| `emulator.sh` | Boots the emulator headless and waits for boot. |
| `build.sh` | Runs `npx expo install --check`, then builds and installs the dev build. First build about 20 minutes. |
| `metro.sh` | Restarts Metro, relaunches the app, prints `NO_CRASH` or the crash header. |
| `tap.sh "<text>" [wait]` | Taps the first element with that exact visible text. |
| `shot.sh <name> [wait]` | Saves `$OUT/<name>.png`. Read it with the Read tool. |
| `fields.sh` | Prints every text input's current value. |
| `crash.sh` | Symbolises the last native crash with `ndk-stack`. |

Settings, all optional:

| Variable | Default |
|---|---|
| `APP_DIR` | current directory |
| `APP_PKG`, `APP_SCHEME` | read from `npx expo config` |
| `AVD` | `expo-dev` |
| `OUT` | `${TMPDIR:-/tmp}/run-expo-android` |
| `API`, `NDK` (setup only) | `36`, `27.1.12297006`. Match `node_modules/react-native/gradle/libs.versions.toml`. |

Platform defaults chosen by `env.sh`:

| | Linux | macOS |
|---|---|---|
| SDK | `~/Android/Sdk` | `~/Library/Android/sdk` (Android Studio's default) |
| Java | `~/.local/jdk-17` | Android Studio's bundled runtime if installed, else `~/.local/jdk-17/Contents/Home` |
| Emulator image | x86_64 | arm64-v8a on Apple Silicon |
| Acceleration | KVM, through `sg kvm` if the group is not active yet | built-in hypervisor |

An existing `ANDROID_HOME` or `JAVA_HOME` always wins.

## Steps

1. **Setup, once per machine.** Run `setup.sh`. Tell the user before running it: it downloads several GB into their home directory. Skip it if `$ANDROID_HOME/emulator/emulator -list-avds` already lists the AVD.
2. **Boot.** Run `emulator.sh`. Wait for `BOOTED`.
3. **Build.** Run `build.sh`. Rebuild only when native dependencies or `app.json` change; JavaScript changes only need Metro.
4. **Launch.** Run `metro.sh`. Read its crash output before anything else.
5. **Drive the flow.** Use `tap.sh` and `shot.sh` to walk the change's core flow, and read each screenshot. Use deep links to test route guards and forged parameters: `adb shell am start -a android.intent.action.VIEW -d "<scheme>://<route>"`.
6. **After each batch of edits**, rerun `metro.sh`, then walk the flow again.
7. **Report** what was verified on the running app, what failed, and what could not be tested and why.

## What a running app caught that headless checks missed

- An entry file that loaded polyfills but never started the router. The export still passed.
- Native modules pinned to an older framework version than the core package.
- An SVG path made invalid by a regex over number pairs, which crashed Android on render.
- A shared button that only called its handler when a route name was set, so every action button did nothing.
- `\uXXXX` escapes printed literally in JSX text and attributes.
- A duplicated tab bar, a missing safe-area inset, and a tab route to a screen that did not exist.
- A network action that failed silently instead of telling the user.

## Pitfalls

- **Stale bundles.** When the inotify watch limit is exhausted, Metro never sees edits and keeps serving the old bundle. A fresh `curl` of the bundle can look correct while the device runs old code. Rerun `metro.sh` after edits, or raise `fs.inotify.max_user_watches`, or install watchman.
- **KVM permission on Linux.** A user just added to the `kvm` group lacks it until they log in again. `emulator.sh` handles this with `sg kvm`.
- **Killing Metro.** Never `pkill -f "expo start"`; it kills the calling shell too. `metro.sh` stops whatever holds port 8081.
- **Dropped keystrokes.** `adb shell input text` loses characters on a slow emulator. Check `fields.sh` before reading a validation error as a bug.
- **Coordinates.** Screenshots are shown scaled. Tap by text with `tap.sh`.
- **Rate-limited test services.** Public faucets and sandboxes often refuse one IP. Record the flow as pending and ask the owner.
- **First boot.** A software-rendered emulator may show "System UI isn't responding". Tap Wait.
- **Intermittent native crashes.** Relaunch several times and count before concluding. Use `crash.sh` to symbolise.
