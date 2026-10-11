#!/usr/bin/env bash
# Exercise the pi helpers against a mock pi binary: no auth, no network, no live run.
#
# Runnable from either pi skill directory. It checks this skill's own helper first,
# then the sibling skill's helper when that skill is installed alongside. A missing
# sibling is not a failure.
set -eu

SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/state"
export TMPDIR="$TEST_DIR/state"
export PATH="$TEST_DIR/bin:$PATH"
export MOCK_CMDS="$TEST_DIR/cmds.txt"

cat > "$TEST_DIR/bin/pi" <<'MOCK'
#!/usr/bin/env bash
set -eu
if [ "${1:-}" = '--version' ]; then
  if [ "${MOCK_VERSION_FAIL:-}" = '1' ]; then
    echo 'mock version failure' >&2
    exit 3
  fi
  echo "${MOCK_VERSION:-0.85.1}"
  exit 0
fi
while IFS= read -r line; do
  echo "$line" >> "$MOCK_CMDS"
  if echo "$line" | grep -q '"type":"prompt"'; then
    echo '{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"{\"status\":\"done\",\"summary\":\"mock pass\"}"}]}}'
    echo '{"type":"agent_settled"}'
  elif echo "$line" | grep -q '"type":"compact"'; then
    echo '{"type":"response","command":"compact","success":true}'
  fi
done
MOCK
chmod +x "$TEST_DIR/bin/pi"

printf 'Test prompt content\n' > "$TEST_DIR/prompt.md"

# spec: <helper-path>:<state-prefix>:<session-id-prefix>:<idle-timeout-var>
HELPERS=""
add_helper() {
  local path="$1" prefix="$2" sid_prefix="$3" timeout_var="$4"
  [ -f "$path" ] || return 0
  case "$HELPERS" in
    *"$path"*) return 0 ;;
  esac
  HELPERS="${HELPERS}${path}:${prefix}:${sid_prefix}:${timeout_var}"$'\n'
}

# This skill's own helper, then the sibling when installed alongside it.
add_helper "$SKILL_DIR/pi-work.sh" pi-work delegate PI_WORK_IDLE_TIMEOUT
add_helper "$SKILL_DIR/pi-rpc.sh" pi-orch orchestrate PI_RPC_IDLE_TIMEOUT
add_helper "$SKILL_DIR/../delegate-work-pi/pi-work.sh" pi-work delegate PI_WORK_IDLE_TIMEOUT
add_helper "$SKILL_DIR/../orchestrate-implementation-pi/pi-rpc.sh" pi-orch orchestrate PI_RPC_IDLE_TIMEOUT

if [ -z "$HELPERS" ]; then
  echo "FAIL: no pi helper found next to this skill" >&2
  exit 1
fi

printf '%s\n' '0.85.1' > "$TEST_DIR/expected-version"
printf '%s\n' '0.86.0' > "$TEST_DIR/bumped-version"
printf '%s\n' "$TEST_DIR/bin/pi" > "$TEST_DIR/expected-path"

while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  IFS=':' read -r helper_script state_prefix sid_prefix timeout_var <<< "$spec"
  label=$(basename "$(dirname "$helper_script")")

  helper() { bash "$helper_script" "$@"; }
  expect_failure() {
    if helper "$@" > "$TEST_DIR/out" 2> "$TEST_DIR/err"; then
      echo "FAIL: $label accepted $*" >&2
      exit 1
    fi
  }

  # 1. Input guards
  expect_failure "bad_slug" stop
  grep -q 'slug must contain' "$TEST_DIR/err"
  # `env` cannot run a shell function, so call the helper directly here.
  if env "$timeout_var=0" bash "$helper_script" "guard-$label" stop >/dev/null 2>&1; then
    echo "FAIL: $label accepted an invalid timeout" >&2
    exit 1
  fi
  expect_failure "unreadable-$label" new "$TEST_DIR/absent"
  grep -q 'not readable' "$TEST_DIR/err"

  # 2. Fresh session per assignment or phase, resume, compact, stop
  slug="run-$label"
  state="$TMPDIR/$state_prefix-$slug"
  helper "$slug" new "$TEST_DIR/prompt.md" > "$TEST_DIR/out"
  grep -q 'mock pass' "$TEST_DIR/out"
  [ "$(helper "$slug" session)" = "$sid_prefix-$slug" ]

  helper "$slug" resume "$TEST_DIR/prompt.md" > "$TEST_DIR/out"
  grep -q 'mock pass' "$TEST_DIR/out"
  [ "$(helper "$slug" session)" = "$sid_prefix-$slug" ]

  helper "$slug" new "$TEST_DIR/prompt.md" > "$TEST_DIR/out"
  [ "$(helper "$slug" session)" = "$sid_prefix-$slug-2" ]

  helper "$slug" compact "preserve summary" >/dev/null
  helper "$slug" stop >/dev/null
  [ "$(helper "$slug" session)" = "no session" ]

  # 3. CLI identity: recorded before every executed turn, a version change across
  #    resume is visible, and a failed capture prevents dispatch.
  id_slug="id-$label"
  id_state="$TMPDIR/$state_prefix-$id_slug"
  helper "$id_slug" new "$TEST_DIR/prompt.md" >/dev/null
  cmp "$TEST_DIR/expected-version" "$id_state/cli-version.txt"
  cmp "$TEST_DIR/expected-path" "$id_state/cli-path.txt"

  MOCK_VERSION='0.86.0' helper "$id_slug" resume "$TEST_DIR/prompt.md" >/dev/null
  cmp "$TEST_DIR/bumped-version" "$id_state/cli-version.txt"

  cmds_before=$(wc -l < "$MOCK_CMDS")
  if MOCK_VERSION_FAIL=1 helper "$id_slug" new "$TEST_DIR/prompt.md" \
      >/dev/null 2> "$TEST_DIR/verr"; then
    echo "FAIL: $label dispatched despite failed version capture" >&2
    exit 1
  fi
  grep -q 'cannot record pi CLI version' "$TEST_DIR/verr"
  [ "$(wc -l < "$MOCK_CMDS")" = "$cmds_before" ] || {
    echo "FAIL: $label sent a prompt after failed version capture" >&2; exit 1; }
  [ -f "$id_state/cli-version.txt" ] || {
    echo "FAIL: $label recorded no version attempt after the failed capture" >&2
    exit 1; }

  helper "$id_slug" stop >/dev/null 2>&1 || true
done <<< "$HELPERS"

echo "PASS: pi helpers handle input guards, fresh sessions, resume, compact, stop, and CLI identity"
