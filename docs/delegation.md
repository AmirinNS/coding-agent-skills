# Delegation and plan implementation

Delegation assigns work to another agent. Orchestration coordinates scope, questions,
review, verification, and continuity. Both skill families perform orchestration; their
difference is the source and shape of the assignment.

## Choose the workflow

| Request | Skill family | Required input |
|---|---|---|
| Fix, refactor, investigate, or edit requested documents | `delegate-work-<agent>` | A bounded task from the user |
| Discuss an approach or get a second opinion | `delegate-work-<agent>` | A question and desired insight |
| Implement an approved plan by phase | `orchestrate-implementation-<agent>` | An existing approved plan |
| Split a task across Codex, agy, and pi in parallel | `delegate-work-swarm` | A task with separately reviewable pieces |
| Implement an approved plan with parallel workers | `orchestrate-implementation-swarm` | An existing approved plan |

A request to "delegate implementation based on the approved plan" belongs to plan
implementation. A request to "discuss this plan" belongs to discussion. The presence of
a `plans/` folder alone does not determine the workflow.

Plan implementation skills check their prerequisite before CLI checks, handoff creation,
dispatch, or project changes. If an explicitly named plan is missing or unreadable,
they report that exact problem without substituting another plan. If no plan is available,
they stop the plan workflow and recommend `delegate-work-<agent>`. Approval already given
in the conversation remains valid.

Use explicit invocation when available in the host, or name the skill and its local
`SKILL.md` path. A repository copy must be made available to the host before normal skill
discovery can select it.

```text
Use $delegate-work-codex to investigate why search pagination skips results.
Preserve the existing API. Do not commit.

Use $delegate-work-codex to discuss whether this design handles retries correctly.
Compare alternatives and challenge assumptions. Do not implement changes.

Use $orchestrate-implementation-codex to implement the approved plan at
plans/search-pagination.md. Do not commit.

Use $delegate-work-agy to fix the search pagination bug. Preserve the existing API
and verify the affected flow. Do not commit.

Use $delegate-work-agy to discuss whether this architecture handles worker crashes.
Compare alternatives and challenge assumptions. Do not implement changes.

Use $orchestrate-implementation-agy to implement the approved plan at
plans/search-pagination.md. Do not commit.
```

## Current agent differences

| Agent | Direct task skill | Plan implementation behavior |
|---|---|---|
| Codex | [delegate-work-codex](../skills/delegate-work-codex/SKILL.md), explicit discussion support | [orchestrate-implementation-codex](../skills/orchestrate-implementation-codex/SKILL.md), fresh thread per phase, missing-plan fallback, leaves changes uncommitted |
| Antigravity | [delegate-work-agy](../skills/delegate-work-agy/SKILL.md), explicit discussion support, run identity capture | [orchestrate-implementation-agy](../skills/orchestrate-implementation-agy/SKILL.md), fresh conversation per phase, run identity capture, missing-plan fallback, leaves changes uncommitted |
| pi | [delegate-work-pi](../skills/delegate-work-pi/SKILL.md), one session per assignment, explicit discussion support, manual compaction | [orchestrate-implementation-pi](../skills/orchestrate-implementation-pi/SKILL.md), fresh session per phase, missing-plan fallback, leaves changes uncommitted |
| Claude Code | [delegate-work-claude](../skills/delegate-work-claude/SKILL.md), native subagent per assignment, explicit discussion support | [orchestrate-implementation-claude](../skills/orchestrate-implementation-claude/SKILL.md), fresh native implementor per phase, missing-plan fallback, leaves changes uncommitted |

All plan skills resolve their plan prerequisite first. If an explicitly named plan is missing
or unreadable, they report that path defect without substitution. If no plan is available,
they stop and recommend their corresponding direct task skill. All direct task skills support
both direct assignments and discussion-only consulting.

## Swarm

The swarm skills run several workers at once on Codex, agy, and pi. Each assignment gets a
level (low, mid, top) from how long it is and whether a test, type check, or lint rule
can judge it. The level and the user's ranking (Codex > agy >= pi, pi's place set by the
model it runs) pick the agent. Workers own disjoint files in one Git tree, and
`swarm-files.sh` snapshots each wave, credits every change to its owner, and restores a
failed worker's files before escalation. Failures are classified as unavailable,
environment, slip, or reasoning before any retry, and an unavailable agent never counts
toward escalation. The full rules, including the user-maintained pi model ranks table,
live in [swarm rules](../skills/delegate-work-swarm/references/swarm-rules.md).

## Discussion and follow-up

For discussion, the orchestrator defines a question and the evidence needed to assess it.
The worker may compare alternatives, challenge assumptions, and identify uncertainty.
The orchestrator evaluates the response and resumes the same thread or session for follow-up
questions or counterarguments.

A completed discussion round uses `done`. It does not need to resolve every open question
to finish its turn. Use `blocked` for a genuine blocker. Discussion alone does not
authorize implementation, and it does not require builds or tests merely to produce advice.
Verify factual claims and cited evidence where relevant.

Discussion defaults to no product edits. Put handoff records in writable temporary
storage when the project must remain read-only. Record useful conclusions and unresolved
questions in the work log.

## Handoffs and review

Direct task skills keep a brief, questions, answers, a work log, and a scratch prompt.
Editing tasks use `.orchestrate/<slug>/`; read-only tasks use temporary storage.
Plan implementation skills use `.orchestrate/<slug>/` with an implementation log.

The orchestrator preserves the initial working tree, index, HEAD, and pre-existing file
contents. It checks actual output against the assignment and acceptance criteria.
Worker summaries remain claims until reviewed. Resume the same thread or session for questions,
corrections, and verification within an assignment.

