import { describe, it, expect } from "@jest/globals";
import chalk from "chalk";
import { highlightJsonLines } from "./json-highlight.js";

const ANSI_RE = /\x1b\[[0-9;]*m/g;
function stripAnsi(text: string): string {
  return text.replace(ANSI_RE, "");
}

chalk.level = 3;

describe("json highlighter", () => {
  it("highlights complete json without changing text", () => {
    const src = '{"k":"v","n":42,"b":true,"x":null}';
    const out = highlightJsonLines(src);
    expect(out).toHaveLength(1);
    expect(out[0]).toMatch(/\x1b\[/);
    expect(stripAnsi(out[0]!)).toBe(src);
  });

  it("handles incomplete json token stream safely", () => {
    const src = '{"tool_calls":[{"id":"t1","tool":"WriteFile","content":"abc';
    const out = highlightJsonLines(src);
    expect(out).toHaveLength(1);
    expect(stripAnsi(out[0]!)).toBe(src);
  });
});
