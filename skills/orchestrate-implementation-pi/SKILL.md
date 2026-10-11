---
name: orchestrate-implementation-pi
description: "Implement an existing approved plan with the pi CLI, phase by phase. Requires a readable approved plan before any execution. Use for 'orchestrate with pi', 'implement the plan with pi', 'run the plan through pi', or 'delegate the implementation to pi'. For a direct task or when no plan is available, direct the user or calling orchestrator to delegate-work-pi instead. Starts a fresh session per phase, handles questions through resume, checks drift, and runs implementation-review. Drift halts with a CTO report. Leaves all work uncommitted and writes no feature documentation. Requires the external pi CLI. For the Claude-only equivalent, use orchestrate-implementation-claude."
---

# Orchestrate implementation (pi CLI)

You are the orchestrator. You do not write the phase code yourself. You delegate
implementation of an approved plan to `pi` through `pi-rpc.sh`, one phase at a time, and you
are the only bridge between that implementor and the user.

## Inputs and plan gate

- An existing approved plan at `plans/<slug>.md` (written by plan-feature, reviewed by plan-review).
- The target project is the current working directory.
- Optional: the user may specify a phase to start from, or override the pi model.

Resolve the plan before checking the CLI, creating handoff files, taking snapshots, starting
a pi session, or editing project files. This workflow must not execute without an existing,
readable approved plan. Use approval already established in the conversation.

- If the request is a direct task without an instruction to implement a plan, recommend
  `delegate-work-pi`. An unrelated `plans/` folder does not change that routing.
- If a plan path is supplied, verify that exact file exists and can be read. If it is missing
  or unreadable, report the path problem. Do not silently substitute another plan.
- If the request explicitly asks for plan implementation without a path, discover plan files
  only when `plans/` exists. Use `ls plans/*.md 2>/dev/null`, then identify actual implementation
  plans rather than index or reference documents. Ask which plan to use if several qualify.
- If no plan is available, stop this workflow and recommend `delegate-work-pi`. Do not
  require the user to run plan-feature or create a plan merely to delegate a task.

When a calling orchestrator selected this skill, return the routing recommendation with the
original task and constraints so it can select `delegate-work-pi`. When speaking directly
to the user, explain the missing prerequisite and offer this invocation:

```text
Use $delegate-work-pi to <the original task, with its constraints>.
```

If the user wants phased plan implementation, they can provide the existing approved plan
instead. Do not invent phases or run the plan workflow while waiting for that input.

## Why this exists

The main session keeps a clean, high-level context. The implementor does the file-level work
in its own pi session, so bulky file reads and test output never land in yours. Questions flow
up to you. You answer what you can, and only bother the user when the answer is a real
judgment call.

One pi session per phase, not one per run. A long session accumulates context that cannot be
isolated cleanly across phases. A fresh session per phase resets the context window and marks
the phase boundary. Continuity across phases comes from `.orchestrate/<slug>/implementation-log.md`,
which each new session reads first.

This skill stops at review. It does not write documentation and does not commit, ever. pi
runs with no built-in sandbox, so the prompt strictly forbids staging and commits, and review
rechecks HEAD and the index. The whole run lands in the working tree for the user to inspect as
one change set, and they decide when to run `document-and-commit`.

## Prerequisite

Check that the CLI is installed:

```bash
pi --version
```

If it is missing, stop and tell the user to install the pi CLI. If a turn fails on
credentials, run `pi auth check --provider <provider>` (add `--model <pattern>` to check one
model), report the result, and ask the user to fix credentials.

### Run identity

The help-checked baseline is `pi 0.85.1`, checked on 2026-10-11 at `/opt/homebrew/bin/pi`.
Helper checks use a mock CLI, so they do not establish live service compatibility for that
release. If the installed version differs, read `pi --help` again before dispatch. A version
difference alone is not a failure and does not authorize an upgrade or downgrade.

