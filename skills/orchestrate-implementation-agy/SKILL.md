---
name: orchestrate-implementation-agy
description: "Delegate implementation of an approved plan to the Antigravity CLI (agy), phase by phase. Per phase: start a fresh agy conversation, drift-check, run implementation-review. agy talks back and forth with the orchestrator by ending each turn with a JSON status, and the orchestrator replies by resuming the same conversation. Drift halts with a CTO report. Never commits and never writes docs; the whole run is left uncommitted for the user to review, then document-and-commit themselves. Requires the agy CLI. Triggers: 'orchestrate with agy', 'orchestrate with antigravity', 'implement the plan with agy', 'implement the plan with antigravity', 'run the plan through agy', 'delegate the implementation to agy', 'agy orchestrator', 'antigravity orchestrator'. For the Claude subagent equivalent, use orchestrate-implementation-claude; for Codex, use orchestrate-implementation-codex; for pi, use orchestrate-implementation."
---

# Orchestrate implementation (Antigravity CLI)

You are the orchestrator. You do not write the phase code yourself. You delegate
implementation of an approved plan to Antigravity through `agy`, one phase at a time, and you
are the only bridge between that implementor and the user.

## Inputs and plan gate

- An existing approved plan at `plans/<slug>.md` (written by plan-feature, reviewed by plan-review).
- The target project is the current working directory.
- Optional: the user may specify a phase to start from, or override the agy model.

Resolve the plan before checking the CLI, creating handoff files, taking snapshots, starting
an agy conversation, or editing project files. This workflow must not execute without an existing,
readable approved plan. Use approval already established in the conversation.

- If the request is a direct task without an instruction to implement a plan, recommend
  `delegate-work-agy`. An unrelated `plans/` folder does not change that routing.
- If a plan path is supplied, verify that exact file exists and can be read. If it is missing
  or unreadable, report the path problem. Do not silently substitute another plan.
- If the request explicitly asks for plan implementation without a path, discover plan files
  only when `plans/` exists. Use `ls plans/*.md 2>/dev/null`, then identify actual implementation
  plans rather than index or reference documents. Ask which plan to use if several qualify.
- If no plan is available, stop this workflow and recommend `delegate-work-agy`. Do not
  require the user to run plan-feature or create a plan merely to delegate a task.

When a calling orchestrator selected this skill, return the routing recommendation with the
original task and constraints so it can select `delegate-work-agy`. When speaking directly
to the user, explain the missing prerequisite and offer this invocation:

```text
Use $delegate-work-agy to <the original task, with its constraints>.
```

If the user wants phased plan implementation, they can provide the existing approved plan
instead. Do not invent phases or run the plan workflow while waiting for that input.

## Why this exists

The main session keeps a clean, high-level context. Antigravity does the file-level work in its
own conversation, so bulky file reads and test output never land in yours. Questions flow up to
you. You answer what you can, and only bother the user when the answer is a real judgment call.

One agy conversation per phase, not one per run. A single conversation carried across every
phase would accumulate context with no recovery path. A fresh conversation per phase resets the
context window and serves as the phase boundary. Continuity across phases comes from
`.orchestrate/<slug>/implementation-log.md`, which each new conversation reads first.

This skill stops at review. It does not write documentation and does not commit, ever. The
whole run lands in the working tree for the user to inspect as one change set, and they decide
when to run `document-and-commit`.

## Prerequisite

Check that the CLI is installed:

```bash
agy --version
```

If it is missing, stop and tell the user to install Antigravity CLI.

The CLI help baseline is `1.3.3`, checked on 2026-10-11. Helper checks use a mock CLI; this
is not a live-service compatibility guarantee. If the installed version differs, inspect
`agy --help` before dispatch. A version difference alone is not a failure and does not
authorize an upgrade or downgrade. Each executed turn records `cli-version.txt` and
`cli-path.txt` in helper state under `${TMPDIR:-/tmp}/agy-orch-<slug>/`. Copy these values
into `.orchestrate/<slug>/implementation-log.md` after each turn, before resume or stop
overwrites or removes them. Use the recorded version and executable path when reproducing
a failure.

