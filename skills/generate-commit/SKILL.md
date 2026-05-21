---
name: generate-commit
description: "Generate a conventional commit message from staged changes and commit. Use this skill when the user asks to commit, create a commit, or write a commit message. Triggers: 'generate commit', 'commit this', 'create a commit', 'commit changes'. Analyzes staged diff, generates a conventional commit message, and commits."
---

# Commit

Generate a conventional commit message from staged changes and create the commit.

## Step 1: Check Staged Changes

Run `git diff --cached` to see what's staged.

If nothing is staged, **stop and tell the user**: "No staged changes found. Stage your changes with `git add` first."

Also run `git diff` to check for unstaged changes. If there are unstaged changes but nothing staged, mention what's unstaged so the user can decide what to stage.

## Step 2: Analyze the Diff

Read the staged diff and determine:
- **What changed**: files modified, added, deleted
- **Why it changed**: the purpose of the change (feature, fix, refactor, etc.)
- **What's the main change**: if multiple things changed, identify the primary one

If the plan file exists for this work (check `plans/`), reference it to understand intent. But the diff is the source of truth.

## Step 3: Generate Commit Message

Use conventional commits format:

```
<type>(scope): <description>

[body — only if the change is non-obvious]

[footer — only for breaking changes or issue refs]
```

### Types
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

### Scope
- Derive from the primary directory or module changed (e.g., `api`, `ui`, `db`, `pipeline`, `server`)
- If changes span multiple scopes, use the most significant one or omit scope
- Keep lowercase

### Description
- Imperative mood: "add" not "added" or "adds"
- Lowercase first letter
- No period at end
- Max 50 characters
- Focus on *what* the change does, not *how*

### Body (only when needed)
- One blank line after description
- Explain *what* and *why*, not *how* — the diff shows how
- Wrap at 72 characters
- Use for: multi-file changes, non-obvious decisions, context that isn't in the code

### Footer (only when needed)
- `BREAKING CHANGE: <description>` for breaking changes
- `Refs: #<issue>` for issue references

## Step 4: Present and Commit

1. Show the generated commit message to the user
2. Create the commit using the message
3. Show `git log --oneline -1` to confirm

## Examples

Simple feature:
```
feat(scraper): add hashtag support for instagram
```

Bug fix with context:
```
fix(db): prevent duplicate deals on concurrent pipeline runs

The upsert was racing on post_url uniqueness check. Added
SELECT FOR UPDATE to lock the row during insert-or-update.
```

Multi-file refactor:
```
refactor(extractors): consolidate gemini prompt builders

Merged threads_gemini and instagram_gemini prompt logic into
deals_gemini_core to reduce duplication across processors.
```

Docs only:
```
docs: add email scraper usage to README
```

Breaking change:
```
feat(api)!: change deals endpoint response format

Switched from flat array to paginated envelope with metadata.
All consumers must update to handle the new response shape.

BREAKING CHANGE: GET /api/deals now returns { data: [], meta: {} }
instead of a flat array
```

## Rules
- Never commit without staged changes.
- Never commit files that look like secrets (`.env`, credentials, tokens). Warn the user if these are staged.
- One commit per logical change. If the staged diff has unrelated changes, suggest splitting.
- The commit message describes the *result*, not the *process*. "add validation" not "wrote code to validate".
- Don't over-explain simple changes. A one-line fix gets a one-line message.
- If the diff is large and unclear, ask the user what the main intent was rather than guessing.
