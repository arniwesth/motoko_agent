import { describe, it, expect, jest, afterEach } from "@jest/globals";
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
  formatEvalCardHeader,
  parseEvalCellsJson,
  renderEvalCardLines,
  evalSegmentsToText,
  evalCellsHaveImage,
  shouldExpandEvalCard,
  hasEvalExtension,
} from "./ui.js";
import type { EvalCellResult } from "./eval/frames.js";
import { __setCapabilitiesForTest } from "./eval/image-segment.js";

function stripAnsi(s: string): string {
  return s.replace(/\x1B\[[0-9;]*m/g, "");
}

describe("ui tool rendering helpers", () => {
  it("detects whether eval is configured as an active extension", () => {
    expect(hasEvalExtension(["compose", "eval", "mcp"])).toBe(true);
    expect(hasEvalExtension(["compose", "eval#3"])).toBe(true);
    expect(hasEvalExtension(["compose", "mcp"])).toBe(false);
    expect(hasEvalExtension([])).toBe(false);
  });

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

  it("renders eval call metadata through the registry", () => {
    const call: DelegatedCall = {
      id: "eval-1",
      tool: "eval",
      arguments: {
        cells: [
          { language: "py", code: "print(1)" },
          { language: "js", code: "console.log(2)" },
        ],
      },
    };
    expect(renderToolCallMetaWithFallback(call)).toBe("eval-1 eval 2 cells");
  });

  it("renders rich eval cards with collapse affordances and display placeholders", () => {
    const cells: EvalCellResult[] = [
      {
        index: 0,
        language: "py",
        title: "load data",
        code: "import pandas as pd\nprint('ready')",
        durationMs: 12,
        exit_code: 0,
        stdout: Array.from({ length: 10 }, (_, i) => `row ${i + 1}`).join("\n"),
        stderr: "",
        displays: [{ type: "json", data: { rows: 10 } }],
        executionCount: 1,
        cancelled: false,
        truncated: false,
      },
      {
        index: 1,
        language: "js",
        title: "summarize",
        code: "console.log('ok')",
        durationMs: 8,
        exit_code: 0,
        stdout: "ok",
        stderr: "",
        displays: [
          { type: "markdown", data: "**done**" },
          { type: "image", mime: "image/png", data: { path: ".motoko/artifacts/eval/cell2-1.png" }, width: 2, height: 3 },
        ],
        executionCount: 1,
        cancelled: false,
        truncated: false,
      },
    ];

    expect(formatEvalCardHeader(cells)).toBe("EVAL · 2 cells · ✓2 ✗0 · 20ms");
    const collapsed = evalSegmentsToText(renderEvalCardLines(cells, false, 120)).map(stripAnsi);
    expect(collapsed[0]).toContain("✓ [1/2] load data (12ms)");
    expect(collapsed.join("\n")).toContain("─ Output");
    expect(collapsed.join("\n")).toContain("2 more lines (Ctrl+O to expand)");
    expect(collapsed.join("\n")).toContain("1 more cells (Ctrl+O to expand)");

    const expanded = evalSegmentsToText(renderEvalCardLines(cells, true, 120)).map(stripAnsi);
    const joined = expanded.join("\n");
    expect(joined).toContain("✓ [2/2] summarize (8ms)");
    expect(joined).toContain("console.log");
    expect(joined).toContain("\"rows\"");
    expect(joined).toContain("done");
    // Record-shaped image data (artifact path reference, no inline base64) keeps
    // the existing placeholder regardless of terminal capability.
    expect(joined).toContain("[image: .motoko/artifacts/eval/cell2-1.png (2x3 image/png)]");
  });

  it("defaults small multi-cell eval cards to expanded", () => {
    const cell = (index: number): EvalCellResult => ({
      index,
      language: "py",
      title: `cell ${index + 1}`,
      code: "print('ok')",
      durationMs: 1,
      exit_code: 0,
      stdout: "ok",
      stderr: "",
      displays: [],
      executionCount: 1,
      cancelled: false,
      truncated: false,
    });

    expect(shouldExpandEvalCard([cell(0)])).toBe(true);
    expect(shouldExpandEvalCard([cell(0), cell(1)])).toBe(true);
    expect(shouldExpandEvalCard([cell(0), cell(1), cell(2)])).toBe(false);
  });

  describe("eval card image segments (inline base64)", () => {
    // Well-formed 4x4 RGB PNG so both the graphics-probe and full-decode (ANSI
    // art) paths work.
    const PNG_1x1 =
      "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAP0lEQVR4nAE0AMv/AAAAABAgMCBAYDBgkABAgMBQoPBgwCBw4FAAgACAkCCwoEDgsGAQAMCAQNCgcODAoPDg0MHDFgGB5uiKAAAAAElFTkSuQmCC";
    const imageCell: EvalCellResult = {
      index: 0,
      language: "py",
      title: "plot",
      code: "plt.plot([1,2,3]); display(fig)",
      durationMs: 5,
      exit_code: 0,
      stdout: "drawing",
      stderr: "",
      displays: [{ type: "image", mime: "image/png", data: PNG_1x1 }],
      executionCount: 1,
      cancelled: false,
      truncated: false,
    };

    afterEach(() => __setCapabilitiesForTest(undefined));

    it("emits [text, image] segments when the terminal supports images", () => {
      __setCapabilitiesForTest({ images: "kitty", trueColor: true, hyperlinks: true });
      const segments = renderEvalCardLines([imageCell], true, 80);
      expect(segments.map((s) => s.kind)).toEqual(["text", "image"]);
      const imageSeg = segments[1];
      expect(imageSeg?.kind === "image" && imageSeg.image).not.toBeNull();
    });

    it("emits a single text segment (placeholder) when neither graphics nor truecolor", () => {
      __setCapabilitiesForTest({ images: null, trueColor: false, hyperlinks: true });
      const segments = renderEvalCardLines([imageCell], true, 80);
      expect(segments.map((s) => s.kind)).toEqual(["text"]);
      expect(evalSegmentsToText(segments).map(stripAnsi).join("\n")).toContain("image/png");
    });

    it("inlines half-block art (single text segment) on a truecolor non-graphics terminal", () => {
      __setCapabilitiesForTest({ images: null, trueColor: true, hyperlinks: true });
      const segments = renderEvalCardLines([imageCell], true, 80);
      expect(segments.map((s) => s.kind)).toEqual(["text"]);
      expect(evalSegmentsToText(segments).join("\n")).toContain("▀");
    });

    it("shows the collapse placeholder and no Image child when collapsed", () => {
      __setCapabilitiesForTest({ images: "kitty", trueColor: true, hyperlinks: true });
      const segments = renderEvalCardLines([imageCell], false, 80);
      expect(segments.every((s) => s.kind === "text")).toBe(true);
      expect(evalSegmentsToText(segments).map(stripAnsi).join("\n")).toContain("[image — Ctrl+O to expand]");
    });

    it("reuses the same Image instance / imageId across re-renders", () => {
      __setCapabilitiesForTest({ images: "kitty", trueColor: true, hyperlinks: true });
      const images = new Map();
      const first = renderEvalCardLines([imageCell], true, 80, images);
      const firstImg = first.find((s) => s.kind === "image");
      const id = firstImg?.kind === "image" ? firstImg.image?.getImageId() : undefined;
      expect(id).toBeGreaterThan(0);
      const second = renderEvalCardLines([imageCell], true, 80, images);
      const secondImg = second.find((s) => s.kind === "image");
      // Same instance reused → same Kitty id (replace, not stack).
      expect(secondImg?.kind === "image" && secondImg.image).toBe(firstImg?.kind === "image" ? firstImg.image : null);
      expect(secondImg?.kind === "image" ? secondImg.image?.getImageId() : undefined).toBe(id);
    });

    it("detects image-bearing cells for default-expand", () => {
      expect(evalCellsHaveImage([imageCell])).toBe(true);
      expect(evalCellsHaveImage([{ ...imageCell, displays: [] }])).toBe(false);
    });

    it("regression: a text-only card collapses to a single text segment (no escape bytes)", () => {
      __setCapabilitiesForTest({ images: "kitty", trueColor: true, hyperlinks: true });
      const textCell: EvalCellResult = { ...imageCell, displays: [{ type: "json", data: { ok: 1 } }] };
      const segments = renderEvalCardLines([textCell], true, 80);
      expect(segments).toHaveLength(1);
      expect(segments[0]?.kind).toBe("text");
      const text = evalSegmentsToText(segments).join("\n");
      expect(text).not.toContain("\x1b_G"); // no kitty graphics
      expect(text).not.toContain("\x1b]1337"); // no iTerm2 graphics
    });
  });

  it("normalizes eval_result cells_json with display alias", () => {
    const cells = parseEvalCellsJson(JSON.stringify([
      {
        index: 0,
        language: "py",
        title: "legacy",
        code: "print(1)",
        status: "ok",
        exitCode: 0,
        stdout: "1",
        stderr: "",
        display: [{ type: "status", data: "ok" }],
      },
    ]));
    expect(cells).toHaveLength(1);
    expect(cells?.[0]?.exit_code).toBe(0);
    expect(cells?.[0]?.displays[0]?.type).toBe("status");
  });

  it("parseEvalCellsJson accepts language:'ail' and preserves metadata.ailang through cells_json", () => {
    const cells = parseEvalCellsJson(JSON.stringify([
      {
        index: 0,
        language: "ail",
        title: "abs_diff",
        code: "export func abs_diff(a: int, b: int) -> int ! {} { 0 }",
        exit_code: 0,
        stdout: "",
        stderr: "",
        metadata: {
          ailang: {
            check: "passed",
            verify: "verified",
            verifyAvailable: true,
            committed: true,
            ran: false,
            functions: [{ function: "abs_diff", status: "verified" }],
            teachPrompt: "TEACH",
            notice: "all good",
          },
        },
      },
    ]));
    expect(cells).toHaveLength(1);
    const m = cells?.[0]?.metadata?.ailang;
    expect(cells?.[0]?.language).toBe("ail");
    expect(m?.check).toBe("passed");
    expect(m?.verify).toBe("verified");
    expect(m?.committed).toBe(true);
    expect(m?.functions?.[0]).toEqual({ function: "abs_diff", status: "verified" });
    expect(m?.teachPrompt).toBe("TEACH");
  });

  it("does not coerce an unproven verify status to 'verified' in the parser", () => {
    const cells = parseEvalCellsJson(JSON.stringify([
      { index: 0, language: "ail", title: "t", exit_code: 1, stdout: "", stderr: "",
        metadata: { ailang: { check: "passed", verify: "unknown", verifyAvailable: true, committed: true, ran: false } } },
    ]));
    expect(cells?.[0]?.metadata?.ailang?.verify).toBe("unknown");
  });

  it("parseEvalCellsJson accepts language:'lean' and preserves metadata.lean through cells_json", () => {
    const cells = parseEvalCellsJson(JSON.stringify([
      {
        index: 0,
        language: "lean",
        title: "add comm",
        code: "theorem t (a b : Nat) : a + b = b + a := by omega",
        exit_code: 0,
        stdout: "",
        stderr: "",
        metadata: {
          lean: {
            elaborated: "passed",
            proof: "verified",
            committed: true,
            theorems: [{ name: "t", status: "verified", axioms: ["propext", "Quot.sound"] }],
            sorries: 0,
          },
        },
      },
    ]));
    expect(cells).toHaveLength(1);
    expect(cells?.[0]?.language).toBe("lean");
    expect(cells?.[0]?.metadata?.lean?.proof).toBe("verified");
    expect(cells?.[0]?.metadata?.lean?.theorems?.[0]?.name).toBe("t");
  });

  it("renders the AILANG check/verify status in the eval card", () => {
    const cells = parseEvalCellsJson(JSON.stringify([
      { index: 0, language: "ail", title: "abs_diff", code: "export func f() -> int ! {} { 1 }",
        exit_code: 0, stdout: "7", stderr: "",
        metadata: { ailang: { check: "passed", verify: "verified", verifyAvailable: true, committed: true, ran: true } } },
    ]))!;
    const plain = evalSegmentsToText(renderEvalCardLines(cells, true, 100)).map(stripAnsi).join("\n");
    expect(plain).toContain("ailang:");
    expect(plain).toContain("check passed");
    expect(plain).toContain("verify verified");
    expect(plain).toContain("committed yes");
  });

  it("renders Lean elaboration/proof status and unexpected axioms in the eval card", () => {
    const cells = parseEvalCellsJson(JSON.stringify([
      { index: 0, language: "lean", title: "native", code: "theorem n : True := by native_decide",
        exit_code: 0, stdout: "", stderr: "",
        metadata: { lean: {
          elaborated: "passed",
          proof: "axiom_tainted",
          committed: true,
          theorems: [{ name: "n", status: "axiom_tainted", axioms: ["n._native.native_decide.ax_1"] }],
          unexpectedAxioms: ["n._native.native_decide.ax_1"],
        } } },
    ]))!;
    const plain = evalSegmentsToText(renderEvalCardLines(cells, true, 120)).map(stripAnsi).join("\n");
    expect(plain).toContain("lean:");
    expect(plain).toContain("elaboration passed");
    expect(plain).toContain("proof axiom_tainted");
    expect(plain).toContain("unexpected axioms: n._native.native_decide.ax_1");
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
