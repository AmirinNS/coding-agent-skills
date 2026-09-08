import { randomUUID } from "node:crypto";
import type { EmitJobEvent, JobStatus } from "../events.js";
import { recordRun } from "../store/runs.js";

export interface RunExampleJobOptions {
  /** How many units of work to simulate. */
  steps: number;
  /** Milliseconds per step. Tests pass 0. */
  stepDelayMs?: number;
  /** Cancellation. The host owns the AbortController. */
  signal?: AbortSignal;
  /** Where progress goes. The host wires this to a JobEventBus or a window. */
  emit?: EmitJobEvent;
  /** Supplied so tests can run a job without a database. */
  jobId?: string;
}

export interface ExampleJobExit {
  jobId: string;
  status: JobStatus;
  message: string;
  stepsDone: number;
  elapsedMs: number;
}

function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  if (ms <= 0) return Promise.resolve();
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, ms);
    signal?.addEventListener(
      "abort",
      () => {
        clearTimeout(timer);
        resolve();
      },
      { once: true },
    );
  });
}

/**
 * The reference long-running job. Replace the body with real work, but keep
 * the four properties that make it shell-agnostic:
 *
 *   1. Progress leaves through `emit`, never through a UI import.
 *   2. Cancellation is checked between units of work, and an aborted run
 *      returns `status: "aborted"` rather than throwing.
 *   3. Every exit path — done, aborted, error — emits exactly one `job-end`
 *      and writes exactly one row to `runs`.
 *   4. The return value is a plain serializable object, so it can cross IPC
 *      as the resolved value of an `ipcMain.handle` call.
 */
export async function runExampleJob(
  opts: RunExampleJobOptions,
): Promise<ExampleJobExit> {
  const jobId = opts.jobId ?? randomUUID();
  const emit = opts.emit ?? (() => {});
  const startedAt = new Date().toISOString();
  const startMs = Date.now();
  const name = "example-job";

  let stepsDone = 0;
  let status: JobStatus = "done";
  let message = `Completed ${opts.steps} steps.`;

  emit({ type: "job-start", jobId, name, totalSteps: opts.steps });

  try {
    for (let step = 1; step <= opts.steps; step += 1) {
      if (opts.signal?.aborted) {
        status = "aborted";
        message = `Aborted after ${stepsDone} of ${opts.steps} steps.`;
        break;
      }
      await sleep(opts.stepDelayMs ?? 0, opts.signal);
      // Re-check: the sleep is what the abort usually lands in.
      if (opts.signal?.aborted) {
        status = "aborted";
        message = `Aborted after ${stepsDone} of ${opts.steps} steps.`;
        break;
      }
      stepsDone = step;
      emit({
        type: "job-progress",
        jobId,
        step,
        totalSteps: opts.steps,
        message: `Step ${step} of ${opts.steps}`,
      });
    }
  } catch (err) {
    status = "error";
    message = err instanceof Error ? err.message : String(err);
    emit({ type: "job-log", jobId, level: "error", message });
  }

  const elapsedMs = Date.now() - startMs;
  emit({ type: "job-end", jobId, status, message, elapsedMs });

  recordRun({
    id: jobId,
    name,
    status,
    message,
    stepsDone,
    elapsedMs,
    startedAt,
    finishedAt: new Date().toISOString(),
  });

  return { jobId, status, message, stepsDone, elapsedMs };
}
