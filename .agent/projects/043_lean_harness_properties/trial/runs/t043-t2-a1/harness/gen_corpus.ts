// gen_corpus.ts — the inputs for the T2 differential test (herdr failure vocabulary).
//
//   bun gen_corpus.ts <out.json> [--fuzz N] [--seed S] [--maxtok L]
//
// Writes a JSON array of {code, err, gen} where `code` is an exit code, `err` is a stderr string
// and `gen` names the generator that produced it. Both halves (ts_twin.ts and ail_twin.ail) read
// the SAME file, so no input is re-encoded on either side: bun reads it with JSON.parse, ailang
// receives it as the entry's argument through `--args-file` (decoded by the runtime, not by
// std/json's `decode`, which is itself under test here).
//
// Three generators, all deterministic:
//
//   G1 grammar  — exit codes x herdr-envelope grammar: code value x error-object form x envelope
//                 form x whitespace wrapper x prefix/suffix. Every combination, then de-duplicated.
//   G2 mutate   — the measured herdr envelopes (MEASUREMENTS-2026-08-31, wake-waiter.test.ts,
//                 types.ail's vectors) with every single-character deletion, and every insertion
//                 and replacement from a small alphabet, at every position.
//   G3 fuzz     — seeded random concatenations of JSON-ish tokens, up to --maxtok tokens.
//
// Inputs are restricted to valid Unicode (no lone surrogates): production stderr is decoded as
// UTF-8 on both sides (wake-waiter's `toString("utf8")`, the bash tool's JSON envelope), so a lone
// surrogate cannot reach either function.

import * as fs from "fs";

type Case = { code: number; err: string; gen: string };

const args = process.argv.slice(2);
const outPath = args[0];
if (!outPath) throw new Error("usage: bun gen_corpus.ts <out.json> [--fuzz N] [--seed S] [--maxtok L]");
const opt = (name: string, dflt: number): number => {
  const i = args.indexOf(name);
  return i >= 0 ? Number(args[i + 1]) : dflt;
};
const FUZZ_N = opt("--fuzz", 200000);
const SEED = opt("--seed", 43);
const MAXTOK = opt("--maxtok", 12);

const seen = new Set<string>();
const corpus: Case[] = [];
const add = (code: number, err: string, gen: string): void => {
  const k = `${code}\u0001${err}`;
  if (seen.has(k)) return;
  seen.add(k);
  corpus.push({ code, err, gen });
};

// ------------------------------------------------------------------------------------------------
// G1 grammar
// ------------------------------------------------------------------------------------------------

const EXIT_CODES = [-1, 0, 1, 2, 3, 124, 137, 255];

// herdr codes seen in the tree, plus near-misses of `agent_not_found`.
const CODES = [
  "agent_not_found",
  "server_not_running",
  "agent_not_running",
  "timeout",
  "pane_not_found",
  "plugin_pane_not_found",
  "plugin_not_found",
  "agent_prompt_stalled",
  "",
  "AGENT_NOT_FOUND",
  "agent_not_found ",
  " agent_not_found",
  "_not_found",
  "not_found",
  "agent_not_foundx",
  "xagent_not_found",
  "agent_not_found\n",
];

const jstr = (s: string): string => JSON.stringify(s);
// The same string, with its first character written as a \u escape: equal after JSON decoding.
const jstrEsc = (s: string): string =>
  s === "" ? '""' : `"\\u${s.charCodeAt(0).toString(16).padStart(4, "0")}${jstr(s.slice(1)).slice(1)}`;

const VALUES: string[] = [];
for (const c of CODES) {
  VALUES.push(jstr(c));
  VALUES.push(jstrEsc(c));
}
VALUES.push("1", "null", "true", "{}", "[]", '["agent_not_found"]', '{"code":"agent_not_found"}');

const ERROR_OBJECTS = (v: string): string[] => [
  `{"code":${v},"message":"x"}`,
  `{"message":"x","code":${v}}`,
  `{"code":${v}}`,
  `{"code":${v},"message":"nested herdr"}`,
  `{"code":"timeout","code":${v}}`,
  `{"code":${v},"code":"timeout"}`,
];
const ERROR_OBJECTS_EXTRA = ["{}", '"agent_not_found"', "null", "[]", '{"Code":"agent_not_found"}'];

const ENVELOPES = (e: string): string[] => [
  `{"error":${e}}`,
  `{"error":${e},"id":"cli:agent:get"}`,
  `{"id":"cli:agent:get","error":${e}}`,
  `{ "error": ${e} }`,
  `{"error" :${e}}`,
  `{\n  "error": ${e}\n}`,
  `{"\\u0065rror":${e}}`,
  `{"error":${e},"error":{"code":"timeout"}}`,
  `{"error":{"code":"timeout"},"error":${e}}`,
  `[{"error":${e}}]`,
  `{"result":{"error":${e}}}`,
];

