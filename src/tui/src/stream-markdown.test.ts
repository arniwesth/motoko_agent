import { describe, it, expect } from "@jest/globals";
import { normalizeJsonLang, segmentStreamMarkdown, trimSegmentsForLiveRender } from "./stream-markdown.js";

describe("stream markdown segmenter", () => {
  it("segments plain to open to complete fence lifecycle", () => {
    const open = "hello\n```ail\nlet x = 1\n";
    const openSeg = segmentStreamMarkdown(open);
    expect(openSeg.map((s) => s.kind)).toEqual(["plain", "code_open"]);
    expect(openSeg[1]?.lang).toBe("ail");

    const closed = "hello\n```ail\nlet x = 1\n```\nbye";
    const closedSeg = segmentStreamMarkdown(closed);
    expect(closedSeg.map((s) => s.kind)).toEqual(["plain", "code_complete", "plain"]);
    expect(closedSeg[1]?.lang).toBe("ail");
  });

  it("handles multiple fenced blocks", () => {
    const text = [
      "a",
      "```ts",
      "const x = 1;",
      "```",
      "b",
      "```py",
      "print('x')",
      "```",
      "c",
    ].join("\n");
    const segs = segmentStreamMarkdown(text);
    expect(segs.filter((s) => s.kind === "code_complete")).toHaveLength(2);
  });

  it("detects bare json regions in plain text", () => {
    const segs = segmentStreamMarkdown('prefix {"a":1,"b":"x"} suffix');
    expect(segs.some((s) => s.kind === "json_bare")).toBe(true);
  });

  it("detects partial bare json region", () => {
    const segs = segmentStreamMarkdown('prefix {"tool_calls":[{"id":"t1","tool":"WriteFile"');
    expect(segs.some((s) => s.kind === "json_bare")).toBe(true);
  });

  it("normalizes supported json langs", () => {
    expect(normalizeJsonLang("json")).toBe("json");
    expect(normalizeJsonLang("application/json")).toBe("json");
    expect(normalizeJsonLang("jsonc")).toBe("json");
    expect(normalizeJsonLang("ts")).toBeUndefined();
  });

  it("trims from oldest segments first and marks truncation", () => {
    const segs = segmentStreamMarkdown("plain\n```ail\n" + "x".repeat(400) + "\n```\n" + "y".repeat(400));
    const trimmed = trimSegmentsForLiveRender(segs, 200);
    expect(trimmed.truncated).toBe(true);
    expect(trimmed.segments.length).toBeGreaterThan(0);
    expect(trimmed.segments[0]?.text.startsWith("…")).toBe(true);
  });
});
