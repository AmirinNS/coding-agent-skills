# Skill Updates: Swarm orchestration across Codex, agy, and pi

## Overview

Two new skills coordinate work across Codex, agy, and pi at the same time. `delegate-work-swarm` breaks direct tasks into parallel assignments, routes each by task level and agent ranking, and reviews results independently. `orchestrate-implementation-swarm` executes approved plans phase by phase, running independent milestones within each phase in parallel waves. A shared shell helper (`swarm-files.sh`) snapshots Git state, attributes changed files to owners, and restores baselines during escalation.

## Skills

### delegate-work-swarm

Direct task orchestration without requiring a `plans/` document. Triggered by requests like "swarm this", "delegate to the swarm", "split this across codex, agy and pi", or "run these in parallel on codex, agy and pi".

Workflow:

1. **Define the work.** Scopes the brief, splits it into separately reviewable assignments, assigns a task level (low, mid, top) and agent, defines owned paths, and sets dependencies (`after:`).
2. **Pre-flight and confirmation.** Runs login and model checks for every agent, shows a routing table with the configured pi model and rank, and waits for user confirmation before dispatching.
3. **Wave dispatch.** Snapshots the wave baseline, writes `<id>/prompt.md`, and runs up to 3 workers concurrently in the background using sibling helper scripts (`codex-exec.sh`, `agy-exec.sh`, `pi-work.sh`).
4. **Independent review.** Verifies outputs using `attribute`, checks reported against changed files, reads the worker's premise, and reviews only owned paths.
5. **Wave close.** Runs full test suites and project checks when all workers are idle, escalates failures before the next snapshot, and allows orchestrator edits only between waves.
6. **Finish.** Stops helpers, reconciles `git status --porcelain`, reports outcomes, and leaves all work uncommitted.

### orchestrate-implementation-swarm

Phase-by-phase execution of an approved plan (`plans/<slug>.md`). Triggered by requests like "implement the plan with the swarm", "orchestrate this plan across codex, agy and pi", or "run the plan in parallel".

Workflow:

1. **Plan gate.** Requires an existing approved plan and a Git repository. Direct tasks route to `delegate-work-swarm`.
2. **Phase mapping.** Maps phases and milestone dependencies (`after:`).
3. **Phase loop.** Sets a phase baseline, maps milestones to assignments, runs parallel waves inside the phase, verifies against the plan, conducts a phase-scoped review, and runs the application flow when applicable.
4. **Drift halt and CTO report.** Catches plan deviations, unowned source edits, and index tampering. Halts the drifting worker and produces a CTO report with concrete diffs, agent, and model details.
5. **Finish.** Stops helpers, summarizes phases and review results, and leaves all work uncommitted.

## Shared helper: swarm-files.sh

A standalone script at `skills/delegate-work-swarm/swarm-files.sh` managing file ownership and integrity in a shared Git worktree:

- `snapshot <state-dir>`: Captures HEAD commit, index sha256, dirty file hashes, and back-up copies of wave-start dirty files. Rejects paths inside the work tree.
- `changed <state-dir>`: Detects modified, added, and deleted files against the snapshot. Exits 3 if HEAD moved or the index changed.
- `overlap <own-file>...`: Verifies disjoint ownership, rejecting identical paths or nested directories.
- `attribute <state-dir> <own-file>...`: Matches changed paths to their `.own` owner. Exits 2 on `UNOWNED` paths.
- `restore <state-dir> <own-file> <save-dir>`: Backs up current files to `<save-dir>`, resets clean tracked files via `git restore --source=HEAD --worktree`, restores pre-dirty files from wave-start copies, and deletes newly added untracked files while skipping handoff state (`.orchestrate/`).

Tested with 19 test cases in `skills/delegate-work-swarm/tests/test-swarm-files.sh`.

## Configuration and Routing

Routing rules live in `skills/delegate-work-swarm/references/swarm-rules.md`:

- **Task levels:**
  - **Low:** Short tasks (< 1 hour) with automated checks (tests, linter, typecheck), mechanical refactors, summaries, doc edits.
  - **Mid:** Bounded features with specs and tests, UI implementations, localized refactors.
  - **Top:** Multi-step architecture, cross-cutting refactors, unknown bugs, writing specs or failing tests for lower tiers.
