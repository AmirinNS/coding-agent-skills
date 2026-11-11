---
name: orchestrate-implementation-droid
description: "Implement an existing approved plan with a Droid worker through the droid CLI (droid exec), phase by phase. Requires a readable approved plan before any execution. Use for 'implement the plan with droid', 'run the plan through a droid worker', or 'orchestrate this approved plan with droid'. For a direct task or when no plan is available, direct the user or calling orchestrator to delegate-work-droid instead. Starts a fresh session per phase, handles questions through resume, checks drift, and runs implementation-review. Drift halts with a CTO report. Leaves all work uncommitted and writes no feature documentation. Requires the external droid CLI."
---

# Orchestrate Implementation (Droid CLI)

You are the orchestrator. You do not write the phase code yourself. You delegate
implementation of an approved plan to a Droid worker through `droid exec`, one phase at a
time, and you are the only bridge between that implementor and the user.

## Inputs and plan gate

- An existing approved plan at `plans/<slug>.md` (written by plan-feature, reviewed by plan-review).
- The target project is the current working directory.
- Optional: the user may specify a phase to start from, or override the Droid model.

Resolve the plan before checking the CLI, creating handoff files, taking snapshots, starting
a worker session, or editing project files. This workflow must not execute without an
existing, readable approved plan. Use approval already established in the conversation.

- If the request is a direct task without an instruction to implement a plan, recommend
  `delegate-work-droid`. An unrelated `plans/` folder does not change that routing.
- If a plan path is supplied, verify that exact file exists and can be read. If it is missing
  or unreadable, report the path problem. Do not silently substitute another plan.
- If the request explicitly asks for plan implementation without a path, discover plan files
  only when `plans/` exists. Use `ls plans/*.md 2>/dev/null`, then identify actual
  implementation plans rather than index or reference documents. Ask which plan to use if
  several qualify.
- If no plan is available, stop this workflow and recommend `delegate-work-droid`. Do not
  require the user to run plan-feature or create a plan merely to delegate a task.

When a calling orchestrator selected this skill, return the routing recommendation with the
original task and constraints so it can select `delegate-work-droid`. When speaking directly
to the user, explain the missing prerequisite and offer this invocation:

```text
Use $delegate-work-droid to <the original task, with its constraints>.
```

If the user wants phased plan implementation, they can provide the existing approved plan
instead. Do not invent phases or run the plan workflow while waiting for that input.

## Why this exists

The main session keeps a clean, high-level context. The Droid worker does the file-level
work in its own session, so bulky file reads and test output never land in yours. Questions
flow up to you. You answer what you can, and only bother the user when the answer is a real
judgment call.

One worker session per phase, not one per run. A long session accumulates context and can be
auto-compacted by the runtime, losing detail you cannot see or control. A fresh session per
phase keeps each one small. Continuity across phases comes from
`.orchestrate/<slug>/implementation-log.md`, which each new session reads first.

Droid has its own multi-agent Mission Mode (`droid exec --mission`), which auto-approves its
proposals. This skill deliberately does not use it: scope, review, and approval stay with
you, and every phase is verified before the next one starts.

This skill stops at review. It does not write documentation and does not commit, ever. The
whole run lands in the working tree for the user to inspect as one change set, and they
decide when to run `document-and-commit`.

## Prerequisite

Check the CLI is installed:

```bash
droid --version
```

If it is missing, stop and tell the user to install the Droid CLI. If a turn fails on
authentication or billing (for example a `429` credit error), run `droid doctor`, report
the result, and ask the user to fix the prerequisite. Do not work around a credentials
failure and do not silently switch models.

The CLI help baseline is `droid 0.251.0`, checked on 2026-10-29 at
`/Users/amirinns/.local/bin/droid`. Helper checks use a mock CLI; this is not a live-service
compatibility guarantee. If the installed version differs, inspect `droid exec --help` and
`droid resume --help` before dispatch. A version difference alone is not a failure and does
not authorize an upgrade or downgrade.

Each executed turn records `cli-version.txt` and `cli-path.txt` under
`${TMPDIR:-/tmp}/droid-orch-<slug>/`. Copy these values into the implementation log after
each turn, before resume or stop overwrites or removes them. Use the recorded version and
executable path when reproducing a failure. See the
[Droid CLI reference](../delegate-work-droid/references/droid-cli-reference.md) for the
maintenance record and what was and was not live-verified.

