// gen.ts — input generators for path_direct.ail. Writes one case per line:
//
//   <entries>|<start>      <entries> = `id<parent` joined by `,`; a root's parent is empty
//
//   bun gen.ts exhaustive <ids> <parents> <starts> <maxlen>
//        every entry list of length 0..maxlen whose entries are (id, parent) pairs from
//        <ids> x <parents>, each with every start in <starts>. Alphabets are `/`-separated,
//        `_` stands for the empty string. E1: a/b/c  _/a/b/c/z  _/a/b/c/z  4
//   bun gen.ts random <seed> <count> <maxN> <maxPool>
//        random lists: N in 0..maxN entries, ids drawn from a pool of 1..maxPool names (so
//        duplicate ids happen), parents empty (15%), a name outside the pool (5%) or a pool
//        name (80%); the start is a pool name, empty, or outside the pool.
//   bun gen.ts structured <maxlen>
//        the shapes the host writes, then broken: a chain e0 <- e1 <- … <- e(n-1) (e0 the
//        root), for n in 1..maxlen; and the same chain with ONE parent redirected to a later or
//        equal entry (a cycle of every length and position), and to a missing id; every start.
//   bun gen.ts long <n>
//        one linear chain of n entries (host shape) and the same with the root's parent set to
//        the leaf (a cycle through the whole file), started at the leaf.
//   bun gen.ts deep <n>
//        n distinct root entries (parent empty) and two starts: the LAST entry's id (find_entry
//        walks the whole file to reach it, path length 1) and an absent id (whole file, None).
//        Isolates find_entry's own recursion depth from path length.

const [mode, ...rest] = process.argv.slice(2);
const out: string[] = [];
const enc = (es: [string, string][]) => es.map(([i, p]) => `${i}<${p}`).join(",");
const alpha = (s: string) => s.split("/").map((x) => (x === "_" ? "" : x));

function exhaustive(ids: string[], parents: string[], starts: string[], maxlen: number) {
  const items: [string, string][] = [];
  for (const i of ids) for (const p of parents) items.push([i, p]);
  // by length, so the first violation found is a shortest one
  const fixed = (prefix: [string, string][], left: number) => {
    if (left === 0) { for (const s of starts) out.push(`${enc(prefix)}|${s}`); return; }
    for (const it of items) fixed([...prefix, it], left - 1);
  };
  for (let len = 0; len <= maxlen; len++) fixed([], len);
}

function mulberry32(a: number) {
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function random(seed: number, count: number, maxN: number, maxPool: number) {
  const r = mulberry32(seed);
  const int = (n: number) => Math.floor(r() * n);
  for (let c = 0; c < count; c++) {
    const pool = Array.from({ length: 1 + int(maxPool) }, (_, k) => `n${k}`);
    const n = int(maxN + 1);
    const es: [string, string][] = [];
    for (let k = 0; k < n; k++) {
      const u = r();
      const p = u < 0.15 ? "" : u < 0.2 ? "zz" : pool[int(pool.length)];
      es.push([pool[int(pool.length)], p]);
    }
    const u = r();
    const start = u < 0.05 ? "" : u < 0.1 ? "zz" : pool[int(pool.length)];
    out.push(`${enc(es)}|${start}`);
  }
}

const id = (k: number) => String(k).padStart(6, "0"); // entryId's shape: zero-padded seq

function chain(n: number): [string, string][] {
  return Array.from({ length: n }, (_, k) => [id(k), k === 0 ? "" : id(k - 1)] as [string, string]);
}

function structured(maxlen: number) {
  for (let n = 1; n <= maxlen; n++) {
    const base = chain(n);
    const starts = [...base.map(([i]) => i), "", "missing"];
    for (const s of starts) out.push(`${enc(base)}|${s}`);
    for (let k = 0; k < n; k++) {
      // entry k's parent redirected to entry j >= k: a cycle k -> j -> j-1 -> ... -> k
      for (let j = k; j < n; j++) {
        const es = base.map((e) => [...e] as [string, string]);
        es[k][1] = id(j);
        for (const s of starts) out.push(`${enc(es)}|${s}`);
      }
      const es = base.map((e) => [...e] as [string, string]);
      es[k][1] = "missing";
      for (const s of starts) out.push(`${enc(es)}|${s}`);
    }
  }
}

function long(n: number) {
  const base = chain(n);
  out.push(`${enc(base)}|${id(n - 1)}`);
  const cyc = base.map((e) => [...e] as [string, string]);
  cyc[0][1] = id(n - 1);
  out.push(`${enc(cyc)}|${id(n - 1)}`);
}

function deep(n: number) {
  const es: [string, string][] = Array.from({ length: n }, (_, k) => [id(k), ""] as [string, string]);
  out.push(`${enc(es)}|${id(n - 1)}`);
  out.push(`${enc(es)}|absent`);
}

switch (mode) {
  case "exhaustive": exhaustive(alpha(rest[0]), alpha(rest[1]), alpha(rest[2]), Number(rest[3])); break;
  case "random": random(Number(rest[0]), Number(rest[1]), Number(rest[2]), Number(rest[3])); break;
  case "structured": structured(Number(rest[0])); break;
  case "long": long(Number(rest[0])); break;
  case "deep": deep(Number(rest[0])); break;
  default: throw new Error("usage: bun gen.ts exhaustive|random|structured|long …");
}
process.stdout.write(out.join("\n") + (out.length ? "\n" : ""));
