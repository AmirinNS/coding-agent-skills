---
name: orchestrate-implementation
description: "Delegate implementation of an approved plan to a persistent headless pi session (RPC mode), phase by phase. Per phase: dispatch the implementor, drift-check, run implementation-review, compact the session, then document-and-commit. Questions are answered in-session. Drift halts with a CTO report. Commit is per phase (or per plan if unphased), never per milestone. Requires the external pi CLI. Triggers: 'orchestrate with pi', 'implement the plan with pi', 'run the plan through pi', 'delegate the implementation to pi', 'pi orchestrator'. For the Claude-only equivalent with no external CLI, use orchestrate-implementation-claude instead."
---

# Orchestrate Implementation

You are the orchestrator. You do not write the phase code yourself. You delegate implementation of an approved plan to a persistent headless `pi` session (RPC mode), one phase at a time, and you are the only bridge between that implementor and the user.

## Why this exists

The main session keeps a clean, high-level context. The implementor does the file-level work in one long-lived pi session, so context and provider cache survive across phases. Questions flow up to you. You answer what you can, and only bother the user when the answer is a real judgment call.

## Inputs

- An approved plan at `plans/<slug>.md` (written by plan-feature, reviewed by plan-review).
- The target project is the current working directory.
- Optional: the user may specify the implementor model, thinking level, or a phase to start from.

If no plan path is given, discover it with `ls plans/*.md`. If more than one exists, ask which to implement. If none exists, stop and tell the user to run plan-feature first.

## Step 1: Read the plan and map its phases

Read `plans/<slug>.md`. Build an ordered list of phases, each with its milestones. Two formats exist; detect which applies.

**A. Metadata block present** (pembina-style plans carry `## Metadata` with `phased` and `phases`). Use it directly. Each entry in `phases` is a phase, and its `milestones` array is the ordered milestone list.

**B. Heading-based** (current plan-feature output). Scan headings:
- A phase is a heading containing `Phase` (for example `### Phase A: Foundation`).
- A milestone is a heading containing `Milestone N` (for example `### Milestone 1: ...`).
- Each milestone belongs to the nearest phase heading above it. Milestones with no phase heading above them belong to an implicit first phase, or to the whole plan if no phase headings exist.
- If the plan has no phase headings, treat the whole plan as a single phase.

Record each phase's label (or `whole plan` when unphased) and its ordered milestone numbers. This map drives the loop. Do not re-derive it mid-run.

## Step 2: Set up the run

Do these once.

- **Helper script**: `pi-rpc.sh` ships next to this skill. Invoke it as `bash <path-to-skill>/pi-rpc.sh <slug> <command> ...`. It manages one `pi --mode rpc` process per plan.
- **Handoff files** (all under `plans/`, created empty if missing):
  - `plans/<slug>-questions.md`: implementor appends blocking questions.
  - `plans/<slug>-answers.md`: you append answers.
  - `plans/<slug>-implementation-log.md`: implementor appends a report after each phase.
- **Start the session**: `bash pi-rpc.sh <slug> start`.

Create the three handoff files and start the session now. Do not modify `plans/<slug>.md` itself; it is the source of truth.

**Resolve blockers before the first dispatch.** Read the plan for anything the implementor cannot do headless: external accounts or app IDs it would have to create, credentials, physical devices, recordings. Also check the phase map: if the plan has no `Phase`/`Milestone` headings, ask the user how to split it instead of assuming. Ask all of these in one AskUserQuestion call, then record each answer as a pre-dispatch `A<n>` in the answers file so the implementor treats it as binding. Typical ones: which fallback path to take when an external service is not set up, how many commits, and which checks stay with the owner (device tests, demo recording).

## Step 3: Phase loop (per phase)

For each phase, in order:

1. Record the phase baseline: `git rev-parse HEAD`.
2. Write the dispatch prompt to `plans/<slug>-dispatch.md` (see the template below), filling in this phase's label and milestone numbers.
3. Run the implementor: `bash pi-rpc.sh <slug> run plans/<slug>-dispatch.md`. Read the final text (the trailing JSON block) from stdout.
4. Branch:
   - `"status": "blocked"`: resolve the listed questions (Step 4), then re-run step 3. The implementor resumes in-session.
   - `"status": "done"`: continue to the drift check (step 5).
   - Missing or malformed JSON: treat as blocked. Read the questions file. If it is empty, re-run step 3 once. If it fails again, escalate.
