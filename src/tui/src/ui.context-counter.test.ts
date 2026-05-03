import { describe, expect, it } from "@jest/globals";
import chalk from "chalk";
import { colorizeContextUsageSegment, formatContextUsage, formatCount } from "./ui.js";

chalk.level = 3;

describe("ui context window counter", () => {
  it("formats counts with k/M suffixes", () => {
    expect(formatCount(999)).toBe("999");
    expect(formatCount(1000)).toBe("1.0k");
    expect(formatCount(12345)).toBe("12.3k");
    expect(formatCount(1_000_000)).toBe("1.0M");
    expect(formatCount(2_000_000)).toBe("2.0M");
  });

  it("renders known-limit status text", () => {
    expect(formatContextUsage(12_345, 200_000)).toBe("ctx: 12.3k/200k (6%)");
  });

  it("omits ratio when limit is unknown", () => {
    expect(formatContextUsage(12_345, 0)).toBe("ctx: 12.3k");
  });

  it("applies threshold colors only to the ctx segment", () => {
    const segment = " | ctx: 150.0k/200k (75%)";
    const yellow = colorizeContextUsageSegment(segment, 150_000, 200_000, chalk.greenBright);
    const red = colorizeContextUsageSegment(" | ctx: 180.0k/200k (90%)", 180_000, 200_000, chalk.greenBright);

    expect(yellow).toMatch(/\x1b\[(33|93)m/);
    expect(red).toMatch(/\x1b\[(31|91)m/);
  });
});
