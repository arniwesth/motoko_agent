import zlib from "node:zlib";

/**
 * Dependency-free inline-image fallback for terminals that report 24-bit colour
 * but no Kitty/iTerm2 graphics protocol (VS Code's integrated terminal, plain
 * xterm-256color, …). Renders a PNG as true-colour half-block (`▀`) art: each
 * character cell encodes two vertical pixels — foreground = top pixel,
 * background = bottom pixel — so one text row covers two image rows.
 *
 * The eval kernel always emits PNG (runner.py forces `format="png"`), so this
 * decodes PNG only; anything else (or any decode failure) returns `null` and the
 * caller keeps the `[Image: …]` text placeholder.
 */

const RESET = "\x1b[0m";
const UPPER_HALF = "▀";

const fg = (r: number, g: number, b: number) => `\x1b[38;2;${r};${g};${b}m`;
const bg = (r: number, g: number, b: number) => `\x1b[48;2;${r};${g};${b}m`;

interface DecodedImage {
  width: number;
  height: number;
  /** Row-major RGBA, 4 bytes per pixel. */
  rgba: Uint8Array;
}

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/**
 * Minimal PNG decoder covering 8-bit, non-interlaced images of colour types
 * 0 (grayscale), 2 (RGB), 3 (palette), 4 (gray+alpha), 6 (RGBA) — i.e. what
 * matplotlib `savefig` and PIL `save` produce. Returns `null` for anything
 * outside that subset (16-bit, interlaced, corrupt) so the caller falls back.
 */
export function decodePng(buf: Buffer): DecodedImage | null {
  if (buf.length < 8) return null;
  for (let i = 0; i < 8; i++) {
    if (buf[i] !== PNG_SIGNATURE[i]) return null;
  }
  let pos = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let interlace = 0;
  let palette: Buffer | null = null;
  let trns: Buffer | null = null;
  const idat: Buffer[] = [];

  while (pos + 8 <= buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString("ascii", pos + 4, pos + 8);
    const dataStart = pos + 8;
    const dataEnd = dataStart + len;
    if (dataEnd + 4 > buf.length) break;
    const data = buf.subarray(dataStart, dataEnd);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8]!;
      colorType = data[9]!;
      interlace = data[12]!;
    } else if (type === "PLTE") {
      palette = Buffer.from(data);
    } else if (type === "tRNS") {
      trns = Buffer.from(data);
    } else if (type === "IDAT") {
      idat.push(Buffer.from(data));
    } else if (type === "IEND") {
      break;
    }
    pos = dataEnd + 4; // skip CRC
  }

  if (width <= 0 || height <= 0 || bitDepth !== 8 || interlace !== 0) return null;
  const channels =
    colorType === 0 ? 1 : colorType === 2 ? 3 : colorType === 3 ? 1 : colorType === 4 ? 2 : colorType === 6 ? 4 : 0;
  if (channels === 0) return null;
  if (colorType === 3 && !palette) return null;
  if (idat.length === 0) return null;

  let raw: Buffer;
  try {
    raw = zlib.inflateSync(Buffer.concat(idat));
  } catch {
    return null;
  }

  const stride = width * channels;
  if (raw.length < (stride + 1) * height) return null;

  // Reverse the per-scanline filters (None/Sub/Up/Average/Paeth).
  const recon = new Uint8Array(stride * height);
  const bpp = channels;
  let rp = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[rp++]!;
    const rowOff = y * stride;
    const prevOff = rowOff - stride;
    for (let x = 0; x < stride; x++) {
      const rawByte = raw[rp++]!;
      const a = x >= bpp ? recon[rowOff + x - bpp]! : 0;
      const b = y > 0 ? recon[prevOff + x]! : 0;
      const c = y > 0 && x >= bpp ? recon[prevOff + x - bpp]! : 0;
      let val: number;
      switch (filter) {
        case 0: val = rawByte; break;
        case 1: val = rawByte + a; break;
        case 2: val = rawByte + b; break;
        case 3: val = rawByte + ((a + b) >> 1); break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a);
          const pb = Math.abs(p - b);
          const pc = Math.abs(p - c);
          val = rawByte + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c);
          break;
        }
        default: return null;
      }
      recon[rowOff + x] = val & 0xff;
    }
  }

  // Expand to RGBA.
  const rgba = new Uint8Array(width * height * 4);
  for (let px = 0; px < width * height; px++) {
    const base = px * channels;
    let r: number, g: number, b: number, a = 255;
    if (colorType === 0) {
      r = g = b = recon[base]!;
    } else if (colorType === 2) {
      r = recon[base]!; g = recon[base + 1]!; b = recon[base + 2]!;
    } else if (colorType === 3) {
      const idx = recon[base]!;
      r = palette![idx * 3] ?? 0;
      g = palette![idx * 3 + 1] ?? 0;
      b = palette![idx * 3 + 2] ?? 0;
      a = trns && idx < trns.length ? trns[idx]! : 255;
    } else if (colorType === 4) {
      r = g = b = recon[base]!; a = recon[base + 1]!;
    } else {
      r = recon[base]!; g = recon[base + 1]!; b = recon[base + 2]!; a = recon[base + 3]!;
    }
    const o = px * 4;
    rgba[o] = r; rgba[o + 1] = g; rgba[o + 2] = b; rgba[o + 3] = a;
  }
  return { width, height, rgba };
}

