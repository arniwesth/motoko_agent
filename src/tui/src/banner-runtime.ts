import {
  BANNER_BG,
  BANNER_DARK_THRESHOLD,
  BANNER_PIXELS_RGB_BASE64,
  BANNER_SOURCE_HEIGHT,
  BANNER_SOURCE_WIDTH,
} from "./banner-pixels.js";

export interface BannerRenderOptions {
  columns?: number;
  width?: number;
  darkThreshold?: number;
}

const RESET = "\x1b[0m";
const UPPER = "▀";
const LOWER = "▄";

const DEFAULT_BANNER_WIDTH = 80;
const MAX_BANNER_WIDTH = 140;
const MIN_BANNER_WIDTH = 16;

let decodedPixels: Uint8Array | undefined;

const fg = (r: number, g: number, b: number): string => `\x1b[38;2;${r};${g};${b}m`;
const bg = (r: number, g: number, b: number): string => `\x1b[48;2;${r};${g};${b}m`;

function clampWidth(raw: number): number {
  const w = Math.floor(raw);
  if (!Number.isFinite(w) || w <= 0) return DEFAULT_BANNER_WIDTH;
  if (w < MIN_BANNER_WIDTH) return w;
  return Math.min(w, MAX_BANNER_WIDTH);
}

function sourcePixels(): Uint8Array {
  if (!decodedPixels) {
    decodedPixels = Uint8Array.from(Buffer.from(BANNER_PIXELS_RGB_BASE64, "base64"));
  }
  return decodedPixels;
}

function sourceRgb(x: number, y: number): { r: number; g: number; b: number } {
  const pixels = sourcePixels();
  const i = (y * BANNER_SOURCE_WIDTH + x) * 3;
  return { r: pixels[i], g: pixels[i + 1], b: pixels[i + 2] };
}

// Area-average the source pixels covered by one target pixel. Nearest-neighbour
// sampling picks a single source pixel per cell and makes the banner noisy.
function sampleScaled(x: number, y: number, targetWidth: number, targetPixelHeight: number): { r: number; g: number; b: number } {
  const x0 = Math.min(Math.floor((x * BANNER_SOURCE_WIDTH) / targetWidth), BANNER_SOURCE_WIDTH - 1);
  const y0 = Math.min(Math.floor((y * BANNER_SOURCE_HEIGHT) / targetPixelHeight), BANNER_SOURCE_HEIGHT - 1);
  const x1 = Math.min(Math.max(x0 + 1, Math.floor(((x + 1) * BANNER_SOURCE_WIDTH) / targetWidth)), BANNER_SOURCE_WIDTH);
  const y1 = Math.min(Math.max(y0 + 1, Math.floor(((y + 1) * BANNER_SOURCE_HEIGHT) / targetPixelHeight)), BANNER_SOURCE_HEIGHT);
  let r = 0;
  let g = 0;
  let b = 0;
  for (let sy = y0; sy < y1; sy += 1) {
    for (let sx = x0; sx < x1; sx += 1) {
      const c = sourceRgb(sx, sy);
      r += c.r;
      g += c.g;
      b += c.b;
    }
  }
  const n = (x1 - x0) * (y1 - y0);
  return { r: Math.round(r / n), g: Math.round(g / n), b: Math.round(b / n) };
}

export function computeBannerWidth(columns?: number): number {
  if (typeof columns !== "number") return DEFAULT_BANNER_WIDTH;
  return clampWidth(columns);
}

export function computeBannerPixelHeight(width: number): number {
  const safeWidth = Math.max(1, Math.floor(width));
  const h = Math.max(2, Math.round(safeWidth * (BANNER_SOURCE_HEIGHT / BANNER_SOURCE_WIDTH) * 0.5) * 2);
  return h;
}

export function renderBanner(options: BannerRenderOptions = {}): string[] {
  const width = clampWidth(options.width ?? computeBannerWidth(options.columns));
  const darkThreshold = options.darkThreshold ?? BANNER_DARK_THRESHOLD;
  const pixelHeight = computeBannerPixelHeight(width);
  const lines: string[] = [];

  const isDark = (c: { r: number; g: number; b: number }): boolean =>
    c.r < darkThreshold && c.g < darkThreshold && c.b < darkThreshold;

  for (let y = 0; y < pixelHeight; y += 2) {
    let line = bg(BANNER_BG.r, BANNER_BG.g, BANNER_BG.b);

    for (let x = 0; x < width; x += 1) {
      const top = sampleScaled(x, y, width, pixelHeight);
      const bot = sampleScaled(x, Math.min(y + 1, pixelHeight - 1), width, pixelHeight);

      if (isDark(top) && isDark(bot)) {
        line += " ";
      } else if (isDark(top)) {
        line += `${fg(bot.r, bot.g, bot.b)}${bg(BANNER_BG.r, BANNER_BG.g, BANNER_BG.b)}${LOWER}`;
      } else if (isDark(bot)) {
        line += `${fg(top.r, top.g, top.b)}${bg(BANNER_BG.r, BANNER_BG.g, BANNER_BG.b)}${UPPER}`;
      } else {
        line += `${fg(top.r, top.g, top.b)}${bg(bot.r, bot.g, bot.b)}${UPPER}`;
      }
    }

    lines.push(line + RESET);
  }

  return lines;
}

export { RESET as BANNER_RESET };
