// check.ts — executable statements of P6.1, P6.2, P6.3 (and the exploratory X-*), applied to
// the REAL truncate_utf8_by_bytes (through run_direct.sh and run_caller.sh) and to its REAL
// TypeScript twins (twins.ts), over one cases file from gen.ts.
//
//   bun check.ts <tree> <cases> [--direct <direct.out>] [--caller <caller.out>] [--twins]
//                [--runclaimcheck] [--fail-on <fn>:<prop>[,<fn>:<prop>...]]
//
// Functions (fn):
//   ail        truncate_utf8_by_bytes, store.ail, called directly (export shim)
//   ailcaller  the clipped prefix inside store_stdout_and_elide's returned stdout
//   tsclaim    compose-claimcheck.ts truncateUtf8ByBytes (by extraction)
//   tsenv      env-server.ts truncateUtf8ByBytes (by extraction)
//   tsrun      compose-claimcheck.ts truncateUtf8ByBytes through runClaimCheck (max >= 1 only:
//              the caller passes Math.max(1, stdoutMaxBytes))
//
// Properties, as executed below (in = input bytes, out = result bytes, n = max_bytes):
//   P6.1   n >= 0  =>  |out| <= n
//   P6.2a  out is a byte prefix of in
//   P6.2b  |in| <= n  =>  out == in
//   P6.3   in is valid UTF-8  =>  out is valid UTF-8
//   X-1    (ailcaller) n >= 0 and truncated == true  =>  |clipped| < |in|  (something was elided)
//   X-2    (tsclaim, tsrun) truncated  =>  omittedBytes == |in| - lcp(in, out), where lcp is
//          the longest common byte prefix: the count of input bytes the text does not carry
//   X-3    (ailcaller) consistency: ailcaller's clipped == ail's result on the same case
//   X-4    (tsclaim, tsenv, tsrun) P6.1 and P6.2a together, stated for the TS twins:
//          n >= 0  =>  |out| <= n,  and  out is a byte prefix of in
//   TWIN   (tsclaim/tsenv vs ail, valid inputs only) the two results are byte-identical
//   TWINX  (tsclaim vs ail) every TWIN disagreement is explained by exactly the two defects
//          reported: (a) ail returned the whole input although |in| > n (the rune-count gate),
//          and ts == lossy(in[0..n]); or (b) ail == in[0..n] and ts == lossy(ail), i.e. ts put
//          U+FFFD where ail kept a partial character. lossy = WHATWG UTF-8 decode with
//          replacement, re-encoded. A violation here is a disagreement neither explains.
//   TWINTS (tsclaim vs tsenv) the two TS twins agree byte for byte
//   TWINRUN (tsrun vs tsclaim, n >= 1) runClaimCheck's view of the twin (text, truncated,
//          omittedBytes) equals the extracted twin's return value: the two routes agree
//
// Prints one row per (fn, property): cases checked, violations, smallest witness. Exits 1 if
// any --fail-on pair has a violation, 2 on a harness error, else 0.

import { readFileSync } from "fs";
import { byExtraction, loadRunClaimCheck, CLAIMCHECK, ENVSERVER } from "./twins.ts";

const argv = process.argv.slice(2);
const flag = (f: string) => { const i = argv.indexOf(f); if (i < 0) return false; argv.splice(i, 1); return true; };
const opt = (f: string) => { const i = argv.indexOf(f); if (i < 0) return null; const v = argv[i + 1]; argv.splice(i, 2); return v; };
const doTwins = flag("--twins");
const doRun = flag("--runclaimcheck");
const failOn = (opt("--fail-on") ?? "").split(",").filter(Boolean);
const directPath = opt("--direct");
const callerPath = opt("--caller");
const [tree, casesPath] = argv;
if (!tree || !casesPath || argv.length !== 2) { console.error("usage: see header"); process.exit(2); }

const parseCsv = (s: string) => (s === "" ? [] : s.split(",").map(Number));
const cases = readFileSync(casesPath, "utf8").split("\n").filter((l) => l !== "").map((l) => {
  const [csv, m] = l.split("|");
  return { inB: Uint8Array.from(parseCsv(csv)), n: Number(m), key: `${csv}|${m}` };
});

function harnessError(msg: string): never { console.error("HARNESS ERROR: " + msg); process.exit(2); }

