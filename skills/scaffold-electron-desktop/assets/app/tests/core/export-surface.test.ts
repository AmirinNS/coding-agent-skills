import { describe, expect, it } from "vitest";
import * as core from "../../src/main/core/index.js";

/**
 * Canary for the public surface. The rest of the main process can only reach
 * what this barrel exports, so dropping a name here silently breaks the app
 * at runtime with no type error at the boundary. Update this list
 * deliberately.
 */
const EXPECTED_EXPORTS = [
  "JobEventBus",
  "runExampleJob",
  "openDb",
  "closeDb",
  "recordRun",
  "listRuns",
  "getRun",
  "appHome",
  "dbPath",
  "configureAppHome",
];

describe("core public surface", () => {
  it("exports every symbol the shell depends on", () => {
    for (const name of EXPECTED_EXPORTS) {
      expect(core, `missing export: ${name}`).toHaveProperty(name);
    }
  });
});
