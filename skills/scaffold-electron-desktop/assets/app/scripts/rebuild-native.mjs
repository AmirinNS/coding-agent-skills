#!/usr/bin/env node
/**
 * Rebuild native modules for the Electron runtime.
 *
 * electron-rebuild v3 loses track of the module in some install layouts, so
 * this script reads the installed Electron version from disk, drops any stale
 * binary, and invokes prebuild-install directly inside each native module.
 * prebuild-install is already a transitive dependency of better-sqlite3, so
 * no extra tooling is needed.
 *
 * Run this before `npm run dev` or packaging. Use scripts/rebuild-node.mjs
 * before running the test suite, which executes in plain Node.
 */

import { execSync } from "node:child_process";
import { existsSync, readFileSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { arch, platform } from "node:process";

const NATIVE_MODULES = [
  { name: "better-sqlite3", binary: "build/Release/better_sqlite3.node" },
];

const electronPkg = join(process.cwd(), "node_modules", "electron", "package.json");
if (!existsSync(electronPkg)) {
  console.error("electron is not installed — skipping native rebuild");
  process.exit(0);
}

const electronVersion = JSON.parse(readFileSync(electronPkg, "utf8")).version;
let failed = false;

for (const mod of NATIVE_MODULES) {
  const modDir = join(process.cwd(), "node_modules", mod.name);
  const binaryFile = join(modDir, mod.binary);

  if (!existsSync(modDir)) {
    console.log(`  ${mod.name}: not installed, skipping`);
    continue;
  }

  // Delete any existing binary so prebuild-install unpacks a fresh one instead
  // of deciding the current (possibly Node-ABI) build is good enough.
  if (existsSync(binaryFile)) {
    try {
      unlinkSync(binaryFile);
    } catch (err) {
      console.error(`  ${mod.name}: failed to remove stale binary:`, err.message);
      failed = true;
      continue;
    }
  }

  console.log(`  ${mod.name}: downloading prebuild for Electron ${electronVersion} …`);
  try {
    execSync(
      `npx prebuild-install --target ${electronVersion} --runtime electron --arch ${arch} --platform ${platform}`,
      { cwd: modDir, stdio: "inherit" },
    );
  } catch {
    console.error(`  ${mod.name}: prebuild-install failed`);
    failed = true;
    continue;
  }

  if (!existsSync(binaryFile)) {
    console.error(`  ${mod.name}: binary missing after download`);
    failed = true;
    continue;
  }

  console.log(`  ${mod.name}: OK (Electron ${electronVersion})`);
}

if (failed) {
  console.error("\nSome native modules could not be rebuilt for Electron.");
  console.error("If prebuild-install failed you may need Xcode / build tools.");
  process.exit(1);
}

console.log("\nNative modules rebuilt successfully for Electron.");