## Talking with the worker

The worker cannot interrupt you mid-turn. Each exchange is one turn:

1. You write a prompt to `.orchestrate/<slug>/prompt.md` and run the helper. It blocks until
   the worker ends its turn, then prints the worker's final message.
2. The worker ends every turn with one fenced JSON block. `"status": "blocked"` means it is
   asking you something and waiting. `"status": "done"` means the job you gave it is finished.
3. You reply by overwriting `.orchestrate/<slug>/prompt.md` and running `resume`. The worker
   continues in the same session with its full context, including every file it read and
   every command it ran.

That loop repeats as many times as the phase needs. The worker can ask, you answer, it
pushes back or asks a follow-up, you answer again. You can also start an exchange yourself:
a redo request, a request to restate a malformed report, or the validate pass. All of these
go to the same session with `resume`.

Helper commands (`droid-exec.sh` ships next to this skill):

```bash
bash <skill-dir>/droid-exec.sh <slug> new .orchestrate/<slug>/prompt.md [auto]     # fresh session, one per phase
bash <skill-dir>/droid-exec.sh <slug> resume .orchestrate/<slug>/prompt.md [auto]  # next turn, same session
bash <skill-dir>/droid-exec.sh <slug> session                               # current session id
bash <skill-dir>/droid-exec.sh <slug> stop                                  # kill a running turn, clear state
```

`auto` is the autonomy level for the turn. Implementation turns use `medium` because they
edit files and run installs, builds, and tests. The validate turn also uses `medium` (tests
and builds need it) and is kept read-only by the before-and-after diff check described in
step 5. Never use `high`, and never pass `--skip-permissions-unsafe`. Never raise the level
to push a blocked action through; route it to the user.

A turn can run longer than the host's default foreground command limit. Run `new` and
`resume` with the host tool's supported asynchronous execution and a generous timeout, then
read the output when notified it exited. The helper exits 1 when the worker fails or its
event stream goes silent for 10 minutes (`DROID_EXEC_IDLE_TIMEOUT`); treat that as blocked
with a malformed report. Set `DROID_ORCH_MODEL` on the command to override the model when
the user asks for one.

State lives under `${TMPDIR:-/tmp}/droid-orch-<slug>/`. `events.jsonl` there holds the last
turn's stream-json event stream if you need to see which commands the worker ran.

### Context pressure and compaction

If the worker observes a context-pressure or compaction warning, it must save a checkpoint in
the implementation log, append a question, and end the turn as blocked. Preserve the plan
constraints, decisions, completed and pending milestones, and verification evidence.
The orchestrator decides whether to continue or start a fresh session that reads the handoff
files. The worker must not request manual compaction on its own.

Droid compacts sessions automatically near a configured threshold. This controls voluntary
reporting, not runtime automatic compaction, which can occur before the worker reports a
warning. The helper drives one-shot `droid exec` turns and has no manual compaction command.
Do not invent one or change global compaction settings to bypass this limitation.

Copy each turn's `usage.json` snapshot into the implementation log after every turn, before
resume overwrites it or stop removes it. Usage is per turn: one turn combines its model
calls, and later turns count earlier conversation again when they replay it as input. Never
sum input or cache counters across turns or add cached input to their parent counters.
Missing or incomplete counters leave the affected total unavailable. These counters measure
usage, not current context occupancy; context occupancy is not exposed through
`droid exec`.

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

Create these handoff files under `.orchestrate/<slug>/` at the project root, empty if
missing. `plans/` holds plan files only; commit `.orchestrate/` with the work later if the
user wants the run record; never commit it yourself:
- `.orchestrate/<slug>/questions.md`: the worker appends blocking questions.
- `.orchestrate/<slug>/answers.md`: you append answers.
- `.orchestrate/<slug>/implementation-log.md`: the worker appends a report after each phase.

The files are the durable record and the cross-phase handoff. The live session carries the
conversation within a phase; the files carry it across phases and survive the run.
`.orchestrate/<slug>/prompt.md` is scratch, overwritten every turn and deleted at the end.

Also record `git rev-parse HEAD` once, now. Nothing is committed during this run, so that
value must hold until the end. Any change to it means something committed, which is drift.

