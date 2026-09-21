#!/usr/bin/env bash
# Boots the emulator headless and waits for boot. macOS uses its built-in
# hypervisor. On Linux, a user added to the kvm group after login does not have
# it in the current session, so run through `sg kvm` in that case.
. "$(dirname "$0")/env.sh"
CMD="$ANDROID_HOME/emulator/emulator -avd $AVD -no-window -no-boot-anim -no-snapshot-save -no-audio"
if [ "$HOST" = linux ] && ! id -nG | grep -qw kvm && getent group kvm | grep -qw "$(id -un)"; then
  nohup sg kvm -c "$CMD" > "$OUT/emulator.log" 2>&1 &
else
  nohup $CMD > "$OUT/emulator.log" 2>&1 &
fi
for i in $(seq 1 60); do
  [ "$($ADB shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && { echo BOOTED; exit 0; }
  sleep 5
done
echo "BOOT TIMEOUT"; grep -iE "error|kvm|hvf" "$OUT/emulator.log" | tail -5; exit 1
