// check.ts — executable statements of P6.1-P6.3, and the twin comparisons, over the outputs
// of the two AILANG harnesses and of the TypeScript twin, on the same cases.
//
//   bun check.ts <prefix> <tree root>
//
// reads <prefix>.cases, <prefix>.tags (gen_cases.ts), <prefix>.direct (direct.sh),
// <prefix>.store (via_store.ail). Prints counts per check and generator, and the shortest
// witnesses of each violation class. Exit 1 if any registered primary property (P6.1, P6.2)
// fails on the AILANG function; P6.3 (known violated, K2) is counted and reported but does
// not set the exit code by itself.
//
// Properties, as executed here (b = input bytes, r = result bytes, n = max_bytes):
//   P6.1   n >= 0  =>  |r| <= n
//   P6.2a  r is a prefix of b
//   P6.2b  |b| <= n  =>  r == b
//   P6.3   b valid UTF-8  =>  r valid UTF-8          (strict decoder, BOM kept)
// Twin and route checks (exploratory, see SUMMARY.md):
//   X-route  via store_stdout_and_elide: truncated == (|b| > n); when truncated the returned
//            stdout is <clip> + "\n[stdout elided; full output at <raw_path>]" and <clip> is
//            byte-identical to the direct call; when not truncated it is b itself
//   X-twin   the TS twin `truncateUtf8ByBytes` (src/tui/src/compose-claimcheck.ts:104), reached
//            through the exported `runClaimCheck`, on valid-UTF-8 cases with n >= 1 (its
//            caller clamps n to >= 1): P6.1/P6.2/P6.3 stated on its `text`, agreement with
//            the AILANG function, and `omittedBytes == |b| - |text|` with
//            `truncated == (|b| > n)`

import { readFileSync } from "fs";
import { join, resolve } from "path";

const prefix = process.argv[2];
const tree = process.argv[3] ? resolve(process.argv[3]) : "";
if (!prefix || !tree) throw new Error("usage: bun check.ts <prefix> <tree root>");

const { runClaimCheck, createClaimCheckTelemetry } = await import(join(tree, "src/tui/src/compose-claimcheck.ts"));

const readLines = (p: string) => readFileSync(p, "utf8").split("\n").filter((l) => l !== "");
const cases = readLines(`${prefix}.cases`).map((l) => {
  const [n, b64] = l.split(",");
  return { n: Number(n), b: new Uint8Array(Buffer.from(b64, "base64")) };
});
const tags = readLines(`${prefix}.tags`);
const parse = (p: string) => {
  const m = new Map<number, string[]>();
  for (const l of readLines(p)) {
    const f = l.split("|");
    if (/^\d+$/.test(f[0])) m.set(Number(f[0]), f.slice(1));
  }
  return m;
};
const direct = parse(`${prefix}.direct`);
const store = parse(`${prefix}.store`);

const strict = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
const valid = (b: Uint8Array) => { try { strict.decode(b); return true; } catch { return false; } };
const eq = (a: Uint8Array, b: Uint8Array) => a.length === b.length && a.every((x, i) => x === b[i]);
const isPrefix = (p: Uint8Array, b: Uint8Array) => p.length <= b.length && p.every((x, i) => x === b[i]);
const hex = (b: Uint8Array) => Buffer.from(b).toString("hex");
const enc = new TextEncoder();

type Viol = { i: number; tag: string; n: number; b: Uint8Array; r: Uint8Array; extra: string };
const viols = new Map<string, Viol[]>();
const checked = new Map<string, number>();
function count(check: string) { checked.set(check, (checked.get(check) ?? 0) + 1); }
function fail(check: string, v: Viol) {
  if (!viols.has(check)) viols.set(check, []);
  viols.get(check)!.push(v);
}

let missing = 0;
for (let i = 0; i < cases.length; i++) {
  const { n, b } = cases[i];
  const tag = tags[i];
  const d = direct.get(i);
  if (!d || d[0] === "BADCASE") { missing++; continue; }
  const r = new Uint8Array(Buffer.from(d[0], "base64"));
  const strLen = Number(d[1]);
  const byteLen = Number(d[2]);
  const extra = `Str.length=${strLen} bytes=${byteLen}`;
  const v = { i, tag, n, b, r, extra };

  if (byteLen !== b.length) fail("X-harness: runtime byte length != input length", v);

  if (n >= 0) { count("P6.1"); if (r.length > n) fail("P6.1", v); }
  count("P6.2a"); if (!isPrefix(r, b)) fail("P6.2a", v);
  if (b.length <= n) { count("P6.2b"); if (!eq(r, b)) fail("P6.2b", v); }
  if (valid(b)) { count("P6.3"); if (!valid(r)) fail("P6.3", v); }

  // Characterisation of P6.1 failures by the runtime's own counts: the function compares
  // Str.length (code points) with a byte budget.
  if (n >= 0 && r.length > n) {
    count("P6.1-explained");
    if (!(strLen <= n && n < b.length && eq(r, b))) fail("P6.1-unexplained", v);
  }
  // The shape the function has when it does cut: exactly the first n bytes.
  if (n >= 0 && strLen > n) { count("cut==b[0:n]"); if (!eq(r, b.subarray(0, n))) fail("cut!=b[0:n]", v); }
  if (n < 0) { count("n<0 => empty"); if (r.length !== 0) fail("n<0 not empty", v); }

  // X-route: through store_stdout_and_elide
  const s = store.get(i);
  if (s && s[0] !== "BADCASE") {
    const truncated = s[0] === "1";
    const out = new Uint8Array(Buffer.from(s[1], "base64"));
    const rawPath = s[2];
    count("X-route");
    if (truncated !== (b.length > n)) fail("X-route: truncated flag", { ...v, extra: `truncated=${truncated}` });
    else if (truncated) {
      const suffix = enc.encode(`\n[stdout elided; full output at ${rawPath}]`);
      const clip = out.subarray(0, out.length - suffix.length);
      if (!eq(out.subarray(out.length - suffix.length), suffix)) fail("X-route: suffix", { ...v, r: out });
      else {
        if (!eq(clip, r)) fail("X-route: clip != direct", { ...v, r: clip });
        if (n >= 0) { count("P6.1 via store"); if (clip.length > n) fail("P6.1 via store", { ...v, r: clip }); }
        count("P6.2a via store"); if (!isPrefix(clip, b)) fail("P6.2a via store", { ...v, r: clip });
        if (valid(b)) { count("P6.3 via store"); if (!valid(clip)) fail("P6.3 via store", { ...v, r: clip }); }
      }
    } else if (!eq(out, b)) fail("X-route: untruncated != input", { ...v, r: out });
  } else missing++;
}

