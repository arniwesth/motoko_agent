// gen_cases.ts — inputs for the T6 harnesses. Writes `<out>.cases` (one `<max_bytes>,<base64>`
// per line, the format via_store.ail and direct.sh read) and `<out>.tags` (the generator that
// produced each line, same order).
//
//   bun gen_cases.ts <out prefix> [seed] [units_len] [bytes_len] [random_count]
//
// Generators (all deterministic for a given seed):
//   units   every string of 0..units_len units over ["a", "é", "€", "😀"] (1, 2, 3, 4 bytes),
//           with every max_bytes from -1 to byte_length + 1
//   bytes   every byte string of length 0..bytes_len over 17 byte values chosen at the UTF-8
//           class boundaries (ASCII, continuation, lead bytes for 2/3/4 bytes, overlong and
//           surrogate leads, never-valid bytes), with every max_bytes from -1 to length + 1.
//           Most of these are not valid UTF-8; P6.1/P6.2 are stated for every string.
//   bytes1  all 256 single bytes and all 65,536 two-byte strings, max_bytes 0 and 1
//   random  random_count random valid strings from weighted code-point classes (ASCII,
//           Latin-1, BMP incl. CJK, astral incl. emoji, combining marks, ZWJ, NUL, U+FFFD,
//           BOM), 0..64 code points, each with max_bytes at the boundaries that matter
//           (0, 1, runes-1, runes, runes+1, bytes-1, bytes, bytes+1) and two random values
//   extreme max_bytes of +-2^31 and +-2^62 on five short inputs
//   big     production-shaped: compose clamps max_stdout_bytes to a positive value, default
//           4000 (compose.ail:851); inputs of a few thousand CJK/emoji/mixed characters

import { writeFileSync } from "fs";

const prefix = process.argv[2];
if (!prefix) throw new Error("usage: bun gen_cases.ts <out prefix> [seed] [units_len] [bytes_len] [random_count]");
const seed = Number(process.argv[3] ?? 1);
const unitsLen = Number(process.argv[4] ?? 5);
const bytesLen = Number(process.argv[5] ?? 3);
const randomCount = Number(process.argv[6] ?? 5000);

function mulberry32(a: number) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(seed);
const ri = (lo: number, hi: number) => lo + Math.floor(rnd() * (hi - lo + 1)); // inclusive

const lines: string[] = [];
const tags: string[] = [];
const enc = new TextEncoder();
function add(tag: string, bytes: Uint8Array, n: number) {
  lines.push(`${n},${Buffer.from(bytes).toString("base64")}`);
  tags.push(tag);
}

// units
const units = ["a", "é", "€", "😀"].map((u) => enc.encode(u));
function unitStrings(len: number): Uint8Array[][] {
  if (len === 0) return [[]];
  const out: Uint8Array[][] = [];
  for (const s of unitStrings(len - 1)) for (const u of units) out.push([...s, u]);
  return out;
}
for (let len = 0; len <= unitsLen; len++) {
  for (const parts of unitStrings(len)) {
    const b = Buffer.concat(parts);
    for (let n = -1; n <= b.length + 1; n++) add("units", b, n);
  }
}

// bytes
const byteAlphabet = [0x00, 0x41, 0x7f, 0x80, 0x8f, 0xbf, 0xc0, 0xc2, 0xdf, 0xe0, 0xe2, 0xed, 0xef, 0xf0, 0xf4, 0xf5, 0xff];
function byteStrings(len: number): number[][] {
  if (len === 0) return [[]];
  const out: number[][] = [];
  for (const s of byteStrings(len - 1)) for (const x of byteAlphabet) out.push([...s, x]);
  return out;
}
for (let len = 0; len <= bytesLen; len++) {
  for (const s of byteStrings(len)) {
    const b = Uint8Array.from(s);
    for (let n = -1; n <= b.length + 1; n++) add("bytes", b, n);
  }
}

// bytes1: every 1- and 2-byte string
for (let x = 0; x < 256; x++) for (const n of [0, 1]) add("bytes1", Uint8Array.of(x), n);
for (let x = 0; x < 256; x++) for (let y = 0; y < 256; y++) for (const n of [0, 1]) add("bytes1", Uint8Array.of(x, y), n);

// random
function randCodePoint(): number {
  const k = rnd();
  if (k < 0.30) return ri(0x20, 0x7e);
  if (k < 0.35) return ri(0x00, 0x1f);
  if (k < 0.45) return ri(0x80, 0x7ff);
  if (k < 0.60) return ri(0x4e00, 0x9fff); // CJK
  if (k < 0.65) return ri(0x0300, 0x036f); // combining marks
  if (k < 0.72) { const c = ri(0x800, 0xfffd); return c >= 0xd800 && c <= 0xdfff ? 0xfffd : c; }
  if (k < 0.85) return ri(0x1f300, 0x1faff); // emoji
  if (k < 0.90) return ri(0x10000, 0x10ffff);
  return [0x0, 0x200d, 0xfffd, 0xfeff, 0xffff, 0x10ffff][ri(0, 5)];
}
for (let i = 0; i < randomCount; i++) {
  const len = ri(0, 64);
  let s = "";
  for (let j = 0; j < len; j++) s += String.fromCodePoint(randCodePoint());
  const b = enc.encode(s);
  const runes = [...s].length;
  const ns = new Set([0, 1, runes - 1, runes, runes + 1, b.length - 1, b.length, b.length + 1, ri(0, b.length + 2), ri(0, b.length + 2)]);
  for (const n of ns) if (n >= -1) add("random", b, n);
}

// big
const big: [string, number[]][] = [
  ["中".repeat(2000), [4000, 3999, 2000, 1999, 6000]],
  ["中".repeat(1500), [4000]],
  ["😀".repeat(1000), [4000, 3999, 1000]],
  ["a".repeat(3999) + "😀", [4000, 4003, 3999]],
  ["é".repeat(4000), [4000, 7999, 8000]],
  ["x".repeat(4001), [4000]],
];
for (const [s, ns] of big) for (const n of ns) add("big", enc.encode(s), n);

// extreme: max_bytes far outside any real budget, on a few inputs
for (const s of ["", "a", "é", "€😀", "中".repeat(10)]) {
  for (const n of [2147483647, 2147483648, 4611686018427387904, -2147483648, -4611686018427387904]) add("extreme", enc.encode(s), n);
}

writeFileSync(`${prefix}.cases`, lines.join("\n") + "\n");
writeFileSync(`${prefix}.tags`, tags.join("\n") + "\n");
const counts: Record<string, number> = {};
for (const t of tags) counts[t] = (counts[t] ?? 0) + 1;
console.error(`gen_cases: seed ${seed}, ${lines.length} cases`, JSON.stringify(counts));
