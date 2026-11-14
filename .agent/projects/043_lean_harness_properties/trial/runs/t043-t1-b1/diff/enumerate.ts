// diff/enumerate.ts — the TypeScript half: the REAL `readHerdrEnvironment`
// (src/tui/src/herdr-agent-state.ts:157), over every triple of diff/alphabet.json, in the order
// enumerate.lean.tail uses. Prints `<i>,<j>,<k>|<null | obj:<P|?>:<B|?>>` per triple.
//
//   bun enumerate.ts <repo root> <alphabet.json>
//
// An unset variable (alphabet index 0, JSON null) is ABSENT from the env object, which is what
// it is in `process.env`; nothing else is put in the object.

const [repo, alphabetPath] = process.argv.slice(2);
if (!repo || !alphabetPath) throw new Error("usage: bun enumerate.ts <repo root> <alphabet.json>");

const { readHerdrEnvironment } = await import(`${repo}/src/tui/src/herdr-agent-state.ts`);
const alphabet: (string | null)[] = JSON.parse(await Bun.file(alphabetPath).text());

const lines: string[] = [];
for (let i = 0; i < alphabet.length; i++) {
  for (let j = 0; j < alphabet.length; j++) {
    for (let k = 0; k < alphabet.length; k++) {
      const env: Record<string, string> = {};
      if (alphabet[i] !== null) env.HERDR_ENV = alphabet[i]!;
      if (alphabet[j] !== null) env.HERDR_BIN_PATH = alphabet[j]!;
      if (alphabet[k] !== null) env.HERDR_PANE_ID = alphabet[k]!;
      const r = readHerdrEnvironment(env);
      const field =
        r === null
          ? "null"
          : `obj:${r.paneId === alphabet[k] ? "P" : "?"}:${r.bin === alphabet[j] ? "B" : "?"}`;
      lines.push(`${i},${j},${k}|${field}`);
    }
  }
}
process.stdout.write(lines.join("\n") + "\n");
