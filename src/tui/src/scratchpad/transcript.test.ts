import { mkdtempSync, readFileSync, rmSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { describe, expect, it, afterEach } from "@jest/globals";
import type { ScratchpadCellResult } from "./frames.js";
import { buildScratchpadTranscript, spillImages } from "./transcript.js";

const temps: string[] = [];

afterEach(() => {
  for (const dir of temps.splice(0)) rmSync(dir, { recursive: true, force: true });
});

function cell(overrides: Partial<ScratchpadCellResult>): ScratchpadCellResult {
  return {
    index: 0,
    language: "py",
    title: "analysis",
    exit_code: 0,
    stdout: "",
    stderr: "",
    displays: [],
    executionCount: 1,
    cancelled: false,
    truncated: false,
    ...overrides,
  };
}

describe("scratchpad transcript", () => {
  it("flattens stdout, json display, markdown, and result", () => {
    const text = buildScratchpadTranscript([
      cell({
        stdout: "hello\n",
        displays: [
          { type: "json", mime: "application/json", data: { answer: 42 } },
          { type: "markdown", mime: "text/markdown", data: "## Done" },
        ],
        result: { type: "text", mime: "text/plain", data: "ok" },
      }),
    ], []);

    expect(text).toContain("== analysis ==");
    expect(text).toContain("[stdout]\nhello");
    expect(text).toContain('"answer": 42');
    expect(text).toContain("## Done");
    expect(text).toContain("[result]\nok");
  });

  it("spills image bundles and renders placeholders", () => {
    const dir = mkdtempSync(join(tmpdir(), "motoko-scratchpad-"));
    temps.push(dir);
    const images = spillImages(dir, "session/one", 1, [
      { type: "image", mime: "image/png", data: Buffer.from("png").toString("base64"), width: 2, height: 3 },
    ]);
    const text = buildScratchpadTranscript([cell({ displays: [{ type: "image", mime: "image/png", data: "ignored", width: 2, height: 3 }] })], images);

    expect(images).toHaveLength(1);
    expect(readFileSync(join(dir, images[0].path), "utf8")).toBe("png");
    expect(text).toContain("[image: .motoko/artifacts/session_one/cell1-1.png (2x3 image/png)]");
  });

  it("pre-truncates long transcripts", () => {
    const text = buildScratchpadTranscript([cell({ stdout: "x".repeat(200) })], [], 80);
    expect(Buffer.byteLength(text, "utf8")).toBeLessThanOrEqual(100);
    expect(text).toContain("[truncated]");
  });
});