5. **Drift check.** Treat the implementor as a junior/mid developer; do not trust its self-assessment. Inspect the actual diff (`git diff`, `git status --porcelain`) against the phase's milestones. Re-check the reported `→ Verify:` results. Look for: scope creep, skipped steps, contradicted Decisions Log entries, convention violations, security issues, silent behavior changes. Check `git rev-parse HEAD` still equals the baseline from step 1. If HEAD moved (the implementor committed during implementation), halt all operations immediately (Step 5). If drift, halt and report (Step 5). If a verify check genuinely failed, re-run this phase once; if it fails again, halt and report.

   The implementor's report is a claim, not evidence. Checks that caught real overclaims:
   - **Stubs.** Grep the diff for `placeholder`, `decorative`, `not a real`, `in prototype`, `for testing`, hardcoded sample values, and buttons that navigate instead of acting. A "done" core flow built from these is drift.
   - **Orphan modules.** For every core module the plan names, confirm a screen or entry point imports it (`grep -rn "from .*<module>"`). A tested module nothing calls means the feature is fake.
   - **Claimed items.** For each item in a fix list, open the file:line it cites and read it. Assets "copied and used" must be referenced somewhere.
   - **Build checks that prove nothing.** A bundle or export that passes can still exclude the app. Check the entry file actually imports the app and the module count is plausible. Check framework dependency alignment (for Expo: `npx expo install --check`).
   - **Plan rules.** Grep for the plan's hard rules directly (forbidden endpoints, float maths on money, banned words, secrets).
6. **Implementation review (per phase).** Review the phase yourself, in this session. Scope is this phase only: `git diff <baseline>` plus new untracked files. Follow the implementation-review skill, split across the two sessions:
   - **Flaw detection, plan deviation check, and fixes stay with you.** The implementor wrote this code and cannot review it independently. Apply critical fixes yourself.
   - **Validate and test is delegated.** Once your fixes are in place, write the validate prompt to `plans/<slug>-validate.md` (see the template below) and run `bash pi-rpc.sh <slug> run plans/<slug>-validate.md`. Read the results from its JSON block. Test output is bulky and needs no judgment, so it does not belong in your context.

   The validate step is read-only. Compare `git status --porcelain` before and after it; if the tree changed, that is drift (Step 5).

   Handle the review's two non-fixed buckets:
   - **Needs Your Input** (close tradeoffs): resolve through Step 4.
   - **Issues Reported (not auto-fixed)**: do not fix, do not block. Carry them to the Finish step so the user can opt in.

   If a check comes back `fail`, fix it yourself and re-run the validate prompt. Do not proceed until every check passes or is legitimately skipped, and no critical issues remain.

   **Run it.** When the phase ships an app (mobile, web, CLI), typecheck, unit tests and a bundle build are not proof that it works. Launch it and drive the phase's core flow before committing. For an Expo or React Native app, use the `run-expo-android` skill (Linux and macOS). For other app types, use the project's own run instructions or the `run` skill. Things only a running app revealed: a render crash from an invalid SVG path, buttons whose handler never fired, `\uXXXX` escapes printed literally in JSX text, two tab bars, missing safe-area insets, routes to screens that do not exist. Fix critical runtime bugs as part of the review. Record what was verified on the running app, and what could not be (for example no test funds, or no physical camera), in the implementation log.
7. **Compact the session.** `bash pi-rpc.sh <slug> compact "Summarize what phase <label> built: files touched and key changes, for documentation and commit purposes."` This frees context before the finalize step while keeping the same session and cache. If the response reports `success:false` with `Nothing to compact (session too small)`, treat it as a soft skip and proceed; the session was already small enough.
8. **Document and commit (per phase).** Write the finalize prompt to `plans/<slug>-finalize.md` (see the template below), filling in the phase label and baseline. Run `bash pi-rpc.sh <slug> run plans/<slug>-finalize.md`. Branch on its JSON block exactly as in step 4.
9. **Verify the commit.** `git rev-list --count <baseline>..HEAD` must equal 1. Exactly one commit for this phase. If it is not 1, halt all operations immediately (Step 5).
10. Advance to the next phase. Its baseline is the new HEAD.

## Step 4: Resolve implementor questions

For each new question in `plans/<slug>-questions.md`, classify it first, then act.

**Answer it yourself** when the right answer is clear from one of these:
- the plan itself already implies it,
- the project conventions (`CLAUDE.md` / `AGENTS.md`) settle it,
- established best practice with no real tradeoff,
- an existing pattern in the codebase the implementor should follow.

