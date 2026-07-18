---
name: log-decision
description: "Capture a non-trivial decision into the project's docs/decisions.md for ownership evidence and future reference. Use this skill when the user wants to record a decision, log a choice made, save reasoning for later, or capture an override/deferral. Triggers: '/log-decision', 'log this decision', 'save to docs/decisions.md', 'add to decision log', 'capture this choice', 'remember why we did this'. Drafts a 3-field entry (date | decision | reason) from conversation context, confirms with the user, appends to <projectRoot>/docs/decisions.md."
---

# Log Decision

Capture a non-trivial decision to the project's `docs/decisions.md`. Over time these accumulate into the CTO-facing evidence of *what you decided and why* — the artifact that replaces commits as proof of management work.

## Input

The user wants to record a decision. Triggers:
- They just made a non-trivial choice (overrode an agent, deferred something, picked between alternatives).
- They want to capture the reasoning before it fades.
- They explicitly typed `/log-decision`.

A **decision** is *"X or Y, and here's why"* — a judgment call between alternatives. A **task** is *"do X"* — executable work. Tasks are not decisions. If the conversation only contains tasks, ask: *"What decision do you want to log? Describe the choice and the reason in one sentence each."*

## Step 1: Find the project root

Walk up from `cwd` looking for, in order: a `.git/` directory, then a `CLAUDE.md` file. The first parent containing either is the project root.

If walking up reaches `~/` or `/` without finding either, ask the user: *"Which project should this entry go into? Give me a path."*

Target file: `<projectRoot>/docs/decisions.md`.

## Step 2: Draft the entry

3-field format. One line. Use today's date (ISO `YYYY-MM-DD`).

```
YYYY-MM-DD | <decision in one sentence>. Reason: <reason in one sentence>.
```

Examples:

```
2026-06-18 | Pushed back on "make the chart real-time" — added 5s polling instead. Reason: WebSocket infra not justified for <10 active users.
2026-06-18 | Shipped AI's first auth fix as-is. Reason: works, change is reversible, deeper refactor is a separate ticket.
2026-06-18 | Escalated Bursa holiday-handling logic to CTO before merging. Reason: affects settlement timing across all FCPO contracts.
2026-06-18 | Declined to add notifications feature this sprint. Reason: only one user has asked and we have unresolved auth work that blocks them anyway.
```

Pre-fill from the conversation. If the *reason* is unclear, ask the user — the reason field is the whole point. Never fabricate a reason.

If the decision needs more than a sentence to summarize, it's two decisions. Log them separately.

## Step 3: Show the draft + confirm

Display the proposed entry. Ask:

> Looks good? Reply `y` to append, `n` to discard, or paste an edited version and I'll use that.

If the user edits inline, use their version verbatim.

## Step 4: Append to docs/decisions.md

- If `<projectRoot>/docs/` does not exist, create the directory first.
- If `<projectRoot>/docs/decisions.md` does not exist, create it with `# Decision log\n\n`.
- Append the entry on a new line. No separators between entries — entries are short and chronological reads cleaner this way.
- Confirm: *"Appended to `<absolute path>`."*

If the write fails, report the path and the error. Do NOT retry silently.

## Output Format

After append:

```
### Logged
- File: <projectRoot>/docs/decisions.md
- Entry: <full entry text>
```

## Rules

- One decision per invocation. Don't batch.
- Append-only. Never edit existing entries.
- The *reason* field is non-negotiable. Don't accept an entry without a real reason. If the user can't articulate why, ask. *Recording the reason is the whole point.*
- Don't log tasks. *"Implemented user search"* is a task. *"Chose Algolia over Postgres FTS for search because of typo-tolerance requirements"* is a decision.
- Decisions to deliberately **NOT** do something are often the highest leverage — log those aggressively. *"Declined feature X because Y"* is a real and important entry.
- Never invent reasons. If the conversation doesn't establish *why*, ask the user before drafting.
- Format is fixed: one line, three fields with the exact labels and pipe (`|`) shown. Other tools (pembina extract, pembina report, dashboard) may parse by this format.
- Project root must contain `.git/` or `CLAUDE.md`. Don't write to a random parent.
