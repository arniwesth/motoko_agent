import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { buildChildEnv } from "./runtime-process.js";

// The AILANG runtime's ollama client settings have to reach the runtime, and
// `buildChildEnv` is an explicit allowlist, so an unnamed variable is dropped
// silently. AILANG_OLLAMA_V1_STREAM was not on it: every local ollama turn took
// the buffered path, where the whole generation arrives as one response and the
// session log gains nothing while the model works. A host watching the log for
// progress then cannot tell a long turn from a hung one: on runs 2026-10-13..15
// (analysed 2026-10-16), 9 of 39 qwen3.8 runs were killed mid-generation by a
// 10-minute idle watchdog. Deltas reach the log during the call on AILANG
// >= v0.54.13, where the ollama client implements StreamingProvider.

let workdir: string;
const KEYS = [
  "AILANG_OLLAMA_V1_STREAM",
  "AILANG_OLLAMA_IDLE_TIMEOUT_SEC",
  "AILANG_OLLAMA_TTFT_TIMEOUT_SEC",
  "AILANG_OLLAMA_HTTP_TIMEOUT_SEC",
  "AILANG_OLLAMA_MAX_TOKENS",
] as const;
const saved: Record<string, string | undefined> = {};

beforeEach(() => {
  workdir = fs.mkdtempSync(path.join(os.tmpdir(), "ollama-child-env-"));
  for (const k of KEYS) saved[k] = process.env[k];
});

afterEach(() => {
  for (const k of KEYS) {
    if (saved[k] === undefined) delete process.env[k];
    else process.env[k] = saved[k];
  }
  fs.rmSync(workdir, { recursive: true, force: true });
});

describe("buildChildEnv forwards the AILANG ollama client settings", () => {
  it("carries the streaming flag, both silence windows, the deadline and the output budget", () => {
    const values: Record<string, string> = {
      AILANG_OLLAMA_V1_STREAM: "1",
      AILANG_OLLAMA_IDLE_TIMEOUT_SEC: "120",
      AILANG_OLLAMA_TTFT_TIMEOUT_SEC: "600",
      AILANG_OLLAMA_HTTP_TIMEOUT_SEC: "3600",
      AILANG_OLLAMA_MAX_TOKENS: "16384",
    };
    for (const k of KEYS) process.env[k] = values[k];
    const env = buildChildEnv(workdir, "default", "", "");
    for (const k of KEYS) expect(env[k]).toBe(values[k]);
  });

  it("leaves them empty when unset, so the runtime keeps its defaults", () => {
    for (const k of KEYS) delete process.env[k];
    const env = buildChildEnv(workdir, "default", "", "");
    for (const k of KEYS) expect(env[k]).toBe("");
  });
});
