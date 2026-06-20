import { describe, expect, test } from "@jest/globals";
import {
  LeanSession,
  aggregateProof,
  classifyTheoremAxioms,
  decideLeanCommit,
  hasSorry,
  mapElaboration,
  normalizeLeanProve,
  parseAxiomInfos,
  parseLeanCell,
} from "./lean-session.js";

describe("parseLeanCell", () => {
  test("extracts imports, named theorems, defs, and anonymous examples", () => {
    const p = parseLeanCell(`import Mathlib

theorem add_comm_named (a b : Nat) : a + b = b + a := by
  omega

def f : Nat := 1

example : f = 1 := rfl`);
    expect(p.imports).toEqual(["import Mathlib"]);
    expect(p.namedTheorems).toEqual(["add_comm_named"]);
    expect(p.decls.map((d) => d.kind)).toEqual(["theorem", "def", "example"]);
    expect(p.hasAnonymousExample).toBe(true);
  });

  test("recognizes lemmas and axioms", () => {
    const p = parseLeanCell(`axiom customAx : False
lemma bad : False := customAx`);
    expect(p.decls.map((d) => [d.kind, d.name])).toEqual([["axiom", "customAx"], ["lemma", "bad"]]);
    expect(p.namedTheorems).toEqual(["bad"]);
  });
});

describe("Lean status mapping", () => {
  test("elaboration fails on any error severity", () => {
    expect(mapElaboration({ messages: [{ severity: "warning", data: "ok" }], env: 1 })).toBe("passed");
    expect(mapElaboration({ messages: [{ severity: "error", data: "bad" }], env: 1 })).toBe("failed");
    expect(mapElaboration(null)).toBe("error");
  });

  test("sorry is detected from sorries and warning text", () => {
    expect(hasSorry({ sorries: [{}], messages: [] })).toBe(true);
    expect(hasSorry({ messages: [{ severity: "warning", data: "declaration uses `sorry`" }] })).toBe(true);
    expect(hasSorry({ messages: [{ severity: "warning", data: "other warning" }] })).toBe(false);
  });

  test("parses #print axioms output", () => {
    expect(parseAxiomInfos([
      { severity: "info", data: "'clean' does not depend on any axioms" },
      { severity: "info", data: "'omega_thm' depends on axioms: [propext, Quot.sound]" },
    ])).toEqual([
      { name: "clean", axioms: [] },
      { name: "omega_thm", axioms: ["propext", "Quot.sound"] },
    ]);
  });

  test("classifies standard axioms, sorryAx, native_decide trust axiom, and custom axioms", () => {
    expect(classifyTheoremAxioms("clean", ["propext", "Quot.sound"], false).status).toBe("verified");
    expect(classifyTheoremAxioms("sorry_thm", ["sorryAx"], false).status).toBe("sorry");
    expect(classifyTheoremAxioms("native_thm", ["native_thm._native.native_decide.ax_1"], false).status).toBe("axiom_tainted");
    expect(classifyTheoremAxioms("tainted", ["customAx"], false).status).toBe("axiom_tainted");
  });
});

describe("aggregateProof and commit policy", () => {
  const parsed = parseLeanCell("theorem t : 1 = 1 := rfl");

  test("verified only for named theorem with clean proof", () => {
    expect(aggregateProof({
      elaborated: "passed",
      parsed,
      theoremProofs: [{ name: "t", status: "verified", axioms: [] }],
      sorrySeen: false,
    })).toBe("verified");
  });

  test("anonymous examples cap at skipped when no sorry is detected", () => {
    const anon = parseLeanCell("example : 1 = 1 := rfl");
    expect(aggregateProof({ elaborated: "passed", parsed: anon, theoremProofs: [], sorrySeen: false })).toBe("skipped");
  });

  test("sorry and axiom taint are not verified", () => {
    expect(aggregateProof({ elaborated: "passed", parsed, theoremProofs: [], sorrySeen: true })).toBe("sorry");
    expect(aggregateProof({
      elaborated: "passed",
      parsed,
      theoremProofs: [{ name: "t", status: "axiom_tainted", axioms: ["customAx"] }],
      sorrySeen: false,
    })).toBe("axiom_tainted");
  });

  test("normalizeLeanProve", () => {
    expect(normalizeLeanProve("required")).toBe("required");
    expect(normalizeLeanProve("off")).toBe("off");
    expect(normalizeLeanProve(false)).toBe("off");
    expect(normalizeLeanProve(undefined)).toBe("auto");
  });

  test("commit decisions match prove modes", () => {
    expect(decideLeanCommit({ elaborated: "failed", proof: "verified", proveMode: "off", hasNamedTheorems: true }).commit).toBe(false);
    expect(decideLeanCommit({ elaborated: "passed", proof: "sorry", proveMode: "off", hasNamedTheorems: true }).commit).toBe(true);
    expect(decideLeanCommit({ elaborated: "passed", proof: "axiom_tainted", proveMode: "auto", hasNamedTheorems: true }).commit).toBe(true);
    expect(decideLeanCommit({ elaborated: "passed", proof: "sorry", proveMode: "required", hasNamedTheorems: true }).commit).toBe(false);
    expect(decideLeanCommit({ elaborated: "passed", proof: "verified", proveMode: "required", hasNamedTheorems: true }).commit).toBe(true);
    expect(decideLeanCommit({ elaborated: "passed", proof: "skipped", proveMode: "required", hasNamedTheorems: false }).commit).toBe(false);
  });

  test("session commits only when caller advances it", () => {
    const s = new LeanSession();
    const p = parseLeanCell("theorem t : 1 = 1 := rfl");
    expect(s.committedEnv).toBeNull();
    s.commit(0, p);
    expect(s.committedEnv).toBe(0);
    expect(s.acceptedNames).toEqual(["t"]);
    // A failed candidate that minted env 1 is abandoned by simply not calling commit.
    expect(s.committedEnv).toBe(0);
  });
});
