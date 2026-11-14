// host_write.ts — stage 2 of the T3 harness: the REAL `SessionJournal` (the host's
// writer, src/tui/src/session-journal.ts:139) over the wire events stage 1 printed.
//
//   bun host_write.ts <tree root> <gen output> > host.out
//
// For every `W` line: a fresh session directory, `writeHeader`, then `record(event)` for
// every wire event in order, exactly as the TUI routes journal-class events. Prints
//
//   H <id> <leaf> <journal lines as a JSON array> <unresumable reason or ""> <pendingToolCalls as JSON>
//
// `pendingToolCalls` is what the host would write as `exit.pending_tool_calls` (D1).
//
// Session directories are created beside <gen output> and removed afterwards.
// The journal is read back from the file the class wrote; nothing is reconstructed.
// At every `session_resumed` a new instance is constructed on the same directory (a resume
// is a new host process, which adopts the journal), unless T3_ADOPT=0.
import * as fs from "fs";
import * as path from "path";

const tree = process.argv[2];
const genOut = process.argv[3];
if (!tree || !genOut) throw new Error("usage: bun host_write.ts <tree root> <gen output>");
// T3_HOST_MODULE (negative controls only): a patched copy of the class to load instead.
const { SessionJournal } = await import(path.resolve(process.env.T3_HOST_MODULE ?? path.join(tree, "src/tui/src/session-journal.ts")));

const adopt = (process.env.T3_ADOPT ?? "1") !== "0";
const scratch = fs.mkdtempSync(path.join(process.env.T3_SCRATCH ?? path.dirname(path.resolve(genOut)), "t3host-"));
const out: string[] = [];
try {
  for (const line of fs.readFileSync(genOut, "utf8").split("\n")) {
    if (!line.startsWith("W\t")) continue;
    const cols = line.split("\t");
    const id = cols[1];
    const events = JSON.parse(cols[5]) as Record<string, unknown>[];
    const root = path.join(scratch, `c${id}`);
    const open = () => new SessionJournal(root, "sess_1", { now: () => 0, onError: () => {} });
    let j = open();
    // The header seed matches the twin's `harness_header(default_run_identity("sess_1"), "m")`.
    j.writeHeader({ sessionId: "sess_1", workdir: "", profile: "", model: "m" });
    for (const e of events) {
      // A `--resume` is a NEW host process (P3 Part 5): it constructs the journal on the
      // existing session directory, which `adopt()`s the file, and only then routes the
      // resumed child's first event. T3_ADOPT=0 keeps one instance instead.
      if (adopt && e.type === "session_resumed") j = open();
      j.record(e);
    }
    const raw = fs.readFileSync(j.filePath, "utf8");
    const lines = raw.split("\n").filter((l) => l.trim() !== "").map((l) => JSON.parse(l));
    out.push(["H", id, j.currentLeaf, JSON.stringify(lines), (j.unresumable ?? "").replace(/[\t\n]/g, " "),
      JSON.stringify(j.pendingToolCalls)].join("\t"));
    fs.rmSync(root, { recursive: true, force: true });
  }
} finally {
  fs.rmSync(scratch, { recursive: true, force: true });
}
process.stdout.write(out.join("\n") + "\n");
