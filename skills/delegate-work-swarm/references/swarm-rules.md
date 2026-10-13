# Swarm rules

Shared by `delegate-work-swarm` and `orchestrate-implementation-swarm`. These rules decide
which agent gets each assignment, how parallel workers share one Git tree, and what happens
when a worker fails or an agent becomes unavailable. The orchestrator keeps all review.

`<skill-dir>` below is the `delegate-work-swarm` skill directory.

## Route by task level

Two questions decide an assignment's level: would a person finish it in under an hour, and
will a test, type check, or lint rule judge the result?

| Level | Typical work |
|---|---|
| Low | Short tasks with an automated check. Mechanical edits, renames, boilerplate that follows an existing pattern, lookups, summaries, running checks, requested doc edits. |
| Mid | Bounded features with a written spec and acceptance tests, UI work, tests for existing behavior, moderate refactors inside one known area, image generation. |
| Top | Long multi-step work, cross-cutting refactors, bugs with unknown cause, unclear specs, concurrency, and writing specs, interfaces, or failing tests for lower levels. |

- Pick the lowest level that fits. If torn between mid and top, pick top. If torn between low
  and mid and an automated check exists, pick low, because a failed cheap attempt is cheap.
- Spec first. A low or mid editing assignment needs an automated acceptance check. If none
  exists, either add an earlier Codex assignment that writes the failing test or interface,
  or route the assignment up.
- The user can set the agent for any assignment. That choice holds over these rules.

## Agent ranking

Codex > agy >= pi. pi's place depends on the model it runs, set by the table below.

### pi model ranks

Maintained by the user. Each row gives a pi model pattern (shell glob, matched against the
model id without its provider) one rank: `below` agy, `peer` of agy, or `above` agy (still
below Codex). A model with no matching row counts as `below`. The first matching row wins.

| pi model pattern | Rank |
|---|---|
| `glm*` | above |

### Level to agent

| Level | pi `below` | pi `peer` | pi `above` |
|---|---|---|---|
| Top | Codex | Codex | Codex |
| Mid | agy | agy or pi | pi |
| Low | pi | pi | pi |

- Between peers, pick by capability first, then by which agent is free, so parallel work
  spreads across both.
- If pi's model lacks a needed capability, low work goes to agy. If pi is unavailable, follow
  the unavailability rules below instead of re-routing on your own.

### Capabilities

An assignment that needs image input (screenshots, mockups, visual review) goes only to an
agent whose current model accepts images. For pi, run `pi --list-models <model>` and read
the `images` column of the row whose `provider` and `model` match exactly. The search is
fuzzy, so other rows can appear first. Several pi models are text-only. Image generation stays on agy
or Codex.

### Which model each agent runs

The ranking is the user's judgment, not a model guarantee. pi switches between open-weight
providers the user enables (DeepSeek, MiMo, Step, and others) and never runs Claude, GPT, or
Gemini models. Use whatever pi model the user has set: `PI_ORCH_MODEL` when set, otherwise
`defaultProvider` and `defaultModel` in `~/.pi/agent/settings.json`. Never pick one yourself.

## Pre-flight

Before the first wave, for each agent in the routing table:

| Agent | Login check | Model to record |
|---|---|---|
| Codex | `codex login status` | `model` in `~/.codex/config.toml`, or `CODEX_ORCH_MODEL` |
| agy | `agy models` (lists models without using prompt tokens) | `AGY_ORCH_MODEL` if set, otherwise "agy default" |
| pi | `pi auth check --provider <provider>` for the provider of the model in use | the model in use, its rank, and its `images` value from the exact row in `pi --list-models <model>` |

Also confirm each helper script exists:

- `<skill-dir>/../delegate-work-codex/codex-exec.sh`
- `<skill-dir>/../delegate-work-agy/agy-exec.sh`
- `<skill-dir>/../delegate-work-pi/pi-work.sh`

Record the results in `run-log.md`. Login checks prove login, not remaining quota. Do not
print credential files or secret values.

## Ownership and waves

`<skill-dir>/swarm-files.sh` does the bookkeeping. Run it from the project. Keep its state
directory outside the work tree.

