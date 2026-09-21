#!/usr/bin/env bash
# pi-rpc.sh - drive one persistent `pi --mode rpc` session for orchestration.
#
# Usage: pi-rpc.sh <slug> <command> [args...]
#
# Commands:
#   start              start the session if it is not already running
#   run <file>         send the file's contents as a prompt, wait for
#                      agent_settled, print the final assistant text
#   compact [instr]    compact the session, optionally with custom instructions
#   send <json>        send a raw JSON command (steer, abort, set_model, ...)
#   status             print whether the session is running
#   stop               terminate the session and remove its state
#
# State lives under ${TMPDIR:-/tmp}/pi-orch-<slug>/.
#
# `run` and `compact` exit 1 when the session dies or the event stream goes
# silent, so the caller can treat a stalled implementor as blocked instead of
# waiting forever. Silence is measured in seconds and defaults to 600; override
# with PI_RPC_IDLE_TIMEOUT.

set -u

IDLE_TIMEOUT="${PI_RPC_IDLE_TIMEOUT:-600}"

SLUG="${1:?usage: pi-rpc.sh <slug> <command> [args]}"; shift
CMD="${1:?command required}"; shift || true

DIR="${TMPDIR:-/tmp}/pi-orch-$SLUG"
CMDS="$DIR/cmds.log"
EVENTS="$DIR/events.jsonl"
ERR="$DIR/err.log"
PIDF="$DIR/pid"

py_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

running() {
  [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null
}

start() {
  if running; then return 0; fi
  pkill -f "tail -f $CMDS" 2>/dev/null || true
  mkdir -p "$DIR"
  : > "$CMDS"; : > "$EVENTS"; : > "$ERR"
  # tail -f keeps stdin open; pi exits on stdin EOF otherwise.
  tail -f "$CMDS" | pi --mode rpc --session-id "orchestrate-$SLUG" -a \
    > "$EVENTS" 2> "$ERR" &
  echo $! > "$PIDF"
  sleep 3
}

events_size() {
  wc -c < "$EVENTS" | tr -d ' '
}

wait_from() {
  # Poll from line $1 for a substring; print new lines up to the match.
  # Returns 1 if pi exits first, or if the event stream stays silent for
  # IDLE_TIMEOUT polls, so a dead or stalled implementor cannot hang the caller.
  local start="$1" pattern="$2"
  local last_size idle=0 size
  last_size=$(events_size)
  while :; do
    if tail -n +"$start" "$EVENTS" | grep -q "$pattern"; then
      tail -n +"$start" "$EVENTS" | awk -v p="$pattern" '{ print; if (index($0, p)) exit }'
      return 0
    fi
    if ! running; then
      echo "pi-rpc: session orchestrate-$SLUG died while waiting for $pattern" >&2
      tail -n 5 "$ERR" >&2
      return 1
    fi
    sleep 1
    size=$(events_size)
    if [ "$size" != "$last_size" ]; then
      last_size="$size"
      idle=0
    else
      idle=$(( idle + 1 ))
      if [ "$idle" -ge "$IDLE_TIMEOUT" ]; then
        echo "pi-rpc: no events for ~${IDLE_TIMEOUT}s while waiting for $pattern" >&2
        return 1
      fi
    fi
  done
}

final_text() {
  python3 - "$EVENTS" <<'PY'
import json, sys
final = ""
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    try:
        e = json.loads(line)
    except Exception:
        continue
    if e.get("type") == "message_end":
        m = e.get("message") or {}
        if m.get("role") == "assistant":
            texts = [c.get("text", "") for c in m.get("content", [])
                     if isinstance(c, dict) and c.get("type") == "text"]
            if texts:
                final = "\n".join(texts)
print(final)
PY
}

case "$CMD" in
  start)
    start
    echo "session orchestrate-$SLUG running (pid $(cat "$PIDF"))"
    ;;
  run)
    file="${1:?usage: pi-rpc.sh <slug> run <file>}"
    start
    start_line=$(( $(wc -l < "$EVENTS") + 1 ))
    msg=$(py_json "$(cat "$file")")
    printf '{"type":"prompt","message":%s}\n' "$msg" >> "$CMDS"
    if ! wait_from "$start_line" '"type":"agent_settled"' > /dev/null; then
      final_text
      exit 1
    fi
    final_text
    ;;
  compact)
    start
    start_line=$(( $(wc -l < "$EVENTS") + 1 ))
    if [ $# -ge 1 ] && [ -n "$1" ]; then
      instr=$(py_json "$1")
      printf '{"type":"compact","customInstructions":%s}\n' "$instr" >> "$CMDS"
    else
      printf '{"type":"compact"}\n' >> "$CMDS"
    fi
    wait_from "$start_line" '"command":"compact"' || exit 1
    ;;
  send)
    json="${1:?usage: pi-rpc.sh <slug> send '<json>'}"
    start
    printf '%s\n' "$json" >> "$CMDS"
    ;;
  status)
    if running; then echo "running (pid $(cat "$PIDF"))"; else echo "not running"; fi
    ;;
  stop)
    pkill -f "tail -f $CMDS" 2>/dev/null || true
    pkill -f "pi --mode rpc --session-id orchestrate-$SLUG" 2>/dev/null || true
    rm -f "$PIDF"
    rm -rf "$DIR"
    echo "stopped"
    ;;
  *)
    echo "unknown command: $CMD" >&2
    exit 1
    ;;
esac
