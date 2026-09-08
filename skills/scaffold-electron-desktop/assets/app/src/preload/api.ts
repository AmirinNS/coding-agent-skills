/**
 * The typed contract between the renderer and the main process.
 *
 * Only `import type` is allowed in this file. The preload runs in a sandboxed
 * context with no access to core's native modules, so a value import of
 * `../main/core/...` would drag better-sqlite3 into the preload bundle and
 * fail at load. Type imports are erased at build time and are safe.
 * `tests/core-boundary.test.ts` enforces this.
 */

import type {
  JobEvent,
  JobStatus,
  RunRecord,
  ExampleJobExit,
} from "../main/core/index.js";

export type { JobEvent, JobStatus, RunRecord, ExampleJobExit };

export interface __PROJECT_TYPE__API {
  /** Starts a job. Resolves when it finishes, aborts, or errors. */
  runJob: (opts: { steps: number; stepDelayMs?: number }) => Promise<ExampleJobExit>;
  /** Returns false if the job already finished. */
  abortJob: (jobId: string) => Promise<boolean>;
  listRuns: (limit?: number) => Promise<RunRecord[]>;
  openPath: (path: string) => Promise<string>;
  /** Subscribes to live job events. Returns an unsubscribe function. */
  onJobEvent: (cb: (event: JobEvent) => void) => () => void;
}
