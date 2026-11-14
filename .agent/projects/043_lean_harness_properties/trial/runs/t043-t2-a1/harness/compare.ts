// compare.ts — P2.1 and P2.2 over the joined halves.
//
//   bun compare.ts <ts.json> <ail.out> [examples per class]
//
// <ts.json> is ts_twin.ts's output (the corpus with the TS twin's values); <ail.out> is
// ail_twin.ail's output for the same cases in the same order (chunks concatenated in order, with
// the index column restarting per chunk, which is why lines are matched by position, not index).
//
// P2.1: for every exit code and stderr, no spawn error, herdrMeansAgentGone == means_agent_gone.
// P2.2: herdrFailureCode == failure_code.
//
// Every disagreement is put in ONE class, the first that applies in the order below. The classes
// are a reading aid for grouping witnesses by mechanism; each class's witness is then re-run
// through the real functions by its own repro script (../repro/), which is what the report rests
// on. Exit 1 if any P2.1 disagreement exists, else 0.

import * as fs from "fs";

const [tsPath, ailPath, perClassArg] = process.argv.slice(2);
const PER_CLASS = Number(perClassArg ?? 4);
type Row = { code: number; err: string; gen: string; ts_code: string; ts_gone: boolean };
const rows = JSON.parse(fs.readFileSync(tsPath, "utf8")) as Row[];
const ail = fs.readFileSync(ailPath, "utf8").split("\n").filter((l) => l !== "");
if (ail.length !== rows.length) {
  console.log(`LENGTH MISMATCH: ts ${rows.length} rows, ail ${ail.length} lines`);
  process.exit(2);
}

const jsonTrim = (s: string): string => s.replace(/^[ \t\n\r]+|[ \t\n\r]+$/g, "");
const parses = (s: string): boolean => {
  try {
    JSON.parse(s);
    return true;
  } catch {
    return false;
  }
};
const count = (s: string, sub: string): number => s.split(sub).length - 1;
const dupKeys = (s: string): boolean =>
  count(s, '"code"') + count(s, '"\\u0063ode"') > 1 || count(s, '"error"') + count(s, '"\\u0065rror"') > 1;

function classify(r: Row, ailGone: boolean, ailCode: string): string {
  const e = r.err;
  if (r.code < 0) return "negative-exit";
  if (r.code === 0 || r.code === 2) return "exit-0-or-2(unexpected)";
  if (r.ts_code.endsWith("_not_found") && r.ts_code !== "agent_not_found" && r.ts_gone !== ailGone) return "ts-suffix-not_found";
  if (e.includes("nested herdr")) return "ail-nested-herdr-gate";
  if (e === "") return "empty-stderr";
  if (e.trim() !== jsonTrim(e)) return "ts-trims-non-json-whitespace";
  const tsParses = parses(e.trim());
  if (!e.includes('{"error"')) return tsParses ? "ail-error-substring-gate(ts-parses)" : "no-error-substring(not-json)";
  if (!tsParses) return ailCode === "herdr_json_undecodable" ? "error-substring-but-not-json(ail-undecodable)" : "ail-decode-lenient(ts-rejects)";
  if (dupKeys(e)) return "duplicate-keys";
  return "other";
}

const p21 = new Map<string, { n: number; ex: string[] }>();
const p22 = new Map<string, { n: number; ex: string[] }>();
let n21 = 0;
let n22 = 0;
let n22only = 0;
const byGen: Record<string, { n: number; d21: number; d22: number }> = {};
for (let i = 0; i < rows.length; i++) {
  const r = rows[i];
  const [, a21, a22, ag, ...rest] = ail[i].split("\t");
  const ailGone = ag === "1";
  const ailCode = rest.join("\t");
  const g = (byGen[r.gen] ??= { n: 0, d21: 0, d22: 0 });
  g.n++;
  const bad21 = a21 !== "1";
  const bad22 = a22 !== "1";
  if (!bad21 && !bad22) continue;
  const cls = classify(r, ailGone, ailCode);
  const ex = `exit=${r.code} stderr=${JSON.stringify(r.err)} | ts: ${JSON.stringify(r.ts_code)} gone=${r.ts_gone} | ail: ${JSON.stringify(ailCode)} gone=${ailGone}`;
  const put = (m: Map<string, { n: number; ex: string[] }>): void => {
    const b = m.get(cls) ?? { n: 0, ex: [] };
    b.n++;
    b.ex.push(ex);
    m.set(cls, b);
  };
  if (bad21) {
    n21++;
    g.d21++;
    put(p21);
  }
  if (bad22) {
    n22++;
    g.d22++;
    if (!bad21) {
      n22only++;
      put(p22);
    }
  }
}

const show = (title: string, m: Map<string, { n: number; ex: string[] }>): void => {
  console.log(title);
  for (const [k, v] of [...m.entries()].sort((a, b) => b[1].n - a[1].n)) {
    console.log(`  ${k}: ${v.n}`);
    for (const e of v.ex.sort((a, b) => a.length - b.length).slice(0, PER_CLASS)) console.log(`      ${e}`);
  }
};
console.log(`cases: ${rows.length}`);
for (const [g, v] of Object.entries(byGen)) console.log(`  ${g}: ${v.n} cases, P2.1 disagree ${v.d21}, P2.2 disagree ${v.d22}`);
console.log(`P2.1 (gone) disagreements: ${n21}`);
console.log(`P2.2 (code) disagreements: ${n22} (${n22only} of them with gone agreeing)`);
show("P2.1 by class:", p21);
show("P2.2-only (gone agrees, code differs) by class:", p22);
process.exit(n21 > 0 ? 1 : 0);
