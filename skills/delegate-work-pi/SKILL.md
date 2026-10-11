---
name: delegate-work-pi
description: "Delegate a general or coding task to the pi CLI, handle discussion and questions through the same session, and independently review the result. Takes scope from the user's request without requiring a plans/ folder, plan file, or planning skill. Use when asked to 'delegate work to pi', 'delegate this task to pi', or 'discuss this with a pi subagent', including fixes, refactors, investigations, advice, and requested document edits. Requires the external pi CLI. For phase-by-phase implementation of an approved plan, use orchestrate-implementation-pi instead."
---

# Delegate work to pi

Keep coordination and review in the main session. Delegate work or discussion to a separate
`pi` session, then inspect what it actually produced. The user's request and subsequent
answers define the task. Do not require, discover, or create a plan in `plans/`.

Use this skill for a direct request such as "Delegate this task to pi". Route to
orchestrate-implementation-pi only when the request is to implement an existing approved
plan. The presence of a plans/ folder alone does not select the plan workflow.

Use one session for one bounded assignment. Small tasks need one assignment. Split larger
requests only when there are distinct, reviewable pieces, and start a fresh session for each
piece after reviewing the previous one. Resume the current session for questions, corrections,
and verification. Carry decisions and results forward through the handoff files.

Leave changes uncommitted. Do not stage, commit, publish, or run document-and-commit.
Documentation edits are allowed when requested, but do not add a documentation phase to
unrelated work. An investigation can finish with findings and no product edits.

For discussion or advice, define the question and desired insight as the assignment. Default
to no product edits and use temporary handoff files. The worker may offer alternatives,
challenge assumptions, explain reasoning, and identify uncertainty. The orchestrator evaluates
the evidence and resumes the same session for follow-up questions or counterarguments. Each
completed discussion round uses `done`; use `blocked` only for a real blocker. Record useful
conclusions and open questions in the work log. Discussion alone does not authorize implementation.

## How this differs from orchestrate-implementation-pi

Both delegate file-level work to a pi session while the main session keeps review. The
difference is where the task comes from and the unit of work.

| | `delegate-work-pi` | `orchestrate-implementation-pi` |
|---|---|---|
| Task source | the user's request, sized by you | an approved plan in `plans/`, split into phases |
| Unit of work | one bounded assignment | one phase, in order, until the plan is done |
| Handoff files | `.orchestrate/<slug>/` (or temp) | `.orchestrate/<slug>/` |
| Commit policy | never commit, changes stay uncommitted | never commit, changes stay uncommitted |
| Session lifetime | one session per assignment | fresh session per phase |

If the work is phased implementation of an approved plan, use `orchestrate-implementation-pi`.
If the user asked for a task without a plan, stay here.

## 1. Define the assignment

Read the request, relevant project instructions, and enough of the actual execution flow to
scope the work. Check `pi --version`. If it is missing, stop and report that prerequisite.
If a turn fails on credentials, run `pi auth check --provider <provider>` (add
`--model <pattern>` to check one model), report the result, and ask the user to fix
credentials. Do not work around a credentials failure.

The help-checked baseline is `pi 0.85.1`, checked on 2026-10-11 at `/opt/homebrew/bin/pi`.
Helper checks use a mock CLI, so they do not establish live service compatibility for that
release. If the installed version differs, read `pi --help` again before dispatch. A version
difference alone is not a failure and does not authorize an upgrade or downgrade.

Each executed turn records `cli-version.txt` and `cli-path.txt` under
`${TMPDIR:-/tmp}/pi-work-<slug>/`. Copy both values into the work log after every turn,
before a later turn overwrites them or `stop` removes them. A failed version capture stops
the turn instead of dispatching the worker. Use the recorded version and command path when
reproducing a failure; the path may identify a wrapper rather than the underlying
executable.

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
- `questions.md`, blocking questions appended by the worker.
- `answers.md`, your answers and their rationale, appended in order.
- `work-log.md`, assignment results and review outcomes, appended in order.
- `prompt.md`, scratch instructions overwritten each turn.

For a task that must leave the project read-only, put these handoff files in a temporary
directory instead. Use their absolute paths in prompts. Never overwrite an earlier run's
handoff files.

Before dispatch, capture the actual initial state. In a Git project, read and save
`git status --porcelain`, `git diff --binary`, `git diff --cached --binary`, and the current
HEAD if one exists. Preserve content copies of pre-existing changed and untracked files
in temporary storage so later edits to them can be distinguished from the user's work.
For later assignments, take a fresh baseline that includes completed work. Outside Git,
use content copies or hashes of the files in scope and record the existing file list.
Keep baseline storage outside the project. Do not stash, reset, or clean the user's tree.

## 3. Delegate and handle replies

The bundled `pi-work.sh` starts and resumes sessions, captures the final message, and keeps
transient state under `${TMPDIR:-/tmp}/pi-work-<slug>/`.

