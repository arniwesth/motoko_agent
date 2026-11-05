// The host half of the exploratory chain differential (X-1, X-2): for every triple in
// (unset, then alphabet.json), set the three variables in THIS process's environment and run
// the REAL host code on it:
//
//   * `readHerdrEnvironment(process.env)`   src/tui/src/herdr-agent-state.ts:157
//   * `buildChildEnv(...)`                  src/tui/src/runtime-process.ts:499, of which only
//     the three gate variables are kept: what the AILANG runtime will see.
//
// One line per triple, in the order of enumerate_chain.lean.tail:
//
//   <e>,<b>,<p>|<gate: null | obj:<pane>,<bin>>|<forwarded e>,<forwarded b>,<forwarded p>
//
// where a forwarded value is its alphabet index, or `u` when buildChildEnv drops it.
//
//   bun enumerate_chain.ts <tree root> <alphabet.json> <scratch workdir>

import { readFileSync } from "fs";

const [treeRoot, alphabetPath, workdir] = process.argv.slice(2);
if (!treeRoot || !alphabetPath || !workdir) {
  throw new Error("usage: bun enumerate_chain.ts <tree root> <alphabet.json> <scratch workdir>");
}

const { readHerdrEnvironment } = await import(`${treeRoot}/src/tui/src/herdr-agent-state.ts`);
const { buildChildEnv } = await import(`${treeRoot}/src/tui/src/runtime-process.ts`);

const alphabet: string[] = JSON.parse(readFileSync(alphabetPath, "utf8"));
const opts: [string, string | undefined][] = [["u", undefined], ...alphabet.map((v, i) => [String(i), v] as [string, string])];
const idx = (s: unknown) => {
  if (s === undefined) return "u";
  const i = alphabet.indexOf(s as string);
  return i < 0 ? "?" : String(i);
};

// Start from no HERDR_* at all, whatever the caller's environment holds.
for (const k of Object.keys(process.env)) if (k.startsWith("HERDR_")) delete process.env[k];

const set = (k: string, v: string | undefined) => {
  if (v === undefined) delete process.env[k];
  else process.env[k] = v;
};

const out: string[] = [];
for (const [el, ev] of opts) {
  for (const [bl, bv] of opts) {
    for (const [pl, pv] of opts) {
      set("HERDR_ENV", ev);
      set("HERDR_BIN_PATH", bv);
      set("HERDR_PANE_ID", pv);
      const r = readHerdrEnvironment(process.env);
      const c = buildChildEnv(workdir, "default", "", "{}");
      const gate = r === null ? "null" : `obj:${idx(r.paneId)},${idx(r.bin)}`;
      out.push(`${el},${bl},${pl}|${gate}|${idx(c.HERDR_ENV)},${idx(c.HERDR_BIN_PATH)},${idx(c.HERDR_PANE_ID)}`);
    }
  }
}
process.stdout.write(out.join("\n") + "\n");
