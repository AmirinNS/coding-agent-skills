---
name: delegate-work-droid
description: "Delegate a general or coding task to a Droid worker through the droid CLI (droid exec), handle discussion and questions through the same session, and independently review the result. Takes scope from the user's request without requiring a plans/ folder, plan file, or planning skill. Use when asked to 'delegate work to droid', 'delegate this task to a droid worker', or 'discuss this with a droid subagent', including fixes, refactors, investigations, advice, and requested document edits. Requires the external droid CLI. For phase-by-phase implementation of an approved plan, use orchestrate-implementation-droid instead."
---

# Delegate work to a Droid worker

Keep coordination and review in the main session. Delegate work or discussion to a separate
Droid session driven through `droid exec`, then inspect what it actually produced. The worker
runs the same Droid harness as this session, in its own session and context. The user's
request and subsequent answers define the task. Do not require, discover, or create a plan
in `plans/`.

Use this skill for a direct request such as "Delegate this task to droid". Route to
orchestrate-implementation-droid only when the request is to implement an existing approved
plan. The presence of a plans/ folder alone does not select the plan workflow.

Use one session for one bounded assignment. Small tasks need one assignment. Split larger
requests only when there are distinct, reviewable pieces, and start a fresh session for each
piece after reviewing the previous one. Resume the current session for questions,
corrections, and verification. Carry decisions and results forward through the handoff
files.

Leave changes uncommitted. Do not stage, commit, publish, or run document-and-commit.
Documentation edits are allowed when requested, but do not add a documentation phase to
unrelated work. An investigation can finish with findings and no product edits.

Image generation is a valid assignment. The brief must give the exact output path for each
image, and review means opening each file and checking it against the brief.

For discussion or advice, define the question and desired insight as the assignment. Default
to no product edits and use temporary handoff files. The worker may offer alternatives,
challenge assumptions, and identify uncertainty. The orchestrator evaluates the evidence
and resumes the same session for follow-up questions or counterarguments. Each completed
discussion round uses `done`; use `blocked` only for a real blocker. Record useful conclusions
and open questions in the work log. Discussion alone does not authorize implementation.

## How this differs from orchestrate-implementation-droid

Both delegate file-level work to a Droid session while the main session keeps review. The
difference is where the task comes from and the unit of work.

| | `delegate-work-droid` | `orchestrate-implementation-droid` |
|---|---|---|
| Task source | the user's request, sized by you | an approved plan in `plans/`, split into phases |
| Unit of work | one bounded assignment | one phase, in order, until the plan is done |
| Handoff files | `.orchestrate/<slug>/` (or temp) | `.orchestrate/<slug>/` |
| Commit policy | never commit, changes stay uncommitted | never commit, changes stay uncommitted |
| Session lifetime | one session per assignment | fresh session per phase |

If the work is phased implementation of an approved plan, use
`orchestrate-implementation-droid`. If the user asked for a task without a plan, stay here.

## 1. Define the assignment

Read the request, relevant project instructions, and enough of the actual execution flow to
scope the work. Check `droid --version`. If it is missing, stop and report that prerequisite.
If a turn fails on authentication or billing (for example a `429` credit error), run
`droid doctor`, report the result, and ask the user to fix the prerequisite. Do not work
around a credentials failure and do not silently switch models.

The help-checked baseline is `droid 0.251.0`, checked on 2026-10-29 at
`/Users/amirinns/.local/bin/droid`. Helper checks use a mock CLI, so they do not establish
live service compatibility for that release. If the installed version differs, read
`droid exec --help` and `droid resume --help` before dispatch. A version difference alone is
not a failure and does not authorize an upgrade or downgrade.

Each executed turn records `cli-version.txt` and `cli-path.txt` under
`${TMPDIR:-/tmp}/droid-work-<slug>/`. Copy both values into the work log after every turn,
before a later turn overwrites them or `stop` removes them. A failed version capture stops
the turn instead of dispatching the worker. Use the recorded version and command path when
reproducing a failure; the path may identify a wrapper rather than the underlying executable.

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
`fix-search-20261029-01`. It must be unique across active projects because helper state is
keyed by slug. Run the helper from the target project's root throughout the assignment.

For editing tasks, create `.orchestrate/<slug>/` with:

- `task.md`, the brief and assignment checklist. You maintain it as scope changes.
- `questions.md`, blocking questions appended by the worker.
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

The bundled `droid-exec.sh` starts and resumes sessions, captures the final message, and
keeps transient state under `${TMPDIR:-/tmp}/droid-work-<slug>/`.

