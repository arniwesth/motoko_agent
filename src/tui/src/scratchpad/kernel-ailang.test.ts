import { describe, expect, test } from "@jest/globals";
import { execFileSync } from "child_process";
import { AilangKernel } from "./kernel-ailang.js";
import type { ScratchpadCell } from "./frames.js";

function ailangAvailable(): boolean {
  try {
    execFileSync("ailang", ["--version"], { timeout: 3000, stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function z3Available(): boolean {
  try {
    execFileSync("z3", ["--version"], { timeout: 3000, stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

const hasAilang = ailangAvailable();
const d = hasAilang ? describe : describe.skip;

const ABS_DIFF: ScratchpadCell = {
  language: "ail",
  code: `export func abs_diff(a: int, b: int) -> int ! {}
requires { true }
ensures { result >= 0 }
{
  if a >= b then a - b else b - a
}`,
  verify: "auto",
};

function newKernel(): AilangKernel {
  return new AilangKernel({ capsCeiling: ["IO", "FS"], agentPrompt: () => "TEACH_PROMPT_BODY" });
}

d("AilangKernel (integration — requires ailang CLI)", () => {
  test("check passes, verifies the ensures contract, commits, then a second cell runs main", () => {
    const k = newKernel();
    const r1 = k.run(0, { cell: ABS_DIFF, timeoutMs: 30_000 });
    expect(r1.metadata?.ailang?.check).toBe("passed");
    if (z3Available()) {
      expect(r1.metadata?.ailang?.verify).toBe("verified");
      expect(r1.metadata?.ailang?.functions?.[0]).toEqual({ function: "abs_diff", status: "verified" });
    }
    expect(r1.metadata?.ailang?.committed).toBe(true);
    expect(r1.exit_code).toBe(0);
    expect(k.session.acceptedNames).toEqual(["abs_diff"]);

    const r2 = k.run(1, {
      cell: { language: "ail", code: `export func main() -> () ! {IO} { println(show(abs_diff(10, 3))) }`, run: true, caps: "IO" },
      timeoutMs: 30_000,
    });
    expect(r2.metadata?.ailang?.check).toBe("passed");
    expect(r2.metadata?.ailang?.ran).toBe(true);
    expect(r2.stdout.trim()).toBe("7");
    expect(r2.exit_code).toBe(0);
    // main is ephemeral — only abs_diff stays accepted.
    expect(k.session.acceptedNames).toEqual(["abs_diff"]);
  }, 60_000);

  test("one-time teach prompt: first ail cell carries it, subsequent cells do not", () => {
    const k = newKernel();
    const r1 = k.run(0, { cell: ABS_DIFF, timeoutMs: 30_000 });
    expect(r1.metadata?.ailang?.teachPrompt).toBe("TEACH_PROMPT_BODY");
    // The guide must reach the VISIBLE output (what the model reads back), not
    // just nested metadata.
    expect(r1.stdout).toContain("AILANG teaching guide");
    expect(r1.stdout).toContain("TEACH_PROMPT_BODY");
    const r2 = k.run(1, { cell: { language: "ail", code: `export func twice(n: int) -> int ! {} { n * 2 }` }, timeoutMs: 30_000 });
    expect(r2.metadata?.ailang?.teachPrompt).toBeUndefined();
    expect(r2.stdout).not.toContain("AILANG teaching guide");
  }, 60_000);

  test("a candidate that fails check does not mutate prior accepted declarations", () => {
    const k = newKernel();
    k.run(0, { cell: ABS_DIFF, timeoutMs: 30_000 });
    expect(k.session.acceptedNames).toEqual(["abs_diff"]);
    const bad = k.run(1, { cell: { language: "ail", code: `export func broken(a: int) -> int ! {} { a +++ }` }, timeoutMs: 30_000 });
    expect(bad.metadata?.ailang?.check).toBe("failed");
    expect(bad.metadata?.ailang?.committed).toBe(false);
    expect(bad.exit_code).toBe(1);
    // prior state intact
    expect(k.session.acceptedNames).toEqual(["abs_diff"]);
  }, 60_000);

  test("duplicate top-level declaration is rejected without running check", () => {
    const k = newKernel();
    k.run(0, { cell: ABS_DIFF, timeoutMs: 30_000 });
    const dup = k.run(1, {
      cell: { language: "ail", code: `export func abs_diff(a: int, b: int) -> int ! {} { 0 }` },
      timeoutMs: 30_000,
    });
    expect(dup.metadata?.ailang?.committed).toBe(false);
    expect(dup.exit_code).toBe(1);
    expect(dup.metadata?.ailang?.notice).toMatch(/duplicate top-level declaration/);
  }, 60_000);

  test("verify:required with an unprovable/false contract is not committed", () => {
    if (!z3Available()) return; // gate requires the solver
    const k = newKernel();
    const r = k.run(0, {
      cell: {
        language: "ail",
        code: `export func bad(price: int, discount: int) -> int ! {}
requires { price >= 0 }
ensures { result >= 0 }
{
  price - discount
}`,
        verify: "required",
      },
      timeoutMs: 30_000,
    });
    expect(r.metadata?.ailang?.check).toBe("passed");
    expect(r.metadata?.ailang?.verify).toBe("failed");
    expect(r.metadata?.ailang?.committed).toBe(false);
    expect(r.exit_code).toBe(1);
  }, 60_000);

  test("reset clears accepted source but keeps the teach-prompt marker", () => {
    const k = newKernel();
    k.run(0, { cell: ABS_DIFF, timeoutMs: 30_000 });
    expect(k.session.acceptedNames).toEqual(["abs_diff"]);
    const r = k.run(1, { cell: { ...ABS_DIFF, reset: true }, timeoutMs: 30_000 });
    // after reset the same declaration is accepted again (not a duplicate)
    expect(r.metadata?.ailang?.committed).toBe(true);
    expect(r.metadata?.ailang?.teachPrompt).toBeUndefined();
    expect(k.session.acceptedNames).toEqual(["abs_diff"]);
  }, 60_000);
});

describe("AilangKernel (no CLI)", () => {
  test("missing ailang binary fails gracefully (check failed, not committed)", () => {
    const k = new AilangKernel({ ailangBin: "/nonexistent/ailang-binary-xyz" });
    const r = k.run(0, { cell: ABS_DIFF, timeoutMs: 5_000 });
    expect(r.metadata?.ailang?.check).toBe("failed");
    expect(r.metadata?.ailang?.committed).toBe(false);
    expect(r.exit_code).toBe(1);
    expect(k.session.acceptedNames).toEqual([]);
  });
});
