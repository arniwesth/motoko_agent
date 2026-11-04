import { describe, it, expect } from "@jest/globals";
import { extractTaggedThinkAnswer, stripThinkTags, stripThinkBlocksForLive } from "./ui.js";

// SYSTEM.md mandates a <plan> block rather than <thinking>: Anthropic's ToS
// classifier blocks a system prompt that instructs the model to emit its
// internal reasoning in a <thinking> block, so claude-opus-5.5 refused every
// request with the old preamble (measured 2026-11-04, native_finish_reason
// "refusal", zero completion tokens). The tag convention is otherwise
// unchanged, so <plan> has to fold into the same panel the other two do —
// that is what these cases pin.
describe("tag-convention plan blocks", () => {
  it("splits a <plan> block into panel text and answer", () => {
    const got = extractTaggedThinkAnswer("<plan> count the letters </plan>There are 3.");
    expect(got).toEqual({ think: "count the letters", answer: "There are 3." });
  });

  it("still splits <thinking> and <think>", () => {
    expect(extractTaggedThinkAnswer("<thinking>a</thinking>b")).toEqual({ think: "a", answer: "b" });
    expect(extractTaggedThinkAnswer("<think>a</think>b")).toEqual({ think: "a", answer: "b" });
  });

  it("takes the last block when a plan and a thinking block are both present", () => {
    // Pre-existing rule (`openIdx > best.openIdx`): the latest opener wins, so
    // a model that narrates in one convention and then plans in the other
    // still has its answer start after the final close tag.
    expect(extractTaggedThinkAnswer("<thinking>x</thinking><plan>y</plan>z"))
      .toEqual({ think: "y", answer: "z" });
  });

  it("returns null when no block is present", () => {
    expect(extractTaggedThinkAnswer("just an answer")).toBeNull();
  });

  it("strips whole plan tags and truncated tag names", () => {
    expect(stripThinkTags("<plan>a</plan>b")).toBe("ab");
    expect(stripThinkTags("<PLAN>a</PLAN>b")).toBe("ab");
    expect(stripThinkTags("x <pl>y")).toBe("x y");
    expect(stripThinkTags("x <pla>y")).toBe("x y");
    expect(stripThinkTags("lan>the answer")).toBe("the answer");
    expect(stripThinkTags("an>the answer")).toBe("the answer");
  });

  it("leaves <p> alone", () => {
    // <pl>/<pla> are not tags anyone writes, so stripping them is safe; <p> is,
    // so the truncated-name list deliberately stops short of it. A model that
    // emits HTML keeps its paragraph.
    expect(stripThinkTags("<p>a paragraph</p>")).toBe("<p>a paragraph</p>");
  });

  it("hides the body of a closed plan block during live render", () => {
    expect(stripThinkBlocksForLive("<plan>secret steps</plan>the answer"))
      .toBe("[thinking]\nthe answer");
  });

  it("hides an unclosed plan block during live render", () => {
    expect(stripThinkBlocksForLive("<plan>still planning")).toBe("[thinking…]");
  });

  it("pairs a plan opener with a thinking closer, as <think> already did", () => {
    // The open and close alternatives are independent, so the conventions mix.
    // That is pre-existing — <think>a</thinking> paired this way before <plan>
    // existed — and harmless here: both placeholders mean "body hidden", so a
    // model that switches tag mid-block still gets its reasoning hidden rather
    // than leaked. Pinned so a later tightening is a deliberate choice.
    expect(stripThinkBlocksForLive("<plan>a</thinking>b")).toBe("[thinking]\nb");
    expect(stripThinkBlocksForLive("<think>a</thinking>b")).toBe("[thinking]\nb");
  });
});