- **Agent ranking:** Codex > agy >= pi. Pi's rank is determined by the "pi model ranks" table in `swarm-rules.md` (`below`, `peer`, `above`). Unlisted models default to `below`.
- **Capability matching:** Image inputs route only to vision-capable models (verified via `pi --list-models`).
- **Spec-first:** Unchecked low or mid editing tasks require an earlier Codex assignment to write failing tests or interfaces first, or must be routed up.
- **Unavailability handling:** Rate limits <= 60 seconds get one wait-and-retry. Quota exhaustion or auth errors pause the assignment, keep other workers running, and ask the user once without escalating.

## Examples

### Direct task split

```text
Use $delegate-work-swarm to update API pagination and write documentation in parallel.
Assign the endpoint changes to agy and the docs update to pi. Do not commit.
```

### Approved plan implementation

```text
Use $orchestrate-implementation-swarm to implement plans/user-billing.md.
Follow the approved phases and leave all work uncommitted.
```

## Notes

- Requires a Git repository. In non-Git projects, editing tasks execute sequentially.
- Parallel concurrency is capped at 3 simultaneous workers.
- Work is never committed by either skill. Final staging and commits are handed off to `document-and-commit`.

## Design Decisions

| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
| Input scope | Both direct tasks and approved plans | Direct tasks only; approved plans only; both | User preference |
| Parallel edit safety | Disjoint file ownership | Disjoint file ownership; Git worktree per worker; parallel read-only with serial edits | User preference |
| Agent ranking | Codex > agy >= pi, pi's place from a user-maintained "pi model ranks" table (`below`, `peer`, `above`), unlisted counts as `below` | Fixed tier per agent; orchestrator judges each pi model itself | User's ranking: pi quality depends on its model, and GLM would put pi above agy. A table in `swarm-rules.md` keeps that the user's call without a new config file. Seeded with `glm*` as `above`; enabled pi models (DeepSeek, MiMo, Step) stay unlisted and count as `below` |
| Capability routing | Image-input work only to models that accept images, read from `pi --list-models` | Ignore modality | Several pi models are text-only (MiMo, Step 3.5, DeepSeek v4 Pro, GLM text models); `pi --list-models` provides an `images` column |
| Helper reuse | Call the `delegate-work-*` scripts from sibling dirs | Copy scripts into swarm skills; use the `orchestrate-implementation-*` scripts | `delegate-work-*` helpers have slug and prompt validation that orchestrate copies lack; `prototype-ui` already reads sibling skill files |
| Ownership enforcement | Post-hoc Git hash comparison in a helper script | Trust worker reports; sandbox per worker | pi runs unsandboxed, so only an after-the-fact check covers all three; a script is deterministic where reading `git status` by eye is not |
| Unsure tier | agy vs Codex: Codex. pi vs agy with an automated check: pi | Always higher; always lower and rely on escalation | Research report: agy costs about 58% of Codex per task, so it only pays off when it usually succeeds; pi costs about 3.5%, so a checked pi attempt pays off even at low success rates |
| Routing basis | Horizon and checkability first, then category | Category only | Tier gap is 3 to 10 points on short fixes and 20 to 37 on long agentic runs; machine-checkable specs narrowed the gap most for weak models (`reports/Coding quality by model tier.md`) |
| Spec first for lower tiers | Codex writes the failing test or interface when no automated check exists | Let agy or pi work unchecked; always route up | Strong-plan, cheap-execute splits have the most consistent support; an unchecked pi task is a guess |
| Escalation trigger | Classify failures; reasoning failure escalates at once, slip gets one correction | Two failures at any tier | Agents rarely recover from false-premise or wrong-problem failures, and cheap models mostly solve a subset of what strong ones solve, so a second same-tier attempt rarely helps |
| Escalation path | pi reasoning failure goes straight to Codex | Always one tier at a time | A third cascade tier rarely raised accuracy in benchmark research |
| Escalation start state | Restore owned paths, fresh brief plus verified facts | Hand over the failed transcript and edits | Strong models shown a weak trajectory repeated its mistakes (SWE-Router); the saved `partial/` directory keeps the attempt for the user |
| Unavailable agent default | Pause and ask once per incident; one auto retry only for a stated reset of 60 seconds or less | Auto move up; auto wait and resume | User preference, and both Codex and agy recommended it: auto move up spends unapproved money, auto wait can hang on an exhausted quota or expired login |
| Unavailability vs escalation | Separate counter, never escalates | Count as a failed attempt | A 429 says nothing about task difficulty; counting it would push pi doc edits up to Codex |
| Edits after unavailability | Keep in place | Restore to baseline | The worker did not fail on the task, and the existing skills forbid automatic reverts after incidents |
| Model record | Record each CLI's configured model at pre-flight | Trust tier labels | Codex runs `gpt-6.1-sol` (`~/.codex/config.toml`), pi defaults to `stepfun/step-5-preview` (`~/.pi/agent/settings.json`), agy default is not in a config file. pi switches between open-weight providers and never runs Claude, GPT, or Gemini |
| pi model choice | Use the user's configured pi model; offer another enabled model on unavailability | Swarm picks a pi model per task | The user picks pi's model; switching within `enabledModels` keeps work on the low tier instead of paying for a move up |
| Restore method | `git restore --source=HEAD --worktree` for clean files, snapshot copies for dirty ones | `git show HEAD:<path>`; `git checkout HEAD -- <path>` | `git show` skips checkout filters (line endings, LFS); `git checkout` also writes the index, which the drift check treats as drift |
| Concurrency cap | 3 workers at once | No cap; one per agent | Keeps rate limits and review load in check; marked as a shortcut |
| Plan skill structure | Copy plan gate, drift list, CTO report from the Codex orchestrate skill | Reference those sections by link | All four orchestrate skills are self-contained today; matching that keeps the plan skill readable alone |
| Outside Git | Editing assignments run one at a time | Hash snapshots of owned files | Keeps the helper small; add when a non-Git project needs a swarm |
| Claude subagents | Not a tier | Add as a fourth tier | User listed three agents |
| Routing confirmation | Wait once per run unless told to proceed | No gate; gate per wave | Tier choice spends money and the user wants override; one gate keeps it cheap |
| Drift halt scope | Stop the drifting worker, let others finish their turn without resuming | Kill every worker; let the wave continue | Killing mid-turn leaves partial edits in clean assignments; continuing ignores the existing halt rule |
| Acceptance checks | Project-wide checks once at wave end | Each worker runs full checks mid-wave | Mid-wave checks see other workers' half-done edits and fail for the wrong reason |
| Dispatch prompts | Each agent's own `delegate-work-<agent>` prompt | One shared Codex prompt | agy and pi prompts carry agent-specific rules the Codex prompt lacks |

