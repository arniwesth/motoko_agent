// p01_diff.ts — P0.1 differential on the REAL code.
//
// Host twin: the REAL SessionJournal, driven through its private `recordAppended` (which calls the
// real `noteHistoryMessage`/`replaceLastHistoryMessage` -> `updatePending`) and `recordReplaced`,
// reached by a cast; `pendingToolCalls` is what `writeExit` copies into `exit.pending_tool_calls`.
// Fold twin: the REAL `fold_journal` (-> `pair_step`, `finish_fold`) via a generated AILANG module
// (fold_template.ail), over journals built with journal.ail's own writer twin.
//
// Ops: i (<100) append ALPHABET[i]; 100+i append ALPHABET[i] with replaces_previous;
//      200+i history_replaced(resume) of seed ++ [ALPHABET[i]]; 300+k resume of seed ++ RESUME_SET[k].
//
//   bun p01_diff.ts <tree root> <scratch> enum <maxLen> [opset]   exhaustive
//   bun p01_diff.ts <tree root> <scratch> random <n> <seed> <maxLen>
//   bun p01_diff.ts <tree root> <scratch> case <ops,comma,separated> [P0.1|X-1]
//
// Checks per case where the fold accepts:
//   P0.1  (only when hypotheses hold: no empty call id, no tool message carrying calls — true of
//         every message in ALPHABET by construction) host pending == SessionState.dangling, as lists.
//   X-1   the folded history is well paired: every tool message's tool_call_id is among the
//         tool_calls of the nearest preceding message that has tool_calls.
// Exit 1 if any checked property is violated (for `case`, only the named one), else 0.
import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";

const [root, scratch, mode, ...rest] = process.argv.slice(2);
if (!root || !scratch || !mode) throw new Error("usage: see header");
fs.mkdirSync(scratch, { recursive: true });
const { SessionJournal } = await import(path.resolve(root, "src/tui/src/session-journal.ts"));

const call = (id: string) => ({ id, name: "bash", arguments: "{}" });
const msg = (role: string, ids: string[], tcid: string) => ({ role, content: "", tool_calls: ids.map(call), tool_call_id: tcid, images: [] });
const ALPHABET = [
  msg("assistant", [], ""), msg("assistant", ["a"], ""), msg("assistant", ["a", "b"], ""), msg("assistant", ["b"], ""),
  msg("tool", [], "a"), msg("tool", [], "b"), msg("user", [], ""), msg("assistant", [], "a"),
  msg("user", ["a"], ""), msg("assistant", ["a", "a"], ""),
];
const SEED = [msg("system", [], ""), msg("user", [], "")];
const RESUME_SET = [
  [msg("assistant", ["a"], ""), msg("tool", [], "a"), msg("assistant", ["a"], "")],
  [msg("assistant", ["a"], ""), msg("tool", [], "a"), msg("assistant", ["b"], "")],
  [msg("assistant", ["a", "b"], ""), msg("tool", [], "a"), msg("tool", [], "b"), msg("assistant", ["b"], "")],
];

const journal = new SessionJournal(scratch, `p01-${process.pid}`, { onError: () => {} });
const j = journal as unknown as {
  openCallIds: string[]; historyMessages: number;
  recordAppended(e: unknown): number; recordReplaced(e: unknown): number;
};

function host(ops: number[]): string[] {
  j.openCallIds = []; // what the class does on a new seed
  j.historyMessages = 0;
  // the seed, as the host expands it: one append per message
  for (const m of SEED) j.recordAppended({ run_id: "r", step: 0, message: m, replaces_previous: false, digest_after: "x" });
  for (const op of ops) {
    if (op < 100) j.recordAppended({ run_id: "r", step: 1, message: ALPHABET[op], replaces_previous: false, digest_after: "x" });
    else if (op < 200) j.recordAppended({ run_id: "r", step: 1, message: ALPHABET[op - 100], replaces_previous: true, digest_after: "x" });
    else {
      const ms = op < 300 ? [...SEED, ALPHABET[op - 200]] : [...SEED, ...RESUME_SET[op - 300]];
      const n = j.recordReplaced({ run_id: "r", step: 1, reason: "resume", messages: ms, digest_after: "x" });
      if (n !== 1) throw new Error("recordReplaced did not append");
    }
  }
  return journal.pendingToolCalls;
}

