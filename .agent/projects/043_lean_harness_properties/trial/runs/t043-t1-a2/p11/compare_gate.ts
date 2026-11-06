// compare_gate.ts — the executable statement of P1.1, applied to the two halves' outputs.
//
//   bun compare_gate.ts <cases.json> <ts.out> <ail.out> [--class ENV_GT_1|BIN_EMPTY|OTHER|all]
//
// P1.1: for every (HERDR_ENV, HERDR_BIN_PATH, HERDR_PANE_ID), each unset or any string, with
// unset passed to AILANG as "": readHerdrEnvironment(env) !== null  <=>  herdr_env_ready(e, b, p).
//
// Also checks that both halves saw the same strings (code-point lengths per field), so a
// disagreement cannot be an artefact of the AILANG literal encoding.
//
// Every disagreement is classified by the case's content:
//   ENV_GT_1     HERDR_ENV is a string other than "1" that AILANG's `>= "1"` admits
//   BIN_EMPTY    HERDR_BIN_PATH is set to "" (TypeScript tests `=== undefined`, AILANG `!= ""`)
//   OTHER        anything else
// Exit 1 when a disagreement of the selected class (default all) occurs, 0 when none does,
// 2 on a fidelity failure (the halves did not see the same strings: no verdict).
import { readFileSync } from "node:fs";

const [cf, tf, af] = process.argv.slice(2);
const ci = process.argv.indexOf("--class");
const want = ci >= 0 ? process.argv[ci + 1] : "all";
if (!cf || !tf || !af) throw new Error("usage: bun compare_gate.ts <cases.json> <ts.out> <ail.out>");
const { cases, tags } = JSON.parse(readFileSync(cf, "utf8")) as { cases: (string | null)[][]; tags: string[] };
const ts = readFileSync(tf, "utf8").trimEnd().split("\n");
const ail = readFileSync(af, "utf8").trimEnd().split("\n").filter((l) => /^\d+\|/.test(l));

let fidelity = 0;
if (ts.length !== cases.length || ail.length !== cases.length) {
  console.log(`LINE COUNT: cases ${cases.length}, ts ${ts.length}, ail ${ail.length}`);
  process.exit(2);
}
const counts = new Map<string, number>();
const examples = new Map<string, string[]>();
const byGen = new Map<string, number>();
let agree = 0, both = 0, selected = 0;
for (let i = 0; i < cases.length; i++) {
  const t = ts[i].split("|");
  const a = ail[i].split("|");
  if (t[0] !== String(i) || a[0] !== String(i)) { console.log(`ORDER at ${i}: ${ts[i]} / ${ail[i]}`); process.exit(2); }
  if (t[2] !== a[2] || t[3] !== a[3] || t[4] !== a[4]) {
    fidelity++;
    if (fidelity <= 5) console.log(`  FIDELITY ${i} ts=${ts[i]} ail=${ail[i]} case=${JSON.stringify(cases[i])}`);
    continue;
  }
  if (t[1] === a[1]) { agree++; if (t[1] === "T") both++; continue; }
  const [e, b] = cases[i];
  const cls = e !== null && e !== "1" && a[1] === "T" ? "ENV_GT_1" : b === "" && t[1] === "T" ? "BIN_EMPTY" : "OTHER";
  if (want === "all" || want === cls) selected++;
  const key = `${cls} (ts=${t[1]} ail=${a[1]})`;
  counts.set(key, (counts.get(key) ?? 0) + 1);
  byGen.set(`${cls}/${tags[i]}`, (byGen.get(`${cls}/${tags[i]}`) ?? 0) + 1);
  const ex = examples.get(key) ?? [];
  if (ex.length < 4) ex.push(`#${i} ${tags[i]} ${JSON.stringify(cases[i])}`);
  examples.set(key, ex);
}
const bad = cases.length - agree - fidelity;
console.log(`P1.1: ${cases.length} cases, ${agree} agree (${both} both open), ${bad} disagree, ${fidelity} fidelity failures`);
for (const [k, n] of [...counts].sort()) {
  console.log(`  ${k}: ${n}`);
  for (const ex of examples.get(k)!) console.log(`      ${ex}`);
}
for (const [k, n] of [...byGen].sort()) console.log(`  by generator ${k}: ${n}`);
console.log(`selected class ${want}: ${selected} disagreements`);
process.exit(fidelity > 0 ? 2 : selected > 0 ? 1 : 0);
