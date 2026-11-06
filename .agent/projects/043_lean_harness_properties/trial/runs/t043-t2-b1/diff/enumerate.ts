// The TypeScript half of the differential test for ../HerdrFailureModel.lean: the REAL
// `herdrFailureCode` and `herdrMeansAgentGone` (src/tui/src/wake-waiter.ts:129-144), over
// gen/corpus.json, crossed with its exit codes, in the order of Corpus.lean and
// enumerate_herdr.ail. `spawnError` is left undefined: P2.1 and P2.2 are stated for "no spawn
// error". One line per case:
//
//   <stderr index>|<exit code>|<herdrFailureCode>|<herdrMeansAgentGone>
//
//   bun enumerate.ts <repo root> <corpus.json>

import * as fs from "fs";
import * as path from "path";

const [repo, corpusPath] = process.argv.slice(2);
if (!repo || !corpusPath) throw new Error("usage: bun enumerate.ts <repo root> <corpus.json>");
// WW_PATH: a mutant copy of wake-waiter.ts, for the negative control (mutants/run_mutants.sh).
const ww = await import(process.env.WW_PATH || path.resolve(repo, "src/tui/src/wake-waiter.ts"));
const { exits, stderr } = JSON.parse(fs.readFileSync(corpusPath, "utf8")) as { exits: number[]; stderr: string[] };

const lines: string[] = [];
stderr.forEach((s, i) => {
  for (const e of exits) {
    const r = { code: e, stdout: "", stderr: s };
    lines.push(`${i}|${e}|${ww.herdrFailureCode(r)}|${ww.herdrMeansAgentGone(r)}`);
  }
});
process.stdout.write(lines.join("\n") + "\n");
