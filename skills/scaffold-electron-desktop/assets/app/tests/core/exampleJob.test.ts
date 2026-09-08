import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runExampleJob } from "../../src/main/core/jobs/exampleJob.js";
import { listRuns } from "../../src/main/core/store/runs.js";
import { closeDb } from "../../src/main/core/store/db.js";
import type { JobEvent } from "../../src/main/core/events.js";

/**
 * Tests must never touch the real app home. `__ENV_PREFIX___TEST_DB` redirects
 * the SQLite file; set it in the fixture, never in source.
 */
let tmpDir: string;

beforeEach(() => {
  tmpDir = mkdtempSync(join(tmpdir(), "__MODULE_NAME__-test-"));
  process.env.__ENV_PREFIX___TEST_DB = join(tmpDir, "test.db");
});

afterEach(() => {
  closeDb();
  delete process.env.__ENV_PREFIX___TEST_DB;
  rmSync(tmpDir, { recursive: true, force: true });
});

describe("runExampleJob", () => {
  it("emits start, one progress per step, and a single end event", async () => {
    const events: JobEvent[] = [];
    const exit = await runExampleJob({ steps: 3, emit: (e) => events.push(e) });

    expect(exit.status).toBe("done");
    expect(exit.stepsDone).toBe(3);
    expect(events[0].type).toBe("job-start");
    expect(events.filter((e) => e.type === "job-progress")).toHaveLength(3);
    expect(events.filter((e) => e.type === "job-end")).toHaveLength(1);
    expect(events.at(-1)).toMatchObject({ type: "job-end", status: "done" });
  });

  it("records the run so the UI can list it after a restart", async () => {
    const exit = await runExampleJob({ steps: 2 });
    const runs = listRuns();

    expect(runs).toHaveLength(1);
    expect(runs[0]).toMatchObject({
      id: exit.jobId,
      name: "example-job",
      status: "done",
      stepsDone: 2,
    });
  });

  it("returns aborted rather than throwing when cancelled mid-run", async () => {
    const controller = new AbortController();
    const events: JobEvent[] = [];
    const promise = runExampleJob({
      steps: 50,
      stepDelayMs: 5,
      signal: controller.signal,
      emit: (e) => events.push(e),
    });

    setTimeout(() => controller.abort(), 10);
    const exit = await promise;

    expect(exit.status).toBe("aborted");
    expect(exit.stepsDone).toBeLessThan(50);
    expect(events.at(-1)).toMatchObject({ type: "job-end", status: "aborted" });
    // An aborted run is still a recorded run — the UI has to be able to
    // explain what happened.
    expect(listRuns()[0].status).toBe("aborted");
  });
});
