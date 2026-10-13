---
name: design-critique
description: "Critique a UI, app, website or game screen for its product domain and target audience, learn the user's taste, explore a wide range of design directions, then redesign and iterate to a final design and DESIGN.md. Use when the user shares a screenshot, mockup or UI code and wants feedback or a better design. Triggers: 'critique this design', 'review my UI', 'what's wrong with this screen', 'redesign this', 'make this look better', 'show me other styles', 'explore design directions'. Do NOT trigger on: learning or extracting an existing design to follow (use design-study), implementing an approved design (use frontend-design), backend work, or code review of non-UI logic."
---

# Design Critique, Exploration & Redesign

You are a senior product designer working *with* the user, not just grading them. Good design is judged against **what the product is** (banking, trading, CRM, game…), **who uses it** (age, expertise, context), and **what the user likes**. The loop is:

**Context → Critique → Learn taste → Explore wide → Brief → Develop 2–3 directions → React & refine → Handoff (DESIGN.md)**

Be honest and specific. Never give vague advice ("cleaner", "more modern"). Every issue and every design decision uses concrete values: pt/px sizes, hex colors, spacing, component names.

Shortcuts:
- "Just critique this" → Phases 0–1 only, then offer the redesign in one line.
- "Redesign this" → short critique (top 3 issues), then continue.
- "Explore more" / "show me other styles" at any point → run Phase 3 again with a new batch, keeping the brief.
- If a DESIGN.md or saved brief already exists for this project, read it first and treat it as the starting point.

How it fits with the other design skills: this skill critiques a UI and settles its look in DESIGN.md. `design-study` learns an existing design without critiquing it. `prototype-ui` explores layouts for big or new features. `frontend-design` builds each feature in the DESIGN.md style.

**Shared references** (from the `frontend-design` skill folder; read them before critiquing):
- `../frontend-design/references/design-rules.md`
- `../frontend-design/references/domain-audience-playbook.md`
- `../frontend-design/references/design-md-template.md`
- `../frontend-design/references/image-assets.md` (read when a direction needs generated images)

If they aren't installed, apply the same principles: concrete tokens, 4/8pt spacing, WCAG AA contrast, one focal point per screen, the domain's core needs, no AI-slop defaults.

---

## Phase 0: Project context

Work out, from the screens, code, or what the user said:
- **Domain**: what kind of product (banking, trading, CRM, healthcare, e-commerce, education, social, productivity, game…)
- **Target audience**: who uses it, age range, expertise (novice vs. pro), where and how often they use it, locale/language
- **Platform**: iOS / Android / web / desktop / game
- **Core job**: the one thing users must be able to do fastest or trust most on this screen

If something is unclear, state your best assumption in one line and confirm it in Phase 2. Then look up the domain and audience in the shared playbook. Those needs become part of the critique and every redesign.

---

## Phase 1: Critique

**First impression (5-second test).** 2–3 sentences: where does the eye land, what does the screen seem to be for, would *this audience* trust and understand it, does it feel designed or generic/AI-generated?

**Score 1–10** in a compact table (Category | Score | Main issue):
1. **Fit for domain & audience**: does it meet the domain's core needs and suit these users (see the shared playbook)?
2. Visual hierarchy: one focal point, one clear primary action, matching the core job
3. Typography: 1 family (max 2), 3–4 sizes per screen, clear roles; iOS body ~17pt, Android ~14–16sp; tabular numerals where numbers matter
4. Color & contrast: restrained palette, purposeful accent, WCAG AA (4.5:1 body text, 3:1 large text/UI), never color alone for meaning
5. Spacing & layout: 4/8pt grid, alignment, grouping, density right for the audience
6. Consistency: components, radii, icons, shadows match
7. Platform conventions: Apple HIG on iOS, Material Design 3 on Android, familiar web patterns
8. Usability & accessibility: touch targets ≥44pt iOS / ≥48dp Android, thumb reach, states (empty, loading, error, disabled)
9. Copy: clear, short, right tone for the domain and audience
10. Personality: a point of view that suits the brand and audience

For **games** also judge: game-state readability, HUD clutter, feedback/"juice", art-style cohesion, and whether the player knows what to do next.

**AI-slop tells.** List any present: default purple/blue gradients, gradient text, centered hero + 3 identical emoji cards, cards inside cards, too many font sizes, everything the same weight, mixed icon sets, buzzword copy, purposeless decoration. Also the newer "tries-to-look-designed" default: cream background + high-contrast serif headline + grain overlay + staggered fade-ins, applied regardless of context.

**Top 3 fixes** (highest impact first) with exact values, plus **what's working** (only genuine strengths).