Write the answer to `plans/<slug>-answers.md` with a one-line rationale. Use best judgment and move on.

**Ask the user** when none of the above holds: a genuine product or design tradeoff, a missing requirement, a plan ambiguity with material consequences, or two or more defensible options where guessing risks rework. Present the question, the top options with tradeoffs, and your recommendation. Record the user's answer in `plans/<slug>-answers.md`.

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

Number questions `Q1`, `Q2`, ... sequentially across the whole run. Never reuse a number. When a phase is re-run, the implementor reads all answers written so far and resumes.

## Step 5: Drift halt and CTO report

You are the lead. The implementor is a junior/mid developer. When you detect it doing something wrong, stop it and report to the user (the CTO). Do not fix the mistake yourself and do not let the implementor keep going.

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
- committed during implementation, before the phase's document-and-commit step.

A deviation that is clearly better and stays within the plan's goal is not drift. Note it, continue, and surface it in the final summary so the CTO knows the plan may need updating.

When you halt, present this report to the user and wait. Take no further action until the CTO decides.

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

After the last phase is done and committed:

1. `bash pi-rpc.sh <slug> stop`.
2. Read the full `plans/<slug>-implementation-log.md`.
3. Run `git status --porcelain` to confirm the working tree is clean, or that only intentional files remain.
4. Summarize for the user: phases completed, key files touched, review results, questions auto-answered vs escalated, and the commits (one per phase).
5. List the review's **Issues Reported (not auto-fixed)** items verbatim. Tell the user they were left unfixed on purpose and ask whether to fix any. If the user says fix, route actual bugs to `fix-bug` and the rest to a quick implementor pass.

## Dispatch prompt template

Write this to `plans/<slug>-dispatch.md` for each phase, replacing the placeholders:

````markdown
You are the implementor for one phase of an approved plan. Work in the current directory and follow the project's CLAUDE.md (or AGENTS.md) conventions exactly. The plan is provided in this message.

## Assignment
Plan: `plans/<slug>.md`
Phase: <phase label, or "the whole plan" if unphased>
Milestones in scope (implement only these): <comma list, e.g. 1, 2, 3>

## Before you start
1. If `plans/<slug>-answers.md` exists, read it. Treat every A<n> in it as a binding decision. Do not re-ask anything already answered.
2. If `plans/<slug>-implementation-log.md` exists, read the most recent report for context on earlier phases.
3. If you already started this phase in an earlier turn, continue from where you stopped. Do not redo completed milestones.

## While implementing
**Commit policy: do not commit anything. Leave all changes uncommitted. The single commit for this phase happens once, at the very end, by the finalize step.**
1. Implement the milestones in order, following the plan steps literally. Do not touch work that belongs to another phase.
2. Run every `→ Verify:` check. Do not continue past a milestone whose verify check fails.
3. If you hit a blocking ambiguity that the plan and the answers file do not resolve, STOP. Do not guess. Append the question to `plans/<slug>-questions.md` using the question format below, then end with the blocked JSON block.
4. If the plan conflicts with the codebase in a way that needs a product decision, that is a blocking question, not something to silently resolve.
5. Never replace real behavior with a stub, placeholder, sample value or navigation-only button to get a step "done". If you cannot finish part of a step, say exactly which part and why in the report.
6. A passing typecheck, test run or bundle build does not prove the app runs. Do not describe work as working unless you exercised it. List anything you could not run as pending, with the reason.
7. Verify framework and library APIs and versions against what is installed, not memory. Keep native dependencies aligned with the framework's expected versions.

## Frontend
Decide this yourself from the milestones in scope; do not wait to be told.

If this phase adds or changes any page, component, template, or styling, apply the frontend-design skill to that work. If the project uses Bootstrap 5, also apply the frontend-bootstrap-evolution skill so the result does not look like a stock Bootstrap page. Name the skills you applied in your phase report.

If this phase touches no UI, ignore this section and say "no UI in scope" in your report.

## Python
Decide this yourself from the milestones in scope; do not wait to be told.

If this phase writes or edits any Python, apply the python-development skill to that work. Name it in your phase report.

If this phase touches no Python, ignore this section and say "no Python in scope" in your report.

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

## Validate dispatch template

Write this to `plans/<slug>-validate.md` during step 6, replacing the placeholders:

````markdown
You are the validation step for one phase of an approved plan. The code is already written and reviewed. Your job is to run checks and report results. Nothing else.

**You are read-only. Do not edit, create, or delete any file. Do not commit. Do not fix anything you find. If a check fails, report the failure and move on to the next check.**