```bash
bash <skill-dir>/pi-work.sh <slug> new <handoff-dir>/prompt.md
bash <skill-dir>/pi-work.sh <slug> resume <handoff-dir>/prompt.md
bash <skill-dir>/pi-work.sh <slug> compact ["<instructions>"]
bash <skill-dir>/pi-work.sh <slug> session
bash <skill-dir>/pi-work.sh <slug> stop
```

`new` starts a session with its own id (`delegate-<slug>`, then `delegate-<slug>-2`, and so
on), so a later assignment never inherits an earlier one's context. `resume` continues the
current session and fails if none is running. If a session dies mid-assignment, start `new`
and let the handoff files carry the state; do not assume `resume` can revive it.

Write the dispatch prompt below, then use `new`. The helper blocks until the turn settles or
the idle timeout fires, so run it with the host tool's supported long-running execution and a
timeout above `PI_WORK_IDLE_TIMEOUT` (default 600). Set `PI_ORCH_MODEL` only when the user
requests a model override; it accepts a `provider/id` pattern with an optional `:<thinking>`
suffix.

pi runs with no sandbox. The worker can run any command, including `git commit` and `git
push`. The dispatch prompt forbids it and review rechecks HEAD and the index, but that is a
detection control, not a barrier. Never widen trust to get a check to pass.

### Context pressure and compaction

If the worker observes a context-pressure or compaction warning, it must save a checkpoint,
append a question, and end the turn as blocked. The checkpoint records constraints,
decisions, completed and pending work, and verification evidence. The orchestrator decides
whether to continue or request manual compaction through `bash pi-work.sh <slug> compact ["<instructions>"]`.
The worker must not request manual compaction on its own.

Automatic compaction can still occur near provider context limits before this exchange; this
policy does not provide a runtime veto. A `Nothing to compact (session too small)` reply is a
soft skip, not a failure. After supported manual compaction, reload the handoff records before
continuing. Use actual runtime telemetry from `get_session_stats` for token reports; if
counters are unavailable, report that limitation explicitly instead of estimating.

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

A failed helper run is not successful work. Inspect its stderr and event stream before
retrying. If its final status is missing or malformed, resume once to request a corrected
report. If recovery fails, stop and report what is incomplete. Do not keep retrying the same
failed approach or silently start over in a new session.

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
changes to HEAD or the index. Because pi has no sandbox, treat a commit, a push, or a
detached HEAD change as material drift even when the diff looks correct. Stop the worker if
still running. Report concrete evidence, impact, and the smallest recovery options. Do not
automatically revert files or continue the affected work until the user resolves the
incident. Ordinary in-scope defects belong in the correction loop above.

## 5. Finish

After review, append the outcome, verified checks, and unresolved items to `work-log.md`.
Capture any useful diagnostics before `stop`, which removes the helper's transient state and
its session files. Remove only this run's scratch `prompt.md`; retain the brief and handoff
record for editing tasks. Do not delete requested deliverables.

Read `git status --porcelain` when Git is available and compare it against the baseline.
Account for every new change, including handoff records. Leave existing staging untouched.
Summarize the result, important files or findings, checks actually run, and pending items.
State that changes remain uncommitted. Do not claim completion if required work is blocked.

## When the pi worker itself is the problem

A failed turn is not automatically a worker mistake. Separate the two before acting. A
**worker problem** (wrong code, scope creep, a fabricated check, a commit) stays in the
correction loop in step 4. A **pi problem** (the CLI, the RPC session, the helper script,
credentials, model selection) needs diagnosis, not another dispatch.

### Where the state is

