import { describe, it, expect } from "@jest/globals";
import chalk from "chalk";
import { AILANG_RESERVED_KEYWORDS, highlightCodeLines } from "./ui.js";

const ANSI_RE = /\x1b\[[0-9;]*m/g;

function stripAnsi(text: string): string {
  return text.replace(ANSI_RE, "");
}

function stripDiffGutter(text: string): string {
  return text.replace(/^\s{0,}\d{0,4}\s+\d{0,4}\s+│\s/, "");
}

chalk.level = 3;

describe("ui highlightCodeLines", () => {
  it("preserves line count across supported languages", () => {
    const sample = "line1\nline2\nline3";
    expect(highlightCodeLines(sample, "typescript")).toHaveLength(3);
    expect(highlightCodeLines(sample, "python")).toHaveLength(3);
    expect(highlightCodeLines(sample, "ailang")).toHaveLength(3);
    expect(highlightCodeLines(sample, "bash")).toHaveLength(3);
    expect(highlightCodeLines(sample, "unknown")).toHaveLength(3);
  });

  it("highlights TypeScript keywords/numbers/comments and keeps text stable", () => {
    const line = "const value = 42 // comment";
    const out = highlightCodeLines(line, "typescript")[0];
    expect(out).toMatch(/\x1b\[/);
    expect(stripAnsi(out)).toBe(line);
  });

  it("maintains Python triple-quoted state across lines", () => {
    const code = 'msg = """hello\nworld"""\nprint(msg)';
    const out = highlightCodeLines(code, "python");
    expect(out).toHaveLength(3);
    expect(out[0]).toMatch(/\x1b\[/);
    expect(out[1]).toMatch(/\x1b\[/);
    expect(out[2]).toMatch(/\x1b\[/);
    expect(stripAnsi(out[0])).toBe('msg = """hello');
    expect(stripAnsi(out[1])).toBe('world"""');
    expect(stripAnsi(out[2])).toBe("print(msg)");
  });

  it("highlights AILANG constructs and keeps text stable", () => {
    const line = "export func main() -> () ! {IO, FS} = Some(42) -- c";
    const out = highlightCodeLines(line, "ailang")[0];
    expect(out).toMatch(/\x1b\[/);
    expect(stripAnsi(out)).toBe(line);
  });

  it("supports VS Code grammar-style AILANG tokens (// comments and <-)", () => {
    const line = "recv <- channel // c-style comment";
    const out = highlightCodeLines(line, "ailang")[0];
    expect(out).toMatch(/\x1b\[/);
    expect(stripAnsi(out)).toBe(line);
  });

  it("renders diff/patch with header/hunk/add/delete/context precedence", () => {
    const diff = [
      "--- a/src/tui/dist/ui.d.ts",
      "+++ b/src/tui/dist/ui.d.ts",
      "@@ -1,3 +1,4 @@",
      " import type { AgentEvent } from \"./runtime-process.js\";",
      "+export declare function highlightCodeLines(code: string, lang?: string): string[];",
      "-export type RunState = \"idle\" | \"thinking\";",
      " context fallback",
    ].join("\n");
    const out = highlightCodeLines(diff, "diff");
    expect(out).toHaveLength(7);
    for (const line of out.slice(0, 6)) expect(line).toMatch(/\x1b\[/);
    expect(stripDiffGutter(stripAnsi(out[0]))).toBe("--- a/src/tui/dist/ui.d.ts");
    expect(stripDiffGutter(stripAnsi(out[1]))).toBe("+++ b/src/tui/dist/ui.d.ts");
    expect(stripDiffGutter(stripAnsi(out[2]))).toBe("@@ -1,3 +1,4 @@");
    expect(stripDiffGutter(stripAnsi(out[3]))).toBe(" import type { AgentEvent } from \"./runtime-process.js\";");
    expect(stripDiffGutter(stripAnsi(out[4]))).toBe("+export declare function highlightCodeLines(code: string, lang?: string): string[];");
    expect(stripDiffGutter(stripAnsi(out[5]))).toBe("-export type RunState = \"idle\" | \"thinking\";");
    expect(stripDiffGutter(stripAnsi(out[6]))).toBe(" context fallback");
    // Add/delete lines should carry background ANSI (16-color or truecolor).
    expect(out[4]).toMatch(/\x1b\[(42|48;2;)/);
    expect(out[5]).toMatch(/\x1b\[(41|48;2;)/);
    // Prefix markers remain clearly colored over the background.
    expect(out[4]).toMatch(/\x1b\[(92|32)m(?:\x1b\[[0-9;]*m)*\+/);
    expect(out[5]).toMatch(/\x1b\[(91|31)m(?:\x1b\[[0-9;]*m)*-/);
    // Language inference from .d.ts should add TypeScript token colors inside diff lines.
    expect(out[4]).toMatch(/\x1b\[(94|34)m/);
    // Line number gutters should be present for hunk lines.
    expect(stripAnsi(out[3])).toMatch(/^\s*1\s+1\s+│\s/);
    expect(stripAnsi(out[4])).toMatch(/^\s*\s+\s*2\s+│\s/);
    expect(stripAnsi(out[5])).toMatch(/^\s*2\s+\s+\s+│\s/);
    expect(stripAnsi(out[6])).toMatch(/^\s*3\s+3\s+│\s/);
  });

  it("treats patch alias the same as diff", () => {
    const line = "+added";
    const out = highlightCodeLines(line, "patch")[0];
    expect(out).toMatch(/\x1b\[/);
    expect(stripDiffGutter(stripAnsi(out))).toBe(line);
  });

  it("does not misclassify hunk lines starting with +++/--- as file headers", () => {
    const diff = [
      "--- a/src/demo.ts",
      "+++ b/src/demo.ts",
      "@@ -1,2 +1,3 @@",
      "-old",
      "+++ value",
      "+next",
    ].join("\n");
    const out = highlightCodeLines(diff, "diff");
    expect(stripDiffGutter(stripAnsi(out[4]))).toBe("+++ value");
    expect(stripDiffGutter(stripAnsi(out[5]))).toBe("+next");
    // First added line should get new-line number 1; next one should get 2.
    expect(stripAnsi(out[4])).toMatch(/^\s*\s+\s*1\s+│\s/);
    expect(stripAnsi(out[5])).toMatch(/^\s*\s+\s*2\s+│\s/);
  });

  it("keeps inferred language when +++ header is /dev/null in deleted-file patch", () => {
    const diff = [
      "--- a/src/old.ts",
      "+++ /dev/null",
      "@@ -1,1 +0,0 @@",
      "-const removed = 1;",
    ].join("\n");
    const out = highlightCodeLines(diff, "diff");
    const deleted = out[3];
    // TS token color should still be present ("const" keyword), proving lang wasn't clobbered.
    expect(deleted).toMatch(/\x1b\[(94|34)m/);
    expect(stripDiffGutter(stripAnsi(deleted))).toBe("-const removed = 1;");
  });

  it("highlights shell variables/command and keeps text stable", () => {
    const line = "echo $HOME # home dir";
    const out = highlightCodeLines(line, "bash")[0];
    expect(out).toMatch(/\x1b\[/);
    expect(stripAnsi(out)).toBe(line);
  });

  it("highlights json keys/values and keeps text stable", () => {
    const line = '{"k":"v","n":42,"ok":true}';
    const out = highlightCodeLines(line, "json")[0];
    expect(out).toMatch(/\x1b\[/);
    expect(stripAnsi(out)).toBe(line);
  });

  it("falls back to dim rendering for unknown language", () => {
    const line = "plain text";
    const out = highlightCodeLines(line, "unknown")[0];
    expect(out).toMatch(/\x1b\[/);
    expect(stripAnsi(out)).toBe(line);
  });
});

describe("AILANG reserved keyword parity", () => {
  const expected = [
    "if", "then", "else", "match", "with", "select", "timeout",
    "func", "pure", "let", "letrec", "in",
    "type", "class", "instance", "forall", "exists", "deriving",
    "module", "import", "export", "extern", "as",
    "test", "tests", "property", "properties", "assert",
    "requires", "ensures", "invariant",
    "spawn", "parallel", "channel", "send", "recv",
    "true", "false", "and", "or", "not",
  ] as const;

  it("uses exact canonical keyword set (no additions/omissions)", () => {
    expect(new Set(AILANG_RESERVED_KEYWORDS)).toEqual(new Set(expected));
  });

  it("keeps canonical keyword count at exactly 41", () => {
    expect(AILANG_RESERVED_KEYWORDS).toHaveLength(41);
    expect(expected).toHaveLength(41);
  });
});
