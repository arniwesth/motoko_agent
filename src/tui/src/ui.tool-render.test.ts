import { describe, it, expect, jest } from "@jest/globals";
import type { DelegatedCall } from "./runtime-process.js";
import {
  formatToolHeaderQueued,
  formatToolHeaderRunning,
  formatToolHeaderDone,
  formatToolRow,
  formatToolDetailLines,
  type ToolRowDetails,
  renderToolCallMetaWithFallback,
  shouldCoalesceToolRowRender,
  shouldGroupReadFileCalls,
  formatReadFileGroupHeader,
  formatGroupedReadFileChildRow,
  describeToolCallMeta,
} from "./ui.js";

describe("ui tool rendering helpers", () => {
  it("formats canonical batch headers", () => {
    expect(formatToolHeaderQueued("req-1", 2)).toBe("[tools] req-1 queued (2 call(s))");
    expect(formatToolHeaderRunning("req-1", 1, 2, 1)).toBe("[tools] req-1 running (1/2 done, failed=1)");
    expect(formatToolHeaderDone("req-1", 2)).toBe("[tools] req-1 done (2 result(s))");
  });

  it("formats canonical compact rows", () => {
    expect(formatToolRow("queued", "a ReadFile foo.ts lines 1-20")).toBe("  [queued] a ReadFile foo.ts lines 1-20");
    expect(formatToolRow("running", "a ReadFile foo.ts lines 1-20")).toBe("  [running] a ReadFile foo.ts lines 1-20");
    expect(formatToolRow("done", "a BashExec echo hi", 0, false)).toBe("  [done] a BashExec echo hi exit=0");
    expect(formatToolRow("failed", "b BashExec false", 1, true)).toBe("  [failed] b BashExec false exit=1 [truncated]");
  });

  it("falls back when renderer throws and emits debug", () => {
    const call: DelegatedCall = { id: "c1", tool: "ReadFile", path: "src/ui.ts", start: 1, end: 10 };
    const onDebug = jest.fn<(msg: string) => void>();
    const rendered = renderToolCallMetaWithFallback(call, onDebug, {
      ReadFile: {
        renderCall: () => {
          throw new Error("boom");
        },
      },
    });

    expect(rendered).toContain("c1 ReadFile src/ui.ts lines 1-10");
    expect(onDebug).toHaveBeenCalledTimes(1);
    expect(onDebug.mock.calls[0]?.[0]).toContain("tool renderer fallback: ReadFile");
  });

  it("renders collapsed output-hidden marker when output exists", () => {
    const details: ToolRowDetails = {
      status: "done",
      stdout: "line1\nline2",
      stderr: "",
      truncated: false,
      exitCode: 0,
    };
    expect(formatToolDetailLines(details, false, 80)).toEqual([
      "  ... output hidden (Ctrl+O to expand)",
    ]);
  });

  it("renders expanded previews with line limits and hidden-line marker", () => {
    const stdout = Array.from({ length: 10 }, (_, i) => `stdout-${i + 1}`).join("\n");
    const stderr = Array.from({ length: 6 }, (_, i) => `stderr-${i + 1}`).join("\n");
    const details: ToolRowDetails = {
      status: "failed",
      stdout,
      stderr,
      truncated: true,
      exitCode: 1,
    };
    const lines = formatToolDetailLines(details, true, 20);
    expect(lines.length).toBe(13); // 8 stdout + 4 stderr + omitted marker
    expect(lines[0]).toContain("stdout-1");
    expect(lines[8]).toContain("[stderr]");
    expect(lines[12]).toContain("4 more lines (Ctrl+O to collapse)");
  });

  it("coalesces non-terminal row refreshes but never terminal states", () => {
    expect(shouldCoalesceToolRowRender(undefined, 1000, "running")).toBe(false);
    expect(shouldCoalesceToolRowRender(1000, 1010, "running")).toBe(true);
    expect(shouldCoalesceToolRowRender(1000, 1010, "done")).toBe(false);
    expect(shouldCoalesceToolRowRender(1000, 1010, "failed")).toBe(false);
  });

  it("enables grouped ReadFile rendering only for two or more calls", () => {
    expect(shouldGroupReadFileCalls([
      { id: "a", tool: "ReadFile", path: "a.ts" },
    ])).toBe(false);
    expect(shouldGroupReadFileCalls([
      { id: "a", tool: "ReadFile", path: "a.ts" },
      { id: "b", tool: "Search", pattern: "x" },
      { id: "c", tool: "ReadFile", path: "b.ts" },
    ])).toBe(true);
  });

  it("formats grouped ReadFile header and child rows", () => {
    expect(formatReadFileGroupHeader(2, 0, 0)).toBe("  [group] ReadFile (2)");
    expect(formatReadFileGroupHeader(2, 1, 0)).toBe("  [group] ReadFile (2) running (1/2 done, failed=0)");
    expect(formatReadFileGroupHeader(2, 2, 0)).toBe("  [group] ReadFile (2) done");
    expect(formatReadFileGroupHeader(2, 1, 1)).toBe("  [group] ReadFile (2) failed (1/2 done, failed=1)");

    expect(formatGroupedReadFileChildRow("queued", "src/a.ts lines 1-20")).toBe("    [queued] src/a.ts lines 1-20");
    expect(formatGroupedReadFileChildRow("done", "src/a.ts lines 1-20", 0, false)).toBe("    [done] src/a.ts lines 1-20 exit=0");
    expect(formatGroupedReadFileChildRow("failed", "src/a.ts lines 1-20", 1, true)).toBe("    [failed] src/a.ts lines 1-20 exit=1 [truncated]");
  });

  it("renders collapsed diff summary for edit tools", () => {
    const details: ToolRowDetails = {
      status: "done",
      stdout: [
        "--- a/src/a.ts",
        "+++ b/src/a.ts",
        "@@ -1,2 +1,2 @@",
        "-const a = 1;",
        "+const a = 2;",
      ].join("\n"),
      stderr: "",
      truncated: false,
      exitCode: 0,
    };
    const lines = formatToolDetailLines(details, false, 120, { toolName: "WriteFile" });
    expect(lines[0]).toContain("[diff]");
    expect(lines[0]).toContain("files=1");
    expect(lines[0]).toContain("hunks=1");
  });

  it("renders expanded diff preview for edit tools and falls back when no diff", () => {
    const diffDetails: ToolRowDetails = {
      status: "done",
      stdout: [
        "--- a/src/a.ts",
        "+++ b/src/a.ts",
        "@@ -1,2 +1,3 @@",
        " const a = 1;",
        "+const b = 2;",
        "-const c = 3;",
      ].join("\n"),
      stderr: "",
      truncated: false,
      exitCode: 0,
    };
    const diffLines = formatToolDetailLines(diffDetails, true, 80, { toolName: "WriteFile" });
    expect(diffLines.length).toBeGreaterThan(0);
    expect(diffLines.join("\n")).toContain("@@ -1,2 +1,3 @@");

    const fallbackDetails: ToolRowDetails = {
      status: "done",
      stdout: "updated file successfully",
      stderr: "",
      truncated: false,
      exitCode: 0,
    };
    const fallbackLines = formatToolDetailLines(fallbackDetails, false, 80, { toolName: "WriteFile" });
    expect(fallbackLines).toEqual(["  ... output hidden (Ctrl+O to expand)"]);
  });

  it("formats EditFile metadata with edit count and flags", () => {
    const call: DelegatedCall = {
      id: "e1",
      tool: "EditFile",
      path: "src/core/parse.ail",
      edits: [{ old: "a", new: "b", replace_all: false }],
      dry_run: true,
      expected_sha256: "abc",
    };
    expect(describeToolCallMeta(call)).toContain("e1 EditFile src/core/parse.ail edits=1 (dry_run,sha_guard)");
  });
});
