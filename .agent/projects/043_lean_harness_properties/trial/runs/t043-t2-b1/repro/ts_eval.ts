// The REAL herdrFailureCode / herdrMeansAgentGone on one case file. Prints <code>|<gone>.
//   bun ts_eval.ts <repo root> <case.json>
import * as fs from "fs";
import * as path from "path";
const [repo, casePath] = process.argv.slice(2);
const ww = await import(path.resolve(repo, "src/tui/src/wake-waiter.ts"));
const c = JSON.parse(fs.readFileSync(casePath, "utf8")) as { exit: number; stderr: string };
const r = { code: c.exit, stdout: "", stderr: c.stderr };
process.stdout.write(`${ww.herdrFailureCode(r)}|${ww.herdrMeansAgentGone(r)}\n`);
