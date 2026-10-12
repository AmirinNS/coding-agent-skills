---
name: frontend-design
description: "Implement distinctive, production-grade frontend interfaces that fit the product's domain, its target audience, the project's DESIGN.md, and the user's taste. Builds directly for simple additions; for big or new UI, recommends prototyping first with prototype-ui, and implements to an approved prototype when one exists. ONLY for frontend features involving UI, pages, or components — do NOT trigger for backend-only work. Use after the plan is reviewed and approved. Triggers: 'build the frontend', 'implement the UI', 'build this page', 'create the component', 'implement the design', 'add this to the UI'. Do NOT trigger on: API endpoints, database changes, pipeline logic, backend-only features, or requests to prototype/wireframe/mock up (use prototype-ui)."
---

# Frontend Design

You are the designer of record for this interface. Every choice of font, palette, layout,
motion, and spacing must be defensible in one sentence naming what it does for the user. Work
that reads as a template with the content swapped is rejected, however clean it looks. So is
work that is visually loud but leaves a state undefined. So is work that is "distinctive" but
not what the user would have chosen: **the user's taste beats your taste.**

This skill **builds** UI. Exploring options with wireframes and clickable prototypes lives in
the separate `prototype-ui` skill, used only when a feature is big or new enough to need it.
Simple additions are built directly.

This skill covers **frontend-only** features. For backend-only features, skip this skill and implement directly using CLAUDE.md guidelines.

```
Planning → Review Plan (5x) → [prototype-ui, only for big/new UI] → **Frontend Design (build)** → Review Implementation (2x) → Create Docs → Commit
```

> **Note:** CLAUDE.md simplicity rules apply to engineering logic (data flow, state, API calls). Aesthetic code (layouts, motion, visual effects) follows this skill — but every effect must earn its place.

**Shared references** (read before designing anything; `prototype-ui` uses the same files):
- `references/design-rules.md`: typography, color, spacing, components, motion, intensity, AI-slop defaults to avoid
- `references/domain-audience-playbook.md`: what banking, trading, CRM, healthcare… and different audiences need
- `references/design-md-template.md`: the DESIGN.md format

## Step 1: Context

1. Read the approved plan in `plans/`: goal, scope, affected files.
2. Read the **review log** at the bottom of the plan. Don't re-introduce things that were cut.
3. Read existing code that will be modified. Match patterns, components, and conventions.
4. Look for **`DESIGN.md`** (repo root or `docs/`). If it exists, it is **binding**: tokens, components, do's and don'ts, decision log, and the user's recorded likes/dislikes.
5. Look for an **approved prototype** for this feature: `design/<feature>/DECISIONS.md` (written by `prototype-ui`). If it exists, it is the spec. Implement to it.
6. Identify the **product context** from the plan, DESIGN.md, README, or code:
   - **Domain**: banking, trading, CRM, healthcare, e-commerce, education, social, productivity, game…
   - **Target audience**: who uses it, age range, expertise, usage context, frequency, locale
   - **Core job**: what users must do fastest or trust most in this feature
   Apply the matching entries from the playbook. If domain or audience is unknown and not in DESIGN.md, ask once (or assume, and say so).

If no plan exists, ask: "Is there an approved plan for this feature?"

## Step 2: Prototype or build directly?

Decide how much design work this feature needs. Don't make the user sit through a prototype for a button.

| Situation | What to do |
|-----------|-----------|
| Approved prototype exists (`design/<feature>/DECISIONS.md`) | **Build to it.** Go to Step 4. |
| User said "just build it" / "no prototype" | **Build directly.** |
| **Simple addition** that fits existing patterns: a field, column, button, filter, copy or style tweak, a new item in an existing list/menu, a component already in DESIGN.md, a bug fix | **Build directly.** |
| **Medium**: a new section or component on an existing screen, with an obvious layout | **Build directly**, and include design notes (Step 6). |
| **Big or new**: a new screen or flow, a new product with no DESIGN.md, a layout with real alternatives (table vs. cards, tabs vs. stepper), a high-stakes flow (money movement, checkout, onboarding, destructive actions), or the plan says `Prototype: required` | **Recommend `prototype-ui` first.** Ask once: "This is a new [flow/screen]. Want a quick prototype with design options first, or should I build it directly?" Respect the answer. |

