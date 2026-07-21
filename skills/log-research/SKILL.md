---
name: log-research
description: "Capture the output of a research / discussion session with the model into a research log so insights aren't lost. Handles two modes: a quick mid-conversation SNAPSHOT of a single insight, or an end-of-session SUMMARY that rolls up the whole discussion. Routes to per-project docs/research.md when the research is about one codebase, or to the central ~/Projects/research.md vault when it spans projects. Use when the user wants to note a finding, capture an insight, or summarize a discussion. Triggers: '/log-research', 'note this', 'capture this insight', 'log this finding', 'save this research', 'summarize our discussion', 'wrap up this discussion', 'write up what we found'. Drafts the entry from conversation context, confirms with the user, appends to the chosen research file."
---

# Log Research

Capture what a research / back-and-forth discussion with the model produced, so the conclusions survive after the conversation scrolls away. These accumulate into a durable research log — the record of *what you explored and what you learned*.

This skill is the research counterpart to `[[log-decision]]` and `[[log-bug]]`: same shape (draft → confirm → append), different content and destination logic.

## Input

The user wants to record research output. Two modes — detect which from the trigger and context:

- **Snapshot** — a single insight captured mid-discussion. Triggers: "note this", "capture this insight", "log this finding". Scope = the one point in front of you.
- **Summary** — a rollup of the whole discussion so far. Triggers: "summarize our discussion", "wrap up", "write up what we found". Scope = the entire research thread in the conversation.

If it's genuinely ambiguous which mode the user wants, ask: *"Snapshot of this one insight, or a full summary of the discussion?"* Default to **snapshot** if they just pointed at a specific thing, **summary** if they're closing out a session.

## Step 1: Choose the destination

Two possible targets:

- **Per-project** — `<projectRoot>/docs/research.md`. Use when the research is about one specific codebase.
- **Central vault** — `~/Projects/research.md`. Use when the research spans multiple projects, is exploratory, or isn't tied to a single codebase.

Decide like this:

1. Walk up from `cwd` looking for a `.git/` directory. The first parent containing one is a candidate `projectRoot`.
   - Note: `~/Projects` itself is a workspace root, **not** a project — its `CLAUDE.md` declares it holds 60+ independent projects. Do not treat it as a `projectRoot`.
2. If a real `projectRoot` was found **and** the research is clearly about that one project → target `<projectRoot>/docs/research.md`.
3. If no project root was found (you're at the `~/Projects` workspace level), **or** the discussion clearly spans multiple projects → target `~/Projects/research.md`.

State your chosen destination in the confirm step (Step 3) so the user can redirect it with one word. When unsure, propose the central vault — a stray entry there is easy to find; a stray entry buried in a project's `docs/` is not.

## Step 2: Draft the entry

Use today's date (ISO `YYYY-MM-DD`). Pre-fill everything from the conversation. Never fabricate findings — if the discussion didn't establish something, leave it out or ask.

**Snapshot** format — short, a title plus 1–3 sentences:

```
## YYYY-MM-DD — <short title>

<the insight, in 1–3 sentences. Include the "so what" — why it matters.>
```

**Summary** format — structured rollup:

```
## YYYY-MM-DD — <topic title>

**Explored:** <what question / area the discussion was about, one sentence>

**Key findings:**
- <finding>
- <finding>

**Open questions / next steps:**
- <anything unresolved or worth following up>
```

Rules for the draft:
- Keep findings concrete. "X is faster than Y because Z" beats "discussed performance."
- Omit the "Open questions" block from a summary only if there genuinely are none.
- If a summary would run past ~10 bullet points, the discussion covered multiple topics — offer to split it into separate entries.

## Step 3: Show the draft + confirm

Display the proposed entry **and** the destination path. Ask:

> Destination: `<absolute path>`. Look good? Reply `y` to append, `n` to discard, `here`/`central` to switch destination, or paste an edited version and I'll use that.

If the user edits inline, use their version verbatim. If they redirect the destination, re-resolve the path and re-confirm the path only.

## Step 4: Append to the research file

- If the target directory does not exist (e.g. `<projectRoot>/docs/`), create it first.
- If the target file does not exist, create it with `# Research log\n\n`.
- Append the entry after a blank line, so entries stay visually separated (unlike the one-line decision log, these are multi-line blocks).
- Confirm: *"Appended to `<absolute path>`."*

If the write fails, report the path and the error. Do NOT retry silently.

## Output Format

After append:

```
### Logged
- Mode: snapshot | summary
- File: <absolute path>
- Entry title: <the ## heading>
```

## Rules

- One coherent entry per invocation. A snapshot is one insight; a summary is one discussion. Don't batch unrelated topics — split them.
- Append-only. Never edit or reorder existing entries.
- Never fabricate findings. Capture only what the discussion actually established. If the user asks for a summary of a thin discussion, say so rather than padding it.
- The destination decision is yours to propose but the user's to override — always show the path before writing.
- `~/Projects` is a workspace root, not a project. Central entries go in `~/Projects/research.md`; project entries need a real `.git/`-bearing `projectRoot`.
- Keep house-style prose: plain, concrete, no filler. This is a personal log, not a report for an audience.
