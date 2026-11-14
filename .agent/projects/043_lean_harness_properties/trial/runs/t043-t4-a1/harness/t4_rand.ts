// t4_rand.ts -- random-input check of P4.1, P4.2, X-1, X-2 and X-4 on the REAL chain functions
// (src/core/journal.ail:242-300).
//
// The generator is here (seeded mulberry32). It writes `t4_rand_cases.json`, runs the AILANG half
// (`t4_rand_eval.ail`), which decodes the messages with the real `messages_of_json` and evaluates
// the real `chain_digest_over` / `chain_digests_over` / `eval_chain_digest_over`, and then states
// each property here over those outputs. Nothing here computes a digest.
//
//   [T4_ROOT=<package root>] bun t4_rand.ts [seed] [cases] [maxLen]
//
// Exit 1 if any registered property (P4.1, P4.2a, P4.2b) or X-1/X-2 is violated on any case;
// exit 2 if the AILANG half failed to produce every case; 0 otherwise.

import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { dirname } from "node:path";

// The package root the AILANG half runs in: this directory (symlinked to the tree), or T4_ROOT
// (e.g. out/control-base, the negative control built by make_control.sh).
const here = process.env.T4_ROOT ?? dirname(new URL(import.meta.url).pathname);
const seed = Number(process.argv[2] ?? 1);
const nCases = Number(process.argv[3] ?? 300);
const maxLen = Number(process.argv[4] ?? 8);

