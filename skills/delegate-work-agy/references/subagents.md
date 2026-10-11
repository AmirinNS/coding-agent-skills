# Antigravity subagents guide

Reference guide for Antigravity subagent mechanics, communication patterns, and tool definitions.

## Execution models

Antigravity supports two primary ways to run subagents:

### 1. External process isolation (recommended)

Driven by `agy-exec.sh`. The orchestrator runs `agy` in print mode with `--conversation` to
isolate the implementor in a separate process.

Advantages:
- Complete context isolation. Bulky file reads, test outputs, and compiler logs never enter
  the orchestrator's context window.
- Clean compaction boundaries. Starting a fresh conversation per phase or assignment prevents
  context degradation.
- Universal support. Works from Antigravity, Claude Code, Cursor, terminal shells, or automated
  scripts.
- Automated idle watchdog. Detects and terminates stalled processes.

### 2. Native tool invocation

Available when the orchestrator runs directly inside an Antigravity IDE or CLI session. The
orchestrator calls Antigravity's built-in subagent tool APIs.

Tool APIs:
- `invoke_subagent`: Launches one or more subagents in the background.
  Parameters:
  - `Subagents`: array of subagent configurations.
  - `Role`: descriptive title (e.g. `Phase Implementor`, `Task Worker`).
  - `TypeName`: `self` (inherits full tool suite), `research` (read-only tools), or custom agent.
  - `Workspace`: `inherit` (shares current directory tree), `share` (shared git worktree), or `branch`.
  - `Prompt`: initial instruction and task assignment.
- `send_message`: Sends messages to an active subagent conversation ID (e.g. providing answers
  to questions, or requesting validation).
- `manage_subagents`: Inspects or terminates subagents using actions `list`, `kill`, or `kill_all`.
- `define_subagent`: Dynamically registers a custom subagent type with specialized system prompt
  and tool permissions.

## Handoff files pattern

Whether using process isolation or native subagents, cross-phase and cross-turn continuity
relies on append-only files under `.orchestrate/<slug>/`:

```
.orchestrate/<slug>/
├── task.md                 # Brief, acceptance criteria, and checklist
├── questions.md            # Blocking questions raised by the worker
├── answers.md              # Binding answers provided by the orchestrator
├── work-log.md             # Chronological task outcomes and verification evidence
├── implementation-log.md   # Phase-by-phase implementation log (orchestration runs)
└── prompt.md               # Scratch instruction file for the current turn
```

Why handoff files matter:
- Subagent conversations do not outlive the phase. A fresh conversation starts with an empty
  transcript and reconstructs state from these files.
- The files form a durable audit trail that is committed with the finished change set.
- Answers in `answers.md` become binding decisions across all subsequent phases.

## Standard response contracts

Every worker turn must conclude with exactly one fenced JSON block:

### When completed successfully

```json
{
  "status": "done",
  "assignment": "task-1",
  "summary": "Short explanation of work done",
  "files": ["path/to/edited/file.py"],
  "checks": [
    {
      "cmd": "pytest tests/test_feature.py",
      "result": "pass",
      "detail": ""
    }
  ],
  "pending": []
}
```

### When blocked by an ambiguity or missing access

```json
{
  "status": "blocked",
  "assignment": "task-1",
  "summary": "Blocked by missing database configuration",
  "questions": ["Q1"],
  "pending": []
}
```
