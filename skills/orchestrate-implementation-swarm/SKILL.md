---
name: orchestrate-implementation-swarm
description: "Implement an existing approved plan phase by phase with a swarm of Codex, agy, and pi workers. Inside each phase, milestones are routed by task level and the user's agent ranking (Codex > agy >= pi, pi's place set by its model) and independent milestones run in parallel; phases stay in plan order. Requires a readable approved plan before any execution. Use for 'implement the plan with the swarm', 'orchestrate this plan across codex, agy and pi', or 'run the plan in parallel'. For a direct task or when no plan is available, use delegate-work-swarm instead. Drift halts with a CTO report. Leaves all work uncommitted and writes no feature documentation. Requires Git and at least one of the codex, agy, or pi CLIs."
---

# Orchestrate implementation (swarm)

You are the orchestrator. You do not write the phase code yourself. You split each phase of
an approved plan into assignments, route each to Codex, agy, or pi, run independent ones in
parallel, and review every phase yourself. You are the only bridge between the workers and
the user.

Read [swarm rules](../delegate-work-swarm/references/swarm-rules.md) before the first
assignment. It holds routing, ownership and waves, failure classes, escalation,
unavailability, and drift rules. This skill adds the plan gate, the phase loop, and the
phase review on top of the procedure in
[delegate-work-swarm](../delegate-work-swarm/SKILL.md).

This skill stops at review. It does not write documentation and never commits. The whole
run lands in the working tree for the user to inspect, and they decide when to run
`document-and-commit`.

## Inputs and plan gate

- An existing approved plan at `plans/<slug>.md` (written by plan-feature, reviewed by
  plan-review).
- The target project is the current working directory, inside a Git repository.
- Optional: a phase to start from, or an agent override for specific milestones.

Resolve the plan before checking CLIs, creating handoff files, taking snapshots, starting a
worker, or editing project files. Use approval already established in the conversation.

- If the request is a direct task without an instruction to implement a plan, recommend
  `delegate-work-swarm`. An unrelated `plans/` folder does not change that routing.
- If a plan path is supplied, verify that exact file exists and can be read. If it is
  missing or unreadable, report the path problem. Do not substitute another plan.
- If the request asks for plan implementation without a path, discover plan files only when
  `plans/` exists (`ls plans/*.md 2>/dev/null`), keep actual implementation plans, and ask
  which one to use if several qualify.
- If no plan is available, stop and recommend `delegate-work-swarm` with the original task
  and constraints. Do not invent phases.
- If the project is not a Git repository with at least one commit, stop and recommend
  `orchestrate-implementation-<agent>` for a single agent. The swarm's snapshots need Git.

## Step 1: Map phases and milestones

Read the plan, including its review log. Build an ordered list of phases, each with its
milestones.

- **Metadata block present** (`## Metadata` with `phased` and `phases`): use it directly.
- **Heading-based**: a phase is a heading containing `Phase`, a milestone is a heading
  containing `Milestone N`, and each milestone belongs to the nearest phase heading above
  it. With no phase headings, the whole plan is one phase.

Inside each phase, find milestone dependencies: a milestone that uses a file, function, or
result another milestone in the same phase creates gets `after:` on that milestone. When in
doubt, add the dependency; a wrong `after:` costs time, a missing one breaks a wave.

Record the map in `run-log.md`. Do not re-derive it mid-run.

## Step 2: Set up the run

Do these once.

1. Run pre-flight from the rules file for every agent the run may use, and record the
   results, including each agent's model and pi's rank and image support. Then draft the
   routing for every phase (Step 3.2) and show it to the user as one table. Wait for one
   confirmation for the whole run, unless the request says to proceed without asking.
2. Create the handoff tree from delegate-work-swarm under `.orchestrate/<run>/`, plus
   `.orchestrate/<run>/implementation-log.md`, written only by you and listed in
   `orchestrator.own`. Commit `.orchestrate/` with the work later if the user wants the run
   record; never commit it yourself.
3. Record `git rev-parse HEAD`. Nothing is committed during the run, so any change to it is
   drift.
4. Resolve blockers before the first dispatch. Read the plan for anything a worker cannot do
   non-interactively: external accounts, credentials, physical devices, recordings, writes
   outside the project. Ask all of them in one question to the user, and record each answer
   as `A<n>` in every affected assignment's `answers.md`.

Do not modify `plans/<slug>.md`. It is the source of truth.

## Step 3: Phase loop

For each phase, in order:

