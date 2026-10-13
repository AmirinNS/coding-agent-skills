# Plan: design-study skill and design-critique sync

## Goal
Add a `design-study` skill. The user hands over an existing website, a set of screenshots, or
an app codebase, and the skill measures its real design tokens and writes a DESIGN.md that later
work can follow. Also bring the restored `design-critique` skill in line with the
`prototype-ui` / `frontend-design` split.

## Scope
- In scope:
  - Sync `skills/design-critique/SKILL.md` with the shared references and the current handoff chain.
  - New skill `skills/design-study/` with three input types: live URL, screenshots, codebase.
  - Bundled script `skills/design-study/scripts/study_site.py` that takes screenshots and tallies computed styles for a live URL, with one runnable test.
  - An optional `## Source` section in the shared DESIGN.md template.
  - README updates, the `~/.claude/skills/design-study` link, and removal of the "skill is missing" note in `docs/skill-updates-2026-10.md`.
- Out of scope:
  - Crawling a whole site (study one to three URLs the user names).
  - Logged-in pages, Chrome profiles, or bot-evasion (use `site-clone` with `--profile` if ever needed).
  - Native app capture. For a running Expo app, `design-study` points at `run-expo-android` / `run-expo-ios` for screenshots and treats them as screenshot input.
  - Changing the critique flow (Phases 0 to 7) beyond the sync edits.

## Approach

### Milestone 1: Sync design-critique
1. `skills/design-critique/SKILL.md` — replace the line "How it fits with `frontend-design`…" with: this skill critiques a UI and settles its look in DESIGN.md; `design-study` learns an existing design without critiquing it; `prototype-ui` explores layouts for big or new features; `frontend-design` builds.
2. Same file — add a "Shared references" block after the intro, listing `../frontend-design/references/design-rules.md`, `domain-audience-playbook.md`, `design-md-template.md` and `image-assets.md` (the last one "read when a direction needs generated images"), plus the fallback sentence `prototype-ui` uses when they are not installed.
3. Same file — delete the "Playbook — domain & audience" section with its leading `---` separator (lines 129 to 155), so a single `---` remains before `## Rules`. The shared playbook holds the same entries (checked with a diff; only wording differences such as "via `Intl`").
4. Same file — Phase 0 "look up the domain and audience in the **Playbook** below" becomes "in the shared playbook". Phase 7 item 2 "same template as the `frontend-design` skill" becomes "from the shared `design-md-template.md`".
5. Same file — add to the frontmatter `Do NOT trigger on:` list "learning or extracting an existing design to follow (use design-study)".
6. Same file — replace em dashes in headings and body with periods or colons per the repo writing style (`## Phase 0 — Project context` becomes `## Phase 0: Project context`).
→ Verify: `grep -n "Playbook below\|wireframes, prototypes\|—" skills/design-critique/SKILL.md` prints nothing; `grep -c "references/" skills/design-critique/SKILL.md` prints 4 or more.

### Milestone 2: Site study script (test first)
1. Create `skills/design-study/tests/fixture.html` — one page with known tokens: `:root { --brand: #0a7cff; }`, body `font-family: Georgia, serif; font-size: 16px`, a `h1` at 32px, a button with `background: var(--brand); border-radius: 12px; padding: 8px 16px; box-shadow: 0 1px 2px rgba(0,0,0,.2)`.
2. Create `skills/design-study/tests/test_study_site.py` — plain asserts, no framework. It puts `../scripts` on `sys.path` before `import study_site`:
   - `rgb_to_hex("rgb(10, 124, 255)") == "#0a7cff"`; `rgb_to_hex("rgba(0, 0, 0, 0)") is None`; `rgb_to_hex("oklch(0.7 0.1 200)") == "oklch(0.7 0.1 200)"` (non-rgb values pass through unchanged).
   - `tally([...])` on a small hand-made sample list returns values sorted by count, capped at 20 per property, and splits a `padding: "8px 16px"` sample into `8px` and `16px` in the `spacing` bucket.
   - `slugify("https://Ex.com/a/../b?x=1")` contains only `[a-z0-9-]`.
   - End to end: run `capture(fixture file:// URL, tmp dir)`; assert `390.png` and `1440.png` exist, `tokens.json` has `custom_properties["--brand"] == "#0a7cff"`, and `#0a7cff`, `12px`, `32px`, `8px` and `Georgia, serif` appear in the matching tallies.
   - Prints `ok` on success.
