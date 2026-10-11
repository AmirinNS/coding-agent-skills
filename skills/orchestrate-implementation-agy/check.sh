#!/usr/bin/env bash
# Simple runnable self-check for agy-exec.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DIR/../delegate-work-agy/tests/test-agy-exec.sh" ]; then
  exec bash "$DIR/../delegate-work-agy/tests/test-agy-exec.sh"
else
  echo "test runner not found" >&2
  exit 1
fi
