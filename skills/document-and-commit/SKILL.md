---
name: document-and-commit
description: "Document a completed feature and commit it in one step. Combines create-docs (developer documentation from the change set) with generate-commit (conventional commit). Use as the final step after implementation and review are done. Stages the work, writes docs, stages the docs, then commits. Triggers: 'document and commit', 'docs and commit', 'finalize', 'wrap up', 'ship it', 'finish the feature'."
---

# Document and Commit

You are a senior software engineer. This is the final step in the workflow — the code is implemented and reviewed. Your job is to document what was built, stage everything, and commit it with a conventional message.

Two phases, run in order:

1. **Document** — write developer-focused docs for the delivered feature.
2. **Stage and Commit** — stage the implementation and the new docs, then commit.

## Phase 1: Document

### Step 0: Load Target Conventions

Before any analysis or writing, read the project's conventions file (`CLAUDE.md` or `AGENTS.md`, whichever exists), plus `README.md` and (if present) `docs/`, from the current working directory. If neither `CLAUDE.md` nor `AGENTS.md` exists, halt and ask the user before proceeding.

If the conventions file (`CLAUDE.md` or `AGENTS.md`) contradicts the plan being documented, surface the contradiction to the user. Do not silently document something the project's own conventions reject.

### Step 1: Gather Context

#### Step 1a: Resolve the Change Set

Documentation should cover all the work delivered for this feature — which may have been committed across multiple milestones, not just left in the staging area. Resolve the change set as follows:

1. **Detect base ref.** Try in order: `git rev-parse --verify main` → `git rev-parse --verify master` → `git symbolic-ref refs/remotes/origin/HEAD`. The first that succeeds is the base ref. If none succeed, fall back to staged-only (see step 3).
2. **Compute the committed range.** `merge_base = git merge-base HEAD <base_ref>`. If `merge_base == HEAD`, there's no committed divergence — fall back to staged-only. Otherwise the committed delta is `git diff <merge_base>..HEAD`.
3. **Build the full change set.** Union of `git diff <merge_base>..HEAD` (committed) AND `git diff --cached` (staged). Both feed documentation.
4. **Empty change set rule.** If BOTH the committed range and the staged delta are empty, **stop and tell the user to stage or commit their changes first** — there is nothing to document or commit.

State which mode you're using up front: "Documenting committed range `abc1234..HEAD` plus staged changes" or "Documenting staged changes only (no base ref divergence)."

#### Step 1b: Read These Sources

1. **The plan file** (in `plans/`) — what was intended, including the review log showing how the plan evolved. This is your primary reference for understanding the feature's goal, scope, and decisions made during review.
2. **The change-set diff** (from Step 1a) — the actual code delta. This is the source of truth for what was built.
3. **The implementation files** — read the full files touched in the diff for context beyond the diff itself.
4. **The tests** — understand what's tested and how.

The plan tells you *why* and *what was intended*. The diff tells you *what was actually built*. When they differ, document what was built, but note significant deviations.

### Step 2: Determine Doc Scope

Check if the plan file specifies which docs to create (look for a "Docs files to create/update" field). If it does, follow that.

If not, determine what's needed based on the change:

**Always document:**
- What the feature does (user-facing behavior)
- How to use it (commands, API, UI flow)

**Document if applicable:**
- Configuration or environment variables added
- Schema or data changes
- New CLI commands or flags
- API endpoints added or changed

**Skip unless asked:**
- Internal architecture explanations
- Code-level documentation (that belongs in the code)
- Deployment or ops procedures for simple features

### Step 3: Write the Documentation

Write developer-focused docs. Keep it practical — someone should be able to read the doc and use the feature.

#### Template

```markdown
# [Feature Name]

## Overview
[1-3 sentences: what this feature does and why it exists]

## Usage
[How to use the feature — commands, API calls, UI steps, etc.]

## Configuration
[Any new env vars, config entries, or settings. Skip if none.]

## Data
[Schema changes, new tables/columns, data flow. Skip if none.]

## Examples
[Concrete usage examples. At least one.]

## Notes
[Gotchas, limitations, or non-obvious behavior. Skip if none.]
```

Adapt the template to fit the feature. Omit sections that don't apply. Add sections if the feature needs them. Don't pad empty sections.

### Step 4: Verify

After writing, re-read the change-set diff (from Step 1a) and verify:
- Every user-facing change is documented (new commands, endpoints, UI flows, config)
- No documented behavior contradicts the actual code
- Examples actually work with the implemented code

