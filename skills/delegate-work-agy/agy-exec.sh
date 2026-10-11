#!/usr/bin/env bash
# agy-exec.sh - drive one `agy` CLI conversation per bounded assignment.
#
# Usage: agy-exec.sh <slug> <command> [args...]
#
# Commands:
#   new <file>       start a fresh conversation with the file as prompt, wait for
#                    the turn to end, print agy's final message
#   resume <file>    send the file as the next prompt on current conversation,
#                    wait for the turn to end, print agy's final message
#   conversation     print the current conversation id
#   thread           alias for conversation
#   status           print whether a turn is currently running
#   stop             kill a running turn and remove all state
#
# State lives under ${TMPDIR:-/tmp}/agy-work-<slug>/.
# cli-version.txt and cli-path.txt identify the CLI used for that turn.
#
# `new` and `resume` exit 1 when agy fails, or when its log stream stays
# silent for AGY_EXEC_IDLE_TIMEOUT seconds (default 600), so a stalled turn
# cannot hang the caller. Set AGY_ORCH_MODEL to override the model.
# Set AGY_ORCH_EFFORT to override reasoning effort.

set -u

IDLE_TIMEOUT="${AGY_EXEC_IDLE_TIMEOUT:-600}"

SLUG="${1:?usage: agy-exec.sh <slug> <command> [args]}"; shift
CMD="${1:?command required}"; shift || true

if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "agy-exec: slug must contain lowercase letters, digits, and single hyphens" >&2
  exit 1
fi
if [[ ! "$IDLE_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "agy-exec: AGY_EXEC_IDLE_TIMEOUT must be a positive integer" >&2
  exit 1
fi

DIR="${TMPDIR:-/tmp}/agy-work-$SLUG"
LOG="$DIR/agy.log"
OUT="$DIR/output.json"
ERR="$DIR/err.log"
CONV="$DIR/conversation_id"
PIDF="$DIR/pid"

running() {
  [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null
}

# ponytail: 1s polling loop over log size. Upgrade to inotify or fswatch if busy-wait overhead matters.
log_size() {
  if [ -f "$LOG" ]; then wc -c < "$LOG" | tr -d ' '; else echo 0; fi
}

run_turn() {
  local file="$1"; shift
  local mode="${1:-new}"

  if running; then
    echo "agy-exec: a turn is already running for $SLUG" >&2
    return 1
  fi
  if [ ! -r "$file" ]; then
    echo "agy-exec: prompt file is not readable: $file" >&2
    return 1
  fi

  mkdir -p "$DIR"
  : > "$OUT"; : > "$ERR"; : > "$LOG"
  command -v agy > "$DIR/cli-path.txt"
  if ! agy --version > "$DIR/cli-version.txt" 2>> "$ERR"; then
    echo "agy-exec: cannot record Antigravity CLI version" >&2
    tail -n 5 "$ERR" >&2
    return 1
  fi

  local prompt
  prompt=$(cat "$file")

  local opts=(--dangerously-skip-permissions --output-format json)
  if [ -n "${AGY_ORCH_MODEL:-}" ]; then
    opts+=(--model "$AGY_ORCH_MODEL")
  fi
  if [ -n "${AGY_ORCH_EFFORT:-}" ]; then
    opts+=(--effort "$AGY_ORCH_EFFORT")
  fi
  opts+=(--log-file "$LOG")

  if [ "$mode" = "resume" ]; then
    if [ ! -s "$CONV" ]; then
      echo "agy-exec: no conversation for $SLUG, run 'new' first" >&2
      return 1
    fi
    opts+=(--conversation "$(cat "$CONV")")
  fi

  agy "${opts[@]}" --print "$prompt" > "$OUT" 2> "$ERR" &
  local pid=$!
  echo "$pid" > "$PIDF"

  local last_size idle=0 size rc
  last_size=$(log_size)
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    size=$(log_size)
    if [ "$size" != "$last_size" ]; then
      last_size="$size"
      idle=0
    else
      idle=$(( idle + 1 ))
      if [ "$idle" -ge "$IDLE_TIMEOUT" ]; then
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        rm -f "$PIDF"
        echo "agy-exec: no events for ~${IDLE_TIMEOUT}s, turn killed" >&2
        return 1
      fi
    fi
  done
  wait "$pid"
  rc=$?
  rm -f "$PIDF"

  if [ "$rc" -ne 0 ]; then
    echo "agy-exec: agy exited $rc" >&2
    tail -n 5 "$ERR" >&2
    return 1
  fi

  python3 - "$OUT" "$CONV" <<'PY'
import json, sys, os
out_path = sys.argv[1]
conv_path = sys.argv[2] if len(sys.argv) > 2 else ""

if not os.path.exists(out_path) or os.path.getsize(out_path) == 0:
    print("agy-exec: empty output from agy", file=sys.stderr)
    sys.exit(1)

try:
    with open(out_path) as f:
        data = json.load(f)
except Exception as e:
    print(f"agy-exec: invalid json output: {e}", file=sys.stderr)
    sys.exit(1)

cid = data.get("conversation_id", "")
if cid and conv_path:
    with open(conv_path, "w") as cf:
        cf.write(cid)

status = data.get("status", "")
resp = data.get("response", "")
if status != "SUCCESS":
    err = data.get("error", "unknown error")
    print(f"agy-exec error ({status}): {err}", file=sys.stderr)
    if not resp:
        sys.exit(1)

print(resp)
PY
}

case "$CMD" in
  new)
    file="${1:?usage: agy-exec.sh <slug> new <file>}"
    if running; then
      echo "agy-exec: a turn is already running for $SLUG" >&2
      exit 1
    fi
    if [ ! -r "$file" ]; then
      echo "agy-exec: prompt file is not readable: $file" >&2
      exit 1
    fi
    rm -f "$CONV"
    run_turn "$file" new || exit 1
    ;;
  resume)
    file="${1:?usage: agy-exec.sh <slug> resume <file>}"
    if [ ! -s "$CONV" ]; then
      echo "agy-exec: no conversation for $SLUG, run 'new' first" >&2
      exit 1
    fi
    run_turn "$file" resume || exit 1
    ;;
  conversation|thread)
    if [ -s "$CONV" ]; then cat "$CONV"; else echo "no conversation"; fi
    ;;
  status)
    if running; then echo "running (pid $(cat "$PIDF"))"; else echo "not running"; fi
    ;;
  stop)
    if running; then kill "$(cat "$PIDF")" 2>/dev/null; fi
    rm -rf "$DIR"
    echo "stopped"
    ;;
  *)
    echo "unknown command: $CMD" >&2
    exit 1
    ;;
esac