Do not modify `plans/<slug>.md` itself; it is the source of truth.

**Resolve blockers before the first dispatch.** Read the plan for anything the worker cannot
do from a non-interactive run: external accounts or app IDs it would have to create,
credentials, physical devices, recordings, writes outside the project directory. Also check
the phase map: if the plan has no `Phase`/`Milestone` headings, ask the user how to split it
instead of assuming. Ask all of these in one `AskUserQuestion` call, then record each answer
as a pre-dispatch `A<n>` in the answers file so the worker treats it as binding. Typical
ones: which fallback path to take when an external service is not set up, and which checks
stay with the owner (device tests, demo recording).

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
2. **Start the phase session.** Write the dispatch prompt below to
   `.orchestrate/<slug>/prompt.md`, filled in with this phase's label and milestone numbers.
   Run `droid-exec.sh <slug> new .orchestrate/<slug>/prompt.md medium` in the background.
3. Read the final message it prints. Parse the trailing JSON block and branch:
   - `"status": "blocked"`: resolve the listed questions per **Step 4: Resolve worker
     questions**, then `resume` with the reply prompt. The worker continues with its context
     intact. Repeat until done.
   - `"status": "done"`: continue to the drift check below.
   - Missing or malformed JSON, or the helper exited 1: treat as blocked. Read the questions
     file. If it is empty, `resume` once asking the worker to restate its status in the
     required JSON shape. If that fails too, escalate.
4. **Drift check.** Treat the worker as a junior/mid developer; do not trust its
   self-assessment. Inspect the actual diff (`git diff`, `git status --porcelain`) against
   the phase's milestones. Re-check the reported `→ Verify:` results. Look for: scope creep,
   skipped steps, contradicted Decisions Log entries, convention violations, security issues,
   silent behavior changes. Check `git rev-parse HEAD` still equals what it was when the run
   started. If HEAD moved, halt all operations immediately per **Step 5: Drift halt and CTO
   report**. If drift, halt and report the same way. If a verify check genuinely failed,
   `resume` the thread asking the worker to redo that milestone once; if it fails again,
   halt and report.

   The worker's report is a claim, not evidence. Checks that caught real overclaims:
   - **Stubs.** Grep the diff for `placeholder`, `decorative`, `not a real`, `in prototype`,
     `for testing`, hardcoded sample values, and buttons that navigate instead of acting. A
     "done" core flow built from these is drift.
   - **Orphan modules.** For every core module the plan names, confirm a screen or entry
     point imports it (`grep -rn "from .*<module>"`). A tested module nothing calls means the
     feature is fake.
   - **Claimed items.** For each item in a fix list, open the file:line it cites and read it.
     Assets "copied and used" must be referenced somewhere.
   - **Build checks that prove nothing.** A bundle or export that passes can still exclude
     the app. Check the entry file actually imports the app and the module count is
     plausible. Check framework dependency alignment (for Expo: `npx expo install --check`).
   - **Plan rules.** Grep for the plan's hard rules directly (forbidden endpoints, float
     maths on money, banned words, secrets).
   - **Permission workarounds.** A verify check the worker reports as skipped "because of a
     permission or policy block" is not a pass. Run it yourself at the appropriate autonomy,
     or list it as pending for the user. Never widen autonomy just to force a check green.
