#!/usr/bin/env bash
# Exercise swarm-files.sh against throwaway Git repos. No agent CLI is needed.
#
# Each case builds a fresh repo, takes a snapshot, simulates worker edits, and
# checks what snapshot, changed, overlap, attribute, and restore report.
set -u

SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
HELPER="$SKILL_DIR/swarm-files.sh"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/swarm-files-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

PASSED=0
FAILED=0
pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1" >&2; FAILED=$((FAILED + 1)); }

# new_repo <name>: create a repo with two committed files and cd into it.
new_repo() {
  REPO="$TEST_DIR/$1"
  STATE="$TEST_DIR/$1-state"
  OWN="$TEST_DIR/$1-own"
  mkdir -p "$REPO/src" "$OWN"
  cd "$REPO" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name test
  printf 'a1\n' > src/a.py
  printf 'b1\n' > src/b.py
  printf 'readme\n' > README.md
  git add -A
  git commit -qm init
}

swarm() { bash "$HELPER" "$@"; }

# 1. A clean edit is credited to its owner.
new_repo clean-edit
printf 'src/a.py\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
printf 'a2\n' > src/a.py
out=$(swarm attribute "$STATE" "$OWN/w1.own"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = $'w1\tsrc/a.py' ]; then
  pass "clean edit attributed to its owner"
else
  fail "clean edit attributed to its owner (rc=$rc out=$out)"
fi

# 2. A file already dirty at snapshot time is reported only when edited again.
new_repo dirty-edit
printf 'user change\n' > src/a.py
printf 'src/\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
out=$(swarm changed "$STATE")
if [ -z "$out" ]; then
  printf 'worker change\n' > src/a.py
  out=$(swarm changed "$STATE")
  if [ "$out" = "src/a.py" ]; then
    pass "edit to a file already dirty at snapshot is detected"
  else
    fail "edit to a file already dirty at snapshot is detected (out=$out)"
  fi
else
  fail "unchanged dirty file is not reported (out=$out)"
fi

# 3. A new untracked file inside an owned directory is credited to that owner.
new_repo untracked
printf 'src/new/\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
mkdir -p src/new
printf 'x\n' > src/new/c.py
out=$(swarm attribute "$STATE" "$OWN/w1.own"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = $'w1\tsrc/new/c.py' ]; then
  pass "new untracked file in an owned directory is attributed"
else
  fail "new untracked file in an owned directory is attributed (rc=$rc out=$out)"
fi

# 4. A change nobody owns is UNOWNED with exit 2.
new_repo unowned
printf 'src/a.py\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
printf 'changed\n' > README.md
out=$(swarm attribute "$STATE" "$OWN/w1.own"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = $'UNOWNED\tREADME.md' ]; then
  pass "unowned change gives UNOWNED and exit 2"
else
  fail "unowned change gives UNOWNED and exit 2 (rc=$rc out=$out)"
fi

# 5. Deleting a tracked file counts as a change.
new_repo deleted
swarm snapshot "$STATE"
rm src/b.py
out=$(swarm changed "$STATE")
if [ "$out" = "src/b.py" ]; then
  pass "deleted tracked file is detected"
else
  fail "deleted tracked file is detected (out=$out)"
fi

# 6. overlap catches a directory that contains another owner's file.
new_repo overlap
printf 'src/\n' > "$OWN/w1.own"
printf 'src/a.py\n' > "$OWN/w2.own"
printf 'README.md\n' > "$OWN/w3.own"
swarm overlap "$OWN/w1.own" "$OWN/w2.own" >/dev/null; rc_bad=$?
swarm overlap "$OWN/w2.own" "$OWN/w3.own" >/dev/null; rc_good=$?
if [ "$rc_bad" -eq 1 ] && [ "$rc_good" -eq 0 ]; then
  pass "overlap catches src/ against src/a.py and passes disjoint sets"
else
  fail "overlap catches src/ against src/a.py and passes disjoint sets (bad=$rc_bad good=$rc_good)"
fi

# 7. A commit after the snapshot is reported with exit 3.
new_repo commit
swarm snapshot "$STATE"
printf 'a2\n' > src/a.py
git commit -qam sneaky
out=$(swarm changed "$STATE" 2>&1); rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'HEAD moved'; then
  pass "commit after snapshot gives exit 3"
