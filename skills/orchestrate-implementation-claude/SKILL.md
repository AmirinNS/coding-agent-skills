---
name: orchestrate-implementation-claude
description: "Delegate implementation of an approved plan to a sonnet phase-implementor subagent, phase by phase. Per phase: spawn the implementor, drift-check, run implementation-review. Questions round-trip over SendMessage. Drift halts with a CTO report. Never commits and never writes docs; the whole run is left uncommitted for the user to review, then document-and-commit themselves. Pure Claude Code, no external CLI. Triggers: 'implement the plan', 'delegate the implementation', 'orchestrate the implementation', 'run the plan', 'execute the plan', 'build this plan', 'implement by phase'."
---

# Orchestrate Implementation (Claude subagents)

You are the orchestrator. You do not write the phase code yourself. You delegate
implementation of an approved plan to a `phase-implementor` subagent, one phase at a time,
and you are the only bridge between that implementor and the user.

## Why this exists

The main session keeps a clean, high-level context. The implementor does the file-level work
in its own context, so bulky file reads and test output never land in yours. Questions flow
up to you. You answer what you can, and only bother the user when the answer is a real
judgment call.

One implementor per phase, not one per run. Subagents cannot be compacted, so a single
implementor carried across every phase would grow unbounded with no recovery path. A fresh
spawn per phase is the compaction. Continuity across phases comes from
`plans/<slug>-implementation-log.md`, which each new implementor reads first.

This skill stops at review. It does not write documentation and does not commit, ever. The
whole run lands in the working tree for the user to inspect as one change set, and they decide
when to run `document-and-commit`.

## Prerequisite

This skill needs the `phase-implementor` agent installed. Check for it:

```bash
ls ~/.claude/agents/phase-implementor.md .claude/agents/phase-implementor.md 2>/dev/null
```

If neither exists, install the copy that ships next to this skill and tell the user you did:

```bash
mkdir -p ~/.claude/agents
cp <path-to-this-skill>/agents/phase-implementor.md ~/.claude/agents/
```

Claude Code only loads agent definitions from `~/.claude/agents/` or a project's
`.claude/agents/`, so the copy is required; the file cannot stay in the skill directory and
still be spawnable. It is picked up on spawn, so no restart is needed.

## Inputs

- An approved plan at `plans/<slug>.md` (written by plan-feature, reviewed by plan-review).
- The target project is the current working directory.
- Optional: the user may specify a phase to start from, or override the implementor model.

If no plan path is given, discover it with `ls plans/*.md`. If more than one exists, ask
which to implement. If none exists, stop and tell the user to run plan-feature first.

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

Create these handoff files under `plans/`, empty if missing:
- `plans/<slug>-questions.md`: implementor appends blocking questions.
- `plans/<slug>-answers.md`: you append answers.
- `plans/<slug>-implementation-log.md`: implementor appends a report after each phase.

The files are the durable record and the cross-phase handoff. `SendMessage` carries the live
conversation within a phase; the files carry it across phases and survive the run.

Also record `git rev-parse HEAD` once, now. Nothing is committed during this run, so that
value must hold until the end. Any change to it means an agent committed, which is drift.

Do not modify `plans/<slug>.md` itself; it is the source of truth.

**Resolve blockers before the first dispatch.** Read the plan for anything the implementor
cannot do from a subagent: external accounts or app IDs it would have to create, credentials,
physical devices, recordings. Also check the phase map: if the plan has no `Phase`/`Milestone`
headings, ask the user how to split it instead of assuming. Ask all of these in one
`AskUserQuestion` call, then record each answer as a pre-dispatch `A<n>` in the answers file so
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
2. **Spawn the implementor.** Call `Agent` with `subagent_type: "phase-implementor"` and the
   dispatch prompt below, filled in with this phase's label and milestone numbers. Record the
   agent's name from the spawn result; every follow-up in this phase goes to that name.
