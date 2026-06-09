# Plan: Migrate skills + plans to sebaik-baik-pembina

## Goal

Move all skill SKILL.md files, both pending workflow plans, the behavioral CLAUDE.md, the template, the LICENSE, and a minimal README from `/Users/amirinns/Projects/coding-agent-skills/` into `/Users/amirinns/Projects/sebaik-baik-pembina/`. Touch up the cross-repo references in moved files so paths remain valid. Add one notice file to coding-agent-skills pointing to the new home. After the migration, sebaik-baik-pembina is the active home for skill and SDLC-workflow development; coding-agent-skills is a frozen archive.

## Scope

**In**
- Copy `skills/*` (all 8 skills) verbatim → `sebaik-baik-pembina/skills/`
- Copy `plans/sdlc-orchestrator.md` and `plans/plan-review-parallel-personas.md` → `sebaik-baik-pembina/plans/`
- Copy `CLAUDE.md`, `CLAUDE-template.md`, `LICENSE` verbatim → `sebaik-baik-pembina/`
- Write a short replacement `README.md` for the new repo (full rewrite deferred to v1-brownfield M1 which builds the pembina repo skeleton).
- Touch up the two `coding-agent-skills/plans/...` hard references in `plan-review-parallel-personas.md` (lines 5 and 168) to repo-relative `plans/sdlc-orchestrator.md`.
- Touch up `sebaik-baik-pembina/plans/v1-brownfield-agent.md` so its "Skill layer — coding-agent-skills" reference points at the in-repo `skills/` location.
- Write `coding-agent-skills/ARCHIVED.md` with a one-paragraph notice pointing to sebaik-baik-pembina. **This is the only edit allowed in coding-agent-skills.**
- Copy this migration plan itself (`plans/migrate-to-sebaik-baik-pembina.md`) to the new repo so the implementer there has the source-of-truth doc.

**Out**
- No changes to `~/.claude/skills/` (manual-copy workflow stays as-is — user syncs when ready).
- No changes to `~/.claude/settings.json` or any plugin manifest.
- No symlinks, no Claude Code plugin manifest, no marketplace registration.
- No git filter-repo or history preservation — files are plain copies. coding-agent-skills' git history stays intact in place as the historical record.
- No edits to coding-agent-skills beyond `ARCHIVED.md`. No README banner, no .gitignore changes, no skill edits.
- No implementation of `sdlc-orchestrator.md` or `plan-review-parallel-personas.md` — those are separate workstreams that ship AFTER this migration lands.
- No MEMORY.md updates (`feedback_workflow.md` reference path) — user said memory updates are a separate task.
- No deletion of coding-agent-skills' git remote, no archive-on-GitHub action.
- No full rewrite of `sebaik-baik-pembina/README.md` — stub only; full version is v1-brownfield M1's job.

## Approach