Each executed turn records `cli-version.txt` and `cli-path.txt` under
`${TMPDIR:-/tmp}/pi-orch-<slug>/`. Copy both values into the implementation log after every
turn, before a later turn overwrites them or `stop` removes them. A failed version capture
stops the turn instead of dispatching the worker. Use the recorded version and command path
when reproducing a failure; the path may identify a wrapper rather than the underlying
executable.

## Talking with pi

pi runs each exchange as a turn:

1. You write a prompt to `.orchestrate/<slug>/prompt.md` and run the helper. It waits until pi
   ends its turn, then prints pi's final assistant text.
2. pi ends every turn with one fenced JSON block. `"status": "blocked"` means it asks a
   question and waits for an answer. `"status": "done"` means the assigned job is complete.
3. You reply by updating `.orchestrate/<slug>/prompt.md` and running `resume`. pi continues in
   the same session with its full context, including earlier file reads and edits.

That loop repeats as many times as the phase needs. pi asks questions, you answer, it resumes,
and completes the work. You can also start an exchange yourself: a redo request, a request to
restate a malformed report, or the validate pass. All of these go to the same session with
`resume`.

Helper commands (`pi-rpc.sh` ships next to this skill):

```bash
bash <skill-dir>/pi-rpc.sh <slug> new .orchestrate/<slug>/prompt.md     # fresh session, one per phase
bash <skill-dir>/pi-rpc.sh <slug> resume .orchestrate/<slug>/prompt.md  # next turn, same session
bash <skill-dir>/pi-rpc.sh <slug> compact ["<instructions>"]             # compact current session
bash <skill-dir>/pi-rpc.sh <slug> session                               # current session id
bash <skill-dir>/pi-rpc.sh <slug> stop                                  # kill running worker, clear state
```

A turn can run for several minutes. Run `new` and `resume` in the background when needed, then
read the output once notified it exited. The helper exits 1 when pi fails or when its event
stream stays silent for 10 minutes (`PI_RPC_IDLE_TIMEOUT`). Treat that as blocked with a
malformed report. Set `PI_ORCH_MODEL` on the command to override the model when the user asks
for one.

State lives under `${TMPDIR:-/tmp}/pi-orch-<slug>/`.

### Context pressure and compaction

If pi observes a context-pressure or compaction warning, it must save a checkpoint in the
implementation log, append a question, and end the turn as blocked. Preserve the plan
constraints, decisions, completed and pending milestones, and verification evidence.
The orchestrator decides whether to continue or request manual compaction through
`bash pi-rpc.sh <slug> compact ["<instructions>"]`. pi must not request manual compaction on
its own.

Automatic compaction can occur near provider context limits before the worker reports a
warning. Prompt instructions cannot guarantee control over automatic compaction. Do not
invent warning events or a runtime veto. After supported manual compaction, instruct pi on
the next resume to re-read the handoff files. Report token usage using actual telemetry from
`bash pi-rpc.sh <slug> send '{"type":"get_session_stats"}'`; if counters are unavailable,
report that limitation explicitly instead of estimating.

## Step 1: Read the plan and map its phases

Read `plans/<slug>.md`. Build an ordered list of phases, each with its milestones. Two
formats exist; detect which applies.

**A. Metadata block present** (pembina-style plans carry `## Metadata` with `phased` and
`phases`). Use it directly. Each entry in `phases` is a phase, and its `milestones` array is
the ordered milestone list.

**B. Heading-based** (current plan-feature output). Scan headings:
- A phase is a heading containing `Phase` (for example `### Phase A: Foundation`).
- A milestone is a heading containing `Milestone N` (for example `### Milestone 1: ...`).
- Each milestone belongs to the nearest phase heading above it. Milestones with no phase
  heading above them belong to an implicit first phase, or to the whole plan if no phase
  headings exist.
- If the plan has no phase headings, treat the whole plan as a single phase.

Record each phase's label (or `whole plan` when unphased) and its ordered milestone numbers.
This map drives the loop. Do not re-derive it mid-run.

