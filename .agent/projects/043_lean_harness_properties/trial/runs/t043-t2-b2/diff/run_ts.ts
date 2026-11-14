// run_ts.ts — the TypeScript half: the REAL herdrFailureCode / herdrMeansAgentGone.
//   bun run_ts.ts <repo> <cases.json>
// One line per case: <index>\t<JSON string of herdrFailureCode>\t<T|F>
import * as fs from "fs";
const [repo, casesPath] = process.argv.slice(2);
// WW_TS overrides the module, for the negative control (negative_control.sh) only.
const ww = await import(process.env.WW_TS ?? `${repo}/src/tui/src/wake-waiter.ts`);
const { cases } = JSON.parse(fs.readFileSync(casesPath, "utf8")) as { cases: { code: number; err: string }[] };
const lines: string[] = [];
cases.forEach((c, i) => {
  const r = { code: c.code, stdout: "", stderr: c.err };
  lines.push(`${i}\t${JSON.stringify(ww.herdrFailureCode(r))}\t${ww.herdrMeansAgentGone(r) ? "T" : "F"}`);
});
process.stdout.write(lines.join("\n") + "\n");
