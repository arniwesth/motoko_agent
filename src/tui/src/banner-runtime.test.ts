import { describe, expect, it } from "@jest/globals";
import {
  BANNER_RESET,
  computeBannerPixelHeight,
  computeBannerWidth,
  renderBanner,
} from "./banner-runtime.js";

function stripAnsi(text: string): string {
  return text.replace(/\x1b\[[0-9;]*m/g, "");
}

describe("banner-runtime", () => {
  it("computes width from terminal columns with sane clamps", () => {
    expect(computeBannerWidth(undefined)).toBe(80);
    expect(computeBannerWidth(120)).toBe(120);
    expect(computeBannerWidth(500)).toBe(140);
    expect(computeBannerWidth(8)).toBe(8);
  });

  it("renders deterministic dimensions for an explicit width", () => {
    const width = 80;
    const lines = renderBanner({ width });
    expect(lines.length).toBe(computeBannerPixelHeight(width) / 2);

    for (const line of lines) {
      expect(line.endsWith(BANNER_RESET)).toBe(true);
      expect(stripAnsi(line).length).toBe(width);
    }
  });

  it("contains ANSI true-color output", () => {
    const lines = renderBanner({ width: 64 });
    expect(lines.length).toBeGreaterThan(0);
    expect(lines[0]).toContain("\x1b[48;2;");
    expect(lines[0]).toContain("\x1b[38;2;");
  });
});
