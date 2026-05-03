// tui/src/commands.test.ts
//
// Tests for the slash-command registry and autocomplete provider.
import { describe, it, expect, beforeAll, afterAll } from "@jest/globals";
import {
  parseSlashCommand,
  createCommandAutocompleteProvider,
} from "./commands.js";

function makeAbortSignal(): AbortSignal {
  const ac = new AbortController();
  return ac.signal;
}

describe("parseSlashCommand", () => {
  it("returns null for non-slash input", () => {
    expect(parseSlashCommand("hello world")).toBeNull();
    expect(parseSlashCommand("")).toBeNull();
  });

  it("parses /model with no args", () => {
    const result = parseSlashCommand("/model");
    expect(result).not.toBeNull();
    expect(result!.cmd.name).toBe("model");
    expect(result!.args).toBe("");
  });

  it("parses /model with provider/model args", () => {
    const result = parseSlashCommand("/model anthropic/claude-sonnet-4-6");
    expect(result).not.toBeNull();
    expect(result!.cmd.name).toBe("model");
    expect(result!.args).toBe("anthropic/claude-sonnet-4-6");
  });

  it("parses /abort with no args", () => {
    const result = parseSlashCommand("/abort");
    expect(result).not.toBeNull();
    expect(result!.cmd.name).toBe("abort");
  });

  it("returns null for unknown command", () => {
    expect(parseSlashCommand("/something")).toBeNull();
    expect(parseSlashCommand("/unknown arg1 arg2")).toBeNull();
  });

  it("handles extra whitespace", () => {
    const result = parseSlashCommand("/model   openai/gpt-4o  ");
    expect(result).not.toBeNull();
    expect(result!.args).toBe("openai/gpt-4o");
  });
});

describe("createCommandAutocompleteProvider", () => {
  const provider = createCommandAutocompleteProvider();

  it("suggests command names when prefix is /", async () => {
    const result = await provider.getSuggestions(["/"], 0, 1, {
      signal: makeAbortSignal(),
    });
    expect(result).not.toBeNull();
    expect(result!.items.length).toBeGreaterThanOrEqual(2);
    expect(result!.items.map((i) => i.label)).toContain("/model");
    expect(result!.items.map((i) => i.label)).toContain("/abort");
  });

  it("filters command names by prefix", async () => {
    const result = await provider.getSuggestions(["/mo"], 0, 3, {
      signal: makeAbortSignal(),
    });
    expect(result).not.toBeNull();
    expect(result!.items).toHaveLength(1);
    expect(result!.items[0].label).toBe("/model");
  });

  it("returns null for non-slash prefix", async () => {
    const result = await provider.getSuggestions(["hello"], 0, 1, {
      signal: makeAbortSignal(),
    });
    expect(result).toBeNull();
  });

  it("suggests /model names when prefix is /model ", async () => {
    const result = await provider.getSuggestions(["/model anthro"], 0, 12, {
      signal: makeAbortSignal(),
    });
    expect(result).not.toBeNull();
    expect(result!.items.length).toBeGreaterThan(0);
    // Known models include anthropic/claude-sonnet-4-6
    expect(
      result!.items.some((i) => i.label.startsWith("anthropic/")),
    ).toBe(true);
  });

  it("applyCompletion replaces prefix correctly", () => {
    const lines = ["/mod"];
    const result = provider.applyCompletion(
      lines,
      0,
      4,
      { value: "model", label: "/model" },
      "mod",
    );
    expect(result.lines[0]).toBe("/model");
    expect(result.cursorCol).toBe(6);
  });
});
