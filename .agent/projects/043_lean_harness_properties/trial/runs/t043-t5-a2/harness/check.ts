// check.ts — the registered properties of path_up, stated as executable predicates over the
// REAL functions' outputs (path_direct.ail). Not a model: nothing here computes a path; it only
// judges the paths the real `path_up` (C), its eval twin `ev_path_up` (T) and the real
// `find_entry` (F) returned.
//
//   bun check.ts <cases file> <results file> [--quiet]
//
// For each function's result r (a list of entry positions into the case's entry list es):
//   P5.1  the run printed a result for every case and its END line (the caller's timeout kills
//         a run that does not terminate, and then END is missing).
//   P5.2  no id occurs twice in r.
//   P5.3  for i >= 1, es[r[i]].parent_id == es[r[i-1]].id; and if the start id names an entry
//         (some entry has that id), r is non-empty and its last entry has that id. Also: that
//         last entry is the one the real find_entry returns.
//   X-1   (ADR-003 D4 rule 1, "stopping at the first repeated id"): if r is non-empty, the
//         first entry's parent_id is "" or names no entry or names an id already in r, i.e.
//         the walk did not stop while it could still go on.
//   TWIN  C == T (the eval copy is pinned to the core's bytes by its SOURCE sha256).
//   STRICT where the eval reader's strict_path (S, a different real function) accepts, C == S:
//         on a header-rooted, acyclic, complete chain both walk the same path. Older result
//         files have no S column; then this check is skipped.
// Violations are counted per (function, property, class) where class says whether the start is
// "" (the root marker) and whether the case contains a parent cycle (judged from T's output:
// T's first entry's parent is in T). Exit 1 on any violation of P5.x / X-1 by C, any STRICT
// mismatch, or any TWIN mismatch (TWIN_GATE=0 in the environment: TWIN mismatches are reported
// but do not gate). T's own violations are reported and never gate.

import { readFileSync } from "fs";

const [casesF, resF, quiet] = process.argv.slice(2);
const cases = readFileSync(casesF, "utf8").split("\n").filter((l) => l !== "");
const res = readFileSync(resF, "utf8").split("\n").filter((l) => /^(\d+|END)\|/.test(l));

type E = { id: string; parent: string };
const parse = (spec: string): E[] =>
  spec === "" ? [] : spec.split(",").map((s) => {
    const k = s.indexOf("<");
    return { id: s.slice(0, k), parent: s.slice(k + 1) };
  });
const seqs = (s: string) => (s === "" ? [] : s.split(",").map(Number));

const counts = new Map<string, number>();
const first = new Map<string, string>();
let bad = 0;
const note = (key: string, witness: string, gate: boolean) => {
  counts.set(key, (counts.get(key) ?? 0) + 1);
  if (!first.has(key)) first.set(key, witness);
  if (gate) bad++;
};

const endLine = res.find((l) => l.startsWith("END|"));
const body = res.filter((l) => !l.startsWith("END|"));
if (!endLine || Number(endLine.split("|")[1]) !== cases.length || body.length !== cases.length) {
  console.log(`P5.1 VIOLATION or harness failure: ${cases.length} cases, ${body.length} results, END=${endLine ?? "missing"}`);
  bad++;
}

let cyc = 0, emptyStart = 0, n = 0, strictOk = 0;
for (let i = 0; i < Math.min(body.length, cases.length); i++) {
  const [ix, fF, cF, tF, sF] = body[i].split("|");
  if (Number(ix) !== i) throw new Error(`order mismatch at ${i}`);
  const [spec, start] = [cases[i].slice(0, cases[i].lastIndexOf("|")), cases[i].slice(cases[i].lastIndexOf("|") + 1)];
  const es = parse(spec);
  const f = fF.slice(2) === "-" ? -1 : Number(fF.slice(2));
  const C = seqs(cF.slice(2)), T = seqs(tF.slice(2));
  const names = es.some((e) => e.id === start);
  const tIds = T.map((k) => es[k].id);
  const cyclic = T.length > 0 && tIds.includes(es[T[0]].parent) && es[T[0]].parent !== "";
  n++; if (cyclic) cyc++; if (start === "") emptyStart++;
  const cls = `${start === "" ? "start=\"\"" : "start!=\"\""},${cyclic ? "cycle" : "acyclic"}`;
  const cut = (x: string) => (x.length > 160 ? `${x.slice(0, 120)}…(${es.length} entries)…${x.slice(-30)}` : x);
  const w = `${cut(cases[i])}  =>  C=[${cut(String(C))}] T=[${cut(String(T))}] F=${f}`;

  for (const [who, r, gate] of [["C", C, true], ["T", T, false]] as const) {
    const ids = r.map((k) => es[k].id);
    if (new Set(ids).size !== ids.length) note(`${who} P5.2 ${cls}`, w, gate);
    let chainOk = true;
    for (let j = 1; j < r.length; j++) if (es[r[j]].parent !== es[r[j - 1]].id) chainOk = false;
    if (!chainOk) note(`${who} P5.3-chain ${cls}`, w, gate);
    if (names && (r.length === 0 || es[r[r.length - 1]].id !== start)) note(`${who} P5.3-last ${cls}`, w, gate);
    if (names && r.length > 0 && r[r.length - 1] !== f) note(`${who} P5.3-last-is-find_entry ${cls}`, w, gate);
    if (r.length > 0) {
      const p = es[r[0]].parent;
      if (!(p === "" || !es.some((e) => e.id === p) || ids.includes(p))) note(`${who} X-1 ${cls}`, w, gate);
    }
  }
  if (C.join(",") !== T.join(",")) note(`TWIN C!=T ${cls}`, w, process.env.TWIN_GATE !== "0");
  if (sF !== undefined && sF !== "S:!") {
    strictOk++;
    if (seqs(sF.slice(2)).join(",") !== C.join(",")) note(`STRICT C!=S ${cls}`, w, true);
  }
}

console.log(`checked ${n} cases (${cyc} with a parent cycle on the twin's path, ${emptyStart} with start "", ${strictOk} accepted by strict_path)`);
for (const [k, v] of [...counts].sort()) {
  console.log(`  ${k.padEnd(52)} ${String(v).padStart(8)}   first: ${first.get(k)}`);
}
if (!quiet) console.log(bad > 0 ? "RESULT: violations present" : "RESULT: no violations");
process.exit(bad > 0 ? 1 : 0);
