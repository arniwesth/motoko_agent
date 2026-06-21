import { describe, it, expect } from "@jest/globals";
import { applyToolProgressCounters, computeMissingDoneResultIds, plainInputRoute, shouldLockPlainInput, type ToolBatchCounters } from "./ui.js";

describe("ui wait-state helpers", () => {
  it("locks plain text input only during active runs", () => {
    expect(shouldLockPlainInput(false, false, "follow up")).toBe(true);
    expect(shouldLockPlainInput(true, false, "new task")).toBe(false);
    expect(shouldLockPlainInput(false, true, "follow up")).toBe(false);
    expect(shouldLockPlainInput(false, false, "/abort")).toBe(false);
  });

  it("routes plain text as a follow-up after resume marks the task done", () => {
    expect(plainInputRoute(false, true, "what was my last prompt?")).toBe("followup");
    expect(plainInputRoute(true, false, "new task")).toBe("initial");
    expect(plainInputRoute(false, false, "still running")).toBe("locked");
  });

  it("applies tool progress counters with dedupe and mixed status", () => {
    const start: ToolBatchCounters = {
      total: 3,
      running: 3,
      done: 0,
      failed: 0,
      seen: new Set<string>(),
    };

    const step1 = applyToolProgressCounters(start, [
      { tool_call_id: "a", stdout: "", stderr: "", exit_code: 0, truncated: false },
    ]);
    expect(step1.done).toBe(1);
    expect(step1.failed).toBe(0);
    expect(step1.running).toBe(2);

    const step2 = applyToolProgressCounters(step1, [
      { tool_call_id: "b", stdout: "", stderr: "", exit_code: 1, truncated: false },
      { tool_call_id: "a", stdout: "", stderr: "", exit_code: 0, truncated: false },
    ]);
    expect(step2.done).toBe(1);
    expect(step2.failed).toBe(1);
    expect(step2.running).toBe(1);
  });

  it("computes missing done-phase results for unseen rows", () => {
    const missing = computeMissingDoneResultIds(["a", "b", "c"], new Set(["a", "c"]));
    expect(missing).toEqual(["b"]);
  });
});