// X-twin: the TS twin in compose-claimcheck.ts, through runClaimCheck.
let twinRuns = 0;
for (let i = 0; i < cases.length; i++) {
  const { n, b } = cases[i];
  if (n < 1 || !valid(b)) continue;
  const d = direct.get(i);
  if (!d) continue;
  const ail = new Uint8Array(Buffer.from(d[0], "base64"));
  const telemetry = createClaimCheckTelemetry();
  let prompt = "";
  await runClaimCheck({
    enabled: true, intentKind: "analyze", intent: "x", certificateStdout: strict.decode(b),
    informalizerModel: "m", comparatorModel: "m", timeoutMs: 1000, maxInvocations: 1,
    stdoutMaxBytes: n, telemetry,
    callStream: async (_m: string, p: string) => { prompt = p; return { output: "", streamed: false }; },
    emitEvent: () => {}, step: 0, composeId: "c", attempt: 1,
  });
  twinRuns++;
  const cert = prompt.slice(prompt.indexOf("Certificate:\n") + "Certificate:\n".length);
  const truncated = telemetry.truncated_stdout_cases === 1;
  let text = cert, omitted = 0;
  if (truncated) {
    const m = cert.match(/\n\[truncated: (\d+) bytes omitted\]$/);
    if (!m) { fail("X-twin: marker", { i, tag: tags[i], n, b, r: enc.encode(cert), extra: "" }); continue; }
    text = cert.slice(0, cert.length - m[0].length);
    omitted = Number(m[1]);
  }
  const t = enc.encode(text);
  const v = { i, tag: tags[i], n, b, r: t, extra: `truncated=${truncated} omittedBytes=${omitted}; ailang=${hex(ail)}` };
  count("X-twin P6.1"); if (t.length > n) fail("X-twin P6.1", v);
  count("X-twin P6.2a"); if (!isPrefix(t, b)) fail("X-twin P6.2a", v);
  if (b.length <= n) { count("X-twin P6.2b"); if (!eq(t, b)) fail("X-twin P6.2b", v); }
  count("X-twin P6.3"); if (!valid(t)) fail("X-twin P6.3", v);
  count("X-twin == AILANG"); if (!eq(t, ail)) fail("X-twin == AILANG", v);
  count("X-twin flag"); if (truncated !== (b.length > n)) fail("X-twin flag", v);
  if (truncated) { count("X-twin omittedBytes"); if (omitted !== b.length - t.length) fail("X-twin omittedBytes", v); }
}

// Report
const byTag = (vs: Viol[]) => {
  const c: Record<string, number> = {};
  for (const v of vs) c[v.tag] = (c[v.tag] ?? 0) + 1;
  return JSON.stringify(c);
};
console.log(`cases: ${cases.length}; missing outputs: ${missing}; twin runs: ${twinRuns}`);
for (const [k, c] of checked) {
  const vs = viols.get(k) ?? [];
  console.log(`${vs.length === 0 ? "ok  " : "FAIL"} ${k}: ${c} checked, ${vs.length} violated ${vs.length ? byTag(vs) : ""}`);
}
for (const [k, vs] of viols) {
  if (checked.has(k)) continue;
  console.log(`FAIL ${k}: ${vs.length} ${byTag(vs)}`);
}
for (const k of ["P6.1", "P6.1 via store", "X-twin P6.1"]) {
  const vs = viols.get(k) ?? [];
  if (vs.length === 0) continue;
  const worst = vs.reduce((a, v) => (v.r.length - v.n > a.r.length - a.n ? v : a));
  const ratio = vs.filter((v) => v.n > 0).reduce((a, v) => (v.r.length / v.n > a.r.length / a.n ? v : a));
  console.log(`--- ${k}: largest overshoot |out|-n = ${worst.r.length - worst.n} (n=${worst.n}, |out|=${worst.r.length}, ${worst.tag}); largest |out|/n = ${(ratio.r.length / ratio.n).toFixed(2)} (n=${ratio.n}, |out|=${ratio.r.length}, ${ratio.tag})`);
}
for (const [k, vs] of viols) {
  const shortest = [...vs].sort((a, b) => a.b.length - b.b.length || a.n - b.n).slice(0, 3);
  console.log(`--- ${k}: shortest witnesses`);
  for (const w of shortest) console.log(`    [${w.i} ${w.tag}] n=${w.n} in=${hex(w.b)} out=${hex(w.r)} (|in|=${w.b.length} |out|=${w.r.length}) ${w.extra}`);
}
const primary = ["P6.1", "P6.2a", "P6.2b", "P6.1 via store", "P6.2a via store"].some((k) => (viols.get(k) ?? []).length > 0);
process.exit(primary || missing > 0 ? 1 : 0);
