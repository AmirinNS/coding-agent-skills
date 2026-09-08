/**
 * The event vocabulary that crosses the core → UI boundary.
 *
 * Every field here has to survive `structuredClone` because these objects are
 * sent over Electron IPC. No class instances, no functions, no Dates — strings,
 * numbers, booleans, and plain objects only.
 *
 * Adding a new event type means adding it to `JobEvent`, re-exporting it from
 * `src/main/core/index.ts`, and mirroring the type in `src/preload/api.ts`.
 */

export interface JobStartEvent {
  type: "job-start";
  jobId: string;
  name: string;
  totalSteps: number;
}

export interface JobProgressEvent {
  type: "job-progress";
  jobId: string;
  step: number;
  totalSteps: number;
  message: string;
}

export interface JobLogEvent {
  type: "job-log";
  jobId: string;
  level: "info" | "warn" | "error";
  message: string;
}

export interface JobEndEvent {
  type: "job-end";
  jobId: string;
  status: JobStatus;
  message: string;
  elapsedMs: number;
}

export type JobStatus = "done" | "aborted" | "error";

export type JobEvent =
  | JobStartEvent
  | JobProgressEvent
  | JobLogEvent
  | JobEndEvent;

/** Every long-running core function takes one of these. */
export type EmitJobEvent = (event: JobEvent) => void;
