#!/usr/bin/env node
/**
 * Rebuild native modules from source for the current Node runtime.
 *
 * After scripts/rebuild-native.mjs downloads Electron prebuilt binaries, the
 * object files in the module's build directory are compiled against Electron
 * headers. `npm rebuild` alone re-links those stale objects and produces a
 * binary that fails to load in plain Node with a NODE_MODULE_VERSION mismatch.
 * Forcing `node-gyp clean` first means every object is compiled fresh against
 * Node headers.
 *
 * Run this before `npm test` / `npx vitest run`.
 */

import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const NATIVE_MODULES = ["better-sqlite3"];

let failed = false;

for (const mod of NATIVE_MODULES) {
  const modDir = join(process.cwd(), "node_modules", mod);
  if (!existsSync(modDir)) {
    console.log(`  ${mod}: not installed, skipping`);
    continue;
  }

  console.log(`  ${mod}: rebuilding from source for Node ${process.versions.node} …`);
  try {
    execSync("npx node-gyp clean && npx node-gyp rebuild --release", {
      cwd: modDir,
      stdio: "inherit",
    });
    console.log(`  ${mod}: OK`);
  } catch {
    console.error(`  ${mod}: FAILED`);
    failed = true;
  }
}

if (failed) {
  console.error("\nSome native modules could not be rebuilt for Node.");
  process.exit(1);
}

console.log("\nNative modules rebuilt successfully for Node.");
