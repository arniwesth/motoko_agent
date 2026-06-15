import {
  Image,
  type ImageDimensions,
  type ImageTheme,
  type TerminalCapabilities,
  allocateImageId,
  calculateImageRows,
  deleteAllKittyImages,
  getCapabilities,
  getCellDimensions,
  getImageDimensions,
  imageFallback,
} from "@mariozechner/pi-tui";
import { renderImageAsAnsi } from "./ascii-image.js";

/**
 * Max terminal rows an eval image may occupy. pi-tui ignores `maxHeightCells`
 * (verified: both `Image.render()` and `renderImage()` derive rows solely from
 * `maxWidthCells` × aspect ratio), so height is capped by clamping the effective
 * width — see {@link effectiveImageWidthCells}.
 */
export const EVAL_IMAGE_MAX_ROWS = 48;

/**
 * Ordered piece of an eval card body. Text segments carry already-rendered
 * (highlighted/dim) lines; image segments carry a pi-tui `Image` child component
 * (rendered as real pixels by Kitty/iTerm2) or a text `fallback` when the
 * terminal can't draw images.
 */
export type EvalSegment =
  | { kind: "text"; lines: string[] }
  | { kind: "image"; image: Image | null; fallback: string[] };

// Test seam: lets unit tests exercise both the image and fallback branches
// without a real image-capable terminal. `undefined` means "use the real
// detected capabilities".
let capabilitiesOverride: TerminalCapabilities | undefined;

export function __setCapabilitiesForTest(caps: TerminalCapabilities | undefined): void {
  capabilitiesOverride = caps;
}

function effectiveCapabilities(): TerminalCapabilities {
  return capabilitiesOverride ?? getCapabilities();
}

const DEFAULT_IMAGE_THEME: ImageTheme = { fallbackColor: (s) => s };

export interface MakeImageSegmentOptions {
  /** Cell width budget for the image (typically the card content width). */
  cardWidth: number;
  /** Max rows the image may occupy; defaults to {@link EVAL_IMAGE_MAX_ROWS}. */
  maxRows?: number;
  /**
   * Stable Kitty image id. Pass the previous id when the underlying data
   * changed so Kitty *replaces* (not stacks). Omitted → a fresh id is allocated.
   */
  imageId?: number;
  /** Filename shown in the text fallback. */
  filename?: string;
  /**
   * Reuse an existing `Image` instance (same data) across re-renders so the
   * same Kitty id is redrawn in place rather than stacking a new image.
   */
  reuse?: Image | null;
  theme?: ImageTheme;
}

function fallbackLines(mime: string, dims: ImageDimensions | null, filename?: string): string[] {
  return [imageFallback(mime, dims ?? undefined, filename)];
}

/**
 * Clamp the effective `maxWidthCells` so the rendered image never exceeds
 * `maxRows`. Because pi-tui derives rows from width × aspect ratio (and ignores
 * `maxHeightCells`), shrinking width is the only lever for height; aspect ratio
 * is preserved automatically because rows track width.
 */
export function effectiveImageWidthCells(
  dims: ImageDimensions | null,
  cardWidth: number,
  maxRows: number,
): number {
  const width = Math.max(1, Math.floor(cardWidth));
  if (!dims || dims.widthPx <= 0 || dims.heightPx <= 0) return width;
  const rows = calculateImageRows(dims, width, getCellDimensions());
  if (rows <= maxRows) return width;
  return Math.max(1, Math.floor((width * maxRows) / rows));
}

/**
 * Build an {@link EvalSegment} for an image bundle. Never throws: SVG, missing
 * data, undecodable data, and non-image-capable terminals all yield a text
 * `fallback` segment.
 */
export function makeImageSegment(
  base64: string,
  mime: string,
  opts: MakeImageSegmentOptions,
): EvalSegment {
  const theme = opts.theme ?? DEFAULT_IMAGE_THEME;
  const maxRows = opts.maxRows ?? EVAL_IMAGE_MAX_ROWS;

  // Reuse path: hand back the Image we already built for this data so the same
  // Kitty id is redrawn in place (no stacking).
  if (opts.reuse) {
    return { kind: "image", image: opts.reuse, fallback: [] };
  }

  const dims = base64 ? getImageDimensions(base64, mime) : null;

  // SVG is vector (Kitty/iTerm2 want raster); missing/empty data has nothing to
  // draw. Both keep the text fallback.
  if (!base64 || mime === "image/svg+xml") {
    return { kind: "image", image: null, fallback: fallbackLines(mime, dims, opts.filename) };
  }

  const caps = effectiveCapabilities();
  if (!caps.images) {
    // No graphics protocol, but a true-colour terminal (VS Code, xterm-256color)
    // can still show colour half-block art instead of a bare text placeholder.
    if (caps.trueColor) {
      const art = renderImageAsAnsi(base64, mime, opts.cardWidth, maxRows);
      if (art && art.length > 0) {
        return { kind: "image", image: null, fallback: art };
      }
    }
    return { kind: "image", image: null, fallback: fallbackLines(mime, dims, opts.filename) };
  }

  // Undecodable / unprobeable data → fallback rather than risk emitting a broken
  // graphics sequence. Valid PNG/JPEG/GIF/WebP (what matplotlib/PIL emit) probe
  // cleanly here.
  if (!dims) {
    return { kind: "image", image: null, fallback: fallbackLines(mime, null, opts.filename) };
  }

  try {
    const maxWidthCells = effectiveImageWidthCells(dims, opts.cardWidth, maxRows);
    const imageId = opts.imageId ?? allocateImageId();
    const image = new Image(base64, mime, theme, {
      maxWidthCells,
      imageId,
      filename: opts.filename,
    }, dims);
    return { kind: "image", image, fallback: fallbackLines(mime, dims, opts.filename) };
  } catch {
    return { kind: "image", image: null, fallback: fallbackLines(mime, dims, opts.filename) };
  }
}

/**
 * Human-readable label of the detected inline-image protocol, for a one-line
 * startup log (e.g. `kitty`, `iterm2`, or `none (text fallback)`).
 */
export function evalImageCapabilityLabel(
  caps: TerminalCapabilities = effectiveCapabilities(),
): string {
  switch (caps.images) {
    case "kitty":
      return "kitty";
    case "iterm2":
      return "iterm2";
    default:
      return caps.trueColor ? "ANSI half-block art" : "none (text fallback)";
  }
}

/**
 * Escape sequence that purges all Kitty graphics images, or `null` when the
 * terminal isn't Kitty (iTerm2 repaints inline and needs no purge; non-capable
 * terminals never drew anything). Emit once on process exit so eval plots don't
 * linger in the user's terminal.
 */
export function evalImageExitSequence(
  caps: TerminalCapabilities = effectiveCapabilities(),
): string | null {
  return caps.images === "kitty" ? deleteAllKittyImages() : null;
}
