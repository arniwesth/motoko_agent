import { afterEach, describe, expect, it } from "@jest/globals";
import { type TerminalCapabilities, resetCapabilitiesCache } from "@mariozechner/pi-tui";
import { isImageLine } from "@mariozechner/pi-tui/dist/terminal-image.js";
import {
  EVAL_IMAGE_MAX_ROWS,
  __setCapabilitiesForTest,
  effectiveImageWidthCells,
  evalImageCapabilityLabel,
  evalImageExitSequence,
  makeImageSegment,
} from "./image-segment.js";

// A real (tiny) 1x1 red PNG.
const PNG_1x1 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
// A well-formed 4x4 RGB PNG (used for the ANSI-art path, which fully decodes).
const PNG_4x4 =
  "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAP0lEQVR4nAE0AMv/AAAAABAgMCBAYDBgkABAgMBQoPBgwCBw4FAAgACAkCCwoEDgsGAQAMCAQNCgcODAoPDg0MHDFgGB5uiKAAAAAElFTkSuQmCC";

const KITTY: TerminalCapabilities = { images: "kitty", trueColor: true, hyperlinks: true };
const ITERM2: TerminalCapabilities = { images: "iterm2", trueColor: true, hyperlinks: true };
// No graphics protocol but 24-bit colour (VS Code, xterm-256color) → ANSI art.
const NONE: TerminalCapabilities = { images: null, trueColor: true, hyperlinks: true };
// No graphics protocol and no truecolor → plain text placeholder.
const NO_COLOR: TerminalCapabilities = { images: null, trueColor: false, hyperlinks: true };

// Put pi-tui itself in Kitty mode so `Image.render` actually emits graphics
// bytes (its internal getCapabilities reads env, independent of our test seam).
function withKittyTerminal<T>(fn: () => T): T {
  const prev = process.env.KITTY_WINDOW_ID;
  process.env.KITTY_WINDOW_ID = "1";
  resetCapabilitiesCache();
  try {
    return fn();
  } finally {
    if (prev === undefined) delete process.env.KITTY_WINDOW_ID;
    else process.env.KITTY_WINDOW_ID = prev;
    resetCapabilitiesCache();
  }
}

afterEach(() => {
  __setCapabilitiesForTest(undefined);
});

describe("makeImageSegment", () => {
  it("renders a real Image whose last line is an image line (kitty caps)", () => {
    withKittyTerminal(() => {
      const seg = makeImageSegment(PNG_1x1, "image/png", { cardWidth: 40, imageId: 99 });
      expect(seg.kind).toBe("image");
      if (seg.kind !== "image") throw new Error("unreachable");
      expect(seg.image).not.toBeNull();
      const lines = seg.image!.render(80);
      expect(isImageLine(lines[lines.length - 1]!)).toBe(true);
      expect(seg.image!.getImageId()).toBe(99);
    });
  });

  it("falls back to plain text when there is neither graphics nor truecolor", () => {
    __setCapabilitiesForTest(NO_COLOR);
    const seg = makeImageSegment(PNG_1x1, "image/png", { cardWidth: 40 });
    expect(seg.kind).toBe("image");
    if (seg.kind !== "image") throw new Error("unreachable");
    expect(seg.image).toBeNull();
    expect(seg.fallback.length).toBeGreaterThan(0);
    expect(seg.fallback[0]).toContain("image/png");
  });

  it("renders half-block art on a truecolor terminal without a graphics protocol", () => {
    __setCapabilitiesForTest(NONE);
    const seg = makeImageSegment(PNG_4x4, "image/png", { cardWidth: 40 });
    expect(seg.kind).toBe("image");
    if (seg.kind !== "image") throw new Error("unreachable");
    expect(seg.image).toBeNull(); // not a graphics Image — text-art lines
    expect(seg.fallback.join("\n")).toContain("▀");
  });

  it("falls back for SVG even on a capable terminal (no rasterization)", () => {
    __setCapabilitiesForTest(KITTY);
    const seg = makeImageSegment("PHN2Zz48L3N2Zz4=", "image/svg+xml", { cardWidth: 40 });
    expect(seg.kind === "image" && seg.image).toBeNull();
  });

  it("falls back (never throws) on empty or undecodable base64", () => {
    __setCapabilitiesForTest(KITTY);
    const empty = makeImageSegment("", "image/png", { cardWidth: 40 });
    expect(empty.kind === "image" && empty.image).toBeNull();
    const garbage = makeImageSegment("not-base64-image-data", "image/png", { cardWidth: 40 });
    expect(garbage.kind === "image" && garbage.image).toBeNull();
  });

  it("reuses a provided Image instance instead of building a new one", () => {
    __setCapabilitiesForTest(KITTY);
    const first = makeImageSegment(PNG_1x1, "image/png", { cardWidth: 40, imageId: 7 });
    if (first.kind !== "image" || !first.image) throw new Error("expected image");
    const again = makeImageSegment(PNG_1x1, "image/png", { cardWidth: 40, reuse: first.image });
    expect(again.kind === "image" && again.image).toBe(first.image);
  });
});

describe("effectiveImageWidthCells", () => {
  it("returns the full width for short images", () => {
    // 100x10 image is very wide & short → well under the row cap.
    expect(effectiveImageWidthCells({ widthPx: 100, heightPx: 10 }, 60, EVAL_IMAGE_MAX_ROWS)).toBe(60);
  });

  it("shrinks width to honor the row cap for tall images", () => {
    // A tall image (e.g. 100x4000) would blow past the row cap at full width.
    const w = effectiveImageWidthCells({ widthPx: 100, heightPx: 4000 }, 60, EVAL_IMAGE_MAX_ROWS);
    expect(w).toBeLessThan(60);
    expect(w).toBeGreaterThanOrEqual(1);
  });

  it("returns the width unchanged when dimensions are unknown", () => {
    expect(effectiveImageWidthCells(null, 50, EVAL_IMAGE_MAX_ROWS)).toBe(50);
  });
});

describe("evalImageExitSequence", () => {
  it("emits a Kitty purge sequence for kitty terminals", () => {
    expect(evalImageExitSequence(KITTY)).toContain("\x1b_Ga=d,d=A");
  });

  it("emits nothing for iTerm2 or non-capable terminals", () => {
    expect(evalImageExitSequence(ITERM2)).toBeNull();
    expect(evalImageExitSequence(NONE)).toBeNull();
  });
});

describe("evalImageCapabilityLabel", () => {
  it("labels each detected protocol", () => {
    expect(evalImageCapabilityLabel(KITTY)).toBe("kitty");
    expect(evalImageCapabilityLabel(ITERM2)).toBe("iterm2");
    expect(evalImageCapabilityLabel(NONE)).toBe("ANSI half-block art");
    expect(evalImageCapabilityLabel(NO_COLOR)).toBe("none (text fallback)");
  });
});
