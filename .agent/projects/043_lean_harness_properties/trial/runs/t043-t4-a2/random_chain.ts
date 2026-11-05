// random_chain.ts — randomised check of T4 (src/core/journal.ail:242-300) on the REAL code.
//
// TypeScript generates random (base, [Message]) cases with a seeded PRNG, writes them as literals
// into an AILANG program (pkg/t4/gen/random_cases.ail) whose `main` calls the REAL
// `chain_digests_over`, `chain_digest_over`, `chain_digests_json` and `messages_json` and prints
// their raw outputs. This file then states the properties in TypeScript over those outputs:
//
//   P4.1       for every split k: D(b, ms) == D(b, ms[..k]) ++ D(O(b, ms[..k]), ms[k..])
//   P4.2       |D(b, ms)| == |ms|  and  ms != [] ==> last(D(b, ms)) == O(b, ms)
//   X-2        D(b, ms)[i] == O(b, ms[..i+1]) for every i (the "prefix chain")
//   X-5        encode(chain_digests_json(ds)) parses back to exactly ds, in order
//   X-6        every digest is `sha256:` + 64 lowercase hex
//   X-7        the AILANG side saw the messages TS generated (messages_json round trip)
//
// where D = chain_digests_over and O = chain_digest_over. Fields that can carry an arbitrary base
// string (the base itself, O, and O over a prefix, which is the base when the prefix is empty)
// are printed JSON-encoded; digest lists are space-joined (a chain digest never contains a space). Exit 1 if any P/X check fails.
//
//   bun ../out/random_chain.ts [seed] [cases] [maxlen]        (from the tree root)
//   T4_PKG=../out/pkg_fixed bun ../out/random_chain.ts ...     (control: the one-token fix)

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";

const OUT = dirname(new URL(import.meta.url).pathname);
// T4_PKG selects the package root: out/pkg (the real tree) by default, out/pkg_fixed for the
// control run against the one-token fix (see fix_base.diff).
const PKG = process.env.T4_PKG ? process.env.T4_PKG : join(OUT, "pkg");
const PKGNAME = PKG.replace(/\/+$/, "").split("/").pop();
const seed = Number(process.argv[2] ?? 1);
const N = Number(process.argv[3] ?? 200);
const MAXLEN = Number(process.argv[4] ?? 24);

