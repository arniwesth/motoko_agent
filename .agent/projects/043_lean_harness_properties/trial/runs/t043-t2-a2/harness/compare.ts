// compare.ts — joins cases, ts.out and ail.out (all keyed by id, same order) and checks
//
//   P2.1  herdrMeansAgentGone(r) == means_agent_gone(exit, stderr)   (no spawn error)
//   P2.2  herdrFailureCode(r)    == failure_code(exit, stderr)
//
// Mismatches are grouped by a key that names the AILANG shape and both codes, with the count
// and the first witness of each group. Exit 1 when any P2.1 mismatch exists, or (with
// --strict-p22) any P2.2 mismatch; 0 otherwise.
//
//   bun compare.ts <cases.tsv> <ts.out> <ail.out> [--strict-p22] [--quiet]

const [casesPath, tsPath, ailPath, ...flags] = process.argv.slice(2);
const strict22 = flags.includes("--strict-p22");
const quiet = flags.includes("--quiet");
const explain = flags.includes("--explain");

// --explain: attribute each P2.1 mismatch to the root causes found on the structured run
// (SUMMARY.md, "Root causes"). Each predicate reads the INPUT (and which side parsed), not the
// twins' bodies. A mismatch no predicate explains is printed: that is a new cause to look at.
const JSON_WS = /^[ \t\n\r]*|[ \t\n\r]*$/g;
function jsonPrefixParses(s: string): boolean {
  const t = s.replace(/^[ \t\n\r]+/, "");
  for (let i = 1; i < t.length; i++) {
    if (t[i - 1] !== "}" && t[i - 1] !== "]") continue;
    try { JSON.parse(t.slice(0, i)); return true; } catch { /* keep looking */ }
  }
  return false;
}
// How many object keys in s are `name` after unescaping (a key is a JSON string followed by `:`).
function keyCount(s: string, name: string): number {
  let n = 0;
  for (const m of s.matchAll(/"((?:[^"\\]|\\.)*)"\s*:/g)) {
    try { if (JSON.parse(`"${m[1]}"`) === name) n++; } catch { /* not a valid string */ }
  }
  return n;
}
function causesOf(exit: number, stderr: string, tcode: string, acode: string, ashape: string): string[] {
  const c: string[] = [];
  if (exit < 0) c.push("H:negative-exit");
  if (tcode.endsWith("_not_found") && tcode !== "agent_not_found") c.push("A:ts-suffix-rule");
  if (ashape === "nested_herdr") c.push("E:nested-herdr-before-json");
  if (ashape === "plain_text" && !stderr.includes('{"error"') && tcode !== "herdr_cli_rejected") c.push("B:ail-literal-{\"error\"-gate");
  if (ashape === "herdr_json" && tcode === "herdr_cli_rejected" && jsonPrefixParses(stderr)) c.push("C:ail-decode-ignores-trailing");
  if (stderr.trim() !== stderr.replace(JSON_WS, "")) c.push("D:ts-trim-strips-non-json-ws");
  if (keyCount(stderr, "code") > 1 || keyCount(stderr, "error") > 1) c.push("F:duplicate-keys");
  if (/[0-9][eE][+]?[0-9]{3,}/.test(stderr) && acode === "herdr_json_undecodable") c.push("G:number-out-of-range");
  return c;
}
const causeTally = new Map<string, Group>();
// P2.2 is registered inside herdr's JSON; outside it the vocabularies are known to differ (K6).
// "Inside" = either twin extracted a code from an `error` object, i.e. one of them returned a
// code that is not its own fixed vocabulary word.
const TS_FIXED = new Set(["", "spawn_error", "cli_syntax", "herdr_json_undecodable", "herdr_cli_rejected"]);
const AIL_FIXED = new Set(["", "cli_syntax", "nested_herdr", "herdr_json_undecodable", "herdr_failed_silently", "herdr_cli_rejected"]);
const p22In = new Map<string, Group>();
const p22Out = new Map<string, Group>();
let p22InUnexplained = 0;
let unexplained = 0;
const unb64 = (s: string): string => Buffer.from(s ?? "", "base64").toString("utf8");
const lines = async (p: string): Promise<string[]> => (await Bun.file(p).text()).split("\n").filter((l) => l !== "");

const cases = await lines(casesPath);
const ts = await lines(tsPath);
const ail = (await lines(ailPath)).filter((l) => /^\d+\t/.test(l));
if (cases.length !== ts.length || cases.length !== ail.length) {
  console.log(`LENGTH MISMATCH: cases ${cases.length}, ts ${ts.length}, ail ${ail.length}`);
  process.exit(3);
}