## Talking with agy

agy runs each exchange as a turn:

1. You write a prompt to `.orchestrate/<slug>/prompt.md` and run the helper. It waits until agy
   ends its turn, then prints agy's final response text.
2. agy ends every turn with one fenced JSON block. `"status": "blocked"` means it asks a
   question and waits for an answer. `"status": "done"` means the assigned job is complete.
3. You reply by updating `.orchestrate/<slug>/prompt.md` and running `resume`. agy continues in
   the same conversation with its full context, including earlier file reads and edits.

That loop repeats as many times as the phase needs. agy asks questions, you answer, it resumes,
and completes the work. You can also start an exchange yourself: a redo request, a request to
restate a malformed report, or the validate pass. All of these go to the same conversation with
`resume`.

Helper commands (`agy-exec.sh` ships next to this skill):

```bash
bash <skill-dir>/agy-exec.sh <slug> new .orchestrate/<slug>/prompt.md     # fresh conversation, one per phase
bash <skill-dir>/agy-exec.sh <slug> resume .orchestrate/<slug>/prompt.md  # next turn, same conversation
bash <skill-dir>/agy-exec.sh <slug> conversation                         # current conversation id
bash <skill-dir>/agy-exec.sh <slug> stop                                 # kill running turn, clear state
```

A turn can run for several minutes. Run `new` and `resume` in the background when needed, then
read the output once notified it exited. The helper exits 1 when agy fails or when its log
stream stays silent for 10 minutes (`AGY_EXEC_IDLE_TIMEOUT`). Treat that as blocked with a
malformed report. Set `AGY_ORCH_MODEL` on the command to override the model when the user asks
for one. Set `AGY_ORCH_EFFORT` to adjust reasoning effort (`low`, `medium`, `high`, `max`).

State lives under `${TMPDIR:-/tmp}/agy-orch-<slug>/`. Before executing each new or resumed
turn, the helper records `cli-version.txt` and `cli-path.txt`. If version capture fails, it
reports the error and does not dispatch agy.

### Context pressure and compaction

If agy observes a context-pressure or compaction warning, it must save a checkpoint in
the implementation log, append a question, and end the turn as blocked. Preserve the plan
constraints, decisions, completed and pending milestones, and verification evidence.
The orchestrator decides whether to continue or request manual compaction through a verified
supported mechanism. agy must not request manual compaction on its own.

This controls voluntary compaction, not runtime automatic compaction, which can occur before
the worker reports a warning. The current helper has no manual compaction command. Do not
invent one or change global compaction settings to bypass this limitation. Use actual runtime
telemetry for token reports; if counters are unavailable, report that instead of estimating.

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
`plans/` holds plan files only; commit `.orchestrate/` with the work so the run record stays
reviewable:
- `.orchestrate/<slug>/questions.md`: agy appends blocking questions.
- `.orchestrate/<slug>/answers.md`: you append answers.
- `.orchestrate/<slug>/implementation-log.md`: agy appends a report after each phase.

The files are the durable record and the cross-phase handoff. The live conversation carries the
exchange within a phase; the files carry it across phases and survive the run.
`.orchestrate/<slug>/prompt.md` is scratch, updated every turn and deleted at the end.

Also record `git rev-parse HEAD` once, now. Nothing is committed during this run, so that
value must hold until the end. Any change to it means an agent committed, which is drift.

Do not modify `plans/<slug>.md` itself; it is the source of truth.

**Resolve blockers before the first dispatch.** Read the plan for anything agy cannot do
from a non-interactive run: external accounts or app IDs it would have to create, credentials,
physical devices, recordings, or third-party service setups. Also check the phase map: if the
plan has no `Phase`/`Milestone` headings, ask the user how to split it instead of assuming.
Ask all of these in one question call, then record each answer as a pre-dispatch `A<n>` in the
answers file so agy treats it as binding. Typical items: which fallback path to take when an
external service is not set up, and which checks stay with the owner (device tests, demo
recording).

