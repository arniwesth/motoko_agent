// The TypeScript half of the T1 differential test: the REAL `readHerdrEnvironment`
// (src/tui/src/herdr-agent-state.ts:157), over every triple in (unset, then alphabet.json), in
// the order of enumerate.lean.tail and enumerate_gate.ail. One line per triple:
//
//   <e>,<b>,<p>|null            or   <e>,<b>,<p>|obj:<pane index>,<bin index>
//
// An unset variable is an absent key. The returned fields are located in the alphabet ("?" if
// absent), so the comparison covers what the gate returns, not only whether it returns.
//
//   bun enumerate.ts <tree root> <alphabet.json>

import { readFileSync } from "fs";

const [treeRoot, alphabetPath] = process.argv.slice(2);
if (!treeRoot || !alphabetPath) throw new Error("usage: bun enumerate.ts <tree root> <alphabet.json>");

const { readHerdrEnvironment } = await import(`${treeRoot}/src/tui/src/herdr-agent-state.ts`);

const alphabet: string[] = JSON.parse(readFileSync(alphabetPath, "utf8"));
const opts: [string, string | undefined][] = [["u", undefined], ...alphabet.map((v, i) => [String(i), v] as [string, string])];
const idx = (s: unknown) => {
  const i = alphabet.indexOf(s as string);
  return i < 0 ? "?" : String(i);
};

const out: string[] = [];
for (const [el, ev] of opts) {
  for (const [bl, bv] of opts) {
    for (const [pl, pv] of opts) {
      const env: Record<string, string> = {};
      if (ev !== undefined) env.HERDR_ENV = ev;
      if (bv !== undefined) env.HERDR_BIN_PATH = bv;
      if (pv !== undefined) env.HERDR_PANE_ID = pv;
      const r = readHerdrEnvironment(env);
      out.push(`${el},${bl},${pl}|${r === null ? "null" : `obj:${idx(r.paneId)},${idx(r.bin)}`}`);
    }
  }
}
process.stdout.write(out.join("\n") + "\n");
