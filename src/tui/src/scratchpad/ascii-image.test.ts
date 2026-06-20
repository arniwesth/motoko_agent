import { describe, expect, it } from "@jest/globals";
import zlib from "node:zlib";
import { decodePng, renderImageAsAnsi } from "./ascii-image.js";

// A well-formed 4x4 RGB PNG (correct chunk lengths + CRCs).
const PNG_4x4 =
  "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAP0lEQVR4nAE0AMv/AAAAABAgMCBAYDBgkABAgMBQoPBgwCBw4FAAgACAkCCwoEDgsGAQAMCAQNCgcODAoPDg0MHDFgGB5uiKAAAAAElFTkSuQmCC";

/** Build a minimal 8-bit RGB PNG (filter 0, dummy CRCs — the decoder skips CRC). */
function makeRgbPng(width: number, height: number, rgb: number[]): Buffer {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // colour type RGB
  const stride = width * 3;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0; // filter: None
    for (let x = 0; x < stride; x++) raw[y * (stride + 1) + 1 + x] = rgb[y * stride + x]!;
  }
  const idat = zlib.deflateSync(raw);
  const chunk = (type: string, data: Buffer): Buffer => {
    const out = Buffer.alloc(12 + data.length);
    out.writeUInt32BE(data.length, 0);
    out.write(type, 4, "ascii");
    data.copy(out, 8);
    out.writeUInt32BE(0, 8 + data.length); // dummy CRC
    return out;
  };
  return Buffer.concat([
    sig,
    chunk("IHDR", ihdr),
    chunk("IDAT", idat),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

describe("decodePng", () => {
  it("decodes a real PNG to RGBA", () => {
    const img = decodePng(Buffer.from(PNG_4x4, "base64"));
    expect(img).not.toBeNull();
    expect(img!.width).toBe(4);
    expect(img!.height).toBe(4);
    expect(img!.rgba.length).toBe(4 * 4 * 4);
  });

  it("decodes a multi-pixel RGB PNG with correct colours", () => {
    // 2x1: red, green.
    const png = makeRgbPng(2, 1, [255, 0, 0, 0, 255, 0]);
    const img = decodePng(png);
    expect(img).not.toBeNull();
    expect([img!.width, img!.height]).toEqual([2, 1]);
    expect([...img!.rgba.slice(0, 4)]).toEqual([255, 0, 0, 255]);
    expect([...img!.rgba.slice(4, 8)]).toEqual([0, 255, 0, 255]);
  });

  it("returns null for non-PNG data", () => {
    expect(decodePng(Buffer.from("not a png at all"))).toBeNull();
  });
});

describe("renderImageAsAnsi", () => {
  it("renders half-block art (contains ▀ and true-colour escapes)", () => {
    const lines = renderImageAsAnsi(PNG_4x4, "image/png", 10, 24);
    expect(lines).not.toBeNull();
    expect(lines!.length).toBeGreaterThanOrEqual(1);
    const joined = lines!.join("\n");
    expect(joined).toContain("▀");
    expect(joined).toContain("\x1b[38;2;"); // truecolor fg
    expect(joined).toContain("\x1b[48;2;"); // truecolor bg
  });

  it("honors the row cap for tall images", () => {
    // 2 wide, 200 tall → at full width would be ~50 rows; clamp to <= 8.
    const tall = makeRgbPng(2, 200, new Array(2 * 200 * 3).fill(120));
    const lines = renderImageAsAnsi(tall.toString("base64"), "image/png", 40, 8);
    expect(lines).not.toBeNull();
    expect(lines!.length).toBeLessThanOrEqual(8);
  });

  it("returns null for non-PNG mime or undecodable data", () => {
    expect(renderImageAsAnsi(PNG_4x4, "image/jpeg", 10, 24)).toBeNull();
    expect(renderImageAsAnsi("@@@not-base64@@@", "image/png", 10, 24)).toBeNull();
    expect(renderImageAsAnsi("", "image/png", 10, 24)).toBeNull();
  });
});
