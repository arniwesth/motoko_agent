// tabulate.ts <results dir> — the markdown tables in SUMMARY.md, from the *.report files that
// check.ts wrote, so no count in SUMMARY.md is transcribed by hand.
import { readFileSync, readdirSync } from "fs";
import { join } from "path";
const dir = process.argv[2];
const gens = ["chars_6", "bytes_3", "random_20000", "random_500_7_2000", "cjk_1400"];
const parse = (f: string) => {
  const m = new Map<string, string>();
  for (const l of readFileSync(join(dir, f), "utf8").split("\n")) {
    const r = l.match(/^(\S+:\S+)\s+(\d+)\s+(\d+)/);
    if (r) m.set(r[1], `${r[3]} / ${r[2]}`);
  }
  return m;
};
const reports = Object.fromEntries(gens.map((g) => [g, parse(`${g}.report`)]));
const keys = [...new Set(gens.flatMap((g) => [...reports[g].keys()]))].sort();
console.log(`| fn:property | ${gens.join(" | ")} |`);
console.log(`|---|${gens.map(() => "---:").join("|")}|`);
for (const k of keys) console.log(`| \`${k}\` | ${gens.map((g) => reports[g].get(k) ?? "–").join(" | ")} |`);
console.log();
const ctl = readdirSync(dir).filter((f) => /^(mutant_|fixed_).*\.report$/.test(f)).sort();
for (const f of ctl) {
  const m = parse(f);
  console.log(`- \`${f}\`: ${[...m.entries()].map(([k, v]) => `${k} ${v}`).join(", ")}`);
}
