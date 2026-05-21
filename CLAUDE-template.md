# CLAUDE.md — [Project Name]

## Development Workflow (SDLC)

Follow the SDLC phases for feature development. Each phase has a dedicated skill.

| Phase | Skill | Notes |
|-------|-------|-------|
| **1. Planning** | `plan-feature` | Create a focused plan in `plans/` |
| **2. Analysis** | `plan-review` | Review the plan. Run multiple times until no critical flaws remain |
| **3. Design** | `frontend-design` / `frontend-bootstrap-evolution` | Frontend features only. Backend follows CLAUDE.md guidelines |
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
