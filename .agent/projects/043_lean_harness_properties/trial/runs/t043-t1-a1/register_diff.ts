// register_diff.ts — the gate end to end, X-1 and X-2 (stated in SUMMARY.md).
//
// The comment at herdr-agent-state.ts:145-155 says the two copies "MUST MOVE TOGETHER" and that the
// AILANG copy sees the variables only through `buildChildEnv`. P1.1 compares the two functions with
// unset passed as "". This harness compares what actually happens to one pane environment E:
//
//   TUI side:  readHerdrEnvironment(E) !== null                       (the REAL function, on E)
//   runtime:   register_with_config advertises tools                  (the REAL extension entry
//              point, run by `ailang` in a process whose environment is exactly the REAL
//              buildChildEnv(...) computed with process.env = E)
//
//   X-2:  for every E, the two sides agree.
//   X-1:  the same, but the runtime process gets E's three variables directly (no buildChildEnv),
//         so only register.ail's own reading of the environment stands between E and the gate.
//
//   bun register_diff.ts [--mode x1|x2|both] [--case JSON] [--scratch DIR]
//
// Run from the tree root. Every case is one `ailang` process (~0.1 s). Exit 0: no disagreement in
// the modes run. Exit 1: at least one. Exit 2: the harness could not run.

import { spawnSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

type V = string | null;
type Case = [V, V, V];
const KEYS = ["HERDR_ENV", "HERDR_BIN_PATH", "HERDR_PANE_ID"] as const;

const here = import.meta.dir;
const tree = process.cwd();
const argv = process.argv.slice(2);
const opt = (n: string) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : undefined; };
const mode = opt("--mode") ?? "both";
const single = opt("--case");
const scratch = opt("--scratch") ?? fs.mkdtempSync(path.join(os.tmpdir(), "t043-register-"));
const workdir = path.join(scratch, "workdir");
fs.mkdirSync(workdir, { recursive: true });

const statePath = path.join(tree, "src/tui/src/herdr-agent-state.ts");
const rpPath = path.join(tree, "src/tui/src/runtime-process.ts");
const wantX2 = mode === "both" || mode === "x2";
if (!fs.existsSync(statePath) || (wantX2 && !fs.existsSync(rpPath))) {
  console.error("register_diff: run from the tree root");
  process.exit(2);
}

// Sandbox process.env BEFORE loading the modules, so nothing from the session leaks into the cases.
const BASE: Record<string, string> = {
  PATH: process.env.PATH ?? "/usr/bin:/bin",
  HOME: process.env.HOME ?? workdir,
  // A HERDR_ variable, so buildChildEnv forwards it: keeps register_with_config from scanning a
  // dagr directory. It does not enter the gate.
  HERDR_ORCHESTRATOR: "off",
  MOTOKO_WORKDIR: workdir,
};
function setProcessEnv(c: Case) {
  for (const k of Object.keys(process.env)) delete process.env[k];
  Object.assign(process.env, BASE);
  KEYS.forEach((k, i) => { if (c[i] !== null) process.env[k] = c[i] as string; });
}
setProcessEnv([null, null, null]);

const { readHerdrEnvironment } = (await import(statePath)) as {
  readHerdrEnvironment: (env: NodeJS.ProcessEnv) => unknown;
};
// Loaded only when X-2 runs, so X-1 needs nothing from the tree but herdr-agent-state.ts and the
// AILANG package.
type BuildChildEnv = (workdir: string, profile: string, openaiBaseUrl: string, aiOptionsJson: string) => NodeJS.ProcessEnv;
const buildChildEnv: BuildChildEnv | null = wantX2
  ? ((await import(rpPath)) as { buildChildEnv: BuildChildEnv }).buildChildEnv
  : null;

const VALUES: V[] = [null, "", " ", "1", "2", "true", "/usr/local/bin/herdr", "w1:p7"];
let cases: Case[] = [];
if (single !== undefined) {
  cases = [JSON.parse(single) as Case];
} else {
  for (const e of VALUES) for (const b of VALUES) for (const p of VALUES) cases.push([e, b, p]);
}

function runExtension(env: Record<string, string>): boolean {
  const r = spawnSync(
    "ailang",
    ["run", "--relax-modules", "--caps", "Clock,Env,FS,IO,Process", "--entry", "main", path.join(here, "register_ail.ail")],
    { cwd: tree, env, encoding: "utf8" },
  );
  const m = /gate=(open|closed) tools=(\d+)/.exec(r.stdout ?? "");
  if (r.status !== 0 || !m) {
    console.error(`register_diff: ailang exited ${r.status}\n${r.stdout}\n${r.stderr}`);
    process.exit(2);
  }
  return m[1] === "open";
}
const clean = (e: NodeJS.ProcessEnv) => {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(e)) if (v !== undefined) out[k] = v;
  return out;
};
const show = (c: Case) => KEYS.map((k, i) => `${k}=${c[i] === null ? "<unset>" : JSON.stringify(c[i])}`).join(" ");

const results: Record<string, { n: number; bad: number; lines: string[] }> = {};
for (const m of mode === "both" ? ["x1", "x2"] : [mode]) results[m] = { n: 0, bad: 0, lines: [] };

for (const c of cases) {
  setProcessEnv(c);
  const ts = readHerdrEnvironment(process.env) !== null;
  if (results.x1) {
    const env = clean({ ...BASE, ...Object.fromEntries(KEYS.flatMap((k, i) => (c[i] === null ? [] : [[k, c[i]]]))) });
    const ext = runExtension(env);
    results.x1.n++;
    if (ext !== ts) { results.x1.bad++; results.x1.lines.push(`${show(c)}  TUI=${ts ? "reports" : "inert"} extension=${ext ? "open" : "closed"}`); }
  }
  if (results.x2) {
    const child = clean(buildChildEnv!(workdir, "default", "", ""));
    const seen = KEYS.map((k) => (k in child ? JSON.stringify(child[k]) : "<unset>")).join(",");
    const ext = runExtension(child);
    results.x2.n++;
    if (ext !== ts) { results.x2.bad++; results.x2.lines.push(`${show(c)}  child sees [${seen}]  TUI=${ts ? "reports" : "inert"} extension=${ext ? "open" : "closed"}`); }
  }
}

let any = false;
for (const [m, r] of Object.entries(results)) {
  console.log(`${m.toUpperCase()}: ${r.n} environments, ${r.bad} where the TUI gate and the extension's gate disagree`);
  for (const l of r.lines.slice(0, single !== undefined ? 1 : 40)) console.log(`  ${l}`);
  if (r.lines.length > 40 && single === undefined) console.log(`  ... ${r.lines.length - 40} more`);
  fs.writeFileSync(path.join(scratch, `${m}.disagree.txt`), r.lines.join("\n") + "\n");
  if (r.bad > 0) any = true;
}
process.exit(any ? 1 : 0);