function mulberry32(a: number) {
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(seed);
const int = (n: number) => Math.floor(rnd() * n);
const pick = <T>(xs: T[]): T => xs[int(xs.length)];

// Characters chosen to stress the frame: its own delimiters, digits (the length prefix), JSON
// escapes, interpolation markers, non-ASCII, astral and combining code points, control chars.
const atoms = [
  "a", "b", "z", " ", "0", "1", "9", ":", ";", "{", "}", "m{", "tc{", "im{", "tc-end;", "im-end;", "m-end;",
  "role:4:user;", "content:", "\"", "\\", "$", "${x}", "\n", "\t", "é", "é", "ß", "中", "😀", "\u0000", "\u001f",
  "make[3]", "make[0]",
];
function str(maxAtoms: number): string {
  const n = int(maxAtoms + 1);
  let s = "";
  for (let i = 0; i < n; i++) s += pick(atoms);
  return s;
}
function message() {
  const role = pick(["system", "user", "assistant", "tool", "", "x"]);
  const calls = Array.from({ length: pick([0, 0, 0, 1, 2, 3]) }, () => ({ id: str(2), name: str(2), arguments: str(3) }));
  const images = Array.from({ length: pick([0, 0, 0, 1, 2]) }, () => ({ source: str(3), mime: pick(["image/png", "image/jpeg", "", str(2)]) }));
  return { role, content: str(6), tool_calls: calls, tool_call_id: pick(["", "", str(2)]), images };
}
function base() {
  const kind = pick(["empty", "empty", "seed", "chain", "literal", "literal"]);
  const hex = Array.from({ length: 64 }, () => "0123456789abcdef"[int(16)]).join("");
  const value = kind === "literal" ? pick(["", `sha256:${hex}`, str(4)]) : "";
  return { kind, value };
}

// Near-miss variants for X-3: the same characters, moved across a field boundary, or one field
// changed by one atom. Each is a different message from its source (checked below by JSON).
type Msg = ReturnType<typeof message>;
function nearMiss(m: Msg): Msg {
  const c: Msg = JSON.parse(JSON.stringify(m));
  switch (int(7)) {
    case 0: // last code unit of content moves to the front of tool_call_id
      c.tool_call_id = c.content.slice(-1) + c.tool_call_id; c.content = c.content.slice(0, -1); break;
    case 1: // content moves into role
      c.role = c.role + c.content; c.content = ""; break;
    case 2: // an image is dropped, or one appears
      if (c.images.length) c.images.pop(); else c.images.push({ source: "", mime: "" }); break;
    case 3: // a call is dropped, or an empty one appears
      if (c.tool_calls.length) c.tool_calls.pop(); else c.tool_calls.push({ id: "", name: "", arguments: "" }); break;
    case 4: // image source and mime trade their boundary
      if (c.images.length) { const i = c.images[0]; i.mime = i.source.slice(-1) + i.mime; i.source = i.source.slice(0, -1); }
      else c.images.push({ source: "a", mime: "" }); break;
    case 5: // one atom appended to content
      c.content += pick(atoms); break;
    default: // content and tool_call_id swap
      [c.content, c.tool_call_id] = [c.tool_call_id, c.content];
  }
  return c;
}

const cases = Array.from({ length: nCases }, (_, i) => {
  const xs = Array.from({ length: int(maxLen + 1) }, message);
  // a third of the cases: ys is near-miss variants of xs, so X-3 sees adjacent pairs
  const ys = i % 3 === 2 ? xs.map(nearMiss) : Array.from({ length: int(maxLen + 1) }, message);
  return { id: String(i), base: base(), xs, ys };
});
writeFileSync(`${here}/t4_rand_cases.json`, JSON.stringify(cases));

const r = spawnSync("ailang", ["run", "--relax-modules", "--caps", "IO,FS", "--entry", "main", "t4_rand_eval.ail"], {
  cwd: here,
  encoding: "utf8",
  maxBuffer: 1 << 30,
});
const outs = r.stdout.split("\n").filter((l) => l.startsWith("{")).map((l) => JSON.parse(l));
if (outs.length !== nCases || outs.some((o) => o.fatal || o.error)) {
  console.log(`AILANG half: ${outs.length}/${nCases} cases; status ${r.status}`);
  for (const o of outs.filter((o) => o.fatal || o.error).slice(0, 5)) console.log(" ", JSON.stringify(o));
  console.log(r.stderr.split("\n").filter((l) => !l.startsWith("Warning: dependency") && !l.startsWith("Run 'ailang lock'")).join("\n").slice(0, 2000));
  process.exit(2);
}

type Tally = { checked: number; bad: number; first?: string };
const tallies: Record<string, Tally> = {};
const eq = (a: string[], b: string[]) => a.length === b.length && a.every((x, i) => x === b[i]);
function note(prop: string, kind: string, ok: boolean, witness: () => string) {
  const k = `${prop} base=${kind}`;
  const t = (tallies[k] ??= { checked: 0, bad: 0 });
  t.checked++;
  if (!ok) {
    t.bad++;
    t.first ??= witness();
  }
}

for (const o of outs) {
  const c = cases[Number(o.id)];
  const kind = c.base.kind;
  const w = () => `case ${o.id} (seed ${seed}): |xs|=${o.n_xs} |ys|=${o.n_ys} base=${JSON.stringify(o.base).slice(0, 40)}`;
  const n = o.n_xs + o.n_ys;
  // P4.1 -- the registered statement, verbatim.
  note("P4.1 ", kind, eq(o.digests_ms, [...o.digests_xs, ...o.digests_ys_from_over_xs]), w);
  // P4.2
  note("P4.2a", kind, o.digests_ms.length === n, w);
  if (n > 0) note("P4.2b", kind, o.digests_ms[n - 1] === o.over_ms, w);
  // X-1: every intermediate value is the chain over that prefix.
  note("X-1  ", kind, eq(o.digests_ms, o.over_prefixes), w);
  // X-2: the evaluator's pinned copy agrees with the candidate.
  note("X-2  ", kind, o.twin_over_ms === o.over_ms, w);
  // X-4 (diagnostic, not a property, never fails the run): does the output equal the chain from
  // the EMPTY base? A correct chain_digests_over would make this "violated" on every case with a
  // base other than the empty one and n > 0; zero violations there means the base is ignored.
  note("X-4 diag digests(b,ms)==digests(empty,ms)", kind, eq(o.digests_ms, o.digests_ms_from_empty), w);
  // The wire form round-trips as the host reads it.
  note("wire ", kind, eq(JSON.parse(o.digests_json), o.digests_ms), w);
}

// X-3: distinct messages give distinct one-step digests, and distinct lists give distinct
// chain digests, from the empty base (over every case at once).
const stepSeen = new Map<string, string>();
const listSeen = new Map<string, string>();
for (const o of outs) {
  const c = cases[Number(o.id)];
  const ms = [...c.xs, ...c.ys];
  ms.forEach((m, i) => {
    const key = JSON.stringify(m);
    const d = o.after_each_from_empty[i];
    const prev = stepSeen.get(d);
    note("X-3 step", "empty", prev === undefined || prev === key, () => `${prev} vs ${key} share ${d}`);
    stepSeen.set(d, key);
  });
  const key = JSON.stringify(ms);
  const prev = listSeen.get(o.over_ms_from_empty);
  note("X-3 list", "empty", prev === undefined || prev === key, () => `${prev} vs ${key}`);
  listSeen.set(o.over_ms_from_empty, key);
}
console.log(`X-3 distinct messages: ${new Set([...stepSeen.values()]).size}, distinct step digests: ${stepSeen.size}; distinct lists: ${new Set([...listSeen.values()]).size}, distinct list digests: ${listSeen.size}`);

let failed = false;
for (const [k, t] of Object.entries(tallies).sort()) {
  console.log(`${k} checked=${t.checked} violated=${t.bad}${t.bad ? ` first: ${t.first}` : ""}`);
  if (t.bad && !k.startsWith("X-4")) failed = true;
}
console.log(`seed=${seed} cases=${nCases} maxLen(xs)=maxLen(ys)=${maxLen}`);
process.exit(failed ? 1 : 0);