3. Run `/Users/amirinns/PythonEnv/isaham/bin/python skills/design-study/tests/test_study_site.py` — expect FAIL: `ModuleNotFoundError: No module named 'study_site'`.
4. Create `skills/design-study/scripts/study_site.py` in the house Python style (functional, imports at top, argparse, stdlib plus Playwright):
   - `rgb_to_hex(value)` — opaque `rgb()`/`rgba()` to `#rrggbb`; `None` when alpha is 0; any other value (partial alpha, `oklch()`, `color()`) returned unchanged. Chrome keeps authored `oklch()` colors in computed style, so these must not be dropped.
   - `slugify(url)` — host plus path, lowercased, every run of characters outside `[a-z0-9]` replaced by `-`, trimmed. Keeps output folders inside `--out`.
   - `COLLECT_JS` — a JS string that walks visible elements (skip `display:none` and zero-size boxes, cap at 3000), reads computed `font-family`, `font-size`, `font-weight`, `line-height`, `color`, `background-color`, `border-color`, `border-radius`, `box-shadow`, `padding`, `margin`, `gap`, and reads `--*` custom properties (values trimmed) by iterating `getComputedStyle(document.documentElement)`.
   - `tally(samples)` — counts per property; colors through `rgb_to_hex`; `padding`, `margin` and `gap` shorthands split on spaces into one `spacing` bucket; drops `0px`, `none`, `normal` and `None`; top 20 per property.
   - `capture(url, out_dir)` — headless Chromium; for widths 390 and 1440, open a context at that viewport, `goto(url, wait_until="load", timeout=30000)`, then wait 1500 ms for late styles (`networkidle` never fires on pages with analytics beacons or long polling), full-page screenshot to `<out_dir>/<width>.png`, collect samples; write `<out_dir>/tokens.json` with `url`, `captured_at`, `widths`, `custom_properties`, `tally`.
   - `main()` — `study_site.py URL [URL ...] --out DIR`; one `slugify(url)` subfolder per URL. A URL that fails to load prints one error line naming the URL and the Playwright error, the rest still run, and the exit code is 1 if any failed.
5. Run the test again — expect `ok`.
→ Verify: the test prints `ok`; `study_site.py https://example.com --out <scratch dir>` writes both PNGs and a `tokens.json` with a non-empty `tally.font-size`; `study_site.py https://nonexistent.invalid https://example.com --out <scratch dir>` prints one error line for the first URL, writes the second, and `echo $?` prints `1`.

### Milestone 3: design-study skill
1. Create `skills/design-study/SKILL.md` with frontmatter `name: design-study` and a description: learns an existing website, app codebase or screenshots, measures its real tokens, lists its components, and writes a DESIGN.md that `prototype-ui` and `frontend-design` follow. Triggers: "study this site", "learn the design from", "extract the design system", "make our design follow this app", "copy the look of our existing app". Do NOT trigger on: critiquing or redesigning a UI (use design-critique), building UI (use frontend-design).
2. Same file — intro and shared references block pointing at `../frontend-design/references/design-md-template.md`, `design-rules.md` and `domain-audience-playbook.md`, with the same not-installed fallback sentence.
3. Same file — the flow:
   - **Step 1: Source and ownership.** Ask once whether the source is the user's own product or a third-party reference. Own product: copy exact tokens. Third-party: take structure and traits only (type ratio, spacing scale, radius, density, layout patterns); never the logo, brand colors, brand font or exact screens.
   - **Step 2: Capture.** Live URL: from the project root, run `/Users/amirinns/PythonEnv/isaham/bin/python <skill-dir>/scripts/study_site.py <url> --out design/study` (the script adds the URL slug folder). Codebase: read theme sources in this order: CSS custom properties, Tailwind config, SCSS/Bootstrap variable overrides, React Native/Expo theme files, then the most-used components. Screenshots: read them directly and mark every value as estimated.
   - **Step 3: Measure.** Turn the tally or theme files into tokens: font families, a type scale (round to the nearest common step and note outliers), color roles (bg, surface, text, muted, accent, positive, negative, danger) chosen by usage, spacing scale snapped to 4/8, radius, shadows, density. Flag inconsistencies (for example seven grays or four radii) as findings, not tokens.
   - **Step 4: Inventory.** List components (buttons, inputs, cards, tables, nav, modals or sheets) one line each, plus layout patterns and the states seen.
   - **Step 5: Sheet and approval.** Write `design/study/<source-slug>/sheet.html`: swatches with hex and role, the type scale rendered, spacing and radius samples, the component list, screenshots side by side. Show it and iterate on the user's reactions.
   - **Step 6: Write DESIGN.md** from the shared template, filling `## Source` with each value's origin (measured, theme file, or estimated) and the ownership answer. Hand off in one line: `design-critique` to improve it, `prototype-ui` for the next big feature, or `frontend-design` to build.