// mulberry32
let st = seed >>> 0;
function rnd(): number {
  st = (st + 0x6d2b79f5) >>> 0;
  let t = st;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const ri = (n: number) => Math.floor(rnd() * n);
const pick = <T>(xs: T[]): T => xs[ri(xs.length)];

const ATOMS = ["", "a", "b", "é", "😀", "\n", "\"", "\\", "$", "${x}", ";", ":", "{", "}", "m{", "im-end;", "tc-end;",
  "role:4:user;", "content:1:a;", "sha256:", "0", "12", " ", "\t", "ü", "日本"];
function rstr(maxAtoms: number): string {
  const k = ri(maxAtoms + 1);
  let s = "";
  for (let i = 0; i < k; i++) s += pick(ATOMS);
  return s;
}

type TC = { id: string; name: string; arguments: string };
type Img = { source: string; mime: string };
type Msg = { role: string; content: string; tool_calls: TC[]; tool_call_id: string; images: Img[] };

function rmsg(): Msg {
  const role = rnd() < 0.85 ? pick(["user", "assistant", "tool", "system"]) : rstr(2);
  const tcs: TC[] = [];
  const ntc = rnd() < 0.7 ? 0 : 1 + ri(3);
  for (let i = 0; i < ntc; i++) tcs.push({ id: rstr(2), name: pick(["bash", "read", rstr(2)]), arguments: pick(["{}", "{\"a\":1}", rstr(3)]) });
  const imgs: Img[] = [];
  const nim = rnd() < 0.8 ? 0 : 1 + ri(2);
  for (let i = 0; i < nim; i++) imgs.push({ source: rstr(3), mime: pick(["image/png", "image/jpeg", rstr(1)]) });
  return { role, content: rstr(6), tool_calls: tcs, tool_call_id: rnd() < 0.7 ? "" : rstr(2), images: imgs };
}

// A base is either the real empty base (computed in AILANG) or a literal string.
type Base = { empty: true } | { empty: false; lit: string };
function rbase(): Base {
  const r = rnd();
  if (r < 0.4) return { empty: true };
  if (r < 0.55) return { empty: false, lit: "" };
  if (r < 0.8) {
    let h = "";
    for (let i = 0; i < 64; i++) h += "0123456789abcdef"[ri(16)];
    return { empty: false, lit: "sha256:" + h };
  }
  return { empty: false, lit: rstr(4) };
}

// AILANG string literal: escape everything that is not plain printable ASCII, plus \ " $.
function lit(s: string): string {
  let o = '"';
  for (const ch of s) {
    const cp = ch.codePointAt(0)!;
    if (ch === "\\") o += "\\\\";
    else if (ch === '"') o += '\\"';
    else if (ch === "$" || cp < 0x20 || cp > 0x7e) o += `\\u{${cp.toString(16)}}`;
    else o += ch;
  }
  return o + '"';
}
const tcLit = (c: TC) => `{ id: ${lit(c.id)}, name: ${lit(c.name)}, arguments: ${lit(c.arguments)} }`;
const imLit = (i: Img) => `{ source: ${lit(i.source)}, mime: ${lit(i.mime)} }`;
const msgLit = (m: Msg) =>
  `{ role: ${lit(m.role)}, content: ${lit(m.content)}, tool_calls: [${m.tool_calls.map(tcLit).join(", ")}], ` +
  `tool_call_id: ${lit(m.tool_call_id)}, images: [${m.images.map(imLit).join(", ")}] }`;
const baseLit = (b: Base) => (b.empty ? "chain_empty_base()" : lit(b.lit));

type Case = { base: Base; ms: Msg[] };
const cases: Case[] = [];
for (let c = 0; c < N; c++) {
  // Bias towards short lists but reach MAXLEN.
  const n = rnd() < 0.3 ? ri(4) : ri(MAXLEN + 1);
  const ms: Msg[] = [];
  for (let i = 0; i < n; i++) ms.push(rmsg());
  cases.push({ base: rbase(), ms });
}

const prog = `-- GENERATED by random_chain.ts (seed ${seed}, ${N} cases, maxlen ${MAXLEN}). Do not edit.
module random_cases

import std/io (println)
import std/ai (Message)
import std/json (encode, js)
import std/string as Str (join, intToStr)
import std/list as List (length, take, drop, range, map, foldl)
import src/core/journal (chain_digest_over, chain_digests_over, chain_digests_json, chain_empty_base, messages_json)

type Case = { base: string, ms: [Message] }

pure func cases() -> [Case] {
  [
${cases.map((c) => `    { base: ${baseLit(c.base)}, ms: [${c.ms.map(msgLit).join(",\n      ")}] }`).join(",\n")}
  ]
}

func emit(ci: int, c: Case) -> () ! {IO} {
  let ms = c.ms;
  let n = length(ms);
  let ds = chain_digests_over(c.base, ms);
  println("C\\t${"${intToStr(ci)}"}\\t${"${intToStr(n)}"}\\t${"${encode(js(c.base))}"}");
  println("M\\t${"${intToStr(ci)}"}\\t${"${encode(messages_json(ms))}"}");
  println("D\\t${"${intToStr(ci)}"}\\t${"${join(\" \", ds)}"}");
  println("J\\t${"${intToStr(ci)}"}\\t${"${encode(chain_digests_json(ds))}"}");
  println("O\\t${"${intToStr(ci)}"}\\t${"${encode(js(chain_digest_over(c.base, ms)))}"}");
  emitPrefixes(ci, c.base, ms, 0, n);
  emitSplits(ci, c.base, ms, 0, n)
}

func emitPrefixes(ci: int, b: string, ms: [Message], i: int, n: int) -> () ! {IO} {
  if i >= n then () else {
    println("P\\t${"${intToStr(ci)}"}\\t${"${intToStr(i)}"}\\t${"${chain_digest_over(b, take(i + 1, ms))}"}");
    emitPrefixes(ci, b, ms, i + 1, n)
  }
}

func emitSplits(ci: int, b: string, ms: [Message], k: int, n: int) -> () ! {IO} {
  if k > n then () else {
    let xs = take(k, ms);
    let ys = drop(k, ms);
    let ox = chain_digest_over(b, xs);
    println("S\\t${"${intToStr(ci)}"}\\t${"${intToStr(k)}"}\\t${"${join(\" \", chain_digests_over(b, xs))}"}\\t${"${encode(js(ox))}"}\\t${"${join(\" \", chain_digests_over(ox, ys))}"}");
    emitSplits(ci, b, ms, k + 1, n)
  }
}

func emitAll(i: int, cs: [Case]) -> () ! {IO} {
  match cs {
    [] => (),
    c :: rest => { emit(i, c); emitAll(i + 1, rest) }
  }
}

export func main() -> () ! {IO} {
  emitAll(0, cases());
  println("END")
}
`;

const genDir = join(PKG, "t4", "gen");
mkdirSync(genDir, { recursive: true });
const genFile = `random_cases_${PKGNAME}.ail`;
writeFileSync(join(genDir, genFile), prog);

const r = spawnSync(
  "ailang",
  ["run", "--relax-modules", "--caps", "IO", "--chdir", PKG, "--entry", "main", `t4/gen/${genFile}`],
  { encoding: "utf8", maxBuffer: 1 << 30 },
);
if (r.status !== 0 || !r.stdout.includes("\nEND")) {
  process.stderr.write(r.stderr.split("\n").filter((l) => !/dependency|ailang lock|MOD010|relax-modules flag/.test(l)).join("\n"));
  process.stderr.write("random_chain: the AILANG side did not complete\n");
  process.exit(2);
}

// ---- parse ----
type Obs = {
  n: number; base: string; msJson: string; D: string[]; J: string; O: string;
  P: Map<number, string>; S: Map<number, { dx: string[]; ox: string; dy: string[] }>;
};
const words = (s: string) => (s === "" ? [] : s.split(" "));
const obs: Obs[] = [];
for (const line of r.stdout.split("\n")) {
  const f = line.split("\t");
  const ci = Number(f[1]);
  switch (f[0]) {
    case "C": obs[ci] = { n: Number(f[2]), base: JSON.parse(f[3]), msJson: "", D: [], J: "", O: "", P: new Map(), S: new Map() }; break;
    case "M": obs[ci].msJson = f.slice(2).join("\t"); break;
    case "D": obs[ci].D = words(f[2] ?? ""); break;
    case "J": obs[ci].J = f[2]; break;
    case "O": obs[ci].O = JSON.parse(f[2]); break;
    case "P": obs[ci].P.set(Number(f[2]), f[3]); break;
    case "S": obs[ci].S.set(Number(f[2]), { dx: words(f[3] ?? ""), ox: JSON.parse(f[4]), dy: words(f[5] ?? "") }); break;
  }
}

// ---- the properties, stated in TypeScript ----
const eq = (a: string[], b: string[]) => a.length === b.length && a.every((x, i) => x === b[i]);
const fails: Record<string, number> = { "P4.1": 0, "P4.2-len": 0, "P4.2-last": 0, "X-2": 0, "X-5": 0, "X-6": 0, "X-7": 0 };
const wit: Record<string, string[]> = {};
const note = (p: string, w: string) => { fails[p]++; (wit[p] ??= []).length < 3 && wit[p].push(w); };
const HEX = /^sha256:[0-9a-f]{64}$/;
let splits = 0, maxN = 0, baseKinds = { empty: 0, other: 0 };

cases.forEach((c, ci) => {
  const o = obs[ci];
  if (!o) { note("X-7", `case ${ci}: no output`); return; }
  const tag = `case ${ci} base=${c.base.empty ? "chain_empty_base()" : JSON.stringify(c.base.lit)} n=${o.n}`;
  maxN = Math.max(maxN, o.n);
  c.base.empty ? baseKinds.empty++ : baseKinds.other++;
  // X-7: what AILANG hashed is what TS generated
  if (o.n !== c.ms.length || JSON.stringify(JSON.parse(o.msJson)) !== JSON.stringify(c.ms)) note("X-7", tag);
  // P4.2
  if (o.D.length !== c.ms.length) note("P4.2-len", `${tag} |D|=${o.D.length}`);
  if (c.ms.length > 0 && o.D[o.D.length - 1] !== o.O) note("P4.2-last", `${tag} last(D)=${o.D[o.D.length - 1]} O=${o.O}`);
  // X-2
  for (let i = 0; i < c.ms.length; i++) if (o.D[i] !== o.P.get(i)) { note("X-2", `${tag} i=${i}`); break; }
  // X-5
  const j = JSON.parse(o.J);
  if (!Array.isArray(j) || !eq(j, o.D)) note("X-5", tag);
  // X-6
  if (![...o.D, o.O].every((d) => HEX.test(d)) && !(c.ms.length === 0 && o.O === o.base)) note("X-6", tag);
  // P4.1 (every split is checked; the case is counted once)
  let p41bad = false;
  for (let k = 0; k <= c.ms.length; k++) {
    const s = o.S.get(k);
    splits++;
    if (!s || !eq(o.D, [...s.dx, ...s.dy])) { if (!p41bad) note("P4.1", `${tag} first bad k=${k}`); p41bad = true; }
  }
});

console.log(`random_chain: pkg=${PKGNAME} seed=${seed} cases=${N} maxlen=${MAXLEN} (longest generated ${maxN}) ` +
  `bases: ${baseKinds.empty} chain_empty_base(), ${baseKinds.other} other; ${splits} splits checked`);
// What the root cause (chain_digests_over ignores `base`) predicts, for comparison with the counts:
// P4.1 fails exactly on lists of length >= 2; P4.2-last and X-2 exactly on non-empty lists whose
// base is not chain_empty_base().
const pred41 = cases.filter((c) => c.ms.length >= 2).length;
const pred42 = cases.filter((c, ci) => c.ms.length >= 1 && !c.base.empty && obs[ci] && obs[ci].base !== obs.find((o, j) => o && cases[j].base.empty)?.base).length;
console.log(`  (base-ignored hypothesis predicts: P4.1 ${pred41}, P4.2-last/X-2 ${pred42})`);
let bad = 0;
for (const [p, n] of Object.entries(fails)) {
  console.log(`  ${p.padEnd(10)} ${n} failing case(s)`);
  for (const w of wit[p] ?? []) console.log(`      witness: ${w}`);
  bad += n;
}
process.exit(bad > 0 ? 1 : 0);
