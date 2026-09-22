# Skill Updates: orchestrate-implementation-claude, python-development, and related improvements

## Overview

Three new capabilities and several refinements across the skills repo. The biggest addition is `orchestrate-implementation-claude`, a pure Claude Code variant of phased implementation that needs no external CLI. A new `python-development` skill codifies house-style Python conventions. Several existing skills received targeted improvements.

## New Skills

### orchestrate-implementation-claude

Delegates phased plan implementation to fresh `phase-implementor` subagents (sonnet), one per phase. Same loop as `orchestrate-implementation` but runs entirely within Claude Code using `Agent` and `SendMessage`.

Key differences from the pi variant:
- No external CLI required. No `pi --mode rpc`, no `pi-rpc.sh`.
- Fresh subagent per phase (no compaction needed, no session management).
- Stops at review. Never commits and never writes docs. The whole run sits uncommitted in the working tree, and you call `document-and-commit` yourself at the end.
- Questions round-trip over `SendMessage` to the same agent within a phase.

The `phase-implementor` agent definition lives at `skills/orchestrate-implementation-claude/agents/phase-implementor.md`. To install, copy it to `~/.claude/agents/`:

```bash
cp skills/orchestrate-implementation-claude/agents/phase-implementor.md ~/.claude/agents/
```

### python-development

Codifies house-style Python conventions into a standalone skill. Covers:
- Non-negotiable conventions (imports at top, functional, no ORM, thin routes, 4-space indent).
- When a class is actually justified (framework requirement, custom exception, frozen dataclass).
- Stdlib-first tool selection (pathlib, datetime with timezone, defaultdict, context managers).
- Error handling at trust boundaries.
- Real footguns (mutable defaults, late binding, float on money, naive datetimes, secrets in logs).
- Verify discipline (fail first, test edges, import before claiming).

Triggered by: "write the python", "implement the backend", "build the service layer", "add the route", "write the module", "fix the python".

## Updated Skills

### orchestrate-implementation

- Added drift-check detail: stub detection, orphan module checks, claimed-item verification, build-check sanity, plan-rule grep.
- Added "run it" step: when a phase ships an app, launch and drive the core flow before committing.
- Dispatch prompt now includes Frontend and Python sections in every phase (implementor self-negates when not applicable, rather than orchestrator guessing scope).
- Report format now includes "Frontend skills applied" and "Python skill applied" lines.
- Drift definitions expanded: stubs, placeholder values, false "no UI/Python in scope" reports.
- Added pre-dispatch blocker resolution step.

### convert-to-house-style

- Added Step 5: write the project's CLAUDE.md after the last migration phase, only if the project has none. Never overwrites an existing file.
- Gap detection during assessment: if a project has neither CLAUDE.md nor AGENTS.md, record it as a gap.
- Audit table now includes "Stated conventions" row.

### frontend-design

- Added designer-of-record mandate: every aesthetic choice must be defensible in one sentence naming what it does for the user. Template-like work is rejected.

### CLAUDE-template.md

- SDLC table Phase 3 row now lists `python-development` alongside `frontend-design` / `frontend-bootstrap-evolution`.
- Added Language Conventions section with a Python block (imports, functional, no ORM, thin routes, PEP 8, project venv) and placeholder blocks for JS/TS and other languages.

### scaffold-project/assets/CLAUDE.md.tmpl

- Architecture rules: expanded "no classes" to name the three allowed exceptions (framework demand, custom exception, frozen dataclass).
- Added rule: use the `python-development` skill when writing or editing Python.

### README.md

- Added `orchestrate-implementation-claude` and `python-development` to the structure tree.
- Updated SDLC table to describe both orchestration variants and the new design phase skills.

## Notes

- The `orchestrate-implementation` (pi) and `orchestrate-implementation-claude` skills share the same conceptual loop but differ in mechanics. The `-claude` variant is the default for users without the pi CLI.
- The `python-development` skill is referenced from the CLAUDE template, the scaffold template, and the orchestration dispatch prompt. It is the single source of depth for Python conventions.