// ---- case generation
let cases: number[][] = [];
let only: string | undefined;
if (mode === "enum") {
  const maxLen = Number(rest[0] ?? 3);
  const opset = rest[1] ? rest[1].split(",").map(Number)
    : [...ALPHABET.keys(), ...[...ALPHABET.keys()].map((i) => 100 + i), 201, 202, 300, 301, 302];
  let layer: number[][] = [[]];
  cases.push([]);
  for (let n = 1; n <= maxLen; n++) {
    const next: number[][] = [];
    for (const s of layer) for (const o of opset) next.push([...s, o]);
    cases.push(...next);
    layer = next;
  }
} else if (mode === "random") {
  const n = Number(rest[0]); let seed = Number(rest[1]); const maxLen = Number(rest[2]);
  const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff), seed / 0x80000000);
  const opset = [...ALPHABET.keys(), ...ALPHABET.keys(), ...[...ALPHABET.keys()].map((i) => 100 + i), 201, 202, 300, 301, 302];
  for (let k = 0; k < n; k++) {
    const len = 1 + Math.floor(rnd() * maxLen);
    cases.push(Array.from({ length: len }, () => opset[Math.floor(rnd() * opset.length)]));
  }
} else if (mode === "case") {
  cases = [rest[0] === "" ? [] : rest[0].split(",").map(Number)];
  only = rest[1];
} else throw new Error(`unknown mode ${mode}`);

// ---- run the fold
const modName = `p01fold_${process.pid}`;
const tmpl = fs.readFileSync(path.join(import.meta.dir, "fold_template.ail"), "utf8");
const lit = "[" + cases.map((c) => `[${c.join(", ")}]`).join(",\n   ") + "]";
// must sit inside the tree for pkg/ imports to resolve; removed after the run
const modDir = path.join(root, ".p01tmp");
fs.mkdirSync(modDir, { recursive: true });
const modFile = path.join(modDir, `${modName}.ail`);
fs.writeFileSync(modFile, tmpl.replace("__MODULE__", modName).replace("__CASES__", lit));
let raw = "";
try {
  raw = execFileSync("ailang", ["run", "--relax-modules", "--caps", "IO", "--entry", "main", modFile],
    { cwd: root, encoding: "utf8", maxBuffer: 1 << 30, stdio: ["ignore", "pipe", "pipe"] });
} catch (e: any) {
  process.stderr.write(String(e.stdout ?? "") + String(e.stderr ?? ""));
  process.exit(3);
} finally {
  fs.rmSync(modDir, { recursive: true, force: true });
}
const lines = raw.split("\n").filter((l) => /^[0-9,]*\|/.test(l));
if (lines.length !== cases.length) { console.error(`fold printed ${lines.length} lines for ${cases.length} cases`); process.stderr.write(raw.slice(0, 2000)); process.exit(3); }

function wellPaired(hist: string): boolean {
  let last: string[] | null = null;
  for (const tok of hist.split(" ")) {
    const [role, ids, tcid] = tok.split(":");
    if (role === "tool") { if (!last || !last.includes(tcid)) return false; }
    else if (ids !== "") last = ids.split(".");
  }
  return true;
}

const verdicts: Record<string, number> = {};
const bad: Record<string, string[]> = { "P0.1": [], "X-1": [] };
cases.forEach((ops, k) => {
  const [ix, verdict, dangling, count, hist] = lines[k].split("|");
  if (ix !== ops.join(",")) throw new Error(`order mismatch at ${k}`);
  verdicts[verdict] = (verdicts[verdict] ?? 0) + 1;
  if (verdict !== "accept") return;
  const h = host(ops);
  const fd = Number(count) === 0 ? [] : dangling.split(",");
  if (JSON.stringify(h) !== JSON.stringify(fd)) bad["P0.1"].push(`ops=[${ix}] host=${JSON.stringify(h)} fold=${JSON.stringify(fd)} history=${hist}`);
  if (!wellPaired(hist)) bad["X-1"].push(`ops=[${ix}] dangling=${JSON.stringify(fd)} history=${hist}`);
});
console.log(`cases: ${cases.length}; fold verdicts: ${JSON.stringify(verdicts)}`);
let fail = false;
for (const p of Object.keys(bad)) {
  if (only && p !== only) continue;
  console.log(`${p}: ${bad[p].length} violations`);
  for (const b of bad[p].slice(0, 8)) console.log(`  ${b}`);
  if (bad[p].length > 0) fail = true;
}
process.exit(fail ? 1 : 0);
