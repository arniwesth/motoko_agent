// host.ts — the TypeScript half of T3's differential test: the REAL `SessionJournal`
// (src/tui/src/session-journal.ts), fed the wire events gen.ail printed, one fresh journal
// per sequence. Nothing on the instance is reached around: `writeHeader` then `record` for
// each event, exactly the host's own entry points. Prints one line per sequence:
//
//   H\t<ix>\t<the journal's entries as one JSON array>
//
//   bun host.ts <repo root> <gen output> <scratch dir>

import * as fs from "fs";
import * as path from "path";

const [repo, genOut, scratch] = process.argv.slice(2);
if (!repo || !genOut || !scratch) throw new Error("usage: bun host.ts <repo> <gen.out> <scratch>");
const { SessionJournal } = await import(path.join(repo, "src/tui/src/session-journal.ts"));

const order: string[] = [];
const events = new Map<string, unknown[]>();
for (const line of fs.readFileSync(genOut, "utf8").split("\n")) {
  const [tag, key, json] = line.split("\t");
  if (tag !== "W") continue;
  if (!events.has(key)) { events.set(key, []); order.push(key); }
  events.get(key)!.push(JSON.parse(json));
}

fs.mkdirSync(scratch, { recursive: true });
const out: string[] = [];
let n = 0;
for (const key of order) {
  const sid = `s${n++}`;
  fs.rmSync(path.join(scratch, ".motoko", "sessions", sid), { recursive: true, force: true });
  const j = new SessionJournal(scratch, sid, { onError: () => {}, now: () => 0 });
  j.writeHeader({ sessionId: sid, workdir: "", profile: "dogfood", model: "m" });
  for (const e of events.get(key)!) j.record(e as Record<string, unknown>);
  const lines = fs.readFileSync(j.filePath, "utf8").split("\n").filter((l: string) => l.trim() !== "");
  out.push(`H\t${key}\t[${lines.join(",")}]`);
}
process.stdout.write(out.join("\n") + "\n");
