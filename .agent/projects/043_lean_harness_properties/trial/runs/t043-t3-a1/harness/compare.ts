// compare.ts — stage 4 of the T3 harness: the executable statements of P3.1 and P3.2.
//
//   bun compare.ts <gen output> <fold_host output> [host output]
//
// P3.1: for every case, the fold of the HOST's journal (F) and the fold of the TWIN's
//       journal (T) must agree: the same refusal id, or both accepted with equal
//       `history` and `dangling`.
// P3.2: for every case the grammar marks run-emittable (W col 4 = 1), the twin's fold
//       accepts, and its history equals the spec history (rule 3 + rule 4 over the
//       records, stage 1). `single_run` (col 5) splits single-run traces from session
//       traces (follow-up, resume).
// X-1:  (exploratory) where both folds accept with equal history and dangling, the rest of
//       the SessionState the fold returns (`last`, `world_ordinal`, `model`, `profile`)
//       must agree too.
// X-3:  (exploratory, needs [host output]) where the fold of the host's journal accepts,
//       the host's `pendingToolCalls` (D1's `exit.pending_tool_calls`) equal its `dangling`.
// Prints a summary and up to N examples per class; exit 1 if any violation.
import * as fs from "fs";

const [genOut, foldOut, hostOut] = [process.argv[2], process.argv[3], process.argv[4]];
const N = Number(process.env.T3_EXAMPLES ?? 8);
type W = { id: string; ops: string; emit: boolean; single: boolean };
type T = { verdict: string; dangling: string; n: string; hist: string; spec: string; child: string; rest: string };
type F = { verdict: string; dangling: string; n: string; hist: string; rest: string };
const ws = new Map<string, W>(), ts = new Map<string, T>(), fs_ = new Map<string, F>();
for (const l of fs.readFileSync(genOut, "utf8").split("\n")) {
  const c = l.split("\t");
  if (c[0] === "W") ws.set(c[1], { id: c[1], ops: c[2], emit: c[3] === "1", single: c[4] === "1" });
  if (c[0] === "T") ts.set(c[1], { verdict: c[2], dangling: c[3], n: c[4], hist: c[5], spec: c[6], child: c[7], rest: c[8] });
}
for (const l of fs.readFileSync(foldOut, "utf8").split("\n")) {
  const c = l.split("\t");
  if (c[0] === "F") fs_.set(c[1], { verdict: c[2], dangling: c[3], n: c[4], hist: c[5], rest: c[6] });
}
const pending = new Map<string, string[]>();
if (hostOut) for (const l of fs.readFileSync(hostOut, "utf8").split("\n")) {
  const c = l.split("\t");
  if (c[0] === "H") pending.set(c[1], JSON.parse(c[5] ?? "[]"));
}
const classes = new Map<string, string[]>();
const add = (k: string, ex: string) => { if (!classes.has(k)) classes.set(k, []); classes.get(k)!.push(ex); };
let p31 = 0, p32 = 0, x1 = 0, x3 = 0, checked31 = 0, checked32 = 0;
const verdictPairs = new Map<string, number>();
for (const [id, w] of ws) {
  const t = ts.get(id), f = fs_.get(id);
  if (!t || !f) { add("MISSING", `${id} ${w.ops}`); p31++; continue; }
  checked31++;
  const vk = `host=${f.verdict} twin=${t.verdict}`;
  verdictPairs.set(vk, (verdictPairs.get(vk) ?? 0) + 1);
  const tag = `${w.emit ? "emittable" : "outside-grammar"}${w.single ? "" : ",session"}`;
  if (f.verdict !== t.verdict) { p31++; add(`P3.1 verdict ${vk} [${tag}]`, `${id} ${w.ops}`); }
  else if (f.verdict === "accept" && (f.hist !== t.hist || f.dangling !== t.dangling || f.n !== t.n)) {
    p31++;
    const what = f.hist !== t.hist ? "history" : "dangling";
    add(`P3.1 accept/accept ${what} differs [${tag}]`, `${id} ${w.ops} host=[${f.dangling}](${f.n}) twin=[${t.dangling}](${t.n})`);
  }
  else if (f.verdict === "accept" && f.rest !== t.rest) {
    x1++;
    add(`X-1 rest of SessionState differs [${tag}]`, `${id} ${w.ops} host{${f.rest}} twin{${t.rest}}`);
  }
  // X-3: the host's three-line twin of rule 4 (`pendingToolCalls`, written as
  // `exit.pending_tool_calls`) against the fold's `dangling` on the host's own journal.
  const pd = pending.get(id);
  if (pd && f.verdict === "accept" && (pd.join(",") !== f.dangling || String(pd.length) !== f.n)) {
    x3++;
    add(`X-3 host pendingToolCalls != fold dangling [${tag}]`, `${id} ${w.ops} pending=${JSON.stringify(pd)} dangling=[${f.dangling}](${f.n})`);
  }
  if (w.emit) {
    checked32++;
    if (t.verdict !== "accept") { p32++; add(`P3.2 twin refuses (${t.verdict}) [${tag}]`, `${id} ${w.ops}`); }
    else if (t.hist !== t.spec) { p32++; add(`P3.2 history != spec [${tag}]`, `${id} ${w.ops}`); }
    else if (t.hist !== t.child) add(`note: history == spec but != child model [${tag}]`, `${id} ${w.ops}`);
  }
}
console.log(`cases: ${ws.size}`);
for (const [k, v] of [...verdictPairs].sort()) console.log(`  ${k.padEnd(40)} ${v}`);
for (const [k, v] of [...classes].sort()) {
  console.log(`${k}: ${v.length}`);
  for (const ex of v.slice(0, N)) console.log(`    ${ex}`);
}
console.log(`P3.1: ${checked31} cases compared, ${p31} violations`);
console.log(`P3.2: ${checked32} run-emittable cases, ${p32} violations`);
if (hostOut) console.log(`X-3: ${x3} cases where the host's pendingToolCalls differ from the fold's dangling on the host journal`);
console.log(`X-1: ${x1} cases where both accept with equal history/dangling but the rest of the state differs`);
// T3_PROP selects what the exit status reports (the repro mode): P3.1, P3.2, X-1, or all.
const prop = process.env.T3_PROP ?? "all";
const bad = prop === "P3.1" ? p31 : prop === "P3.2" ? p32 : prop === "X-1" ? x1 : prop === "X-3" ? x3 : p31 + p32 + x1 + x3;
process.exit(bad > 0 ? 1 : 0);