## Step 2: Set up the run

Do these once.

Create these handoff files under `.orchestrate/<slug>/` at the project root, empty if missing.
`plans/` holds plan files only; commit `.orchestrate/` with the work so the run record stays reviewable:
- `.orchestrate/<slug>/questions.md`: implementor appends blocking questions.
- `.orchestrate/<slug>/answers.md`: you append answers.
- `.orchestrate/<slug>/implementation-log.md`: implementor appends a report after each phase.

The files are the durable record and the cross-phase handoff. The live session carries the
conversation within a phase; the files carry it across phases and survive the run.
`.orchestrate/<slug>/prompt.md` is scratch, overwritten every turn and deleted at the end.

Also record `git rev-parse HEAD` once, now. Nothing is committed during this run, so that
value must hold until the end. Any change to it means the implementor committed, which is drift.

Do not modify `plans/<slug>.md` itself; it is the source of truth.

**Resolve blockers before the first dispatch.** Read the plan for anything the implementor
cannot do headless: external accounts or app IDs it would have to create, credentials,
physical devices, recordings. Also check the phase map: if the plan has no `Phase`/`Milestone`
headings, ask the user how to split it instead of assuming. Ask all of these in one
AskUserQuestion call, then record each answer as a pre-dispatch `A<n>` in the answers file so
the implementor treats it as binding. Typical ones: which fallback path to take when an
external service is not set up, and which checks stay with the owner (device tests, demo
recording).

## Step 3: Phase loop (per phase)

For each phase, in order:

1. **Record the phase baseline.** Nothing is committed during this run, so HEAD does not move
   and cannot scope a phase. Snapshot the working tree instead:

   ```bash
   git stash create          # prints a commit SHA capturing the current tracked tree
   git status --porcelain    # record the '??' entries; the snapshot excludes untracked files
   ```

   `git stash create` writes a commit object without touching the working tree or the stash
   list, so it is safe to call mid-run. On a clean tree it prints nothing; use `git rev-parse
   HEAD` as the baseline in that case. Keep the SHA and the untracked list for this phase.
