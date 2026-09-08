---
name: scaffold-electron-desktop
description: "Scaffold a new Electron desktop app on the standard electron-vite single-app layout (src/main, src/preload, src/renderer) with one enforced extra: all logic lives in src/main/core/, a UI-free boundary wired to the shell by a typed contextBridge preload and an event bus. Ships better-sqlite3 persistence, a long-running-job reference, and boundary tests. Use when the user wants to start a new desktop application, a GUI wrapper around long-running local work, or an Electron app in general. Triggers: 'new electron app', 'scaffold an electron desktop app', 'create a desktop app', 'start an electron project', 'build a desktop GUI', 'electron + react app'. Do NOT use for web apps — use scaffold-project (Flask house style) instead."
---

# Scaffold Electron Desktop

You are scaffolding a **new** Electron desktop app on the standard
electron-vite layout — the shape every plan, tool, and tutorial already
assumes: `src/main`, `src/preload`, `src/renderer`, one `package.json`.
On top of that layout the scaffold enforces one non-standard rule: all logic
lives in `src/main/core/`, which knows nothing about Electron or React.

The starter files are **physical assets** in this skill's `assets/` directory
and are stamped out by `scaffold.sh`. You do not hand-write them.

## Why the boundary exists (and why it is not a monorepo)

This skill descends from pembina, where an `engine/` workspace serves three
real hosts (`cli/`, `tui/`, `desktop/`). A workspaces monorepo is right there
because the second (and third) host actually ships. It is wrong for a new
Electron app whose only host today is the shell: you pay workspace resolution,
a build-ordering dependency, and packaging friction for a future that may
never come — and you collide with every plan and tool that expects the
electron-vite default layout.

So this scaffold keeps the boundary but drops the monorepo. The split still
buys its three things, now enforced by tests instead of package boundaries:
the logic is testable in plain Node (vitest runs `src/main/core/` without
Electron), extracting a second host later is a mechanical move of one
directory, and a UI bug can never be a logic bug.

If the app is planned from day one to ship multiple hosts (a CLI plus the
desktop shell, like pembina), say so and borrow pembina's workspaces layout
instead — do not use this skill's default for that case.

Long-running work is the case this scaffold is built for — a job that takes
seconds to minutes, streams progress, and can be cancelled. If the app is just
forms over a database, this is more structure than the problem needs; say so
and offer a plain `npm create electron@latest` start instead.

## Non-negotiable conventions

- **ESM import paths carry `.js`.** The app is `"type": "module"` with
  `module: NodeNext`. Every intra-project import needs the extension even when
  the source is `.ts`/`.tsx` — `tsc` does not rewrite them and Node throws
  `ERR_MODULE_NOT_FOUND` at runtime.
- **Core never imports `electron`, `react`, `react-dom`, or anything outside
  `src/main/core/`.** Progress leaves core through the `JobEventBus`, and that
  bus is the only channel into a UI. `tests/core-boundary.test.ts` enforces it.
- **`src/main/core/index.ts` is the entire public surface of core.** The shell
  imports `./core/index.js` and never a deeper path like
  `./core/store/runs.js`. The boundary test enforces the barrel and
  `tests/core/export-surface.test.ts` is the canary for removals.
- **The preload uses `import type` for core only.** A value import of core
  drags better-sqlite3 into the preload bundle, which fails at load. The
  boundary test enforces this too.
- **IPC handlers stay thin.** Translate the payload, call core, translate back.
  Logic inside a handler cannot be tested without Electron.
- **Long-running work takes an `AbortSignal` and returns a status.** Cancelling
  returns `status: "aborted"`, it does not throw. Every exit path emits exactly
  one `job-end` and writes exactly one row.
- **Events must survive `structuredClone`.** They cross IPC — plain objects,
  no class instances, no Dates, no functions.
- **Two native rebuilds, not one.** better-sqlite3 needs the Electron ABI to
  run the app and the Node ABI to run the tests. Both scripts ship.
- **One accent hue.** `--accent: #0ea5e9` for interactive elements; amber/red/
  green are reserved for status. Extend the tokens in `App.css` rather than
  introducing a competing accent.

## Step 0: Gather inputs

Ask only for what you cannot confidently infer.

| Input | Default / how to derive |
|-------|-------------------------|
| **Project name** (display, e.g. `Deal Tracker`) | Ask if not given |
| **`module_name`** (kebab-case) | lowercase, spaces/underscores → `-`, e.g. `deal-tracker`. Drives the package name, the `window` global, the env prefix, and the `~/.<module_name>/` fallback state dir. |
| **App id** (reverse-DNS) | `com.<user-or-org>.<module_name without dashes>`. Confirm the vendor part. |
| **One-line description** | Ask, or infer from context |
| **Target directory** | Default `~/Projects/<module_name>`. To scaffold into an existing repo, target a subdirectory (e.g. `~/Projects/<repo>/app`) — the skill's structure sits at that target's root. Confirm if it might collide. |

