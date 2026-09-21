#!/usr/bin/env bash
# Prints the current value of every text input. `adb shell input text` drops
# characters on a slow emulator, so check what landed before judging a
# validation error.
. "$(dirname "$0")/env.sh"
$ADB exec-out uiautomator dump /dev/tty 2>/dev/null | grep -o '<node[^>]*EditText[^>]*>' | grep -o ' text="[^"]*"'
