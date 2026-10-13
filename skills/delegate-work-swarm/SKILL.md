---
name: delegate-work-swarm
description: "Split a direct task into assignments and run them in parallel on Codex, agy, and pi, routing each by task level and the user's agent ranking (Codex > agy >= pi, pi's place set by its model), then independently review every result. Takes scope from the user's request without a plans/ folder. Use when asked to 'swarm this', 'delegate to the swarm', 'split this across codex, agy and pi', or 'run these in parallel on codex, agy and pi', including fixes, refactors, investigations, and discussion. Requires Git for parallel edits and at least one of the codex, agy, or pi CLIs. For phase-by-phase implementation of an approved plan, use orchestrate-implementation-swarm instead. For a single assignment on one agent, use delegate-work-codex, delegate-work-agy, or delegate-work-pi."
---

# Delegate work to the swarm

You are the orchestrator. Split the user's request into assignments, give each one to the
agent that fits, run independent assignments at the same time, and review everything they
produce. You do not hand review to a worker.

Read [swarm rules](references/swarm-rules.md) before the first assignment. It holds the
routing tables, the ownership and wave rules, failure classes, escalation, and what to do
when an agent hits a usage limit or an expired login. This file is the procedure; the rules
file is the reference.

Route to `orchestrate-implementation-swarm` only when the request is to implement an
existing approved plan. If the request is one bounded assignment, use the single-agent
`delegate-work-<agent>` skill instead; a swarm adds bookkeeping that one assignment does
not need.

Leave changes uncommitted. Do not stage, commit, publish, or run document-and-commit.
Never bypass a sandbox or widen permissions to get a check to pass.

## 1. Define the work

Read the request, the project's instructions, and enough of the code to scope it. Write a
brief with the expected result, scope and exclusions, constraints, acceptance criteria, and
confirmed file paths.

Split the brief into assignments only where pieces are separately reviewable. For each one,
decide:

- its level (low, mid, top) and agent, from the rules file;
- the files and directories it owns;
- its acceptance checks, and whether it is read-only;
- `after: <ids>` for anything it depends on, including a Codex spec assignment when a low or
  mid editing assignment has no automated check.

Run pre-flight from the rules file for every agent you plan to use, and record the results.
Then show the user a routing table and wait for one confirmation per run, so they can
change agents before money is spent. Skip the wait only when the request already says to
proceed without asking.

```
| Assignment | Level | Agent | Why | Owns | Wave | After |
pi model: <provider/model>, rank <below|peer|above>, images <yes|no>
```

## 2. Prepare the handoff and baseline

Choose a run slug of lowercase letters, digits, and hyphens, unique across active projects,
such as `search-fixes-20261013-01`. Create:

```
.orchestrate/<run>/
  run-log.md               orchestrator only: pre-flight, routing, sessions, outcomes
  orchestrator.own         run-log.md and every .own file
  <id>.own                 one per assignment
  <id>/task.md             brief, assignment, acceptance checks, after:
  <id>/questions.md        appended by the worker
  <id>/answers.md          appended by you
  <id>/work-log.md         appended by the worker
  <id>/prompt.md           scratch, overwritten each turn
```

When every assignment is read-only, put this tree in a temporary directory instead so the
project stays untouched. Keep `swarm-files.sh` state under
`${TMPDIR:-/tmp}/swarm-<run>/`, outside the work tree.

Swarm runs need Git for parallel edits. Outside Git, run editing assignments one at a time
with the single-agent baseline from `delegate-work-<agent>`, and run read-only ones in
parallel.

Run `swarm-files.sh overlap` on every `.own` file and plan waves so that overlapping or
dependent assignments land in different waves. Never stash, reset, or clean the user's tree.

## 3. Dispatch a wave

1. Run `bash <skill-dir>/swarm-files.sh snapshot ${TMPDIR:-/tmp}/swarm-<run>/wave-<n>`.
2. For each assignment in the wave (at most 3 workers at once), write its dispatch prompt to
   `<id>/prompt.md` and start its helper with `new` in the background, using the host's
   asynchronous execution. Do not invent background flags.
3. When a turn ends, read its final JSON block and copy `cli-version.txt`, `cli-path.txt`,
   and any usage counters into the assignment's work log.
4. For `blocked`, answer in that assignment's `answers.md` with numbered `A<n>` entries
   matching its `Q<n>`, ask the user when a material decision remains, then `resume` that
   worker only.
5. For a failed or missing turn, classify it with the rules file before any retry,
   escalation, or hold.

Keep the user posted as workers finish. Never report a pending worker's result.

## 4. Review each worker

Follow "Reviewing a worker during a wave" in the rules file: run `attribute` with every
own-file in the wave, compare reported and credited files, read the worker's stated premise,
and review only its owned paths. Use implementation-review for code changes when its
prerequisites are present, reviewing against the brief. For discussion or investigation,
verify cited evidence instead.

Then accept, correct through a bounded `resume`, or escalate per the rules file. For
mechanical verification, `resume` with that agent's verification prompt, and compare
`attribute` output before and after; verification permits test and build artifacts only.

Halt for drift as the rules file says. Do not keep the wave going around an incident.

## 5. Close the wave

When every worker in the wave is idle:

1. Run the project-wide checks (full test suite, build, the affected runtime flow when
   available). Read the output. This result decides acceptance; worker reports do not.
2. Run `attribute` once more. Any new `UNOWNED` source edit is drift.
3. Escalate any failed assignment now, before the next snapshot, so `restore` still has the
   right baseline.
4. Make orchestrator edits only now, between waves.
5. Record the wave outcome in `run-log.md`, then start the next wave.

Held assignments (unavailable agent) block acceptance of their wave and any dependent work
until the user decides.

## 6. Finish

1. Run each helper's `stop` after copying any diagnostics you still need.
2. Delete this run's `prompt.md` files. Keep the briefs, logs, and `partial/` directories.
3. Run `git status --porcelain` and account for every change against the run baseline,
   including the handoff records.
4. Report per assignment: level, agent and model, escalations, checks actually run, and
   pending items. List anything held or halted, and why.
5. State that all changes remain uncommitted.

## Dispatch prompt

Use the dispatch prompt from the assigned agent's own skill, unchanged, so agent-specific
rules (agy image copying, pi compaction) still apply:

- Codex: [delegate-work-codex](../delegate-work-codex/SKILL.md#dispatch-prompt)
- agy: [delegate-work-agy](../delegate-work-agy/SKILL.md#dispatch-prompt)
- pi: [delegate-work-pi](../delegate-work-pi/SKILL.md#dispatch-prompt)

Fill it with the assignment's paths, then add this block before the response contract:

````markdown
You are one of several workers editing this project at the same time.
Ownership: <absolute path to <id>.own>
Edit only paths listed in the ownership file. If you need another file, append a question
and end blocked. Do not edit test files unless the ownership file lists them.
Before editing, append your premise (what you believe is wrong or needed, and why) and your
plan to the work log.
Other workers may leave files half-edited while you run checks. Report failures in files
you do not own, and do not fix them.
````

For an escalated worker, also add: "Do not read the partial/ directory in your handoff
folder." For verification turns, use the same agent's verification prompt.
