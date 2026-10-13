# Skill Updates: design-study, design-critique sync, and generated image assets

## Overview

The design skills could judge a UI (`design-critique`, restored in this change) and build one
(`prototype-ui`, `frontend-design`), but nothing measured an existing product's design so new
work could match it. The new `design-study` skill fills that gap. It takes a live URL, an app
codebase, or screenshots, measures the real tokens, shows a token sheet for approval, and
writes a `DESIGN.md` that the other design skills follow. This change also adds a fourth
shared reference, `image-assets.md`, for delegating generated images, and syncs
`design-critique` with the shared references and the current handoff chain.

## New Skill

### design-study

Answers one question: what is this product's design, written down so new work can follow it?
It measures what exists; it does not judge or redesign it. That split is the trigger
boundary with `design-critique`.

Flow, six steps:

1. **Source and ownership.** Name the source (one to three pages the user names, never a
   whole-site crawl), then ask once: own product or third-party reference? Own product:
   copy exact tokens. Third-party: take structure and traits only (type scale ratio,
   spacing scale, radius, density, layout patterns, component behavior), never the logo,
   brand colors, brand font, illustrations, or exact screens.
2. **Capture.** Live URL: run the bundled script (below). Codebase: read theme sources in
   order (CSS custom properties, Tailwind config, SCSS or Bootstrap variable overrides,
   React Native or Expo theme files, then the most-used components). Screenshots: read them
   directly and mark every derived value as estimated.
3. **Measure.** Turn the capture into tokens: font families, a type scale rounded to common
   steps, color roles (bg, surface, text, muted, accent, positive, negative, danger) chosen
   by usage, spacing snapped to 4/8, radius, shadows, density. Inconsistencies (seven
   grays, four radii, 13px and 14px body text) are findings for the user to resolve, not
   tokens.
4. **Inventory.** One line per component (buttons, inputs, cards, tables, nav, modals or
   sheets, badges, toasts), plus layout patterns and states seen.
5. **Sheet approval.** Write a self-contained `design/study/<slug>/sheet.html` with color
   swatches and roles, the type scale in the real fonts, spacing and radius samples, the
   component list, the two screenshots side by side, and findings. Show it and iterate on
   the user's reactions, changing only what they ask for.
6. **Write DESIGN.md** from the shared template, filling the new `## Source` section with
   the source, the ownership answer, and each token's origin (measured, theme file, or
   estimated). Hand off in one line to `design-critique`, `prototype-ui`, or
   `frontend-design`.

Rules worth knowing: study only pages the user names and is allowed to view (no login, no
stealth, no Chrome profile); third-party captures stay under `design/study/` as reference
and never enter the app bundle; every value carries its origin and estimated values are
labeled.

## Bundled Script

`skills/design-study/scripts/study_site.py` screenshots a live page at 390px and 1440px and
tallies its computed styles. It needs the isaham venv Python, which has Playwright and its
bundled Chromium.

```bash
/Users/amirinns/PythonEnv/isaham/bin/python <skill-dir>/scripts/study_site.py <url> [<url> ...] --out design/study
```

Run it from the project root. For each URL it writes `design/study/<slug>/390.png`,
`1440.png`, and `tokens.json`. The `tokens.json` holds the page's `--*` custom properties
and the top 20 values of each computed style (font-family, font-size, font-weight,
line-height, color, background-color, border-color, border-radius, box-shadow, and a
combined spacing bucket from padding, margin, and gap), counted across visible elements at
both widths. Open both screenshots with Read before measuring.

Behavior notes:

- Opaque `rgb()` and `rgba()` colors convert to `#rrggbb`; fully transparent colors are
  dropped; partial alpha and non-rgb values (`oklch()`, `color()`) pass through unchanged,
  because Chrome keeps authored modern colors in computed style.
- `padding`, `margin`, and `gap` shorthands split into single values, so `8px 16px` lands
  in the spacing bucket as `8px` and `16px`. Horizontal auto margins are excluded so a
  centered container does not leak a large offset into spacing.
- Page load uses `load` plus a fixed 1500 ms settle, not `networkidle`, which never fires on
  pages with analytics beacons or long polling. Raise `SETTLE_MS` in the script if
  late-loading styles get missed.
- A URL that fails to load prints one `error: <url>: ...` line to stderr, the other URLs
  still run, and the exit code is 1 if any failed.

## Tests

`skills/design-study/tests/test_study_site.py` is a plain-assert runnable check, no
framework:

```bash
/Users/amirinns/PythonEnv/isaham/bin/python skills/design-study/tests/test_study_site.py
```

It covers `rgb_to_hex` (opaque, transparent, partial alpha, non-rgb), `tally` (sorting,
the top-20 cap, spacing splitting, ignored values), `slugify` (folder-safe output), and an
end-to-end capture against the bundled `tests/fixture.html` (both PNGs exist, `--brand`
reads `#0a7cff`, the expected values appear in the matching tallies). It prints `ok` on
success. It failed with `ModuleNotFoundError` before the script existed.