- Each editing assignment gets `<handoff>/<id>.own`, one repo-relative path per line, a
  trailing `/` for a directory. It always lists the assignment's own handoff directory.
  Read-only assignments own only that handoff directory.
- The orchestrator gets `<handoff>/orchestrator.own` listing `run-log.md` and every `.own`
  file, so its own bookkeeping during a wave is never `UNOWNED`. Pass it to `attribute`
  along with the workers' files.
- Workers do not own test files unless the assignment is to write tests. An edit to a test
  file then shows up as cross-owner or `UNOWNED` and is reviewed as drift.
- Run `swarm-files.sh overlap <own-file>...` before dispatch. Assignments that overlap go to
  different waves. A file several assignments need (for example `package.json`) belongs to
  one assignment, or to the orchestrator between waves.
- Dependencies. An assignment may list `after: <ids>` in its `task.md`. It goes in a later
  wave than every assignment it depends on. A Codex spec assignment is always a dependency
  of the assignment it writes the spec for.
- Waves. Run `swarm-files.sh snapshot <state-dir>/wave-<n>` before each wave. Run at most 3
  workers at once (shortcut: fixed cap, raise it when rate limits allow). A wave ends when
  every assignment in it is accepted, escalated, held, or halted.
- Same-agent concurrency. Two sessions of the same agent may run at once, one slug each.
  If that ever fails for an agent, drop to one worker per agent at a time and note it here.

## Reviewing a worker during a wave

1. Run `swarm-files.sh attribute <state-dir>/wave-<n> <own-file>...` with every own-file in
   the wave.
   - Exit 3 (HEAD or index moved) is always drift.
   - Exit 2 means inspect each `UNOWNED` path. A generated test or build artifact is
     allowed. Any other edit is drift.
2. Compare the worker's reported `files` with the changed paths credited to it. A changed
   path the owner did not report, or a reported path it does not own, is a drift suspect.
   Leave the assignment's handoff directory out of this comparison; you write `answers.md`
   there and workers rarely list their work log.
   `attribute` cannot see worker A editing a file that worker B owns, because the path is
   still credited to B. Read that file's diff before accepting. When B also changed that
   file, this comparison cannot see A's edit either; reading B's full diff in step 4 is the
   only check.
3. Read the premise and plan the worker wrote to its work log before editing. Most agent
   failures start with a false premise.
4. Review only the worker's owned paths. Security-sensitive changes get an explicit security
   pass for every agent, plus the project's security scanner if it has one.
5. Other workers may be mid-edit, so a worker's own checks can fail on files it does not
   own. Workers report those failures and do not fix them. Project-wide checks (full test
   suite, build) run once at wave end, after every worker is idle. That result decides
   acceptance.
6. Treat every worker summary as a claim. Rerun checks yourself.

During a wave, route corrections through the owning worker with `resume`. Edit files
directly only between waves, before the next snapshot. The one exception is `restore`
during escalation.

## Classify every unsuccessful turn

All three helpers exit 1 for crashes, timeouts, and many rate limits and auth failures
alike, and a turn can also end with exit 0 and no final JSON. pi does this on a provider
error: it retries on its own, then settles with an empty reply, and its `events.jsonl`
holds assistant messages with `"stopReason": "error"` and an `errorMessage` such as
`429: ... quota exhausted`. Treat any turn without a final JSON block as unsuccessful. Read
the helper's stderr, `err.log`, and event stream before acting, using that agent's
troubleshooting reference.

| Class | Signs | Action |
|---|---|---|
| Unavailable | HTTP 429, quota or usage limit, expired or missing login, or the provider unreachable (DNS failure, connection errors to its API while other hosts resolve, a 5xx outage) | Unavailability rules below. Never counts toward escalation. |
| Environment | Helper error, idle timeout, flaky tool, malformed final JSON | One retry with the same agent (for malformed JSON, one resume asking for the report). If the retry fails, follow the agent's troubleshooting reference and report. Do not escalate. |
| Slip | A small in-scope defect the worker can fix | One correction `resume` with the same agent. If it fails, escalate. |
| Reasoning failure | Wrong premise, fixing the wrong problem, looping, a success claim your own checks disprove | Escalate at once. |