const WRAPS = (s: string): string[] => [
  s,
  s + "\n",
  "\n" + s,
  " " + s + " ",
  "\t" + s + "\r\n",
  "﻿" + s,
  " " + s,
  s + " ",
  "\u000b" + s,
  "\u000c" + s,
];

const AFFIXES = (s: string): string[] => [
  s,
  s + "x",
  s + "killed by SIGTERM",
  s + "\nkilled by SIGKILL",
  "Error: " + s,
  s + "\n" + s,
  s + "}",
  s + ",",
  s + '{"error":{"code":"timeout"}}',
];

// The full cross product is large; the code values meet every envelope, but the wrappers and
// affixes are applied to the four "core" error-object forms only, so the corpus stays ~10^5.
const g1Strings = new Set<string>();
for (const v of VALUES) {
  const eos = ERROR_OBJECTS(v);
  for (let ei = 0; ei < eos.length; ei++) {
    for (const env of ENVELOPES(eos[ei])) {
      g1Strings.add(env);
      if (ei < 3) for (const w of WRAPS(env)) for (const a of AFFIXES(w)) g1Strings.add(a);
    }
  }
}
for (const e of ERROR_OBJECTS_EXTRA) for (const env of ENVELOPES(e)) g1Strings.add(env);
// Non-JSON shapes (K6 territory) and the measured plain-text ones.
for (const s of [
  "",
  " ",
  "\n",
  "herdr agent commands:",
  "error: nested herdr is disabled by default.",
  "--current requires HERDR_PANE_ID",
  "agent_not_found",
  "killed by SIGTERM",
  "null",
  "1",
  '"agent_not_found"',
  "[]",
  "{}",
  '{"error"',
  '{"error":',
  '{"error":{"code":"agent_not_found"',
  '{"id":"x"}',
  '{"error":null}',
  '{"error":"agent_not_found"}',
  "{'error':{'code':'agent_not_found'}}",
  '{error:{code:"agent_not_found"}}',
  '{"error":{"code":"agent_not_found",}}',
  '{"error":{"code":"agent_not_found"},}',
  '/*c*/{"error":{"code":"agent_not_found"}}',
  '{"error":{"code":"agent_not_found"}}//c',
  '{"error":{"code":"agent_not_found","n":NaN}}',
  '{"error":{"code":"agent_not_found","n":01}}',
  '{"error":{"code":"agent_not_found","n":1e999}}',
  '{"error":{"code":"agent_not_found","n":-}}',
  '{"error":{"code":"agent_not_found","s":"\\x41"}}',
  '{"error":{"code":"agent_not_found","s":"\\ud83d\\ude00"}}',
  '{"error":{"code":"agent_not_found","s":"\\udc00"}}',
  '{"error":{"code":"agent_not_found","s":"a\tb"}}',
  '{"error":{"code":"agent_not_found","s":"a\nb"}}',
  '{"error":{"code":"agent_\\/not_found"}}',
  '{"error":{"code":"agent\\u005Fnot\\u005ffound"}}',
]) {
  g1Strings.add(s);
}
for (const s of g1Strings) for (const k of EXIT_CODES) add(k, s, "G1");

// ------------------------------------------------------------------------------------------------
// G2 single-edit mutations of the measured envelopes
// ------------------------------------------------------------------------------------------------

const BASES = [
  '{"error":{"code":"agent_not_found","message":"x"},"id":"cli:agent:get"}',
  '{"error":{"code":"agent_not_found","message":"x"}}',
  '{"error":{"code":"server_not_running","message":"x"}}',
  '{"error":{"code":"timeout","message":"timed out"}}',
  '{"error":{"code":"agent_not_running","message":"x"}}',
  "--current requires HERDR_PANE_ID",
  "error: nested herdr is disabled by default.",
];
const EDIT_ALPHABET = [" ", "\n", "x", "{", "}", "[", "]", '"', "\\", ",", ":", "_", "﻿", " "];
const G2_EXITS = [-1, 1, 2];
for (const b of BASES) {
  const muts = new Set<string>([b]);
  for (let i = 0; i <= b.length; i++) {
    if (i < b.length) muts.add(b.slice(0, i) + b.slice(i + 1));
    for (const ch of EDIT_ALPHABET) {
      muts.add(b.slice(0, i) + ch + b.slice(i));
      if (i < b.length) muts.add(b.slice(0, i) + ch + b.slice(i + 1));
    }
  }
  for (const m of muts) for (const k of G2_EXITS) add(k, m, "G2");
}

