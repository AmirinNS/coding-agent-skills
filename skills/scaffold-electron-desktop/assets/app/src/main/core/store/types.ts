import type { JobStatus } from "../events.js";

/** One row of the `runs` table. Keep in sync with schema.ts. */
export interface RunRecord {
  id: string;
  name: string;
  status: JobStatus;
  message: string;
  stepsDone: number;
  elapsedMs: number;
  startedAt: string;
  finishedAt: string;
}
