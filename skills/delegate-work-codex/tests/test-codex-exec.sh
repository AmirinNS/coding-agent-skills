#!/usr/bin/env bash
# Exercise thread handling without authentication, network access, or a real Codex run.
set -eu

SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/state"
export TMPDIR="$TEST_DIR/state"
export PATH="$TEST_DIR/bin:$PATH"
export MOCK_ARGS="$TEST_DIR/args"

cat > "$TEST_DIR/bin/codex" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$@" >> "$MOCK_ARGS"
if [ "${1:-}" = '--version' ]; then
  if [ "${MOCK_VERSION_FAIL:-}" = '1' ]; then
    echo 'mock version failure' >&2
    exit 3
  fi
  echo "${MOCK_VERSION:-codex-cli 0.162.1}"
  exit 0
fi
last=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-o' ]; then last="$2"; shift; fi
  shift
done
cat > "$MOCK_ARGS.prompt"
if [ "${MOCK_MODE:-}" = 'idle' ]; then
  sleep 3
  exit 0
fi
printf '%s\n' '{"type":"thread.started","thread_id":"test-thread-1"}'
if [ "${MOCK_MODE:-}" = 'fail' ]; then
  echo 'mock authentication failure' >&2
  exit 2
fi
printf '%s\n' '{"status":"done","summary":"mock result"}' > "$last"
MOCK
chmod +x "$TEST_DIR/bin/codex"
printf 'A prompt with spaces and literal $variables\n' > "$TEST_DIR/prompt"

helper() {
  bash "$SKILL_DIR/codex-exec.sh" "$@"
}

expect_failure() {
  if helper "$@" > "$TEST_DIR/out" 2> "$TEST_DIR/err"; then
    echo "Expected failure for $*" >&2
    exit 1
  fi
}

expect_failure missing resume "$TEST_DIR/prompt"
grep -q 'no thread' "$TEST_DIR/err"
expect_failure '../escape' stop
grep -q 'slug must contain' "$TEST_DIR/err"
CODEX_EXEC_IDLE_TIMEOUT=0 expect_failure invalid thread
grep -q 'positive integer' "$TEST_DIR/err"
expect_failure unreadable new "$TEST_DIR/absent"
grep -q 'prompt file is not readable' "$TEST_DIR/err"

CODEX_ORCH_MODEL=test-model helper happy new "$TEST_DIR/prompt" > "$TEST_DIR/out"
grep -q 'mock result' "$TEST_DIR/out"
test "$(helper happy thread)" = 'test-thread-1'
cmp "$TEST_DIR/prompt" "$MOCK_ARGS.prompt"
grep -q -- '--skip-git-repo-check' "$MOCK_ARGS"
grep -q 'sandbox_mode="workspace-write"' "$MOCK_ARGS"
grep -q 'test-model' "$MOCK_ARGS"
if grep -Eq 'network_access=true|danger-full-access|dangerously-bypass' "$MOCK_ARGS"; then
  echo 'Helper widened sandbox permissions' >&2
  exit 1
fi

helper happy resume "$TEST_DIR/prompt" > "$TEST_DIR/out"
grep -q '^resume$' "$MOCK_ARGS"
grep -q '^test-thread-1$' "$MOCK_ARGS"
expect_failure happy new "$TEST_DIR/absent"
test "$(helper happy thread)" = 'test-thread-1'

# Reject a new turn without destroying the resumable thread of an active worker.
printf '%s\n' "$$" > "$TMPDIR/codex-work-happy/pid"
expect_failure happy new "$TEST_DIR/prompt"
grep -q 'already running' "$TEST_DIR/err"
test "$(helper happy thread)" = 'test-thread-1'
rm "$TMPDIR/codex-work-happy/pid"

MOCK_MODE=fail expect_failure failed new "$TEST_DIR/prompt"
grep -q 'codex exited 2' "$TEST_DIR/err"
grep -q 'mock authentication failure' "$TEST_DIR/err"
test "$(helper failed thread)" = 'test-thread-1'

MOCK_MODE=idle CODEX_EXEC_IDLE_TIMEOUT=1 expect_failure idle new "$TEST_DIR/prompt"
grep -q 'turn killed' "$TEST_DIR/err"
test ! -e "$TMPDIR/codex-work-idle/pid"

helper happy stop > "$TEST_DIR/out"
test ! -e "$TMPDIR/codex-work-happy"
test "$(helper happy thread)" = 'no thread'

# Check the sibling plan helper too when both skills are present.
printf '%s\n' 'codex-cli 0.162.1' > "$TEST_DIR/expected-version"
printf '%s\n' "$TEST_DIR/bin/codex" > "$TEST_DIR/expected-path"
for skill_path in "$SKILL_DIR" "$SKILL_DIR/../orchestrate-implementation-codex"; do
  [ -f "$skill_path/codex-exec.sh" ] || continue
  if [ "$skill_path" = "$SKILL_DIR" ]; then prefix=codex-work; else prefix=codex-orch; fi
  bash "$skill_path/codex-exec.sh" versioned new "$TEST_DIR/prompt" > "$TEST_DIR/out"
  cmp "$TEST_DIR/expected-version" "$TMPDIR/$prefix-versioned/cli-version.txt"
  cmp "$TEST_DIR/expected-path" "$TMPDIR/$prefix-versioned/cli-path.txt"
  MOCK_VERSION='codex-cli 0.163.0' bash "$skill_path/codex-exec.sh" versioned resume "$TEST_DIR/prompt" > "$TEST_DIR/out"
  test "$(cat "$TMPDIR/$prefix-versioned/cli-version.txt")" = 'codex-cli 0.163.0'
  : > "$MOCK_ARGS"
  if MOCK_VERSION_FAIL=1 bash "$skill_path/codex-exec.sh" version-failed new "$TEST_DIR/prompt" > "$TEST_DIR/out" 2> "$TEST_DIR/err"; then
    echo 'Expected version capture failure' >&2
    exit 1
  fi
  grep -q 'mock version failure' "$TEST_DIR/err"
  if grep -q '^exec$' "$MOCK_ARGS"; then
    echo 'Worker started despite failed version capture' >&2
    exit 1
  fi
  bash "$skill_path/codex-exec.sh" versioned stop > "$TEST_DIR/out"
  test ! -e "$TMPDIR/$prefix-versioned"
done
echo 'PASS: thread handling, guards, failure, timeout, and CLI identity on available helpers'