3. Read the report it returns. Parse the trailing JSON block and branch:
   - `"status": "blocked"`: resolve the listed questions per **Step 4: Resolve implementor
     questions**, then `SendMessage` the resume prompt to the same agent. It continues with
     its context intact. Repeat until done.
   - `"status": "done"`: continue to the drift check below.
   - Missing or malformed JSON: treat as blocked. Read the questions file. If it is empty,
     `SendMessage` the agent once asking it to restate its status in the required JSON shape.
     If that fails too, escalate.
4. **Drift check.** Treat the implementor as a junior/mid developer; do not trust its
   self-assessment. Inspect the actual diff (`git diff`, `git status --porcelain`) against the
   phase's milestones. Re-check the reported `→ Verify:` results. Look for: scope creep,
   skipped steps, contradicted Decisions Log entries, convention violations, security issues,
   silent behavior changes. Check `git rev-parse HEAD` still equals what it was when the run
   started. If HEAD moved, the implementor committed; halt all operations immediately per
   **Step 5: Drift halt and CTO report**. If drift, halt and report the same way. If a verify
   check genuinely failed, `SendMessage` the agent to redo that milestone once; if it fails
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
   - **Validate and test is delegated.** Once your fixes are in place, `SendMessage` the
     validate prompt to the same implementor agent. Read the results from its JSON block. Test
     output is bulky and needs no judgment, so it does not belong in your context.

   The validate step is read-only. Compare `git status --porcelain` before and after it; if
   the tree changed, that is drift; halt per **Step 5: Drift halt and CTO report**.

   Handle the review's two non-fixed buckets:
   - **Needs Your Input** (close tradeoffs): resolve through **Step 4: Resolve implementor
     questions**.
   - **Issues Reported (not auto-fixed)**: do not fix, do not block. Carry them to the Finish
     step so the user can opt in.

   If a check comes back `fail`, fix it yourself and `SendMessage` the validate prompt again.
   Do not proceed until every check passes or is legitimately skipped, and no critical issues
   remain.

   **Run it.** When the phase ships an app (mobile, web, CLI), typecheck, unit tests and a
   bundle build are not proof that it works. Launch it and drive the phase's core flow before
   you close the phase. For an Expo or React Native app, use the `run-expo-android` skill
   (Linux and macOS). For other app types, use the project's own run instructions or the `run`
   skill. Things only a running app revealed: a render crash from an invalid SVG path, buttons
   whose handler never fired, `\uXXXX` escapes printed literally in JSX text, two tab bars,
   missing safe-area insets, routes to screens that do not exist. Fix critical runtime bugs as
   part of the review. Record what was verified on the running app, and what could not be (for
   example no test funds, or no physical camera), in the implementation log.
6. **Do not commit and do not document.** The phase ends here, with its work in the working
   tree. Documentation and commits are the user's call, after the run.
7. Advance to the next phase. Take a fresh snapshot for it (step 1) and spawn a brand new
   implementor. Do not reuse the previous phase's agent.

Subagent reports are not shown to the user. After each phase, relay one line of progress
yourself.

## Step 4: Resolve implementor questions

For each new question in `plans/<slug>-questions.md`, classify it first, then act.

**Answer it yourself** when the right answer is clear from one of these:
- the plan itself already implies it,
- the project conventions (`CLAUDE.md` / `AGENTS.md`) settle it,
- established best practice with no real tradeoff,
- an existing pattern in the codebase the implementor should follow.

Write the answer to `plans/<slug>-answers.md` with a one-line rationale. Use best judgment
and move on.

**Ask the user** when none of the above holds: a genuine product or design tradeoff, a
missing requirement, a plan ambiguity with material consequences, or two or more defensible
options where guessing risks rework. Present the question, the top options with tradeoffs,
and your recommendation. Record the user's answer in `plans/<slug>-answers.md`.

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

Write the answers to the file first, then send this resume message to the implementor:

```
Answers to your questions are in `plans/<slug>-answers.md`: <A ids>. Read them, treat each
as a binding decision, and continue this phase from where you stopped. Do not redo completed
milestones. End with the same JSON block contract.
```

