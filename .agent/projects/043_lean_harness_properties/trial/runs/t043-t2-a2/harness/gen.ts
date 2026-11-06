// gen.ts — case generators for the T2 differential test. Writes cases to stdout as
//   <id> TAB <exit_code> TAB <base64 of stderr's UTF-8>
// which ts_eval.ts and ail_eval.ail both read. Every generator is deterministic.
//
//   bun gen.ts structured            exit codes x (envelopes x code values) + plain-text stderrs
//   bun gen.ts tokens <maxlen>       every sequence of 0..maxlen tokens from TOKENS, exits {-1,1,2,0}
//   bun gen.ts chunks <maxlen>       every sequence of 0..maxlen chunks from CHUNKS, exits {1,-1}
//   bun gen.ts random <n> <seed>     random herdr-like JSON, random whitespace, then 0..3 mutations
//   bun gen.ts one <witness.json>    a single case from {"exit":..,"stderr":..}

export const EXITS = [-2147483648, -256, -2, -1, 0, 1, 2, 3, 124, 127, 128, 130, 137, 143, 255, 256, 2147483647];

// error.code values, as raw JSON text (so escapes stay escapes).
export const CODE_VALUES: string[] = [
  `"agent_not_found"`, `"pane_not_found"`, `"workspace_not_found"`, `"tab_not_found"`,
  `"session_not_found"`, `"plugin_not_found"`, `"_not_found"`, `"not_found"`, `"agent_not_found_yet"`,
  `"xagent_not_found"`, `"AGENT_NOT_FOUND"`, `"agent_not_found "`, `" agent_not_found"`,
  `"agent_not_found\\n"`, `"agent\\u005fnot_found"`, `"\\u0061gent_not_found"`, `"agent_not_f\\u006fund"`,
  `"server_not_running"`, `"timeout"`, `"agent_prompt_stalled"`, `"nested herdr"`, `""`,
  `1`, `0`, `null`, `true`, `{}`, `[]`, `["agent_not_found"]`, `{"code":"agent_not_found"}`,
];

const BOM = "﻿";
const NBSP = " ";
const LS = " ";

