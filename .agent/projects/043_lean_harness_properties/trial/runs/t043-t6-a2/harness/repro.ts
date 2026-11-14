// repro.ts — one witness, one property, on the real code. Exit 1 when the property is
// violated (the defect is present), 0 when it holds, 2 when the harness itself fails.
// Run from the tree root.
//
//   bun <out>/harness/repro.ts <check> <max_bytes> <witness>
//
// <witness> is hex bytes, optionally `<hex>*<count>` for repetition, and pieces joined
// with `+` (e.g. `61*3999+f09f9880`).
//
// <check>:
//   P6.1   n >= 0 => |r| <= n        on the AILANG function, through BOTH routes: the direct
//                                    call (direct.sh) and the exported store_stdout_and_elide
//                                    (via_store.ail); violated if either route violates it
//   P6.2   r is a prefix of b, and |b| <= n => r == b, both routes
//   P6.3   b valid UTF-8 => r valid UTF-8, both routes
//   X-1    the TS twin truncateUtf8ByBytes (src/tui/src/compose-claimcheck.ts:104), through the
//          exported runClaimCheck: its text is a byte prefix of b of at most n bytes
//   X-2    store_stdout_and_elide with ports whose dir_make and file_write both answer
//          ok=false: violated if the result still points at raw_path as holding the full
//          output, with nothing in the result reporting the failed write (store_write.ail)
//
// Environment: T6_MUTANT=<name> is passed to direct.sh (negative controls, see SUMMARY.md);
// it does not affect the store route or the TS twin.

import { spawnSync } from "child_process";
import { mkdtempSync, writeFileSync, rmSync } from "fs";
import { tmpdir } from "os";
import { join, dirname, resolve } from "path";

const [check, nArg, witness] = process.argv.slice(2);
if (!check || nArg === undefined || witness === undefined) {
  console.error("usage: bun repro.ts <P6.1|P6.2|P6.3|X-1|X-2> <max_bytes> <witness hex>");
  process.exit(2);
}
const here = dirname(new URL(import.meta.url).pathname);
const tree = resolve(".");
const n = Number(nArg);

function parseWitness(w: string): Uint8Array {
  if (w === "" || w === "-") return new Uint8Array();
  const parts = w.split("+").map((p) => {
    const [h, c] = p.split("*");
    const one = Buffer.from(h, "hex");
    if (one.toString("hex") !== h.toLowerCase()) throw new Error(`bad hex: ${h}`);
    return Buffer.concat(Array(Number(c ?? 1)).fill(one));
  });
  return new Uint8Array(Buffer.concat(parts));
}
const b = parseWitness(witness);
const hexs = (x: Uint8Array) => (x.length > 40 ? `${Buffer.from(x.subarray(0, 20)).toString("hex")}…(${x.length} bytes)` : Buffer.from(x).toString("hex") || "(empty)");
const strict = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
const valid = (x: Uint8Array) => { try { strict.decode(x); return true; } catch { return false; } };
const eq = (x: Uint8Array, y: Uint8Array) => x.length === y.length && x.every((v, i) => v === y[i]);
const isPrefix = (p: Uint8Array, x: Uint8Array) => p.length <= x.length && p.every((v, i) => v === x[i]);

const tmp = mkdtempSync(join(tmpdir(), "t6-repro-"));
const cases = join(tmp, "w.cases");
writeFileSync(cases, `${n},${Buffer.from(b).toString("base64")}\n`);

function run(cmd: string, args: string[]): string {
  const r = spawnSync(cmd, args, { cwd: tree, encoding: "utf8", maxBuffer: 1 << 26, env: process.env });
  if (r.status !== 0) { console.error(`harness failed: ${cmd} ${args.join(" ")}\n${r.stderr}`); rmSync(tmp, { recursive: true, force: true }); process.exit(2); }
  return r.stdout;
}
function firstLine(out: string): string[] {
  const l = out.split("\n").find((x) => /^0\|/.test(x));
  if (!l) { console.error(`no result line in:\n${out}`); process.exit(2); }
  return l.split("|").slice(1);
}

function viaDirect(): Uint8Array {
  const f = firstLine(run(join(here, "direct.sh"), [cases]));
  return new Uint8Array(Buffer.from(f[0], "base64"));
}
function viaStore(): { truncated: boolean; clip: Uint8Array } {
  const f = firstLine(run("ailang", ["run", "--relax-modules", "--caps", "IO,FS", "--entry", "main", "--args-json", JSON.stringify(cases), join(here, "via_store.ail")]));
  const out = new Uint8Array(Buffer.from(f[1], "base64"));
  if (f[0] !== "1") return { truncated: false, clip: out };
  const suffix = new TextEncoder().encode(`\n[stdout elided; full output at ${f[2]}]`);
  if (!eq(out.subarray(out.length - suffix.length), suffix)) { console.error("store route: unexpected suffix"); process.exit(2); }
  return { truncated: true, clip: out.subarray(0, out.length - suffix.length) };
}