All direct task and plan implementation skills leave changes uncommitted for the user to review.

## Compaction and token reporting

Across all skills, a worker that observes context pressure or a compaction warning saves
a checkpoint, appends a question, and ends its turn as blocked. The checkpoint preserves
constraints, decisions, completed work, pending work, and verification evidence. The
orchestrator decides whether to continue or request manual compaction through a verified
supported mechanism. The worker does not request manual compaction independently.

This handoff policy does not veto automatic runtime compaction, which can occur before
a warning is emitted. Only use verified compaction capabilities:
- pi supports explicit RPC compaction with custom instructions (`compact`).
- Codex CLI helpers have no manual compaction command; manual compaction is an app-server feature.
- Antigravity manages context automatically at the engine level without a manual compaction CLI command.
- Claude subagents cannot be manually compacted; a fresh spawn per phase or assignment resets context.

Report counters only from actual runtime telemetry with their verified scope. Do not estimate
counts, sum cumulative counters as increments, or double-count cached input. Total tokens
spent differ from tokens occupying the current context. If usage is unavailable, say so.

Preserve relevant counters and diagnostics before another turn overwrites them or `stop`
removes helper state. After supported manual compaction, reload handoff records before
continuing. The orchestrator also maintains checkpoints for its own continuity.

## Troubleshooting and maintenance

### Codex version identity

The help-checked baseline is `codex-cli 0.162.1`, checked on 2026-10-11. It is a
documentation and invocation reference, not an enforced installation pin or a live-service
compatibility guarantee. Helper tests run against a mock CLI.

The latest stable release was independently confirmed as `0.162.1` on 2026-10-11, so the
existing baseline remains in place. The [maintenance record](../skills/delegate-work-codex/references/codex-cli-reference.md#maintenance-review-2026-10-11)
records official release sources and separate help, mock, source, and live evidence. Helpers
remain unchanged. The source audit establishes that `turn.completed.usage` carries thread
totals. Preserve snapshots and use the latest reliable total per thread; do not sum resume
snapshots. Actual counter continuity across live resumes was not exercised.

Both Codex helpers save `cli-version.txt` and `cli-path.txt` before each executed new or
resumed turn. The direct task helper stores these under `${TMPDIR:-/tmp}/codex-work-<slug>/`;
the plan helper uses `${TMPDIR:-/tmp}/codex-orch-<slug>/`. Copy the values into the work or
implementation log after every turn, before another turn overwrites them or `stop` removes
them. A failed version check prevents worker dispatch.

If the actual version differs from the baseline or the previous turn, inspect
`codex exec --help` and `codex exec resume --help`. Reproduce failures against the recorded
version and command path. A mismatch alone does not establish incompatibility or authorize
changing the installed CLI. Update the baseline deliberately after checking the new release.

### Antigravity version identity

The help-checked baseline is `1.3.3`, checked on 2026-10-11 at `/Users/amirinns/.local/bin/agy`.
It is a documentation and invocation reference, not an enforced installation pin or a live-service
compatibility guarantee. Helper tests run against a mock CLI.

Both Antigravity helpers save `cli-version.txt` and `cli-path.txt` before each executed new or
resumed turn. The direct task helper stores these under `${TMPDIR:-/tmp}/agy-work-<slug>/`;
the plan helper uses `${TMPDIR:-/tmp}/agy-orch-<slug>/`. Copy the values into the work log or
implementation log after every turn, before another turn overwrites them or `stop` removes
them. A failed version check prevents worker dispatch.

If the actual version differs from the baseline or the previous turn, inspect `agy --help` and
`agy changelog`. Reproduce failures against the recorded version and command path. A mismatch
alone does not establish incompatibility or authorize changing the installed CLI. Update the
baseline deliberately after checking the new release.

### pi version identity

The help-checked baseline is `pi 0.85.1`, checked on 2026-10-11 at `/opt/homebrew/bin/pi`.
It is a documentation and invocation reference, not an enforced installation pin or a
live-service compatibility guarantee. Helper tests run against a mock CLI.

Both pi helpers save `cli-version.txt` and `cli-path.txt` before each executed new or
resumed turn. The direct task helper stores these under `${TMPDIR:-/tmp}/pi-work-<slug>/`;
the plan helper uses `${TMPDIR:-/tmp}/pi-orch-<slug>/`. Copy the values into the work or
implementation log after every turn, before another turn overwrites them or `stop` removes
them. A failed version capture prevents worker dispatch.

If the actual version differs from the baseline or the previous turn, inspect `pi --help`
and the docs shipped with the installed CLI, resolved from the binary rather than a
hardcoded path. Reproduce failures against the recorded version and command path. A mismatch
alone does not establish incompatibility or authorize changing the installed CLI. Update the
baseline deliberately after checking the new release.

### Repair scope

Identify whether a failure comes from task code, the prompt or handoff, the helper, or the
agent runtime and environment. Reproduce a local defect, make the smallest authorized fix,
verify the repair, and resume the existing worker session when recoverable.

Use [Codex troubleshooting](../skills/delegate-work-codex/references/troubleshooting-and-bugfixes.md),
[Antigravity troubleshooting](../skills/delegate-work-agy/references/troubleshooting-and-bugfixes.md),
[pi troubleshooting](../skills/delegate-work-pi/references/troubleshooting-and-bugfixes.md),
and the corresponding CLI references for diagnostic files, supported commands, and official
documentation. Global configuration, credentials, installed binaries, and permission boundaries
are outside routine local fixes.

Use the [skill creation prompt](delegation-skill-creation-prompt.md) when creating or updating
variants. Inspect existing skills first, update only outdated behavior, and leave correct
variants unchanged. Verify each agent's actual capabilities before adapting a Codex mechanism.
