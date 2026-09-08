/**
 * The public surface of `src/main/core/`.
 *
 * The rest of the main process imports from `./core/index.js` and never from
 * a deeper path. If a symbol is not re-exported here, the shell cannot reach
 * it — that is the point. `tests/core/export-surface.test.ts` is the canary
 * that catches an accidental removal, and `tests/core-boundary.test.ts`
 * enforces the barrel.
 */

export { JobEventBus } from "./bus.js";
export { runExampleJob } from "./jobs/exampleJob.js";
export { openDb, closeDb } from "./store/db.js";
export { recordRun, listRuns, getRun } from "./store/runs.js";
export { appHome, dbPath, configureAppHome } from "./config/paths.js";

export type {
  JobEvent,
  JobStartEvent,
  JobProgressEvent,
  JobLogEvent,
  JobEndEvent,
  JobStatus,
  EmitJobEvent,
} from "./events.js";
export type { RunRecord } from "./store/types.js";
export type { RunExampleJobOptions, ExampleJobExit } from "./jobs/exampleJob.js";
