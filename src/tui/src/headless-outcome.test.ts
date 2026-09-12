import { describe, it, expect } from "@jest/globals";
import { HeadlessOutcome, formatResumeViewLine, RESUME_REFUSED_EXIT_CODE, SUSPENDED_EXIT_CODE } from "./headless-outcome.js";
import type { AgentEvent } from "./runtime-process.js";

// PLAN-003 P3 Part 6: the non-TTY loggers exit non-zero on `run_suspended` with the reason on stderr.
const suspended: AgentEvent = { type: "run_suspended", session_id: "s1", run_id: "s1.r0.0", reason: "budget_exhausted", step: 3 };
const refused: AgentEvent = { type: "session_resume_refused", journal: "/j/journal.jsonl", refusal: "prompt", message: "the system prompt changed under the same profile." };

describe("HeadlessOutcome", () => {
  it("leaves an ordinary run's exit at 0 and says nothing on stderr", () => {
    const outcome = new HeadlessOutcome();
    for (const event of [
      { type: "session_start", task: "t", model: "m" },
      { type: "run_summary", finish_reason: "stop" },
      { type: "done", step: 1, output: "ok" },
    ] as unknown as AgentEvent[]) {
      expect(outcome.observe(event)).toBeNull();
    }
    expect(outcome.exitCode).toBe(0);
  });

  it("puts the suspension's reason on stderr and records a non-zero exit", () => {
    const outcome = new HeadlessOutcome();
    const line = outcome.observe(suspended);
    expect(line).toContain("budget_exhausted");
    expect(line).toContain("step 3");
    expect(line).toContain("s1.r0.0");
    expect(outcome.exitCode).toBe(SUSPENDED_EXIT_CODE);
    expect(SUSPENDED_EXIT_CODE).not.toBe(0);
  });

  it("does not let the headless `error` that follows a suspension change the recorded exit", () => {
    // The wire order QEVAL pinned for the eval harness: run_suspended, run_summary, error.
    const outcome = new HeadlessOutcome();
    outcome.observe(suspended);
    expect(outcome.observe({ type: "run_summary" } as unknown as AgentEvent)).toBeNull();
    expect(outcome.observe({ type: "error", message: "step budget exhausted" })).toBeNull();
    expect(outcome.exitCode).toBe(SUSPENDED_EXIT_CODE);
  });

  it("puts a resume refusal's rule and message on stderr, with the child's exit 3", () => {
    const outcome = new HeadlessOutcome();
    const line = outcome.observe(refused);
    expect(line).toContain("[resume refused] prompt:");
    expect(line).toContain("the system prompt changed");
    expect(line).toContain("/j/journal.jsonl");
    expect(outcome.exitCode).toBe(RESUME_REFUSED_EXIT_CODE);
  });
});

describe("formatResumeViewLine", () => {
  it("renders D6's marker as one plain line", () => {
    const line = formatResumeViewLine({
      type: "session_resume_view",
      resume_count: 1,
      from_id: "0009",
      boundary: "suspended",
      boundary_detail: "suspended (budget_exhausted)",
      suspended: true,
      profile_from: "dogfood",
      profile_to: "dogfood",
      head_replaced: false,
      forced: false,
      dangling: [],
      ext_artifacts_digest: "sha256:e",
      ext_artifacts_empty: true,
      messages: 8,
      provider_calls_started: 3,
      provider_calls_completed: 3,
    });
    expect(line.startsWith("[resume] ── resumed session #1")).toBe(true);
    expect(line).toContain("8 messages, 3 provider call(s) carried");
    expect(line).toContain("the suspended run is held");
    expect(line.endsWith("\n")).toBe(true);
    expect(line.split("\n")).toHaveLength(2);
  });
});
