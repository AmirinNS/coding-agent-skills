#!/usr/bin/env bash
# Exercise session handling without authentication, network access, or a real Droid run.
set -eu

SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/state"
export TMPDIR="$TEST_DIR/state"
export PATH="$TEST_DIR/bin:$PATH"
export MOCK_ARGS="$TEST_DIR/args"

cat > "$TEST_DIR/bin/droid" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$@" >> "$MOCK_ARGS"
if [ "${1:-}" = '--version' ]; then
  if [ "${MOCK_VERSION_FAIL:-}" = '1' ]; then
    echo 'mock version failure' >&2
    exit 3
  fi
  echo "${MOCK_VERSION:-droid 0.251.0}"
  exit 0
fi
file=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-f' ]; then file="$2"; shift; fi
  shift
done
if [ -n "$file" ]; then cp "$file" "$MOCK_ARGS.prompt"; fi
if [ "${MOCK_MODE:-}" = 'idle' ]; then
  sleep 3
  exit 0
fi
printf '%s\n' '{"type":"system","subtype":"init","cwd":"/mock","session_id":"test-session-1","tools":[],"model":"mock-model","reasoning_effort":"high"}'
if [ "${MOCK_MODE:-}" = 'fail' ]; then
  printf '%s\n' '{"type":"error","source":"agent_loop","message":"mock authentication failure","session_id":"test-session-1"}'
  echo 'mock authentication failure' >&2
  exit 2
fi
printf '%s\n' '{"type":"message","role":"assistant","text":"mock thinking","session_id":"test-session-1"}'
if [ "${MOCK_TERMINAL:-}" = 'result' ]; then
  printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":"mock result","session_id":"test-session-1","usage":{"input_tokens":4,"output_tokens":18}}'
else
  # Shape observed live on 2026-10-29: completion carries finalText and usage.
  printf '%s\n' '{"type":"completion","finalText":"mock result","numTurns":1,"durationMs":1,"session_id":"test-session-1","usage":{"input_tokens":4,"output_tokens":18}}'
fi
MOCK
chmod +x "$TEST_DIR/bin/droid"
printf 'A prompt with spaces and literal $variables\n' > "$TEST_DIR/prompt"

helper() {
  bash "$SKILL_DIR/droid-exec.sh" "$@"
}

expect_failure() {
  if helper "$@" > "$TEST_DIR/out" 2> "$TEST_DIR/err"; then
    echo "Expected failure for $*" >&2
    exit 1
  fi
}

expect_failure missing resume "$TEST_DIR/prompt"
grep -q 'no session' "$TEST_DIR/err"
expect_failure '../escape' stop
grep -q 'slug must contain' "$TEST_DIR/err"
DROID_EXEC_IDLE_TIMEOUT=0 expect_failure invalid session
grep -q 'positive integer' "$TEST_DIR/err"
expect_failure unreadable new "$TEST_DIR/absent"
grep -q 'prompt file is not readable' "$TEST_DIR/err"
expect_failure badauto new "$TEST_DIR/prompt" wrong
grep -q 'auto must be' "$TEST_DIR/err"
expect_failure badauto resume "$TEST_DIR/prompt" wrong
grep -q 'auto must be' "$TEST_DIR/err"

DROID_ORCH_MODEL=test-model helper happy new "$TEST_DIR/prompt" medium > "$TEST_DIR/out"
grep -q 'mock result' "$TEST_DIR/out"
test "$(helper happy session)" = 'test-session-1'
cmp "$TEST_DIR/prompt" "$MOCK_ARGS.prompt"
grep -q '^medium$' "$MOCK_ARGS"
grep -q '^test-model$' "$MOCK_ARGS"
grep -q '"input_tokens": 4' "$TMPDIR/droid-work-happy/usage.json"
if grep -Eq 'skip-permissions-unsafe|danger-full-access|dangerously-bypass' "$MOCK_ARGS"; then
  echo 'Helper bypassed permission checks' >&2
  exit 1
fi