/** Box-average resample to (dw × dh) RGBA. Works for up- and down-scaling. */
function resampleBox(src: Uint8Array, sw: number, sh: number, dw: number, dh: number): Uint8Array {
  const dst = new Uint8Array(dw * dh * 4);
  for (let dy = 0; dy < dh; dy++) {
    const sy0 = Math.floor((dy * sh) / dh);
    const sy1 = Math.max(sy0 + 1, Math.floor(((dy + 1) * sh) / dh));
    for (let dx = 0; dx < dw; dx++) {
      const sx0 = Math.floor((dx * sw) / dw);
      const sx1 = Math.max(sx0 + 1, Math.floor(((dx + 1) * sw) / dw));
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let sy = sy0; sy < sy1; sy++) {
        for (let sx = sx0; sx < sx1; sx++) {
          const i = (sy * sw + sx) * 4;
          r += src[i]!; g += src[i + 1]!; b += src[i + 2]!; a += src[i + 3]!; n++;
        }
      }
      const o = (dy * dw + dx) * 4;
      dst[o] = Math.round(r / n);
      dst[o + 1] = Math.round(g / n);
      dst[o + 2] = Math.round(b / n);
      dst[o + 3] = Math.round(a / n);
    }
  }
  return dst;
}

/**
 * Render a base64 PNG as true-colour half-block art, ≤ `maxWidthCells` wide and
 * ≤ `maxRows` text rows tall (aspect-ratio preserved; cells are ~2× taller than
 * wide, hence the 0.5 factor). Returns `null` if the data isn't a decodable PNG.
 */
export function renderImageAsAnsi(
  base64: string,
  mime: string,
  maxWidthCells: number,
  maxRows: number,
): string[] | null {
  if (mime !== "image/png" || !base64) return null;
  let buf: Buffer;
  try {
    buf = Buffer.from(base64, "base64");
  } catch {
    return null;
  }
  const img = decodePng(buf);
  if (!img || img.width <= 0 || img.height <= 0) return null;

  // Width follows the card budget (never upscaled past native); height follows
  // from the aspect ratio (÷2: a cell is ~2× taller than wide), then hard-capped
  // at maxRows. Capping compresses pathologically tall images slightly rather
  // than letting them flood scrollback.
  const targetWidth = Math.max(1, Math.min(Math.floor(maxWidthCells), img.width));
  const aspectRows = Math.max(1, Math.ceil((targetWidth * (img.height / img.width)) / 2));
  const rows = Math.min(aspectRows, Math.max(1, Math.floor(maxRows)));
  const targetHeight = rows * 2;

  const small = resampleBox(img.rgba, img.width, img.height, targetWidth, targetHeight);
  // Composite any transparency over black so semi-transparent edges stay sane.
  const over = (c: number, a: number) => Math.round((c * a) / 255);

  const lines: string[] = [];
  for (let y = 0; y < targetHeight; y += 2) {
    let line = "";
    for (let x = 0; x < targetWidth; x++) {
      const ti = (y * targetWidth + x) * 4;
      const bi = (Math.min(y + 1, targetHeight - 1) * targetWidth + x) * 4;
      const ta = small[ti + 3]!;
      const ba = small[bi + 3]!;
      line +=
        fg(over(small[ti]!, ta), over(small[ti + 1]!, ta), over(small[ti + 2]!, ta)) +
        bg(over(small[bi]!, ba), over(small[bi + 1]!, ba), over(small[bi + 2]!, ba)) +
        UPPER_HALF;
    }
    lines.push(line + RESET);
  }
  return lines;
}
