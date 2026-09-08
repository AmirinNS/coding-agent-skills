import type { __PROJECT_TYPE__API } from "../../preload/api.js";

declare global {
  interface Window {
    __API_GLOBAL__: __PROJECT_TYPE__API;
  }
}

export {};
