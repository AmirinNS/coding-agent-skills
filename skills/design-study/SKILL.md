---
name: design-study
description: "Learn an existing design from a live website, an app codebase, or screenshots: measure its real tokens (fonts, type scale, colors, spacing, radius, shadows), list its components and layout patterns, show a token sheet for approval, and write a DESIGN.md that prototype-ui and frontend-design follow. Use when the user wants new work to match an existing product, or wants the design system of a site or app written down. Triggers: 'study this site', 'learn the design from', 'extract the design system', 'make our design follow this app', 'copy the look of our existing app', 'write a DESIGN.md from our site'. Do NOT trigger on: critiquing or redesigning a UI (use design-critique), building UI (use frontend-design), or exploring new layouts (use prototype-ui)."
---

# Design Study

Study answers one question: **what is this product's design, written down so new work can follow it?**
It measures what exists. It does not judge it or redesign it. That is `design-critique`.

```
**design-study: Source → Capture → Measure → Inventory → ✅ Sheet approval → DESIGN.md** → design-critique / prototype-ui / frontend-design
```

**Shared references** (from the `frontend-design` skill folder; read them before writing DESIGN.md):
- `../frontend-design/references/design-md-template.md`
- `../frontend-design/references/design-rules.md`
- `../frontend-design/references/domain-audience-playbook.md`

If they aren't installed, apply the same principles: concrete tokens, 4/8pt spacing, WCAG AA contrast, the domain's core needs.

## Step 1: Source and ownership

Name the source back in one line: URL(s), codebase path, or screenshots. Study one to three pages
the user names; never crawl a whole site. Then ask once, unless the user already said:
**is this your own product, or a third-party reference?**

- **Own product**: copy exact tokens. New work must match what already ships.
- **Third-party reference**: take structure and traits only: type scale ratio, spacing scale, radius, density, layout patterns, component behavior. Never the logo, brand colors, brand font, illustrations, or exact screens. Pick the project's own colors and fonts to fill those roles, and say which you picked.

## Step 2: Capture

**Live URL.** From the project root:

```bash
/Users/amirinns/PythonEnv/isaham/bin/python <skill-dir>/scripts/study_site.py <url> [<url> ...] --out design/study
```

For each URL it writes `design/study/<slug>/390.png`, `1440.png` and `tokens.json` (CSS custom
properties plus the top 20 values of each computed style, counted across visible elements at both
widths). A URL that fails prints `error: <url>: ...`, the others still run, and the exit code is 1.
Public pages only: no login, no Chrome profile. Open both screenshots with Read before measuring.

**Codebase.** Read the theme sources in this order and stop when tokens are clear:
1. CSS custom properties (`:root { --... }`)
2. Tailwind config (`tailwind.config.*`, `@theme` blocks)
3. SCSS or Bootstrap variable overrides (`_variables.scss`, `$primary`, …)
4. React Native / Expo theme files (`theme.ts`, `colors.ts`, `constants/`)
5. The most-used components (buttons, inputs, cards) for values the theme doesn't name

If the app runs, add screenshots: the dev server for web, `run-expo-android` or `run-expo-ios` for Expo.

**Screenshots only.** Read each one. Every value you derive is **estimated**; say so in the sheet and in DESIGN.md.

## Step 3: Measure

Turn the tally, theme files, or screenshots into tokens:

- **Fonts**: display and body families. Drop generic fallbacks.
- **Type scale**: the sizes that carry most text, rounded to the nearest common step. List outliers separately.
- **Color roles**: bg, surface, text, muted, accent, positive, negative, danger, chosen by how often and where each color is used (`background-color` on large areas is bg or surface; the most common text color is text). Light and dark if both exist.
- **Spacing**: snap to a 4/8 scale. Note values that don't fit.
- **Radius, shadows, density** (comfortable or compact), and number formats if numbers matter.

Inconsistencies (seven grays, four radii, 13px and 14px body text) are **findings**, not tokens.
List them under the sheet so the user can choose which value wins.

## Step 4: Inventory

One line each for the components seen: buttons (variants and sizes), inputs, cards, tables, lists,
navigation, modals or sheets, badges, toasts. Then the layout patterns (grid widths, sidebar or top
nav, card vs. table lists) and the states seen (empty, loading, error, disabled).

## Step 5: ✅ Sheet and approval

Write `design/study/<slug>/sheet.html`, one self-contained page:
- color swatches with hex and role
- the type scale rendered in the real fonts
- spacing and radius samples
- the component list and layout patterns
- the two screenshots side by side
- findings, each with the value you propose to keep

Show it. Ask the user to approve or correct ("accent is #0a7cff, not the blue you picked").
Update the sheet for each reaction. Change only what they asked for.

If the user isn't around: finish the sheet and DESIGN.md with your proposed values and mark both **not yet approved**.

## Step 6: Write DESIGN.md

Write `DESIGN.md` (repo root, or `docs/` if the project keeps docs there) from the shared template:
- Product & Audience from what you saw, with assumptions marked.
- `## Source`: the URL, codebase path or screenshots; own product or third-party; the origin of each token (measured, theme file, or estimated).
- Tokens and components from Steps 3 and 4. Findings the user resolved go into the decision log.

If a DESIGN.md already exists, show the differences and ask before replacing anything.

Hand off in one line: "DESIGN.md written. Next: `design-critique` to improve it, `prototype-ui` for the next big feature, or `frontend-design` to build."

## Rules
- Measure, don't judge. Critique belongs to `design-critique`.
- Study only pages the user names and is allowed to view. No login, stealth, or whole-site crawls.
- Third-party sources give traits only. Never copy a logo, brand colors, brand font, illustrations, or exact screens.
- Captures of a third-party site stay under `design/study/` as reference and never enter the app bundle.
- Every value carries its origin. Estimated values are labeled as estimated.
