# CLAUDE.md — [Project Name]

## Development Workflow (SDLC)

Follow the SDLC phases for feature development. Each phase has a dedicated skill.

| Phase | Skill | Notes |
|-------|-------|-------|
| **1. Planning** | `plan-feature` | Create a focused plan in `plans/` |
| **2. Analysis** | `plan-review` | Review the plan. Run multiple times until no critical flaws remain |
| **3. Design** | `frontend-design` / `frontend-bootstrap-evolution` / `python-development` | `frontend-design` for UI, `python-development` for Python. A feature can need both |
| **4. Implementation** | `implementation-review` → `create-docs` → `generate-commit` | Review code (2x), generate docs, commit |
| **5. Maintenance** | `fix-bug` | Reproduce-first bug fixing. Skips phases 1-3 |

## Critical Setup

<!-- Add any critical rules that must always be followed -->
<!-- Examples: -->
<!-- > **PERMISSION REQUIRED: Never read `.env` without explicit user permission.** -->

- **Runtime environment:**
  ```
  # e.g., python venv, node version, etc.
  ```

## Project Overview

<!-- 1-3 sentences: what this project does -->

## Information Sources

<!-- Where to look first before making assumptions -->
- README: `README.md`
- Docs: `docs/`

## Stack

<!-- List the actual tech used — framework, database, frontend, testing, etc. -->

- **Backend:** <!-- e.g., Flask, Express, Django, Rails -->
- **Database:** <!-- e.g., PostgreSQL, SQLite, MongoDB -->
- **Frontend:** <!-- e.g., React, Vue, Jinja2 + Vanilla JS -->
- **Testing:** <!-- e.g., Jest, pytest, unittest -->
- **Other:** <!-- e.g., message queues, external APIs, CDN -->

Any framework/database change requires explicit user approval.

## Language Conventions

Style rules that always apply, regardless of what a plan says. An agent reads this section
before writing code, so state the rules here even when they feel obvious. A convention that
lives only in your head gets violated by every agent that touches this project.

**Delete the blocks below that do not apply, and fill in the one that does.**

<!-- PYTHON. Delete this block if the project is not Python -->

- **Imports at the top of every file.** Never inside a function. The only exceptions are
  breaking a real circular import or deferring a heavy optional dependency, and both carry a
  comment saying which.
- **Functional for business logic and views.** No classes. Business logic lives in `modules/`
  as pure functions that take `db` explicitly. A class is allowed only when a framework
  demands one (for example `flask-login`'s `User(UserMixin)`), for a custom exception type,
  or for a `frozen=True` dataclass value object.
- **No ORM.** Direct PyMongo calls.
- **Thin routes.** A handler parses the request, calls one `modules/` function, and renders or
  returns. Logic in a route handler is a bug.
- **PEP 8**, 4-space indent. When editing an existing file, match that file.
- **The project venv only**, never system `python` / `pip`. Path is under Critical Setup above.

Depth on all of this, including when a class is genuinely justified and the footguns to check
for, is in the `python-development` skill.

<!-- JAVASCRIPT / TYPESCRIPT. Delete this block if not applicable -->

<!--
- **Module system:** e.g. ESM only, no `require`
- **Types:** e.g. strict mode on, no `any` without a comment
- **Formatting:** e.g. Prettier, 2-space indent, run `npm run lint` before handing off
- **Framework rules:** e.g. server components by default, `use client` only where needed
-->

<!-- OTHER LANGUAGE. Replace with the rules for this project's language -->

## Running Tests

```bash
# All tests
# e.g., npm test, pytest, make test

# Individual suites
# e.g., npm run test:unit, npm run test:e2e
```

## Common Commands

```bash
# Start dev server
# e.g., python -m server.app, npm run dev

# Build
# e.g., npm run build

# Lint
# e.g., npm run lint, flake8

# Database
# e.g., python manage.py migrate
```

## Architecture

```
project-root/
├── src/                # <!-- describe -->
├── tests/              # <!-- describe -->
├── docs/               # <!-- describe -->
└── .env                # <!-- describe -->
```

<!-- Optional: describe the high-level data flow or pipeline stages -->

## Key Patterns

<!-- Non-obvious conventions that an agent needs to know -->
<!-- Examples: -->
<!-- - Deduplication via UNIQUE index on X -->
<!-- - Config is stored in DB, not files -->
<!-- - Imports: shared/ must never import from app/ -->

## Important File Locations

<!-- Quick reference for the most important files -->
<!-- - Main app entry: `src/app.py` -->
<!-- - Database config: `src/db.py` -->
<!-- - Routes: `src/routes/` -->

## Plan File Location

All plan files MUST be saved in `plans/` (e.g., `plans/feature-name.md`). Use kebab-case for file names. After creating a plan, suggest starting a new conversation for implementation.

## Dependencies

<!-- List key dependencies and how to install them -->
<!-- e.g., Flask, React, PostgreSQL. Install with `npm install` or `pip install -r requirements.txt` -->
