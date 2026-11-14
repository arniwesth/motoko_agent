// gen.ts — inputs for the T2 differential test. Deterministic (fixed seed).
//   bun gen.ts <outdir> [randomCount]
// Writes <outdir>/cases.json ({cases:[{code,err}]}, for ailang --args-file and bun) and
// <outdir>/cases.hex (<code>\t<hex of UTF-8 stderr>, for the Lean model).
import * as fs from "fs";

const out = process.argv[2];
const nRandom = Number(process.argv[3] ?? "20000");

const codes = [-1, 0, 1, 2, 3, 124, 127, 255];
const errCodes = [
  `"agent_not_found"`, `"pane_not_found"`, `"workspace_not_found"`, `"_not_found"`, `"not_found"`,
  `"server_not_running"`, `"timeout"`, `""`, `"agent_not_found "`, `"Agent_not_found"`,
  `"agent\\u005fnot_found"`, `"agent_not_found\\u0000"`, `"nested herdr"`, `"\\ud800_not_found"`,
  `"\\ud83d\\ude00"`, `"é_not_found"`, `5`, `null`, `true`, `["agent_not_found"]`, `{"code":"agent_not_found"}`,
];
const templates: ((c: string) => string)[] = [
  (c) => `{"error":{"code":${c},"message":"x"}}`,
  (c) => `{"error":{"code":${c},"message":"no change"},"id":"cli:agent:prompt"}`,
  (c) => `{"id":"cli:agent:get","error":{"code":${c}}}`,
  (c) => `{ "error": { "code": ${c} } }`,
  (c) => `{\n  "error": {\n    "code": ${c},\n    "message": "x"\n  }\n}`,
  (c) => `{"error":{"message":"x","code":${c}}}`,
  (c) => `{"error":{"code":${c},"code":"timeout"}}`,
  (c) => `{"error":{"code":"timeout","code":${c}}}`,
  (c) => `{"error":{"code":${c}},"error":{"code":"timeout"}}`,
  (c) => `{"error":{"code":"timeout"},"error":{"code":${c}}}`,
  (c) => `{"error":{"code":${c},"message":"error: nested herdr is disabled by default."}}`,
  (c) => `{"error":{"code":${c},"message":"a \\"{\\"error\\"\\" b"}}`,
  (c) => `{"error" :{"code":${c}}}`,
  (c) => `{"error":{"code" : ${c}}}`,
  (c) => `[{"error":{"code":${c}}}]`,
  (c) => `{"result":{"error":{"code":${c}}}}`,
  (c) => `{"error":{"code":${c}}`,
  (c) => `{"error":{"code":${c},}}`,
  (c) => `{"error":{"code":${c}}}x`,
  (c) => `{"error":{"code":${c}}}{"error":{"code":"timeout"}}`,
  (c) => `{"error":{"code":${c}},"n":01}`,
  (c) => `{"error":{"code":${c}},"n":-0.5e+3}`,
  (c) => `{"error":{"code":${c}},"n":1.}`,
  (c) => `{"error":{"code":${c}},"n":NaN}`,
  // Model fix 3's boundary: float64's largest magnitude is 2^1024 - 2^970 ~ 1.7976931348623158079e308.
  (c) => `{"error":{"code":${c}},"n":1e999}`,
  (c) => `{"error":{"code":${c}},"n":-2e308}`,
  (c) => `{"error":{"code":${c}},"n":1.7976931348623157e308}`,
  (c) => `{"error":{"code":${c}},"n":1.7976931348623158e308}`,
  (c) => `{"error":{"code":${c}},"n":1.7976931348623159e308}`,
  (c) => `{"error":{"code":${c}},"n":179769313486231580793728971405303415079934132710037826936173778980444968292764750946647368169e216}`,
  (c) => `{"error":{"code":${c}},"n":179769313486231580793728971405303415079934132710037826936173778980444968292764750946647368170e216}`,
  (c) => `{"error":{"code":${c}},"n":0.00017976931348623159e312}`,
  (c) => `{"error":{"code":${c}},"n":1e-99999}`,
  (c) => `{"error":{"code":${c}},"n":0e99999}`,
  (c) => `{"error":{"code":${c}},"n":1e+308}`,
  (c) => `{"error":{"code":${c}},"n":10e307}`,
  (c) => `{"error":{"code":${c}},"n":100e307}`,
  (c) => `{"error":{"code":${c}},"s":"a\tb"}`,
  (c) => `{"error":{"code":${c}},"s":"a\\x"}`,
  (c) => `{"error":{"code":${c}},"s":"\\u12"}`,
  (c) => `{"error":{"code":${c}},"s":"\\/\\b\\f\\n\\r\\t\\"\\\\"}`,
  (c) => `{'error':{'code':${c}}}`,
  (c) => `{error:{code:${c}}}`,
  (c) => `{"error":{"code":${c}}} // c`,
  (c) => `{"\\u0065rror":{"code":${c}}}`,
  (c) => `{"error":{"\\u0063ode":${c}}}`,
];
const wraps: [string, string][] = [
  ["", ""], ["", "\n"], [" ", " "], ["\t", "\r\n"], [" ", ""], ["", " "], ["﻿", ""],
  ["\u000b", ""], ["", "\u000c"], [" ", ""], ["", "　"], ["warn: x\n", ""],
  ["", "\nkilled by SIGTERM"], ["", "killed by SIGTERM"], ["\u0000", ""], ["", "\u0000"],
];
const plain = [
  "", " ", "\n", "herdr agent commands:", "error: nested herdr is disabled by default.",
  "--current requires HERDR_PANE_ID", "null", "[]", "5", "\"str\"", "true", "{}", "{\"error\"",
  "{\"error\":", "killed by SIGTERM", "{\"error\":{\"code\":\"agent_not_found\"}",
  "{\"error\":null}", "{\"error\":\"agent_not_found\"}", "{\"error\":{}}", "{\"error\":[]}",
  "{\"code\":\"agent_not_found\"}", "agent_not_found", "{\"error\":{\"code\":\"agent_not_found\"}} nested herdr",
  "nested herdr {\"error\":{\"code\":\"agent_not_found\"}}", "{\"Error\":{\"code\":\"agent_not_found\"}}",
  "{\"errors\":{\"code\":\"agent_not_found\"}}", "\"{\\\"error\\\":1}\"", "{\"error\":{\"code\":\"x\"}}\n{\"error\":{\"code\":\"y\"}}",
];

