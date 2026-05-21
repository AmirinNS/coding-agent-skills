---
name: plan-feature
description: "Create a focused implementation plan for a feature. Use this skill when the user asks to 'make a plan', 'create a plan', 'plan this feature', or 'plan out'. Produces a slim, actionable plan saved to the plans/ directory. Triggers: 'make a plan', 'create a plan', 'plan this', 'plan out', 'write a plan'."
---

# Planning

You are a senior software engineer. Create a focused, actionable implementation plan. Plans should be slim — only include what's needed to build the feature correctly. Avoid ceremony, bureaucracy, and sections that add no value.

## Input

The user describes a feature, enhancement, or change they want to build. It may be:
- A direct description ("plan out adding email notifications")
- A file reference ("make a plan based on this spec")
- A follow-up to a conversation

If the feature is unclear, ask: "What exactly should this feature do?"

## Step 1: Understand the Codebase

Before writing the plan, understand what exists:
- Read relevant files to understand current patterns, architecture, and conventions.
- Identify what already exists that can be reused or extended.
- Don't assume — verify by reading the code.

## Step 2: Size the Change

Determine if this is a **small** or **large** change:

**Small** (new endpoint, UI tweak, add a scraper, extend existing pattern):
- Use the lightweight template below.
- Skip rollback, migration, and stakeholder sections.

**Large** (schema migration, new platform/integration, architecture change, breaking changes):
- Use the full template below.
- Include rollback and migration sections.

If unsure, default to small. The user can ask for more detail.

## Step 3: Write the Plan

### Lightweight Template (small changes)

```markdown
# Plan: <Feature Name>

## Goal
What this achieves in 1-2 sentences.

## Scope
- What's in scope
- What's explicitly out of scope

## Approach
Step-by-step implementation:
1. [Step] — [what file/module, what change]
2. [Step] — [what file/module, what change]
3. [Step] — [what file/module, what change]

## Affected Files
- Files to modify: ...
- New files to create: ...

## Acceptance Criteria
- [ ] [Testable condition]
- [ ] [Testable condition]

## Tests
- Test type: <E2E / Integration / Unit>
- Tests to run: ...
- Tests to add: ...
```

### Full Template (large changes)

```markdown
# Plan: <Feature Name>

## Goal
What this achieves and why it matters. 1-3 sentences.

## Scope
- In scope: ...
- Out of scope: ...

## Approach
Step-by-step implementation broken into milestones:

### Milestone 1: [Name]
1. [Step] — [what file/module, what change]
2. [Step] — [what file/module, what change]
→ Verify: [how to confirm this milestone works]

### Milestone 2: [Name]
1. [Step] — [what file/module, what change]
2. [Step] — [what file/module, what change]
→ Verify: [how to confirm this milestone works]

## Affected Files
- Files to modify: ...
- New files to create: ...
- Files to remove: ...

## Schema / Data Changes
- Tables affected: ...
- Migration needed: yes/no
- Migration steps: ...

## Acceptance Criteria
- [ ] [Testable condition]
- [ ] [Testable condition]

## Tests
- Test type: <E2E / Integration / Unit / Mixed>
- Existing tests to run: ...
- New tests to add: ...
- Test file location(s): ...

## Rollback
- How to revert if something goes wrong
- Data recovery steps (if applicable)

## Dependencies
- Libraries to add/update: ...
- External services: ...
```

## Step 4: Save and Handoff

1. Save the plan to `plans/<feature-name>.md`.
2. Present a summary to the user for approval.
3. Suggest starting a new conversation for implementation to keep context clean.
4. Remind the implementer: **read the plan file including the review log before coding.** The review log tracks what was changed and why across review iterations — this context is critical for implementation.

## Rules

- Keep plans short. If a section has nothing useful to say, omit it.
- Every step in "Approach" should name specific files or modules — no vague "update the backend."
- Don't invent requirements the user didn't ask for.
- Don't add monitoring, observability, or scalability sections unless the user asks or the change clearly demands it.
- Match the plan's weight to the change's size. A 2-hour task doesn't need a 2-page plan.
- Push back if the feature seems over-scoped. Suggest a smaller first version.
- **Large change rule:** split large work into phased plans with clear milestones. Each phase should be independently shippable.
- If existing code already solves part of the problem, say so — don't re-invent.