let violated = false;
const say = (route: string, ok: boolean, msg: string) => { console.log(`${ok ? "holds   " : "VIOLATED"} ${check} [${route}] ${msg}`); if (!ok) violated = true; };

if (check === "P6.1" || check === "P6.2" || check === "P6.3") {
  const d = viaDirect();
  // The store route calls the function only when |b| > n; otherwise the function is not
  // reached on that route and only the direct route says anything. It always loads the
  // tree's package, so under T6_MUTANT (which only rewrites direct.sh's copy) it is skipped.
  const routes: [string, Uint8Array][] = [["direct", d]];
  if (process.env.T6_MUTANT) console.log(`(T6_MUTANT=${process.env.T6_MUTANT}: store route skipped, it cannot see the mutant)`);
  else {
    const s = viaStore();
    if (s.truncated) routes.push(["store_stdout_and_elide", s.clip]);
    else console.log(`(store route: |b|=${b.length} <= n=${n}, so store_stdout_and_elide does not call the function)`);
  }
  for (const [route, r] of routes) {
    const desc = `n=${n} in=${hexs(b)} out=${hexs(r)} |in|=${b.length} |out|=${r.length}`;
    if (check === "P6.1") say(route, n < 0 || r.length <= n, desc);
    if (check === "P6.2") say(route, isPrefix(r, b) && (b.length > n || eq(r, b)), desc);
    if (check === "P6.3") {
      if (!valid(b)) { console.error("P6.3 needs a valid UTF-8 witness"); process.exit(2); }
      say(route, valid(r), `${desc} out valid UTF-8: ${valid(r)}`);
    }
  }
} else if (check === "X-1") {
  if (!valid(b) || n < 1) { console.error("X-1 needs a valid UTF-8 witness and n >= 1 (the caller clamps n to >= 1)"); process.exit(2); }
  const { runClaimCheck, createClaimCheckTelemetry } = await import(join(tree, "src/tui/src/compose-claimcheck.ts"));
  const telemetry = createClaimCheckTelemetry();
  let prompt = "";
  await runClaimCheck({
    enabled: true, intentKind: "analyze", intent: "x", certificateStdout: strict.decode(b),
    informalizerModel: "m", comparatorModel: "m", timeoutMs: 1000, maxInvocations: 1,
    stdoutMaxBytes: n, telemetry,
    callStream: async (_m: string, p: string) => { prompt = p; return { output: "", streamed: false }; },
    emitEvent: () => {}, step: 0, composeId: "c", attempt: 1,
  });
  let cert = prompt.slice(prompt.indexOf("Certificate:\n") + "Certificate:\n".length);
  let omitted = "n/a";
  const m = cert.match(/\n\[truncated: (\d+) bytes omitted\]$/);
  if (telemetry.truncated_stdout_cases === 1 && m) { cert = cert.slice(0, cert.length - m[0].length); omitted = m[1]; }
  const t = new TextEncoder().encode(cert);
  say("ts twin via runClaimCheck", t.length <= n && isPrefix(t, b),
    `n=${n} in=${hexs(b)} text=${hexs(t)} |in|=${b.length} |text|=${t.length} prefix=${isPrefix(t, b)} omittedBytes=${omitted}`);
} else if (check === "X-2") {
  const f = firstLine(run("ailang", ["run", "--relax-modules", "--caps", "IO,FS", "--entry", "main", "--args-json", JSON.stringify(cases), join(here, "store_write.ail")]));
  // f = [writes_attempted_ok, truncated, stdout b64, raw_path]
  const out = Buffer.from(f[2], "base64").toString("utf8");
  const points = f[1] === "1" && out.includes(`full output at ${f[3]}`);
  say("store_stdout_and_elide, failing ports", !(f[0] === "0" && points),
    `ports answered ok=${f[0] === "1"}; truncated=${f[1]}; result points at ${f[3]}: ${points}; the result type has no field for the failure`);
} else {
  console.error(`unknown check ${check}`); process.exit(2);
}
rmSync(tmp, { recursive: true, force: true });
process.exit(violated ? 1 : 0);
