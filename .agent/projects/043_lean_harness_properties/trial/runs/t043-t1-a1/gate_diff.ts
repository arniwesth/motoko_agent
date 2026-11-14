// gate_diff.ts — the P1.1 differential for the herdr environment gate (MOT-118).
//
// The TypeScript half calls the REAL `readHerdrEnvironment` (src/tui/src/herdr-agent-state.ts:157),
// loaded from the tree root (the current directory). The AILANG half is gate_ail.ail, next to this
// file, which calls the REAL `herdr_env_ready` (packages/motoko-ext-herdr/types.ail:1425).
//
// P1.1, as executed here: for every case (HERDR_ENV, HERDR_BIN_PATH, HERDR_PANE_ID), each unset or a
// string,
//
//     readHerdrEnvironment(env) !== null   <=>   herdr_env_ready(e ?? "", b ?? "", p ?? "")
//
// where `env` has a key only for the variables that are set. Every mismatch is printed with which
// side accepted it. Each mismatch is also scored against an executable statement of the documented
// intent (herdr-agent-state.ts:158-160 and types.ail:1405-1418): HERDR_ENV is exactly "1" and both
// HERDR_BIN_PATH and HERDR_PANE_ID are non-empty. That attribution is informative only; the exit code
// is P1.1 alone.
//
//   bun gate_diff.ts [--gen G[,G...]] [--n N] [--seed S] [--case JSON] [--scratch DIR] [--quiet]
//
//   --gen   exhaustive | env-order | bin | pane | random | all   (default: all)
//   --case  one triple, e.g. '["2","/usr/local/bin/herdr","w1:p7"]' (null = unset); overrides --gen
//
// Run from the tree root. Exit 0: no P1.1 mismatch. Exit 1: at least one. Exit 2: the harness could
// not run, or the AILANG side did not receive the strings it was sent (a transport problem, not a
// verdict).

import { spawnSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

type V = string | null; // null = unset
type Case = [V, V, V];

const here = import.meta.dir;
const tree = process.cwd();
const tsPath = path.join(tree, "src/tui/src/herdr-agent-state.ts");
if (!fs.existsSync(tsPath)) {
  console.error(`gate_diff: run from the tree root (no ${tsPath})`);
  process.exit(2);
}
const { readHerdrEnvironment } = (await import(tsPath)) as {
  readHerdrEnvironment: (env: NodeJS.ProcessEnv) => { paneId: string; bin: string } | null;
};

// ---------------------------------------------------------------------------------------------
// Arguments
// ---------------------------------------------------------------------------------------------
const argv = process.argv.slice(2);
function opt(name: string): string | undefined {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : undefined;
}
const gens = (opt("--gen") ?? "all").split(",");
const N = Number(opt("--n") ?? "20000");
const SEED = Number(opt("--seed") ?? "43118");
const single = opt("--case");
const quiet = argv.includes("--quiet");
const scratch = opt("--scratch") ?? fs.mkdtempSync(path.join(os.tmpdir(), "t043-gate-"));
fs.mkdirSync(scratch, { recursive: true });

// ---------------------------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------------------------

// Hand-picked values: the documented ones, the near-misses of "1" on both sides of the string
// order, whitespace, controls, non-ASCII, and realistic bin/pane values.
const VALUES: V[] = [
  null, "", "1", "0", "2", "9", "10", "01", "1 ", " 1", "1\n", "true", "yes", "on", "a", "A", ":",
  "/", "!", " ", "\t", "\n", "\u0000", "１", "é", "/usr/local/bin/herdr", "herdr", "w1:p7",
];

function exhaustive(): Case[] {
  const out: Case[] = [];
  for (const e of VALUES) for (const b of VALUES) for (const p of VALUES) out.push([e, b, p]);
  return out;
}

// Every string of length 0..2 over characters chosen around "1" in code-point order, for HERDR_ENV
// alone, with a realistic bin and pane. Any mismatch here is about HERDR_ENV.
const ORDER_CHARS = ["\u0000", "\t", " ", "!", "/", "0", "1", "2", "9", ":", "A", "a", "~", "\u007f", "é", "€", "１", "𝟙"];
function strings(chars: string[], maxLen: number): string[] {
  let layer = [""];
  const all = [""];
  for (let n = 1; n <= maxLen; n++) {
    const next: string[] = [];
    for (const s of layer) for (const c of chars) next.push(s + c);
    all.push(...next);
    layer = next;
  }
  return all;
}
function envOrder(): Case[] {
  const es: V[] = [null, ...strings(ORDER_CHARS, 2)];
  return es.map((e): Case => [e, "/usr/local/bin/herdr", "w1:p7"]);
}

// HERDR_BIN_PATH alone, with HERDR_ENV=1 and a pane id. Any mismatch here is about the binary.
const SLOT_CHARS = ["\u0000", "\t", "\n", " ", "/", "0", "1", "a", "é", "𝟙"];
function binSlice(): Case[] {
  const bs: V[] = [null, ...strings(SLOT_CHARS, 2), "/usr/local/bin/herdr", "herdr"];
  return bs.map((b): Case => ["1", b, "w1:p7"]);
}
// HERDR_PANE_ID alone, with HERDR_ENV=1 and a binary. Any mismatch here is about the pane id.
function paneSlice(): Case[] {
  const ps: V[] = [null, ...strings(SLOT_CHARS, 2), "w1:p7", "0"];
  return ps.map((p): Case => ["1", "/usr/local/bin/herdr", p]);
}

// Seeded random strings. Lone surrogates are excluded: an environment variable read from the OS is
// decoded from bytes and cannot carry one, and they do not survive JSON into Go (U+FFFD), so they
// would test the transport, not the gate.
function mulberry32(a: number) {
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function randomCases(n: number, seed: number): Case[] {
  const r = mulberry32(seed);
  const pick = <T,>(xs: T[]) => xs[Math.floor(r() * xs.length)];
  const randChar = (): string => {
    const k = r();
    if (k < 0.35) return String.fromCharCode(0x30 + Math.floor(r() * 10)); // digits
    if (k < 0.6) return String.fromCharCode(0x20 + Math.floor(r() * 0x5f)); // printable ASCII
    if (k < 0.7) return pick(["\u0000", "\t", "\n", "\r", "\u001b", "\u007f"]); // controls
    if (k < 0.85) {
      let c: number;
      do c = 0x80 + Math.floor(r() * (0xfffe - 0x80)); while (c >= 0xd800 && c <= 0xdfff);
      return String.fromCharCode(c); // BMP, no surrogates
    }
    return String.fromCodePoint(0x10000 + Math.floor(r() * 0xfffff)); // astral, as a valid pair
  };
  const randString = (): string => {
    const len = Math.floor(r() * 7);
    let s = "";
    for (let i = 0; i < len; i++) s += randChar();
    return s;
  };
  const slot = (bias: string[]): V => {
    const k = r();
    if (k < 0.15) return null;
    if (k < 0.25) return "";
    if (k < 0.45) return pick(bias);
    if (k < 0.6) return pick(bias) + randString();
    return randString();
  };
  const out: Case[] = [];
  for (let i = 0; i < n; i++) {
    out.push([slot(["1", "0", "2"]), slot(["/usr/local/bin/herdr", "herdr"]), slot(["w1:p7", "w2:p1"])]);
  }
  return out;
}

let cases: Case[] = [];
const genCounts: Record<string, number> = {};
const addGen = (name: string, cs: Case[]) => { genCounts[name] = cs.length; cases.push(...cs); };
if (single !== undefined) {
  const c = JSON.parse(single) as Case;
  if (!Array.isArray(c) || c.length !== 3) { console.error("gate_diff: --case wants a JSON triple"); process.exit(2); }
  addGen("case", [c]);
} else {
  for (const g of gens) {
    if (g === "exhaustive" || g === "all") addGen("exhaustive", exhaustive());
    if (g === "env-order" || g === "all") addGen("env-order", envOrder());
    if (g === "bin" || g === "all") addGen("bin", binSlice());
    if (g === "pane" || g === "all") addGen("pane", paneSlice());
    if (g === "random" || g === "all") addGen("random", randomCases(N, SEED));
  }
}
if (cases.length === 0) { console.error(`gate_diff: no cases for --gen ${gens.join(",")}`); process.exit(2); }

// ---------------------------------------------------------------------------------------------
// The two real functions
// ---------------------------------------------------------------------------------------------
function tsEnv(c: Case): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  if (c[0] !== null) env.HERDR_ENV = c[0];
  if (c[1] !== null) env.HERDR_BIN_PATH = c[1];
  if (c[2] !== null) env.HERDR_PANE_ID = c[2];
  return env;
}
const tsOut = cases.map((c) => readHerdrEnvironment(tsEnv(c)));

const casesFile = path.join(scratch, "cases.jsonl");
fs.writeFileSync(casesFile, cases.map((c) => JSON.stringify(c)).join("\n") + "\n");
const ail = spawnSync(
  "ailang",
  ["run", "--relax-modules", "--caps", "IO,FS,Env", "--entry", "main", path.join(here, "gate_ail.ail"), "--", casesFile],
  { cwd: tree, encoding: "utf8", maxBuffer: 1 << 30 },
);
if (ail.status !== 0) {
  console.error(`gate_diff: ailang exited ${ail.status}\n${ail.stderr}`);
  process.exit(2);
}
const ailOut: (boolean | undefined)[] = new Array(cases.length);
let transport = 0;
for (const line of ail.stdout.split("\n")) {
  // dotAll: the echo is JSON, and AILANG's encoder writes U+2028/U+2029 raw, which `.` would not match.
  const m = /^(\d+)\|([01E])\|(.*)$/s.exec(line);
  if (!m) continue;
  const i = Number(m[1]);
  if (m[2] === "E") { transport++; console.error(`  AILANG could not read case ${i}: ${m[3]}`); continue; }
  const want = cases[i].map((x) => x ?? "");
  const got = JSON.parse(m[3]) as string[];
  if (JSON.stringify(got) !== JSON.stringify(want)) {
    transport++;
    if (transport <= 5) console.error(`  TRANSPORT case ${i}: sent ${JSON.stringify(want)} received ${m[3]}`);
    continue;
  }
  ailOut[i] = m[2] === "1";
}
let missing = 0; // a counted loop: reduce() would skip the holes it is meant to count
for (let i = 0; i < cases.length; i++) if (ailOut[i] === undefined) missing++;
if (transport > 0 || missing > 0) {
  console.error(`gate_diff: ${transport} transport errors, ${missing} cases with no AILANG verdict`);
  process.exit(2);
}

// ---------------------------------------------------------------------------------------------
// P1.1, and attribution against the documented intent
// ---------------------------------------------------------------------------------------------
const intent = (c: Case) => c[0] === "1" && !!c[1] && !!c[2];
const show = (c: Case) =>
  `HERDR_ENV=${JSON.stringify(c[0])} HERDR_BIN_PATH=${JSON.stringify(c[1])} HERDR_PANE_ID=${JSON.stringify(c[2])}`;
const classify = (c: Case, ts: boolean, ai: boolean): string => {
  if (ai && !ts && c[0] !== "1") return "ail-accepts-HERDR_ENV-not-1";
  if (ts && !ai && c[1] === "") return "ts-accepts-empty-HERDR_BIN_PATH";
  return "unclassified";
};

let mismatches = 0;
const byClass: Record<string, number> = {};
const firstOf: Record<string, string> = {};
const tsVsIntent = { agree: 0, differ: 0 };
const aiVsIntent = { agree: 0, differ: 0 };
const lines: string[] = [];
cases.forEach((c, i) => {
  const ts = tsOut[i] !== null;
  const ai = ailOut[i] as boolean;
  const want = intent(c);
  if (ts === want) tsVsIntent.agree++; else tsVsIntent.differ++;
  if (ai === want) aiVsIntent.agree++; else aiVsIntent.differ++;
  if (ts !== ai) {
    mismatches++;
    const k = classify(c, ts, ai);
    byClass[k] = (byClass[k] ?? 0) + 1;
    firstOf[k] ??= show(c);
    lines.push(`${JSON.stringify(c)}\tts=${ts ? "non-null" : "null"}\tail=${ai}\tintent=${want}\t${k}`);
  }
});
fs.writeFileSync(path.join(scratch, "mismatches.tsv"), lines.join("\n") + (lines.length ? "\n" : ""));

const genText = Object.entries(genCounts).map(([k, v]) => `${k}=${v}`).join(" ");
console.log(`P1.1: ${cases.length} cases (${genText}), ${mismatches} mismatches`);
for (const [k, v] of Object.entries(byClass)) console.log(`  ${k}: ${v}   e.g. ${firstOf[k]}`);
console.log(`  against the documented intent: TS differs on ${tsVsIntent.differ}, AILANG differs on ${aiVsIntent.differ}`);
if (!quiet && single === undefined) console.log(`  mismatch list: ${path.join(scratch, "mismatches.tsv")}`);
if (single !== undefined) {
  const c = cases[0];
  console.log(`  ${show(c)}: readHerdrEnvironment -> ${JSON.stringify(tsOut[0])}, herdr_env_ready -> ${ailOut[0]}`);
}
process.exit(mismatches > 0 ? 1 : 0);
