// gen.ts — input generators for T6 (truncate_utf8_by_bytes and its twins).
//
//   bun gen.ts <generator> [size] [seed] [max length]  > cases.txt
//
// One case per line:  <input bytes as decimal CSV>|<max_bytes>
// (the CSV may be empty: the empty string). Generators:
//
//   chars L   every string of 0..L characters over {a, é, €, 😀} (1, 2, 3, 4 UTF-8 bytes),
//             each with every max_bytes in -1 .. byteLength+1. Valid UTF-8 only.
//   bytes L   every byte sequence of length 0..L over a 12-byte alphabet that contains whole
//             and partial encodings of 2-, 3- and 4-byte characters plus 0xFF and a lone
//             continuation byte, each with every max_bytes in -1 .. length+1. Mostly NOT
//             valid UTF-8: the domain AILANG strings reach through std/bytes.toString.
//   random N [seed] [L]  N random strings (seeded, default 6): 0..L code points (default 64) drawn from ASCII, Latin-1,
//             BMP, astral planes and the encoding-boundary code points
//             U+007F/0080/07FF/0800/FFFF/10000/10FFFF; max_bytes uniform in -2 .. len+2.
//   cjk N     one string of N CJK characters (3 bytes each, U+6F22) with max_bytes in
//             {0, 1, 2, N-1, N, N+1, 2N, 3N-1, 3N, 3N+1, 4000}: at N = 1400 this is the shape
//             store_stdout_and_elide meets at compose's default cap of 4000 bytes.
//
// All generators are deterministic; `random` takes a seed (default 6).

const [gen, sizeArg, seedArg, lenArg] = process.argv.slice(2);
const size = Number(sizeArg ?? "0");
const out: string[] = [];
const enc = new TextEncoder();
const emit = (bytes: Uint8Array | number[], max: number) => out.push(`${Array.from(bytes).join(",")}|${max}`);

function emitAllMax(bytes: Uint8Array | number[], lo = -1, hiExtra = 1) {
  for (let m = lo; m <= bytes.length + hiExtra; m++) emit(bytes, m);
}

if (gen === "chars") {
  const alpha = ["a", "é", "€", "😀"];
  let frontier = [""];
  for (let len = 0; len <= size; len++) {
    for (const s of frontier) emitAllMax(enc.encode(s));
    const next: string[] = [];
    for (const s of frontier) for (const c of alpha) next.push(s + c);
    frontier = next;
  }
} else if (gen === "bytes") {
  // a; é = C3 A9; € = E2 82 AC; 😀 = F0 9F 98 80; FF never valid; 80 lone continuation.
  const alpha = [0x61, 0xc3, 0xa9, 0xe2, 0x82, 0xac, 0xf0, 0x9f, 0x98, 0x80, 0xff, 0xbf];
  let frontier: number[][] = [[]];
  for (let len = 0; len <= size; len++) {
    for (const s of frontier) emitAllMax(s);
    const next: number[][] = [];
    for (const s of frontier) for (const b of alpha) next.push([...s, b]);
    frontier = next;
  }
} else if (gen === "random") {
  let x = BigInt(seedArg ?? "6") * 0x9e3779b97f4a7c15n + 1n;
  const rnd = () => {
    // splitmix64
    x = (x + 0x9e3779b97f4a7c15n) & 0xffffffffffffffffn;
    let z = x;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & 0xffffffffffffffffn;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & 0xffffffffffffffffn;
    return Number((z ^ (z >> 31n)) & 0xffffffffn) / 2 ** 32;
  };
  const pick = (lo: number, hi: number) => lo + Math.floor(rnd() * (hi - lo + 1));
  const edges = [0x00, 0x7f, 0x80, 0x7ff, 0x800, 0xfffd, 0xffff, 0x10000, 0x10ffff];
  const cp = (): number => {
    const k = pick(0, 5);
    let c: number;
    if (k === 0) c = pick(0x20, 0x7e);
    else if (k === 1) c = pick(0x80, 0x7ff);
    else if (k === 2) c = pick(0x800, 0xffff);
    else if (k === 3) c = pick(0x10000, 0x10ffff);
    else if (k === 4) c = edges[pick(0, edges.length - 1)];
    else c = pick(0x4e00, 0x9fff);
    return c >= 0xd800 && c <= 0xdfff ? 0x41 : c; // surrogates are not scalar values
  };
  for (let i = 0; i < size; i++) {
    const n = pick(0, Number(lenArg ?? "64"));
    let s = "";
    for (let j = 0; j < n; j++) s += String.fromCodePoint(cp());
    const b = enc.encode(s);
    emit(b, pick(-2, b.length + 2));
  }
} else if (gen === "cjk") {
  const b = enc.encode("漢".repeat(size));
  const ms = new Set([0, 1, 2, size - 1, size, size + 1, 2 * size, 3 * size - 1, 3 * size, 3 * size + 1, 4000]);
  for (const m of [...ms].filter((m) => m >= 0).sort((x, y) => x - y)) emit(b, m);
} else {
  console.error("usage: bun gen.ts chars|bytes|random|cjk <size> [seed]");
  process.exit(2);
}
process.stdout.write(out.join("\n") + "\n");
