import type { Database } from "better-sqlite3";

/**
 * Schema is applied on every open and must stay idempotent. Adding a column
 * means adding an ALTER here AND updating `RunRecord` in types.ts — the two
 * are read together by recordRun/listRuns.
 */
export function applySchema(db: Database): void {
  db.pragma("journal_mode = WAL");
  db.exec(`
    CREATE TABLE IF NOT EXISTS runs (
      id            TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      status        TEXT NOT NULL,
      message       TEXT NOT NULL DEFAULT '',
      steps_done    INTEGER NOT NULL DEFAULT 0,
      elapsed_ms    INTEGER NOT NULL DEFAULT 0,
      started_at    TEXT NOT NULL,
      finished_at   TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_runs_started_at ON runs(started_at DESC);
  `);
}
