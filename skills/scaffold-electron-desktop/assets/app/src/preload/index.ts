import { contextBridge, ipcRenderer } from "electron";
import type { __PROJECT_TYPE__API, JobEvent } from "./api.js";

/**
 * The one place the renderer touches Electron. Context isolation is on and
 * nodeIntegration is off, so the renderer can only call what is listed here.
 *
 * Event subscriptions return an unsubscribe function rather than exposing
 * `removeListener` — otherwise every React effect leaks a listener on
 * re-render.
 */
const api: __PROJECT_TYPE__API = {
  runJob: (opts) => ipcRenderer.invoke("jobs:run", opts),
  abortJob: (jobId) => ipcRenderer.invoke("jobs:abort", jobId),
  listRuns: (limit) => ipcRenderer.invoke("runs:list", limit),
  openPath: (path) => ipcRenderer.invoke("shell:openPath", path),
  onJobEvent: (cb) => {
    const handler = (_event: Electron.IpcRendererEvent, e: unknown) =>
      cb(e as JobEvent);
    ipcRenderer.on("job:event", handler);
    return () => {
      ipcRenderer.removeListener("job:event", handler);
    };
  },
};

contextBridge.exposeInMainWorld("__API_GLOBAL__", api);
