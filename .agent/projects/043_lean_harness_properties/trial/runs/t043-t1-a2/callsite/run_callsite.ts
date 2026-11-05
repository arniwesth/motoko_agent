// run_callsite.ts — the gate at its REAL call sites, under real process environments.
//
//   bun run_callsite.ts <tree root> [--prop X-1|X-2|all] [--class NAME|all] [--grid full|small]
//
// For every environment in the grid below (each of HERDR_ENV, HERDR_BIN_PATH, HERDR_PANE_ID
// unset or one of a few strings; HERDR_ORCHESTRATOR=off so no run file is read; every other
// variable stripped, PATH and HOME kept):
//
//   TS     `bun ts_side.ts` under that environment: readHerdrEnvironment(process.env), and the
//          HERDR_* entries the real buildChildEnv forwards to the runtime child.
//   DIRECT `ailang run register_gate.ail` under the SAME environment: the real
//          register_with_config, which reads the variables through std/env.
//   E2E    the same AILANG program under the environment buildChildEnv produced (its HERDR_*
//          entries, plus PATH and HOME): what the runtime grandchild of a herdr pane decides.
//
// X-1 (call-site twins): TS gate open  <=>  DIRECT advertises tools.
// X-2 (end to end):      TS gate open  <=>  E2E advertises tools.
//
// Disagreements are classified by the environment:
//   ENV_GT_1   HERDR_ENV set, not "1", and the AILANG side opened
//   BIN_UNSET  HERDR_BIN_PATH unset (or not forwarded), TS closed, AILANG opened
//   BIN_EMPTY  HERDR_BIN_PATH="" in the environment AILANG saw, TS open, AILANG closed
//   PANE_DROP  HERDR_PANE_ID set non-empty in the TUI, not forwarded, TS open, AILANG closed
//   BIN_DROP   HERDR_BIN_PATH set in the TUI, not forwarded, TS open, AILANG closed (latent on
//              the real code: register.ail's "herdr" default opens the gate instead; it shows
//              once that default is removed)
//   OTHER      anything else
// Exit 1 when the selected property has a disagreement in the selected class, else 0; 2 when
// a half could not run (no verdict).
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, copyFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join, dirname } from "node:path";

const args = process.argv.slice(2);
const root = args[0] && !args[0].startsWith("--") ? resolve(args[0]) : process.cwd();
const opt = (k: string, d: string) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const prop = opt("--prop", "all");
const cls = opt("--class", "all");
const here = dirname(new URL(import.meta.url).pathname);
const BASE = { PATH: process.env.PATH ?? "", HOME: process.env.HOME ?? "" };

// The AILANG program runs from a scratch package that depends on THIS tree's packages
// (mkpkg.sh), so a mutated copy of the tree is tested as itself.
const pkg = mkdtempSync(join(tmpdir(), "t1-callsite-"));
process.on("exit", () => rmSync(pkg, { recursive: true, force: true }));
const mk = spawnSync("bash", [join(here, "..", "mkpkg.sh"), root, pkg], { stdio: "inherit" });
if (mk.status !== 0) { console.error("mkpkg failed"); process.exit(2); }
copyFileSync(join(here, "register_gate.ail"), join(pkg, "register_gate.ail"));

type V = string | null;
// --grid full (default): 6 x 4 x 4 = 96 environments. --grid small: 3 x 3 x 3 = 27, still one
// witness of every class below, for the per-report repros (which must finish in 120 s).
const grid_ = opt("--grid", "full");
const ENVS: V[] = grid_ === "small" ? [null, "1", "2"] : [null, "", "1", "2", "1 ", "true"];
const BINS: V[] = grid_ === "small" ? [null, "", "/usr/local/bin/herdr"] : [null, "", " ", "/usr/local/bin/herdr"];
const PANES: V[] = grid_ === "small" ? [null, " ", "w1:p7"] : [null, "", " ", "w1:p7"];

