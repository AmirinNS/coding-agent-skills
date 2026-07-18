#!/usr/bin/env bash
# Assemble a new project from the canonical assets/ skeleton.
#
# This script is the SINGLE SOURCE OF TRUTH for scaffold output. Both the
# scaffold-project skill (new projects) and the convert-to-house-style skill
# (migrations) stamp files from the same assets/ tree, so output is guaranteed
# identical — no hand-transcription of templates.
#
# Usage:
#   scaffold.sh <target_dir> <project_name> <module_name> <db_name> [description]
#
# Tokens replaced in every text file: __PROJECT_NAME__ __MODULE_NAME__
# __DB_NAME__ __DESCRIPTION__
set -euo pipefail

TARGET="${1:?target dir required}"
PROJECT_NAME="${2:?project name required}"
MODULE_NAME="${3:?module name (python-safe) required}"
DB_NAME="${4:?db name required}"
DESCRIPTION="${5:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/assets"

if [ ! -d "$ASSETS" ]; then
    echo "ERROR: assets/ not found at $ASSETS" >&2
    exit 1
fi

mkdir -p "$TARGET"
cp -R "$ASSETS/." "$TARGET/"

# Rename placeholder-named files to their real names.
mv "$TARGET/entrypoint.py"  "$TARGET/${MODULE_NAME}.py"
mv "$TARGET/gitignore"      "$TARGET/.gitignore"
mv "$TARGET/env.example"    "$TARGET/.env.example"
mv "$TARGET/README.md.tmpl" "$TARGET/README.md"
mv "$TARGET/CLAUDE.md.tmpl" "$TARGET/CLAUDE.md"

mkdir -p "$TARGET/plans" "$TARGET/static/img"
touch "$TARGET/plans/.gitkeep" "$TARGET/static/img/.gitkeep"

# Token substitution across all text files (safe for arbitrary description text).
PROJECT_NAME="$PROJECT_NAME" MODULE_NAME="$MODULE_NAME" DB_NAME="$DB_NAME" DESCRIPTION="$DESCRIPTION" \
python3 - "$TARGET" <<'PY'
import os, sys

target = sys.argv[1]
subs = {
    "__PROJECT_NAME__": os.environ["PROJECT_NAME"],
    "__MODULE_NAME__": os.environ["MODULE_NAME"],
    "__DB_NAME__": os.environ["DB_NAME"],
    "__DESCRIPTION__": os.environ["DESCRIPTION"],
}
text_names = (".env.example", ".gitignore", ".gitkeep")
text_exts = (".py", ".html", ".css", ".js", ".md", ".txt", ".example")
for root, _, files in os.walk(target):
    for fn in files:
        if not (fn.endswith(text_exts) or fn in text_names):
            continue
        path = os.path.join(root, fn)
        try:
            with open(path, encoding="utf-8") as f:
                original = f.read()
        except (UnicodeDecodeError, IsADirectoryError):
            continue
        updated = original
        for token, value in subs.items():
            updated = updated.replace(token, value)
        if updated != original:
            with open(path, "w", encoding="utf-8") as f:
                f.write(updated)
PY

echo "Scaffolded '$PROJECT_NAME' -> $TARGET (entrypoint: ${MODULE_NAME}.py)"
