---
name: prototype-ui
description: "Explore what a UI should look like before building it: wireframes, design directions, and a clickable prototype with a design-decisions table explaining each choice for the product's domain and target audience, iterated with the user until approved. Throwaway design work that answers 'what should this look like?', not production code. Triggers: 'prototype this', 'wireframe this', 'mock this up', 'show me design options', 'what should this screen look like', 'explore layouts', 'show me a few directions'. Also used when frontend-design recommends a prototype for a big or new feature. Do NOT trigger on: simple UI additions, implementing an approved design (use frontend-design), critiquing an existing screen (use design-critique), or backend-only work."
---

# Prototype UI

A prototype is throwaway design work that answers one question: **what should this look like,
and why?** You explore options cheaply, show the user design choices with the reasoning behind
each, and iterate until they approve. Then `frontend-design` builds it for real.

Changing a wireframe takes minutes; changing shipped code takes hours. But a prototype is not
free either, so it's for big or new UI: new screens and flows, new products, layouts with real
alternatives, and high-stakes flows (money movement, checkout, onboarding). For a new field or
button, skip this skill and let `frontend-design` build directly.

```
[plan-feature] → **prototype-ui: Context → Direction → States → Wireframes → Prototype → ✅ Approval → Record** → frontend-design (build to it)
```

A prototype can come before or after the plan. Before: to decide what to build. After: to decide how it should look.

**Shared references** (from the `frontend-design` skill folder; read them before designing):
- `../frontend-design/references/design-rules.md`
- `../frontend-design/references/domain-audience-playbook.md`
- `../frontend-design/references/design-md-template.md`
- `../frontend-design/references/image-assets.md` (read when the design needs generated images)

If they aren't installed, apply the same principles: concrete tokens, 4/8pt spacing, WCAG AA contrast, one focal point per screen, the domain's core needs, no AI-slop defaults.

## Fidelity ladder

Use only the steps the question needs:

| Question | Steps |
|----------|-------|
| "What visual style should the whole product have?" | Direction (Step 2) → Prototype of one key screen |
| "How should this screen/flow be laid out?" | Wireframes (Step 4) → Prototype |
| "Does this flow feel right?" | Prototype only, with the flow clickable |
| "Which of these looks better?" | Prototype variants only |

Say which steps you're running in one line at the start.

## Step 1: Context

1. Read the plan in `plans/` if one exists, plus its review log.
2. Read **DESIGN.md** if it exists. It's binding: prototypes use its tokens and components unless the user asked for a new look.
3. Read the existing screens/components this feature sits next to.
4. Identify **domain**, **target audience** (age, expertise, usage context, frequency, locale), and **core job**. Apply the matching playbook entries. If unknown, ask in the Step 2 round, or assume and say so.

## Step 2: Direction (only when there's no DESIGN.md, or the user wants a new look)

1. **Gather context and taste (one round, max 4 questions)**: domain/audience if unclear; 1–3 reference apps/sites they love the look of (screenshots best); what they dislike; fixed constraints (brand colors, fonts, platform). From references, extract concrete traits (type style, density, radius, color usage, shadow vs. flat, imagery) and name them back.
2. **Explore styles wide, cheaply**: 4–6 small static previews of *one key screen*, side by side, in clearly different directions:
   - 1–2 close to their references
   - 1 domain-standard (what the best products in this category do)
   - 1 native/safe (Apple HIG / Material 3 / clean web convention)
   - 1 wildcard outside what they asked for, labeled as such
   - the rest spread across genuinely different styles (Swiss minimal, editorial, soft & rounded, neo-brutalist, dark luxury, bento, utilitarian/dense, retro…)
   **Vary the style, not the fundamentals**: every preview still meets the domain's and audience's core needs. Under each: a name, one line on its personality, one line on how it serves the audience.
3. **User picks** one, or combines ("colors from 2, layout from 4").
4. **Lock tokens** in DESIGN.md (from the template). Show the token list in a few lines.

## Step 3: States

List the non-happy paths for each screen in scope: **empty**, **loading**, **error**, **success**, plus forms (validation timing, submit state), destructive actions (confirm or undo), navigation (how users arrive and leave), keyboard/focus. They appear in the wireframes and the prototype's state switcher.

## Step 4: Wireframes (structure)

Low fidelity, grayscale, no styling. This step is about **layout and flow**, not looks.

1. For each key screen, sketch **2–3 genuinely different layouts** where a real choice exists:
   - table vs. card list vs. split view
   - tabs vs. single long scroll vs. stepper
   - bottom sheet vs. full-screen page vs. modal
   - dashboard-first vs. action-first home
   If the layout is obvious, show one and say why there's no real alternative.
