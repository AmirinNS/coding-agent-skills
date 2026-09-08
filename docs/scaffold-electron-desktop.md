# scaffold-electron-desktop

## Overview

Skill that scaffolds a new Electron desktop app on the standard electron-vite
single-app layout: `src/main`, `src/preload`, `src/renderer`, one
`package.json`. All application logic lives in `src/main/core/`, a UI-free
boundary enforced by tests rather than a package split, wired to the shell
through a typed contextBridge preload and a JobEventBus.

This supersedes the skill's first version, which produced a two-workspace npm
monorepo (`core/` + `desktop/` packages) modeled on pembina's
engine-with-multiple-hosts layout. That shape collided with plans and tooling
that assume the electron-vite default, and it charged every new app the
workspace cost for a second host that pembina has but new apps do not. The
rework was triggered by exactly that collision surfacing in a downstream
project's scaffold milestone.

## What it produces

`bash skills/scaffold-electron-desktop/scaffold.sh <target> "<Project Name>" <module-name> <app.id> "<description>"`
stamps the canonical skeleton from `assets/app/` into a fresh target directory
(refuses a non-empty one) and substitutes seven tokens across every text file:
`__PROJECT_NAME__`, `__MODULE_NAME__`, `__APP_ID__`, `__DESCRIPTION__`
(caller-supplied) and `__PROJECT_TYPE__`, `__API_GLOBAL__`, `__ENV_PREFIX__`
(derived from the kebab module name).

The generated app:

- React 19 renderer behind a locked-down CSP, sandboxed preload exposing a
  typed `window.<apiGlobal>` API via contextBridge.
- Thin IPC handlers in `src/main/ipc.ts`; one `ipcMain.handle` per channel,
  matched 1:1 to preload methods.
- `src/main/core/` holds the logic: a JobEventBus, an event vocabulary that
  survives `structuredClone`, a better-sqlite3 store (runs history), and a
  reference long-running job with `AbortSignal` cancellation that records
  exactly one row and emits exactly one `job-end` per run.
- State lands in the app's `userData` dir: main calls
  `configureAppHome(app.getPath("userData"))`, core resolves
  `ENV_PREFIX_HOME` → configured dir → `~/.<module>/` fallback, and
  `ENV_PREFIX_TEST_DB` redirects SQLite in tests.

## Usage

Invoke the skill ("scaffold an electron desktop app", "new electron app") and
it walks SKILL.md: gather five inputs, run the assembler, then verify from the
target. Verification is the deliverable, all four must pass:

```bash
npm install          # postinstall rebuilds better-sqlite3 for the Electron ABI
npm run rebuild:node # rebuild better-sqlite3 for Node, or vitest cannot load it
npm test             # 9 tests, 4 files
npm run typecheck
npm run build
```

Optional launch check: `npm run rebuild && npx electron .` opens a window and
creates `app.db` in the app's `userData` dir.

## Examples

```bash
bash skills/scaffold-electron-desktop/scaffold.sh ~/Projects/deal-tracker \
  "Deal Tracker" deal-tracker com.example.dealtracker \
  "Tracks the best deals across brands."
grep -rn "__PROJECT_NAME__\|__MODULE_NAME__" ~/Projects/deal-tracker || echo clean
```

## Design decisions

| Decision | Chosen | Alternatives considered | Why |
|----------|--------|------------------------|-----|
| App shape | electron-vite single-app layout | npm workspaces monorepo (previous version) | pembina's split serves three real hosts (cli, tui, desktop); a new app has one. Single-app matches what plans and tooling assume |
| Core isolation | `src/main/core/` boundary enforced by `tests/core-boundary.test.ts` | Separate `core/` package with its own build | Same guarantees (plain-Node testability, no UI deps, mechanical extraction later) without workspace machinery |
| State path | `configureAppHome(dir)` called from main with `app.getPath("userData")` | Core importing electron directly | Core must stay UI-free; the shell passes the path in, tests override via env |
| Builder config | `electron-builder.config.cjs` | `electron-builder.yml` | Signing and notarization switch on env vars, which YAML cannot express |
| Test enforcement | Boundary test with three cases (no UI imports, barrel-only shell imports, preload `import type` only) | Comments and convention alone | A rule without a failing test drifts; the tasks it guards are exactly the ones that broke silently before |

## Notes

- The better-sqlite3 ABI toggle persists: `npm run rebuild` before running the
  app, `npm run rebuild:node` before running tests. Skipping produces
  `NODE_MODULE_VERSION` errors on whichever runtime has the wrong binary.
- Do not turn the output back into a workspaces monorepo. If an app genuinely
  plans multiple hosts from day one, pembina's layout is the reference, not
  this skill.
- If the app is forms over a database with no long-running work, SKILL.md says
  to say so and offer a plain `npm create electron@latest` start instead.

## Verification record

Gauntlet run 2026-09-08 on a fresh target: scaffold and token grep clean,
install OK, 9/9 tests, typecheck clean, lint clean, `out/` build OK, launch
check opened a window and created `app.db` under `userData`. A fail-first
probe injected violations into core, ipc, and preload and watched each
boundary test fail.
