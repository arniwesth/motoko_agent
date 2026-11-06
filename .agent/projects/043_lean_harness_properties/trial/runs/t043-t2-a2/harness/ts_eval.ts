// ts_eval.ts — the TypeScript half of the T2 differential test.
//
// Calls the REAL `herdrFailureCode` and `herdrMeansAgentGone` from
// src/tui/src/wake-waiter.ts on the same cases as ail_eval.ail, in the same order.
//
//   bun ts_eval.ts < cases.tsv
//
// Input lines:  <id> TAB <exit_code> TAB <base64 of stderr's UTF-8>
// Output lines: <id> TAB <base64 of herdrFailureCode's UTF-8> TAB <herdrMeansAgentGone: 1|0>
//
// No case sets `spawnError`: P2.1 and P2.2 are stated with no spawn error.

import type { HerdrResult } from "../../tree/src/tui/src/wake-waiter.ts";

// T2_TS_MODULE overrides the module under test (fixcheck/ uses it to show a repro exits 0 on a
// patched COPY); by default it is the real tree file.
const modPath = process.env.T2_TS_MODULE ?? new URL("../../tree/src/tui/src/wake-waiter.ts", import.meta.url).pathname;
const { herdrFailureCode, herdrMeansAgentGone } = (await import(modPath)) as typeof import("../../tree/src/tui/src/wake-waiter.ts");

const b64 = (s: string): string => Buffer.from(s, "utf8").toString("base64");

export function tsEval(code: number, stderr: string): { code: string; gone: boolean } {
  const r: HerdrResult = { code, stdout: "", stderr };
  return { code: herdrFailureCode(r), gone: herdrMeansAgentGone(r) };
}

if (import.meta.main) {
  const input = await Bun.stdin.text();
  const out: string[] = [];
  for (const line of input.split("\n")) {
    if (line === "") continue;
    const [id, ec, e64] = line.split("\t");
    const stderr = Buffer.from(e64 ?? "", "base64").toString("utf8");
    const r = tsEval(Number.parseInt(ec, 10), stderr);
    out.push(`${id}\t${b64(r.code)}\t${r.gone ? "1" : "0"}`);
  }
  process.stdout.write(out.join("\n") + (out.length ? "\n" : ""));
}