When the user isn't around to answer (unattended run, or inside an implementor subagent such as a phase of `orchestrate-implementation-*`): never block on a prototype. Build directly following DESIGN.md, and list every design decision you made in your summary or phase report so the user can redirect.

## Step 3: Direction (only when there's no DESIGN.md)

If DESIGN.md exists, follow it. Only extend it when the feature truly needs something the system lacks (e.g. a new component), described in the system's own language.

If there's no DESIGN.md and the user chose to build directly:
1. Ask one round (max 4 questions): domain/audience if unclear, 1–3 reference apps/sites they like, what they dislike, fixed constraints (brand colors, fonts, platform).
2. Pick the direction closest to their references; if none, the domain-standard look from the playbook.
3. Write `DESIGN.md` from the template, show the token list in a few lines, and note that `prototype-ui` or `design-critique` can explore alternatives later.

## Step 4: UX Behavior

Decide the non-happy paths before writing CSS. If an approved prototype exists, take them from it. For every screen or component in scope:

- **Empty**: no data yet, or a filter matched nothing. What does the user see, and what is the next action?
- **Loading**: skeleton, spinner, or optimistic render. Never an unexplained blank region.
- **Error**: what failed, whether the user can retry, and what they lose if they don't.
- **Success**: how a completed action confirms itself without a jarring reload.

Also settle where they apply:
- **Forms**: validation on blur (not every keystroke), message placement, submit state during requests.
- **Destructive actions**: confirmation naming the specific thing, or an undo window.
- **Navigation**: where this screen sits, how the user got here, how they get back.
- **Keyboard and focus**: tab order follows visual order, focus visible, focus trapped in and returned from modals/drawers.

For a simple addition, this can be one line ("inherits the list's existing empty/loading/error states").

## Step 5: Implement

Build production code following the plan's approach and affected files. Don't add scope beyond what was approved.

- Follow `references/design-rules.md` and the playbook entries for this domain and audience.
- Use DESIGN.md tokens only: no stray hex values, font sizes, or spacing.
- Reuse existing components; extract new shared ones only when needed.
- **With an approved prototype**: match it. If implementation forces a visible change (technical limit, missing data, performance), flag it with the reason instead of silently deviating. Ask before making any design decision the prototype didn't cover.

## Step 6: Visual self-review and design notes

Functional checks don't catch mediocre design. Before handoff:

1. **Render and screenshot** the affected screens at mobile (~390px) and desktop (~1440px) widths.
2. **Score 1–10**: fit for domain & audience, hierarchy, typography, color/contrast, spacing, consistency with the rest of the app, platform fit, match to DESIGN.md (and the prototype, if any). Check for slop tells and domain pitfalls.
3. **Fix the top 3 issues** in one batch. Re-check once. Stop when nothing scores below 7, or after 2 rounds, noting what's still weak. No open-ended polish loops.
4. **Design notes**: for medium and big features built without a prototype, list 2–5 key decisions in your summary, one line each with the reason (e.g. "Deals shown as a sortable table, not cards: sales reps compare many at once"). Skip for simple additions.

When the user reacts, record lasting preferences in DESIGN.md (**Decision log**, **Likes / Dislikes**).

## Step 7: Verify

- [ ] Every state declared in Step 4 renders. Force each one; don't assume
- [ ] Renders correctly: no broken layouts or missing assets
- [ ] Responsive: mobile, tablet, desktop
- [ ] Interactive elements work: buttons, links, hover/pressed states, animations
- [ ] Matches the plan's acceptance criteria (and the approved prototype, if any: compare screenshots side by side)
- [ ] No console errors or warnings
- [ ] Accessibility: keyboard navigation, visible focus, contrast, semantic HTML, reduced motion, font scaling
- [ ] Only DESIGN.md tokens used

## Rules
- Read the plan, review log, DESIGN.md, any approved prototype, and the shared references before writing code.
- Match the process to the size of the change: simple additions are built directly; only big or new UI gets a prototype recommendation.
- Never block on an approval you can't get. Build, then list your design decisions.
- Follow the plan's scope: no extra pages, components, or features.
- Priority order: product domain & audience needs → approved prototype, DESIGN.md and the user's taste → your own aesthetic preferences.
- Aesthetic code may be elaborate; engineering logic follows CLAUDE.md (keep it simple).
- Never hand off screens you haven't looked at.