```bash
bash <skill-dir>/droid-exec.sh <slug> new <handoff-dir>/prompt.md [auto]
bash <skill-dir>/droid-exec.sh <slug> resume <handoff-dir>/prompt.md [auto]
bash <skill-dir>/droid-exec.sh <slug> session
bash <skill-dir>/droid-exec.sh <slug> stop
```

`auto` is the autonomy level for the turn and maps to `droid exec --auto <level>`. Choose
the lowest level that covers the assignment, and record the level in the work log:

- `none` (default, omit) for read-only analysis, investigation, and discussion.
- `low` for edit-only work with no installs, builds, or tests.
- `medium` when the assignment must install dependencies, build, or run tests. This level
  also permits local `git commit`, so the prompt forbids it and review detects it.

Never pass `--skip-permissions-unsafe`, never use `high` for this workflow, and never raise
the level mid-assignment to force a blocked action through. A fail-fast permission stop is
an environment fact: route the action to the main session or ask the user.

Write the dispatch prompt below, then use `new`. Long turns must use the host tool's
supported asynchronous execution and polling mechanism. Do not invent background flags
or leave the user without progress updates. Set `DROID_ORCH_MODEL` only when the user
requests a model override. Never bypass permission checks or widen trust to get a check
to pass. Route a blocked action to the main session.

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
answers before resuming so later sessions can read them. Preserve prior authorization.

Use sequential `Q1`, `Q2`, and matching `A1`, `A2` entries across the run. Each question
records context, the question, and options if useful. Each answer records the decision and
a short rationale. Resume with an instruction to read the new answers, continue from where
it stopped, and keep the same response contract.

A failed helper run is not successful work. Read
[Droid troubleshooting and bugfixes](references/troubleshooting-and-bugfixes.md) to identify
whether the problem is task code, the prompt, the helper, or the CLI/environment. Use the
[Droid CLI reference](references/droid-cli-reference.md) for confirmed command shapes,
diagnostic files, and official documentation. Fix reproducible local defects within the
authorized scope, verify the repair, and resume the existing session when recoverable.
If its final status is missing or malformed, resume once to request a corrected report.
If recovery fails, stop and report what is incomplete. Do not keep retrying the same failed
approach or silently start over in a new session. This recovery path does not override the
material-drift halt in step 4.

### Context pressure and compaction

If the worker observes a context-pressure or compaction warning, it must save a checkpoint,
append a question, and end the turn as blocked. The checkpoint records constraints,
decisions, completed and pending work, and verification evidence. The orchestrator decides
whether to continue or to start a fresh session that reads the handoff files. The worker
must not request manual compaction on its own.

