import { afterEach, describe, expect, it } from "@jest/globals";
import chalk from "chalk";
import { setTheme, theme } from "./theme.js";

chalk.level = 3;

afterEach(() => {
  setTheme(undefined);
});

describe("theme selection", () => {
  it("defaults to PI's ANSI-16 colours when unset", () => {
    expect(setTheme(undefined)).toBe(true);
    expect(theme.red("x")).toBe("\x1b[31mx\x1b[39m");
    expect(theme.dim("x")).toBe("\x1b[2mx\x1b[22m");
    expect(setTheme("  ")).toBe(true);
    expect(theme.cyanBright("x")).toBe("\x1b[96mx\x1b[39m");
  });

  it("switches to Tokyo Night truecolor", () => {
    expect(setTheme("tokyo-night")).toBe(true);
    expect(theme.red("x")).toBe("\x1b[38;2;247;118;142mx\x1b[39m");
    expect(theme.dim("x")).toBe("\x1b[38;2;115;122;162mx\x1b[39m");
    expect(theme.diffAddBg("x")).toContain("\x1b[48;2;32;48;59m");
  });

  it("is case-insensitive and falls back to PI for unknown names", () => {
    expect(setTheme("Tokyo-Night")).toBe(true);
    expect(theme.red("x")).toContain("38;2;");
    expect(setTheme("solarized")).toBe(false);
    expect(theme.red("x")).toBe("\x1b[31mx\x1b[39m");
  });
});
