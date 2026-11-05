// check.ts — reproduce one T2 counterexample on the REAL, unmodified code.
//
//   bun check.ts <mode> <exit code> <stderr as a JSON string literal>
//
// Runs the real herdrFailureCode / herdrMeansAgentGone (src/tui/src/wake-waiter.ts) in-process,
// and the real failure_code / means_agent_gone (packages/motoko-ext-herdr/types.ail) through
// `ailang run` on ../diff/run_ail.ail. Modes:
//   gone  P2.1: exit 1 when herdrMeansAgentGone != means_agent_gone
//   code  P2.2: exit 1 when herdrFailureCode != failure_code
//   x1    X-1:  exit 1 when herdrFailureCode is "" (the documented success value) on a non-zero
//              exit code (TS only; no ailang)
// Exit 0 when the defect is absent, 2 on a harness error.
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { spawnSync } from "child_process";

const [mode, codeArg, errJson] = process.argv.slice(2);
const here = path.dirname(new URL(import.meta.url).pathname);
const cwd = process.cwd();
const tree = fs.existsSync(path.join(cwd, "src/tui/src/wake-waiter.ts"))
  ? cwd
  : path.resolve(here, "../../tree");
const code = Number(codeArg);
const err = JSON.parse(errJson) as string;

const ww = await import(path.join(tree, "src/tui/src/wake-waiter.ts"));
const r = { code, stdout: "", stderr: err };
const tsCode: string = ww.herdrFailureCode(r);
const tsGone: boolean = ww.herdrMeansAgentGone(r);
console.log(`input:  exit ${code}, stderr ${JSON.stringify(err)}`);
console.log(`TS      herdrFailureCode=${JSON.stringify(tsCode)} herdrMeansAgentGone=${tsGone}`);

if (mode === "x1") {
  const bad = code !== 0 && tsCode === "";
  console.log(bad ? "DEFECT PRESENT: a failed call gets the success code \"\"" : "defect absent");
  process.exit(bad ? 1 : 0);
}

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "t2-repro-"));
const args = path.join(tmp, "case.json");
fs.writeFileSync(args, JSON.stringify({ cases: [{ code, err }] }));
const ail = spawnSync(
  "ailang",
  ["run", "--package-dir", tree, "--relax-modules", "--caps", "IO", "--entry", "main", "--args-file", args, "run_ail.ail"],
  { cwd: path.resolve(here, "../diff"), encoding: "utf8", timeout: 100_000 },
);
fs.rmSync(tmp, { recursive: true, force: true });
const line = (ail.stdout ?? "").split("\n").find((l) => l.startsWith("0\t"));
if (!line) {
  console.log(`harness error: ailang gave no result\n${ail.stdout}\n${ail.stderr}`);
  process.exit(2);
}
const [, ailCodeJson, ailGoneTF] = line.split("\t");
const ailCode: string = JSON.parse(ailCodeJson);
const ailGone = ailGoneTF === "T";
console.log(`AILANG  failure_code=${JSON.stringify(ailCode)} means_agent_gone=${ailGone}`);
const bad = mode === "gone" ? tsGone !== ailGone : tsCode !== ailCode;
console.log(bad ? `DEFECT PRESENT: the twins disagree (${mode === "gone" ? "P2.1" : "P2.2"})` : "defect absent");
process.exit(bad ? 1 : 0);
