# Skill Updates: Droid Delegation and Orchestration

## Overview
Two new skills provide delegation and plan implementation workflows for Factory Droid using the `droid` CLI (`droid exec`). `delegate-work-droid` assigns direct tasks or discussions to a Droid worker in a single session. `orchestrate-implementation-droid` implements an approved plan phase by phase, spawning a fresh Droid session per phase, handling questions through resume, and stopping at review without committing.

## Skills

### delegate-work-droid
Delegates a direct task or discussion to a Droid worker through `droid exec` without requiring a plan in `plans/`.
- **Scope:** Direct tasks, bug fixes, investigations, refactoring, advice, or requested document edits.
- **Session management:** Uses one session per bounded assignment, continuing questions and verification rounds with `resume`.
- **Autonomy levels:** Supports `none` (default, read-only), `low`, `medium`, and `high`.
- **Safety:** Stays in the main session for review. Changes remain uncommitted.

### orchestrate-implementation-droid
Coordinates phased execution of an approved plan from `plans/<slug>.md` using `droid exec`.
- **Plan gate:** Verifies the approved plan file exists and is readable before any execution or handoff setup. If missing, halts and recommends `delegate-work-droid`.
- **Session isolation:** Runs a fresh worker session per phase to prevent context degradation from runtime auto-compaction.
- **Continuity:** Carries context across phases through `.orchestrate/<slug>/implementation-log.md`.
- **Drift detection:** Captures Git baselines before each phase and halts with a CTO report on unauthorized modifications.
- **Review boundary:** Stops after review. Never commits or writes feature documentation.

## Helper Script

The standalone `droid-exec.sh` helper manages worker sessions under `${TMPDIR:-/tmp}/droid-work-<slug>/` (for direct tasks) or `${TMPDIR:-/tmp}/droid-orch-<slug>/` (for plan orchestration).

Commands:
- `droid-exec.sh <slug> new <prompt-file> [auto]` starts a fresh session and blocks until the turn finishes.
- `droid-exec.sh <slug> resume <prompt-file> [auto]` sends the next prompt to an active session.
- `droid-exec.sh <slug> session` outputs the active session ID.
- `droid-exec.sh <slug> stop` terminates the running process and clears session state.

Telemetry and state:
- `cli-version.txt` and `cli-path.txt` capture the active Droid binary path and version before each turn.
- `events.jsonl` stores raw stream-json events from `droid exec -o stream-json`.
- `last.txt` extracts the terminal assistant message.
- `usage.json` stores per-turn token and credit metrics.

## Usage

### Direct tasks
```bash
# In the host agent prompt
Use $delegate-work-droid to investigate why search pagination skips results.
Preserve the existing API. Do not commit.

Use $delegate-work-droid to discuss retry backoff strategies.
Compare alternatives and challenge assumptions. Do not implement changes.
```

### Plan orchestration
```bash
# In the host agent prompt
Use $orchestrate-implementation-droid to implement the approved plan at
plans/search-pagination.md. Do not commit.
```

### Direct helper execution
```bash
# Start a direct task with read-only inspection
bash skills/delegate-work-droid/droid-exec.sh task-1 new /path/to/prompt.md none

# Resume with write access
bash skills/delegate-work-droid/droid-exec.sh task-1 resume /path/to/next-prompt.md medium

# Inspect active session ID
bash skills/delegate-work-droid/droid-exec.sh task-1 session

# Stop and clean up
bash skills/delegate-work-droid/droid-exec.sh task-1 stop
```

## Configuration

Environment variables:
- `DROID_EXEC_IDLE_TIMEOUT`: Maximum seconds of stream inactivity before aborting a turn (default: 600).
- `DROID_ORCH_MODEL`: Overrides the default model passed via `-m` (e.g. `custom:Xiaomi-MiMo-V2.6-Flash`).

## Verification

Run the helper test suite:
```bash
bash skills/delegate-work-droid/tests/test-droid-exec.sh
```

The test validates session tracking, `-s` resume handling, autonomy mapping, idle timeouts, guard rails, and CLI version capture against a mock CLI.

## Notes
- Tested against baseline `droid 0.251.0` at `/Users/amirinns/.local/bin/droid`.
- Helper telemetry in `usage.json` captures per-turn counts. Later turns replay prior conversation as input, so counters must not be summed across resumes.
- Autonomy level `medium` allows local git commands. Prompts explicitly forbid commits, and the orchestrator verifies the Git baseline after each turn.
