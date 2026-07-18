---
name: scaffold-project
description: "Scaffold a new web project in the user's house style — Flask + Bootstrap 5 (CDN) + MongoDB (PyMongo, no ORM), functional architecture with thin routes and an isolated service layer. Use when the user wants to start, create, bootstrap, or scaffold a new project/app from scratch. Triggers: 'new project', 'scaffold a project', 'start a new app', 'bootstrap a Flask app', 'create a new project', 'set up a new project'."
---

# Scaffold Project

You are scaffolding a **new** project in the user's established house style. The canonical stack is **Flask + Bootstrap 5 (CDN) + MongoDB (PyMongo, direct driver calls, no ORM)**, functional architecture (no classes for business logic or views), thin route handlers, business logic in `modules/` as pure functions that take `db` explicitly.

The starter files are **physical assets** in this skill's `assets/` directory and are stamped out by `scaffold.sh` — you do not hand-write them. This guarantees every scaffolded project is byte-for-byte consistent, and lets the `convert-to-house-style` skill reuse the exact same files.

## Non-negotiable conventions

- **Functional only.** No OOP for business logic or views. Pure functions in `modules/`.
- **No ORM.** Direct `db.collection.find(...)` / `insert_one(...)` PyMongo calls.
- **Imports at the top of every file.** Never import inside a function.
- **4-space indentation** for all new files.
- **Thin routes, isolated service layer.** Handlers parse the request, call a `modules/` function passing `db` explicitly, and render/return.
- **Shared page chrome** (navbar, footer) lives in `templates/_navbar.html` / `templates/_footer.html`, pulled into `base.html` with `{% include %}`.
- **Themed error pages** ship in the scaffold: one `templates/error.html` (extends `base.html`, `noindex`) serves every HTTP status via `sources/errors.py` (`init_errors(app)` registers a handler for all codes; API/`/api` + JSON-Accept callers get JSON; render-failure fallback; `Retry-After` on 429). Pattern lifted from isaham-learn. (In dev/testing, Flask's debugger still intercepts 500s; the themed page shows in production.)
- **Baseline SEO** ships in the scaffold: `base.html` carries meta description + Open Graph + Twitter + canonical (per-page overridable via `{% block title %}` / `{% block meta_description %}`), `sources/seo.py` holds defaults + `canonical_url()`, and the entrypoint serves `/robots.txt` + a minimal `/sitemap.xml`. Rich JSON-LD and dynamic DB-driven sitemaps are the `add-capability` skill's job (seo), not the scaffold's.
- **Three run modes via `APP_ENV`.** `development` and `testing` use the native Flask server with debug on; `production` uses the waitress WSGI server with debug off. One mode-aware entrypoint; the native Flask server is never used in production. The app and MongoDB are assumed co-located (same host); `MONGO_URI` is set per environment in `.env` (testing may point at a remote/shared DB), never hardcoded.
- **Dedicated venv** at `/Users/amirinns/PythonEnv/<module_name>/` — never system `python`/`pip`.
- **`plans/` folder** from day one; plan files are kebab-case markdown.
- Stack changes (different framework/DB) require explicit user approval — don't substitute.

## Step 0: Gather inputs

Ask only for what you can't confidently infer:

| Input | Default / how to derive |
|-------|-------------------------|
| **Project name** (display, e.g. `Deal Tracker`) | Ask if not given |
| **`module_name`** (Python-safe) | lowercase, `-`/spaces → `_`, e.g. `deal_tracker`. Used for entrypoint filename, venv name, default db name. |
| **One-line description** | Ask, or infer from context |
| **Target directory** | Default `~/Projects/<module_name>`. Confirm if it might collide. |
| **Mongo db name** | Default `<module_name>` |

If the target directory already exists and is non-empty, this is not a scaffold job — **stop** and point the user at the `convert-to-house-style` skill.

## Step 1: What gets generated

```
<target>/
  <module_name>.py        # Flask entrypoint — thin routes + context processor
  modules/                # business logic (pure functions, direct PyMongo)
    __init__.py  items.py
  sources/                # config.py (env + Mongo client), functions.py, seo.py, errors.py
    __init__.py  config.py  functions.py  seo.py  errors.py
  templates/              # base.html (SEO meta/OG) + _navbar.html + _footer.html + index.html + error.html
  static/                 # css/theme.css  js/app.js  img/
  plans/                  # .gitkeep
  requirements.txt  .env.example  .gitignore  README.md  CLAUDE.md
```

The authoritative source for every one of these files is `assets/` in this skill. If you need to see exactly what will be written, read the files under `assets/` — do not reproduce them from memory.

## Step 2: Run the assembler

Run `scaffold.sh` from this skill's directory (it copies `assets/`, renames placeholder files, and substitutes the four tokens `__PROJECT_NAME__`, `__MODULE_NAME__`, `__DB_NAME__`, `__DESCRIPTION__`):

```bash
bash <path-to-this-skill>/scaffold.sh "<target>" "<Project Name>" "<module_name>" "<db_name>" "<description>"
```

Example:

```bash
bash <path-to-this-skill>/scaffold.sh ~/Projects/deal_tracker "Deal Tracker" deal_tracker deal_tracker "Tracks the best deals across brands."
```

After it runs, confirm there are no leftover `__…__` tokens:

```bash
grep -rn "__PROJECT_NAME__\|__MODULE_NAME__\|__DB_NAME__\|__DESCRIPTION__" "<target>" || echo "clean"
```

## Step 3: Create the venv, install, and verify it runs

```bash
python3 -m venv /Users/amirinns/PythonEnv/<module_name>
/Users/amirinns/PythonEnv/<module_name>/bin/pip install --upgrade pip
/Users/amirinns/PythonEnv/<module_name>/bin/pip install -r <target>/requirements.txt
```

Then verify: launch the app in the background from the project directory
(`/Users/amirinns/PythonEnv/<module_name>/bin/python <module_name>.py`), wait a moment, then
`curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health` — expect **200**. Then stop the
background app.

`/health` does not touch Mongo (PyMongo connects lazily), so verification does not require a live database.

## Step 4: Report

Tell the user:
- Where the project was created and that assets were stamped from the canonical skeleton.
- That the venv exists at `/Users/amirinns/PythonEnv/<module_name>/` and deps are installed.
- The `/health` smoke-test result (the HTTP code you observed).
- The run command: `/Users/amirinns/PythonEnv/<module_name>/bin/python <module_name>.py`.
- That `modules/items.py` + the `items` template are a placeholder example to rename/replace.
- Offer to `git init` + initial commit if they want (don't do it unprompted).

## Rules

- **Do not hand-write the starter files.** Edit `assets/` and let `scaffold.sh` do the stamping. If a convention changes, change it in `assets/` (and, if it's a prose rule, here in this SKILL) — never fork the templates into a one-off.
- Do not add features, config, or abstractions beyond the skeleton. It is deliberately minimal.
- Do not swap the stack. Flask + Bootstrap 5 (CDN) + MongoDB is the house default; changing it needs the user's say-so.
- Do not add a `dev/` npm build pipeline — this scaffold uses Bootstrap via CDN by design.
- If the user's request implies a different layout (e.g. a CLI pipeline alongside the web server), mention the `app_shared/` + `server/` variant used in `jimmat` and let them choose — don't silently restructure.
