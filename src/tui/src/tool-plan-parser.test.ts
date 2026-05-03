import { describe, it, expect } from "@jest/globals";
import { canonicalToolIdentity, extractToolPlanSnapshot, stableCallArgsHash } from "./tool-plan-parser.js";

describe("tool plan parser", () => {
  it("extracts latest fenced tool_calls envelope", () => {
    const text = [
      "thinking...",
      "```json",
      '{"tool_calls":[{"id":"t1","tool":"ReadFile","path":"a.ail","start":1,"end":50}]}',
      "```",
      "more text",
    ].join("\n");
    const snap = extractToolPlanSnapshot(text);
    expect(snap.calls).toHaveLength(1);
    expect(snap.calls[0]?.id).toBe("t1");
    expect(snap.calls[0]?.tool).toBe("ReadFile");
  });

  it("extracts balanced bare JSON envelope", () => {
    const text = 'prefix {"tool_calls":[{"tool":"BashExec","exec":{"cmd":"echo","args":["hi"]}}]} suffix';
    const snap = extractToolPlanSnapshot(text);
    expect(snap.calls).toHaveLength(1);
    expect(snap.calls[0]?.tool).toBe("BashExec");
    expect(snap.calls[0]?.exec?.cmd).toBe("echo");
  });

  it("returns empty calls for incomplete fragment", () => {
    const text = '```json\n{"tool_calls":[{"id":"t1","tool":"ReadFile"';
    const snap = extractToolPlanSnapshot(text);
    expect(snap.calls).toEqual([]);
  });

  it("uses stable anon identity for same call args", () => {
    const c1 = { id: "", tool: "ReadFile", path: "x", start: 1, end: 2 };
    const c2 = { id: "", tool: "ReadFile", path: "x", start: 1, end: 2 };
    const h1 = stableCallArgsHash(c1);
    const h2 = stableCallArgsHash(c2);
    expect(h1).toBe(h2);
    expect(canonicalToolIdentity(c1, 0)).toBe(canonicalToolIdentity(c2, 0));
  });
});