2. **Start the phase session.** Write the dispatch prompt below to `.orchestrate/<slug>/prompt.md`,
   filled in with this phase's label and milestone numbers. Run `pi-rpc.sh <slug> new
   .orchestrate/<slug>/prompt.md` in the background.
3. Read the final message it prints. Parse the trailing JSON block and branch:
   - `"status": "blocked"`: resolve the listed questions per **Step 4: Resolve implementor
     questions**, then `resume` with the reply prompt. pi continues with its context
     intact. Repeat until done.
   - `"status": "done"`: continue to the drift check below.
   - Missing or malformed JSON, or the helper exited 1: treat as blocked. Read the questions
     file. If it is empty, `resume` once asking pi to restate its status in the required
     JSON shape. If that fails too, escalate.
4. **Drift check.** Treat the implementor as a junior/mid developer; do not trust its
   self-assessment. Inspect the actual diff (`git diff`, `git status --porcelain`) against the
   phase's milestones. Re-check the reported `→ Verify:` results. Look for: scope creep,
   skipped steps, contradicted Decisions Log entries, convention violations, security issues,
   silent behavior changes. Check `git rev-parse HEAD` still equals what it was when the run
   started. If HEAD moved, the implementor committed; halt all operations immediately per
   **Step 5: Drift halt and CTO report**. If drift, halt and report the same way. If a verify
   check genuinely failed, `resume` the session asking pi to redo that milestone once; if it fails
   again, halt and report.

   The implementor's report is a claim, not evidence. Checks that caught real overclaims:
   - **Stubs.** Grep the diff for `placeholder`, `decorative`, `not a real`, `in prototype`,
     `for testing`, hardcoded sample values, and buttons that navigate instead of acting. A
     "done" core flow built from these is drift.
   - **Orphan modules.** For every core module the plan names, confirm a screen or entry point
     imports it (`grep -rn "from .*<module>"`). A tested module nothing calls means the
     feature is fake.
   - **Claimed items.** For each item in a fix list, open the file:line it cites and read it.
     Assets "copied and used" must be referenced somewhere.
   - **Build checks that prove nothing.** A bundle or export that passes can still exclude the
     app. Check the entry file actually imports the app and the module count is plausible.
     Check framework dependency alignment (for Expo: `npx expo install --check`).
   - **Plan rules.** Grep for the plan's hard rules directly (forbidden endpoints, float maths
     on money, banned words, secrets).
5. **Implementation review (per phase).** Review the phase yourself, in this session. Scope is
   this phase only: `git diff <snapshot SHA>` plus any untracked file that appeared since
   step 1.
   The snapshot is what keeps this phase's review from re-covering earlier phases still
   sitting uncommitted in the tree. Follow the implementation-review skill, split across the
   two contexts:
   - **Flaw detection, plan deviation check, and fixes stay with you.** The implementor wrote
     this code and cannot review it independently. Apply critical fixes yourself.
   - **Validate and test is delegated.** Once your fixes are in place, write the validate
     prompt to `.orchestrate/<slug>/prompt.md` and `resume` the same session. Read the results
     from its JSON block. Test output is bulky and needs no judgment, so it does not belong in
     your context.

   The validate step is read-only. Compare `git status --porcelain` before and after it; if
   the tree changed, that is drift; halt per **Step 5: Drift halt and CTO report**.

   Handle the review's two non-fixed buckets:
   - **Needs Your Input** (close tradeoffs): resolve through **Step 4: Resolve implementor
     questions**.
   - **Issues Reported (not auto-fixed)**: do not fix, do not block. Carry them to the Finish
     step so the user can opt in.

   If a check comes back `fail`, fix it yourself and `resume` with the validate prompt again.
   Do not proceed until every check passes or is legitimately skipped, and no critical issues
   remain.

   **Run it.** When the phase ships an app (mobile, web, CLI), typecheck, unit tests and a
   bundle build are not proof that it works. Launch it and drive the phase's core flow before
   you close the phase. For an Expo or React Native app, use the `run-expo-android` skill
   (Linux and macOS). For other app types, use the project's own run instructions or the `run`
   skill. Fix critical runtime bugs as part of the review. Record what was verified on the
   running app, and what could not be, in the implementation log.
6. **Do not commit and do not document.** The phase ends here, with its work in the working
   tree. Documentation and commits are the user's call, after the run.
7. Advance to the next phase. Take a fresh snapshot for it (step 1) and start a new session
   with `new`. Do not `resume` the previous phase's session.

The implementor's messages are not shown to the user. After each phase, relay one line of
progress yourself.

## Step 4: Resolve implementor questions

For each new question in `.orchestrate/<slug>/questions.md`, classify it first, then act.

**Answer it yourself** when the right answer is clear from one of these:
- the plan itself already implies it,
- the project conventions (`CLAUDE.md` / `AGENTS.md`) settle it,
- established best practice with no real tradeoff,
- an existing pattern in the codebase the implementor should follow.

Write the answer to `.orchestrate/<slug>/answers.md` with a one-line rationale. Use best judgment
and move on.

**Ask the user** when none of the above holds: a genuine product or design tradeoff, a
missing requirement, a plan ambiguity with material consequences, or two or more defensible
options where guessing risks rework. Present the question, the top options with tradeoffs,
and your recommendation. Record the user's answer in `.orchestrate/<slug>/answers.md`.

Question block (implementor appends):

```
### Q<n>: <short title>
Context: <what it was doing and why this blocks it>
Question: <one clear question>
Options considered: <options and tradeoffs, if any>
```

Answer block (you append):

```
### A<n> (Q<n>)
Answer: <the decision, stated as an instruction>
Rationale: <one line>
```

Number questions `Q1`, `Q2`, ... sequentially across the whole run. Never reuse a number.

Write the answers to the file first, then write this reply to `.orchestrate/<slug>/prompt.md` and
`resume`:

```
Answers to your questions are in `.orchestrate/<slug>/answers.md`: <A ids>. Read them, treat each
as a binding decision, and continue this phase from where you stopped. Do not redo completed
milestones. If an answer conflicts with something you found in the code, do not work around
it; raise a new question instead. End with the same JSON block contract.
```

The file write matters even though the session is live: a later phase's session starts fresh
and learns the decision only from the file.

## Step 5: Drift halt and CTO report

You are the lead. The implementor is a junior/mid developer. When you detect it doing something
wrong, stop it and report to the user (the CTO). Do not fix the mistake yourself and do not
let the implementor keep going.

**What counts as wrong (drift):**
- scope creep: touched files or milestones outside the assigned phase,
- skipped a plan step or milestone,
- contradicted a plan Decisions Log entry or an explicit plan step,
- broke the project's conventions (`CLAUDE.md` / `AGENTS.md`),
- introduced a security issue,
- faked or skipped verification: claimed a `→ Verify:` passed without running it,
- shipped a stub, placeholder, sample value or navigation-only button as a finished step,
- reported "no UI in scope" while the diff changes pages, components, templates, or styling,
- reported "no Python in scope" while the diff changes `.py` files,
- made a silent behavior change the plan does not call for,
- edited files during the read-only validate step,
- committed anything at all. Because pi has no sandbox, check HEAD and the index after every turn.

A deviation that is clearly better and stays within the plan's goal is not drift. Note it,
continue, and surface it in the final summary so the CTO knows the plan may need updating.

When you halt, run `pi-rpc.sh <slug> stop` if a turn is still running, present this report
to the user, and wait. Take no further action until the CTO decides.

```
## CTO report