### Step 5: Absorb the Plan

The `plans/` folder is a working queue — once a feature is documented, its plan has served its purpose. Absorb the plan's valuable context into the final doc, then clean up:

1. **Merge plan context into the doc.** Add these sections to the documentation:

```markdown
## Design Decisions
| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
(Pulled from the plan's Decisions Log)

## Review History
(Condensed summary from the plan's Review Log — key changes and reasoning, not the full iteration-by-iteration log)
```

2. **Keep the plan file in `plans/`.** It is committed with the work, so don't skip it or leave it unstaged. The doc summarizes what was built; the plan stays in the repo as the record of intent.

Omit "Design Decisions" if the plan had no decisions log. Omit "Review History" if there was no review log. Don't add empty sections.

### Step 6: Save

1. Save docs to the location specified in the plan or project's docs directory.
2. If the plan specified doc file paths, use those exactly.
3. Report what was documented and what was absorbed from the plan.

## Phase 2: Stage and Commit

### Step 7: Stage Everything

Stage the feature files, the plan file (in `plans/`), AND the newly written docs with `git add`.

Before committing, run `git diff --cached` and confirm the staged diff contains the feature work, the plan file, and the docs.

If nothing is staged, stop and tell the user: "No staged changes found. Stage your changes with `git add` first."

Also run `git diff` to check for unstaged changes. If there are unstaged changes, mention what's unstaged so the user can decide what to stage.

### Step 8: Analyze the Diff

Read the staged diff and determine:
- **What changed**: files modified, added, deleted
- **Why it changed**: the purpose of the change (feature, fix, refactor, etc.)
- **What's the main change**: if multiple things changed, identify the primary one

If the feature code was already committed and only docs are staged, the main change is documentation — use the `docs` type. If the feature code and docs are staged together, the type reflects the feature.

If the plan file exists for this work (check `plans/`), reference it to understand intent. But the diff is the source of truth.

### Step 9: Generate Commit Message

Use conventional commits format:

```
<type>(scope): <description>

[body — only if the change is non-obvious]

[footer — only for breaking changes or issue refs]
```

#### Types
- **feat**: new feature or functionality
- **fix**: bug fix
- **docs**: documentation only
- **style**: formatting, whitespace (no logic change)
- **refactor**: code restructuring (no feature/fix)
- **perf**: performance improvement
- **test**: adding or fixing tests
- **build**: build system or dependency changes
- **ci**: CI/CD changes
- **chore**: maintenance, tooling

#### Scope
- Derive from the primary directory or module changed (e.g., `api`, `ui`, `db`, `pipeline`, `server`)
- If changes span multiple scopes, use the most significant one or omit scope
- Keep lowercase

#### Description
- Imperative mood: "add" not "added" or "adds"
- Lowercase first letter
- No period at end
- Max 50 characters
- Focus on *what* the change does, not *how*

#### Body (only when needed)
- One blank line after description
- Explain *what* and *why*, not *how* — the diff shows how
- Wrap at 72 characters
- Use for: multi-file changes, non-obvious decisions, context that isn't in the code

#### Footer (only when needed)
- `BREAKING CHANGE: <description>` for breaking changes
- `Refs: #<issue>` for issue references

### Step 10: Present and Commit

1. Show the generated commit message to the user
2. Create the commit using the message
3. Show `git log --oneline -1` to confirm

## Rules

- Document what was built, not what was planned. Read the code.
- Keep it short. If the feature is simple, the doc should be short.
- Write for developers who will use or maintain this feature, not for stakeholders.
- Use concrete examples over abstract descriptions.
- Don't repeat information already in the code (docstrings, inline comments).
- Don't document internal implementation details unless they affect usage.
- Match the tone and style of existing docs in the project.
- If existing docs need updating because of this feature, update them rather than creating duplicates.
- Commit the plan file with the work. Don't skip or leave `plans/` files unstaged. Absorb the plan's decisions and review history into the doc, but keep the plan in the repo as the record of intent. Don't delete plan files.
- Never commit without staged changes.
- Never commit files that look like secrets (`.env`, credentials, tokens). Warn the user if these are staged.
- One commit per logical change. If the staged diff has unrelated changes, suggest splitting.
- The commit message describes the *result*, not the *process*. "add validation" not "wrote code to validate".
- Don't over-explain simple changes. A one-line fix gets a one-line message.
- If the diff is large and unclear, ask the user what the main intent was rather than guessing.