2. Use **real-looking content** for the domain (balances, client names, products), never lorem ipsum. Real content reveals real layout problems.
3. Show the **flow** between screens (A → tap → B) and where each state appears.
4. For each option: **why it works** (tied to core job, domain, audience; e.g. "Table: pro sales reps compare 50+ deals at once; sortable columns beat scrolling cards") and its **trade-off**.
5. **Recommend one** in one sentence. Let the user pick or mix.

## Step 5: Prototype & design rationale

Turn the chosen wireframe into a **high-fidelity, clickable prototype** in the DESIGN.md style.

### Pick the format
- **Standalone HTML** (default): self-contained HTML/CSS/JS, mobile screens in a ~390×844 phone frame. Best for new products and new flows. Save under `design/<feature>/prototype/`. Use the session's design canvas instead if one is available.
- **In-app variants**: when the app already runs and the feature lives inside existing screens, build the variants on a throwaway route in the real app, switched with a `?variant=a|b|c` URL param and a small floating bar. It looks real because it uses real components. Keep it isolated (one route, no shared-state changes, in-memory data) and delete it in Step 7.

### Build
- Key screens and the main flow, clickable (navigation, primary actions, opening sheets/modals).
- A small **state switcher** (Default / Empty / Loading / Error).
- 2–3 **variants** only where the user is still choosing; otherwise one.
- Light and dark mode if the product supports both.
- Real-looking content; correct number, date, currency formats for the locale.
- Keep it simple: in-memory state, no backend, one command (or one file) to open it.

### Explain the design choices
Alongside the prototype, present a **Design Decisions** table (also in the prototype as numbered callouts or a toggleable side panel):

| # | Decision | Why (for this product & audience) | Alternative considered | Trade-off |
|---|----------|-----------------------------------|------------------------|-----------|
| 1 | Balance at 34pt bold, top of screen | Core job is "check my money"; older users need it readable at a glance | Balance inside a card | Less room above the fold for actions |
| 2 | Transfer requires a review screen | Money movement must be confirmable (banking trust) | One-tap transfer | One extra step |

Cover at least: layout/hierarchy, primary action placement, typography and number display, color use (especially semantic colors like positive/negative), density, navigation pattern, and any motion. One sentence per reason, grounded in the domain, audience, core job, or the user's stated taste. Never "it looks modern."

### Self-review before showing (bounded)
1. Screenshot at mobile (~390px) and desktop (~1440px) widths.
2. Score 1–10: **fit for domain & audience**, hierarchy, typography, color/contrast, spacing, consistency, platform fit, match to DESIGN.md, match to the user's references and likes/dislikes. Check for slop tells and domain pitfalls.
3. Fix the top 3 issues in one batch; re-check once. Stop when nothing scores below 7, or after 2 rounds, noting what's still weak.

## Step 6: ✅ Approval

Show the prototype and the decision table. Ask the user to approve, or to react per decision ("keep 1, change 3") or per variant ("header from B, cards from A"). Iterate on the prototype until approved. Change only what they asked for plus what breaks as a result.

If they say "it doesn't feel right" but can't say why, offer 2–3 targeted variations of the one element most likely responsible rather than starting over.

If the user isn't around: finish the prototype with your recommended option, put the decision table at the top of your summary, and mark it **not yet approved**.

## Step 7: Record the verdict and hand off

1. Write **`design/<feature>/DECISIONS.md`**: the approved variant, the final decision table, the states, any open questions, and the prototype's location. This is the spec `frontend-design` (or an implementor subagent) builds to.
2. Append lasting decisions and the user's reactions to **DESIGN.md** (**Decision log**, **Likes / Dislikes**) so future features reuse the reasoning.
3. **Clean up**: delete in-app variant routes and unused variants. Standalone prototypes in `design/` can stay as a reference; they are never part of the app bundle.
4. Hand off in one line: "Approved. Next: `frontend-design` builds this from `design/<feature>/DECISIONS.md`."

## Rules
- Prototypes are throwaway. They answer a design question; they are not production code.
- Use only the fidelity steps the question needs.
- Every design decision shown to the user comes with a one-sentence reason tied to the domain, audience, core job, or their taste.
- Priority order: product domain & audience needs → DESIGN.md and the user's taste → your own aesthetic preferences.
- One round of questions per step; never interrogate.
- Bounded self-review: at most 2 rounds before showing the user.
- Never copy a real brand's logo, characters, or exact app design; use references for traits.
