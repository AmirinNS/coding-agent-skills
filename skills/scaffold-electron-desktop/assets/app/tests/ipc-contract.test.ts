import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * The preload and the main process agree on channel names by string literal,
 * so a typo compiles fine and fails at runtime with an unhandled-invoke error.
 * This test reads both files and checks the two sets match.
 */

const ROOT = join(import.meta.dirname, "..");
const preload = readFileSync(join(ROOT, "src/preload/index.ts"), "utf8");
const ipc = readFileSync(join(ROOT, "src/main/ipc.ts"), "utf8");

function collect(source: string, re: RegExp): Set<string> {
  const found = new Set<string>();
  let match: RegExpExecArray | null;
  while ((match = re.exec(source)) !== null) found.add(match[1]);
  return found;
}

describe("IPC channel contract", () => {
  it("registers a main-process handler for every channel the preload invokes", () => {
    const invoked = collect(preload, /ipcRenderer\.invoke\(\s*"([^"]+)"/g);
    const handled = collect(ipc, /ipcMain\.handle\(\s*\n?\s*"([^"]+)"/g);

    const missing = [...invoked].filter((channel) => !handled.has(channel));
    expect(missing, `no ipcMain.handle for: ${missing.join(", ")}`).toEqual([]);
  });

  it("has no orphaned handlers the renderer can never reach", () => {
    const invoked = collect(preload, /ipcRenderer\.invoke\(\s*"([^"]+)"/g);
    const handled = collect(ipc, /ipcMain\.handle\(\s*\n?\s*"([^"]+)"/g);

    const orphans = [...handled].filter((channel) => !invoked.has(channel));
    expect(orphans, `unreachable handlers: ${orphans.join(", ")}`).toEqual([]);
  });
});
