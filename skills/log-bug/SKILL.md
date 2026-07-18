---
name: log-bug
description: "Capture a bug into the project's docs/bugs.md engineering memory so the next session — yours or an AI agent's — doesn't re-fight it. Use this skill when the user wants to record a bug, save bug context after a fix, or log what was just diagnosed. Triggers: '/log-bug', 'log this bug', 'save to docs/bugs.md', 'capture this bug', 'add to bug log', 'remember this bug for later'. Drafts a 5-field entry from conversation context, confirms with the user, appends to <projectRoot>/docs/bugs.md."
---

# Log Bug

Capture a bug to the project's `docs/bugs.md`. The Prevention field is the highest-leverage piece — it's the rule that makes the log compound by stopping the *class* of bug from recurring.

## Input

The user wants to record a bug. Triggers:
- They just fixed something and want it captured before context is lost.
- They're mid-discussion and want to log what's been learned so far.
- They explicitly typed `/log-bug` (optionally with a short description argument).

If the conversation hasn't actually discussed a bug, ask: *"What bug do you want to log? Briefly describe symptom and root cause if known."*

## Step 1: Find the project root

Walk up from `cwd` looking for, in order: a `.git/` directory, then a `CLAUDE.md` file. The first parent containing either is the project root.

If walking up reaches `~/` or `/` without finding either, ask the user: *"Which project should this entry go into? Give me a path."*

Target file: `<projectRoot>/docs/bugs.md`.

## Step 2: Draft the entry

5-field format. Use today's date (ISO `YYYY-MM-DD`).

```
YYYY-MM-DD | <project-slug> / <one-line summary>
  Symptom:    <what was observed — user-facing description, no stack traces>
  Root cause: <what was actually wrong, with file:line if known>
  Fix:        <what changed; reference commit if known>
  Prevention: <rule, brief-checklist item, or CLAUDE.md addition that would have caught this earlier>
```

Pre-fill from the conversation:
- **Title:** project slug (from project-root directory name) + short bug title.
- **Symptom:** the observable behavior — what failed, what the user saw.
- **Root cause:** the actual reason, with `file:line` if it came up.
- **Fix:** what changed (and where, if a fix was applied in this session).
- **Prevention:** if the conversation discussed how to prevent the class of bug, fill it. Otherwise leave as `TODO — fill in: what brief constraint, test, or CLAUDE.md rule would have caught this?`

**Be conservative.** If a field has no clear source in the conversation, leave it blank or `TODO`. Don't invent file paths, commit SHAs, or root causes.

## Step 3: Show the draft + confirm

Display the proposed entry. Ask:

> Looks good? Reply `y` to append, `n` to discard, or paste an edited version and I'll use that.

If the user edits inline, use their version verbatim.

## Step 4: Append to docs/bugs.md

- If `<projectRoot>/docs/` does not exist, create the directory first.
- If `<projectRoot>/docs/bugs.md` does not exist, create it with `# Bug log\n\n`.
- Separate from prior entries with `\n---\n\n` so entries are visually distinct.
- Append the entry.
- Confirm: *"Appended to `<absolute path>`."*

If the write fails, report the path and the error. Do NOT retry silently or fall back to writing elsewhere.

## Output Format

After append:

```
### Logged
- File: <projectRoot>/docs/bugs.md
- Title: <title line>
- Prevention: <"TODO" if blank, else first ~80 chars of the prevention text>
```

If Prevention is `TODO`, gently flag: *"The Prevention field is the highest-leverage piece. Fill it before you next read the file — that's what makes the log compound."*

## Rules

- One entry per invocation. Don't batch multiple bugs into one call — if the conversation surfaced several, ask which to log.
- Append-only. Never edit existing entries.
- Never invent: file paths, line numbers, commit SHAs, or root causes that weren't established in the conversation. Leave them blank or ask.
- Project root must contain `.git/` or `CLAUDE.md`. Don't write to a random parent.
- Format is fixed: 5 fields with the exact labels shown. Other tools (pembina context-injection, pembina extract, pembina bug-log-capture) read this file expecting those labels.
- If the user typed `/log-bug` but the conversation has no bug content, ask for the bug — don't fabricate.