Everything for a run lives in `${TMPDIR:-/tmp}/pi-work-<slug>/`: `events.jsonl` (the full
event stream), `err.log` (pi's stderr), `cmds.log` (the commands you sent), and the session
file. `send` queries the live session without disturbing it:

```bash
bash pi-work.sh <slug> send '{"type":"get_state"}'               # model, isStreaming, messageCount
bash pi-work.sh <slug> send '{"type":"get_session_stats"}'       # tokens, cost, contextUsage
bash pi-work.sh <slug> send '{"type":"get_last_assistant_text"}'
bash pi-work.sh <slug> send '{"type":"get_messages"}'
bash pi-work.sh <slug> send '{"type":"get_entries","since":"<entryId>"}'
bash pi-work.sh <slug> send '{"type":"abort"}'                   # stop a running turn
bash pi-work.sh <slug> send '{"type":"abort_retry"}'             # stop a retry loop
```

### Triage

| Symptom | Likely cause | What to check |
|---|---|---|
| `no events for ~600s` | the turn stalled or is waiting on something | `get_state` for `isStreaming`, then `tail events.jsonl`, then `abort` |
| `session ... died` | pi exited | `tail err.log`; look for `extension_error`, `auto_retry_end` with `finalError` |
| worker forgets the brief mid-assignment | context pressure | `get_session_stats` `contextUsage`; auto-compaction fires near the window limit, so compact early with instructions if the worker is drifting |
| turn never settles, events keep flowing | automatic retry or compaction retry | `auto_retry_start`, `compaction_start`, `summarization_retry_scheduled` in the stream, then `abort_retry` |
| a commit, push, or HEAD change appeared | no sandbox, worker ignored the prompt | material drift, step 4; then `get_entries` to find the tool call |
| credentials or model errors | auth or model selection | `pi auth check --provider <provider> --model <pattern>` |

`agent_end` is not the end. One low-level run can be followed by an automatic retry or a
compaction retry, which is why the helper waits for `agent_settled`. If events keep arriving
after `agent_end`, look for the retry and compaction events before assuming the session hung.

### pi documentation

The docs ship with the installed CLI and match its version. Resolve them from the binary
instead of hardcoding a path:

```bash
PI_PKG=$(cd "$(dirname "$(readlink -f "$(command -v pi)")")/../.." && pwd)
ls "$PI_PKG/docs"
```

| Problem | Doc |
|---|---|
| RPC commands, events, error shapes | `docs/rpc.md` |
| Compaction triggers, split turns, cut points | `docs/compaction.md` |
| Session file layout, entry ids, forking | `docs/sessions.md`, `docs/session-format.md` |
| `PI_*` variables, shell tool environment | `docs/environment-variables.md` |
| Model and provider selection | `docs/models.md`, `docs/providers.md` |
| Project trust, `-a`, no built-in sandbox | `docs/security.md` |
| Real isolation for untrusted work | `docs/containerization.md` |
| Building or patching pi, the `/debug` log | `docs/development.md` |

Upstream source and issues: https://github.com/earendil-works/pi

### Fixing it

- **Helper script bug** (`pi-work.sh`): fix it in this repo with the `fix-bug` skill, and
  leave a check that runs the helper against a throwaway slug.
- **pi bug**: reproduce with the smallest prompt that fails, capture `events.jsonl`,
  `err.log`, and `pi --version`, then report it upstream. Do not patch the installed package
  to unblock a run; a local edit disappears on the next `pi update`.
- **Credentials or model**: report the `pi auth check` result and ask the user to fix it.
  Never switch provider or model to route around a failure the user did not ask for.
- **Worker context**: compact with instructions, or start a fresh assignment. The handoff
  files are the recovery path, so bring `task.md`, `answers.md`, and `work-log.md` up to date
  first.

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
when appropriate. You have no sandbox, so never run a command that leaves this repository:
do not stage, commit, push, tag, publish, or modify Git config or remotes. Do not add
unrequested documentation. Requested documentation edits are allowed within scope.

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
files. Normal generated test and build artifacts are allowed. Do not stage, commit, push,
fix failures, or perform unauthorized external actions.

Read each command's output. Give one entry per check, with pass, fail, or skipped and
concrete evidence. Quote the decisive failing line. A blocked or unavailable check is
skipped, not passed. Report unexercised runtime behavior in pending. Use the same final JSON
contract. A done status reports the end of this verification turn even when checks fail.
````

## Helper script

`pi-work.sh` ships next to this skill. Commands:

```bash
bash pi-work.sh <slug> new <prompt-file>     # fresh session, first prompt, wait for settled
bash pi-work.sh <slug> resume <prompt-file>  # next prompt on the current session
bash pi-work.sh <slug> compact ["<instr>"]   # compact the session, optional instructions
bash pi-work.sh <slug> send '<json>'         # raw RPC command, waits for its response
bash pi-work.sh <slug> session               # print the current session id
bash pi-work.sh <slug> stop                  # terminate and clean state
```

State lives under `${TMPDIR:-/tmp}/pi-work-<slug>/`, including the pi session files
(`--session-dir` points there), so `stop` leaves nothing behind. The event stream is in
`events.jsonl` there if you need to inspect tool calls the worker ran. The last turn's
final message is also available from the helper's stdout.

## Rules

- Scope comes from the user's request, never from a plan. Do not require, discover, or
  create a `plans/` folder or plan file, and do not run plan-feature.
- One session per bounded assignment. Split only when the pieces are independently
  reviewable, and review each piece before starting the next session.
- Never stage, commit, push, publish, or run document-and-commit. Changes stay uncommitted
  for the user to inspect.
- Review judgment stays with you. The worker's summary is a claim; verify it against the
  diff, the untracked file list, and the recorded baseline.
- Recheck HEAD and the index after every worker turn. pi has no sandbox, so a commit is
  possible and counts as material drift.
- Treat a failed helper run as no work done. Inspect stderr and the event stream before
  retrying, and never silently restart in a new session.
- Keep the handoff files append-only. Never rewrite or renumber past entries.
- Answer the easy questions yourself. Ask the user only when a material decision remains.
