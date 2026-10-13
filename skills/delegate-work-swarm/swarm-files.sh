#!/usr/bin/env bash
# swarm-files.sh - track which swarm worker changed which file in a shared Git tree.
#
# Usage: swarm-files.sh <command> [args...]
#
# Commands:
#   snapshot <state-dir>                       record HEAD, the index, and every dirty file
#   changed <state-dir>                        print paths whose content changed since the snapshot
#   overlap <own-file>...                      print ownership entries that collide
#   attribute <state-dir> <own-file>...        credit each changed path to its owner
#   restore <state-dir> <own-file> <save-dir>  save one owner's changes, then undo them;
#                                              never touches .orchestrate/ (handoff records)
#
# Exit codes: 0 ok; 1 usage or setup error, an overlap found, or restore left changes;
# 2 attribute found UNOWNED paths; 3 HEAD or the index moved since the snapshot.
#
# An own-file lists one repo-relative path per line, and a trailing "/" marks a
# directory. Blank lines and lines starting with "#" are ignored. The assignment id
# is the own-file's basename without ".own".
#
# Run from inside the project. The state dir must live outside the work tree, or the
# snapshot itself would show up as changed files.
#
# shortcut: content hashes only, so a mode-only change (chmod) is not reported, and
# path lookups are linear. Both are fine for the dozens of files a swarm run touches.

die() { echo "swarm-files: $*" >&2; exit 1; }

abspath() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$PWD/$1" ;;
  esac
}

enter_repo() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a Git work tree"
  git rev-parse -q --verify HEAD >/dev/null || die "repository has no HEAD commit"
  cd "$root" || die "cannot enter $root"
  ROOT=$(pwd -P)
}

hash_of() {
  if [ -L "$1" ]; then
    printf '%s' "$(readlink "$1")" | git hash-object --stdin
  elif [ -f "$1" ]; then
    git hash-object -- "$1"
  elif [ -d "$1" ]; then
    echo dir
  else
    echo absent
  fi
}

index_hash() { git ls-files -s -z | git hash-object --stdin; }

# Print every path git status reports, NUL-separated.
status_paths() {
  local rec
  git status --porcelain=v1 -z -uall --no-renames | while IFS= read -r -d '' rec; do
    printf '%s\0' "${rec:3}"
  done
}

load_dirty() {
  local rec
  DIRTY_PATHS=()
  DIRTY_HASHES=()
  while IFS= read -r -d '' rec; do
    DIRTY_HASHES+=("${rec%%$'\t'*}")
    DIRTY_PATHS+=("${rec#*$'\t'}")
  done < "$STATE/dirty.z"
}

