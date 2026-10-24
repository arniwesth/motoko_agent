import { describe, expect, it } from "@jest/globals";
import * as fs from "fs";

/**
 * M10b removed the AILANG producer/consumer for delegated execution. The wire
 * variants stay for old-session presentation; process execution must not be
 * silently revived under their legacy names. See project 041 ADR-001.
 */
describe("legacy delegated events have no execution path", () => {
  const source = fs.readFileSync("src/runtime-process.ts", "utf8");

  it("does not execute tool_calls or spawn delegated process commands", () => {
    expect(source).not.toContain("runDelegatedCall");
    expect(source).not.toContain("handleToolCalls");
    expect(source).not.toContain("runDelegatedCallsSequential");
    expect(source).not.toContain("resolveDelegatedSpawn");
    expect(source).not.toContain("dispatchOhMyPiTool");
    expect(source).not.toContain('if (event.type === "tool_calls")');
  });

  it("retains legacy wire types for presentation, not execution", () => {
    expect(source).toContain('| { type: "tool_calls"; request_id: string; tool_calls: DelegatedCall[] }');
    expect(source).toContain("old sessions can still be rendered");
    expect(source).toContain("never executes that event");
  });
});