## Review History

The implementation plan passed three review rounds on 2026-10-13:

- **Wave verification and drift:** Added wave-end project-wide checks so parallel workers are not derailed by sibling partial edits. `attribute` exit code 2 inspects rather than halts on generated build or test artifacts. Added reported-versus-changed checks to catch cross-owner file modifications.
- **Escalation sequencing and restore safety:** Refined `restore` to use `git restore --source=HEAD --worktree` to respect checkout filters and avoid modifying the index. Ordered escalation steps: record diagnostics, stop helper, confirm worker exit, then run `restore`. New workers receive a fresh slug and original brief plus verified facts, while previous failed attempts move to `partial/`.
- **Dependencies and failure classification:** Added `after:` milestone dependencies so dependent tasks execute in subsequent waves. Separated environment errors (one retry, no escalation) from reasoning failures (immediate escalation to Codex).
- **Dynamic pi rankings and capabilities:** Replaced rigid agent tiers with task levels (low, mid, top) and introduced a user-maintained pi model ranks table (`glm*` seeded as `above`). Integrated image capability filtering using `pi --list-models`.
- **Pre-flight and unslop refinements:** Updated pre-flight checks to run CLI status commands directly (`codex login status`, `pi auth check`, `agy models`). Replaced em dashes and colons across headings and rules per `CLAUDE.md`.
