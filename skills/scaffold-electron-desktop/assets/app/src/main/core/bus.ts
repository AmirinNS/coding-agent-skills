import { EventEmitter } from "node:events";
import type { JobEvent } from "./events.js";

/**
 * The only channel core code uses to talk to a UI.
 *
 * Core never imports electron or react, so it cannot call into a window
 * directly. It emits `JobEvent`s here and the host (the Electron shell, a
 * test) subscribes and decides what to do with them.
 */
export class JobEventBus {
  private readonly emitter = new EventEmitter();
  private readonly listeners = new Set<(e: JobEvent) => void>();

  emit(event: JobEvent): void {
    this.emitter.emit("event", event);
    for (const listener of this.listeners) {
      listener(event);
    }
  }

  /** Returns an unsubscribe function. */
  on(listener: (e: JobEvent) => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }
}