else
  fail "commit after snapshot gives exit 3 (rc=$rc out=$out)"
fi

# 8. Staging after the snapshot is reported with exit 3; staging before it is not.
new_repo staged
printf 'staged by user\n' > src/a.py
git add src/a.py
swarm snapshot "$STATE"
out=$(swarm changed "$STATE" 2>&1); rc_before=$?
printf 'b2\n' > src/b.py
git add src/b.py
out=$(swarm changed "$STATE" 2>&1); rc_after=$?
if [ "$rc_before" -eq 0 ] && [ "$rc_after" -eq 3 ] && printf '%s' "$out" | grep -q 'index changed'; then
  pass "staging after snapshot gives exit 3, staging before it does not"
else
  fail "staging after snapshot gives exit 3 (before=$rc_before after=$rc_after out=$out)"
fi

# 9. Paths with spaces are attributed correctly.
new_repo spaces
mkdir -p "docs dir"
printf 'docs dir/\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
printf 'x\n' > "docs dir/my file.md"
out=$(swarm attribute "$STATE" "$OWN/w1.own"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = $'w1\tdocs dir/my file.md' ]; then
  pass "path containing spaces is attributed correctly"
else
  fail "path containing spaces is attributed correctly (rc=$rc out=$out)"
fi

# 9b. A path with spaces that was dirty at snapshot is not reported until edited again.
new_repo spaces-dirty
mkdir -p "docs dir"
printf 'draft\n' > "docs dir/my notes.md"
swarm snapshot "$STATE"
out_before=$(swarm changed "$STATE")
printf 'edited\n' > "docs dir/my notes.md"
out_after=$(swarm changed "$STATE")
if [ -z "$out_before" ] && [ "$out_after" = "docs dir/my notes.md" ]; then
  pass "dirty path containing spaces is tracked from the snapshot"
else
  fail "dirty path containing spaces is tracked from the snapshot (before=$out_before after=$out_after)"
fi

# 10. restore returns a file dirty at snapshot to its wave-start content, not HEAD.
new_repo restore-dirty
printf 'user change\n' > src/a.py
printf 'src/a.py\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
printf 'worker change\n' > src/a.py
swarm restore "$STATE" "$OWN/w1.own" "$TEST_DIR/save10" >/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat src/a.py)" = "user change" ] \
  && [ "$(cat "$TEST_DIR/save10/src/a.py")" = "worker change" ]; then
  pass "restore returns a file dirty at snapshot to wave-start content"
else
  fail "restore returns a file dirty at snapshot to wave-start content (rc=$rc now=$(cat src/a.py))"
fi

# 11. restore resets a clean file from HEAD, removes a new file, recreates a deleted one.
new_repo restore-mixed
printf 'src/\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
printf 'a2\n' > src/a.py
rm src/b.py
printf 'new\n' > src/c.py
swarm restore "$STATE" "$OWN/w1.own" "$TEST_DIR/save11" >/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat src/a.py)" = "a1" ] && [ "$(cat src/b.py 2>/dev/null)" = "b1" ] \
  && [ ! -e src/c.py ] && [ "$(cat "$TEST_DIR/save11/src/c.py")" = "new" ] \
  && tr '\0' '\n' < "$TEST_DIR/save11/.deleted" | grep -qx 'src/b.py'; then
  pass "restore resets from HEAD, removes a new file, and recreates a deleted file"
else
  fail "restore resets from HEAD, removes a new file, and recreates a deleted file (rc=$rc)"
fi

# 12. restore leaves other owners' changes and the index alone.
new_repo restore-scope
printf 'src/a.py\n' > "$OWN/w1.own"
printf 'staged\n' > src/b.py
git add src/b.py
swarm snapshot "$STATE"
index_before=$(git ls-files -s -z | git hash-object --stdin)
printf 'a2\n' > src/a.py
printf 'other worker\n' > README.md
swarm restore "$STATE" "$OWN/w1.own" "$TEST_DIR/save12" >/dev/null; rc=$?
index_after=$(git ls-files -s -z | git hash-object --stdin)
if [ "$rc" -eq 0 ] && [ "$(cat README.md)" = "other worker" ] && [ "$(cat src/a.py)" = "a1" ] \
  && [ -f "$TEST_DIR/save12/src/a.py" ] && [ ! -e "$TEST_DIR/save12/README.md" ] \
  && [ "$index_before" = "$index_after" ]; then
  pass "restore leaves other changes and the index untouched"
