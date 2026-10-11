#!/usr/bin/env bash
# pi-work.sh - drive one persistent `pi --mode rpc` worker session per bounded assignment.
#
# Usage: pi-work.sh <slug> <command> [args...]
#
# Commands:
#   new <file>       stop any worker running for this slug, start a fresh pi
#                    session, send the file as its first prompt, wait for
#                    agent_settled, print the final assistant text
#   resume <file>    send the file as the next prompt on the current session,
#                    wait for agent_settled, print the final assistant text
#   compact [instr]  compact the current session, optionally with instructions
#   send <json>       send a raw RPC command, wait for its response, print it
#   session          print the current session id
#   stop             kill the worker and remove all state
#
# State lives under ${TMPDIR:-/tmp}/pi-work-<slug>/. events.jsonl there holds the
# last turn's event stream if you need to inspect commands the worker ran.
#
# pi runs with no sandbox, so the worker can run any command, including git. The
# dispatch prompt forbids staging and commits, and review rechecks the Git
# baseline (HEAD and the index) to catch a violation.
#
# `new`, `resume`, and `compact` exit 1 when the session dies or the event stream
# goes silent for PI_WORK_IDLE_TIMEOUT seconds (default 600), so a stalled worker
# cannot hang the caller. Set PI_ORCH_MODEL to override the model. It accepts a
# "provider/id" pattern with an optional ":<thinking>" suffix.

set -u

IDLE_TIMEOUT="${PI_WORK_IDLE_TIMEOUT:-600}"

SLUG="${1:?usage: pi-work.sh <slug> <command> [args]}"; shift
CMD="${1:?command required}"; shift || true

if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "pi-work: slug must contain lowercase letters, digits, and single hyphens" >&2
  exit 1
fi
if [[ ! "$IDLE_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "pi-work: PI_WORK_IDLE_TIMEOUT must be a positive integer" >&2
  exit 1
fi

DIR="${TMPDIR:-/tmp}/pi-work-$SLUG"
CMDS="$DIR/cmds.log"
EVENTS="$DIR/events.jsonl"
ERR="$DIR/err.log"
PIDF="$DIR/pid"
SESSION="$DIR/session"
GEN="$DIR/gen"

OPTS=()
if [ -n "${PI_ORCH_MODEL:-}" ]; then
  OPTS+=(--model "$PI_ORCH_MODEL")
fi

py_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

running() {
  [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null
}

record_cli_identity() {
  # Capture the runtime identity before dispatch. A failed version check stops the
  # turn instead of running pi with an unknown CLI.
  command -v pi > "$DIR/cli-path.txt"
  if ! pi --version > "$DIR/cli-version.txt" 2>> "$ERR"; then
    echo "pi-work: cannot record pi CLI version" >&2
    tail -n 5 "$ERR" >&2
    return 1
  fi
}

kill_worker() {
  if running; then kill "$(cat "$PIDF")" 2>/dev/null || true; fi
  pkill -f "tail -f $CMDS" 2>/dev/null || true
  if [ -s "$SESSION" ]; then
    pkill -f "pi --mode rpc --session-id $(cat "$SESSION")" 2>/dev/null || true
  fi
  rm -f "$PIDF"
}

start_session() {
  # Usage: start_session <session-id>. Session files live in $DIR, so `stop`
  # leaves no history behind and a later run starts clean.
  local sid="$1"
  kill_worker
  mkdir -p "$DIR"
  : > "$CMDS"; : > "$EVENTS"; : > "$ERR"
  echo "$sid" > "$SESSION"
  # tail -f keeps stdin open; pi exits on stdin EOF otherwise.
  tail -f "$CMDS" | pi --mode rpc --session-id "$sid" --session-dir "$DIR" -a \
    ${OPTS[@]+"${OPTS[@]}"} > "$EVENTS" 2> "$ERR" &
  echo $! > "$PIDF"
  sleep 3
}

next_session_id() {
  # A fresh assignment must not inherit the previous one's context, so every
  # `new` gets its own session id.
  local n=1
  mkdir -p "$DIR"
  [ -f "$GEN" ] && n=$(( $(cat "$GEN") + 1 ))
  echo "$n" > "$GEN"
  if [ "$n" -gt 1 ]; then echo "delegate-$SLUG-$n"; else echo "delegate-$SLUG"; fi
}

events_size() {
  wc -c < "$EVENTS" | tr -d ' '
}

wait_from() {
  # Poll from line $1 for a substring; print new lines up to the match.
  # Returns 1 if pi exits first, or if the event stream stays silent for
  # IDLE_TIMEOUT polls, so a dead or stalled worker cannot hang the caller.
  local start="$1" pattern="$2"
  local last_size idle=0 size
  last_size=$(events_size)
  while :; do
    if tail -n +"$start" "$EVENTS" | grep -q "$pattern"; then
      tail -n +"$start" "$EVENTS" | awk -v p="$pattern" '{ print; if (index($0, p)) exit }'
      return 0
    fi
    if ! running; then
      echo "pi-work: session $(cat "$SESSION" 2>/dev/null) died while waiting for $pattern" >&2
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
        echo "pi-work: no events for ~${IDLE_TIMEOUT}s while waiting for $pattern" >&2
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

run_prompt() {
  local file="$1"
  if ! running; then
    echo "pi-work: no session for $SLUG, run 'new' first" >&2
    return 1
  fi
  if [ ! -r "$file" ]; then
    echo "pi-work: prompt file is not readable: $file" >&2
    return 1
  fi
  record_cli_identity || return 1
  local start_line msg
  start_line=$(( $(wc -l < "$EVENTS") + 1 ))
  msg=$(py_json "$(cat "$file")")
  printf '{"type":"prompt","message":%s}\n' "$msg" >> "$CMDS"
  if ! wait_from "$start_line" '"type":"agent_settled"' > /dev/null; then
    final_text
    return 1
  fi
  final_text
}

case "$CMD" in
  new)
    file="${1:?usage: pi-work.sh <slug> new <file>}"
    if [ ! -r "$file" ]; then
      echo "pi-work: prompt file is not readable: $file" >&2
      exit 1
    fi
    start_session "$(next_session_id)"
    run_prompt "$file" || exit 1
    ;;
  resume)
    file="${1:?usage: pi-work.sh <slug> resume <file>}"
    run_prompt "$file" || exit 1
    ;;
  compact)
    if ! running; then
      echo "pi-work: no session for $SLUG, run 'new' first" >&2
      exit 1
    fi
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
    json="${1:?usage: pi-work.sh <slug> send '<json>'}"
    if ! running; then
      echo "pi-work: no session for $SLUG, run 'new' first" >&2
      exit 1
    fi
    name=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("type",""))' "$json" 2>/dev/null)
    if [ -z "$name" ]; then
      echo "pi-work: send expects one JSON object with a type field" >&2
      exit 1
    fi
    start_line=$(( $(wc -l < "$EVENTS") + 1 ))
    printf '%s\n' "$json" >> "$CMDS"
    # Every response carries "command":"<the type you sent>".
    wait_from "$start_line" "\"command\":\"$name\"" || exit 1
    ;;
  session)
    if [ -s "$SESSION" ]; then cat "$SESSION"; else echo "no session"; fi
    ;;
  stop)
    kill_worker
    rm -rf "$DIR"
    echo "stopped"
    ;;
  *)
    echo "unknown command: $CMD" >&2
    exit 1
    ;;
esac