0. **Pre-flight: resolve pending git state in both repos.**
   - In `coding-agent-skills`: there are currently staged/untracked changes (`plans/sdlc-orchestrator.md` staged-added, `plans/plan-review-parallel-personas.md` staged-added-with-modifications, `plans/migrate-to-sebaik-baik-pembina.md` untracked). Commit these to the historical record BEFORE the freeze takes effect: `git -C coding-agent-skills add plans/ && git -C coding-agent-skills commit -m "docs: add SDLC orchestrator and parallel-personas plans (final pre-archive commit)"`. After this commit, the freeze rule kicks in (only `ARCHIVED.md` allowed thereafter).
   - In `sebaik-baik-pembina`: there are pending staged AND unstaged edits to `plans/v1-brownfield-agent.md` on a "no commits yet" branch. Decide first: are those pending edits part of the migration commit (likely yes, since they're already the intended in-progress state) or do they need to be committed/reset separately? Default: include them — the initial commit on a fresh repo can reasonably bundle "the seed state of the repo." Confirm by running `git -C sebaik-baik-pembina diff plans/v1-brownfield-agent.md` and reading the change; abort the migration if anything looks wrong.

1. **Copy skills** — `mkdir -p /Users/amirinns/Projects/sebaik-baik-pembina/skills && cp -R /Users/amirinns/Projects/coding-agent-skills/skills/. /Users/amirinns/Projects/sebaik-baik-pembina/skills/`. The `mkdir -p` is required because the destination `skills/` directory does not exist yet (verified). The `cp -R src/. dest/` form copies directory contents recursively into an existing destination (the trailing `/.` avoids the macOS `cp: skills: Not a directory` failure mode of `cp -r src/* dest/skills/`).

2. **Copy the two pending workflow plans** — `cp /Users/amirinns/Projects/coding-agent-skills/plans/sdlc-orchestrator.md /Users/amirinns/Projects/sebaik-baik-pembina/plans/` and same for `plan-review-parallel-personas.md`. The existing `v1-brownfield-agent.md` already in `sebaik-baik-pembina/plans/` stays in place. **`sdlc-orchestrator.md` has zero `coding-agent-skills` references (verified by grep) and needs no edits after copy** — it describes the MCP orchestrator in a stack-agnostic way and is self-contained.

3. **Copy this migration plan** — `cp /Users/amirinns/Projects/coding-agent-skills/plans/migrate-to-sebaik-baik-pembina.md /Users/amirinns/Projects/sebaik-baik-pembina/plans/`. Lets the implementer in the new repo see what was migrated and why.

4. **Copy supporting files** — `CLAUDE.md`, `CLAUDE-template.md`, `LICENSE` verbatim to `sebaik-baik-pembina/`. These are generic and don't reference either repo by name.

5. **Write minimal new README** — `sebaik-baik-pembina/README.md`. ~20 lines. Names the repo, points at `plans/v1-brownfield-agent.md` for the full architecture, names what's in `skills/` and `plans/`. Notes the coding-agent-skills lineage with a one-line link. Full repo README is v1-brownfield M1's job — do not duplicate that scope here.

6. **Touch up `plan-review-parallel-personas.md` (in the destination only)** — open `sebaik-baik-pembina/plans/plan-review-parallel-personas.md` after copy and:
   - **Line 5 (Goal section, active body):** replace `coding-agent-skills/plans/sdlc-orchestrator.md` with `plans/sdlc-orchestrator.md`.
   - **Line 168 (inside the Review Log):** **leave untouched.** Same principle as `v1-brownfield-agent.md` Step 7 — the Review Log records what was discussed at the time, including the path references the user used in that discussion. Editing it rewrites historical record.
   - **Add an editor's note** at the very top of the file (under the H1):
   
   > **Editor's note (2026-06-09):** This plan was originally written when skills lived in a separate `coding-agent-skills/` repo. As of this date the skills live in this repo's `skills/` directory. The Goal section's path reference has been updated; the Review Log entry that mentions `coding-agent-skills/plans/sdlc-orchestrator.md` is preserved as historical record.
   
   Leaves the version in coding-agent-skills untouched per the freeze rule.

7. **Reconcile `v1-brownfield-agent.md` with the post-migration topology.** This plan is currently unexecuted, so it's safe to rewrite both the path references AND the structural sections (architecture, milestones, decisions) to describe the post-migration world from the start. Three categories of edits:

   **7a. Path/repo references** — replace `coding-agent-skills/` with in-repo paths in:
   - **Goal section** (line 5)
   - **Prerequisites** (lines 80, 81)
   - **Milestone steps that name file paths** (lines 114, 140, 150, 164, 238, 240, 260, 338, 342)

   **7b. Structural rewrites:**
   - **Architecture diagram (lines 13–38).** Currently shows three repo-boxes (Knowledge / Execution / Skill). Collapse to two: this repo (Knowledge + bundled Skill module) above sdlc-orchestrator MCP. The three *logical* layers still exist; the diagram should reflect that they live in two repos, not three.
   - **Architecture table (lines 40–44).** Replace the `coding-agent-skills/` row with a row for `skills/ (in this repo)` describing the workflow-skills module. Mark the old `coding-agent-skills/` repo as "Archived 2026-06-09; superseded by `skills/` in this repo" if you want a row for historical clarity, otherwise drop it.
   - **M1 step 1 directory-layout block (lines 88–100).** Update the comments to reflect what the migration left behind:
     - `README.md` — note "already exists (stub from migration; full rewrite is M1's job)"
     - `CLAUDE.md` — drop the "(same shape as coding-agent-skills/CLAUDE.md)" comment; replace with "already exists (copied during migration)"
     - `skills/` — add as an existing directory: "already exists (migrated from coding-agent-skills)"
     - `plans/` comment already reads "already exists"; leave it
   - **M1 step 2 (lines 101–107).** `git init` is already done by the migration's initial commit. Drop the `git init` line; keep `gh repo create`. Add a one-line note: "Repo is already initialized post-migration; create the remote only."
   - **Prerequisite #3 (line 81).** The "verified 2026-06-07" date is stale relative to the migration. Update to "verified 2026-06-09 post-migration" and change the source path from `~/Projects/coding-agent-skills/skills/` to `~/Projects/sebaik-baik-pembina/skills/`. The symlink decision (use symlinks, not copies) stays valid — only the source path changes.

   **7c. Add a new Decisions Log entry, do NOT edit existing ones.** Append (don't overwrite):

   > | Skill source repo (post-migration) | `~/Projects/sebaik-baik-pembina/skills/` | `~/Projects/coding-agent-skills/skills/` (pre-2026-06-09) | The 2026-06-09 migration moved all skills into this repo. The discovery mechanism (`~/.claude/skills/<name>/`) and the symlink-install decision are unchanged — only the source path is different. The earlier "invoke from globally-installed coding-agent-skills" decision remains semantically correct (globally-installed = `~/.claude/skills/`) — only its source-of-truth repo changed. |

   The Decisions Log and Review Log entries that reference `coding-agent-skills/` stay UNTOUCHED — they record the reasoning at the time and are historical record. A short editor's note goes at the very top of the file (under the H1):

   > **Editor's note (2026-06-09):** Skills migrated into this repo on 2026-06-09 (see `plans/migrate-to-sebaik-baik-pembina.md`). The Goal, Architecture, Prerequisites, and Milestone 1 sections have been updated to describe the post-migration starting state. The Decisions Log and Review Log preserve the prior reasoning verbatim — a new "Skill source repo (post-migration)" decisions entry has been appended.

8. **Write ARCHIVED.md in coding-agent-skills** — `/Users/amirinns/Projects/coding-agent-skills/ARCHIVED.md`. Short notice: "This repo is archived as of 2026-06-09. Active development moved to `/Users/amirinns/Projects/sebaik-baik-pembina/`. See that repo's `README.md` and `plans/v1-brownfield-agent.md` for the current architecture."

9. **Write `.gitignore` in `sebaik-baik-pembina`** — at least `.DS_Store` (a `.DS_Store` already exists in the repo root, verified). Without this, `git add` patterns risk capturing it in the initial commit.

10. **Commit on the destination side** — in `sebaik-baik-pembina`, this will be the **initial commit** of the repo (verified: `git status` reports "No commits yet"). Stage explicitly by listed path — `git add skills/ plans/ CLAUDE.md CLAUDE-template.md LICENSE README.md .gitignore` — rather than `git add -A`, to avoid capturing `.DS_Store` or other workspace cruft. Commit with: `chore: migrate skills, plans, and supporting files from coding-agent-skills`. Do NOT commit anything in coding-agent-skills — `ARCHIVED.md` stays as an uncommitted/staged change for the user to commit manually if they choose (preserves the "no automated edits to coding-agent-skills" stance and lets the user decide whether to commit the archive notice).

11. **Delete the migration plan source from coding-agent-skills (optional cleanup)** — `rm /Users/amirinns/Projects/coding-agent-skills/plans/migrate-to-sebaik-baik-pembina.md` is **out of scope** under the freeze rule (the freeze permits only adding `ARCHIVED.md`). Leave it untracked in place. Acceptance Criterion #9 below accounts for it.

## Affected Files

**Files to create in `sebaik-baik-pembina/`:**
- `skills/create-docs/SKILL.md` (and reference files if any)
- `skills/fix-bug/SKILL.md`
- `skills/frontend-bootstrap-evolution/SKILL.md` (and any subdirectory contents)
- `skills/frontend-design/SKILL.md` (and any subdirectory contents)
- `skills/generate-commit/SKILL.md`
- `skills/implementation-review/SKILL.md`
- `skills/plan-feature/SKILL.md`
- `skills/plan-review/SKILL.md`
- `plans/sdlc-orchestrator.md` (copy)
- `plans/plan-review-parallel-personas.md` (copy + 2-line path touch-up)
- `plans/migrate-to-sebaik-baik-pembina.md` (this plan, copied)
- `CLAUDE.md` (copy)
- `CLAUDE-template.md` (copy)
- `LICENSE` (copy)
- `README.md` (new minimal stub)

**Files to modify in `sebaik-baik-pembina/`:**
- `plans/v1-brownfield-agent.md` — three categories of edits (see Approach Step 7): (a) path/repo reference swaps, (b) structural rewrites to Architecture diagram, Architecture table, M1 directory-layout block, M1 step 2, and Prerequisite #3, (c) a new appended Decisions Log entry plus a top-of-file editor's note. Decisions Log and Review Log existing entries stay untouched.

**Files to create in `sebaik-baik-pembina/` (additional, from Approach Step 9):**
- `.gitignore` (single line: `.DS_Store`)

**Files to create in `coding-agent-skills/` (the only allowed edit):**
- `ARCHIVED.md`

**Files to modify in `coding-agent-skills/`:** none after the Step 0 pre-flight commit.

**Pre-flight commit in `coding-agent-skills/` (Approach Step 0):** one commit that adds `plans/sdlc-orchestrator.md`, `plans/plan-review-parallel-personas.md` (with its working-tree mods), and `plans/migrate-to-sebaik-baik-pembina.md`. The freeze rule begins immediately after this commit.

## Acceptance Criteria

- [ ] `ls /Users/amirinns/Projects/sebaik-baik-pembina/skills/` shows all 8 skill directory names.
- [ ] `diff -r /Users/amirinns/Projects/coding-agent-skills/skills/ /Users/amirinns/Projects/sebaik-baik-pembina/skills/` returns no differences.
- [ ] `sebaik-baik-pembina/plans/sdlc-orchestrator.md` exists; `diff` against the source is empty.
- [ ] `sebaik-baik-pembina/plans/plan-review-parallel-personas.md` exists. `grep -n "coding-agent-skills/plans" sebaik-baik-pembina/plans/plan-review-parallel-personas.md` returns EXACTLY ONE match — the surviving Review Log reference (preserved as historical record per Approach Step 6). The Goal section reference on line 5 (or its post-migration line number) has been swapped to `plans/sdlc-orchestrator.md`.
- [ ] `sebaik-baik-pembina/plans/plan-review-parallel-personas.md` has an editor's note at the top (under H1) explaining the migration context.
- [ ] `sebaik-baik-pembina/plans/sdlc-orchestrator.md` exists; `grep -c "coding-agent-skills\|sebaik-baik-pembina" sebaik-baik-pembina/plans/sdlc-orchestrator.md` returns 0 (verified pre-migration; nothing to update).
- [ ] `sebaik-baik-pembina/plans/migrate-to-sebaik-baik-pembina.md` exists.
- [ ] `sebaik-baik-pembina/CLAUDE.md`, `CLAUDE-template.md`, `LICENSE` exist; `diff` against source is empty for each.
- [ ] `sebaik-baik-pembina/README.md` exists and is ≤ 30 lines (stub, not full rewrite).
- [ ] `grep "coding-agent-skills" sebaik-baik-pembina/plans/v1-brownfield-agent.md` returns no matches in the architecture diagram/table (or, if matches remain, they are intentional historical references in the body — verify by reading).
- [ ] `coding-agent-skills/ARCHIVED.md` exists with the destination path.
- [ ] `git status` in `coding-agent-skills` shows ONLY `ARCHIVED.md` as untracked/new (the three previously pending plan files are now committed in the Step 0 pre-flight; the freeze rule kicks in after that commit). No other modifications.
- [ ] `git log -1` in `coding-agent-skills` after the pre-flight commit shows the message `docs: add SDLC orchestrator and parallel-personas plans (final pre-archive commit)` (or equivalent).
- [ ] `~/.claude/skills/` is byte-for-byte unchanged by the migration (`ls -la ~/.claude/skills/` shows pre-migration mtimes on existing directories).
- [ ] In `sebaik-baik-pembina`, `git log -1 --stat` after the initial commit shows the migration as a single chore commit. It includes all copied files, the `v1-brownfield-agent.md` touch-up (which subsumes the pre-existing pending edits on that file — see Approach Step 0), the new `README.md` stub, and `.gitignore`. It MUST NOT include `.DS_Store`.
- [ ] `sebaik-baik-pembina/.gitignore` contains `.DS_Store`.
- [ ] `sebaik-baik-pembina/plans/v1-brownfield-agent.md` has an editor's note at the top (under H1) explaining the migration context.
- [ ] `git diff` on `sebaik-baik-pembina/plans/v1-brownfield-agent.md` (against its initial-commit-staged state right before the touch-up) confirms NO edits inside the existing Decisions Log or Review Log rows. (A NEW Decisions Log row appended at the bottom of the table is expected and correct — see Approach Step 7c.)
- [ ] `sebaik-baik-pembina/plans/v1-brownfield-agent.md` Architecture diagram shows TWO repos (this repo + sdlc-orchestrator MCP), not three. `grep -c "Skill layer — coding-agent-skills" sebaik-baik-pembina/plans/v1-brownfield-agent.md` returns 0.
- [ ] `sebaik-baik-pembina/plans/v1-brownfield-agent.md` M1 step 2 does NOT contain `git init` (only `gh repo create`).
- [ ] `sebaik-baik-pembina/plans/v1-brownfield-agent.md` M1 step 1 directory-layout block annotates `README.md`, `CLAUDE.md`, `skills/`, `plans/` as "already exists" (post-migration starting state).
- [ ] `sebaik-baik-pembina/plans/v1-brownfield-agent.md` Decisions Log table contains a new row with the header "Skill source repo (post-migration)".

## Tests

- Test type: manual file-system verification (no automated tests — this is a file migration).
- Tests to run:
  - The `diff -r` and `grep` checks under Acceptance Criteria.
  - Open `~/.claude/skills/plan-review/SKILL.md` and confirm it still works as a Claude Code skill (no change expected — manual-copy workflow means the installed copy is untouched).
  - From any project directory, trigger `/plan-review` — confirm the skill still loads (uses `~/.claude/skills/`, unaffected by the migration).
- Tests to add: none.

## Decisions Log

| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
| Skill discovery mechanism | Manual copy to `~/.claude/skills/` (status quo) | Symlinks; Claude Code plugin manifest | User-selected. Preserves the existing workflow; lowest setup cost. Drift risk exists in theory (two copies, no auto-sync) but no actual divergence between `~/.claude/skills/` and the workspace skills was found at migration time — the apparent `create-docs` divergence noted during planning was unstaged workspace edits, since discarded. User accepts the manual-sync discipline. |
| Git history preservation | Plain `cp`, no history transfer | `git filter-repo` / subtree-split to preserve commit history per-skill | Mechanical simplicity. coding-agent-skills' git log stays intact in place as the historical record; future blame on skill text can be done against the archived repo if needed. |
| README in new repo | Write a short stub (~20 lines) pointing at `v1-brownfield-agent.md` | Copy `coding-agent-skills/README.md` verbatim; rewrite README fully here | Verbatim copy would be misleading (the old README describes "Coding Agent Skills"). Full rewrite is v1-brownfield M1's stated job — duplicating that scope here violates the migration's purpose. |
| Touch-up `v1-brownfield-agent.md` | Surgical edit: only the path/repo refs that are now factually wrong | Leave it untouched; rewrite the whole architecture section to match the new collapsed-repo model | Stale references would silently mislead any reviewer. Full architectural rewrite is too far from "migration" — keep that for a follow-up plan if needed. |
| Cross-repo path refs in `plan-review-parallel-personas.md` | Edit ONLY the Goal section path ref (line 5); leave the Review Log occurrence (line 168) intact as historical record. Add an editor's note. | Replace both occurrences (original plan); leave both untouched; use absolute paths | The Review Log records what was discussed at the time including the path used — editing it rewrites history (same principle as `v1-brownfield-agent.md` Step 7). The Goal section is active body and must be correct. Editor's note signals what was preserved vs updated. |
| `sdlc-orchestrator.md` updates | None — file is self-contained, no `coding-agent-skills` or `sebaik-baik-pembina` references (verified by grep) | Add an editor's note anyway for consistency | Adding edits to a file that needs none introduces drift risk for no benefit. The file describes the MCP orchestrator stack-agnostically; the migration doesn't change anything it relies on. |
| coding-agent-skills edits | Exactly one new file: `ARCHIVED.md` at repo root | Add a banner to existing `README.md`; rename `README.md` to `README.archived.md`; delete the repo | User said "frozen as-is (no edits)" and ALSO "add an ARCHIVED notice". One new file is the minimum that satisfies both. README banner would be an edit to an existing file. |
| Commit strategy | Auto-commit only on sebaik-baik-pembina side; leave `ARCHIVED.md` staged in coding-agent-skills | Commit both sides automatically; leave both sides for manual commit | The new repo benefits from a clean atomic commit. coding-agent-skills is meant to be touched at most once ever — let the user decide if/when to commit the archive notice. |
| Memory file (`feedback_workflow.md`) update | Out of scope | Include in this plan; auto-update after migration | User explicitly said memory updates are separate. Honoring that. |
| ~/.claude/skills sync | Out of scope (user does it manually when ready) | Auto-sync to ~/.claude/skills as final migration step | Manual-copy was the chosen discovery mechanism; syncing on the user's behalf changes their workflow without consent. After the migration, user can `cp -r sebaik-baik-pembina/skills/* ~/.claude/skills/` whenever they want the changes live. |
| Pre-flight commit in coding-agent-skills | One commit of pending plan files immediately before freeze | Leave pending changes dangling; discard them | Pending work (`plans/sdlc-orchestrator.md`, `plans/plan-review-parallel-personas.md`, this migration plan) represents real history. Committing once before the freeze preserves the historical record and makes the "freeze + only ARCHIVED.md edit" rule actually checkable via `git status`. Dangling pending changes would silently violate Acceptance Criterion #9. |

## Review Log

### Review 1 — 2026-06-09
**Flaws found:** 8
**Changes made:**
- Fixed broken `cp` command in Approach Step 1 — **Reason:** Verified on macOS that `cp -r src/* dest/skills/` errors with `cp: dest/skills: Not a directory` when the destination directory doesn't exist (which is the case in `sebaik-baik-pembina/`). Replaced with `mkdir -p dest && cp -R src/. dest/`. The original plan's parenthetical "Creates target if missing" was factually wrong and would have failed at the first step.
- Added Approach Step 0 (pre-flight git state) — **Reason:** Both repos have pending git state the plan ignored. `coding-agent-skills` has 3 staged/untracked plan files (including this migration plan); `sebaik-baik-pembina` has unstaged + staged edits to `v1-brownfield-agent.md` on a fresh branch with "No commits yet". Without addressing pre-flight, AC #9 fails today and the migration commit silently entangles unrelated pending edits.
- Tightened Step 7 scope (which lines in `v1-brownfield-agent.md` to edit, which to preserve, plus required editor's note) — **Reason:** Original wording "surgical edit" was under-specified for a file with 15+ `coding-agent-skills` references spread across active sections (Goal, Architecture, Milestones — must update) AND historical sections (Decisions Log, Review Log — must NOT update or it rewrites the audit trail). The plan now distinguishes the two.
- Added explicit `.gitignore` step (Approach Step 9) and AC — **Reason:** `.DS_Store` already exists in `sebaik-baik-pembina/` root; a wildcard `git add` would silently capture it in the initial commit. One-line zero-risk fix.
- Reworked Step 9 → Steps 10+11, with explicit-path `git add` and "initial commit" framing — **Reason:** `sebaik-baik-pembina` has "No commits yet" — this is the repo's initial commit, which the plan didn't acknowledge. Explicit-path staging prevents `.DS_Store` capture and prevents pre-existing pending edits from being entangled silently.
- Rewrote Acceptance Criterion #9 and added 3 new ACs — **Reason:** AC #9 (`git status shows ONLY ARCHIVED.md`) was unsatisfiable as-written even before the migration started. Now it correctly expects the pre-flight commit to clear the slate first. New ACs verify `.gitignore`, the editor's note, and that the Decisions/Review logs were not edited.
- Expanded Step 7 from path-swap-only to a three-part edit of `v1-brownfield-agent.md` (paths + structural rewrites + new Decisions Log row); added 4 ACs for the structural changes — **Reason:** User confirmed `v1-brownfield-agent.md` is unexecuted, so updating it to describe the post-migration starting state is safe. Path-swap-only would leave the architecture diagram showing 3 repos, M1 step 2 redundantly running `git init`, and M1 step 1 instructing creation of files the migration already created. The expanded scope catches all three structural drifts in one pass while still preserving the Decisions/Review Log historical record via append-only updates.
- Fixed Step 6 + AC for `plan-review-parallel-personas.md`: only edit the Goal-section path (line 5), leave the Review Log occurrence (line 168) intact, add editor's note. Also explicitly confirmed `sdlc-orchestrator.md` needs zero edits — **Reason:** original Step 6 instructed editing both line 5 AND line 168, but line 168 is inside the Review Log. That contradicts the historical-record principle established for `v1-brownfield-agent.md` and the original AC (`grep returns NO matches`) would have failed once the principle was applied consistently. Grep also confirmed `sdlc-orchestrator.md` is self-contained (no `coding-agent-skills` or `sebaik-baik-pembina` references), so it copies verbatim with no edits.

**Still open:**
- None. All identified flaws were directly fixable; no genuine tradeoffs surfaced that need user judgment.

**Architectural premise that does NOT need rewriting (confirmed):** `v1-brownfield-agent.md`'s decision "invoke skills by name from globally-installed `coding-agent-skills`" stays semantically correct after this migration. The skill-discovery mechanism remains `~/.claude/skills/<name>/`; only the *source repo* the user copies from changes. The decisions about discovery and install method don't need editing — only the path/repo references in active architecture sections do.
| `cp` command form | `mkdir -p dest && cp -R src/. dest/` | `cp -r src/* dest/` (original) | Verified on macOS: `cp -r src/* dest/` fails with `cp: dest: Not a directory` when `dest` doesn't exist. The original plan's parenthetical "Creates target if missing" was incorrect. `cp -R src/. dest/` is the POSIX-portable way to copy directory contents into an existing directory. |
| `v1-brownfield-agent.md` edits | Three-part edit during migration: (a) path swaps, (b) structural rewrite of Architecture/M1/Prereq #3 to describe post-migration starting state, (c) append a NEW Decisions Log row; preserve existing Decisions Log and Review Log rows untouched; add editor's note at top | Path swaps only (leave structural drift to a follow-up plan); full file rewrite (rewrites history) | `v1-brownfield-agent.md` is unexecuted, so it's safe to update it to describe the post-migration world from the start (user's call). Path-swap-only would leave the Architecture diagram showing 3 repos, M1 step 2 doing redundant `git init`, and M1 step 1 with stale "create everything" assumptions. Full rewrite would destroy the historical Decisions/Review Log audit trail. The three-part edit reconciles the file with reality while keeping history intact. |
| `.gitignore` in new repo | Add `.gitignore` with `.DS_Store` as part of the initial commit | Skip — let user add later | A `.DS_Store` already exists in `sebaik-baik-pembina/` root (verified). Without `.gitignore`, the initial commit risks capturing it. Adding `.gitignore` is a one-line zero-risk addition that prevents a noisy second commit. |
