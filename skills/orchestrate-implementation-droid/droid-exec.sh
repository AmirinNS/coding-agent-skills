#!/usr/bin/env bash
# droid-exec.sh - drive one `droid exec` session per phase for orchestration.
#
# Usage: droid-exec.sh <slug> <command> [args...]
#
# Commands:
#   new <file> [auto]      start a fresh session with the file as the prompt, wait for
#                          the turn to end, print Droid's final message
#   resume <file> [auto]   send the file as the next prompt on the current session,
#                          wait for the turn to end, print Droid's final message
#   session                print the current session id
#   stop                   kill a running turn and remove all state
#
# `auto` is the autonomy level for the turn: none (default, read-only), low, medium,
# or high. It maps to `droid exec --auto <level>`; none omits the flag so the turn
# stays read-only. Implementation turns use medium (they edit and run checks); the
# read-only validate turn also uses medium because tests and builds need it, with
# the before-and-after diff as the read-only control. The helper never passes
# --skip-permissions-unsafe.
#
# State lives under ${TMPDIR:-/tmp}/droid-orch-<slug>/. events.jsonl holds the last
# turn's stream-json event stream if you need to inspect commands Droid ran.
# last.txt holds the extracted final message. usage.json holds the turn's usage
# counters from the terminal event when present. cli-version.txt and cli-path.txt
# identify the CLI used for that turn. session holds the session id used by resume.
#
# Droid autonomy medium permits local git commits, so prompts forbid staging and
# commits and review rechecks the Git baseline. Never bypass permission checks to
# get a check to pass.
#
# `new` and `resume` exit 1 when droid fails, or when its event stream stays silent
# for DROID_EXEC_IDLE_TIMEOUT seconds (default 600), so a stalled turn cannot hang
# the caller. Set DROID_ORCH_MODEL to override the model.

set -u

IDLE_TIMEOUT="${DROID_EXEC_IDLE_TIMEOUT:-600}"

SLUG="${1:?usage: droid-exec.sh <slug> <command> [args]}"; shift
CMD="${1:?command required}"; shift || true

if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "droid-exec: slug must contain lowercase letters, digits, and single hyphens" >&2
  exit 1
fi
if [[ ! "$IDLE_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "droid-exec: DROID_EXEC_IDLE_TIMEOUT must be a positive integer" >&2
  exit 1
fi

DIR="${TMPDIR:-/tmp}/droid-orch-$SLUG"
EVENTS="$DIR/events.jsonl"
LAST="$DIR/last.txt"
ERR="$DIR/err.log"
USAGE="$DIR/usage.json"
SESSION="$DIR/session"
PIDF="$DIR/pid"

running() {
  [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null
}

events_size() {
  wc -c < "$EVENTS" | tr -d ' '
}

check_auto() {
  case "${1:-none}" in
    none|low|medium|high) ;;
    *)
      echo "droid-exec: auto must be none, low, medium, or high" >&2
      return 1
      ;;
  esac
}

save_session_id() {
  # Every stream-json event observed so far carries "session_id"; the first one
  # is the system init event of the turn.
  local id
  id=$(python3 - "$EVENTS" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    try:
        e = json.loads(line)
    except Exception:
        continue
    sid = e.get("session_id")
    if sid:
        print(sid)
        break
PY
)
  if [ -n "$id" ]; then echo "$id" > "$SESSION"; fi
}

extract_result() {
  # Print the terminal event's text to last.txt and its usage counters to
  # usage.json. The observed terminal event is `completion` with `finalText`
  # (live-verified 2026-10-29); the documented `json` envelope uses `result`.
  # Accept either type and the common text fields. When no terminal event
  # exists, fall back to the last error message.
  python3 - "$EVENTS" "$LAST" "$USAGE" <<'PY'
import json, sys
events_path, last_path, usage_path = sys.argv[1:4]
events = []
for line in open(events_path):
    try:
        events.append(json.loads(line))
    except Exception:
        continue
text = ""
usage = None
for e in reversed(events):
    if e.get("type") in ("completion", "result"):
        text = e.get("finalText") or e.get("result") or e.get("text") or e.get("message") or ""
        usage = e.get("usage")
        break
if not text:
    for e in reversed(events):
        if e.get("type") == "error":
            text = e.get("message") or ""
            break
with open(last_path, "w") as f:
    f.write(text)
if usage:
    with open(usage_path, "w") as f:
        json.dump(usage, f)
PY
}

run_turn() {
  # Usage: run_turn <prompt-file> <auto> <droid exec args...>
  # The prompt goes in with -f so its size and quoting never matter.
  local file="$1" auto="$2"; shift 2
  if running; then
    echo "droid-exec: a turn is already running for $SLUG" >&2
    return 1
  fi
  if [ ! -r "$file" ]; then
    echo "droid-exec: prompt file is not readable: $file" >&2
    return 1
  fi
  mkdir -p "$DIR"
  : > "$EVENTS"; : > "$LAST"; : > "$ERR"; : > "$USAGE"
  command -v droid > "$DIR/cli-path.txt"
  if ! droid --version > "$DIR/cli-version.txt" 2>> "$ERR"; then
    echo "droid-exec: cannot record Droid CLI version" >&2
    tail -n 5 "$ERR" >&2
    return 1
  fi
  local opts=(-o stream-json -f "$file")
  case "$auto" in
    none) ;;
    low|medium|high) opts+=(--auto "$auto") ;;
  esac
  if [ -n "${DROID_ORCH_MODEL:-}" ]; then
    opts+=(-m "$DROID_ORCH_MODEL")
  fi
  droid exec "${opts[@]}" "$@" > "$EVENTS" 2>> "$ERR" &
  local pid=$!
  echo "$pid" > "$PIDF"

  local last_size idle=0 size rc
  last_size=$(events_size)
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    size=$(events_size)
    if [ "$size" != "$last_size" ]; then
      last_size="$size"
      idle=0
    else
      idle=$(( idle + 1 ))
      if [ "$idle" -ge "$IDLE_TIMEOUT" ]; then
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        rm -f "$PIDF"
        save_session_id
        extract_result
        echo "droid-exec: no events for ~${IDLE_TIMEOUT}s, turn killed" >&2
        cat "$LAST"; echo
        return 1
      fi
    fi
  done
  wait "$pid"
  rc=$?
  rm -f "$PIDF"
  save_session_id
  extract_result
  cat "$LAST"; echo
  if [ "$rc" -ne 0 ]; then
    echo "droid-exec: droid exited $rc" >&2
    tail -n 5 "$ERR" >&2
    return 1
  fi
}

case "$CMD" in
  new)
    file="${1:?usage: droid-exec.sh <slug> new <file> [auto]}"
    auto="${2:-none}"
    check_auto "$auto" || exit 1
    if running; then
      echo "droid-exec: a turn is already running for $SLUG" >&2
      exit 1
    fi
    if [ ! -r "$file" ]; then
      echo "droid-exec: prompt file is not readable: $file" >&2
      exit 1
    fi
    rm -f "$SESSION"
    run_turn "$file" "$auto" || exit 1
    ;;
  resume)
    file="${1:?usage: droid-exec.sh <slug> resume <file> [auto]}"
    auto="${2:-none}"
    check_auto "$auto" || exit 1
    if [ ! -s "$SESSION" ]; then
      echo "droid-exec: no session for $SLUG, run 'new' first" >&2
      exit 1
    fi
    run_turn "$file" "$auto" -s "$(cat "$SESSION")" || exit 1
    ;;
  session)
    if [ -s "$SESSION" ]; then cat "$SESSION"; else echo "no session"; fi
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