4. Same file — Rules: only study pages the user names and is allowed to view; no login or stealth; never copy a third-party logo, brand colors, brand font or exact screens; captures of a third-party site stay under `design/study/` as reference and never enter the app bundle; mark estimated values as estimated.
5. Link the new skill into every agent that already links `prototype-ui`: `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, `~/.gemini/antigravity-cli/skills`. In the same pass, link `design-critique` into `~/.pi/agent/skills` and `~/.gemini/antigravity-cli/skills`, where it is missing today.
→ Verify: `head -4 <dir>/design-study/SKILL.md` prints the frontmatter for all four dirs; every command, flag and path the skill names exists (`study_site.py --help`, the reference files, the venv python).

### Milestone 4: Template, README, docs
1. `skills/frontend-design/references/design-md-template.md` — add `design-study` to the list of skills that write DESIGN.md in line 3, and add an optional `## Source` section after `## Vibe`: "Only when studied from an existing product: source URL, codebase path or screenshots; own or third-party; per-token origin (measured / theme file / estimated)."
2. `README.md:72` — add a tree entry for `design-study/` with `SKILL.md`, `scripts/` (site study script) and `tests/`, next to `design-critique/SKILL.md`.
3. `README.md:105` — add `DS[design-study] -.->|DESIGN.md| FD` to the flowchart.
4. `README.md:163` — add `design-study` to the Design row's skill list and one sentence: `design-study` measures an existing site, app or screenshots and writes `DESIGN.md` from it.
5. `docs/skill-updates-2026-10.md:142-145` — remove the bullet that says `design-critique` is missing.
→ Verify: `grep -n "not in this change set" docs/skill-updates-2026-10.md` prints nothing; `grep -c design-study README.md` prints 3 or more; `git status --porcelain` lists only the files in Affected Files.

## Affected Files
- Files to modify: `skills/design-critique/SKILL.md` (currently untracked, restored from a dangling blob), `skills/frontend-design/references/design-md-template.md`, `README.md`, `docs/skill-updates-2026-10.md`
- New files to create: `skills/design-study/SKILL.md`, `skills/design-study/scripts/study_site.py`, `skills/design-study/tests/test_study_site.py`, `skills/design-study/tests/fixture.html`
- Outside the repo: `design-study` symlinks in `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, `~/.gemini/antigravity-cli/skills`; `design-critique` symlinks in the last two

## Acceptance Criteria
- [ ] `design-critique` has no inline playbook, points at the four shared references, and routes study requests to `design-study`.
- [ ] No line in `design-critique` says `frontend-design` wireframes or prototypes.
- [ ] `test_study_site.py` prints `ok`, and it failed before the script existed.
- [ ] `study_site.py` on a real public URL writes `390.png`, `1440.png` and a non-empty `tokens.json`.
- [ ] `design-study` covers URL, codebase and screenshot input, the ownership rule, the sheet approval step, and DESIGN.md with `## Source`.
- [ ] `design-study` resolves in all four agent skill dirs, and `design-critique` resolves in pi and agy.
- [ ] `study_site.py` with one bad URL and one good URL writes the good one, prints one error line, and exits 1.
- [ ] README and the October update doc list both skills and no longer describe `design-critique` as missing.

