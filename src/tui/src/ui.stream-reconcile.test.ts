import { describe, it, expect } from "@jest/globals";
import { shouldRenderThinkingAfterStream } from "./ui.js";

describe("ui stream reconciliation", () => {
  it("suppresses final thinking render when the step was streamed", () => {
    const streamed = new Set<number>([7]);
    expect(shouldRenderThinkingAfterStream(streamed, 7)).toBe(false);
  });

  it("allows final thinking render when no stream happened for the step", () => {
    const streamed = new Set<number>([6]);
    expect(shouldRenderThinkingAfterStream(streamed, 7)).toBe(true);
  });
});