A `blocked` status for missing information is none of these. Answer it and resume.

## Escalation

- A failed slip correction goes to the next agent strictly above the current one that has
  the needed capabilities. A peer is not "above", so a peer skips to the next agent above
  both.
- A reasoning failure goes straight to Codex from any agent.
- At Codex, a reasoning failure or a failed slip correction halts the assignment and goes to
  the user.
- Never move work down without asking.

Escalation restarts the assignment. Do it before the next wave's snapshot, while the current
snapshot still describes the starting state:

1. Record the old session id, CLI version and path, and diagnostics in `run-log.md`.
2. Run the helper's `stop` (it deletes helper state) and confirm the worker has exited.
3. Run `swarm-files.sh restore <state-dir>/wave-<n> <own-file> <handoff>/<id>/partial`. It
   saves the attempt and returns the owned paths to the wave baseline. It never touches
   `.orchestrate/`, so the handoff records stay. Move the old `work-log.md` into `partial/`
   yourself.
4. Start the new worker under a new slug (`<run>-<id>-<attempt>`) with the original
   `task.md`, binding answers, and a short "verified facts" section you write. Do not give
   it the failed transcript, work log, or partial edits, and tell it not to read
   `partial/`, which sits in the same handoff directory. Strong models shown a weak attempt
   tend to repeat its mistakes.

## Unavailability

When a turn fails as unavailable:

- A rate limit that states a reset time of 60 seconds or less gets one wait and one retry of
  the same session. Do not stack retries on top of the CLI's own retry loop.
- Anything else (quota used up, expired login, a longer or unknown reset): hold that agent's
  assignments and every assignment that depends on them. Keep other workers running. Ask
  the user once per incident: log in again, wait and resume, move up, move down, or stop.
- For pi, also offer switching to another model in `enabledModels`, showing that model's
  rank and `images` value, since a switch can change pi's place in the ranking. Run
  `pi auth check` for the new provider before resuming, and re-route held work by the new
  rank.
- pi's providers never overlap with Codex or agy, so a pi limit does not hold Codex or agy
  work, and the reverse.
- Never change agent, model, or account without asking, even where an agent's
  troubleshooting reference suggests switching models.
- Keep the interrupted worker's edits in place. If the work moves to another agent, save the
  owned changes to `partial/` first (copy them; do not run `restore`), copy the session id
  and diagnostics before `stop`, and confirm the old worker has exited before a new one
  starts on the same files. The edits stay because the worker did not fail on the task.
- Held assignments block wave acceptance and any dependent work until resolved.

## Drift halt

Drift includes an `UNOWNED` source edit, a moved HEAD or index, a confirmed cross-owner
edit, scope expansion, damage to pre-existing work, a security violation, fabricated
verification, and source edits during verification.

- Stop the drifting worker's helper. Let other workers finish their current turn, but do not
  resume them or start new assignments.
- If the drift cannot be pinned to one worker (exit 3, or an `UNOWNED` source edit), stop
  every worker in the wave.
- Report to the user with concrete evidence, naming the agent and its model. Do not
  automatically revert files or continue the affected work until the user decides.

## Helpers

| Agent | Helper | Commands |
|---|---|---|
| Codex | `<skill-dir>/../delegate-work-codex/codex-exec.sh` | `new`, `resume`, `thread`, `stop` |
| agy | `<skill-dir>/../delegate-work-agy/agy-exec.sh` | `new`, `resume`, `conversation`, `stop` |
| pi | `<skill-dir>/../delegate-work-pi/pi-work.sh` | `new`, `resume`, `compact`, `session`, `stop` |

Use one slug per assignment: `<run>-<id>`, or `<run>-<id>-<attempt>` after escalation. Each
helper keeps state under `${TMPDIR:-/tmp}/<agent>-work-<slug>/`. Copy `cli-version.txt` and
`cli-path.txt` into the assignment's work log after each turn, before `resume` or `stop`
overwrites or removes them.
