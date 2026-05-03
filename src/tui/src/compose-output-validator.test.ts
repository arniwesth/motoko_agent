import { describe, expect, it } from "@jest/globals";
import { validateExpectedOutput } from "./env-server.js";

describe("compose expected_output validator", () => {
  it("supports non_empty spec", () => {
    const ok = validateExpectedOutput('{"kind":"non_empty"}', "hello\n");
    const bad = validateExpectedOutput('{"kind":"non_empty"}', "   ");
    expect(ok.decided).toBe(true);
    expect(ok.satisfied).toBe(true);
    expect(bad.decided).toBe(true);
    expect(bad.satisfied).toBe(false);
  });

  it("supports contains_all spec", () => {
    const r = validateExpectedOutput(
      '{"kind":"contains_all","tokens":["alpha","beta"],"case_sensitive":false}',
      "Alpha here and BETA there",
    );
    expect(r.decided).toBe(true);
    expect(r.satisfied).toBe(true);
  });

  it("supports lines_regex bounds", () => {
    const r = validateExpectedOutput(
      '{"kind":"lines_regex","pattern":"^file\\\\.ts \\\\([0-9]+ lines\\\\)$","min_lines":1,"max_lines":3}',
      "file.ts (12 lines)\n",
    );
    expect(r.decided).toBe(true);
    expect(r.satisfied).toBe(true);
  });

  it("treats free-text expected_output as inconclusive", () => {
    const r = validateExpectedOutput("one line per file", "a.ts (1 lines)");
    expect(r.decided).toBe(false);
    expect(r.confidence).toBe("low");
  });

  it("supports certificate spec", () => {
    const out = [
      "PREMISES",
      "  src/core/rpc.ail -> rpc_loop drains inbox before model call",
      "  src/core/env_client.ail -> exec_compose_stream sends NDJSON",
      "TRACE",
      "  Premises combine into end-to-end event flow.",
      "CONCLUSION",
      "  Compose emits NDJSON and drains commands between steps.",
    ].join("\n");
    const r = validateExpectedOutput(
      '{"kind":"certificate","min_premises":2,"require_trace":true,"require_conclusion":true}',
      out,
    );
    expect(r.decided).toBe(true);
    expect(r.satisfied).toBe(true);
  });

  it("fails certificate when TRACE is missing", () => {
    const out = [
      "PREMISES",
      "  src/core/rpc.ail -> rpc_loop drains inbox",
      "CONCLUSION",
      "  Inbox draining exists.",
    ].join("\n");
    const r = validateExpectedOutput('{"kind":"certificate","min_premises":1,"require_trace":true}', out);
    expect(r.decided).toBe(true);
    expect(r.satisfied).toBe(false);
    expect(r.reason.toLowerCase()).toContain("trace");
  });

  it("fails certificate with malformed premise line", () => {
    const out = [
      "PREMISES",
      "  src/core/rpc.ail : missing arrow",
      "TRACE",
      "  bad",
      "CONCLUSION",
      "  bad",
    ].join("\n");
    const r = validateExpectedOutput('{"kind":"certificate"}', out);
    expect(r.decided).toBe(true);
    expect(r.satisfied).toBe(false);
    expect(r.reason.toLowerCase()).toContain("premise");
  });
});
