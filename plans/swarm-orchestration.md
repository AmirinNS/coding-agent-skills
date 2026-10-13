# Plan: Swarm orchestration across Codex, agy, and pi

## Goal
Let one orchestrator split work into several assignments and run them at the same time on
Codex, agy, and pi, picking the agent for each assignment by difficulty. Two skills cover the
two existing inputs: `delegate-work-swarm` for direct tasks and
`orchestrate-implementation-swarm` for approved plans. The orchestrator keeps all review.

## Scope
- In scope:
  - A rubric that routes each assignment by task level to Codex, agy, or pi (ranked
    Codex > agy >= pi, with pi's place set by the model it runs), with
    classified failures, upward escalation, per-assignment user override, and handling for
    agents that hit usage limits or expired logins.
  - Parallel dispatch with disjoint file ownership, enforced after the fact by a small Git helper.
  - `delegate-work-swarm` (direct tasks and discussion) and `orchestrate-implementation-swarm`
    (approved plans, phase by phase, assignments inside a phase run in parallel).
  - README and `docs/delegation.md` entries, and `~/.claude/skills` symlinks.
- Out of scope:
  - Claude subagents as a fourth tier. Add when the user asks for it.
  - Git worktrees or merging branches back.
  - Parallel editing outside Git. Without Git, editing assignments run one at a time.
  - Changes to the existing single-agent skills or their helper scripts.
  - Model overrides per agent. The helpers' existing env vars still work if the user asks.

## Approach

### Phase A: delegate-work-swarm (ships on its own)

<!-- milestone:1 -->
### Milestone 1: Ownership helper with a runnable check
1. Create `skills/delegate-work-swarm/swarm-files.sh` with five commands, all run from the
   project root:
   - `snapshot <state-dir>` writes `head.txt` (`git rev-parse HEAD`), `index.txt`
     (`git ls-files -s | shasum -a 256`), and `dirty.tsv` (path and `git hash-object` result,
     or `absent`, for every entry in `git status --porcelain=v1 -z -uall --no-renames`).
     It also copies each dirty file that exists into `<state-dir>/files/<path>`, so `restore`
     can return it to its wave-start content. Exits 1 when there is no Git repo or no HEAD.
   - `changed <state-dir>` exits 3 and prints `HEAD moved` or `index changed` when either
     differs from the snapshot. Otherwise it takes the union of `dirty.tsv` paths and current
     status paths, and prints each path whose current content hash differs from its baseline
     hash. Baseline hash is the `dirty.tsv` value, else `git rev-parse -q --verify HEAD:<path>`,
     else `absent`.
   - `overlap <own-file>...` reads ownership files (one repo-relative path per line, a
     trailing `/` marks a directory). Prints every conflicting pair (equal paths, or one a
     prefix directory of the other) and exits 1 if any exist.
   - `attribute <state-dir> <own-file>...` runs `changed`, then prints `<assignment>\t<path>`
     for each changed path, using `UNOWNED` when no file claims it. The assignment id is the
     own-file basename without `.own`. Exits 2 if any path is `UNOWNED`, and passes through
     exit 3 from `changed`.
   - `restore <state-dir> <own-file> <save-dir>` takes the changed paths inside that
     ownership, copies their current content (or a `deleted` marker) into `<save-dir>`, then
     returns each one to its snapshot state: the copy in `files/` for a file dirty at snapshot
     time, `git restore --source=HEAD --worktree -- <path>` for a file clean at snapshot time
     (worktree only, with Git's checkout filters applied), and removal for a file
     absent at snapshot time. It never touches paths outside the ownership file and never
     touches the index. It ends by running `changed` and exits 1 if any owned path still
     differs from the snapshot.
2. Create `skills/delegate-work-swarm/tests/test-swarm-files.sh`. It builds a temp Git repo
   under `${TMPDIR:-/tmp}` and asserts these cases:
   - a clean edit is attributed to its owner;
   - an edit to a file that was already dirty at snapshot time is detected;
   - a new untracked file inside an owned directory is attributed;
   - a file nobody owns gives `UNOWNED` and exit 2;
   - a deleted tracked file is detected;
   - `overlap` catches `src/` against `src/a.py` and passes on disjoint sets;
   - a commit after the snapshot gives exit 3;
   - a path containing spaces is attributed correctly;
   - `restore` returns an edited file that was already dirty at snapshot time to its
     wave-start content, not to HEAD;
   - `restore` restores a clean file from HEAD, removes a new untracked file, and recreates
     a deleted file;
   - `restore` leaves a changed file outside the ownership untouched, saves every restored
     path into the save directory, and leaves the index hash unchanged.
3. Run `bash skills/delegate-work-swarm/tests/test-swarm-files.sh` before writing the helper
   body. Expect it to fail. Write the body, run again, and expect all cases to pass.
→ Verify: test script exits 0 and prints one PASS line per case.

<!-- milestone:2 -->
### Milestone 2: Routing and ownership rules
1. Create `skills/delegate-work-swarm/references/swarm-rules.md`, shared by both swarm skills.
   It holds:
   - Route by horizon and checkability first, then by category. Two questions decide the task
     level: would a person finish this in under an hour, and will a test, type check, or lint
     rule judge the result?
     - Low: short tasks with an automated check. Mechanical edits, renames, boilerplate
       following an existing pattern, lookups, summaries, running checks, requested doc edits.
     - Mid: bounded features with a written spec and acceptance tests, UI work, tests for
       existing behavior, moderate refactors inside one known area, image generation.
     - Top: long multi-step work, cross-cutting refactors, bugs with unknown cause, unclear
       specs, concurrency, and writing specs, interfaces, or failing tests for lower levels.
   - Agent ranking. Codex > agy >= pi, where pi's place depends on the model it runs. A
     "pi model ranks" table in this file, maintained by the user, gives each pi model pattern
     one rank: `below` agy, `peer` of agy, or `above` agy (still below Codex). Seed it with
     `glm*` as `above`. An unlisted model counts as `below`, and the routing table says so.
   - Level to agent, for this run's pi rank:
     - Top goes to Codex.
     - Mid goes to pi when pi is `above`, to agy when pi is `below`, and to either when pi is
       a `peer`. Between peers, pick by capability first, then by which agent is free, so
       parallel work spreads across both.
     - Low goes to pi. If pi's model lacks a needed capability, low goes to agy. If pi is
       unavailable, follow the unavailability rules instead of re-routing on its own.
   - Capabilities. An assignment that needs image input (screenshots, mockups, visual review)
     goes only to an agent whose current model accepts images. For pi, read the `images`
     column of `pi --list-models <model>`; several pi models are text-only (some MiMo, Step
     3.5, DeepSeek v4 Pro, and GLM text models). Image generation stays on agy or Codex.
   - Spec first. A low or mid editing assignment needs an automated acceptance check. If none
     exists, either add an earlier Codex assignment that writes the failing test or interface,
     or route the assignment up.
   - Pick the lowest level that fits. If torn between mid and top, pick top. If torn between
     low and mid and an automated check exists, pick low, because a failed cheap attempt is
     cheap.
   - The user can set the agent for any assignment, and that choice holds over the rubric.
   - The ranking is the user's judgment, not a model guarantee. At pre-flight, record the model
     each CLI is configured to run in `run-log.md`, from its own config or status output.
     pi switches between open-weight providers (DeepSeek, MiMo, Step, and others the user
     enables) and never runs Claude, GPT, or Gemini models. The swarm uses whatever pi model
     the user has set (`PI_ORCH_MODEL`, else `defaultProvider` and `defaultModel` in
     `~/.pi/agent/settings.json`) and never picks one itself. Pre-flight records pi's model,
     its rank from the table, and whether it accepts images, and the routing table shows all
     three.
   - Test files. Workers do not own test files unless the assignment is to write tests. An
     edit to a test file then shows up as cross-owner or `UNOWNED` and is reviewed as drift.
   - Security. Security-sensitive changes get an explicit security pass in review for every
     agent, plus the project's security scanner if it has one. Rank alone is not a control.
   - Classify every unsuccessful turn before acting. Read the helper's stderr, `err.log`, and
     event stream, because all three helpers exit 1 for crashes, timeouts, rate limits, and
     auth failures alike.
     - Unavailable (rate limit, quota, expired login): follow the unavailability rules below.
       It never counts toward escalation.
     - Environment (helper error, idle timeout, flaky tool): one retry with the same agent. If
       the retry fails, follow that agent's troubleshooting reference and report. Do not
       escalate, because a broken tool says nothing about task difficulty.
     - Slip (a small in-scope defect the worker can fix): one correction `resume` with the same
       agent. If the correction fails, escalate.
     - Reasoning failure (wrong premise, fixing the wrong problem, looping, a success claim the
       orchestrator's own checks disprove): escalate at once.
     - A `blocked` status for missing information is none of these. Answer it and resume.
   - Escalation targets follow this run's ranking. A failed slip correction goes to the next
     agent strictly above the current one that has the needed capabilities. A peer is not
     "above", so a peer skips to the next agent above both. A reasoning failure goes straight
     to Codex from any agent. At Codex, a reasoning failure or a failed slip correction halts
     the assignment and goes to the user. Never move down without asking.
   - Escalation restarts the assignment. Do it before the next wave's `snapshot`, while the
     current snapshot still describes the starting state. In this order:
     1. Record the old session id, CLI version, and diagnostics in `run-log.md`.
     2. Run the helper's `stop` (it deletes helper state) and confirm the worker has exited.
     3. Run `restore` for the failed worker's owned paths. It saves the attempt to `partial/`
        in that handoff directory and returns those paths to the wave baseline. Move the old
        `work-log.md` into `partial/` as well. This is the one orchestrator edit allowed
        mid-wave, because it touches only that ownership and only returns paths to the
        snapshot.
     4. Start the new worker under a new slug (`<run>-<id>-<attempt>`) with the original
        `task.md`, binding answers, and a short
        "verified facts" section written by the orchestrator. It does not get the failed
        transcript, work log, or partial edits, because strong models shown a weak attempt
        repeat its mistakes.
   - Dependencies. An assignment may list `after: <ids>` in its `task.md`. It goes in a later
     wave than every assignment it depends on. A Codex spec assignment is always a dependency
     of the assignment it writes the spec for.
   - Unavailability. Pre-flight before the first wave, for each agent in the routing table:
     `codex login status`, `pi auth check --provider <provider>` (the `defaultProvider` in
     `~/.pi/agent/settings.json`, or the provider in `PI_ORCH_MODEL` when set), and
     `agy models`. These prove login, not remaining quota. When a turn
     fails as unavailable:
     - A rate limit that states a reset time of 60 seconds or less gets one wait and one retry
       of the same session. Do not stack retries on top of the CLI's own retry loop.
     - Anything else (quota used up, expired login, longer or unknown reset): hold that
       agent's assignments and every assignment that depends on them. Keep other workers
       running. Ask the user once per incident: log in again, wait and resume, move up, move
       down, or stop. For pi, also offer switching pi to another model in `enabledModels`,
       showing that model's rank and image support, since a switch can change pi's place in
       the ranking. Run `pi auth check` for the new provider before resuming, and re-route
       held work by the new rank.
     - pi's providers never overlap with Codex or agy, so a pi limit does not hold Codex or agy
       work, and the reverse.
     - Never change agent, model, or account without asking, even where an agent's
       troubleshooting reference suggests switching models.
     - Keep the interrupted worker's edits in place. If the work moves to another agent, save
       `partial/` first, copy the session id and diagnostics before `stop` (which deletes
       helper state), and confirm the old worker has exited before a new one starts on the
       same files. Unlike a reasoning-failure escalation, the edits stay, because the worker
       did not fail on the task.
     - Held assignments block wave acceptance and any dependent work until resolved.
   - Ownership. Each editing assignment gets `<handoff>/<id>.own` listing its files and
     directories, plus its own handoff subdirectory. Read-only assignments own only their
     handoff subdirectory. Run `overlap` before dispatch. Overlapping assignments go to
     different waves. A file every assignment needs (for example `package.json`) belongs to
     one assignment or to the orchestrator between waves.
   - Waves. Take a `snapshot` before each wave. Run at most 3 workers at once
     (`shortcut: fixed cap, raise when rate limits allow`). A wave ends when every assignment
     in it is reviewed, escalated, or halted. Run `attribute` before each worker's review and
     at wave end.
   - Reading `attribute`. Exit 3 (HEAD or index moved) is always drift. Exit 2 means inspect
     each `UNOWNED` path: a generated test or build artifact is allowed, any other edit is drift.
   - Cross-owner edits. `attribute` cannot see worker A editing a file that worker B owns,
     because the path is still credited to B. For each worker, compare its reported `files`
     with the changed paths credited to it. A changed path the owner did not report, or a
     reported path it does not own, is a drift suspect. Read that file's diff before accepting.
   - Checks during a wave. Other workers may be mid-edit, so a worker's own checks can fail on
     files it does not own. Workers report those failures and do not fix them. Project-wide
     checks (full test suite, build) run once at wave end, after every worker is idle, and
     that result decides acceptance.
   - Drift halt. Stop the drifting worker's helper. Let other workers finish their current
     turn, but do not resume them or start new assignments. If the drift cannot be pinned to
     one worker (exit 3, or an `UNOWNED` source edit), stop every worker in the wave. Then
     report to the user, naming the agent and its model.
   - Orchestrator edits. During a wave, route corrections through the owning worker with
     `resume`. Edit files directly only between waves, before the next `snapshot`. The one
     exception is `restore` during escalation. This keeps the reported-versus-changed
     comparison clean.
   - Same-agent concurrency. If the smoke run shows an agent cannot run two sessions at once
     in one project, the rule becomes one worker per agent at a time, and this file says so.
   - Helper paths. Dispatch through the existing sibling scripts
     `../delegate-work-codex/codex-exec.sh`, `../delegate-work-agy/agy-exec.sh`, and
     `../delegate-work-pi/pi-work.sh`, one slug per assignment (`<run>-<id>`). Check that each
     needed script exists before the first wave.
→ Verify: every helper path named in the file exists (`ls` each); `codex login status`,
  `pi auth check --help`, `pi --list-models`, and `agy models` each run; the ranks table holds
  exactly one seed row (`glm*`, `above`); each level names its agent for all three pi ranks.

<!-- milestone:3 -->
### Milestone 3: delegate-work-swarm SKILL.md
1. Create `skills/delegate-work-swarm/SKILL.md`. Frontmatter description names triggers
   ('swarm this', 'delegate to the swarm', 'split this across codex, agy and pi', 'run these
   in parallel') and points plan implementation to `orchestrate-implementation-swarm`.
2. Body sections, following `skills/delegate-work-codex/SKILL.md` but shorter:
   1. Define the work. Write the brief, split it into assignments only where pieces are
      separately reviewable, give each a level, an agent, ownership, and acceptance checks.
      Show the routing table (assignment, level, agent, why, owned files, wave, plus pi's
      model, rank, and image support) and wait for one confirmation per run, so the user can
      override agents before money is spent. Skip the wait when the
      request already says to proceed without asking.
   2. Prepare handoff. `.orchestrate/<run>/<id>/` per assignment with `task.md`,
      `questions.md`, `answers.md`, `work-log.md`, `prompt.md`, plus `<id>.own`. Run-level
      `run-log.md` written only by the orchestrator. When every assignment is read-only, put
      the handoff tree in a temp directory instead, as the `delegate-work-*` skills do, so the
      project stays untouched.
   3. Dispatch a wave. Start each worker with its helper in the background. Read each final
      JSON when its turn ends. Answer `blocked` questions in that assignment's `answers.md`
      and resume that worker only.
   4. Review each worker. Run `attribute`, review only its owned paths, then correct,
      escalate, or accept per `references/swarm-rules.md`.
   5. Finish. Stop every helper, compare `git status --porcelain` with the run baseline, and
      report per assignment: level, agent used, escalations, checks run, pending items. Leave all work
      uncommitted.
3. For each worker, use that agent's own dispatch prompt and verification prompt from
   `../delegate-work-<agent>/SKILL.md` (they carry agent-specific rules such as agy image
   copying and pi compaction), adding one line: "Edit only paths listed in <own-file>. If you
   need another file, end blocked and ask. Before editing, append your premise and plan to
   the work log." The orchestrator reads that premise during review, since most agent
   failures start with a false premise. All three share the same done/blocked JSON
   contract. For helper or CLI failures, follow that agent's troubleshooting reference and
   copy `cli-version.txt` and `cli-path.txt` into the assignment's work log, as the single-agent
   skills require.
→ Verify: dry run in a scratch Git repo (Milestone 4).

<!-- milestone:4 -->
### Milestone 4: Smoke run
1. In a scratch Git repo under the session scratchpad, create two small Python files and ask
   the swarm for two disjoint edits plus one read-only question, so that pi, agy, and Codex
   each get one assignment in one wave.
2. Confirm all three ran at once, each report parsed, `attribute` gave no `UNOWNED`, and the
   final summary lists the agent for each assignment.
3. Repeat with a deliberate overlap and confirm the two assignments land in different waves.
4. Run two agy assignments and two pi assignments at once in the same repo. Confirm each
   session keeps its own id and output. If either agent fails, apply the same-agent fallback
   rule in `swarm-rules.md`.
5. Plant one cross-owner edit (tell one worker to also touch another's file) and confirm the
   reported-versus-changed comparison flags it.
6. Put a stub `agy` first on `PATH` that prints a quota-exhausted 429 error and exits 1.
   Confirm the orchestrator classifies it as unavailable, does not count it toward
   escalation, holds that assignment, keeps the other workers running, and asks the user.
7. Give pi a short assignment with a strict acceptance test that a low-ranked model may get
   wrong (for example a validating parser). If pi fails it on reasoning, confirm the failure
   goes straight to Codex. If pi passes, force the escalation and label it forced in the
   notes. Either way confirm that `restore` returns the owned files to the wave
   baseline with the attempt saved under `partial/`, and the Codex prompt carries the original
   brief without the pi transcript.
8. Set pi to a text-only model and include an assignment that needs a screenshot. Confirm it
   goes to agy. Then add the pi model to the ranks table as `above`, confirm a mid-level
   assignment goes to pi, and remove that row again so the table keeps only the user's
   entries.
→ Verify: notes from every run appended to `docs/research.md`.

### Phase B: orchestrate-implementation-swarm (starts after Phase A smoke passes and the user confirms)

<!-- milestone:5 -->
### Milestone 5: orchestrate-implementation-swarm SKILL.md
1. Create `skills/orchestrate-implementation-swarm/SKILL.md`. Copy the plan gate, phase
   baseline (`git stash create`), drift list, CTO report, and finish steps from
   `skills/orchestrate-implementation-codex/SKILL.md`, replacing Codex-specific wording.
2. Change the phase loop. For each phase, split its milestones into assignments, route each by
   `../delegate-work-swarm/references/swarm-rules.md`, run waves inside the phase, then run
   one implementation-review over the whole phase. Phases stay in plan order. A milestone
   that builds on another milestone in the same phase gets `after:` and runs in a later wave.
3. The CTO report adds `Agent and model` so the user sees which worker drifted.
→ Verify: Milestone 6.

<!-- milestone:6 -->
### Milestone 6: Plan smoke run
1. In the scratch repo, write a two-phase plan where phase 1 has two independent milestones.
   Run the skill and confirm phase 1 runs both milestones in one wave, phase 2 waits for the
   phase 1 review, and nothing is committed.
→ Verify: `git log` unchanged, `.orchestrate/<run>/implementation-log.md` shows the agent per
  assignment.

### Phase C: docs and install

<!-- milestone:7 -->
### Milestone 7: Docs and symlinks
1. Add both skills to the README structure tree.
2. Add a "Swarm" row to the workflow table in `docs/delegation.md` and a short section that
   points to `swarm-rules.md`.
3. `ln -s` both skill dirs into `~/.claude/skills/`.
→ Verify: `ls -la ~/.claude/skills | grep swarm` shows both links, and a fresh session lists
  both skills.

## Affected Files
- New files:
  - `skills/delegate-work-swarm/SKILL.md`
  - `skills/delegate-work-swarm/swarm-files.sh`
  - `skills/delegate-work-swarm/references/swarm-rules.md`
  - `skills/delegate-work-swarm/tests/test-swarm-files.sh`
  - `skills/orchestrate-implementation-swarm/SKILL.md`
- Files to modify: `README.md`, `docs/delegation.md`, `docs/research.md`
- Unchanged: every existing `delegate-work-*` and `orchestrate-implementation-*` skill and helper.

## Acceptance Criteria
- [ ] `test-swarm-files.sh` passes every case listed in Milestone 1.
- [ ] A direct task split three ways runs on pi, agy, and Codex at the same time and every
      change is attributed to its owner.
- [ ] Overlapping ownership puts assignments in separate waves.
- [ ] An `UNOWNED` source edit or a moved HEAD halts the wave with a drift report naming
      agent and model. Generated test or build artifacts do not.
- [ ] A worker editing another worker's file is flagged by the reported-versus-changed check.
- [ ] Project-wide checks run once per wave, after every worker is idle.
- [ ] Every unsuccessful turn is classified as unavailable, environment, slip, or reasoning
      failure before any retry or escalation.
- [ ] A reasoning failure escalates at once (pi goes straight to Codex), a slip gets one
      same-agent correction, and nothing moves down without asking.
- [ ] Escalation restores the failed worker's owned paths to the wave baseline, saves the
      attempt under `partial/`, and the next worker starts from the original brief.
- [ ] An unavailable agent never counts toward escalation. Its assignments are held, other
      workers continue, and the user is asked once per incident.
- [ ] Pre-flight checks login for every agent in the routing table and records each CLI's
      configured model.
- [ ] A pi model listed as `above` in the ranks table takes mid-level work, and an unlisted pi
      model counts as `below`.
- [ ] An assignment that needs image input never goes to a text-only model.
- [ ] A low or mid editing assignment without an automated check is either preceded by a Codex
      spec assignment or routed up.
- [ ] A user agent override wins over the rubric.
- [ ] The plan skill runs phases in order, parallelizes within a phase, and commits nothing.

## Tests
- Unit: `bash skills/delegate-work-swarm/tests/test-swarm-files.sh` (no agent CLIs needed).
- Manual smoke: Milestones 4 and 6, using the installed `codex`, `agy`, and `pi`.

## Rollback
Delete the two new skill directories and their symlinks. Revert the README and
`docs/delegation.md` edits. No existing skill changes, so nothing else to undo.

## Decisions Log
| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
| Input scope | Both direct tasks and approved plans | Direct tasks only; approved plans only; both | User preference |
| Parallel edit safety | Disjoint file ownership | Disjoint file ownership; Git worktree per worker; parallel read-only with serial edits | User preference |
| Agent ranking | Codex > agy >= pi, pi's place from a user-maintained "pi model ranks" table (`below`, `peer`, `above`), unlisted counts as `below` | Fixed tier per agent; orchestrator judges each pi model itself | User's ranking: pi's quality depends on its model, and GLM would put pi above agy. A table in `swarm-rules.md` keeps that the user's call without a new config file. User confirmed 2026-10-13: seed only `glm*` as `above`; every currently enabled pi model (DeepSeek, MiMo, Step) stays unlisted and counts as `below` |
| Capability routing | Image-input work only to models that accept images, read from `pi --list-models` | Ignore modality | Several pi models are text-only (MiMo, Step 3.5, DeepSeek v4 Pro, GLM text models); `pi --list-models` has an `images` column (checked 2026-10-13) |
| Helper reuse | Call the `delegate-work-*` scripts from sibling dirs | Copy scripts into swarm skills; use the `orchestrate-implementation-*` scripts | `delegate-work-*` helpers have slug and prompt validation the orchestrate copies lack; `prototype-ui` already reads sibling skill files |
| Ownership enforcement | Post-hoc Git hash comparison in a helper script | Trust worker reports; sandbox per worker | pi runs unsandboxed, so only an after-the-fact check covers all three; a script is deterministic where reading `git status` by eye is not |
| Unsure tier | agy vs Codex: Codex. pi vs agy with an automated check: pi | Always higher; always lower and rely on escalation | Research report: agy costs about 58% of Codex per task, so it only pays off when it usually succeeds; pi costs about 3.5%, so a checked pi attempt pays off even at low success rates |
| Routing basis | Horizon and checkability first, then category | Category only | Tier gap is 3 to 10 points on short fixes and 20 to 37 on long agentic runs; machine-checkable specs narrowed the gap most for weak models (`reports/Coding quality by model tier.md`) |
| Spec first for lower tiers | Codex writes the failing test or interface when no automated check exists | Let agy or pi work unchecked; always route up | Strong-plan, cheap-execute splits have the most consistent support; an unchecked pi task is a guess |
| Escalation trigger | Classify failures; reasoning failure escalates at once, slip gets one correction | Two failures at any tier | Agents rarely recover from false-premise or wrong-problem failures, and cheap models mostly solve a subset of what strong ones solve, so a second same-tier attempt rarely helps |
| Escalation path | pi reasoning failure goes straight to Codex | Always one tier at a time | A third cascade tier rarely raised accuracy (118 of 135 comparisons) |
| Escalation start state | Restore owned paths, fresh brief plus verified facts | Hand over the failed transcript and edits | Strong models shown a weak trajectory repeated its mistakes (SWE-Router); the saved `partial/` keeps the attempt for the user |
| Unavailable agent default | Pause and ask once per incident; one auto retry only for a stated reset of 60 seconds or less | Auto move up; auto wait and resume | User preference, and both Codex and agy recommended it: auto move up spends unapproved money, auto wait can hang on a used-up quota or expired login |
| Unavailability vs escalation | Separate counter, never escalates | Count as a failed attempt | A 429 says nothing about task difficulty; counting it would push pi doc edits up to Codex |
| Edits after unavailability | Keep in place | Restore to baseline | The worker did not fail on the task, and the existing skills forbid automatic reverts after incidents |
| Model record | Record each CLI's configured model at pre-flight | Trust tier labels | Checked 2026-10-13: Codex runs `gpt-6.1-sol` (`~/.codex/config.toml`), pi defaults to `stepfun/step-5-preview` (`~/.pi/agent/settings.json`), agy's default is not in a config file. The user switches pi between open-weight providers (DeepSeek, MiMo, Step) and pi never runs Claude, GPT, or Gemini, so the research report's Haiku-class numbers are only a loose proxy for pi |
| pi model choice | Use the user's configured pi model; offer another enabled model on unavailability | Swarm picks a pi model per task | The user picks pi's model for the moment; switching within `enabledModels` keeps work on the low tier instead of paying for a move up |
| Restore method | `git restore --source=HEAD --worktree` for clean files, snapshot copies for dirty ones | `git show HEAD:<path>`; `git checkout HEAD -- <path>` | `git show` skips checkout filters (line endings, LFS); `git checkout` also writes the index, which the drift check treats as drift |
| Concurrency cap | 3 workers at once | No cap; one per agent | Keeps rate limits and review load in check; marked as a shortcut |
| Plan skill structure | Copy plan gate, drift list, CTO report from the Codex orchestrate skill | Reference those sections by link | All four orchestrate skills are self-contained today; matching that keeps the plan skill readable alone |
| Outside Git | Editing assignments run one at a time | Hash snapshots of owned files | Keeps the helper small; add when a non-Git project needs a swarm |
| Claude subagents | Not a tier | Add as a fourth tier | User listed three agents |
| Routing confirmation | Wait once per run unless told to proceed | No gate; gate per wave | Tier choice spends money and the user wants override; one gate keeps it cheap |
| Drift halt scope | Stop the drifting worker, let others finish their turn without resuming | Kill every worker; let the wave continue | Killing mid-turn leaves half edits in clean assignments; continuing ignores the existing halt rule |
| Acceptance checks | Project-wide checks once at wave end | Each worker runs full checks mid-wave | Mid-wave checks see other workers' half-done edits and fail for the wrong reason |
| Dispatch prompts | Each agent's own `delegate-work-<agent>` prompt | One shared Codex prompt | agy and pi prompts carry agent-specific rules the Codex one lacks |

## Review Log

### Review 1: 2026-10-13
**Flaws found:** 7
**Changes made:**
- Added wave-end project-wide checks and told workers not to fix failures in files they do not own. **Reason:** parallel workers see each other's half-done edits, so mid-wave test runs fail for the wrong reason.
- `attribute` exit 2 now means inspect, not auto-halt; generated artifacts are allowed. **Reason:** untracked build or test output would halt every wave, and the existing skills already allow it.
- Added a reported-versus-changed comparison per worker, plus a planted cross-owner edit in the smoke run. **Reason:** `attribute` credits a path to its owner even when another worker edited it, so cross-owner edits were invisible.
- Defined drift halt scope and named agent and tier in the report. **Reason:** the plan said "halts the wave" without saying what happens to clean workers mid-turn.
- Switched to each agent's own dispatch and verification prompt and its troubleshooting reference. **Reason:** the Codex prompt lacks agy image copying and pi compaction rules; all three share the JSON contract (checked in each SKILL.md).
- Added a same-agent concurrency smoke test with a one-worker-per-agent fallback. **Reason:** helpers capture ids per process (checked `agy-exec.sh` lines 131-149), but running two agy or pi sessions in one project at once is unverified.
- Added a routing-table confirmation, temp handoff for all-read-only runs, a Phase A to Phase B gate, and replaced em dashes in phase headings. **Reason:** user override needs a moment before dispatch; read-only runs must leave the project untouched as in `delegate-work-*`; Phase B should wait until Phase A is proven; CLAUDE.md bans em dashes.
- Pass 2: orchestrator corrections go through the owning worker during a wave, direct edits only between waves. **Reason:** a direct orchestrator edit would look like an unreported change and trigger a false drift suspect.
**Still open:**
- Submodules and symlinks in `swarm-files.sh`. **Reason not resolved:** `git hash-object` on a submodule directory fails; no current project needs it. Handle when one does.

### Review 2: 2026-10-13
Scope: new routing, escalation, `restore`, and unavailability rules added after the Codex and agy discussion and the research report.
**Flaws found:** 9
**Changes made:**
- `restore` uses `git restore --source=HEAD --worktree` instead of `git show HEAD:<path>`. **Reason:** `git show` skips checkout filters (line endings, LFS), and `git checkout HEAD --` would also write the index, which the drift check reads as drift.
- Escalation steps are ordered: record session evidence, `stop`, confirm exit, then `restore`. **Reason:** the first draft ran `restore` before `stop`, so a live worker could keep writing after its files were reset, and `stop` deletes the evidence.
- `restore` is named as the one allowed mid-wave orchestrator edit. **Reason:** it contradicted the "edit only between waves" rule.
- Escalation must happen before the next wave's snapshot; the new worker gets a fresh slug; the old work log moves to `partial/`. **Reason:** after a new snapshot, "wave baseline" no longer means the failed worker's starting state, and leaving the old work log in place leaked the failed attempt to the new worker.
- Added `after: <ids>` dependencies, with Codex spec assignments always running first, and the same rule for milestones inside a plan phase. **Reason:** spec-first routing and held assignments both assume dependencies, but waves were planned on file overlap only.
- Environment failures that survive one retry are reported, not escalated. **Reason:** the rule did not say what happens after the retry, and escalating a broken tool shifts cost without helping.
- Codex halt condition reworded to "reasoning failure or failed slip correction". **Reason:** "a failure at Codex" skipped the one correction every other tier gets.
- pi pre-flight reads `defaultProvider` from `~/.pi/agent/settings.json`. Model-record row corrected. **Reason:** the plan said pi runs DeepSeek; the settings file says `stepfun/step-5-preview`. agy's earlier check of the deepseek provider would not catch a stepfun login failure.
- Milestone 2 verify wording matches the list format. **Reason:** the tier table became a list.
- User clarification after Review 2: pi switches between open-weight providers (DeepSeek, MiMo, Step) and never runs Claude, GPT, or Gemini. Added: the swarm uses the user's configured pi model, the unavailability prompt offers another enabled pi model, and pi limits never hold Codex or agy work. **Reason:** pi's model is the user's choice per session, and a provider switch is a cheaper recovery than moving up a tier.
- User ranking after Review 2: Codex > agy >= pi, with pi's place set by its model (GLM would put pi above agy) and some pi models text-only. Replaced fixed agent tiers with task levels (low, mid, top), a user-maintained "pi model ranks" table (`below`, `peer`, `above`; unlisted counts as `below`), image-input capability routing from `pi --list-models`, and escalation that follows the run's ranking. Added acceptance criteria and smoke step 8. **Reason:** a fixed pi tier misroutes work whenever the user switches pi to a stronger or text-only model.
- Recheck: "low goes to agy when pi is unavailable" contradicted the ask-first unavailability rule. Now only a missing capability re-routes on its own. **Reason:** moving work to a pricier agent without asking is what the unavailability rule forbids.
**Still open:**
- Submodules and symlinks in `swarm-files.sh` (carried from Review 1).
- Classifying slip versus reasoning failure is orchestrator judgment, not a mechanical check. **Reason not resolved:** no reliable automatic signal exists (research: LLM judges detect false success near chance). The smoke run in Milestone 4 step 7 exercises one case.

### Review 3: 2026-10-13
Scope: whole plan after the model-dependent pi ranking.
**Flaws found:** 4
**Changes made:**
- Replaced leftover fixed-tier wording ("set the tier", "tier used", "same tier", "agent and tier") with level and agent terms, and the routing table now shows level, agent, and pi's model, rank, and image support. **Reason:** once pi's place depends on its model, "tier" no longer names one agent, and an implementer would build the routing table from the old columns.
- Smoke step 8 removes the temporary ranks-table row after the test. **Reason:** the step edited the real `swarm-rules.md`, so a test entry would have stayed and rerouted later runs.
- Milestone 2 verify now runs each pre-flight command (`codex login status`, `pi auth check --help`, `pi --list-models`, `agy models`), checks the single `glm*` seed row, and checks every level maps to an agent for all three pi ranks. **Reason:** the old check counted tier rows that no longer exist and never ran the commands the rules depend on.
- Drift reports and the CTO report name the agent and its model instead of a tier. **Reason:** same as the first item; a pi drift report is only useful with the model that drifted.
**Security review:** every assignment routed to pi sends that code to the provider of pi's current model. The routing-table confirmation shows that model before dispatch, which keeps the choice with the user. No further change.
**Still open:**
- Submodules and symlinks in `swarm-files.sh` (carried from Review 1).
- Slip versus reasoning-failure classification is judgment (carried from Review 2).
- The decisions log cites `reports/Coding quality by model tier.md`, which is untracked. **Reason not resolved:** the user has not decided whether to keep `reports/` or log the findings to `docs/research.md`; update the citation when they do.