# A default (none) turn passes no --auto flag and stays read-only.
: > "$MOCK_ARGS"
helper happy resume "$TEST_DIR/prompt" > "$TEST_DIR/out"
grep -q '^-s$' "$MOCK_ARGS"
grep -q '^test-session-1$' "$MOCK_ARGS"
if grep -q -- '--auto' "$MOCK_ARGS"; then
  echo 'Default turn must not set --auto' >&2
  exit 1
fi
grep -q 'mock result' "$TEST_DIR/out"

# The documented json result envelope parses as a terminal event too.
: > "$MOCK_ARGS"
MOCK_TERMINAL=result helper result-type new "$TEST_DIR/prompt" low > "$TEST_DIR/out"
grep -q 'mock result' "$TEST_DIR/out"
grep -q '^low$' "$MOCK_ARGS"

expect_failure happy new "$TEST_DIR/absent"
test "$(helper happy session)" = 'test-session-1'

# Reject a new turn without destroying the resumable session of an active worker.
printf '%s\n' "$$" > "$TMPDIR/droid-work-happy/pid"
expect_failure happy new "$TEST_DIR/prompt"
grep -q 'already running' "$TEST_DIR/err"
test "$(helper happy session)" = 'test-session-1'
rm "$TMPDIR/droid-work-happy/pid"

MOCK_MODE=fail expect_failure failed new "$TEST_DIR/prompt"
grep -q 'droid exited 2' "$TEST_DIR/err"
grep -q 'mock authentication failure' "$TEST_DIR/err"
grep -q 'mock authentication failure' "$TMPDIR/droid-work-failed/last.txt"
test "$(helper failed session)" = 'test-session-1'

MOCK_MODE=idle DROID_EXEC_IDLE_TIMEOUT=1 expect_failure idle new "$TEST_DIR/prompt"
grep -q 'turn killed' "$TEST_DIR/err"
test ! -e "$TMPDIR/droid-work-idle/pid"

helper happy stop > "$TEST_DIR/out"
test ! -e "$TMPDIR/droid-work-happy"
test "$(helper happy session)" = 'no session'

# Check the sibling plan helper too when both skills are present.
printf '%s\n' 'droid 0.251.0' > "$TEST_DIR/expected-version"
printf '%s\n' "$TEST_DIR/bin/droid" > "$TEST_DIR/expected-path"
for skill_path in "$SKILL_DIR" "$SKILL_DIR/../orchestrate-implementation-droid"; do
  [ -f "$skill_path/droid-exec.sh" ] || continue
  if [ "$skill_path" = "$SKILL_DIR" ]; then prefix=droid-work; else prefix=droid-orch; fi
  bash "$skill_path/droid-exec.sh" versioned new "$TEST_DIR/prompt" > "$TEST_DIR/out"
  cmp "$TEST_DIR/expected-version" "$TMPDIR/$prefix-versioned/cli-version.txt"
  cmp "$TEST_DIR/expected-path" "$TMPDIR/$prefix-versioned/cli-path.txt"
  MOCK_VERSION='droid 0.252.0' bash "$skill_path/droid-exec.sh" versioned resume "$TEST_DIR/prompt" > "$TEST_DIR/out"
  test "$(cat "$TMPDIR/$prefix-versioned/cli-version.txt")" = 'droid 0.252.0'
  : > "$MOCK_ARGS"
  if MOCK_VERSION_FAIL=1 bash "$skill_path/droid-exec.sh" version-failed new "$TEST_DIR/prompt" > "$TEST_DIR/out" 2> "$TEST_DIR/err"; then
    echo 'Expected version capture failure' >&2
    exit 1
  fi
  grep -q 'mock version failure' "$TEST_DIR/err"
  if grep -q '^exec$' "$MOCK_ARGS"; then
    echo 'Worker started despite failed version capture' >&2
    exit 1
  fi
  bash "$skill_path/droid-exec.sh" versioned stop > "$TEST_DIR/out"
  test ! -e "$TMPDIR/$prefix-versioned"
done
echo 'PASS: session handling, autonomy mapping, guards, failure, timeout, and CLI identity on available helpers'
