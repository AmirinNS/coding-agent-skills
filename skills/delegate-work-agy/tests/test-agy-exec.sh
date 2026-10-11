#!/usr/bin/env bash
# Exercise Antigravity helpers against a mock agy binary: no auth, no network, no live run.
#
# Runnable from either agy skill directory. It checks this skill's own helper first,
# then the sibling skill's helper when that skill is installed alongside.
set -eu

SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/state"
export TMPDIR="$TEST_DIR/state"
export PATH="$TEST_DIR/bin:$PATH"
export MOCK_ARGS="$TEST_DIR/args"

cat > "$TEST_DIR/bin/agy" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$@" >> "$MOCK_ARGS"
if [ "${1:-}" = '--version' ]; then
  if [ "${MOCK_VERSION_FAIL:-}" = '1' ]; then
    echo 'mock version failure' >&2
    exit 3
  fi
  echo "${MOCK_VERSION:-1.3.3}"
  exit 0
fi

log_file=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [ "${args[i]}" = '--log-file' ] && [ $((i+1)) -lt ${#args[@]} ]; then
    log_file="${args[i+1]}"
    break
  fi
done

if [ -n "$log_file" ]; then
  echo "mock agy log line" >> "$log_file"
fi

if [ "${MOCK_MODE:-}" = 'idle' ]; then
  sleep 3
  exit 0
fi

if [ "${MOCK_MODE:-}" = 'fail' ]; then
  echo 'mock agy error' >&2
  exit 2
fi

printf '%s\n' '{"conversation_id":"test-conv-1","status":"SUCCESS","response":"{\"status\":\"done\",\"summary\":\"mock result\"}"}'
MOCK
chmod +x "$TEST_DIR/bin/agy"
printf 'A prompt with spaces and literal $variables\n' > "$TEST_DIR/prompt"

helper() {
  bash "$SKILL_DIR/agy-exec.sh" "$@"
}

expect_failure() {
  if helper "$@" > "$TEST_DIR/out" 2> "$TEST_DIR/err"; then
    echo "Expected failure for $*" >&2
    exit 1
  fi
}

# 1. Input guards
expect_failure missing resume "$TEST_DIR/prompt"
grep -q 'no conversation' "$TEST_DIR/err"
expect_failure '../escape' stop
grep -q 'slug must contain' "$TEST_DIR/err"
AGY_EXEC_IDLE_TIMEOUT=0 expect_failure invalid stop
grep -q 'positive integer' "$TEST_DIR/err"
expect_failure unreadable new "$TEST_DIR/absent"
grep -q 'prompt file is not readable' "$TEST_DIR/err"

# 2. Basic turn, conversation ID, and resume
AGY_ORCH_MODEL=test-model helper happy new "$TEST_DIR/prompt" > "$TEST_DIR/out"
grep -q 'mock result' "$TEST_DIR/out"
test "$(helper happy conversation)" = 'test-conv-1'
test "$(helper happy thread)" = 'test-conv-1'
grep -q -- '--dangerously-skip-permissions' "$MOCK_ARGS"
grep -q -- '--output-format' "$MOCK_ARGS"
grep -q 'test-model' "$MOCK_ARGS"

helper happy resume "$TEST_DIR/prompt" > "$TEST_DIR/out"
grep -q -- '--conversation' "$MOCK_ARGS"
grep -q 'test-conv-1' "$MOCK_ARGS"
expect_failure happy new "$TEST_DIR/absent"
test "$(helper happy conversation)" = 'test-conv-1'

# 3. Reject turn when worker is already running
printf '%s\n' "$$" > "$TMPDIR/agy-work-happy/pid"
expect_failure happy new "$TEST_DIR/prompt"
grep -q 'already running' "$TEST_DIR/err"
test "$(helper happy conversation)" = 'test-conv-1'
rm "$TMPDIR/agy-work-happy/pid"

# 4. Handle turn failure
MOCK_MODE=fail expect_failure failed new "$TEST_DIR/prompt"
grep -q 'agy exited 2' "$TEST_DIR/err"
grep -q 'mock agy error' "$TEST_DIR/err"

# 5. Handle idle timeout
MOCK_MODE=idle AGY_EXEC_IDLE_TIMEOUT=1 expect_failure idle new "$TEST_DIR/prompt"
grep -q 'turn killed' "$TEST_DIR/err"
test ! -e "$TMPDIR/agy-work-idle/pid"

# 6. Stop cleans up state
helper happy stop > "$TEST_DIR/out"
test ! -e "$TMPDIR/agy-work-happy"
test "$(helper happy conversation)" = 'no conversation'

# 7. Check sibling plan helper too when both skills are present, verifying CLI identity
printf '%s\n' '1.3.3' > "$TEST_DIR/expected-version"
printf '%s\n' "$TEST_DIR/bin/agy" > "$TEST_DIR/expected-path"

for skill_path in "$SKILL_DIR" "$SKILL_DIR/../orchestrate-implementation-agy"; do
  [ -f "$skill_path/agy-exec.sh" ] || continue
  if [ "$skill_path" = "$SKILL_DIR" ]; then prefix=agy-work; else prefix=agy-orch; fi

  bash "$skill_path/agy-exec.sh" versioned new "$TEST_DIR/prompt" > "$TEST_DIR/out"
  cmp "$TEST_DIR/expected-version" "$TMPDIR/$prefix-versioned/cli-version.txt"
  cmp "$TEST_DIR/expected-path" "$TMPDIR/$prefix-versioned/cli-path.txt"

  MOCK_VERSION='1.3.4' bash "$skill_path/agy-exec.sh" versioned resume "$TEST_DIR/prompt" > "$TEST_DIR/out"
  test "$(cat "$TMPDIR/$prefix-versioned/cli-version.txt")" = '1.3.4'

  : > "$MOCK_ARGS"
  if MOCK_VERSION_FAIL=1 bash "$skill_path/agy-exec.sh" version-failed new "$TEST_DIR/prompt" > "$TEST_DIR/out" 2> "$TEST_DIR/err"; then
    echo "Expected version capture failure for $prefix" >&2
    exit 1
  fi
  grep -q 'mock version failure' "$TEST_DIR/err"
  if grep -q -- '--print' "$MOCK_ARGS"; then
    echo "Worker started despite failed version capture on $prefix" >&2
    exit 1
  fi

  bash "$skill_path/agy-exec.sh" versioned stop > "$TEST_DIR/out"
  test ! -e "$TMPDIR/$prefix-versioned"
done

echo 'PASS: input guards, turns, resume, timeout, stop, and CLI identity on agy helpers'
