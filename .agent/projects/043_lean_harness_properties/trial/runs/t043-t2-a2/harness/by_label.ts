// by_label.ts — the structured run, one row per (envelope, code value) at exit 1 and at
// exit -1: what each twin returns and whether P2.1 holds. For finding root causes; not a
// pass/fail check.
//
//   bun by_label.ts <cases.tsv> <labels.tsv> <ts.out> <ail.out> [exit ...]
const [cp, lp, tp, ap, ...exitsArg] = process.argv.slice(2);
const exits = exitsArg.length ? exitsArg : ["1"];
const rd = async (p: string) => (await Bun.file(p).text()).split("\n").filter((l) => l !== "");
const unb64 = (s: string) => Buffer.from(s ?? "", "base64").toString("utf8");
const [cases, labels, ts, ail] = [await rd(cp), await rd(lp), await rd(tp), (await rd(ap)).filter((l) => /^\d+\t/.test(l))];
const rows = new Map<string, string[]>();
for (let i = 0; i < cases.length; i++) {
  const ec = cases[i].split("\t")[1];
  if (!exits.includes(ec)) continue;
  const label = labels[i].split("\t")[1];
  const [env, val] = label.includes(":") ? [label.slice(0, label.indexOf(":")), label.slice(label.indexOf(":") + 1)] : [label, ""];
  const [, tc, tg] = ts[i].split("\t");
  const [, shape, ac, ag] = ail[i].split("\t");
  const mark = tg !== ag ? "P2.1-FAIL" : unb64(tc) !== unb64(ac) ? "p2.2-diff" : "same";
  if (mark === "same") continue;
  const k = `exit=${ec} ${env}`;
  if (!rows.has(k)) rows.set(k, []);
  rows.get(k)!.push(`    ${mark} ${val || "-"}: ts=${JSON.stringify(unb64(tc))}/${tg} ail[${shape}]=${JSON.stringify(unb64(ac))}/${ag}`);
}
for (const [k, v] of rows) {
  console.log(`${k}: ${v.filter((x) => x.includes("P2.1")).length} P2.1 fails, ${v.length} rows differ`);
  for (const x of v.filter((x) => x.includes("P2.1")).slice(0, 4)) console.log(x);
}
