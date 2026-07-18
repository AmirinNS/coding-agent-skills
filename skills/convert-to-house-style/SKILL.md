---
name: convert-to-house-style
description: "Migrate an EXISTING project toward the user's house style — Flask + Bootstrap 5 + MongoDB (PyMongo, no ORM), functional architecture with thin routes and an isolated service layer. Assess the current project, produce a gap report + phased migration plan in plans/, then migrate slice-by-slice keeping the app runnable and verified. Use when converting, migrating, refactoring, or aligning an existing codebase to the house style. Triggers: 'convert this project', 'migrate to my style', 'refactor to house style', 'align this project', 'bring this up to standard', 'convert to Flask/Mongo'. Do NOT use for brand-new projects — use scaffold-project instead."
---

# Convert to House Style

You are migrating an **existing** project toward the user's house style. This is a refactor/migration, not a rewrite. The app must stay runnable at every step, changes are surgical, and nothing dangerous happens without a committed baseline and an approved plan.

**If the target is an empty/new project, stop — use `scaffold-project` instead.**

## Target house style (the destination)

- **Backend:** Flask, thin route handlers.
- **Database:** MongoDB via PyMongo — direct driver calls, **no ORM** (no MongoEngine, no Repository pattern).
- **Frontend:** Jinja2 templates + Bootstrap 5 + vanilla JS. Pages `{% extends "base.html" %}`; the navbar and footer live in shared, underscore-prefixed partials (`_navbar.html`, `_footer.html`) pulled in with `{% include %}` — no chrome duplicated per page.
- **Architecture:** Functional. Business logic in `modules/` as pure functions that take `db` explicitly. Shared helpers/config in `sources/`. Templates in `templates/`, assets in `static/`.
- **Discipline:** imports at top of file (never inside functions); 4-space indent for new/edited code (match a file's existing indent when editing it); dedicated venv at `/Users/amirinns/PythonEnv/<module_name>/`; plans in `plans/`.

### Single source of truth (read this before planning)

The bullets above are a summary, not the spec. The **canonical definition of the house style lives in the `scaffold-project` skill**, and it can change. Do not rely on your memory of it. Before you plan or migrate:

1. **Read `scaffold-project/SKILL.md`** — its "Non-negotiable conventions" and "Rules" are the authoritative *directives* (prose conventions that aren't files). If a new direction was added there, it applies here too.
2. **List `scaffold-project/assets/`** — those physical files are the authoritative *content*. Whatever that tree contains today is the target, even if it differs from these bullets.

When this skill needs to create or replace a file (a new `base.html`, `_navbar.html`, `sources/config.py`, etc.), **copy the file from `scaffold-project/assets/` and substitute the tokens** `__PROJECT_NAME__` / `__MODULE_NAME__` / `__DB_NAME__` / `__DESCRIPTION__` — do not hand-write it. That is what guarantees a converted project is byte-for-byte indistinguishable from a freshly scaffolded one, and that any future change to `scaffold-project` automatically flows into conversions.

Match this destination, but see the **Reality check** rule below — do not force a migration the project doesn't need.

## Step 0: Safety gate (do this first, always)

1. Confirm the working tree is clean (`git status`). If there are uncommitted changes, ask the user to commit or stash first — you need a known-good baseline to revert to.
2. If the project is not a git repo, offer to `git init` + commit a baseline before touching anything. Do not migrate an unversioned project without the user's explicit OK.
3. Confirm the project's dedicated venv path. Default `/Users/amirinns/PythonEnv/<module_name>/`. If it doesn't exist yet, note that it'll be needed.

Never begin migration edits until there is a committed baseline you can roll back to.

## Step 1: Assess the current project

Read before concluding — do not assume. Cover:

- `CLAUDE.md`, `AGENTS.md`, `README.md`, `docs/` — the project's own stated conventions (these override the generic house style where they conflict; surface conflicts, don't silently override).
- **Framework:** Flask / Bottle / Django / FastAPI / other? (check entrypoint + imports)
- **Database:** MongoDB / Postgres / MySQL / SQLite? ORM in use (SQLAlchemy, MongoEngine, Django ORM)?
- **Layout:** where do routes, business logic, templates, static, config live? Is logic tangled into route handlers?
- **Frontend:** Bootstrap version (check `base.html`/`layout.html`/`package.json` — BS4 vs BS5 class names differ), custom CSS, build pipeline (`dev/`, npm, parcel/gulp, webpack), or CDN?
- **Import hygiene:** imports inside functions? indentation (tabs vs spaces)?
- **Tests:** what exists, how they run.

Produce findings as a **gap report** (see template).

## Step 2: Reality check (decide scope honestly)

Not every deviation is worth migrating. Before planning, judge:

- **A different framework/DB is a major migration, not a cleanup.** Flask→? or Postgres→MongoDB rewrites data access across the whole app and can change behavior. Never assume the user wants this — call it out explicitly and get a decision. A working Postgres app usually should *stay* Postgres unless the user specifically wants Mongo.
- **Bootstrap 4→5** is mechanical but wide (class renames, `data-bs-*`, JS bundle). Worth it, but scope it as its own phase.
- **Fat routes → service layer** and **imports-inside-functions → top-level** are low-risk, high-value — usually the best first slices.
- If the project already conforms, say so and stop. Don't manufacture work.

If a genuinely large migration (framework or DB swap) is on the table, **ask the user to confirm the endpoint before planning** — present it as a decision with the cost, don't bury it in a plan.

## Step 3: Write a phased migration plan

Save to `plans/convert-to-house-style.md` (kebab-case). Each phase must leave the app **runnable and verifiable** on its own — phases are independent slices, not checkpoints in one big-bang rewrite. Order phases lowest-risk-first.

```markdown
# Plan: Convert <project> to House Style

## Current state
One paragraph: framework, DB, layout, frontend, key deviations.

## Target state
Flask + Bootstrap 5 + MongoDB (or the subset the user approved). Note anything intentionally left as-is and why.

## Gap Report
| Area | Current | House style | Gap severity | Migrate? |
|------|---------|-------------|--------------|----------|
| Framework | ... | Flask | none/low/med/high | yes/no/defer |
| Database | ... | MongoDB (PyMongo) | ... | ... |
| Route/logic separation | ... | thin routes + modules/ | ... | ... |
| Frontend | ... | Bootstrap 5 | ... | ... |
| Shared chrome | ... | navbar/footer as `_navbar.html`/`_footer.html` partials via `{% include %}` | ... | ... |
| Run modes | ... | `APP_ENV` dev/testing/production; native Flask for dev/testing, WSGI (waitress) for production; app + DB co-located, `MONGO_URI` per env | ... | ... |
| SEO baseline | ... | meta/OG/Twitter/canonical in `base.html`, `sources/seo.py` defaults, `/robots.txt` + `/sitemap.xml` (rich JSON-LD/dynamic sitemap = `add-capability` (seo)) | ... | ... |
| Error pages | ... | one themed `error.html` for all codes via `sources/errors.py` (`init_errors`), JSON for `/api`, `noindex` | ... | ... |
| Import hygiene | ... | top-level only | ... | ... |
| Layout | ... | modules/ sources/ templates/ static/ | ... | ... |

## Phases (each independently shippable + verifiable)
### Phase 1: <lowest-risk slice, e.g. import hygiene + extract service functions>
1. [step — file, change]
→ Verify: app boots, <existing tests / curl a route> still pass.

### Phase 2: <next slice>
...
→ Verify: ...

## Out of scope
- What is deliberately NOT being changed (with reason).

## Rollback
Per phase: `git revert`/reset to the phase's baseline commit.

## Decisions Log
| Decision | Chosen | Alternatives | Why |
|----------|--------|--------------|-----|
```

Then present the plan for approval. Recommend running the `plan-review` skill on it before implementing, per the user's workflow. **Do not start migrating until the plan is approved.**

## Step 4: Migrate one phase at a time

For each approved phase:
1. Make the surgical edits for that phase only. Don't "improve" adjacent code (per CLAUDE.md guideline 4).
2. Keep the app runnable — never leave it broken between phases.
3. **Verify:** run the app (`/Users/amirinns/PythonEnv/<module_name>/bin/python <entrypoint>`), hit the affected routes, run existing tests. Confirm behavior is unchanged.
4. Commit the phase with a conventional message before starting the next.
5. Recommend the `implementation-review` skill after a non-trivial phase.

If a phase can't be verified green, stop and report — don't stack another phase on a broken one.

## Rules

- **No baseline, no migration.** A committed, revertible starting point is mandatory.
- **App stays runnable every step.** No big-bang rewrites; slice it.
- **Surgical changes only.** Every changed line traces to the migration. Don't refactor things that aren't in the plan; mention unrelated dead code, don't delete it.
- **Framework/DB swaps need explicit sign-off** — never assume the user wants Postgres→Mongo or a framework change; present the cost and let them decide.
- **Respect the project's own `CLAUDE.md`.** Where it conflicts with the generic house style, surface the conflict and let the user choose.
- **Don't manufacture work.** If it already conforms, say so and stop.
- Enforce house-style discipline in what you touch: functional (no OOP for logic/views), direct PyMongo (no ORM), thin routes + `modules/` service layer, top-level imports, 4-space indent for new code.
- For new files created during migration, **copy from `scaffold-project/assets/` and substitute tokens** — never hand-write them. Read `scaffold-project/SKILL.md` first so any prose conventions added there are honored too. This is the mechanism that keeps convert output identical to scaffold output as the house style evolves.
