---
name: design-critique
description: Review an existing screen or user flow for usability, accessibility, and visual design. Use for focused UX findings on screenshots, prototypes, code, or running interfaces, or to explore redesign options for an existing UI. Route production UI changes to frontend-design.
---

# Design critique

## Choose the workflow

- **Review.** For requests such as “review this checkout” or “what feels off on this screen?”, inspect the current experience and deliver prioritized findings with repeatable checks.
- **Redesign exploration.** For requests to see different design directions for an existing interface, start with a short critique, then follow the [redesign workflow](references/redesign.md).
- **Production implementation.** For requests to build or apply a redesign in the app or codebase, use `frontend-design`. Use the review findings as acceptance checks when both review and implementation are requested.

## Set the context

Identify the product domain, audience, platform, and task. Find what the user needs to decide and how they know they succeeded. Read the relevant screens, code, existing `DESIGN.md`, and approved design when available. State assumptions that affect the review.

For a broad visual critique, consider the relevant [design rules](../frontend-design/references/design-rules.md) and [domain and audience guidance](../frontend-design/references/domain-audience-playbook.md) when available. Apply the product's own tokens and platform conventions.

## Review the experience

Walk from the entry point through decisions, actions, and the completion signal. Check recovery paths that could stop the task, such as failed submission, an empty filter result, or going back in a multistep form. For a screenshot, report visible evidence and state the behavior to verify in the running interface.

Apply the checks that matter to the task.

- **Cognitive load.** Keep information and controls needed for the current decision visible. Group related items, give sections specific labels, and reveal optional details on demand. Preserve side-by-side comparison when it serves the task.
- **Hierarchy and spacing.** Use primary button styling for a clear next action. Give equivalent choices equal emphasis. Tighten spacing within groups, separate groups, and check icon and label alignment.
- **Readability and color.** Check contrast against actual backgrounds in relevant states and themes. Give meaning a visible cue alongside color. Test type with real labels, numbers, and longer strings, including line height and letter spacing.
- **Responsive behavior.** Preserve task order, essential details, and actions at narrow and intermediate widths. Find where real content stops fitting. Check the same task with keyboard and touch where supported.
- **Forms and steps.** Keep labels visible after entry. Tie errors to fields, explain the correction, and preserve valid input on retry. For distinct stages, show progress and preserve entries when users go back.
- **Feedback and recovery.** Distinguish initial load from refresh. Have skeletons reserve space for the content. Keep useful existing content visible during refresh and show progress. Confirm what changed on success and give a next action when needed. Explain how to recover from failure and keep focus logical.
- **Motion and speed.** Check that selection, progress, and completion stay clear with reduced motion. For media-heavy screens, check when content and controls become available on a representative mobile connection.

For a broad screen critique, describe the first impression and what works. Consider visual consistency, copy, platform fit, and fit for the product's audience. For game screens, consider game-state readability, HUD clutter, feedback, and the player's next action. Use a 1–10 scorecard when a broad comparison or before-and-after assessment helps the user decide.

Use the [focused checks and source examples](references/focused-checks.md) for web accessibility, performance, and specific interaction examples.

## Deliver findings

Lead with the issues that most affect task completion. For each, give the screen or state, the observation, the user impact, a specific fix, and a check someone can repeat. Use concrete values when the evidence supports them. Label predicted behavior as a hypothesis until tested.

For review requests, hand off the findings and any checks that still need a live interface. When implementing an authorized fix, reuse existing components, keep the scope to the affected flow, and check the affected state before and after where possible.
