// host.ts — the TypeScript half of the T3 differential test: the REAL `SessionJournal`.
//
//   bun host.ts <repo root> <scratch dir> < events.txt > host_journals.txt
//
// Input: the `E|<actions>|<json>\t<json>...` lines gen_events.ail prints. For each one, a fresh
// `SessionJournal` (its own session directory under <scratch dir>), `writeHeader`, then
// `record(event)` for every wire event in order, exactly as the TUI's wire handler does. Output,
// one line per sequence: `<actions>\t[<line 0>,<line 1>,...]`, the journal file's lines as a
// JSON array, for fold_host.ail.

import * as fs from "fs";
import * as path from "path";
// T3_HOST_MODULE: a patched copy of session-journal.ts (../repro/case.sh, T3_FIX=host); the
// real module otherwise.
const { SessionJournal } = await import(process.env.T3_HOST_MODULE ?? "../../tree/src/tui/src/session-journal.ts");

const root = process.argv[3];
if (!root) throw new Error("usage: bun host.ts <repo root> <scratch dir> [--across]");
// --across: every `session_resumed` reaches a NEW `SessionJournal` on the same file, which is
// what a host process that starts after a kill -9 or a quit is (`adopt()`). Labels are
// prefixed with `A:` so fold_host.ail's output can sit beside the single-process run's.
const across = process.argv[4] === "--across";
fs.mkdirSync(root, { recursive: true });

const input = fs.readFileSync(0, "utf8").split("\n").filter((l) => l.startsWith("E|"));
const out: string[] = [];
let n = 0;
for (const line of input) {
  const rest = line.slice(2);
  const bar = rest.indexOf("|");
  const acts = rest.slice(0, bar);
  const events = rest.slice(bar + 1).split("\t").filter((s) => s !== "");
  const sid = `s${n++}`;
  const opts = { onError: () => {}, now: () => 0 };
  let j = new SessionJournal(root, sid, opts);
  j.writeHeader({ sessionId: sid, workdir: "", profile: "prof", model: "m" });
  for (const e of events) {
    const ev = JSON.parse(e);
    if (across && ev.type === "session_resumed") j = new SessionJournal(root, sid, opts);
    j.record(ev);
  }
  const lines = fs.readFileSync(j.filePath, "utf8").split("\n").filter((l) => l.trim() !== "");
  out.push(`${across ? "A:" : ""}${acts}\t[${lines.join(",")}]`);
  fs.rmSync(j.dir, { recursive: true, force: true });
}
process.stdout.write(out.join("\n") + "\n");