Droid compacts sessions automatically near a configured threshold. The helper drives
one-shot `droid exec` turns and has no manual compaction command; do not invent one or
change global compaction settings. See
[token usage and compaction](references/droid-cli-reference.md#token-usage-and-compaction)
for what is observable and the limits of the current integration.

Copy each turn's `usage.json` snapshot into the work log before the next turn or `stop`
removes it. Usage is per turn: one turn combines its model calls, and later turns count
earlier conversation again when they replay it as input. Never sum input or cache counters
across turns, and never estimate counters that are missing. Context occupancy is not
exposed through `droid exec`; report it as unavailable.

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
deliverables, or handoff files. Run verification turns at `medium` when they execute tests
or builds; the before-and-after diff is the read-only control, because the autonomy tiers
have no level that runs tests while blocking edits. Inspect unexpected changes rather than
treating them as harmless just because status entries look the same.

For discussion-only work, verify factual claims and cited evidence where relevant. Do not
require builds, tests, or implementation artifacts solely to complete a discussion.

Run checks proportionate to the change. A bug fix needs an observed reproduction before
the fix and a passing check afterward. Use the project's real commands. For an app behavior
change, exercise the affected flow in the running app when available. Use run-expo-android
for an Expo or React Native app when that skill is available and applicable. Report any
runtime check that could not be exercised as pending.

Halt for material drift, including unauthorized scope expansion, damage to pre-existing
work, a security violation, fabricated verification, source edits during verification, or
changes to HEAD or the index. `--auto medium` permits local `git commit`, so treat a commit,
a push, or a detached HEAD change as material drift even when the diff looks correct. Stop
the worker if still running. Report concrete evidence, impact, and the smallest recovery
options. Do not automatically revert files or continue the affected work until the user
resolves the incident. Ordinary in-scope defects belong in the correction loop above.

## 5. Finish

After review, append the outcome, verified checks, and unresolved items to `work-log.md`.
Capture any useful diagnostics and the last `usage.json` before `stop`, which removes the
helper's transient state. The Droid session itself stays in the local session store and
remains searchable; note the session id in the work log. Remove only this run's scratch
`prompt.md`; retain the brief and handoff record for editing tasks. Do not delete requested
deliverables.

Read `git status --porcelain` when Git is available and compare it against the baseline.
Account for every new change, including handoff records. Leave existing staging untouched.
Summarize the result, important files or findings, checks actually run, and pending items.
State that changes remain uncommitted. Do not claim completion if required work is blocked.

## Dispatch prompt

Fill in this template with the actual brief, assignment, paths, and available skill paths.
Omit unavailable skills rather than asking the worker to guess where they are installed.

````markdown
You are the worker for a bounded task. The main session directs you and independently
reviews your output. It replies by resuming this same session.

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
done even when the orchestrator may ask follow-up questions by resuming this session.

Trace the actual behavior and callers before changing code. Preserve unrelated existing
work. Apply relevant available skills to the actual work, including UI and Python skills
when appropriate. This session runs under an autonomy tier, not a sandbox, so never run a
command that leaves this repository: do not stage, commit, push, tag, publish, or modify
Git config or remotes. Do not delegate onward to subagents or missions; do the work in
this session. Do not add unrequested documentation. Requested documentation edits are
allowed within scope.

Run the acceptance checks and read their output. For a bug fix, reproduce the failure
before editing. Never report a stub, fabricated finding, or unrun check as completed work.
If blocked by a material ambiguity, missing access, or authorization, append a numbered
question to the questions file and end with blocked status. Do not guess around it.

If you observe a context-pressure or compaction warning, save a checkpoint in the work log,
append a question, and end with blocked status. Let the orchestrator decide how to
continue. Report token counters only when available from actual runtime telemetry; otherwise
state that they are unavailable. Do not estimate them.

Append a result to the work log with the assignment, files or findings, checks and evidence,
skills used, deviations, and pending items. End every turn with exactly one fenced JSON
block using the provided done or blocked response contract: <paste contract from this skill>.
````

## Verification prompt

````markdown
I have reviewed assignment <id>. Verify it with these checks: <confirmed commands and
acceptance criteria, including the affected runtime flow where applicable>.

Run checks and report results only. Do not edit source, requested deliverables, or handoff
files. Normal generated test and build artifacts are allowed. Do not stage, commit, push,
fix failures, or perform unauthorized external actions.

Read each command's output. Give one entry per check, with pass, fail, or skipped and
concrete evidence. Quote the decisive failing line. A blocked or unavailable check is
skipped, not passed. Report unexercised runtime behavior in pending. Use the same final JSON
contract. A done status reports the end of this verification turn even when checks fail.
````

## Helper script

`droid-exec.sh` ships next to this skill. Commands:

```bash
bash droid-exec.sh <slug> new <prompt-file> [auto]     # fresh session, first prompt, wait
bash droid-exec.sh <slug> resume <prompt-file> [auto]  # next prompt on the current session
bash droid-exec.sh <slug> session                      # print the current session id
bash droid-exec.sh <slug> stop                         # kill a running turn, clear state
```

State lives under `${TMPDIR:-/tmp}/droid-work-<slug>/`: `events.jsonl` (the stream-json
event stream, including tool calls the worker ran), `last.txt` (the final message),
`usage.json` (the turn's usage counters), `err.log`, `session`, and the captured CLI
identity. `stop` removes this state only; the Droid session remains in the local session
store. The last turn's final message is also available from the helper's stdout.

## Rules

- Scope comes from the user's request, never from a plan. Do not require, discover, or
  create a `plans/` folder or plan file, and do not run plan-feature.
- One session per bounded assignment. Split only when the pieces are independently
  reviewable, and review each piece before starting the next session.
- Never stage, commit, push, publish, or run document-and-commit. Changes stay uncommitted
  for the user to inspect. `--auto medium` permits local git writes, so a commit is material
  drift, not a convenience.
- Choose the lowest autonomy level that covers the assignment. Never use
  `--skip-permissions-unsafe`, and never raise the level to push a blocked action through.
- Review judgment stays with you. The worker's summary is a claim; verify it against the
  diff, the untracked file list, and the recorded baseline.
- Recheck HEAD and the index after every worker turn.
- Treat a failed helper run as no work done. Inspect stderr and the event stream before
  retrying, and never silently restart in a new session.
- Keep the handoff files append-only. Never rewrite or renumber past entries.
- Answer the easy questions yourself. Ask the user only when a material decision remains.
