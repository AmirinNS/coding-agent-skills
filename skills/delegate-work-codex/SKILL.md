---
name: delegate-work-codex
description: "Delegate a general or coding task to the Codex CLI, handle discussion and questions through the same thread, and independently review the result. Takes scope from the user's request without requiring a plans/ folder, plan file, or planning skill. Use when asked to 'delegate work to codex', 'delegate this task to codex', or 'discuss this with a codex subagent', including fixes, refactors, investigations, advice, and requested document edits. Requires the external codex CLI. For phase-by-phase implementation of an approved plan, use orchestrate-implementation-codex instead."
---

# Delegate work to Codex

Keep coordination and review in the main session. Delegate work or discussion to a separate
`codex exec` thread, then inspect what it actually produced. The user's request and subsequent
answers define the task. Do not require, discover, or create a plan in `plans/`.

Use this skill for a direct request such as "Delegate this task to Codex". Route to
orchestrate-implementation-codex only when the request is to implement an existing approved
plan. The presence of a plans/ folder alone does not select the plan workflow.

Use one thread for one bounded assignment. Small tasks need one assignment. Split larger
requests only when there are distinct, reviewable pieces, and start a fresh thread for each
piece after reviewing the previous one. Resume the current thread for questions, corrections,
and verification. Carry decisions and results forward through the handoff files.

Leave changes uncommitted. Do not stage, commit, publish, or run document-and-commit.
Documentation edits are allowed when requested, but do not add a documentation phase to
unrelated work. An investigation can finish with findings and no product edits.

For discussion or advice, define the question and desired insight as the assignment. Default
to no product edits and use temporary handoff files. The worker may offer alternatives,
challenge assumptions, and identify uncertainty. The orchestrator evaluates the evidence
and resumes the same thread for follow-up questions or counterarguments. Each completed
discussion round uses `done`; use `blocked` only for a real blocker. Record useful conclusions
and open questions in the work log. Discussion alone does not authorize implementation.

## 1. Define the assignment

Read the request, relevant project instructions, and enough of the actual execution flow to
scope the work. Check `codex --version`. If it is missing, stop and report that prerequisite.
If authentication fails, report the error and ask the user to log in with `codex login`.

The CLI help baseline is `codex-cli 0.162.1`, checked on 2026-10-11. Helper checks use
a mock CLI; this is not a live-service compatibility guarantee. If the installed version
differs, inspect `codex exec --help` and `codex exec resume --help` before dispatch.
A version difference alone is not a failure and does not authorize an upgrade or downgrade.
Each executed turn records `cli-version.txt` and `cli-path.txt` in helper state. Copy these
values into the work log after each turn, before resume or stop overwrites or removes them.
Use the recorded version and executable path when reproducing a failure.