// Envelopes: functions of the code's JSON text. Name -> builder.
export const ENVELOPES: Array<[string, (c: string) => string]> = [
  ["plain", (c) => `{"error":{"code":${c},"message":"x"}}`],
  ["id_after", (c) => `{"error":{"code":${c},"message":"x"},"id":"cli:agent:get"}`],
  ["id_before", (c) => `{"id":"cli:agent:get","error":{"code":${c},"message":"x"}}`],
  ["spaced", (c) => `{ "error": { "code": ${c}, "message": "x" } }`],
  ["pretty", (c) => `{\n  "error": {\n    "code": ${c},\n    "message": "x"\n  }\n}`],
  ["space_before_colon", (c) => `{"error" : {"code" : ${c}}}`],
  ["msg_first", (c) => `{"error":{"message":"x","code":${c}}}`],
  ["trail_nl", (c) => `{"error":{"code":${c},"message":"x"}}\n`],
  ["trail_crlf", (c) => `{"error":{"code":${c},"message":"x"}}\r\n`],
  ["lead_ws", (c) => `  \n\t{"error":{"code":${c},"message":"x"}}`],
  ["bom", (c) => `${BOM}{"error":{"code":${c},"message":"x"}}`],
  ["trail_nbsp", (c) => `{"error":{"code":${c},"message":"x"}}${NBSP}`],
  ["trail_ls", (c) => `{"error":{"code":${c},"message":"x"}}${LS}`],
  ["lead_nbsp", (c) => `${NBSP}{"error":{"code":${c},"message":"x"}}`],
  ["prefix_line", (c) => `warning: config reloaded\n{"error":{"code":${c},"message":"x"}}`],
  ["signal_suffix", (c) => `{"error":{"code":${c},"message":"x"}}killed by SIGTERM`],
  ["signal_suffix_nl", (c) => `{"error":{"code":${c},"message":"x"}}\nkilled by SIGKILL`],
  ["trail_garbage", (c) => `{"error":{"code":${c},"message":"x"}} trailing`],
  ["two_objects", (c) => `{"error":{"code":${c},"message":"x"}}{"error":{"code":"timeout"}}`],
  ["two_lines", (c) => `{"error":{"code":${c},"message":"x"}}\n{"error":{"code":"timeout"}}`],
  ["msg_nested_herdr", (c) => `{"error":{"code":${c},"message":"nested herdr is disabled"}}`],
  ["nested_herdr_prefix", (c) => `nested herdr\n{"error":{"code":${c},"message":"x"}}`],
  ["dup_code_last", (c) => `{"error":{"code":"timeout","code":${c}}}`],
  ["dup_code_first", (c) => `{"error":{"code":${c},"code":"timeout"}}`],
  ["dup_error_last", (c) => `{"error":{"code":"timeout"},"error":{"code":${c}}}`],
  ["dup_error_first", (c) => `{"error":{"code":${c}},"error":{"code":"timeout"}}`],
  ["escaped_error_key", (c) => `{"err\\u006fr":{"code":${c}}}`],
  ["escaped_code_key", (c) => `{"error":{"c\\u006fde":${c}}}`],
  ["upper_error_key", (c) => `{"Error":{"code":${c}}}`],
  ["upper_code_key", (c) => `{"error":{"Code":${c}}}`],
  ["under_result", (c) => `{"result":{"error":{"code":${c}}}}`],
  ["in_array", (c) => `[{"error":{"code":${c}}}]`],
  ["trailing_comma", (c) => `{"error":{"code":${c},},}`],
  ["truncated", (c) => `{"error":{"code":${c}`],
  ["big_number", (c) => `{"error":{"code":${c},"n":1e400}}`],
  ["huge_int", (c) => `{"error":{"code":${c},"n":123456789012345678901234567890}}`],
  ["neg_zero", (c) => `{"error":{"code":${c},"n":-0}}`],
  ["lone_surrogate", (c) => `{"error":{"code":${c},"message":"\\ud800"}}`],
  ["nul_escape", (c) => `{"error":{"code":${c},"message":"\\u0000"}}`],
  ["raw_tab_in_string", (c) => `{"error":{"code":${c},"message":"a\tb"}}`],
  ["raw_nl_in_string", (c) => `{"error":{"code":${c},"message":"a\nb"}}`],
  ["slash_escape", (c) => `{"error":{"code":${c},"message":"a\\/b"}}`],
  ["bad_escape", (c) => `{"error":{"code":${c},"message":"a\\qb"}}`],
  ["deep_message", (c) => `{"error":{"code":${c},"message":${"[".repeat(200)}${"]".repeat(200)}}}`],
  ["very_deep_message", (c) => `{"error":{"code":${c},"message":${"[".repeat(5000)}${"]".repeat(5000)}}}`],
  ["comment_after", (c) => `{"error":{"code":${c}}} // note`],
  ["single_quotes", (c) => `{'error':{'code':${c}}}`],
  ["error_null_then", (c) => `{"error":null,"x":{"error":{"code":${c}}}}`],
  // Leniencies inside the document (not trailing): number and literal syntax JSON forbids.
  ["lz_number", (c) => `{"error":{"code":${c},"n":01}}`],
  ["plus_number", (c) => `{"error":{"code":${c},"n":+1}}`],
  ["dot_number", (c) => `{"error":{"code":${c},"n":.5}}`],
  ["trailing_dot_number", (c) => `{"error":{"code":${c},"n":1.}}`],
  ["nan", (c) => `{"error":{"code":${c},"n":NaN}}`],
  ["infinity", (c) => `{"error":{"code":${c},"n":Infinity}}`],
  ["hex_number", (c) => `{"error":{"code":${c},"n":0x1}}`],
  ["unquoted_key", (c) => `{"error":{code:${c}}}`],
  ["single_quoted_value", (c) => `{"error":{"code":${c},"m":'x'}}`],
  ["inner_comment", (c) => `{"error":{"code":${c} /* c */}}`],
  ["x_escape", (c) => `{"error":{"code":${c},"m":"\x41"}}`],
  ["capital_true", (c) => `{"error":{"code":${c},"m":True}}`],
  ["missing_colon", (c) => `{"error":{"code" ${c}}}`],
  ["missing_comma", (c) => `{"error":{"code":${c} "m":"x"}}`],
  ["emoji_message", (c) => `{"error":{"code":${c},"message":"\ud83d\ude00 😀 é"}}`],
];

