#!/usr/bin/env bash
# Runnable self-check for delegate-work-agy helper script.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SKILL_DIR/tests/test-agy-exec.sh"
