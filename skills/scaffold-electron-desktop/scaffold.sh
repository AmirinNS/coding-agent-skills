#!/usr/bin/env bash
# Assemble a new Electron desktop app from the canonical assets/ skeleton.
#
# This script is the SINGLE SOURCE OF TRUTH for scaffold output. Never
# hand-transcribe the templates — edit assets/ and re-run.
#
# Usage:
#   scaffold.sh <target_dir> <project_name> <module_name> <app_id> [description]
#
# Example:
#   scaffold.sh ~/Projects/deal-tracker "Deal Tracker" deal-tracker \
#     com.example.dealtracker "Tracks the best deals across brands."
#
# Tokens replaced in every text file:
#   __PROJECT_NAME__  display name          "Deal Tracker"
#   __MODULE_NAME__   kebab package name    "deal-tracker"
#   __PROJECT_TYPE__  PascalCase prefix     "DealTracker"   (derived)
#   __API_GLOBAL__    window global         "dealTracker"   (derived)
#   __ENV_PREFIX__    env var prefix        "DEAL_TRACKER"  (derived)
#   __APP_ID__        bundle id             "com.example.dealtracker"
#   __DESCRIPTION__   one-line description
set -euo pipefail

TARGET="${1:?target dir required}"
PROJECT_NAME="${2:?project name required}"
MODULE_NAME="${3:?module name (kebab-case) required}"
APP_ID="${4:?app id (reverse-DNS) required}"
DESCRIPTION="${5:-}"

if ! printf '%s' "$MODULE_NAME" | grep -Eq '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
    echo "ERROR: module_name must be kebab-case (got: $MODULE_NAME)" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/assets"

if [ ! -d "$ASSETS/app" ]; then
    echo "ERROR: assets/app/ not found at $ASSETS" >&2
    exit 1
fi

if [ -d "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "ERROR: $TARGET exists and is not empty — refusing to overwrite" >&2
    exit 1
fi

mkdir -p "$TARGET"
cp -R "$ASSETS/app/." "$TARGET/"

# Rename placeholder-named files to their real names.
mv "$TARGET/package.json.tmpl" "$TARGET/package.json"
mv "$TARGET/gitignore"         "$TARGET/.gitignore"
mv "$TARGET/README.md.tmpl"    "$TARGET/README.md"
mv "$TARGET/CLAUDE.md.tmpl"    "$TARGET/CLAUDE.md"

# electron-builder points buildResources at public/.
mkdir -p "$TARGET/public"
touch "$TARGET/public/.gitkeep"

# Token substitution across every text file. Derived tokens are computed here
# so callers only supply the kebab module name.
PROJECT_NAME="$PROJECT_NAME" MODULE_NAME="$MODULE_NAME" APP_ID="$APP_ID" \
DESCRIPTION="$DESCRIPTION" python3 - "$TARGET" <<'PY'
import os, sys

target = sys.argv[1]
module = os.environ["MODULE_NAME"]
parts = module.split("-")

subs = {
    "__PROJECT_NAME__": os.environ["PROJECT_NAME"],
    "__MODULE_NAME__": module,
    "__PROJECT_TYPE__": "".join(p.capitalize() for p in parts),
    "__API_GLOBAL__": parts[0] + "".join(p.capitalize() for p in parts[1:]),
    "__ENV_PREFIX__": module.replace("-", "_").upper(),
    "__APP_ID__": os.environ["APP_ID"],
    "__DESCRIPTION__": os.environ["DESCRIPTION"],
}

for root, dirs, files in os.walk(target):
    dirs[:] = [d for d in dirs if d != "node_modules"]
    for fn in files:
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

echo "Scaffolded '$PROJECT_NAME' -> $TARGET"
echo "  next: cd $TARGET && npm install && npm run rebuild:node && npm test"
