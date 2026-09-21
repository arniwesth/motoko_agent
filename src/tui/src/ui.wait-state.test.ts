import { describe, it, expect } from "@jest/globals";
import {
  applyToolProgressCounters,
  computeMissingDoneResultIds,
  operatorInputReply,
  plainInputRoute,
  shouldLockPlainInput,
  type ToolBatchCounters,
} from "./ui.js";

describe("parked input route (PLAN-002 W4 Part 5)", () => {
  it("while a wake_request is outstanding, plain input bypasses shouldLockPlainInput and answers it", () => {
    // Mid-task: the lock applies...
    expect(shouldLockPlainInput(false, false, "keep going")).toBe(true);
    expect(plainInputRoute(false, false, null, "keep going")).toBe("locked");
    // ...unless the runtime is parked.
    expect(plainInputRoute(false, false, "s.r0.1.p1", "keep going")).toBe("wake_reply");
    expect(operatorInputReply("s.r0.1.p1", "keep going")).toEqual({
      request_id: "s.r0.1.p1", wait_id: "", outcome: "operator_input", detail: "keep going",
    });
  });

  it("slash commands and empty lines are not operator input, and the unparked routes are unchanged", () => {
    expect(plainInputRoute(false, false, "s.r0.1.p1", "/abort")).toBe("other");
    expect(plainInputRoute(false, false, "s.r0.1.p1", "")).toBe("other");
    expect(plainInputRoute(true, false, null, "new task")).toBe("initial_task");
    expect(plainInputRoute(false, true, null, "follow up")).toBe("follow_up");
    expect(plainInputRoute(false, false, null, "/abort")).toBe("other");
  });
});

describe("ui wait-state helpers", () => {
  it("locks plain text input only during active runs", () => {
    expect(shouldLockPlainInput(false, false, "follow up")).toBe(true);
    expect(shouldLockPlainInput(true, false, "new task")).toBe(false);
    expect(shouldLockPlainInput(false, true, "follow up")).toBe(false);
    expect(shouldLockPlainInput(false, false, "/abort")).toBe(false);
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