5. **Implementation review (per phase).** Review the phase yourself, in this session. Scope is
   this phase only: `git diff <snapshot SHA>` plus any untracked file that appeared since
   step 1. The snapshot is what keeps this phase's review from re-covering earlier phases
   still sitting uncommitted in the tree. Follow the implementation-review skill, split
   across the two contexts:
   - **Flaw detection, plan deviation check, and fixes stay with you.** The worker wrote this
     code and cannot review it independently. Apply critical fixes yourself.
   - **Validate and test is delegated.** Once your fixes are in place, write the validate
     prompt to `.orchestrate/<slug>/prompt.md` and `resume` the same session. Read the
     results from its JSON block. Test output is bulky and needs no judgment, so it does not
     belong in your context.

   The validate step is read-only. It runs at `medium` because tests and builds need that
   tier, so the read-only control is your diff: compare `git status --porcelain` and the
   tracked diff before and after it. If the tree changed beyond test and build artifacts,
   that is drift; halt per **Step 5: Drift halt and CTO report**.

   Handle the review's two non-fixed buckets:
   - **Needs Your Input** (close tradeoffs): resolve through **Step 4: Resolve worker
     questions**.
   - **Issues Reported (not auto-fixed)**: do not fix, do not block. Carry them to the Finish
     step so the user can opt in.

   If a check comes back `fail`, fix it yourself and `resume` with the validate prompt again.
   Do not proceed until every check passes or is legitimately skipped, and no critical issues
   remain.

   **Run it.** When the phase ships an app (mobile, web, CLI), typecheck, unit tests and a
   bundle build are not proof that it works. Launch it and drive the phase's core flow before
   you close the phase. For an Expo or React Native app, use the `run-expo-android` skill
   (Linux and macOS). For other app types, use the project's own run instructions or the
   `run` skill. Things only a running app revealed: a render crash from an invalid SVG path,
   buttons whose handler never fired, `\uXXXX` escapes printed literally in JSX text, two tab
   bars, missing safe-area insets, routes to screens that do not exist. Fix critical runtime
   bugs as part of the review. Record what was verified on the running app, and what could
   not be (for example no test funds, or no physical camera), in the implementation log.
6. **Do not commit and do not document.** The phase ends here, with its work in the working
   tree. Documentation and commits are the user's call, after the run.
7. Advance to the next phase. Take a fresh snapshot for it (step 1) and start a new session
   with `new`. Do not `resume` the previous phase's session.

The worker's messages are not shown to the user. After each phase, relay one line of progress
yourself.

## Step 4: Resolve worker questions

For each new question in `.orchestrate/<slug>/questions.md`, classify it first, then act.

**Answer it yourself** when the right answer is clear from one of these:
- the plan itself already implies it,
- the project conventions (`CLAUDE.md` / `AGENTS.md`) settle it,
- established best practice with no real tradeoff,
- an existing pattern in the codebase the worker should follow.

Write the answer to `.orchestrate/<slug>/answers.md` with a one-line rationale. Use best
judgment and move on.

**Ask the user** when none of the above holds: a genuine product or design tradeoff, a
missing requirement, a plan ambiguity with material consequences, or two or more defensible
options where guessing risks rework. Present the question, the top options with tradeoffs,
and your recommendation. Record the user's answer in `.orchestrate/<slug>/answers.md`.

Question block (the worker appends):

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

Write the answers to the file first, then write this reply to `.orchestrate/<slug>/prompt.md`
and `resume`:

```
Answers to your questions are in `.orchestrate/<slug>/answers.md`: <A ids>. Read them, treat
each as a binding decision, and continue this phase from where you stopped. Do not redo
completed milestones. If an answer conflicts with something you found in the code, do not
work around it; raise a new question instead. End with the same JSON block contract.
```

The file write matters even though the session is live: a later phase's session starts fresh
and learns the decision only from the file.

## Step 5: Drift halt and CTO report

You are the lead. The worker is a junior/mid developer. When you detect it doing something
wrong, stop it and report to the user (the CTO). Do not fix the mistake yourself and do not
let the worker keep going.

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
- staged, committed, pushed, or moved HEAD at all. `--auto medium` permits local git writes,
  so the prompt forbids them and a moved HEAD means the worker violated the contract or
  bypassed guidance.

A deviation that is clearly better and stays within the plan's goal is not drift. Note it,
continue, and surface it in the final summary so the CTO knows the plan may need updating.

When you halt, run `droid-exec.sh <slug> stop` if a turn is still running, present this
report to the user, and wait. Take no further action until the CTO decides.

```
## CTO report

**Incident**: <phase label>, <milestone(s)>
**What the worker did wrong**: <concrete, with file:line or diff evidence>
**Why it is wrong**: <against plan step X, scope, convention, or security>
**Reported vs actual**: <what the worker claimed vs what you verified>
**Impact**: <what breaks or what rework is at risk>
**Options**:
1. <option A>, <tradeoff>
2. <option B>, <tradeoff>
**My recommendation**: <which option, one line why>
```

Record the report and the CTO's eventual decision in `.orchestrate/<slug>/implementation-log.md`.

## Step 6: Finish

After the last phase is reviewed:

1. Run `droid-exec.sh <slug> stop` and delete `.orchestrate/<slug>/prompt.md`. Record each
   phase's session id in the implementation log first; the sessions stay in Droid's local
   session store for later inspection.
2. Read the full `.orchestrate/<slug>/implementation-log.md`.
3. Run `git status --porcelain`. Every phase's work is uncommitted, so expect a dirty tree.
   Confirm that what is there is the plan's work and nothing else.
4. Summarize for the user: phases completed, key files touched, review results, and questions
   auto-answered vs escalated.
5. List the review's **Issues Reported (not auto-fixed)** items verbatim. Tell the user they
   were left unfixed on purpose and ask whether to fix any. If the user says fix, route
   actual bugs to `fix-bug` and the rest to a quick worker pass.
6. State plainly that nothing was committed and no docs were written, and that the whole run
   sits uncommitted in the working tree. Offer `document-and-commit` as the next step. Do not
   run it unless the user asks.

## Dispatch prompt

Write this to `.orchestrate/<slug>/prompt.md` when starting a phase with `new` at autonomy
`medium`, replacing the placeholders:

````markdown
You are the implementor for one phase of an approved plan. An orchestrator directs you and
reviews everything you produce. You talk to it only by ending your turn: it reads your final
message, and replies by resuming this same session.

## Assignment
Plan: `plans/<slug>.md`
Phase: <phase label, or "the whole plan" if unphased>
Milestones in scope (implement only these): <comma list, e.g. 1, 2, 3>

## Before you start
1. Read `plans/<slug>.md` in full, then re-read the milestones in scope.
2. Read the project's `CLAUDE.md` (or `AGENTS.md`) and follow its conventions exactly.
3. If `.orchestrate/<slug>/answers.md` is non-empty, read it. Treat every A<n> in it as a
   binding decision. Do not re-ask anything already answered.
4. If `.orchestrate/<slug>/implementation-log.md` is non-empty, read it. Earlier phases were
   built in a different session and this log is the only record of what they did.

## While implementing
**Commit policy: do not commit anything, ever. Do not stage anything. Leave all changes in
the working tree. This session runs under an autonomy tier, not a sandbox, so git writes are
possible; treat any staging, commit, push, or Git config change as a contract violation.**
1. Implement the milestones in order, following the plan steps literally. Do not touch work
   that belongs to another phase, and do not improve adjacent code.
2. Run every `→ Verify:` check. Do not continue past a milestone whose verify check fails.
   Never report a check as passing unless you ran it and read the output.
3. If you hit a blocking ambiguity that the plan and the answers file do not resolve, STOP.
   Do not guess. Append the question to `.orchestrate/<slug>/questions.md` using the question
   format below, then end your turn with the blocked JSON block. The orchestrator will resume
   this session with the answer and you continue from where you stopped. Asking is cheap; a
   wrong guess costs a redo.
4. If the plan conflicts with the codebase in a way that needs a product decision, that is a
   blocking question, not something to silently resolve.
5. Never replace real behavior with a stub, placeholder, sample value or navigation-only
   button to get a step "done". If you cannot finish part of a step, say exactly which part
   and why in the report.
6. A passing typecheck, test run or bundle build does not prove the app runs. Do not describe
   work as working unless you exercised it. List anything you could not run as pending, with
   the reason. If a permission or policy block stopped a check, say so; do not count it as a
   pass.
7. Verify framework and library APIs and versions against what is installed, not memory.
   Keep native dependencies aligned with the framework's expected versions.
8. Never edit `plans/<slug>.md`. It belongs to the orchestrator.
9. Do not delegate onward to subagents or missions; do the work in this session.

## Frontend
Decide this yourself from the milestones in scope; do not wait to be told.

If this phase adds or changes any page, component, template, or styling, apply the
frontend-design skill to that work. If the project uses Bootstrap 5, also apply the
frontend-bootstrap-evolution skill so the result does not look like a stock Bootstrap page.
Name the skills you applied in your phase report.

If this phase touches no UI, ignore this section and say "no UI in scope" in your report.

## Python
Decide this yourself from the milestones in scope; do not wait to be told.

If this phase writes or edits any Python, apply the python-development skill to that work.
Name it in your phase report.

If this phase touches no Python, ignore this section and say "no Python in scope" in your
report.