## Tests
- Test type: unit plus one end-to-end run against a local fixture.
- New tests: `skills/design-study/tests/test_study_site.py`, run with `/Users/amirinns/PythonEnv/isaham/bin/python`.
- Existing tests to run: none touch these files.

## Dependencies
- Playwright for Python 1.53.0 and its Chromium 138, already installed in `/Users/amirinns/PythonEnv/isaham`. A probe on 2026-10-13 launched it headless on a `file://` page, enumerated `--*` custom properties from `getComputedStyle`, and showed `padding` as the shorthand `8px 16px` and an `oklch()` color kept as `oklch(...)`. No new libraries.

## Decisions Log
| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
| How the skill measures a live site | Bundled script `study_site.py` (user's pick) | Instructions only, using the agent's browser tool; a JS snippet file pasted into the browser tool | Same output in Claude, Codex, agy and pi, and it can ship with a test |
| Where study lives | Separate `design-study` skill (user's pick) | A study mode inside `design-critique` | Different requests and triggers; critique's taste and exploration phases don't apply; keeps `design-critique` from growing |
| Which Python runs the script | isaham venv | recon-tools `.venv`; a new venv | It is the shared venv for this workspace and already has Playwright |
| Browser | Headless bundled Chromium | Real Chrome with a profile, as `site-clone` does | Public pages only; no stealth or login needed |
| Third-party sources | Structure and traits only | Copy exact tokens from any source | Matches the existing rule against replicas; own products keep exact tokens |
| Output location | `design/study/<source-slug>/` | `design/<feature>/`; a temp dir | Study is per source, not per feature; it sits next to `prototype-ui`'s `design/` output |
| Playbook in `design-critique` | Drop it, read the shared one | Keep both copies | Diff shows the same entries; one copy avoids drift |
| Source section | Optional section in the shared template | Separate `SOURCE.md` | One file stays binding; other skills already read the template |

## Review Log

### Review 1 — 2026-10-13
**Flaws found:** 10
**Changes made:**
- Spacing tally now splits `padding`, `margin` and `gap` shorthands into single values — **Reason:** a Playwright probe showed computed `padding` comes back as `8px 16px`, which would never match a spacing scale.
- `rgb_to_hex` passes non-rgb colors through unchanged — **Reason:** the probe showed Chrome keeps authored `oklch()` colors as `oklch(...)`; the old rule would have dropped modern palettes.
- Page load uses `load` plus a 1500 ms settle instead of `networkidle` — **Reason:** `networkidle` never fires on pages with analytics beacons or long polling, so real sites would time out.
- Added `slugify(url)` with a test — **Reason:** URL text becomes a folder name; unsanitized `..` or `/` could write outside `--out`.
- Failed URLs print one error line, the rest still run, exit code 1 — **Reason:** a dead or blocked URL is the most likely failure, and it had no defined behavior. Added an acceptance check and a verify command for it.
- Test puts `../scripts` on `sys.path` — **Reason:** tests/ and scripts/ are sibling folders, so a plain import fails for the wrong reason.
- The skill runs the script as `<skill-dir>/scripts/study_site.py` from the project root with `--out design/study` — **Reason:** the relative `scripts/` path only works from inside the skill folder.
- Symlinks go into all four agent skill dirs (Claude, Codex, pi, agy), and `design-critique` gets the pi and agy links it lacks — **Reason:** `prototype-ui` is linked in all four; Claude only would leave Codex, pi and agy without the new skill.
- Playbook delete range is lines 129 to 155 — **Reason:** 131 to 154 left two `---` separators back to back.
- Rule added that third-party captures stay under `design/study/` and never enter the app bundle — **Reason:** screenshots of someone else's site are reference material only.
**Still open:**
- None.

### Review 2 — 2026-10-13
**Flaws found:** 1
**Changes made:**
- Milestone 2 verify now runs the bad-URL case — **Reason:** Review 1 added the acceptance criterion but no milestone check exercised it.
**Still open:**
- None. Pass 3 found nothing new; plan is stable.
