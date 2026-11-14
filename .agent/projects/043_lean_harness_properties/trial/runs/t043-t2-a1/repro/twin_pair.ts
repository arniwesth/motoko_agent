// twin_pair.ts — one witness, both REAL twins, one verdict.
//
//   bun twin_pair.ts <P2.1|P2.2> <witness.json>      (from the tree root; exit 1 = they disagree)
//
// <witness.json> is {"code": <exit code>, "err": <stderr>}; spawnError is absent (P2.1's
// precondition). The TS side calls the real herdrFailureCode / herdrMeansAgentGone from
// src/tui/src/wake-waiter.ts; the AILANG side runs ../harness/ail_twin.ail (the real failure_code /
// means_agent_gone from packages/motoko-ext-herdr/types.ail) on the same case, and AILANG's own
// `==` decides agreement. Exit 1 when the selected property fails on the witness, 0 when it holds,
// 2 on a harness fault.

import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { spawnSync } from "child_process";

// A harness fault (failed import, crash) must not read as "defect present": exit 2, never 1.
process.on("uncaughtException", (e) => { console.error(`harness fault: ${e?.stack ?? e}`); process.exit(2); });
process.on("unhandledRejection", (e) => { console.error(`harness fault: ${(e as Error)?.stack ?? e}`); process.exit(2); });

const [prop, witnessPath] = process.argv.slice(2);
if ((prop !== "P2.1" && prop !== "P2.2") || !witnessPath) {
  console.error("usage: bun twin_pair.ts <P2.1|P2.2> <witness.json>");
  process.exit(2);
}
const root = process.cwd();
const here = path.dirname(new URL(import.meta.url).pathname);
const ww = await import(path.join(root, "src/tui/src/wake-waiter.ts"));

const w = JSON.parse(fs.readFileSync(witnessPath, "utf8")) as { code: number; err: string };
const r = { code: w.code, stdout: "", stderr: w.err };
const tsCode: string = ww.herdrFailureCode(r);
const tsGone: boolean = ww.herdrMeansAgentGone(r);

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "t2-twin-"));
const args = path.join(dir, "case.json");
fs.writeFileSync(args, JSON.stringify([{ code: w.code, err: w.err, gen: "repro", ts_code: tsCode, ts_gone: tsGone }]));
const ail = spawnSync(
  "ailang",
  ["run", "--relax-modules", "--caps", "IO", "--entry", "main", "--args-file", args, path.resolve(here, "../harness/ail_twin.ail")],
  { cwd: root, encoding: "utf8", timeout: 100_000 },
);
fs.rmSync(dir, { recursive: true, force: true });
const line = (ail.stdout ?? "").split("\n").find((l) => /^0\t[01]\t[01]\t[01]\t/.test(l));
if (ail.status !== 0 || !line) {
  console.error(`harness fault: ailang exit ${ail.status}\n${ail.stderr}`);
  process.exit(2);
}
const [, agree21, agree22, ailGone, ...rest] = line.split("\t");
console.log(`witness: exit ${w.code}, stderr ${JSON.stringify(w.err)}, no spawn error`);
console.log(`TS     herdrFailureCode = ${JSON.stringify(tsCode)}, herdrMeansAgentGone = ${tsGone}`);
console.log(`AILANG failure_code     = "${rest.join("\t")}" (display-escaped), means_agent_gone = ${ailGone === "1"}`);
const holds = prop === "P2.1" ? agree21 === "1" : agree22 === "1";
console.log(`${prop}: ${holds ? "holds" : "VIOLATED"} on this witness`);
process.exit(holds ? 0 : 1);
