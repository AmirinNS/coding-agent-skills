import { app, BrowserWindow, dialog } from "electron";
import path from "node:path";
import { existsSync } from "node:fs";
import { closeDb, configureAppHome } from "./core/index.js";
import {
  abortWindowRuns,
  getActiveRunsForWindow,
  hasAnyActiveRuns,
} from "./ipc.js";

// Must run before app.whenReady so the macOS menu bar and process name show
// the product name in dev. The packaged bundle gets this from Info.plist.
app.setName("__PROJECT_NAME__");

/**
 * electron-vite emits the preload as .cjs in a build and .js in dev, and the
 * extension differs across versions. Probe rather than guess — a wrong path
 * fails silently as "window.__API_GLOBAL__ is undefined" in the renderer.
 */
function getPreloadPath(): string {
  const base = path.join(__dirname, "../preload/index");
  return existsSync(base + ".cjs") ? base + ".cjs" : base + ".js";
}

function createWindow(): BrowserWindow {
  const window = new BrowserWindow({
    width: 1100,
    height: 760,
    title: "__PROJECT_NAME__",
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  const devServerUrl =
    process.env.ELECTRON_RENDERER_URL ?? process.env.VITE_DEV_SERVER_URL;
  if (devServerUrl) {
    window.loadURL(devServerUrl);
  } else {
    window.loadFile(path.join(__dirname, "../renderer/index.html"));
  }

  window.on("close", async (e) => {
    const runs = getActiveRunsForWindow(window.webContents.id);
    if (runs.length === 0) return;
    // Closing mid-run would strand the job with no way to report its outcome,
    // so make the user choose.
    e.preventDefault();
    const { response } = await dialog.showMessageBox(window, {
      type: "warning",
      buttons: ["Cancel", "Quit Anyway"],
      defaultId: 0,
      cancelId: 0,
      message: `${runs.length} job${runs.length > 1 ? "s" : ""} still running. Quit anyway?`,
    });
    if (response === 1) {
      abortWindowRuns(window.webContents.id);
      window.destroy();
    }
  });

  return window;
}

app.whenReady().then(() => {
  // Core cannot import electron, so the shell tells it where to keep state.
  // Tests and plain-Node runs fall back to env overrides (see
  // src/main/core/config/paths.ts).
  configureAppHome(app.getPath("userData"));
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("before-quit", () => {
  if (!hasAnyActiveRuns()) closeDb();
});
