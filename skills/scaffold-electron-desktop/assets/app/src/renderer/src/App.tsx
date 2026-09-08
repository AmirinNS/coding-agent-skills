import { useCallback, useEffect, useRef, useState } from "react";
import type { JobEvent, RunRecord } from "../../preload/api.js";

/**
 * Reference wiring for the whole pattern:
 *
 *   button click → window.__API_GLOBAL__.runJob → ipcMain → core job
 *   core emits   → main forwards to this window → onJobEvent → React state
 *
 * The renderer holds no business logic. It renders what core reports and sends
 * back what the user asked for.
 */

const api = window.__API_GLOBAL__;

export function App() {
  const [events, setEvents] = useState<JobEvent[]>([]);
  const [runs, setRuns] = useState<RunRecord[]>([]);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const jobIdRef = useRef<string | null>(null);

  // An IPC call that rejects (a thrown handler, a native module that failed to
  // load) must surface, not vanish into an unhandled rejection. Silent
  // failure here reads to the user as "the app does nothing".
  const refreshRuns = useCallback(() => {
    api.listRuns(20).then(setRuns, (err: Error) => setError(err.message));
  }, []);

  useEffect(() => {
    // Subscribe once and unsubscribe on unmount — onJobEvent returns the
    // teardown so a re-render cannot stack duplicate listeners.
    const unsubscribe = api.onJobEvent((event) => {
      setEvents((prev) => [...prev, event]);
      if (event.type === "job-start") jobIdRef.current = event.jobId;
    });
    refreshRuns();
    return unsubscribe;
  }, [refreshRuns]);

  const start = async () => {
    setEvents([]);
    setError(null);
    setRunning(true);
    try {
      await api.runJob({ steps: 10, stepDelayMs: 300 });
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setRunning(false);
      jobIdRef.current = null;
      refreshRuns();
    }
  };

  const abort = () => {
    if (jobIdRef.current) void api.abortJob(jobIdRef.current);
  };

  const progress = events.filter((e) => e.type === "job-progress").at(-1);
  const percent = progress
    ? Math.round((progress.step / progress.totalSteps) * 100)
    : 0;

  return (
    <div className="app-shell">
      <header className="app-header">
        <h1>__PROJECT_NAME__</h1>
        <div className="actions">
          <button className="btn primary" onClick={start} disabled={running}>
            {running ? "Running…" : "Run job"}
          </button>
          <button className="btn" onClick={abort} disabled={!running}>
            Abort
          </button>
        </div>
      </header>

      {error && (
        <div className="banner banner-error" role="alert">
          {error}
        </div>
      )}

      <main className="app-main">
        <section className="panel">
          <h2>Live events</h2>
          {running && (
            <div className="progress">
              <div className="progress-bar" style={{ width: `${percent}%` }} />
            </div>
          )}
          <ul className="event-feed">
            {events.map((event, i) => (
              <li key={i} className={`event event-${event.type}`}>
                <span className="event-type">{event.type}</span>
                <span className="event-msg">{describe(event)}</span>
              </li>
            ))}
            {events.length === 0 && <li className="empty">No events yet.</li>}
          </ul>
        </section>

        <section className="panel">
          <h2>Past runs</h2>
          <table className="runs">
            <thead>
              <tr>
                <th>Started</th>
                <th>Name</th>
                <th>Status</th>
                <th>Steps</th>
                <th>Elapsed</th>
              </tr>
            </thead>
            <tbody>
              {runs.map((run) => (
                <tr key={run.id}>
                  <td>{new Date(run.startedAt).toLocaleTimeString()}</td>
                  <td>{run.name}</td>
                  <td>
                    <span className={`status status-${run.status}`}>{run.status}</span>
                  </td>
                  <td>{run.stepsDone}</td>
                  <td>{(run.elapsedMs / 1000).toFixed(1)}s</td>
                </tr>
              ))}
              {runs.length === 0 && (
                <tr>
                  <td colSpan={5} className="empty">
                    No runs recorded.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </section>
      </main>
    </div>
  );
}

function describe(event: JobEvent): string {
  switch (event.type) {
    case "job-start":
      return `${event.name} · ${event.totalSteps} steps`;
    case "job-progress":
      return event.message;
    case "job-log":
      return `[${event.level}] ${event.message}`;
    case "job-end":
      return `${event.status} · ${event.message}`;
  }
}