## Step 3: Phase loop (per phase)

For each phase, in order:

1. **Record the phase baseline.** Nothing is committed during this run, so HEAD does not move
   and cannot scope a phase. Snapshot the working tree instead:

   ```bash
   git stash create          # prints a commit SHA capturing current tracked tree
   git status --porcelain    # record '??' entries; snapshot excludes untracked files
   ```

   `git stash create` writes a commit object without modifying the working tree or the stash
   list, so it is safe to call mid-run. On a clean tree it prints nothing; use `git rev-parse
   HEAD` as the baseline in that case. Keep the SHA and the untracked list for this phase.
2. **Start the phase conversation.** Write the dispatch prompt below to
   `.orchestrate/<slug>/prompt.md`, filled in with this phase's label and milestone numbers. Run
   `agy-exec.sh <slug> new .orchestrate/<slug>/prompt.md` in the background.
3. Read the final response text it prints. Parse the trailing JSON block and branch:
   - `"status": "blocked"`: resolve the listed questions per **Step 4: Resolve agy questions**,
     then `resume` with the reply prompt. agy continues with its context intact. Repeat until
     done.
   - `"status": "done"`: continue to the drift check below.
   - Missing or malformed JSON, or the helper exited 1: treat as blocked. Read the questions
     file. If it is empty, `resume` once asking agy to restate its status in the required
     JSON shape. If that fails too, escalate.
4. **Drift check.** Treat agy as a junior/mid developer; do not trust its self-assessment.
   Inspect the actual diff (`git diff`, `git status --porcelain`) against the phase's
   milestones. Re-check the reported `→ Verify:` results. Look for: scope creep, skipped
   steps, contradicted Decisions Log entries, convention violations, security issues, silent
   behavior changes. Check that `git rev-parse HEAD` still equals what it was when the run
   started. If HEAD moved, halt all operations immediately per **Step 5: Drift halt and CTO
   report**. If drift, halt and report the same way. If a verify check failed, `resume` the
   conversation asking agy to redo that milestone once; if it fails again, halt and report.

   agy's report is a claim, not evidence. Checks that caught real overclaims:
   - **Stubs.** Grep the diff for `placeholder`, `decorative`, `not a real`, `in prototype`,
     `for testing`, hardcoded sample values, and buttons that navigate instead of acting. A
     claimed core flow built from these is drift.
   - **Orphan modules.** For every core module the plan names, confirm an entry point or route
     imports it (`grep -rn "from .*<module>"`). A tested module that nothing calls means the
     feature is not integrated.
   - **Claimed items.** For each item in a fix list, open the file and line it cites and read it.
     Assets claimed as copied must be referenced in code.
   - **Build checks that prove nothing.** A bundle export that passes can still exclude the
     app. Check that the entry file imports the app. Check dependency alignment.
   - **Plan rules.** Grep for the plan's hard rules directly (forbidden endpoints, float maths
     on money, banned words, secrets).
5. **Implementation review (per phase).** Review the phase yourself, in this session. Scope is
   this phase only: `git diff <snapshot SHA>` plus any untracked file that appeared since step 1.
   The snapshot is what keeps this phase's review from re-covering earlier phases still
   sitting uncommitted in the tree. Follow the implementation-review skill, split across the
   two contexts:
   - **Flaw detection, plan deviation check, and fixes stay with you.** agy wrote this code
     and cannot review it independently. Apply critical fixes yourself.
   - **Validate and test is delegated.** Once your fixes are in place, write the validate
     prompt to `.orchestrate/<slug>/prompt.md` and `resume` the same conversation. Read the
     results from its JSON block. Test output is bulky and needs no judgment, so it does not
     belong in your context.

   The validate step is read-only. Compare `git status --porcelain` before and after it; if
   the tree changed, that is drift; halt per **Step 5: Drift halt and CTO report**.

   Handle the review's two non-fixed buckets:
   - **Needs Your Input** (close tradeoffs): resolve through **Step 4: Resolve agy questions**.
   - **Issues Reported (not auto-fixed)**: do not fix, do not block. Carry them to the Finish
     step so the user can opt in.

   If a check comes back `fail`, fix it yourself and `resume` with the validate prompt again.
   Do not proceed until every check passes or is legitimately skipped, and no critical issues
   remain.

   **Run it.** When the phase ships an app (mobile, web, CLI), typecheck, unit tests, and a
   bundle build are not proof that it works. Launch it and drive the phase's core flow before
   you close the phase. For an Expo or React Native app, use the `run-expo-android` skill
   (Linux and macOS). For other app types, use the project's run instructions or the `run`
   skill. Things only a running app revealed: render crashes from invalid syntax, button handlers
   that never fire, escaped characters printed literally in text, routes to missing screens.
   Fix runtime bugs as part of the review. Record what was verified on the running app, and
   what could not be, in the implementation log.