else
  fail "restore leaves other changes and the index untouched (rc=$rc)"
fi

# 12b. restore leaves handoff records alone and accepts a save dir inside .orchestrate/.
new_repo restore-handoff
mkdir -p .orchestrate/run/w1
printf 'brief\n' > .orchestrate/run/w1/task.md
printf '.orchestrate/run/w1/\nsrc/a.py\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
printf 'a2\n' > src/a.py
printf 'premise\n' > .orchestrate/run/w1/work-log.md
printf 'scratch\n' > .orchestrate/run/w1/prompt.md
swarm restore "$STATE" "$OWN/w1.own" "$REPO/.orchestrate/run/w1/partial" >/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat src/a.py)" = "a1" ] \
  && [ "$(cat .orchestrate/run/w1/work-log.md)" = "premise" ] \
  && [ -f .orchestrate/run/w1/prompt.md ] \
  && [ "$(cat .orchestrate/run/w1/partial/src/a.py)" = "a2" ] \
  && [ ! -e .orchestrate/run/w1/partial/.orchestrate ]; then
  pass "restore leaves handoff records alone and saves inside .orchestrate/"
else
  fail "restore leaves handoff records alone and saves inside .orchestrate/ (rc=$rc)"
fi

# 12c. restore treats file names literally, so a glob-like name cannot reset another file.
new_repo restore-literal
printf 'one\n' > 'src/a[1].py'
printf 'other\n' > src/a1.py
git add -A && git commit -qm glob
printf 'src/a[1].py\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
printf 'w1 edit\n' > 'src/a[1].py'
printf 'w2 edit\n' > src/a1.py
swarm restore "$STATE" "$OWN/w1.own" "$TEST_DIR/save12c" >/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat 'src/a[1].py')" = "one" ] && [ "$(cat src/a1.py)" = "w2 edit" ]; then
  pass "restore treats glob-like file names literally"
else
  fail "restore treats glob-like file names literally (rc=$rc a1=$(cat src/a1.py))"
fi

# 13. A state dir inside the work tree is refused, since it would show up as changes.
new_repo state-inside
swarm snapshot "$REPO/.state" 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ] && [ ! -e "$REPO/.state" ]; then
  pass "snapshot refuses a state dir inside the work tree"
else
  fail "snapshot refuses a state dir inside the work tree (rc=$rc)"
fi
swarm snapshot "$REPO/.cache/swarm/wave-1" 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ] && [ ! -e "$REPO/.cache" ]; then
  pass "snapshot refuses an in-tree state dir whose parents do not exist yet"
else
  fail "snapshot refuses an in-tree state dir whose parents do not exist yet (rc=$rc)"
fi

# 13b. A retargeted tracked symlink is detected and restore puts the old target back.
new_repo symlink
ln -s a.py src/link.py
git add -A && git commit -qm link
printf 'src/link.py\n' > "$OWN/w1.own"
swarm snapshot "$STATE"
rm src/link.py && ln -s b.py src/link.py
out=$(swarm changed "$STATE")
swarm restore "$STATE" "$OWN/w1.own" "$TEST_DIR/save13b" >/dev/null; rc=$?
if [ "$out" = "src/link.py" ] && [ "$rc" -eq 0 ] && [ "$(readlink src/link.py)" = "a.py" ] \
  && [ "$(readlink "$TEST_DIR/save13b/src/link.py")" = "b.py" ]; then
  pass "retargeted symlink is detected and restored"
else
  fail "retargeted symlink is detected and restored (out=$out rc=$rc target=$(readlink src/link.py))"
fi

# 14. Commands refuse to run outside a Git repo with a HEAD.
mkdir -p "$TEST_DIR/no-git" && cd "$TEST_DIR/no-git" || exit 1
swarm snapshot "$TEST_DIR/no-git-state" 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ]; then
  pass "snapshot exits 1 outside a Git repo"
else
  fail "snapshot exits 1 outside a Git repo (rc=$rc)"
fi

echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