This baseline was rechecked against the latest stable release on 2026-10-11; see the
[maintenance record](references/codex-cli-reference.md#maintenance-review-2026-10-11)
for release sources and the separate help, mock, and live verification limits.

Define a brief with these fields:

- Request and expected result.
- Scope and explicit exclusions, including whether product files may be edited.
- User constraints and any assumptions that affect the result.
- Acceptance criteria and how each will be checked.
- Relevant files, commands, and instruction or skill paths already confirmed to exist.

Use a short task checklist when helpful. Do not add planning or approval gates for routine
choices already covered by the request. Ask only for missing information that materially
affects the outcome or for an action that needs authorization. Continue independent work
while waiting for an answer, but do not dispatch work that depends on it.

## 2. Prepare the handoff and baseline

Choose a unique run slug using lowercase letters, digits, and hyphens, such as
`fix-search-20261011-01`. It must be unique across active projects because helper state is
keyed by slug. Run the helper from the target project's root throughout the assignment.

For editing tasks, create `.orchestrate/<slug>/` with:

- `task.md`, the brief and assignment checklist. You maintain it as scope changes.
- `questions.md`, blocking questions appended by Codex.
- `answers.md`, your answers and their rationale, appended in order.
- `work-log.md`, assignment results and review outcomes, appended in order.
- `prompt.md`, scratch instructions overwritten each turn.

For a task that must leave the project read-only, put these handoff files in a temporary
directory instead. Use its absolute paths in prompts. This directory must be writable
within the existing sandbox. Never overwrite an earlier run's handoff files.

Before dispatch, capture the actual initial state. In a Git project, read and save
`git status --porcelain`, `git diff --binary`, `git diff --cached --binary`, and the current
HEAD if one exists. Preserve content copies of pre-existing changed and untracked files
in temporary storage so later edits to them can be distinguished from the user's work.
For later assignments, take a fresh baseline that includes completed work. Outside Git,
use content copies or hashes of the files in scope and record the existing file list.
Keep baseline storage outside the project. Do not stash, reset, or clean the user's tree.

## 3. Delegate and handle replies

The bundled `codex-exec.sh` starts and resumes threads, captures the final message, and
keeps transient state under `${TMPDIR:-/tmp}/codex-work-<slug>/`.

```bash
bash <skill-dir>/codex-exec.sh <slug> new <handoff-dir>/prompt.md
bash <skill-dir>/codex-exec.sh <slug> resume <handoff-dir>/prompt.md
bash <skill-dir>/codex-exec.sh <slug> thread
bash <skill-dir>/codex-exec.sh <slug> stop
```

Write the dispatch prompt below, then use `new`. Long turns must use the host tool's
supported asynchronous execution and polling mechanism. Do not invent background flags
or leave the user without progress updates. Set `CODEX_ORCH_MODEL` only when the user
requests a model override. The helper uses `workspace-write`, supports directories outside
Git, and does not explicitly enable network access. Never bypass the sandbox or widen
permissions to get a check to pass. Route a blocked action to the main session.

Each final response must end with exactly one fenced JSON block:

```json
{"status":"done","assignment":"task-1","summary":"Result","files":[],"checks":[{"cmd":"actual command","result":"pass","detail":"evidence"}],"pending":[]}
```

or:

```json
{"status":"blocked","assignment":"task-1","summary":"What blocks progress","questions":["Q1"],"pending":[]}
```

`done` means the worker finished its turn. Inspect the checks and pending items before
deciding whether the assignment is complete. Check results are `pass`, `fail`, or `skipped`.
Skipped checks need a reason and remain unverified.

For `blocked`, read the questions. Answer from the request, project conventions, or existing
code when those settle the issue. Ask the user when a material decision remains. Record
answers before resuming so later threads can read them. Preserve prior authorization.

Use sequential `Q1`, `Q2`, and matching `A1`, `A2` entries across the run. Each question
records context, the question, and options if useful. Each answer records the decision and
a short rationale. Resume with an instruction to read the new answers, continue from where
it stopped, and keep the same response contract.

A failed helper run is not successful work. Read
[Codex troubleshooting and bugfixes](references/troubleshooting-and-bugfixes.md) to identify
whether the problem is task code, the prompt, the helper, or the CLI/environment. Use the
[Codex CLI reference](references/codex-cli-reference.md) for confirmed command shapes,
diagnostic files, and official documentation. Fix reproducible local defects within the
authorized scope, verify the repair, and resume the existing thread when recoverable.
If its final status is missing or malformed, resume once to request a corrected report.
If recovery fails, stop and report what is incomplete. Do not keep retrying the same failed
approach or silently start over in a new thread. This recovery path does not override the
material-drift halt in step 4.

### Context pressure and compaction

If the worker observes a context-pressure or compaction warning, it must save a checkpoint,
append a question, and end the turn as blocked. The checkpoint records constraints,
decisions, completed and pending work, and verification evidence. The orchestrator decides
whether to continue or request manual compaction through a verified supported mechanism.
The worker must not request manual compaction on its own.

Codex runtime automatic compaction can still occur before this exchange; this policy does
not provide a runtime veto. The current helper has no manual compaction command. Do not
invent one. See [token usage and compaction](references/codex-cli-reference.md#token-usage-and-compaction)
for observable usage counters and the limits of the current integration.

At the checked baseline, `turn.completed.usage` is populated from thread totals, not
independent per-turn increments. Copy each observed usage snapshot into the work log before
resume or stop removes it. Use the latest reliable total for that thread; never sum its
resume snapshots or add cached input and reasoning output to their parent counters.
If counters are missing, reset, or incomplete, report the affected total as unavailable.

## 4. Review and verify

Compare the actual outputs and changes against the assignment baseline and acceptance
criteria. Inspect untracked files as well as tracked diffs. Preserve unrelated changes.
Recheck HEAD and the index against their recorded baseline. Do not infer content stability
from an unchanged `git status` alone.

Review judgment stays in the main session. Use implementation-review for code changes when
available and its prerequisites are already present. Review against the task brief and skip
its optional plan search. Otherwise review the changed code directly without adding a file
or planning prerequisite. For non-code work, verify findings or artifacts against the request.
Read cited locations, trace changed behavior through its callers, and confirm new modules
are connected to the real entry point. Treat worker summaries as claims until checked.

Correct ordinary in-scope defects, either yourself during review or through a bounded
`resume` request. If the same correction fails twice, reassess the cause and report the
remaining blocker instead of repeating it. Do not expand scope to fix unrelated findings.

For mechanical checks, resume with the verification prompt below. Before and after this
turn, compare file contents or hashes, the tracked diff, and the untracked file list.
Verification permits normal test or build artifacts but no edits to source, requested
deliverables, or handoff files. Inspect unexpected changes rather than treating them as
harmless just because status entries look the same.

For discussion-only work, verify factual claims and cited evidence where relevant. Do not
require builds, tests, or implementation artifacts solely to complete a discussion.

Run checks proportionate to the change. A bug fix needs an observed reproduction before
the fix and a passing check afterward. Use the project's real commands. For an app behavior
change, exercise the affected flow in the running app when available. Use run-expo-android
for an Expo or React Native app when that skill is available and applicable. Report any
runtime check that could not be exercised as pending.

Halt for material drift, including unauthorized scope expansion, damage to pre-existing
work, a security violation, fabricated verification, source edits during verification, or
changes to HEAD or the index. Stop the worker if still running. Report concrete evidence,
impact, and the smallest recovery options. Do not automatically revert files or continue
the affected work until the user resolves the incident. Ordinary in-scope defects belong
in the correction loop above.

## 5. Finish

After review, append the outcome, verified checks, and unresolved items to `work-log.md`.
Capture any useful diagnostics before `stop`, which removes the helper's transient state.
Remove only this run's scratch `prompt.md`; retain the brief and handoff record for editing
tasks. Do not delete requested deliverables.

Read `git status --porcelain` when Git is available and compare it against the baseline.
Account for every new change, including handoff records. Leave existing staging untouched.
Summarize the result, important files or findings, checks actually run, and pending items.
State that changes remain uncommitted. Do not claim completion if required work is blocked.

## Dispatch prompt

Fill in this template with the actual brief, assignment, paths, and available skill paths.
Omit unavailable skills rather than asking the worker to guess where they are installed.

````markdown
You are the worker for a bounded task. The main session directs you and independently
reviews your output. It replies by resuming this same thread.

Assignment: <id and concrete requested result>
Brief: <absolute path to task.md>
Questions: <absolute path to questions.md>
Answers: <absolute path to answers.md>
Work log: <absolute path to work-log.md>
Product edits allowed: <yes or no, with scope>
Discussion-only assignment: <yes or no; if yes, the question and desired insight>
Relevant instructions and skills: <confirmed paths and when each applies>

Read the brief, applicable project instructions, prior answers, and prior work-log entries.
Use the request as scope. No plans/ folder or plan file is required. Do not edit the brief
or answers. Treat answers as binding within the user's authorization.

For discussion-only assignments, provide reasoning, alternatives, evidence where relevant,
and remaining uncertainty. Do not implement suggestions. A completed discussion round is
done even when the orchestrator may ask follow-up questions by resuming this thread.

Trace the actual behavior and callers before changing code. Preserve unrelated existing
work. Apply relevant available skills to the actual work, including UI and Python skills
when appropriate. Do not stage, commit, publish, bypass the sandbox, or add unrequested
documentation. Requested documentation edits are allowed within scope.

Run the acceptance checks and read their output. For a bug fix, reproduce the failure
before editing. Never report a stub, fabricated finding, or unrun check as completed work.
If blocked by a material ambiguity, missing access, or authorization, append a numbered
question to the questions file and end with blocked status. Do not guess around it.

If you observe a context-pressure or compaction warning, save a checkpoint in the work log,
append a question, and end with blocked status. Let the orchestrator decide whether to
request manual compaction. Report token counters only when available from actual runtime
telemetry; otherwise state that they are unavailable. Do not estimate them.

Append a result to the work log with the assignment, files or findings, checks and evidence,
skills used, deviations, and pending items. End every turn with exactly one fenced JSON
block using the provided done or blocked response contract: <paste contract from this skill>.
````

## Verification prompt

````markdown
I have reviewed assignment <id>. Verify it with these checks: <confirmed commands and
acceptance criteria, including the affected runtime flow where applicable>.

Run checks and report results only. Do not edit source, requested deliverables, or handoff
files. Normal generated test and build artifacts are allowed. Do not stage, commit, fix
failures, bypass the sandbox, or perform unauthorized external actions.

Read each command's output. Give one entry per check, with pass, fail, or skipped and
concrete evidence. Quote the decisive failing line. A sandbox-blocked check is skipped,
not passed. Report unexercised runtime behavior in pending. Use the same final JSON
contract. A done status reports the end of this verification turn even when checks fail.
````