6. **Do not commit and do not document.** The phase ends here, with its work in the working
   tree. Documentation and commits are the user's call, after the run.
7. Advance to the next phase. Take a fresh snapshot for it (step 1) and start a new conversation
   with `new`. Do not `resume` the previous phase's conversation.

agy's messages are not shown directly to the user. After each phase, relay one line of
progress yourself.

## Step 4: Resolve agy questions

For each new question in `.orchestrate/<slug>/questions.md`, classify it first, then act.

**Answer it yourself** when the right answer is clear from one of these:
- the plan itself implies it,
- the project conventions (`CLAUDE.md` / `AGENTS.md`) settle it,
- established practice with no real tradeoff,
- an existing pattern in the codebase agy should follow.

Write the answer to `.orchestrate/<slug>/answers.md` with a one-line rationale. Use best judgment
and move on.

**Ask the user** when none of the above holds: a genuine product or design tradeoff, a
missing requirement, a plan ambiguity with material consequences, or two or more defensible
options where guessing risks rework. Present the question, the top options with tradeoffs,
and your recommendation. Record the user's answer in `.orchestrate/<slug>/answers.md`.

Question block (agy appends):

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

The file write matters even though the conversation is live: a later phase's conversation
starts fresh and learns the decision only from the file.

## Step 5: Drift halt and CTO report

You are the lead. agy is a junior/mid developer. When you detect it doing something wrong,
stop it and report to the user (the CTO). Do not fix the mistake yourself and do not let agy
keep going.

**What counts as wrong (drift):**
- scope creep: touched files or milestones outside the assigned phase,
- skipped a plan step or milestone,
- contradicted a plan Decisions Log entry or an explicit plan step,
- broke the project's conventions (`CLAUDE.md` / `AGENTS.md`),
- introduced a security issue,
- faked or skipped verification: claimed a `→ Verify:` passed without running it,
- shipped a stub, placeholder, sample value, or navigation-only button as a finished step,
- reported "no UI in scope" while the diff changes pages, components, templates, or styling,
- reported "no Python in scope" while the diff changes `.py` files,
- made a silent behavior change the plan does not call for,
- edited files during the read-only validate step,
- committed anything at all. Nothing is committed during this run.

A deviation that is clearly better and stays within the plan's goal is not drift. Note it,
continue, and surface it in the final summary so the CTO knows the plan may need updating.

When you halt, run `agy-exec.sh <slug> stop` if a turn is still running, present this report
to the user, and wait. Take no further action until the CTO decides.

```
## CTO report

**Incident**: <phase label>, <milestone(s)>
**What agy did wrong**: <concrete, with file:line or diff evidence>
**Why it is wrong**: <against plan step X, scope, convention, or security>
**Reported vs actual**: <what agy claimed vs what you verified>
**Impact**: <what breaks or what rework is at risk>
**Options**:
1. <option A>, <tradeoff>
2. <option B>, <tradeoff>
**My recommendation**: <which option, one line why>
```

Record the report and the CTO's eventual decision in `.orchestrate/<slug>/implementation-log.md`.

## Step 6: Finish

After the last phase is reviewed:

1. Copy `cli-version.txt` and `cli-path.txt` from helper state into
   `.orchestrate/<slug>/implementation-log.md` if not already recorded.
   Run `agy-exec.sh <slug> stop` and delete `.orchestrate/<slug>/prompt.md`.
2. Read the full `.orchestrate/<slug>/implementation-log.md`.
3. Run `git status --porcelain`. Every phase's work is uncommitted, so expect a dirty tree.
   Confirm that what is there is the plan's work and nothing else.
4. Summarize for the user: phases completed, key files touched, review results, and questions
   auto-answered vs escalated.
5. List the review's **Issues Reported (not auto-fixed)** items verbatim. Tell the user they
   were left unfixed on purpose and ask whether to fix any. If the user says fix, route actual
   bugs to `fix-bug` and the rest to a quick agy pass.
6. State plainly that nothing was committed and no docs were written, and that the whole run
   sits uncommitted in the working tree. Offer `document-and-commit` as the next step. Do not
   run it unless the user asks.

## Dispatch prompt

Write this to `.orchestrate/<slug>/prompt.md` when starting a phase with `new`, replacing the
placeholders:

````markdown
You are the implementor for one phase of an approved plan. An orchestrator directs you and
reviews everything you produce. You talk to it only by ending your turn: it reads your final
message, and replies by resuming this same conversation.

## Assignment
Plan: `plans/<slug>.md`
Phase: <phase label, or "the whole plan" if unphased>
Milestones in scope (implement only these): <comma list, e.g. 1, 2, 3>

## Before you start
1. Read `plans/<slug>.md` in full, then re-read the milestones in scope.
2. Read the project's `CLAUDE.md` (or `AGENTS.md`) and follow its conventions exactly.
3. If `.orchestrate/<slug>/answers.md` is non-empty, read it. Treat every A<n> in it as a binding
   decision. Do not re-ask anything already answered.
4. If `.orchestrate/<slug>/implementation-log.md` is non-empty, read it. Earlier phases were built in
   a different conversation and this log is the only record of what they did.

## While implementing
**Commit policy: do not commit anything, ever. Do not stage anything. Leave all changes in the
working tree. Nothing is committed during this run; the user commits when the whole run is
done.**
1. Implement the milestones in order, following the plan steps literally. Do not touch work
   that belongs to another phase, and do not improve adjacent code.
2. Run every `→ Verify:` check. Do not continue past a milestone whose verify check fails.
   Never report a check as passing unless you ran it and read the output.
3. If you hit a blocking ambiguity that the plan and the answers file do not resolve, STOP. Do
   not guess. Append the question to `.orchestrate/<slug>/questions.md` using the question format
   below, then end your turn with the blocked JSON block. The orchestrator will resume this
   conversation with the answer and you continue from where you stopped. Asking is cheap; a wrong
   guess costs a redo.
4. If the plan conflicts with the codebase in a way that needs a product decision, that is a
   blocking question, not something to silently resolve.
5. Never replace real behavior with a stub, placeholder, sample value, or navigation-only
   button to get a step "done". If you cannot finish part of a step, say exactly which part and
   why in the report.
6. A passing typecheck, test run, or bundle build does not prove the app runs. Do not describe
   work as working unless you exercised it. List anything you could not run as pending, with
   the reason.
7. Verify framework and library APIs and versions against what is installed, not memory. Keep
   native dependencies aligned with the framework's expected versions.
8. Never edit `plans/<slug>.md`. It belongs to the orchestrator.
9. If you observe a context-pressure or compaction warning, save a checkpoint in the
   implementation log, append a question to the questions file, and end with blocked status.
   Let the orchestrator decide whether to continue or request manual compaction. Report token
   counters only when available from actual runtime telemetry; otherwise state that they are
   unavailable. Do not estimate them.

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
- Frontend skills applied: <"no UI in scope", or the skills you applied and where>
- Python skill applied: <"no Python in scope", or where you applied python-development>
- Deviations from plan: <none, or list>
- Questions raised: <none, or list of Q ids>

## Ending JSON block
Every turn in this conversation ends with exactly one fenced JSON block as the last thing in your
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

