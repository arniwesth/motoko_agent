// ts_twin.ts — the TypeScript half: the REAL `herdrFailureCode` and `herdrMeansAgentGone`
// (src/tui/src/wake-waiter.ts:129, :142), called on every corpus case with NO spawn error
// (P2.1's precondition), so `HerdrResult` is `{code, stdout: "", stderr: err}`.
//
//   bun ts_twin.ts <repo root> <corpus.json> <out.json>
//
// Writes the corpus back with `ts_code` and `ts_gone` added. The AILANG half (ail_twin.ail) reads
// that file and compares the real `failure_code` / `means_agent_gone` with these values using
// AILANG's own `==`, so neither language's output is re-encoded before the comparison.

import * as fs from "fs";
import * as path from "path";

const [root, corpusPath, outPath] = process.argv.slice(2);
if (!root || !corpusPath || !outPath) throw new Error("usage: bun ts_twin.ts <repo root> <corpus.json> <out.json>");

const ww = await import(path.resolve(root, "src/tui/src/wake-waiter.ts"));
const herdrFailureCode: (r: unknown) => string = ww.herdrFailureCode;
const herdrMeansAgentGone: (r: unknown) => boolean = ww.herdrMeansAgentGone;

type Case = { code: number; err: string; gen: string };
const corpus = JSON.parse(fs.readFileSync(corpusPath, "utf8")) as Case[];

const out = corpus.map((c) => {
  const r = { code: c.code, stdout: "", stderr: c.err }; // spawnError absent
  return { ...c, ts_code: herdrFailureCode(r), ts_gone: herdrMeansAgentGone(r) };
});
fs.writeFileSync(outPath, JSON.stringify(out));
process.stderr.write(`ts: ${out.length} cases, ${out.filter((c) => c.ts_gone).length} gone\n`);