// ------------------------------------------------------------------------------------------------
// G3 seeded token fuzz
// ------------------------------------------------------------------------------------------------

function mulberry32(a: number): () => number {
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const TOKENS = [
  "{", "}", "[", "]", ":", ",", '"', "\\", " ", "\n", "\t",
  '"error"', '"code"', '"message"', '"id"', "error", "code",
  '"agent_not_found"', '"server_not_running"', '"pane_not_found"', '"timeout"', '""',
  "agent_not_found", "_not_found", "nested herdr", '{"error"', '{"error":', '{"code":',
  "null", "true", "1", "-1", "0", "x", "\\u0065", "\\n", "﻿", " ",
];
const FUZZ_EXITS = [-1, 0, 1, 2, 3, 137];
const rnd = mulberry32(SEED);
for (let n = 0; n < FUZZ_N; n++) {
  const len = 1 + Math.floor(rnd() * MAXTOK);
  let s = "";
  for (let i = 0; i < len; i++) s += TOKENS[Math.floor(rnd() * TOKENS.length)];
  // Bias toward well-formed envelopes: half the time wrap the tokens as an error code or message.
  const r = rnd();
  if (r < 0.25) s = `{"error":{"code":${s}}}`;
  else if (r < 0.5) s = `{"error":{"code":"agent_not_found","message":${s}}}`;
  add(FUZZ_EXITS[Math.floor(rnd() * FUZZ_EXITS.length)], s, "G3");
}

// ------------------------------------------------------------------------------------------------
// G4 valid JSON: the measured `agent_not_found` envelope carrying one extra VALID JSON value (in
// the error object, or beside it), and the envelope wrapped in one whitespace-like code point.
// Every case here is JSON that `JSON.parse` accepts after `trim()` (or a single wrapper char).
// ------------------------------------------------------------------------------------------------

const JSON_VALUES = [
  "0", "-0", "1", "-1", "1.5", "1e2", "1E+2", "1e-2", "0.1e-5", "1e308", "1e309", "1e999", "-1e999",
  "4.9e-324", "1e-400", "9007199254740993", "123456789012345678901234567890",
  "true", "false", "null", '""', '"x"', '"\\b\\f\\n\\r\\t\\/\\\\\\""', '"\\u0000"', '"\\u001f"',
  '"\\ud83d\\ude00"', '"é"', '"😀"', '" "', '"\u007f"',
  "[]", "{}", "[1,[2,[3]]]", '{"a":{"b":{"c":null}}}', "[".repeat(64) + "]".repeat(64),
  "[".repeat(600) + "]".repeat(600), '{"code":"timeout"}', '{"error":{"code":"timeout"}}',
];
const BASE_NF = '{"code":"agent_not_found","message":"x"';
for (const v of JSON_VALUES) {
  for (const s of [`{"error":${BASE_NF},"extra":${v}}}`, `{"error":${BASE_NF}},"extra":${v}}`, `{"error":${BASE_NF}},"id":${v}}`]) {
    for (const k of [1, 3]) add(k, s, "G4");
  }
}
const ENVELOPE_NF = `{"error":${BASE_NF}}}`;
for (let cp = 0; cp <= 0x3000; cp++) {
  const ch = String.fromCodePoint(cp);
  if (cp > 0x20 && !/\s/u.test(ch) && cp !== 0x85 && cp !== 0x180e && cp !== 0x200b) continue;
  for (const s of [ch + ENVELOPE_NF, ENVELOPE_NF + ch]) add(1, s, "G4");
}
add(1, "﻿" + ENVELOPE_NF, "G4");
add(1, ENVELOPE_NF + "﻿", "G4");

// ------------------------------------------------------------------------------------------------

// Lone surrogates cannot reach either function in production (see header); drop any.
const valid = corpus.filter((c) => !/[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/.test(c.err));
fs.writeFileSync(outPath, JSON.stringify(valid));
const by: Record<string, number> = {};
for (const c of valid) by[c.gen] = (by[c.gen] ?? 0) + 1;
process.stderr.write(
  `corpus: ${valid.length} cases (${Object.entries(by).map(([g, n]) => `${g} ${n}`).join(", ")}), ` +
    `max stderr length ${valid.reduce((m, c) => Math.max(m, c.err.length), 0)}, seed ${SEED}, fuzz ${FUZZ_N}, maxtok ${MAXTOK}\n`,
);