The file write matters even though the agent is live: a later phase's implementor is a
different agent and learns the decision only from the file.

## Step 5: Drift halt and CTO report

You are the lead. The implementor is a junior/mid developer. When you detect it doing
something wrong, stop it and report to the user (the CTO). Do not fix the mistake yourself
and do not let the implementor keep going.

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
- committed anything at all. Nothing is committed during this run, so any new commit is drift.

A deviation that is clearly better and stays within the plan's goal is not drift. Note it,
continue, and surface it in the final summary so the CTO knows the plan may need updating.

When you halt, present this report to the user and wait. Take no further action until the CTO
decides.

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

Record the report and the CTO's eventual decision in `plans/<slug>-implementation-log.md`.

## Step 6: Finish

After the last phase is reviewed:

1. Read the full `plans/<slug>-implementation-log.md`.
2. Run `git status --porcelain`. Every phase's work is uncommitted, so expect a dirty tree.
   Confirm that what is there is the plan's work and nothing else.
3. Summarize for the user: phases completed, key files touched, review results, and questions
   auto-answered vs escalated.
4. List the review's **Issues Reported (not auto-fixed)** items verbatim. Tell the user they
   were left unfixed on purpose and ask whether to fix any. If the user says fix, route actual
   bugs to `fix-bug` and the rest to a quick implementor pass.
5. State plainly that nothing was committed and no docs were written, and that the whole run
   sits uncommitted in the working tree. Offer `document-and-commit` as the next step. Do not
   run it unless the user asks.

No teardown step. Subagents end on their own once the run is over.

## Dispatch prompt

Send this as the `prompt` when spawning the phase's implementor, replacing the placeholders:

````markdown
You are the implementor for one phase of an approved plan.

## Assignment
Plan: `plans/<slug>.md`
Phase: <phase label, or "the whole plan" if unphased>
Milestones in scope (implement only these): <comma list, e.g. 1, 2, 3>

## Before you start
1. Read `plans/<slug>.md` in full, then re-read the milestones in scope.
2. Read the project's `CLAUDE.md` (or `AGENTS.md`).
3. If `plans/<slug>-answers.md` is non-empty, read it. Treat every A<n> in it as a binding
   decision. Do not re-ask anything already answered.
4. If `plans/<slug>-implementation-log.md` is non-empty, read it. Earlier phases were built by
   a different implementor and this log is the only record of what they did.

## While implementing
**Commit policy: do not commit anything, ever. Do not stage anything. Leave all changes in the
working tree. Nothing is committed during this run; the user commits when the whole run is
done.**
1. Implement the milestones in order, following the plan steps literally. Do not touch work
   that belongs to another phase.
2. Run every `→ Verify:` check. Do not continue past a milestone whose verify check fails.
3. If you hit a blocking ambiguity that the plan and the answers file do not resolve, STOP. Do
   not guess. Append the question to `plans/<slug>-questions.md` using the question format
   below, then end with the blocked JSON block. You will be messaged back with the answer and
   can resume from where you stopped.
4. If the plan conflicts with the codebase in a way that needs a product decision, that is a
   blocking question, not something to silently resolve.
5. Never replace real behavior with a stub, placeholder, sample value or navigation-only
   button to get a step "done". If you cannot finish part of a step, say exactly which part and
   why in the report.
6. A passing typecheck, test run or bundle build does not prove the app runs. Do not describe
   work as working unless you exercised it. List anything you could not run as pending, with
   the reason.
7. Verify framework and library APIs and versions against what is installed, not memory. Keep
   native dependencies aligned with the framework's expected versions.

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
1. Append a report to `plans/<slug>-implementation-log.md` using the report format below.
2. End your final message with the done JSON block.

## Question format (append to `plans/<slug>-questions.md`)
### Q<n>: <short title>
Context: <what you were doing and why this blocks you>
Question: <one clear question>
Options considered: <options and tradeoffs, if any>

