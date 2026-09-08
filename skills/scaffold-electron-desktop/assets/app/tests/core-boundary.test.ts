import { describe, expect, it } from "vitest";
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";

/**
 * The boundary guard. `src/main/core/` holds the logic and must stay
 * driveable from plain Node — the moment it imports electron or reaches out
 * of its own directory, a UI bug can become a logic bug and the test suite
 * quietly starts needing Electron. This file is the enforcement.
 *
 * Three rules, three tests:
 *
 *   1. Core never imports electron / react / react-dom, and no relative
 *      import inside core resolves to a file outside `src/main/core/`.
 *   2. The rest of the shell reaches core only through `./core/index.js`
 *      (the barrel). No deep imports into `core/store/...` from ipc.ts.
 *   3. Preload files may import core with `import type` ONLY. A value import
 *      would bundle better-sqlite3 into the preload and fail at load.
 */

const SRC_DIR = join(import.meta.dirname, "../src");
const CORE_DIR = join(SRC_DIR, "main", "core");
const MAIN_DIR = join(SRC_DIR, "main");
const PRELOAD_DIR = join(SRC_DIR, "preload");

const BARE_FORBIDDEN = ["electron", "react", "react-dom"];

interface ImportRef {
  /** The raw specifier, e.g. "./index.js" or "electron". */
  specifier: string;
  /** True when the statement is `import type ...`. */
  typeOnly: boolean;
}

function* walkSourceFiles(dir: string): Generator<string> {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walkSourceFiles(path);
    } else if (entry.isFile() && /\.tsx?$/.test(entry.name)) {
      yield path;
    }
  }
}

function extractImports(content: string): ImportRef[] {
  const refs: ImportRef[] = [];
  const patterns = [
    /^\s*import\s+(type\s+)?.*?\sfrom\s+["']([^"']+)["']/gm,
    /^\s*import\s+(type\s+)?["']([^"']+)["']/gm,
  ];
  for (const re of patterns) {
    let match: RegExpExecArray | null;
    while ((match = re.exec(content)) !== null) {
      refs.push({ specifier: match[2], typeOnly: Boolean(match[1]) });
    }
  }
  // Dynamic import() and require() can never be type-only.
  for (const re of [
    /import\s*\(\s*["']([^"']+)["']\s*\)/g,
    /require\s*\(\s*["']([^"']+)["']\s*\)/g,
  ]) {
    let match: RegExpExecArray | null;
    while ((match = re.exec(content)) !== null) {
      refs.push({ specifier: match[1], typeOnly: false });
    }
  }
  return refs;
}

/** Resolves a relative specifier against the importing file; null for bare. */
function resolveRelative(fromFile: string, specifier: string): string | null {
  if (!specifier.startsWith(".")) return null;
  // Strip the compile-time .js so we compare real locations.
  return resolve(dirname(fromFile), specifier).replace(/\.js$/, "");
}

describe("core boundary", () => {
  it("core never imports a UI framework or anything outside src/main/core", () => {
    const violations: string[] = [];
    for (const file of walkSourceFiles(CORE_DIR)) {
      for (const ref of extractImports(readFileSync(file, "utf8"))) {
        const topLevel = ref.specifier.replace(/\/.*$/, "");
        if (ref.specifier.startsWith(".") === false && BARE_FORBIDDEN.includes(topLevel)) {
          violations.push(`${file}: forbidden bare import "${ref.specifier}"`);
        }
        const resolved = resolveRelative(file, ref.specifier);
        if (resolved && resolved !== CORE_DIR && !resolved.startsWith(CORE_DIR + sep)) {
          violations.push(`${file}: import escapes core "${ref.specifier}"`);
        }
      }
    }
    expect(violations).toEqual([]);
  });

  it("the shell reaches core only through ./core/index.js", () => {
    const violations: string[] = [];
    for (const entry of readdirSync(MAIN_DIR, { withFileTypes: true })) {
      if (!entry.isFile() || !/\.ts$/.test(entry.name)) continue;
      const file = join(MAIN_DIR, entry.name);
      for (const ref of extractImports(readFileSync(file, "utf8"))) {
        const resolved = resolveRelative(file, ref.specifier);
        if (!resolved) continue;
        const insideCore =
          resolved === CORE_DIR || resolved.startsWith(CORE_DIR + sep);
        if (insideCore && resolved !== join(CORE_DIR, "index")) {
          violations.push(`${file}: deep core import "${ref.specifier}"`);
        }
      }
    }
    expect(violations).toEqual([]);
  });

  it("preload imports core with import type only", () => {
    const violations: string[] = [];
    for (const file of walkSourceFiles(PRELOAD_DIR)) {
      for (const ref of extractImports(readFileSync(file, "utf8"))) {
        const resolved = resolveRelative(file, ref.specifier);
        if (!resolved) continue;
        const touchesCore =
          resolved === CORE_DIR || resolved.startsWith(CORE_DIR + sep);
        if (touchesCore && !ref.typeOnly) {
          violations.push(`${file}: value import of core "${ref.specifier}"`);
        }
      }
    }
    expect(violations).toEqual([]);
  });
});
