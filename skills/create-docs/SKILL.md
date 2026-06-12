---
name: create-docs
description: "Generate documentation for a completed feature implementation. Use this skill as the final step after implementation and review are done. Triggers: 'create docs', 'generate docs', 'write docs', 'document this feature', 'create documentation'. Reads the plan, review log, and implementation to produce accurate, developer-focused documentation."
---

# Create Docs

You are a senior software engineer. Generate documentation for a feature that has been implemented and reviewed. This is the final step in the workflow — the code is done, reviewed, and working. Your job is to document what was built, not what was planned.

## Input

The user asks to document a completed feature. They may provide:
- A plan file path (e.g., "create docs for plans/email-scraper.md")
- A feature name or description
- A reference to recent work

If unclear, ask: "Which feature should I document?"

## Step 0: Load Target Conventions

Before any analysis or writing, read `CLAUDE.md`, `README.md`, and (if present) `docs/` from the current working directory. If `CLAUDE.md` is missing, halt and ask the user before proceeding.

If `CLAUDE.md` contradicts the plan being documented, surface the contradiction to the user. Do not silently document something the project's own conventions reject.

## Step 1: Gather Context

### Step 1a: Resolve the Change Set

Documentation should cover all the work delivered for this feature — which may have been committed across multiple milestones, not just left in the staging area. Resolve the change set as follows:

1. **Detect base ref.** Try in order: `git rev-parse --verify main` → `git rev-parse --verify master` → `git symbolic-ref refs/remotes/origin/HEAD`. The first that succeeds is the base ref. If none succeed, fall back to staged-only (see step 3).
2. **Compute the committed range.** `merge_base = git merge-base HEAD <base_ref>`. If `merge_base == HEAD`, there's no committed divergence — fall back to staged-only. Otherwise the committed delta is `git diff <merge_base>..HEAD`.
3. **Build the full change set.** Union of `git diff <merge_base>..HEAD` (committed) AND `git diff --cached` (staged). Both feed documentation.
4. **Empty change set rule.** If BOTH the committed range and the staged delta are empty, **stop and remind the user to commit or stage their changes first** — there is nothing to document.

State which mode you're using up front: "Documenting committed range `abc1234..HEAD` plus staged changes" or "Documenting staged changes only (no base ref divergence)."

### Step 1b: Read These Sources

1. **The plan file** (in `plans/`) — what was intended, including the review log showing how the plan evolved. This is your primary reference for understanding the feature's goal, scope, and decisions made during review.
2. **The change-set diff** (from Step 1a) — the actual code delta. This is the source of truth for what was built.
3. **The implementation files** — read the full files touched in the diff for context beyond the diff itself.
4. **The tests** — understand what's tested and how.

The plan tells you *why* and *what was intended*. The diff tells you *what was actually built*. When they differ, document what was built, but note significant deviations.

## Step 2: Determine Doc Scope

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

## Step 3: Write the Documentation

Write developer-focused docs. Keep it practical — someone should be able to read the doc and use the feature.

### Template

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

## Step 4: Verify

After writing, re-read the change-set diff (from Step 1a) and verify:
- Every user-facing change is documented (new commands, endpoints, UI flows, config)
- No documented behavior contradicts the actual code
- Examples actually work with the implemented code

## Step 5: Absorb the Plan

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

2. **Leave the plan file in `plans/`.** Plans are gitignored and not committed — the user will clean them up manually when they're no longer needed. The doc is now the single source of truth for this feature.

Omit "Design Decisions" if the plan had no decisions log. Omit "Review History" if there was no review log. Don't add empty sections.

## Step 6: Save and Report

1. Save docs to the location specified in the plan or project's docs directory.
2. If the plan specified doc file paths, use those exactly.
3. Present a summary to the user: what was documented and what was absorbed from the plan.

## Rules
- Document what was built, not what was planned. Read the code.
- Keep it short. If the feature is simple, the doc should be short.
- Write for developers who will use or maintain this feature, not for stakeholders.
- Use concrete examples over abstract descriptions.
- Don't repeat information already in the code (docstrings, inline comments).
- Don't document internal implementation details unless they affect usage.
- Match the tone and style of existing docs in the project.
- If existing docs need updating because of this feature, update them rather than creating duplicates.
- **Plans are gitignored and not committed.** The doc is the only permanent record of design decisions and review history. Absorb everything valuable into the doc. Don't delete plan files — the user manages cleanup manually.