export const PLAIN: string[] = [
  "", " ", "\n", "\r\n", "\t", BOM, NBSP, "usage", "herdr agent commands:",
  "error: nested herdr is disabled by default.", "--current requires HERDR_PANE_ID",
  "killed by SIGTERM", "killed by SIGKILL", "timeout after 30002ms", "agent_not_found", "pane_not_found",
  "null", "true", "false", "1", "0", "-0", "1e400", `"agent_not_found"`, `"x_not_found"`, "[]", "{}", "[1]",
  `{"error":null}`, `{"error":"agent_not_found"}`, `{"error":{}}`, `{"error":[]}`, `{"error":1}`,
  `{"error":{"code":"agent_not_found"`, `{"error"`, `{"error"}`, `{"result":{"agent":{}}}`,
  `{"id":"x","result":{"agent":{"agent_status":"idle"}}}`, `not json {"error":{"code":"agent_not_found"}}`,
];

export function structured(): Array<[number, string, string]> {
  const stderrs: Array<[string, string]> = PLAIN.map((s, i) => [s, `plain#${i}`]);
  for (const [name, env] of ENVELOPES) for (const c of CODE_VALUES) stderrs.push([env(c), `${name}:${c}`]);
  stderrs.push([`{"error":{"message":"x"}}`, "no_code"]);
  const cases: Array<[number, string, string]> = [];
  for (const e of EXITS) for (const [s, l] of stderrs) cases.push([e, s, l]);
  return cases;
}

// Token alphabet for the exhaustive short-sequence generator.
export const TOKENS: string[] = [
  `{`, `}`, `"error"`, `"code"`, `:`, `,`, `"agent_not_found"`, `"pane_not_found"`, `"timeout"`,
  ` `, `\n`, `nested herdr`, BOM, `null`,
];

export function tokens(maxLen: number): Array<[number, string]> {
  const cases: Array<[number, string]> = [];
  const exits = [-1, 0, 1, 2];
  const rec = (prefix: string, left: number): void => {
    for (const e of exits) cases.push([e, prefix]);
    if (left === 0) return;
    for (const t of TOKENS) rec(prefix + t, left - 1);
  };
  rec("", maxLen);
  return cases;
}

// Chunk alphabet: five chunks make a whole herdr envelope, so every short envelope, broken
// envelope and envelope-plus-noise up to five chunks is enumerated.
export const CHUNKS: string[] = [
  `{"error":`, `{ "error":`, `{"id":"x","error":`, `{"code":`, `"code":`, `"agent_not_found"`,
  `"pane_not_found"`, `"timeout"`, `}`, `,`, `\n`, BOM, `nested herdr`, `x`,
];

export function chunks(maxLen: number): Array<[number, string]> {
  const cases: Array<[number, string]> = [];
  const exits = [1, -1];
  const rec = (prefix: string, left: number): void => {
    for (const e of exits) cases.push([e, prefix]);
    if (left === 0) return;
    for (const t of CHUNKS) rec(prefix + t, left - 1);
  };
  rec("", maxLen);
  return cases;
}