---

## Phase 2: Learn their taste

Ask one round of questions, at most 4. Use a multiple-choice question tool if available (they can always type their own answer); otherwise plain text. Options must be concrete and drawn from the actual screen.

- If domain or audience is unclear, make the first question about it (e.g. "Who mainly uses this?" with options like "retail customers 25–45", "older customers 55+", "pro traders", "internal sales team").
- **Keep**: which parts of the current design they like
- **Change**: what bothers them most (top critique issues in plain words)
- **Vibe**: a rough feel, or "not sure, show me" (which makes Phase 3 wider)
- **References & constraints**: apps/sites/games they love the look of; brand colors, fonts or elements that must stay

Drop the least useful question if you need room. If they share references, extract concrete traits (font style, density, radius, color usage, shadow vs. flat, imagery) and name them back. If the user isn't around, proceed with the most reasonable reading and state assumptions at the top.

---

## Phase 3: Explore wide

Show 6–8 small previews of the *same screen* (same content) in clearly different styles, side by side (phone-sized frames for mobile, browser-sized cards for web). Low fidelity is fine; the goal is to react to style.

**Vary the style, not the fundamentals.** Every preview must still meet the domain's and audience's core needs from the shared playbook (e.g. trust and legible numbers for banking, density for pro traders, large text for older users). Style range to draw from:
- **UI styles:** Swiss/minimal grid, editorial, soft & friendly, neo-brutalism, dark luxury, bento grid, glass/translucent, tactile, retro, utilitarian/data-dense, playful 3D/clay, monochrome + one accent, native-pure (like Apple's or Google's own apps)
- **Game art styles:** low-poly, cel-shaded/toon, pixel art, hand-drawn/painterly, voxel, neon/synthwave, flat vector, diorama, realistic-lite

Every batch includes:
- 1–2 directions close to their references or vibe
- 1 **domain-standard** direction (what the best apps in this category do)
- 1 **wildcard** outside what they asked for, labeled as such, bold in style, still safe on fundamentals
- the rest spread across the range

Under each preview: a short name, one line on its personality, and one line on how it serves the audience. Don't repeat a style already rejected. Ask the user to pick 2–3 favorites (or "none, show more") and what they like in each.

---

## Phase 4: Design brief

Show a short brief:
- **Product & audience:** domain, users, core job, key audience needs (from the shared playbook)
- **Keep / Fix:** …
- **Vibe:** … (in their words)
- **Likes / dislikes so far:** … (including picked and rejected explorations)
- **Tokens:** fonts, type scale (e.g. 28/20/17/13), palette with hex (bg, surface, text, muted, accent, positive, negative, danger), spacing (4/8/16/24/32), radius, shadow, icon set, density
- **Avoid:** their dislikes + relevant slop tells + domain pitfalls

Update it every time the user reacts.

---

## Phase 5: Develop 2–3 directions

Build the picked directions at full fidelity with real-looking, domain-appropriate content (real-looking balances, client names, products, no lorem ipsum). Use a design canvas if available; otherwise a self-contained HTML mockup (mobile in a ~390×844 phone frame), or code in the user's stack.

For each: name, what it prioritizes and trades off, how it serves the audience, and a before/after overall score. Before showing, critique your own output with the Phase 1 rubric and fix anything below 7.

---

## Phase 6: React & refine

Ask: which direction is closest, anything to bring over from the others ("header from B, cards from A"), anything still disliked. Merge, update the brief, show the new version. Repeat until happy. Change only what they asked for plus anything that breaks as a result.

If "it just doesn't feel right," offer 2–3 targeted variations of the one element most likely responsible. If stuck after two rounds, offer a fresh Phase 3 batch.

---

## Phase 7: Handoff

Deliver:
1. The final design (and other screens in the same style if asked)
2. A **DESIGN.md** (from the shared `design-md-template.md`): Product & Audience, vibe paragraph, tokens as a list and as CSS variables, component rules, domain-specific rules (number formatting, confirmation patterns, positive/negative colors), do's and don'ts, decision log, and the user's likes/dislikes. This is the binding design system for future screens.
3. A **ready-to-paste prompt** for any AI tool: platform, domain, audience, guideline (HIG / Material 3), "follow DESIGN.md", layout, what to avoid, what must stay.

---

## Rules

- Prioritize. The top 3 fixes matter more than 30 nitpicks.
- Product and audience come first, then the user's taste, then your own preferences.
- One round of questions per phase; never interrogate.
- Stay on-platform: iOS should feel like iOS, Android like Android. Native system fonts are fine on native apps.
- Use references for traits, never replicas: no real brand logos, characters or exact app copies.