1. **Phase baseline.** Record `git stash create` (or `git rev-parse HEAD` when it prints
   nothing) and the untracked file list. This scopes the phase review to this phase.
2. **Assignments.** Split the phase's milestones into assignments, usually one per
   milestone, merging milestones that edit the same files. For each, set level, agent,
   ownership, acceptance checks (the milestone's `→ Verify:` lines), and `after:`. Use the
   routing confirmed in Step 2. If a phase's split or agents must change (for example after
   an unavailability decision), show the changed rows and wait for confirmation again.
3. **Waves.** Run the phase's assignments in waves exactly as delegate-work-swarm steps 3 to
   5 describe: snapshot, dispatch, answer questions, review each worker, close the wave
   with project-wide checks, escalate before the next snapshot.
4. **Drift check against the plan.** Worker reports are claims. On top of the rules file's
   drift list, check for skipped plan steps, contradicted Decisions Log entries, convention
   violations, stubs or placeholders reported as finished work, modules nothing imports,
   and silent behavior changes the plan does not call for. Grep for the plan's hard rules
   directly.
5. **Phase review.** Review the phase yourself with the implementation-review skill. Scope
   is this phase only: `git diff <phase baseline>` plus untracked files that appeared since
   step 1. Apply critical fixes yourself, between waves. Then run the validate checks
   (the phase's `→ Verify:` commands and the project's tests) yourself, or resume one
   worker with its verification prompt; a verification turn may not edit source. Carry
   "Issues Reported (not auto-fixed)" to the finish step.
6. **Run it.** When the phase ships an app, launch it and drive the phase's core flow
   (`run-expo-android` for Expo or React Native, the project's run instructions or the `run`
   skill otherwise). Record what was and was not verified on the running app.
7. **Log the phase.** Append to `implementation-log.md`: milestones done, assignment, level,
   agent and model for each, escalations, holds, review result, checks run.
8. Relay one line of progress to the user, then start the next phase with a fresh baseline
   and fresh worker sessions.

## Step 4: Resolve worker questions

For each new question in an assignment's `questions.md`, answer it yourself when the plan,
the project conventions, established practice with no real tradeoff, or an existing code
pattern settles it. Otherwise ask the user, with the options and your recommendation.

Write each answer to that assignment's `answers.md` before resuming:

```
### A<n> (Q<n>)
Answer: <the decision, stated as an instruction>
Rationale: <one line>
```

Number questions per assignment. When an answer affects other assignments or later
phases, record it in `implementation-log.md` too, since later workers start fresh.

## Step 5: Drift halt and CTO report

When the rules file or Step 3.4 finds drift, halt as the rules file says. Do not fix the
mistake yourself and do not let the worker keep going. A deviation that is clearly better
and stays within the plan's goal is not drift; note it and surface it at the end.

Present this report and wait for the user (the CTO):

```
## CTO report

**Incident**: <phase>, <milestone(s)>, assignment <id>
**Agent and model**: <agent>, <model>, rank <rank>
**What the worker did wrong**: <concrete, with file:line or diff evidence>
**Why it is wrong**: <against plan step X, scope, convention, or security>
**Reported vs actual**: <what the worker claimed vs what you verified>
**Impact**: <what breaks or what rework is at risk>
**Options**:
1. <option A>, <tradeoff>
2. <option B>, <tradeoff>
**My recommendation**: <which option, one line why>
```

Record the report and the user's decision in `implementation-log.md`.

## Step 6: Finish

After the last phase is reviewed:

1. Stop every helper after copying diagnostics you still need, and delete the run's
   `prompt.md` files.
2. Read the whole `implementation-log.md`.
3. Run `git status --porcelain` and confirm the dirty tree holds the plan's work, the handoff
   records, and nothing else.
4. Summarize: phases completed, assignments per agent, escalations and holds, key files,
   review results, and questions answered by you versus the user.
5. List the review's "Issues Reported (not auto-fixed)" items verbatim and ask whether to fix
   any.
6. State that nothing was committed and no docs were written. Offer `document-and-commit`;
   do not run it unless the user asks.

## Dispatch prompt

Use the assigned agent's dispatch prompt and the ownership block exactly as
delegate-work-swarm describes, and add this block for plan work:

````markdown
This assignment implements part of an approved plan.
Plan: <absolute path to plans/<slug>.md> (read it, including its review log)
Phase: <label>. Your milestones: <numbers and names>.
Implementation log: <absolute path> (read it for earlier phases; do not edit it)
Implement only your milestones. Run each milestone's `→ Verify:` checks and report them.
Do not change the plan file.
````