function run(cmd: string, argv: string[], env: Record<string, string>, cwd = root): Promise<string> {
  return new Promise((ok, fail) => {
    const p = spawn(cmd, argv, { env, cwd, stdio: ["ignore", "pipe", "pipe"] });
    let out = "", err = "";
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", (d) => (err += d));
    p.on("close", (code) => (code === 0 ? ok(out) : fail(new Error(`${cmd} exited ${code}: ${err.slice(-400)}`))));
  });
}
const ail = async (env: Record<string, string>) => {
  const out = await run("ailang", ["run", "--relax-modules", "--caps", "Clock,Env,FS,IO,Process", "--entry", "main", "register_gate.ail"], env, pkg);
  const m = out.match(/gate=([TF])/);
  if (!m) throw new Error(`no gate line in: ${out}`);
  return m[1] === "T";
};

const grid: [V, V, V][] = [];
for (const e of ENVS) for (const b of BINS) for (const p of PANES) grid.push([e, b, p]);

async function one([e, b, p]: [V, V, V]) {
  const env: Record<string, string> = { ...BASE, HERDR_ORCHESTRATOR: "off" };
  if (e !== null) env.HERDR_ENV = e;
  if (b !== null) env.HERDR_BIN_PATH = b;
  if (p !== null) env.HERDR_PANE_ID = p;
  const ts = JSON.parse((await run("bun", [join(here, "ts_side.ts"), root], env)).trim());
  const direct = await ail(env);
  const childEnv: Record<string, string> = { ...BASE, ...ts.child };
  const e2e = await ail(childEnv);
  return { case: [e, b, p] as [V, V, V], ts: ts.gate as boolean, direct, e2e, child: ts.child as Record<string, string> };
}

function classify(c: [V, V, V], ts: boolean, a: boolean, seen: Record<string, string | undefined>): string {
  const [e, b, p] = c;
  if (!ts && a && e !== null && e !== "1") return "ENV_GT_1";
  if (!ts && a && seen.HERDR_BIN_PATH === undefined) return "BIN_UNSET";
  if (ts && !a && seen.HERDR_BIN_PATH === "") return "BIN_EMPTY";
  if (ts && !a && p !== null && p !== "" && seen.HERDR_PANE_ID === undefined) return "PANE_DROP";
  if (ts && !a && b !== null && seen.HERDR_BIN_PATH === undefined) return "BIN_DROP";
  return "OTHER";
}

// One sequential run first: ailang caches the compiled modules in <pkg>/.ailang, and eight
// cold runs in parallel would each compile everything (measured on the full grid: ~100 s
// instead of ~40 s).
try { await ail({ ...BASE, HERDR_ORCHESTRATOR: "off" }); } catch (err) { console.error(String(err)); process.exit(2); }

const results: Awaited<ReturnType<typeof one>>[] = [];
const queue = [...grid];
try {
  await Promise.all(Array.from({ length: 8 }, async () => {
    for (let c = queue.shift(); c; c = queue.shift()) results.push(await one(c));
  }));
} catch (err) {
  console.error(String(err));
  process.exit(2);
}

let fail = false;
for (const [name, pick] of [["X-1", "direct"], ["X-2", "e2e"]] as const) {
  if (prop !== "all" && prop !== name) continue;
  const counts = new Map<string, string[]>();
  for (const r of results) {
    const a = r[pick];
    if (a === r.ts) continue;
    const seen = pick === "direct"
      ? { HERDR_BIN_PATH: r.case[1] ?? undefined, HERDR_PANE_ID: r.case[2] ?? undefined }
      : { HERDR_BIN_PATH: r.child.HERDR_BIN_PATH, HERDR_PANE_ID: r.child.HERDR_PANE_ID };
    const k = classify(r.case, r.ts, a, seen);
    const list = counts.get(k) ?? [];
    list.push(`${JSON.stringify(r.case)} ts=${r.ts ? "T" : "F"} ail=${a ? "T" : "F"}`);
    counts.set(k, list);
    if (cls === "all" || cls === k) fail = true;
  }
  const n = [...counts.values()].reduce((s, l) => s + l.length, 0);
  console.log(`${name}: ${results.length} environments, ${n} disagree`);
  for (const [k, l] of [...counts].sort()) {
    console.log(`  ${k}: ${l.length}`);
    for (const x of l.slice(0, 6)) console.log(`      ${x}`);
  }
}
process.exit(fail ? 1 : 0);