type Group = { n: number; ex: string };
const g21 = new Map<string, Group>();
const g22 = new Map<string, Group>();
let n21 = 0;
let n22 = 0;
let n22InJson = 0;
const add = (m: Map<string, Group>, k: string, ex: string): void => {
  const g = m.get(k);
  if (g) g.n++;
  else m.set(k, { n: 1, ex });
};
for (let i = 0; i < cases.length; i++) {
  const [id, ec, e64] = cases[i].split("\t");
  const [tid, tcode64, tgone] = ts[i].split("\t");
  const [aid, ashape, acode64, agone] = ail[i].split("\t");
  if (id !== tid || id !== aid || ashape === "PARSE_ERROR") {
    console.log(`ORDER/PARSE MISMATCH at ${i}: ${id} ${tid} ${aid} ${ashape}`);
    process.exit(3);
  }
  const stderr = unb64(e64);
  const tcode = unb64(tcode64);
  const acode = unb64(acode64);
  const ex = `exit=${ec} stderr=${JSON.stringify(stderr.length > 160 ? stderr.slice(0, 160) + "…" : stderr)} ts_code=${JSON.stringify(tcode)} ail_code=${JSON.stringify(acode)} ts_gone=${tgone} ail_gone=${agone}`;
  const exitClass = Number(ec) < 0 ? "exit<0" : Number(ec) === 0 ? "exit=0" : Number(ec) === 2 ? "exit=2" : "exit>0,!=2";
  if (tgone !== agone) {
    n21++;
    add(g21, `${exitClass} shape=${ashape} ts=${JSON.stringify(tcode)} ail=${JSON.stringify(acode)} gone ts/ail=${tgone}/${agone}`, ex);
    if (explain) {
      const cs = causesOf(Number(ec), stderr, tcode, acode, ashape);
      if (cs.length === 0) unexplained++;
      add(causeTally, cs.length ? cs.join(" + ") : "UNEXPLAINED", ex);
    }
  }
  if (tcode !== acode) {
    n22++;
    if (ashape === "herdr_json") n22InJson++;
    const cls = (c: string): string => (c.endsWith("_not_found") || ["", "cli_syntax", "nested_herdr", "herdr_cli_rejected", "herdr_json_undecodable", "herdr_failed_silently", "timeout", "server_not_running"].includes(c) ? JSON.stringify(c) : "<other code>");
    add(g22, `${exitClass} shape=${ashape} ts=${cls(tcode)} ail=${cls(acode)}`, ex);
    if (explain) {
      const inside = !TS_FIXED.has(tcode) || !AIL_FIXED.has(acode);
      if (inside) {
        const cs = causesOf(Number(ec), stderr, tcode, acode, ashape).filter((x) => !x.startsWith("A:"));
        if (cs.length === 0) p22InUnexplained++;
        add(p22In, cs.length ? cs.join(" + ") : "UNEXPLAINED", ex);
      } else add(p22Out, `ts=${JSON.stringify(tcode)} ail=${JSON.stringify(acode)}`, ex);
    }
  }
}
const show = (title: string, m: Map<string, Group>): void => {
  console.log(`${title}: ${m.size} groups`);
  if (quiet) return;
  for (const [k, g] of [...m.entries()].sort((a, b) => b[1].n - a[1].n)) console.log(`  [${g.n}] ${k}\n      e.g. ${g.ex}`);
};
console.log(`cases: ${cases.length}`);
console.log(`P2.1 (means agent gone) mismatches: ${n21}`);
show("P2.1 groups", g21);
console.log(`P2.2 (failure code) mismatches: ${n22} (${n22InJson} where AILANG's shape is herdr_json)`);
show("P2.2 groups", g22);
if (explain) {
  console.log(`P2.1 mismatches by cause (${unexplained} unexplained):`);
  for (const [k, g] of [...causeTally.entries()].sort((a, b) => b[1].n - a[1].n)) console.log(`  [${g.n}] ${k}${k === "UNEXPLAINED" || !quiet ? `\n      e.g. ${g.ex}` : ""}`);
}
if (explain) {
  const nIn = [...p22In.values()].reduce((a, g) => a + g.n, 0);
  const nOut = [...p22Out.values()].reduce((a, g) => a + g.n, 0);
  console.log(`P2.2 mismatches inside herdr's JSON: ${nIn} (${p22InUnexplained} unexplained by causes B-H)`);
  for (const [k, g] of [...p22In.entries()].sort((a, b) => b[1].n - a[1].n)) console.log(`  [${g.n}] ${k}${k === "UNEXPLAINED" || !quiet ? `\n      e.g. ${g.ex}` : ""}`);
  console.log(`P2.2 mismatches outside herdr's JSON (K6): ${nOut}`);
  for (const [k, g] of [...p22Out.entries()].sort((a, b) => b[1].n - a[1].n)) console.log(`  [${g.n}] ${k}\n      e.g. ${g.ex}`);
}
process.exit(n21 > 0 || (strict22 && n22 > 0) ? 1 : 0);
