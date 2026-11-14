// p31_host.ts — P3.1, the TypeScript half: the REAL `SessionJournal` fed the wire events the
// generator (`p31_twin.ail`, `W` lines) produced, one fresh session directory per case.
//
//   bun p31_host.ts <tree root> <W-lines file> <scratch dir> > host.tsv
//
// Three host lifecycles per case, because a resume is a NEW host process that ADOPTS the file:
//   one     — one SessionJournal for the whole case (no adopt), no exit entry.
//   crash   — at every `session_resumed` a new SessionJournal on the same dir (kill -9: no exit).
//   restart — at every `session_resumed`: writeExit("restart"), then a new SessionJournal.
// Output, one line per case and mode:  <ix>\t<mode>\t<journal path>\t<leaf>\t<pendingToolCalls>
import * as fs from "fs";
import * as path from "path";

const [root, wfile, scratch] = process.argv.slice(2);
if (!root || !wfile || !scratch) throw new Error("usage: bun p31_host.ts <tree> <W file> <scratch>");
// T3_HOST_MODULE swaps in a patched copy of the writer (fix validation); default: the real one.
const { SessionJournal } = await import(path.resolve(root, process.env.T3_HOST_MODULE ?? "src/tui/src/session-journal.ts"));

const modes = (process.env.T3_MODES ?? "one,crash,restart").split(",");
const lines = fs.readFileSync(wfile, "utf8").split("\n").filter((l) => l.startsWith("W\t"));
const out: string[] = [];
let n = 0;
for (const l of lines) {
  const [, ix, json] = l.split("\t");
  const events = JSON.parse(json) as Record<string, unknown>[];
  for (const mode of modes) {
    const proj = path.join(scratch, `${n}`);
    n += 1;
    fs.rmSync(proj, { recursive: true, force: true });
    const errors: string[] = [];
    const mk = () => new SessionJournal(proj, "sess_1", { now: () => 0, onError: (m: string) => errors.push(m) });
    let j = mk();
    j.writeHeader({ sessionId: "sess_1", workdir: "", profile: "dogfood", model: "m" });
    for (const e of events) {
      if (e.type === "session_resumed" && mode !== "one") {
        if (mode === "restart") j.writeExit("restart");
        j = mk();
      }
      j.record(e);
    }
    out.push(`${ix}\t${mode}\t${j.filePath}\t${j.currentLeaf}\t${j.pendingToolCalls.join(",")}\t${errors.length}`);
  }
}
process.stdout.write(out.join("\n") + "\n");
