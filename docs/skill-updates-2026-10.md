# Skill Updates: prototype-ui, frontend-design split, and shared design references

## Overview

The design work in this repo was one skill doing two jobs: deciding what a UI should look
like, and building it. It is now split. `prototype-ui` explores wireframes, style
directions, and clickable prototypes with a design-decisions table, and stops at your
approval. `frontend-design` builds production UI, either directly for simple additions or
to an approved prototype. Both read the same three reference files, which now hold the
concrete design rules that used to live inline in `frontend-design`.

## New Skills

### prototype-ui

Explores what a UI should look like before anything is built. Throwaway design work, not
production code. Triggered by "prototype this", "wireframe this", "mock this up", "show me
design options", "what should this screen look like", or by a `frontend-design`
recommendation on big or new UI.

Scope. A prototype is for big or new UI only: new screens and flows, a new product with no
`DESIGN.md`, a layout with real alternatives, or a high-stakes flow (money movement,
checkout, onboarding, destructive actions). For a new field or button, skip it and let
`frontend-design` build directly.

A fidelity ladder keeps the work proportional to the question. "Which looks better?" runs
variants only. "How should this flow be laid out?" runs wireframes then a prototype. "What
visual style should the product have?" runs direction then a prototype of one key screen.

Steps:

1. **Context.** Read the plan and its review log, `DESIGN.md` (binding if present), the
   screens this feature sits next to, and the domain, audience, and core job.
2. **Direction.** Only when there is no `DESIGN.md` or the user wants a new look. One round
   of max 4 questions (references they like, what they dislike, fixed constraints), then
   4 to 6 static previews of one key screen in clearly different directions, including one
   domain-standard and one wildcard. The user picks or mixes. Tokens get locked in
   `DESIGN.md`.
3. **States.** Empty, loading, error, success, plus forms, destructive actions, navigation,
   and keyboard/focus.
4. **Wireframes.** Grayscale, no styling. Two or three genuinely different layouts where a
   real choice exists (table vs. cards, tabs vs. stepper, modal vs. page). Real-looking
   content, never lorem ipsum. Each option gets why it works and its trade-off, then a
   recommendation.
5. **Prototype and rationale.** Standalone HTML under `design/<feature>/prototype/` by
   default, or in-app variants on a throwaway route switched with `?variant=a|b|c` when the
   app already runs. Includes a state switcher and a design-decisions table covering layout,
   primary action placement, typography and numbers, color, density, navigation, and motion.
   Every reason is one sentence tied to the domain, audience, core job, or the user's taste.
6. **Approval.** Iterate until the user approves. Unattended runs finish with the
   recommended option and mark it not yet approved.
7. **Record.** Write `design/<feature>/DECISIONS.md` (approved variant, decision table,
   states, open questions, prototype location), append lasting decisions to `DESIGN.md`,
   delete in-app variant routes, and hand off in one line.

## New Shared References

Three reference files under `skills/frontend-design/references/`, read by both skills:

- `design-rules.md`. Typography (one family, defined scale, tabular numerals), color
  (tokens only, roughly 60/30/10, WCAG AA in light and dark), spacing (4/8pt scale),
  components (one radius/elevation/icon scale, touch targets), motion (150 to 300ms,
  respect `prefers-reduced-motion`), and the AI-slop defaults to avoid in both their classic
  and newer forms. Intensity is a dial: product UI gets restraint, marketing pages get room.
- `domain-audience-playbook.md`. Per-domain defaults for banking, trading, CRM, healthcare,
  e-commerce, education, social, productivity, government, and games, plus per-audience
  defaults for age, expertise, usage context, frequency, and locale. Defaults, not laws.
  When a user preference conflicts with a domain's core need, say so once and offer a
  version that keeps both.
- `design-md-template.md`. The `DESIGN.md` format: product and audience, vibe, tokens,
  components, do/don't, decision log, and likes/dislikes.

## Updated Skills

### frontend-design

Now the build skill. It no longer explores style directions inline.

- Reads `DESIGN.md` as binding and `design/<feature>/DECISIONS.md` as the spec when either
  exists.
- Step 2 decides prototype or build directly, with a table covering approved prototype,
  user override, simple addition, medium, and big or new. Unattended runs never block on an
  approval gate; they build following `DESIGN.md` and list every design decision in the
  report.
- Step 3 writes `DESIGN.md` from the template when none exists, after one round of max 4
  questions.
- Step 6 adds a bounded visual self-review: render and screenshot at ~390px and ~1440px,
  score 1 to 10, fix the top 3 issues in one batch, stop after 2 rounds.
- The old inline "Frontend Aesthetics Guidelines" block moved to `design-rules.md`, which
  is stricter in places. It bans emoji icons and buzzword copy, names the newer
  cream-plus-serif-plus-grain look as a default to avoid too, and states that consistency
  beats novelty within one product.
- Added rules: never hand off screens you haven't looked at, and priority order is domain
  and audience needs, then the approved prototype, `DESIGN.md`, and the user's taste, then
  your own preferences.

### plan-feature

New Step 2.5, "UI Check (Prototype or Not)", skipped when the feature touches no UI. It
reads `DESIGN.md` and `design/<feature>/DECISIONS.md` first, then classifies the change:

| UI change | Prototype |
|-----------|-----------|
| Simple: a field, column, button, filter, copy or style tweak, a new item in an existing list or menu, a component already in DESIGN.md | not needed |
| Medium: a new section or component on an existing screen, with an obvious layout | not needed |
| Big or new: a new screen or flow, a new product with no DESIGN.md, a layout with real alternatives, a high-stakes flow | required |

When required, the plan names the design question the prototype must answer and writes UI
steps as "Build `<screen>` per `design/<feature>/DECISIONS.md`" rather than inventing layout
details. Both plan templates gained a `## UI / Design` section with prototype status,
design question, design spec, and affected screens. The plan summary now says when a
prototype is required and names `prototype-ui` as the next step after plan review.

Prototyping happens in the main session with the user, never inside an implementation
phase, because an implementor subagent cannot hold an approval gate.

### README.md

Structure tree, the design-phase mermaid diagram, and the SDLC Phase 3 row all describe the
split. The tree now shows `prototype-ui`, the `frontend-design/` folder with its
`references/` subfolder, and `design-critique`.

## Usage

Install by copying the skill folders into the agent's skills directory. `prototype-ui`
resolves its shared references at `../frontend-design/references/`, so both skills must be
installed side by side under the same skills root.

Typical flow for a new screen:

1. `plan-feature` marks the plan `Prototype: required` and names the design question.
2. `plan-review` reviews the plan.
3. `prototype-ui` runs, iterates with you, and writes `design/<feature>/DECISIONS.md`.
4. `frontend-design` builds to `DECISIONS.md`.
5. `implementation-review`, then `document-and-commit`.

For a button on an existing screen, steps 1 to 3 collapse into the plan marking
`Prototype: not needed`, and `frontend-design` builds directly.

## Notes

- `CLAUDE-template.md` still lists Phase 3 as `frontend-design` /
  `frontend-bootstrap-evolution` / `python-development`. It was left untouched because it is
  a scaffold template rather than part of this change set, but it now lags the README.
- `DESIGN.md` and `design/<feature>/DECISIONS.md` are project files, written into the
  project being worked on. They are not committed to this repo.
- Standalone prototypes under `design/` are reference material and must never end up in the
  app bundle. In-app variant routes are deleted in `prototype-ui` Step 7.