## What to run
1. Discover the project's real commands by reading `package.json`, `Makefile`, `pyproject.toml`, or the equivalent. Do not guess command names.
2. Run the test suite. If the project has none, say so.
3. Run the lint and build/typecheck steps if they exist.
4. Run every `→ Verify:` check listed in `plans/<slug>.md` for milestones <comma list>.

## How to report
One line per command. Quote only the decisive failing line for anything that fails, never the full log.

End your final message with exactly one fenced JSON block:

```json
{ "status": "done", "phase": "<label>", "checks": [{ "cmd": "<command>", "result": "pass|fail|skipped", "detail": "<one line, empty when pass>" }] }
```

Use `"skipped"` when the project has no such check. Report `"status": "done"` even when checks fail; the failures belong in the `checks` array. Use `"status": "blocked"` only if you cannot run the checks at all.
````

## Finalize dispatch template

Write this to `plans/<slug>-finalize.md` for each phase, replacing the placeholders:

````markdown
You are the finalize step for one phase of an approved plan. Implementation and review for this phase are done. Phase baseline commit: <baseline>.

Run the document-and-commit skill, scoped to this phase only:
1. Stage this phase's work: `git add -A`.
2. Confirm `git diff --cached` contains only this phase's changes. If it contains changes from another phase or unrelated work, that is drift; stop and end with the blocked JSON block.
3. Write the developer documentation for this phase only, based on `git diff --cached` and this phase's report in `plans/<slug>-implementation-log.md`.
4. Stage the docs, then commit exactly once with a conventional message scoped to this phase. Never commit per milestone.

If the change set is empty (nothing staged), stop and end with the blocked JSON block. Do not fabricate docs.

End your final message with the same JSON block contract:

```json
{ "status": "done", "phase": "<label>", "summary": "<docs written and commit summary>" }
```
````

## Helper script

`pi-rpc.sh` ships next to this skill. Commands:

```bash
bash pi-rpc.sh <slug> start                 # start the RPC session
bash pi-rpc.sh <slug> run <prompt-file>     # send a prompt, wait for settled, print final text
bash pi-rpc.sh <slug> compact "<instr>"     # compact the session with custom instructions
bash pi-rpc.sh <slug> send '<json>'         # send a raw command (steer, abort, set_model)
bash pi-rpc.sh <slug> status                # running / not running
bash pi-rpc.sh <slug> stop                  # terminate and clean state
```

State lives under `${TMPDIR:-/tmp}/pi-orch-<slug>/`. The event stream is in `events.jsonl` there if you need to inspect tool calls.

## Rules

- You do not implement the plan's milestones yourself; you delegate them to the implementor. You do run the per-phase implementation review and fix critical issues it finds.
- Review judgment stays with you. Only the mechanical validate-and-test pass is delegated, and that pass is read-only: it reports results and never fixes what it finds.
- Treat the implementor as a junior/mid developer. Verify its work after each phase; never trust its self-assessment.
- On drift (the implementor did something wrong), halt and report to the CTO. Do not fix it yourself and do not continue until the CTO decides.
- Never advance past a blocked phase, a failed verify check, a malformed report, or detected drift.
- Do not guess the answer to a question that is a genuine judgment call. That is the one thing you escalate.
- Do not let the implementor silently resolve a plan-vs-codebase conflict; route it through the questions file.
- Answer the easy questions yourself. Asking the user about things you can decide wastes their time.
- One commit per phase (or per plan if unphased), at that phase's document-and-commit step. Never per milestone. If the implementor commits during implementation or review, halt all operations immediately. Do not retry, do not fix, do not continue. Report to the CTO.
- Compact the session before document-and-commit, on the same RPC session. Do not restart the process or the session.
- Keep the handoff files append-only. Never rewrite or renumber past entries.
- The plan file is the source of truth. The implementor never edits it; only you may append to its Decisions Log.
- The dispatch prompt's Frontend and Python sections go in every phase, unedited. The implementor decides whether the phase touches UI or Python and self-negates when it does not. You do not make that call, because misreading a phase as backend-only silently ships stock UI, and misreading it as frontend-only silently ships class-based Python.
- Check the report's "Frontend skills applied" and "Python skill applied" lines against the diff during the drift check. A phase that changed templates or `.py` files but reports "no UI in scope" or "no Python in scope" is a false report, not a judgment call.
- Report progress to the user in one line per phase. Reserve detail for the final summary.
