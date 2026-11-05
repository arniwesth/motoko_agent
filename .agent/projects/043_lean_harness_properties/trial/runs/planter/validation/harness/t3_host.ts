// T3, the TypeScript half: the REAL SessionJournal writes each case's journal from the wire events
// t3_gen.ail printed (E lines), exactly as the host does: header first, then one record() per event.
//   bun t3_host.ts <tree> <gen-output> <scratch-dir>   ->   J <tab> case <tab> journal-line
import * as fs from "fs";
import * as path from "path";
const [tree, genFile, scratch] = process.argv.slice(2);
const { SessionJournal } = await import(`${tree}/src/tui/src/session-journal.ts`);
const byCase = new Map<string, unknown[]>();
for (const line of fs.readFileSync(genFile, "utf8").split("\n")) {
  if (!line.startsWith("E\t")) continue;
  const [, name, json] = line.split("\t");
  if (!byCase.has(name)) byCase.set(name, []);
  byCase.get(name)!.push(JSON.parse(json));
}
fs.mkdirSync(scratch, { recursive: true });
const out: string[] = [];
let i = 0;
for (const [name, events] of byCase) {
  const j = new SessionJournal(scratch, `c${i++}`, { onError: () => {}, now: () => 0 });
  j.writeHeader({ sessionId: `c${i}`, workdir: "", profile: "", model: "m" });
  for (const e of events) j.record(e as Record<string, unknown>);
  for (const l of fs.readFileSync(j.filePath, "utf8").split("\n")) if (l.trim() !== "") out.push(`J\t${name}\t${l}`);
}
process.stdout.write(out.join("\n") + "\n");