// Mulberry32: small, seedable, deterministic.
export function prng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const WS = ["", "", "", " ", "\n", "\t", "\r\n", "  "];
const WS_EXOTIC = [BOM, NBSP, LS, "\u3000", "\u000B", "\u000C", "\u0085"];
const KEYS = ["error", "code", "message", "id", "result", "err\\u006fr", "c\\u006fde", "Error"];
const STR_VALUES = CODE_VALUES.filter((v) => v.startsWith(`"`));
const SUFFIXES = ["", "", "", "\n", "killed by SIGTERM", "\nkilled by SIGKILL", " x", "}", "{}", "\u0000"];
const PREFIXES = ["", "", "", "warning\n", "nested herdr ", "x", "\n", "{"];

export function random(n: number, seed: number): Array<[number, string]> {
  const r = prng(seed);
  const pick = <T,>(xs: T[]): T => xs[Math.floor(r() * xs.length)];
  // JSON whitespace, and 1 time in 40 a character JS's trim() strips but JSON does not allow.
  const ws = (): string => (r() < 0.025 ? pick(WS_EXOTIC) : pick(WS));
  const value = (depth: number): string => {
    const k = r();
    if (depth >= 3 || k < 0.45) return pick(CODE_VALUES);
    if (k < 0.85) return object(depth + 1);
    return `[${ws()}${value(depth + 1)}${ws()}]`;
  };
  const object = (depth: number): string => {
    const m = Math.floor(r() * 3) + (depth === 0 ? 1 : 0);
    const members: string[] = [];
    for (let i = 0; i < m; i++) {
      const key = depth === 0 && i === 0 && r() < 0.7 ? "error" : depth === 1 && r() < 0.6 ? "code" : pick(KEYS);
      const v = depth === 0 && key === "error" && r() < 0.8 ? `{${ws()}"code"${ws()}:${ws()}${pick(STR_VALUES)}${ws()}}` : value(depth);
      members.push(`${ws()}"${key}"${ws()}:${ws()}${v}${ws()}`);
    }
    return `{${members.join(",")}}`;
  };
  const mutate = (s: string): string => {
    if (s.length === 0) return s;
    const i = Math.floor(r() * s.length);
    const k = r();
    if (k < 0.33) return s.slice(0, i) + s.slice(i + 1);
    if (k < 0.66) return s.slice(0, i) + pick(["{", "}", `"`, ",", ":", " ", "\\", "\n", BOM, "_not_found"]) + s.slice(i);
    return s.slice(0, i) + s.slice(i, i + 1).toUpperCase() + s.slice(i + 1);
  };
  const cases: Array<[number, string]> = [];
  for (let i = 0; i < n; i++) {
    let s = pick(PREFIXES) + ws() + object(0) + ws() + pick(SUFFIXES);
    const muts = r() < 0.7 ? 0 : 1 + Math.floor(r() * 3);
    for (let j = 0; j < muts; j++) s = mutate(s);
    cases.push([pick(EXITS), s]);
  }
  return cases;
}

const b64 = (s: string): string => Buffer.from(s, "utf8").toString("base64");

export function emit(cases: Array<[number, string, string?]>): string {
  return cases.map(([e, s], i) => `${i}\t${e}\t${b64(s)}`).join("\n") + "\n";
}

if (import.meta.main) {
  const [mode, a, b] = process.argv.slice(2);
  let cases: Array<[number, string, string?]>;
  if (mode === "structured") cases = structured();
  else if (mode === "tokens") cases = tokens(Number(a ?? 3));
  else if (mode === "chunks") cases = chunks(Number(a ?? 3));
  else if (mode === "random") cases = random(Number(a ?? 10000), Number(b ?? 1));
  else if (mode === "one") {
    const w = JSON.parse(await Bun.file(a).text()) as { exit: number; stderr: string };
    cases = [[w.exit, w.stderr]];
  } else throw new Error("usage: bun gen.ts structured | tokens <maxlen> | random <n> <seed> | one <witness.json>");
  process.stdout.write(emit(cases));
  // Optional side file: one label per case (the structured generator names the envelope and
  // code value), for compare.ts's per-label table.
  if (process.env.GEN_LABELS) await Bun.write(process.env.GEN_LABELS, cases.map(([, , l], i) => `${i}\t${l ?? mode}`).join("\n") + "\n");
}