const direct = directPath ? readFileSync(directPath, "utf8").split("\n").filter((l) => l !== "") : [];
if (directPath && direct.length !== cases.length) harnessError(`direct output has ${direct.length} lines, cases ${cases.length}`);

const strict = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
const enc = new TextEncoder();
const valid = (b: Uint8Array) => { try { strict.decode(b); return true; } catch { return false; } };
const eq = (a: Uint8Array, b: Uint8Array) => a.length === b.length && a.every((x, i) => x === b[i]);
const isPrefix = (p: Uint8Array, w: Uint8Array) => p.length <= w.length && p.every((x, i) => x === w[i]);
const lcp = (a: Uint8Array, b: Uint8Array) => { let i = 0; while (i < a.length && i < b.length && a[i] === b[i]) i++; return i; };
const hex = (b: Uint8Array) => {
  const h = (xs: Uint8Array) => Array.from(xs, (x) => x.toString(16).padStart(2, "0")).join(" ");
  return b.length <= 24 ? h(b) : `${h(b.subarray(0, 9))} ... ${h(b.subarray(b.length - 6))} <${b.length} bytes>`;
};

type Row = { checked: number; bad: number; witness: string | null; wsize: number };
const rows = new Map<string, Row>();
function record(fn: string, prop: string, applies: boolean, ok: boolean, inB: Uint8Array, n: number, detail: () => string) {
  if (!applies) return;
  const k = `${fn}:${prop}`;
  const r = rows.get(k) ?? { checked: 0, bad: 0, witness: null, wsize: Infinity };
  r.checked++;
  if (!ok) {
    r.bad++;
    const size = inB.length * 1000 + Math.max(n, 0);
    if (size < r.wsize) { r.wsize = size; r.witness = `in=[${hex(inB)}] n=${n} ${detail()}`; }
  }
  rows.set(k, r);
}

function checkCore(fn: string, inB: Uint8Array, n: number, out: Uint8Array) {
  const d = () => `out=[${hex(out)}] (${out.length} B)`;
  if (fn.startsWith("ts")) record(fn, "X-4", true, (n < 0 || out.length <= n) && isPrefix(out, inB), inB, n, d);
  record(fn, "P6.1", n >= 0, out.length <= n, inB, n, d);
  record(fn, "P6.2a", true, isPrefix(out, inB), inB, n, d);
  record(fn, "P6.2b", inB.length <= n, eq(out, inB), inB, n, d);
  record(fn, "P6.3", valid(inB), valid(out), inB, n, d);
}

// 1. The real AILANG function, directly.
const ailOut: Uint8Array[] = [];
direct.forEach((line, i) => {
  const [csv, m, outCsv] = line.split("|");
  if (`${csv}|${m}` !== cases[i].key) harnessError(`direct line ${i + 1} is for ${csv}|${m}, expected ${cases[i].key}`);
  const out = Uint8Array.from(parseCsv(outCsv));
  ailOut.push(out);
  checkCore("ail", cases[i].inB, cases[i].n, out);
});

// 2. The real AILANG caller.
if (callerPath) {
  if (!directPath) harnessError("--caller needs --direct (X-3 compares them)");
  const caller = readFileSync(callerPath, "utf8").split("\n").filter((l) => l !== "");
  if (caller.length !== cases.length) harnessError(`caller output has ${caller.length} lines, cases ${cases.length}`);
  const notice = enc.encode("\n[stdout elided; full output at /t6w/.motoko-store/compose/t6.stdout]");
  caller.forEach((line, i) => {
    const [csv, m, tr, outCsv] = line.split("|");
    if (`${csv}|${m}` !== cases[i].key) harnessError(`caller line ${i + 1} is for ${csv}|${m}`);
    const { inB, n } = cases[i];
    const ret = Uint8Array.from(parseCsv(outCsv));
    if (tr === "false") {
      // Not truncated: the caller returns stdout unchanged, and only does so when it fits.
      record("ailcaller", "P6.2b", inB.length <= n, eq(ret, inB), inB, n, () => `returned=[${hex(ret)}]`);
      record("ailcaller", "P6.1", n >= 0, ret.length <= n, inB, n, () => `returned unclipped=[${hex(ret)}]`);
      return;
    }
    const tail = ret.subarray(ret.length - notice.length);
    if (ret.length < notice.length || !eq(tail, notice)) harnessError(`caller line ${i + 1}: truncated without the notice`);
    const clipped = ret.subarray(0, ret.length - notice.length);
    const d = () => `clipped=[${hex(clipped)}] (${clipped.length} B), truncated=true`;
    record("ailcaller", "P6.1", n >= 0, clipped.length <= n, inB, n, d);
    record("ailcaller", "P6.2a", true, isPrefix(clipped, inB), inB, n, d);
    record("ailcaller", "P6.3", valid(inB), valid(clipped), inB, n, d);
    record("ailcaller", "X-1", n >= 0, clipped.length < inB.length, inB, n, d);
    record("ailcaller", "X-3", true, eq(clipped, ailOut[i]), inB, n, () => `${d()} ail=[${hex(ailOut[i])}]`);
  });
}

