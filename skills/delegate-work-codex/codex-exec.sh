#!/usr/bin/env bash
# codex-exec.sh - drive one `codex exec` thread per bounded assignment.
#
# Usage: codex-exec.sh <slug> <command> [args...]
#
# Commands:
#   new <file>       start a fresh thread with the file as the prompt, wait for
#                    the turn to end, print Codex's final message
#   resume <file>    send the file as the next prompt on the current thread,
#                    wait for the turn to end, print Codex's final message
#   thread           print the current thread id
#   stop             kill a running turn and remove all state
#
# State lives under ${TMPDIR:-/tmp}/codex-work-<slug>/. events.jsonl there holds
# the last turn's event stream if you need to inspect commands Codex ran.
# cli-version.txt and cli-path.txt identify the CLI used for that turn.
#
# Codex runs in the workspace-write sandbox. Network access uses the existing
# configuration. Prompts forbid staging and commits; review checks the Git baseline.
#
# `new` and `resume` exit 1 when codex fails, or when its event stream stays
# silent for CODEX_EXEC_IDLE_TIMEOUT seconds (default 600), so a stalled turn
# cannot hang the caller. Set CODEX_ORCH_MODEL to override the model.

set -u

IDLE_TIMEOUT="${CODEX_EXEC_IDLE_TIMEOUT:-600}"

SLUG="${1:?usage: codex-exec.sh <slug> <command> [args]}"; shift
CMD="${1:?command required}"; shift || true

if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "codex-exec: slug must contain lowercase letters, digits, and single hyphens" >&2
  exit 1
fi
if [[ ! "$IDLE_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "codex-exec: CODEX_EXEC_IDLE_TIMEOUT must be a positive integer" >&2
  exit 1
fi

DIR="${TMPDIR:-/tmp}/codex-work-$SLUG"
EVENTS="$DIR/events.jsonl"
LAST="$DIR/last.txt"
ERR="$DIR/err.log"
THREAD="$DIR/thread"
PIDF="$DIR/pid"

OPTS=(--json -o "$LAST" --skip-git-repo-check
      -c 'sandbox_mode="workspace-write"')
if [ -n "${CODEX_ORCH_MODEL:-}" ]; then
  OPTS+=(-m "$CODEX_ORCH_MODEL")
fi

running() {
  [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null
}

events_size() {
  wc -c < "$EVENTS" | tr -d ' '
}

save_thread_id() {
  # The first event of every turn is {"type":"thread.started","thread_id":...}.
  local id
  id=$(python3 - "$EVENTS" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    try:
        e = json.loads(line)
    except Exception:
        continue
    if e.get("type") == "thread.started":
        print(e.get("thread_id", ""))
        break
PY
)
  if [ -n "$id" ]; then echo "$id" > "$THREAD"; fi
}

run_turn() {
  # Usage: run_turn <prompt-file> <codex exec args...>
  # The prompt goes in on stdin so its size and quoting never matter.
  local file="$1"; shift
  if running; then
    echo "codex-exec: a turn is already running for $SLUG" >&2
    return 1
  fi
  if [ ! -r "$file" ]; then
    echo "codex-exec: prompt file is not readable: $file" >&2
    return 1
  fi
  mkdir -p "$DIR"
  : > "$EVENTS"; : > "$LAST"; : > "$ERR"
  command -v codex > "$DIR/cli-path.txt"
  if ! codex --version > "$DIR/cli-version.txt" 2>> "$ERR"; then
    echo "codex-exec: cannot record Codex CLI version" >&2
    tail -n 5 "$ERR" >&2
    return 1
  fi
  codex exec "$@" < "$file" > "$EVENTS" 2>> "$ERR" &
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
        save_thread_id
        echo "codex-exec: no events for ~${IDLE_TIMEOUT}s, turn killed" >&2
        cat "$LAST"; echo
        return 1
      fi
    fi
  done
  wait "$pid"
  rc=$?
  rm -f "$PIDF"
  save_thread_id
  cat "$LAST"; echo
  if [ "$rc" -ne 0 ]; then
    echo "codex-exec: codex exited $rc" >&2
    tail -n 5 "$ERR" >&2
    return 1
  fi
}

case "$CMD" in
  new)
    file="${1:?usage: codex-exec.sh <slug> new <file>}"
    if running; then
      echo "codex-exec: a turn is already running for $SLUG" >&2
      exit 1
    fi
    if [ ! -r "$file" ]; then
      echo "codex-exec: prompt file is not readable: $file" >&2
      exit 1
    fi
    rm -f "$THREAD"
    run_turn "$file" "${OPTS[@]}" - || exit 1
    ;;
  resume)
    file="${1:?usage: codex-exec.sh <slug> resume <file>}"
    if [ ! -s "$THREAD" ]; then
      echo "codex-exec: no thread for $SLUG, run 'new' first" >&2
      exit 1
    fi
    run_turn "$file" resume "${OPTS[@]}" "$(cat "$THREAD")" - || exit 1
    ;;
  thread)
    if [ -s "$THREAD" ]; then cat "$THREAD"; else echo "no thread"; fi
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
