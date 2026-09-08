import { ipcMain, shell, type WebContents } from "electron";
import { randomUUID } from "node:crypto";
import { runExampleJob, listRuns } from "./core/index.js";
import type { JobEvent, ExampleJobExit, RunRecord } from "./core/index.js";

/**
 * All IPC channels live here. Two rules keep this file from rotting:
 *
 *   1. Every channel registered here has a matching method in
 *      `src/preload/api.ts`. `tests/ipc-contract.test.ts` enforces it.
 *   2. Handlers stay thin. They translate an IPC payload into a core call and
 *      translate the result back. Business logic belongs in `src/main/core/`,
 *      where it can be tested without Electron.
 */

interface ActiveRun {
  jobId: string;
  controller: AbortController;
  senderId: number;
}

const activeRuns = new Map<string, ActiveRun>();

/**
 * Forwards core events to one window. Guards `isDestroyed` because a job can
 * outlive the window that started it — the user closes it mid-run and the
 * loop keeps emitting until the abort lands.
 */
function createJobEmitter(sender: WebContents): (e: JobEvent) => void {
  return (event: JobEvent) => {
    if (sender.isDestroyed()) return;
    sender.send("job:event", event);
  };
}

export function getActiveRunsForWindow(senderId: number): ActiveRun[] {
  return [...activeRuns.values()].filter((r) => r.senderId === senderId);
}

export function hasAnyActiveRuns(): boolean {
  return activeRuns.size > 0;
}

/** Aborts every run owned by a window. Used by the close/quit guard. */
export function abortWindowRuns(senderId: number): void {
  for (const run of getActiveRunsForWindow(senderId)) {
    run.controller.abort();
  }
}

ipcMain.handle(
  "jobs:run",
  async (event, opts: { steps: number; stepDelayMs?: number }): Promise<ExampleJobExit> => {
    const jobId = randomUUID();
    const controller = new AbortController();
    activeRuns.set(jobId, { jobId, controller, senderId: event.sender.id });
    try {
      return await runExampleJob({
        jobId,
        steps: opts.steps,
        stepDelayMs: opts.stepDelayMs,
        signal: controller.signal,
        emit: createJobEmitter(event.sender),
      });
    } finally {
      // Unregister in `finally` so an error path cannot leak a run that the
      // quit guard would then wait on forever.
      activeRuns.delete(jobId);
    }
  },
);

ipcMain.handle("jobs:abort", (_event, jobId: string): boolean => {
  const run = activeRuns.get(jobId);
  if (!run) return false;
  run.controller.abort();
  return true;
});

ipcMain.handle("runs:list", (_event, limit?: number): RunRecord[] => {
  return listRuns(limit);
});

ipcMain.handle("shell:openPath", async (_event, path: string): Promise<string> => {
  return shell.openPath(path);
});