## Report format (append to `plans/<slug>-implementation-log.md`)
## Phase <label>: <name> (done)
- Milestones completed: <list>
- Files touched: <list>
- Verify results: <pass/fail per check>
- Frontend skills applied: <"no UI in scope", or the skills you applied and where>
- Python skill applied: <"no Python in scope", or where you applied python-development>
- Deviations from plan: <none, or list>
- Questions raised: <none, or list of Q ids>

## Ending JSON block
Your final message must end with exactly one fenced JSON block:

```json
{ "status": "done", "phase": "<label>", "summary": "<one paragraph>" }
```

or

```json
{ "status": "blocked", "phase": "<label>", "questions": ["Q<n>", ...] }
```
````

## Validate prompt

`SendMessage` this to the phase's implementor during step 5, replacing the placeholders:

````markdown
Implementation for this phase is done and I have reviewed it and applied fixes. Your job now
is to run checks and report results. Nothing else.

**You are read-only for this message. Do not edit, create, or delete any file. Do not commit.
Do not fix anything you find. If a check fails, report the failure and move on to the next
check.** I diff the working tree before and after this step; any edit you make here is drift.

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

## Agent mechanics

- Spawn: `Agent` with `subagent_type: "phase-implementor"`. The agent definition pins the
  model to sonnet; pass `model` only when the user asks to override it.
- Continue: `SendMessage` to the agent's name. The agent resumes from its transcript, so you
  never restate context it already has.
- One agent per phase, covering implement and validate. Never carry an agent across phases.
- Agents run in the same working directory and see the same git tree. Do not pass
  `isolation: "worktree"`; the drift check and the phase snapshots both depend on a shared
  tree.
- Everything an agent returns is text to you, not to the user. Relay progress yourself.

## Rules

- You do not implement the plan's milestones yourself; you delegate them to the implementor.
  You do run the per-phase implementation review and fix critical issues it finds.
- Review judgment stays with you. Only the mechanical validate-and-test pass is delegated, and
  that pass is read-only: it reports results and never fixes what it finds.
- Treat the implementor as a junior/mid developer. Verify its work after each phase; never
  trust its self-assessment.
- On drift (the implementor did something wrong), halt and report to the CTO. Do not fix it
  yourself and do not continue until the CTO decides.
- Never advance past a blocked phase, a failed verify check, a malformed report, or detected
  drift.
- Do not guess the answer to a question that is a genuine judgment call. That is the one thing
  you escalate.
- Do not let the implementor silently resolve a plan-vs-codebase conflict; route it through
  the questions file.
- Answer the easy questions yourself. Asking the user about things you can decide wastes their
  time.
- This skill never commits and never writes documentation. It implements and reviews, and
  leaves the result in the working tree. If any agent commits, halt all operations
  immediately. Do not retry, do not fix, do not continue. Report to the CTO.
- Scope each phase's review with that phase's `git stash create` snapshot, not with HEAD.
  HEAD does not move during the run, so it cannot tell one phase from another.
- A fresh implementor per phase is mandatory, not an optimization. It is what replaces
  compaction, which subagents do not have.
- Keep the handoff files append-only. Never rewrite or renumber past entries. Write answers to
  the file even when the live agent already has them; the next phase's agent reads only files.
- The plan file is the source of truth. The implementor never edits it; only you may append to
  its Decisions Log.
- The dispatch prompt's Frontend and Python sections go in every phase, unedited. The
  implementor decides whether the phase touches UI or Python and self-negates when it does
  not. You do not make that call, because misreading a phase as backend-only silently ships
  stock UI, and misreading it as frontend-only silently ships class-based Python.
- Check the report's "Frontend skills applied" and "Python skill applied" lines against the
  diff during the drift check. A phase that changed templates or `.py` files but reports "no
  UI in scope" or "no Python in scope" is a false report, not a judgment call.
- Report progress to the user in one line per phase. Reserve detail for the final summary.
