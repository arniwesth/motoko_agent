import { describe, it, expect } from "@jest/globals";
import { shouldRenderDoneOutput, shouldRenderThinkingAfterStream } from "./ui.js";

describe("ui stream reconciliation", () => {
  it("suppresses final thinking render when the step was streamed", () => {
    const streamed = new Set<number>([7]);
    expect(shouldRenderThinkingAfterStream(streamed, 7)).toBe(false);
  });

  it("allows final thinking render when no stream happened for the step", () => {
    const streamed = new Set<number>([6]);
    expect(shouldRenderThinkingAfterStream(streamed, 7)).toBe(true);
  });

  it("suppresses done output when thinking already rendered the answer", () => {
    const rendered = new Set<number>([7]);
    expect(shouldRenderDoneOutput(rendered, 7)).toBe(false);
  });

  it("allows done output when nothing rendered for the step", () => {
    const rendered = new Set<number>([6]);
    expect(shouldRenderDoneOutput(rendered, 7)).toBe(true);
  });
});