Write this to `.orchestrate/<slug>/prompt.md` during step 5 and `resume` the phase's conversation,
replacing the placeholders:

````markdown
Implementation for this phase is done and I have reviewed it and applied fixes. Your job now
is to run checks and report results. Nothing else.

**You are read-only for this turn. Do not edit, create, or delete any file. Do not commit. Do
not fix anything you find. If a check fails, report the failure and move on to the next
check.** I diff the working tree before and after this turn; any edit you make here is drift.

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

## Native Antigravity subagent option

When running inside an interactive Antigravity session (IDE or CLI) with tool access to
`invoke_subagent`, the orchestrator can also choose to invoke the implementor natively instead
of running the shell script.

To use the native subagent option:
1. Dispatch the subagent using `invoke_subagent` with `Role: "Phase Implementor"`, `TypeName: "self"`,
   and the dispatch prompt as `Prompt`. Set `Workspace: "inherit"` to share the working tree.
2. Handle questions by messaging the subagent conversation ID with `send_message`.
3. Dispatch the read-only validate step using `send_message` with the validate prompt.

`agy-exec.sh` remains the recommended path across heterogeneous orchestrators because it
guarantees process isolation and automated idle timeouts.

## Rules

- You do not implement the plan's milestones yourself; you delegate them to agy. You do run
  the per-phase implementation review and fix critical issues it finds.
- Review judgment stays with you. Only the mechanical validate-and-test pass is delegated, and
  that pass is read-only: it reports results and never fixes what it finds.
- Treat agy as a junior/mid developer. Verify its work after each phase; never trust its
  self-assessment.
- On drift (agy did something wrong), halt and report to the CTO. Do not fix it yourself
  and do not continue until the CTO decides.
- Never advance past a blocked phase, a failed verify check, a malformed report, or detected
  drift.
- Do not guess the answer to a question that is a genuine judgment call. That is the one thing
  you escalate.
- Do not let agy silently resolve a plan-vs-codebase conflict; route it through the questions
  file.
- Answer the easy questions yourself. Asking the user about things you can decide wastes their
  time.
- Every reply to agy within a phase goes through `resume` on that phase's conversation. Never
  start a new conversation mid-phase; it throws away everything agy learned in the phase.
- This skill never commits and never writes documentation. It implements and reviews, and
  leaves the result in the working tree. If anything commits, halt all operations immediately.
  Do not retry, do not fix, do not continue. Report to the CTO.
- Scope each phase's review with that phase's `git stash create` snapshot, not with HEAD.
  HEAD does not move during the run, so it cannot tell one phase from another.
- Keep the handoff files append-only. Never rewrite or renumber past entries. Write answers to
  the file even when the live conversation already has them; the next phase's conversation
  reads only files.
- The plan file is the source of truth. agy never edits it; only you may append to its
  Decisions Log.
- The dispatch prompt's Frontend and Python sections go in every phase, unedited. agy
  decides whether the phase touches UI or Python and self-negates when it does not. You do not
  make that call, because misreading a phase as backend-only silently ships stock UI, and
  misreading it as frontend-only silently ships class-based Python.
- Check the report's "Frontend skills applied" and "Python skill applied" lines against the
  diff during the drift check. A phase that changed templates or `.py` files but reports "no
  UI in scope" or "no Python in scope" is a false report, not a judgment call.
- Report progress to the user in one line per phase. Reserve detail for the final summary.

## References and troubleshooting

If agy encounters an execution issue, stalled command, or permission block, consult these references:
- [CLI Reference](file:///Users/amirinns/Projects/coding-agent-skills/skills/orchestrate-implementation-agy/references/agy-cli-reference.md)
- [Troubleshooting and Bugfixes](file:///Users/amirinns/Projects/coding-agent-skills/skills/orchestrate-implementation-agy/references/troubleshooting-and-bugfixes.md)
- [Subagent Mechanics Guide](file:///Users/amirinns/Projects/coding-agent-skills/skills/orchestrate-implementation-agy/references/subagents.md)
