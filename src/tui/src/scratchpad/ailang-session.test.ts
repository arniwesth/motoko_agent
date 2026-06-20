import { describe, expect, test } from "@jest/globals";
import {
  AilangSession,
  aggregateVerify,
  decideCommit,
  mapCheckStatus,
  mapFnVerify,
  parseCell,
  type AiCheckJson,
} from "./ailang-session.js";

const ABS_DIFF = `export func abs_diff(a: int, b: int) -> int ! {}
requires { true }
ensures { result >= 0 }
{
  if a >= b then a - b else b - a
}`;

describe("parseCell", () => {
  test("splits imports and declarations, strips module line", () => {
    const p = parseCell(`module foo/bar

import std/list (map)
import std/io (println)

${ABS_DIFF}

export func twice(n: int) -> int ! {} { n * 2 }`);
    expect(p.imports).toEqual(["import std/list (map)", "import std/io (println)"]);
    expect(p.decls.map((d) => d.name)).toEqual(["abs_diff", "twice"]);
    expect(p.decls[0].kind).toBe("func");
    expect(p.hasAnnotations).toBe(true);
  });

  test("dedupes repeated imports", () => {
    const p = parseCell(`import std/io (println)
import std/io (println)
export func main() -> () ! {IO} { println("hi") }`);
    expect(p.imports).toEqual(["import std/io (println)"]);
  });

  test("keeps a multi-line braced body as one declaration", () => {
    const p = parseCell(ABS_DIFF);
    expect(p.decls).toHaveLength(1);
    expect(p.decls[0].name).toBe("abs_diff");
    expect(p.decls[0].source).toContain("ensures { result >= 0 }");
  });

  test("no annotations detected for plain functions", () => {
    const p = parseCell(`export func id(n: int) -> int ! {} { n }`);
    expect(p.hasAnnotations).toBe(false);
  });
});

describe("AilangSession accumulation", () => {
  test("accepts a declaration and exposes it; later cell can be rendered with it", () => {
    const s = new AilangSession();
    s.commit(parseCell(ABS_DIFF), "main");
    expect(s.acceptedNames).toEqual(["abs_diff"]);
    const rendered = s.renderModule(parseCell(`export func main() -> () ! {IO} { println(show(abs_diff(10, 3))) }`));
    expect(rendered).toContain("module motoko/scratchpad_session");
    expect(rendered).toContain("func abs_diff");
    expect(rendered).toContain("func main");
  });

  test("ephemeral entry (main) is not persisted", () => {
    const s = new AilangSession();
    s.commit(parseCell(`export func main() -> () ! {IO} { println("hi") }`), "main");
    expect(s.acceptedNames).toEqual([]);
  });

  test("reset clears source but preserves teachPromptSeen", () => {
    const s = new AilangSession();
    s.commit(parseCell(ABS_DIFF), "main");
    s.teachPromptSeen = true;
    s.reset();
    expect(s.acceptedNames).toEqual([]);
    expect(s.imports).toEqual([]);
    expect(s.teachPromptSeen).toBe(true);
  });

  test("duplicate declaration names are reported (no in-place replacement)", () => {
    const s = new AilangSession();
    s.commit(parseCell(ABS_DIFF), "main");
    const dups = s.duplicateNames(parseCell(`export func abs_diff(a: int, b: int) -> int ! {} { 0 }`), "main");
    expect(dups).toEqual(["abs_diff"]);
  });

  test("late import in a later cell is hoisted to the import block, before declarations", () => {
    const s = new AilangSession();
    s.commit(parseCell(`import std/list (map)\n${ABS_DIFF}`), "main");
    const rendered = s.renderModule(parseCell(`import std/io (println)\nexport func main() -> () ! {IO} { println("x") }`));
    const importIdx = rendered.indexOf("import std/io (println)");
    const declIdx = rendered.indexOf("func abs_diff");
    expect(importIdx).toBeGreaterThan(-1);
    expect(declIdx).toBeGreaterThan(-1);
    // both imports appear before any declaration
    expect(rendered.indexOf("import std/list (map)")).toBeLessThan(declIdx);
    expect(importIdx).toBeLessThan(declIdx);
  });
});