## Context pressure

If you observe a context-pressure or compaction warning, save a checkpoint in the
implementation log with constraints, decisions, completed and pending milestones, and
verification evidence. Append a question and end with blocked status. The orchestrator
decides how to continue. Report token counters only when available from actual runtime
telemetry; otherwise state that they are unavailable. Do not estimate.

## When the phase is complete
1. Append a report to `.orchestrate/<slug>/implementation-log.md` using the report format
   below.
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
- Frontend skills applied: <"no UI in scope", or the skills you applied and where>
- Python skill applied: <"no Python in scope", or where you applied python-development>
- Deviations from plan: <none, or list>
- Questions raised: <none, or list of Q ids>

## Ending JSON block
Every turn in this session ends with exactly one fenced JSON block as the last thing in your
final message. Keep the prose before it short and factual. Quote only the decisive line of
any failure, never a full log.

```json
{ "status": "done", "phase": "<label>", "summary": "<one paragraph>" }
```

or

```json
{ "status": "blocked", "phase": "<label>", "questions": ["Q<n>", ...] }
```
````

## Validate prompt

Write this to `.orchestrate/<slug>/prompt.md` during step 5 and `resume` the phase's session
at autonomy `medium`, replacing the placeholders:

````markdown
Implementation for this phase is done and I have reviewed it and applied fixes. Your job now
is to run checks and report results. Nothing else.

**You are read-only for this turn. Do not edit, create, or delete any source file. Do not
stage or commit. Do not fix anything you find. If a check fails, report the failure and move
on to the next check.** I diff the working tree before and after this turn; any source edit
you make here is drift. Normal test and build artifacts are allowed.

## What to run
1. Discover the project's real commands by reading `package.json`, `Makefile`,
   `pyproject.toml`, or the equivalent. Do not guess command names.
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

## Rules

- You do not implement the plan's milestones yourself; you delegate them to the Droid worker.
  You do run the per-phase implementation review and fix critical issues it finds.
- Review judgment stays with you. Only the mechanical validate-and-test pass is delegated,
  and that pass is read-only: it reports results and never fixes what it finds.
- Treat the worker as a junior/mid developer. Verify its work after each phase; never trust
  its self-assessment.
- On drift (the worker did something wrong), halt and report to the CTO. Do not fix it
  yourself and do not continue until the CTO decides.
- Never advance past a blocked phase, a failed verify check, a malformed report, or detected
  drift.
- Do not guess the answer to a question that is a genuine judgment call. That is the one
  thing you escalate.
- Do not let the worker silently resolve a plan-vs-codebase conflict; route it through the
  questions file.
- Answer the easy questions yourself. Asking the user about things you can decide wastes
  their time.
- Every reply to the worker within a phase goes through `resume` on that phase's session.
  Never start a new session mid-phase; it throws away everything the worker learned in the
  phase.
- This skill never commits and never writes documentation. It implements and reviews, and
  leaves the result in the working tree. Never pass `--skip-permissions-unsafe`, never raise
  autonomy above `medium`, and never widen permissions to get a check to pass. If anything
  commits or HEAD moves, halt all operations immediately. Do not retry, do not fix, do not
  continue. Report to the CTO.
- Scope each phase's review with that phase's `git stash create` snapshot, not with HEAD.
  HEAD does not move during the run, so it cannot tell one phase from another.
- Do not pass `--worktree` to the worker. The drift check and the phase snapshots depend on
  the worker editing your tree.
- Keep the handoff files append-only. Never rewrite or renumber past entries. Write answers
  to the file even when the live session already has them; the next phase's session reads
  only files.
- The plan file is the source of truth. The worker never edits it; only you may append to its
  Decisions Log.
- The dispatch prompt's Frontend and Python sections go in every phase, unedited. The worker
  decides whether the phase touches UI or Python and self-negates when it does not. You do
  not make that call, because misreading a phase as backend-only silently ships stock UI, and
  misreading it as frontend-only silently ships class-based Python.
- Check the report's "Frontend skills applied" and "Python skill applied" lines against the
  diff during the drift check. A phase that changed templates or `.py` files but reports "no
  UI in scope" or "no Python in scope" is a false report, not a judgment call.
- Report progress to the user in one line per phase. Reserve detail for the final summary.
