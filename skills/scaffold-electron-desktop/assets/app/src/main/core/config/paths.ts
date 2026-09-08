import { homedir } from "node:os";
import { join } from "node:path";
import { mkdirSync } from "node:fs";

/**
 * All on-disk state lives under one directory so tests can redirect it and
 * users can delete it. Never hardcode a path anywhere else.
 *
 * Resolution order for the state dir:
 *   1. `__ENV_PREFIX___HOME` — tests set this per case to a tmp dir.
 *   2. Whatever the host passed to `configureAppHome` — the Electron shell
 *      passes `app.getPath("userData")`.
 *   3. `~/.__MODULE_NAME__` — the plain-Node fallback, so core runs outside
 *      Electron (a test, a script) without any setup.
 */
let configuredHome: string | null = null;

export function configureAppHome(dir: string): void {
  configuredHome = dir;
}

export function appHome(): string {
  const dir =
    process.env.__ENV_PREFIX___HOME ??
    configuredHome ??
    join(homedir(), ".__MODULE_NAME__");
  mkdirSync(dir, { recursive: true });
  return dir;
}

/**
 * SQLite file path. `__ENV_PREFIX___TEST_DB` wins so the test suite never
 * touches the real database — set it per test to a tmp/ path.
 */
export function dbPath(): string {
  return process.env.__ENV_PREFIX___TEST_DB ?? join(appHome(), "app.db");
}
