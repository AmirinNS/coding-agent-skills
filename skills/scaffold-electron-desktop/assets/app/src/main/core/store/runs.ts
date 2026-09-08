import { openDb } from "./db.js";
import type { RunRecord } from "./types.js";

interface RunRow {
  id: string;
  name: string;
  status: string;
  message: string;
  steps_done: number;
  elapsed_ms: number;
  started_at: string;
  finished_at: string;
}

function toRecord(row: RunRow): RunRecord {
  return {
    id: row.id,
    name: row.name,
    status: row.status as RunRecord["status"],
    message: row.message,
    stepsDone: row.steps_done,
    elapsedMs: row.elapsed_ms,
    startedAt: row.started_at,
    finishedAt: row.finished_at,
  };
}

export function recordRun(record: RunRecord): void {
  openDb()
    .prepare(
      `INSERT OR REPLACE INTO runs
         (id, name, status, message, steps_done, elapsed_ms, started_at, finished_at)
       VALUES (@id, @name, @status, @message, @stepsDone, @elapsedMs, @startedAt, @finishedAt)`,
    )
    .run(record);
}

export function listRuns(limit = 50): RunRecord[] {
  const rows = openDb()
    .prepare(`SELECT * FROM runs ORDER BY started_at DESC LIMIT ?`)
    .all(limit) as RunRow[];
  return rows.map(toRecord);
}

export function getRun(id: string): RunRecord | null {
  const row = openDb().prepare(`SELECT * FROM runs WHERE id = ?`).get(id) as
    | RunRow
    | undefined;
  return row ? toRecord(row) : null;
}
