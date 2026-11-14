// diff/enumerate_e2e.ts — step (2) for section 4 of ../HerdrGateModel.lean (X-1): the REAL path
// between the two copies, over every triple of E2E below.
//
//   bun enumerate_e2e.ts <repo root> <scratch workdir>
//
// For each TUI environment (HERDR_ENV, HERDR_BIN_PATH, HERDR_PANE_ID, each unset or a string):
//   1. every ambient HERDR_* is deleted from this process's env, and the three are set;
//   2. the REAL readHerdrEnvironment(process.env) is the TUI copy;
//   3. the REAL buildChildEnv(...) gives the runtime's environment; its HERDR_* entries are kept;
//   4. the REAL register_with_config runs in `ailang` (register_gate.ail) with exactly those
//      entries plus PATH, HOME, MOTOKO_WORKDIR and HERDR_ORCHESTRATOR=off; tools advertised = open.
// Prints `<i>,<j>,<k>|<null | obj:P?:B?>|<fe>,<fb>,<fp>|<true|false>`, where fX is the E2E index
// of the forwarded value (`-` when buildChildEnv dropped it, `?` when it changed it).

const [repo, workdir] = process.argv.slice(2);
if (!repo || !workdir) throw new Error("usage: bun enumerate_e2e.ts <repo root> <scratch workdir>");
const here = import.meta.dir;

// Same values, same order, as `e2eAlphabet` in enumerate_e2e.lean.tail.
const E2E: (string | null)[] = [null, "", " ", " ", "1", "2", "w1:p7", "1 "];
const NAMES = ["HERDR_ENV", "HERDR_BIN_PATH", "HERDR_PANE_ID"] as const;

const { readHerdrEnvironment } = await import(`${repo}/src/tui/src/herdr-agent-state.ts`);
const { buildChildEnv } = await import(`${repo}/src/tui/src/runtime-process.ts`);

for (const k of Object.keys(process.env)) if (k.startsWith("HERDR_")) delete process.env[k];

type Job = { key: string; ts: string; fwd: string; env: Record<string, string> };
const jobs: Job[] = [];
for (let i = 0; i < E2E.length; i++)
  for (let j = 0; j < E2E.length; j++)
    for (let k = 0; k < E2E.length; k++) {
      const vals = [E2E[i], E2E[j], E2E[k]];
      NAMES.forEach((n, x) => {
        if (vals[x] === null) delete process.env[n];
        else process.env[n] = vals[x]!;
      });
      const r = readHerdrEnvironment(process.env);
      const ts = r === null ? "null" : `obj:${r.paneId === vals[2] ? "P" : "?"}:${r.bin === vals[1] ? "B" : "?"}`;
      const child = buildChildEnv(workdir, "default", "", "");
      const herdr: Record<string, string> = {};
      for (const [kk, v] of Object.entries(child)) {
        if (kk.startsWith("HERDR_") && v !== undefined) herdr[kk] = v as string;
      }
      for (const kk of Object.keys(herdr)) if (!NAMES.includes(kk as never)) throw new Error(`stray ${kk}`);
      const fwd = NAMES.map((n, x) =>
        herdr[n] === undefined ? "-" : herdr[n] === vals[x] ? String([i, j, k][x]) : "?").join(",");
      jobs.push({
        key: `${i},${j},${k}`, ts, fwd,
        env: { PATH: process.env.PATH ?? "", HOME: process.env.HOME ?? "",
               MOTOKO_WORKDIR: workdir, HERDR_ORCHESTRATOR: "off", ...herdr },
      });
    }

async function gate(env: Record<string, string>): Promise<string> {
  const p = Bun.spawn(
    ["ailang", "run", "--relax-modules", "--caps", "Clock,Env,FS,IO,Process", "--entry", "main", "register_gate.ail"],
    { cwd: here, env, stdout: "pipe", stderr: "pipe" });
  const out = await new Response(p.stdout).text();
  await p.exited;
  const m = out.match(/^tools=(.*)$/m);
  if (!m) throw new Error(`register_gate.ail printed no tools line (exit ${p.exitCode}): ${out}`);
  return m[1] === "" ? "false" : "true";
}

const results: string[] = new Array(jobs.length);
let next = 0;
async function worker() {
  while (next < jobs.length) {
    const n = next++;
    const jb = jobs[n];
    results[n] = `${jb.key}|${jb.ts}|${jb.fwd}|${await gate(jb.env)}`;
  }
}
await Promise.all(Array.from({ length: 8 }, worker));
process.stdout.write(results.join("\n") + "\n");