describe("status mapping", () => {
  test("mapCheckStatus", () => {
    expect(mapCheckStatus({ check: { passed: true } })).toBe("passed");
    expect(mapCheckStatus({ check: { passed: false } })).toBe("failed");
    expect(mapCheckStatus({})).toBe("skipped");
  });

  test("mapFnVerify conservatively classifies", () => {
    expect(mapFnVerify("verified")).toBe("verified");
    expect(mapFnVerify("counterexample")).toBe("failed");
    expect(mapFnVerify("timeout")).toBe("timeout");
    expect(mapFnVerify("skipped")).toBe("skipped");
    expect(mapFnVerify("error")).toBe("unknown");
    expect(mapFnVerify(undefined)).toBe("unknown");
  });

  test("aggregateVerify: Z3 unavailable is skipped, never verified", () => {
    const j: AiCheckJson = { verify: { available: false, results: [{ function: "f", status: "verified" }] } };
    expect(aggregateVerify(j)).toEqual({ status: "skipped", available: false });
  });

  test("aggregateVerify: all verified", () => {
    const j: AiCheckJson = { verify: { available: true, results: [{ function: "f", status: "verified" }] } };
    expect(aggregateVerify(j)).toEqual({ status: "verified", available: true });
  });

  test("aggregateVerify: any counterexample fails", () => {
    const j: AiCheckJson = { verify: { available: true, results: [{ function: "f", status: "verified" }, { function: "g", status: "counterexample" }] } };
    expect(aggregateVerify(j).status).toBe("failed");
  });

  test("aggregateVerify: timeout and unknown surface (not coerced to success)", () => {
    expect(aggregateVerify({ verify: { available: true, results: [{ function: "f", status: "timeout" }] } }).status).toBe("timeout");
    expect(aggregateVerify({ verify: { available: true, results: [{ function: "f", status: "error" }] } }).status).toBe("unknown");
  });

  test("aggregateVerify: no annotated functions is skipped", () => {
    expect(aggregateVerify({ verify: { available: true, results: [] } }).status).toBe("skipped");
  });
});

describe("decideCommit", () => {
  const base = { verifyAvailable: true, hasAnnotations: true } as const;

  test("check failure never commits", () => {
    expect(decideCommit({ ...base, check: "failed", verify: "verified", verifyMode: false }).commit).toBe(false);
  });

  test("verify off commits when check passes regardless of verify", () => {
    expect(decideCommit({ ...base, check: "passed", verify: "unknown", verifyMode: false }).commit).toBe(true);
  });

  test("auto: counterexample blocks commit", () => {
    expect(decideCommit({ ...base, check: "passed", verify: "failed", verifyMode: "auto" }).commit).toBe(false);
  });

  test("auto: unknown/skipped still commits", () => {
    expect(decideCommit({ ...base, check: "passed", verify: "unknown", verifyMode: "auto" }).commit).toBe(true);
    expect(decideCommit({ ...base, check: "passed", verify: "skipped", verifyMode: "auto", hasAnnotations: false }).commit).toBe(true);
  });

  test("required: only verified commits", () => {
    expect(decideCommit({ ...base, check: "passed", verify: "verified", verifyMode: "required" }).commit).toBe(true);
    expect(decideCommit({ ...base, check: "passed", verify: "unknown", verifyMode: "required" }).commit).toBe(false);
    expect(decideCommit({ ...base, check: "passed", verify: "timeout", verifyMode: "required" }).commit).toBe(false);
  });

  test("required with no annotations is rejected", () => {
    expect(decideCommit({ ...base, check: "passed", verify: "skipped", verifyMode: "required", hasAnnotations: false }).commit).toBe(false);
  });

  test("required with Z3 unavailable is rejected", () => {
    expect(decideCommit({ ...base, check: "passed", verify: "skipped", verifyMode: "required", verifyAvailable: false }).commit).toBe(false);
  });
});