// 3. The real TypeScript twins, on the inputs a JS string can hold (valid UTF-8).
if (doTwins || doRun) {
  const tsclaim = byExtraction(tree, CLAIMCHECK) as (s: string, n: number) => { text: string; truncated: boolean; omittedBytes: number };
  const tsenv = byExtraction(tree, ENVSERVER) as (s: string, n: number) => string;
  const run = doRun ? await loadRunClaimCheck(tree) : null;
  for (let i = 0; i < cases.length; i++) {
    const { inB, n } = cases[i];
    if (!valid(inB)) continue;
    const s = strict.decode(inB);
    let a: { text: string; truncated: boolean; omittedBytes: number } | null = null;
    if (doTwins) {
      a = tsclaim(s, n);
      const aB = enc.encode(a.text);
      checkCore("tsclaim", inB, n, aB);
      record("tsclaim", "X-2", a.truncated, a.omittedBytes === inB.length - lcp(inB, aB), inB, n,
        () => `text=[${hex(aB)}] omittedBytes=${a.omittedBytes}, expected ${inB.length - lcp(inB, aB)}`);
      if (directPath) record("tsclaim", "TWIN", true, eq(aB, ailOut[i]), inB, n, () => `ts=[${hex(aB)}] ail=[${hex(ailOut[i])}]`);
      if (directPath && !eq(aB, ailOut[i])) {
        const lossy = (x: Uint8Array) => enc.encode(new TextDecoder("utf-8", { ignoreBOM: true }).decode(x));
        const cut = inB.subarray(0, Math.max(0, n));
        const a1 = eq(ailOut[i], inB) && inB.length > n && eq(aB, lossy(cut));
        const b1 = eq(ailOut[i], cut) && eq(aB, lossy(ailOut[i]));
        record("tsclaim", "TWINX", true, a1 || b1, inB, n, () => `ts=[${hex(aB)}] ail=[${hex(ailOut[i])}] unexplained`);
      }
      const b = enc.encode(tsenv(s, n));
      record("tsenv", "TWINTS", true, eq(aB, b), inB, n, () => `tsclaim=[${hex(aB)}] tsenv=[${hex(b)}]`);
      checkCore("tsenv", inB, n, b);
      if (directPath) record("tsenv", "TWIN", true, eq(b, ailOut[i]), inB, n, () => `ts=[${hex(b)}] ail=[${hex(ailOut[i])}]`);
    }
    if (run && n >= 1) {
      const r = await run(s, n);
      const rB = enc.encode(r.text);
      if (a) record("tsrun", "TWINRUN", true, r.text === a.text && r.truncated === a.truncated && r.omittedBytes === a.omittedBytes,
        inB, n, () => `run=${JSON.stringify(r)} twin=${JSON.stringify(a)}`);
      checkCore("tsrun", inB, n, rB);
      record("tsrun", "X-2", r.truncated, r.omittedBytes === inB.length - lcp(inB, rB), inB, n,
        () => `text=[${hex(rB)}] omittedBytes=${r.omittedBytes}, expected ${inB.length - lcp(inB, rB)}`);
    }
  }
}

console.log(`cases: ${cases.length} (${casesPath})`);
console.log(["fn:property".padEnd(18), "checked".padStart(8), "violations".padStart(11), "  smallest witness"].join(""));
let fail = false;
for (const [k, r] of [...rows.entries()].sort()) {
  console.log([k.padEnd(18), String(r.checked).padStart(8), String(r.bad).padStart(11), "  " + (r.witness ?? "-")].join(""));
  if (failOn.includes(k) && r.bad > 0) fail = true;
}
for (const k of failOn) if (!rows.has(k)) harnessError(`--fail-on ${k}: no case exercised it`);
process.exit(fail ? 1 : 0);