const cases: { code: number; err: string }[] = [];
const stderrs: string[] = [...plain];
for (const t of templates) for (const c of errCodes) for (const [a, b] of wraps) stderrs.push(a + t(c) + b);

for (const s of stderrs) for (const code of codes) cases.push({ code, err: s });

// Random mutations of herdr-shaped JSON. xorshift32, fixed seed.
let seed = 0x2f6b9e3d;
const rnd = (n: number): number => {
  seed ^= seed << 13; seed >>>= 0; seed ^= seed >>> 17; seed ^= seed << 5; seed >>>= 0;
  return seed % n;
};
const pool = [
  "{", "}", "[", "]", ":", ",", "\"", "\\", " ", "\n", "\t", " ", "e", "r", "o", "c", "d",
  "_", "n", "t", "f", "u", "a", "g", "0", "1", "-", ".", "\\u005f", "\"error\"", "\"code\"",
  "\"agent_not_found\"", "\"pane_not_found\"", "nested herdr", "{\"error\"", "_not_found", "null",
  "é", " ", "﻿", "\\\"", "\"message\"", "\u0000", "\u000b", "e99", "e308", "9", "E+3",
];
const seeds = [
  ...errCodes.slice(0, 8).map((c) => templates[0](c)),
  ...errCodes.slice(0, 8).map((c) => templates[1](c)),
  ...errCodes.slice(0, 4).map((c) => templates[2](c)),
  ...errCodes.slice(0, 4).map((c) => templates[6](c)),
  ...errCodes.slice(0, 2).map((c) => `{"error":{"code":${c}},"n":1.7976931348623158e308}`),
  ...plain,
];
for (let i = 0; i < nRandom; i++) {
  let s = seeds[rnd(seeds.length)];
  const k = 1 + rnd(4);
  for (let j = 0; j < k; j++) {
    const op = rnd(3);
    const pos = rnd(s.length + 1);
    if (op === 0 && s.length > 0) s = s.slice(0, pos) + s.slice(pos + 1);
    else if (op === 1) s = s.slice(0, pos) + pool[rnd(pool.length)] + s.slice(pos);
    else if (s.length > 0) s = s.slice(0, pos) + pool[rnd(pool.length)] + s.slice(pos + 1);
  }
  cases.push({ code: [1, 1, 1, 3, 255, -1, 0, 2][rnd(8)], err: s });
}

fs.writeFileSync(`${out}/cases.json`, JSON.stringify({ cases }));
fs.writeFileSync(
  `${out}/cases.hex`,
  cases.map((c) => `${c.code}\t${Buffer.from(c.err, "utf8").toString("hex")}`).join("\n") + "\n",
);
console.error(`gen: ${cases.length} cases`);
