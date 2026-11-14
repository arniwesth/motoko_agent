// check_cases.ts — the checking half of the random test: executable statements of P5.1-P5.3
// and the exploratory X-1..X-4 (SUMMARY.md), applied to what run_cases.ail printed for the
// REAL `path_up`, its twin `ev_path_up` and the reader's `strict_path`. Nothing here computes a
// path: every check is a statement about the returned entries (by their position, `seq`).
//
//   bun check_cases.ts cases.jsonl results.jsonl
//
// Prints counts per property and generator, and up to 3 witnesses each. Exit 1 on any violation,
// 2 if the result file does not have exactly one line per case (P5.1: a call that did not
// return, or a crash, leaves the AILANG half short).

import { readFileSync } from "node:fs";

type Spec = [string, string, string];
type Case = { mode: string; es: Spec[]; start: string };
type Res = { i: number; core: number[]; twin: number[]; strict_ok: boolean; strict: number[]; strict_err: string };

const [casesPath, resPath] = process.argv.slice(2);
const lines = (p: string) => readFileSync(p, "utf8").split("\n").filter((l) => l.trim() !== "");
const cases: Case[] = lines(casesPath).map((l) => JSON.parse(l));
const results: Res[] = lines(resPath).filter((l) => l.startsWith("{")).map((l) => JSON.parse(l));

if (results.length !== cases.length || results.some((r, k) => r.i !== k || !Array.isArray(r.core))) {
  console.log(`P5.1: ${cases.length} cases but ${results.length} well-formed results: a call did not return`);
  process.exit(2);
}

const eq = (a: number[], b: number[]) => a.length === b.length && a.every((x, k) => x === b[k]);

const checks: Record<string, (c: Case, r: Res) => boolean> = {
  // P5.2: no id occurs twice in the result.
  "P5.2": (c, r) => new Set(r.core.map((s) => c.es[s][0])).size === r.core.length,
  // P5.3 (chain): each entry's parent_id is the id of the entry before it.
  "P5.3c": (c, r) => r.core.every((s, k) => k === 0 || c.es[s][1] === c.es[r.core[k - 1]][0]),
  // P5.3 (end): if the start id names an entry, the last entry has that id.
  "P5.3l": (c, r) =>
    !c.es.some((e) => e[0] === c.start) || (r.core.length > 0 && c.es[r.core[r.core.length - 1]][0] === c.start),
  // X-1: D4 rule 1 stops only at the root, a missing parent, or the first repeated id.
  "X-1": (c, r) => {
    if (r.core.length === 0) return c.start === "" || !c.es.some((e) => e[0] === c.start);
    const p = c.es[r.core[0]][1];
    return p === "" || !c.es.some((e) => e[0] === p) || r.core.some((s) => c.es[s][0] === p);
  },
  // X-2: each returned entry is the FIRST entry in the list with its id (find_entry's contract).
  "X-2": (c, r) => r.core.every((s) => c.es.findIndex((e) => e[0] === c.es[s][0]) === s),
  // X-3: the twin returns the same entries.
  "X-3": (_c, r) => eq(r.core, r.twin),
  // X-4: where the strict reader accepts, it returns the same entries.
  "X-4": (_c, r) => !r.strict_ok || eq(r.core, r.strict),
};

const tally: Record<string, Record<string, number>> = {};
const perMode: Record<string, number> = {};
const wits: Record<string, string[]> = {};
let bad = 0;
const show = (c: Case) =>
  `es=[${c.es.map((e) => `${JSON.stringify(e[0])}<${JSON.stringify(e[1])}`).join(" ")}] start=${JSON.stringify(c.start)}`;
cases.forEach((c, k) => {
  const r = results[k];
  const mode = c.mode + (c.start === "" ? "(start \"\")" : "");
  perMode[mode] = (perMode[mode] ?? 0) + 1;
  for (const [name, ok] of Object.entries(checks)) {
    if (ok(c, r)) continue;
    bad++;
    (tally[name] ??= {})[mode] = (tally[name]?.[mode] ?? 0) + 1;
    const w = (wits[`${name} ${mode}`] ??= []);
    if (w.length < 3)
      w.push(`  ${name} [${mode}] ${show(c)}  path_up=[${r.core}] ev_path_up=[${r.twin}] strict_path=${r.strict_ok ? `[${r.strict}]` : `Err(${r.strict_err})`}`);
  }
});

console.log(`check_cases: ${cases.length} cases, ${results.length} results (P5.1: every call returned)`);
console.log(`  cases per generator: ${Object.entries(perMode).map(([m, n]) => `${m}=${n}`).join(" ")}`);
console.log(`  max entries in a case: ${Math.max(...cases.map((c) => c.es.length))}`);
for (const name of Object.keys(checks)) {
  const t = tally[name] ?? {};
  const total = Object.values(t).reduce((a, b) => a + b, 0);
  console.log(`  ${name.padEnd(6)} ${String(total).padStart(6)} violations  ${Object.entries(t).map(([m, n]) => `${m}=${n}`).join(" ")}`);
}
for (const w of Object.values(wits)) for (const l of w) console.log(l.length > 300 ? l.slice(0, 300) + " …" : l);
process.exit(bad > 0 ? 1 : 0);