# Print the snapshot hash of a path that was dirty at snapshot time; fail otherwise.
dirty_hash() {
  local i
  for ((i = 0; i < ${#DIRTY_PATHS[@]}; i++)); do
    if [ "${DIRTY_PATHS[$i]}" = "$1" ]; then
      echo "${DIRTY_HASHES[$i]}"
      return 0
    fi
  done
  return 1
}

baseline_hash() {
  dirty_hash "$1" && return 0
  git rev-parse -q --verify "HEAD:$1" 2>/dev/null || echo absent
}

check_state() {
  [ -f "$STATE/head.txt" ] && [ -f "$STATE/index.txt" ] && [ -f "$STATE/dirty.z" ] \
    || die "no snapshot in $STATE"
  if [ "$(git rev-parse HEAD)" != "$(cat "$STATE/head.txt")" ]; then
    echo "swarm-files: HEAD moved since the snapshot" >&2
    exit 3
  fi
  if [ "$(index_hash)" != "$(cat "$STATE/index.txt")" ]; then
    echo "swarm-files: index changed since the snapshot" >&2
    exit 3
  fi
}

# Write changed paths, NUL-separated, to the file named by $1.
collect_changed() {
  local out="$1" path seen=() s dup
  load_dirty
  : > "$out"
  while IFS= read -r -d '' path; do
    dup=0
    for s in ${seen[@]+"${seen[@]}"}; do
      [ "$s" = "$path" ] && dup=1 && break
    done
    [ "$dup" -eq 1 ] && continue
    seen+=("$path")
    if [ "$(baseline_hash "$path")" != "$(hash_of "$path")" ]; then
      printf '%s\0' "$path" >> "$out"
    fi
  done < <({
    if [ ${#DIRTY_PATHS[@]} -gt 0 ]; then printf '%s\0' "${DIRTY_PATHS[@]}"; fi
    status_paths
  })
}

# Print an own-file's entries, one per line, without "./" prefixes or comments.
own_entries() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#./}"
    case "$line" in ''|'#'*) continue ;; esac
    printf '%s\n' "$line"
  done < "$1"
}

# entry_covers <entry> <path>: true when an ownership entry claims the path.
entry_covers() {
  [ "$1" = "$2" ] && return 0
  case "$1" in
    */) case "$2" in "$1"*) return 0 ;; esac ;;
  esac
  return 1
}

# owner_of <path> <own-file>...: print the owning assignment id, or fail.
owner_of() {
  local path="$1" f entry
  shift
  for f in "$@"; do
    while IFS= read -r entry; do
      if entry_covers "$entry" "$path"; then
        basename "$f" .own
        return 0
      fi
    done < <(own_entries "$f")
  done
  return 1
}

copy_path() {
  mkdir -p "$(dirname "$2")"
  rm -f "$2"
  if [ -L "$1" ]; then
    ln -s "$(readlink "$1")" "$2"
  else
    cp -p "$1" "$2"
  fi
}

cmd_snapshot() {
  [ $# -eq 1 ] || die "usage: snapshot <state-dir>"
  STATE=$(abspath "$1")
  enter_repo
  # Resolve the nearest existing ancestor, since the state dir may not exist yet.
  local probe="$STATE"
  while [ ! -d "$probe" ]; do probe=$(dirname "$probe"); done
  case "$(cd "$probe" && pwd -P)/" in
    "$ROOT"/*) die "state dir must be outside the work tree: $STATE" ;;
  esac
  mkdir -p "$STATE" || die "cannot create $STATE"
  rm -rf "$STATE/files"
  git rev-parse HEAD > "$STATE/head.txt"
  index_hash > "$STATE/index.txt"
  : > "$STATE/dirty.z"
  local path
  while IFS= read -r -d '' path; do
    printf '%s\t%s\0' "$(hash_of "$path")" "$path" >> "$STATE/dirty.z"
    if [ -L "$path" ] || [ -f "$path" ]; then
      copy_path "$path" "$STATE/files/$path"
    fi
  done < <(status_paths)
}

cmd_changed() {
  [ $# -eq 1 ] || die "usage: changed <state-dir>"
  STATE=$(abspath "$1")
  enter_repo
  check_state
  local tmp path
  tmp=$(mktemp) || die "cannot create a temp file"
  collect_changed "$tmp"
  while IFS= read -r -d '' path; do
    printf '%s\n' "$path"
  done < "$tmp"
  rm -f "$tmp"
}

cmd_overlap() {
  [ $# -ge 1 ] || die "usage: overlap <own-file>..."
  local ids=() entries=() f entry i j found=0
  for f in "$@"; do
    [ -r "$f" ] || die "cannot read $f"
    while IFS= read -r entry; do
      ids+=("$(basename "$f" .own)")
      entries+=("$entry")
    done < <(own_entries "$f")
  done
  for ((i = 0; i < ${#entries[@]}; i++)); do
    for ((j = i + 1; j < ${#entries[@]}; j++)); do
      [ "${ids[$i]}" = "${ids[$j]}" ] && continue
      if entry_covers "${entries[$i]}" "${entries[$j]}" \
        || entry_covers "${entries[$j]}" "${entries[$i]}"; then
        printf '%s:%s\t%s:%s\n' "${ids[$i]}" "${entries[$i]}" "${ids[$j]}" "${entries[$j]}"
        found=1
      fi
    done
  done
  return "$found"
}

cmd_attribute() {
  [ $# -ge 2 ] || die "usage: attribute <state-dir> <own-file>..."
  STATE=$(abspath "$1")
  shift
  local owns=() f
  for f in "$@"; do
    [ -r "$f" ] || die "cannot read $f"
    owns+=("$(abspath "$f")")
  done
  enter_repo
  check_state
  local tmp path owner unowned=0
  tmp=$(mktemp) || die "cannot create a temp file"
  collect_changed "$tmp"
  while IFS= read -r -d '' path; do
    if owner=$(owner_of "$path" "${owns[@]}"); then
      printf '%s\t%s\n' "$owner" "$path"
    else
      printf 'UNOWNED\t%s\n' "$path"
      unowned=1
    fi
  done < "$tmp"
  rm -f "$tmp"
  [ "$unowned" -eq 0 ] || exit 2
}

cmd_restore() {
  [ $# -eq 3 ] || die "usage: restore <state-dir> <own-file> <save-dir>"
  STATE=$(abspath "$1")
  local own save
  own=$(abspath "$2")
  save=$(abspath "$3")
  [ -r "$own" ] || die "cannot read $own"
  enter_repo
  check_state
  mkdir -p "$save" || die "cannot create $save"
  local tmp path dh left=0
  tmp=$(mktemp) || die "cannot create a temp file"
  collect_changed "$tmp"
  while IFS= read -r -d '' path; do
    case "$path" in .orchestrate/*) continue ;; esac
    owner_of "$path" "$own" >/dev/null || continue
    if [ -L "$path" ] || [ -e "$path" ]; then
      copy_path "$path" "$save/$path"
    else
      printf '%s\0' "$path" >> "$save/.deleted"
    fi
    if dh=$(dirty_hash "$path"); then
      case "$dh" in
        absent) rm -f "$path" ;;
        dir) echo "swarm-files: skipped directory $path" >&2 ;;
        *) copy_path "$STATE/files/$path" "$path" ;;
      esac
    elif git cat-file -e "HEAD:$path" 2>/dev/null; then
      git --literal-pathspecs restore --source=HEAD --worktree -- "$path" || die "git restore failed for $path"
    else
      rm -f "$path"
    fi
    echo "restored $path"
  done < "$tmp"
  collect_changed "$tmp"
  while IFS= read -r -d '' path; do
    case "$path" in .orchestrate/*) continue ;; esac
    if owner_of "$path" "$own" >/dev/null; then
      echo "swarm-files: still changed after restore: $path" >&2
      left=1
    fi
  done < "$tmp"
  rm -f "$tmp"
  [ "$left" -eq 0 ] || exit 1
}

CMD="${1:-}"
[ $# -gt 0 ] && shift
case "$CMD" in
  snapshot) cmd_snapshot "$@" ;;
  changed) cmd_changed "$@" ;;
  overlap) cmd_overlap "$@" ;;
  attribute) cmd_attribute "$@" ;;
  restore) cmd_restore "$@" ;;
  *) die "usage: swarm-files.sh snapshot|changed|overlap|attribute|restore ..." ;;
esac
