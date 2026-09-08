import Database from "better-sqlite3";
import type { Database as Db } from "better-sqlite3";
import { dbPath } from "../config/paths.js";
import { applySchema } from "./schema.js";

let cached: Db | null = null;
let cachedPath: string | null = null;

/**
 * Opens (and memoizes) the SQLite connection.
 *
 * The cache key is the resolved path, so a test that swaps
 * `__ENV_PREFIX___TEST_DB` between cases gets a fresh connection instead of
 * silently reusing the previous file.
 */
export function openDb(): Db {
  const path = dbPath();
  if (cached && cachedPath === path) return cached;
  cached?.close();
  const db = new Database(path);
  applySchema(db);
  cached = db;
  cachedPath = path;
  return db;
}

export function closeDb(): void {
  cached?.close();
  cached = null;
  cachedPath = null;
}
