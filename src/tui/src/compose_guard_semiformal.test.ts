import { describe, expect, it } from "@jest/globals";
import { composeSnippetGuard, parseDeclaredEffects } from "./env-server.js";

describe("compose semi-formal guard (SF2)", () => {
  it("parses declared effects from main signature", () => {
    const effects = parseDeclaredEffects([
      "import std/fs (readFile)",
      "export func main() -> () ! {IO, FS, Process} {",
      "  println(readFile(\"README.md\"))",
      "}",
    ].join("\n"));
    expect(Array.from(effects).sort()).toEqual(["FS", "IO", "Process"]);
  });

  it("rejects analyze intent when FS/Process effects are absent", () => {
    const prev = process.env.AILANG_COMPOSE_EFFECT_GUARD;
    process.env.AILANG_COMPOSE_EFFECT_GUARD = "1";
    const err = composeSnippetGuard(
      "Analyze src/core",
      "export func main() -> () ! {IO} { println(\"x\") }",
      "analyze",
    );
    if (prev === undefined) delete process.env.AILANG_COMPOSE_EFFECT_GUARD;
    else process.env.AILANG_COMPOSE_EFFECT_GUARD = prev;
    expect(err).toContain("requires FS or Process effect");
  });

  it("accepts analyze intent when FS effect is declared", () => {
    const prev = process.env.AILANG_COMPOSE_EFFECT_GUARD;
    process.env.AILANG_COMPOSE_EFFECT_GUARD = "1";
    const err = composeSnippetGuard(
      "Analyze src/core",
      "export func main() -> () ! {IO, FS} { println(\"ok\") }",
      "analyze",
    );
    if (prev === undefined) delete process.env.AILANG_COMPOSE_EFFECT_GUARD;
    else process.env.AILANG_COMPOSE_EFFECT_GUARD = prev;
    expect(err).toBe("");
  });

  it("does not flag plain 'assume' text as fabricated marker", () => {
    const prev = process.env.AILANG_COMPOSE_EFFECT_GUARD;
    process.env.AILANG_COMPOSE_EFFECT_GUARD = "1";
    const err = composeSnippetGuard(
      "compute checksum",
      "export func main() -> () ! {IO} { println(\"assume x\") }",
      "compute",
    );
    if (prev === undefined) delete process.env.AILANG_COMPOSE_EFFECT_GUARD;
    else process.env.AILANG_COMPOSE_EFFECT_GUARD = prev;
    expect(err).toBe("");
  });
});