## Updated Skills and References

- **`design-critique`** is restored to the repo and synced: its inline domain and audience
  playbook is deleted in favor of the shared one, it points at the four shared references,
  Phase 7 writes DESIGN.md from the shared template, and study requests route to
  `design-study` (added to its `Do NOT trigger on` list). Its critique phases are otherwise
  unchanged.
- **`design-md-template.md`** gains an optional `## Source` section (source URL, codebase
  path, or screenshots; own or third-party; per-token origin) and lists `design-study`
  among the skills that write DESIGN.md.
- **`image-assets.md`** is a new shared reference covering delegation of generated images:
  brief fields (purpose, exact output path, size and format, style tied to DESIGN.md tokens,
  variants, exclusions such as no text or real faces), the review loop (confirm the file,
  open it, at most 2 correction rounds, save the prompt next to the asset), and the rule
  that wireframes use gray boxes, never generated images. `frontend-design`,
  `prototype-ui`, and `design-critique` list it, read when a design needs generated images.
- **`delegate-work-codex`** and **`delegate-work-agy`** gain a note that image generation is
  a valid assignment. Codex requires `codex features list` to show `image_generation`
  enabled before dispatch; agy needs the brief to name the exact output path because its
  artifacts land outside the project. Both define review as opening each file and checking
  it against the brief.
- **`README.md`** gains the `design-study/` tree entry, the `DS[design-study]` flowchart
  edge into `frontend-design`, and the Phase 3 row entry. The stale note in
  `docs/skill-updates-2026-10.md` saying `design-critique` was missing is removed.

## Installation

`design-study` resolves its shared references at `../frontend-design/references/`, so keep
it installed side by side with `frontend-design` under the same skills root. This change
links the new skill into all four agent skill dirs that already link `prototype-ui`
(`~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`,
`~/.gemini/antigravity-cli/skills`) and adds the missing `design-critique` links to the pi
and agy dirs. Those symlinks live outside this repo.

## Design Decisions

| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
| How the skill measures a live site | Bundled script `study_site.py` | Instructions only, using the agent's browser tool; a JS snippet file pasted into the browser tool | Same output in Claude, Codex, agy and pi, and it can ship with a test |
| Where study lives | Separate `design-study` skill | A study mode inside `design-critique` | Different requests and triggers; critique's taste and exploration phases don't apply; keeps `design-critique` from growing |
| Which Python runs the script | isaham venv | recon-tools `.venv`; a new venv | It is the shared venv for this workspace and already has Playwright |
| Browser | Headless bundled Chromium | Real Chrome with a profile, as `site-clone` does | Public pages only; no stealth or login needed |
| Third-party sources | Structure and traits only | Copy exact tokens from any source | Matches the existing rule against replicas; own products keep exact tokens |
| Output location | `design/study/<source-slug>/` | `design/<feature>/`; a temp dir | Study is per source, not per feature; it sits next to `prototype-ui`'s `design/` output |
| Playbook in `design-critique` | Drop it, read the shared one | Keep both copies | Diff shows the same entries; one copy avoids drift |
| Source section | Optional section in the shared template | Separate `SOURCE.md` | One file stays binding; other skills already read the template |

## Review History

The plan passed two review rounds on 2026-10-13 (a third pass found nothing new). The
substantive changes:

- A Playwright probe showed computed `padding` comes back as the shorthand `8px 16px` and
  Chrome keeps authored `oklch()` colors as `oklch(...)`, so the tally splits spacing
  shorthands and `rgb_to_hex` passes non-rgb colors through. The old rules would have
  missed both.
- `networkidle` never fires on pages with analytics beacons or long polling, so page load
  uses `load` plus a fixed settle.
- `slugify(url)` was added with a test because URL text becomes a folder name and
  unsanitized `..` or `/` could write outside `--out`.
- Failed URLs got defined behavior (one error line, the rest still run, exit code 1) with an
  acceptance check, since a dead or blocked URL is the most likely failure.
- The skill runs the script as `<skill-dir>/scripts/study_site.py` from the project root;
  a relative `scripts/` path only works from inside the skill folder.
- Symlinks go into all four agent skill dirs, and `design-critique` gets the pi and agy
  links it lacked.
- A rule was added that third-party captures stay under `design/study/` and never enter the
  app bundle.

Deviation from the plan: the plan referenced `image-assets.md` as an existing shared
reference; it did not exist, so this change created it along with the `delegate-work-codex`
and `delegate-work-agy` image-generation notes and the reference lines in
`frontend-design` and `prototype-ui`. Those files are beyond the plan's Affected Files list.