**Incident**: <phase label>, <milestone(s)>
**What the implementor did wrong**: <concrete, with file:line or diff evidence>
**Why it is wrong**: <against plan step X, scope, convention, or security>
**Reported vs actual**: <what the implementor claimed vs what you verified>
**Impact**: <what breaks or what rework is at risk>
**Options**:
1. <option A>, <tradeoff>
2. <option B>, <tradeoff>
**My recommendation**: <which option, one line why>
```

Record the report and the CTO's eventual decision in `.orchestrate/<slug>/implementation-log.md`.

## Dispatch prompt

Write this to `.orchestrate/<slug>/prompt.md` for `new` on each phase, filling in the
placeholders:

````markdown
You are the implementor for phase <label> of an approved implementation plan.
The orchestrator directs you from the main session and reviews your work.

Your job in this phase: implement milestones <comma-separated list of milestone numbers> only.
Do not touch other milestones.

Plan: plans/<slug>.md
Implementation log: .orchestrate/<slug>/implementation-log.md
Questions: .orchestrate/<slug>/questions.md
Answers: .orchestrate/<slug>/answers.md

## How to work
1. Work in the current directory. Follow the project's CLAUDE.md or AGENTS.md conventions.
2. Read the implementation log and answers file before writing code. Prior phases may have
   made decisions that affect this one. Treat answers as binding instructions.
3. Implement only the milestones listed above, in order.
4. Run every `→ Verify:` check listed for your milestones. Do not proceed past a milestone
   whose verify check fails. Never report a check as passing unless you ran it and read the output.
5. If you hit a blocking ambiguity that the plan and answers file do not resolve, STOP. Append
   the question to `.orchestrate/<slug>/questions.md` using the format below and end your turn
   with the blocked JSON block.
6. pi has no sandbox. Never run `git commit`, `git add`, `git push`, or modify Git config or
   remotes. Never stage or commit changes. Leave all work in the working tree.
7. Never edit `plans/<slug>.md`. It belongs to the orchestrator.
8. If you observe a context-pressure or compaction warning, save a checkpoint in the
   implementation log, append a question to the questions file, and end with blocked status.
   Let the orchestrator decide whether to continue or request manual compaction. Report token
   counters only when available from actual runtime telemetry; otherwise state that they are
   unavailable. Do not estimate them.

## Frontend
Decide this yourself from the milestones in scope; do not wait to be told.
If this phase adds or changes any page, component, template, or styling, apply the
frontend-design skill. If the project uses Bootstrap 5, also apply frontend-bootstrap-evolution.
Name the skills applied in your phase report. If no UI in scope, state "no UI in scope".

## Python
Decide this yourself from the milestones in scope; do not wait to be told.
If this phase writes or edits any Python, apply python-development. Name it in your report.
If no Python in scope, state "no Python in scope".

## When the phase is complete
1. Append a report to `.orchestrate/<slug>/implementation-log.md` using the report format below.
2. End your final message with the done JSON block.

## Question format (append to `.orchestrate/<slug>/questions.md`)
### Q<n>: <short title>
Context: <what you were doing and why this blocks you>
Question: <one clear question>
Options considered: <options and tradeoffs, if any>

## Report format (append to `.orchestrate/<slug>/implementation-log.md`)
## Phase <label>: <name> (done)
- Milestones completed: <list>
- Files touched: <list>
- Verify results: <pass/fail per check>
- Frontend skills applied: <"no UI in scope", or skills applied>
- Python skill applied: <"no Python in scope", or python-development>
- Deviations from plan: <none, or list>
- Questions raised: <none, or list of Q ids>

## Ending JSON block
Every turn in this session ends with exactly one fenced JSON block as the last thing in your
final message:

```json
{ "status": "done", "phase": "<label>", "summary": "<one paragraph>" }
```

or

```json
{ "status": "blocked", "phase": "<label>", "questions": ["Q<n>", ...] }
```
````

## Validate prompt

Write this to `.orchestrate/<slug>/prompt.md` during step 5 and `resume` the phase session:

````markdown
Implementation for this phase is done and I have reviewed it and applied fixes. Your job now
is to run checks and report results. Nothing else.

Do not edit any files. Do not fix failures. Do not stage or commit. Run checks and report.

## What to run
1. Discover the project's real commands by reading `package.json`, `Makefile`, `pyproject.toml`,
   or the equivalent.
2. Run the test suite. If the project has none, say so.
3. Run the lint and build/typecheck steps if they exist.
4. Run every `→ Verify:` check listed in `plans/<slug>.md` for milestones <comma list>.

## How to report
One line per command. Quote only the decisive failing line for anything that fails, never the
full log.

End your final message with exactly one fenced JSON block:

```json
{ "status": "done", "phase": "<label>", "checks": [{ "cmd": "<command>", "result": "pass|fail|skipped", "detail": "<one line, empty when pass>" }] }
```

Use `"skipped"` when the project has no such check. Report `"status": "done"` even when checks
fail; the failures belong in the `checks` array. Use `"status": "blocked"` only if you cannot
run the checks at all.
````

## Helper script

`pi-rpc.sh` ships next to this skill:

```bash
bash pi-rpc.sh <slug> new <prompt-file>      # fresh session, send prompt, wait for settled
bash pi-rpc.sh <slug> resume <prompt-file>   # next prompt on current session
bash pi-rpc.sh <slug> compact ["<instr>"]    # compact the session, optional instructions
bash pi-rpc.sh <slug> send '<json>'          # raw RPC command
bash pi-rpc.sh <slug> session                # print the current session id
bash pi-rpc.sh <slug> status                 # running / not running
bash pi-rpc.sh <slug> stop                   # terminate and clean state
```

State lives under `${TMPDIR:-/tmp}/pi-orch-<slug>/`. The event stream is in `events.jsonl` there.

## When the pi implementor itself is the problem

A failed turn is not automatically implementor drift. Separate the two before acting.
**Implementor drift** (wrong code, scope creep, a fabricated verify, a commit) is Step 5. A
**pi problem** (the CLI, the RPC session, `pi-rpc.sh`, credentials, model selection) needs
diagnosis, not another dispatch.

State for the run lives in `${TMPDIR:-/tmp}/pi-orch-<slug>/`: `events.jsonl` (the full event
stream), `err.log` (pi's stderr), and `cmds.log`. Read `events.jsonl` or use `send`:

```bash
bash pi-rpc.sh <slug> send '{"type":"get_state"}'            # model, isStreaming, messageCount
bash pi-rpc.sh <slug> send '{"type":"get_session_stats"}'    # tokens, cost, contextUsage
tail -n 20 ${TMPDIR:-/tmp}/pi-orch-<slug>/events.jsonl
```

| Symptom | Likely cause | What to check |
|---|---|---|
| `no events for ~600s` | the turn stalled | `get_state` for `isStreaming`, then `tail events.jsonl`, then `send '{"type":"abort"}'` |
| `session ... died` | pi exited | `tail err.log`; look for `extension_error`, `auto_retry_end` with `finalError` |
| the implementor forgets the phase brief | context pressure | `get_session_stats` `contextUsage`; compact with custom instructions |
| events keep flowing after `agent_end` | automatic retry or compaction retry | `auto_retry_start`, `compaction_start`, `summarization_retry_scheduled`, then `abort_retry` |

The pi docs ship with the installed CLI and match its version. Resolve them from the binary:

```bash
PI_PKG=$(cd "$(dirname "$(readlink -f "$(command -v pi)")")/../.." && pwd)
ls "$PI_PKG/docs"
```

Start with `docs/rpc.md` for commands, events, and error shapes, then `docs/compaction.md`
for compaction behavior and `docs/sessions.md` for session layout. `docs/security.md`
covers project trust and the fact that pi has no built-in sandbox. Upstream source and
issues: https://github.com/earendil-works/pi

Fixing it: a `pi-rpc.sh` bug is fixed in this repo with the `fix-bug` skill. A pi bug is
reproduced with the smallest failing prompt, captured with `events.jsonl`, `err.log`, and
`pi --version`, then reported upstream. Do not patch the installed package to unblock a run.

## Rules

- You do not implement the plan's milestones yourself; you delegate them to the implementor. You do run the per-phase implementation review and fix critical issues it finds.
- Review judgment stays with you. Only the mechanical validate-and-test pass is delegated, and that pass is read-only: it reports results and never fixes what it finds.
- Treat the implementor as a junior/mid developer. Verify its work after each phase; never trust its self-assessment.
- On drift (the implementor did something wrong), halt and report to the CTO. Do not fix it yourself and do not continue until the CTO decides.
- Never advance past a blocked phase, a failed verify check, a malformed report, or detected drift.
- Do not guess the answer to a question that is a genuine judgment call. That is the one thing you escalate.
- Do not let the implementor silently resolve a plan-vs-codebase conflict; route it through the questions file.
- Answer the easy questions yourself. Asking the user about things you can decide wastes their time.
- This skill stops at review. It never commits and never writes documentation. pi runs with no built-in sandbox, so the prompt strictly forbids staging and commits, and review checks HEAD and the index. If anything commits, halt all operations immediately. Do not retry, do not fix, do not continue. Report to the CTO.
- Keep the handoff files append-only. Never rewrite or renumber past entries.
- The plan file is the source of truth. The implementor never edits it; only you may append to its Decisions Log.
- The dispatch prompt's Frontend and Python sections go in every phase, unedited. The implementor decides whether the phase touches UI or Python and self-negates when it does not.
- Check the report's "Frontend skills applied" and "Python skill applied" lines against the diff during the drift check. A phase that changed templates or `.py` files but reports "no UI in scope" or "no Python in scope" is a false report, not a judgment call.
- Report progress to the user in one line per phase. Reserve detail for the final summary.