The script derives `__PROJECT_TYPE__` (PascalCase), `__API_GLOBAL__`
(camelCase `window` global), and `__ENV_PREFIX__` (UPPER_SNAKE env prefix) from
`module_name` — do not ask for those.

If the target directory exists and is non-empty, the script refuses. That is a
migration, not a scaffold; stop and tell the user.

## Step 1: What gets generated

```
<target>/
  package.json            # single app: dev/test/lint/build/dist scripts
  tsconfig.json  vitest.config.ts  eslint.config.mjs  .gitignore
  electron.vite.config.ts  electron-builder.config.cjs
  README.md  CLAUDE.md
  scripts/
    rebuild-native.mjs    # better-sqlite3 → Electron ABI (postinstall, dev, packaging)
    rebuild-node.mjs      # better-sqlite3 → Node ABI (before tests)
  src/
    main/
      index.ts            # window lifecycle; configureAppHome(userData)
      ipc.ts              # thin IPC handlers
      core/               # UI-free logic, no electron/react imports
        index.ts          #   the public surface the shell imports
        events.ts         #   JobEvent vocabulary (IPC-serializable)
        bus.ts            #   JobEventBus
        jobs/exampleJob.ts#   reference long-running job: emit + AbortSignal
        store/            #   db.ts  schema.ts  runs.ts  types.ts
        config/paths.ts   #   state dir resolution + test env overrides
    preload/
      api.ts  index.ts    # typed contextBridge surface, import type only
    renderer/
      index.html
      src/                # App.tsx  App.css  index.tsx  global.d.ts
  tests/
    core/                 # exampleJob · export-surface
    core-boundary.test.ts # isolation, barrel, preload-type-only
    ipc-contract.test.ts  # preload ↔ main channel names match
```

The authoritative source for every file is `assets/`. To see exactly what will
be written, read `assets/` — do not reproduce it from memory.

## Step 2: Run the assembler

```bash
bash <path-to-this-skill>/scaffold.sh "<target>" "<Project Name>" "<module-name>" "<app.id>" "<description>"
```

Example:

```bash
bash <path-to-this-skill>/scaffold.sh ~/Projects/deal-tracker "Deal Tracker" \
  deal-tracker com.example.dealtracker "Tracks the best deals across brands."
```

Confirm no tokens survived:

```bash
grep -rn "__PROJECT_NAME__\|__MODULE_NAME__\|__PROJECT_TYPE__\|__API_GLOBAL__\|__ENV_PREFIX__\|__APP_ID__\|__DESCRIPTION__" "<target>" || echo clean
```

## Step 3: Install and verify

Run these from `<target>` and read the output. The scaffold is only delivered
once all four pass.

```bash
npm install            # postinstall: better-sqlite3 → Electron ABI
npm run rebuild:node   # then rebuild for Node, or the tests cannot load it
npm test               # 9 tests, 4 files
npm run typecheck
npm run build
```

One load-bearing fact:

- `install` → `rebuild:node` is not optional. Skipping it gives
  `NODE_MODULE_VERSION` errors in vitest; running the app afterwards gives the
  same error inside Electron until `npm run rebuild` runs again. That toggle is
  the cost of one native module and is documented in the generated `CLAUDE.md`.

Optional launch check (opens a window for a few seconds):

```bash
npm run rebuild                       # back to the Electron ABI
npx electron .
```

A clean run prints nothing and creates `app.db` in the app's `userData` dir
(macOS: `~/Library/Application Support/<Project Name>/`).

## Step 4: Report

Tell the user:

- Where the project was created and that files were stamped from the canonical
  skeleton.
- The results you actually observed for install, tests, typecheck, and build.
- The dev command: `npm run dev` (electron-vite; editing `src/main/**`
  restarts the main process, renderer edits hot-reload).
- That `src/main/core/jobs/exampleJob.ts` and the App UI are a working
  reference to replace, not scaffolding to keep.
- The rebuild toggle: `npm run rebuild` before running the app,
  `npm run rebuild:node` before running tests.
- Offer to `git init` + initial commit. Do not do it unprompted.

## Rules

- **Do not hand-write the starter files.** Edit `assets/` and let
  `scaffold.sh` stamp them. If a convention changes, change it in `assets/`
  and in this file — never fork a template into a one-off.
- Do not add features, pages, or abstractions beyond the skeleton. One example
  job and one screen is the whole point.
- Do not swap the stack. Electron + electron-vite + React 19 + better-sqlite3
  is the default; changing it needs the user's say-so.
- Do not add a state-management library, a router, or a component framework.
  One screen does not need them, and the user can add one when a second screen
  proves it.
- Do not turn the output into a workspaces monorepo. If the app genuinely
  plans multiple hosts from day one, say so and use pembina's layout as the
  reference instead.
- Stay on electron-vite conventions (`src/main`, `src/preload`,
  `src/renderer` with `src/renderer/src/`). Plans and ecosystem tooling
  assume them; diverging is how scaffolds rot.
- If the app has no long-running work and no local persistence, say so and
  offer a plain `npm create electron@latest` start instead of scaffolding
  structure the user will have to delete later.
