// x3_torn.ts — X-3: a torn last line (what `kill -9` mid-append leaves, session-journal.ts:303)
// and the adopting host's next append. Uses the REAL SessionJournal and the wire events of one
// generated case (a `W` line of p31_twin.ail).
//
//   bun x3_torn.ts <tree root> <W-lines file> <scratch dir> > host.tsv
//
// Writes two journals and prints them in p31_host.ts's host.tsv format:
//   torn     — every event but the last journaled, then HALF of the last event's entry line
//              appended with no newline (the crash), and nothing after.
//   torn+1   — the same, then a new SessionJournal (the next process adopts the file) records
//              one more journal-class event (a state_delta): the first append after the crash.
import * as fs from "fs";
import * as path from "path";

const [root, wfile, scratch] = process.argv.slice(2);
const { SessionJournal } = await import(path.resolve(root, process.env.T3_HOST_MODULE ?? "src/tui/src/session-journal.ts"));
const line = fs.readFileSync(wfile, "utf8").split("\n").find((l) => l.startsWith("W\t"))!;
const [, ix, json] = line.split("\t");
const events = JSON.parse(json) as Record<string, unknown>[];
const out: string[] = [];
for (const mode of ["torn", "torn+1"]) {
  const proj = path.join(scratch, mode);
  fs.rmSync(proj, { recursive: true, force: true });
  const mk = () => new SessionJournal(proj, "sess_1", { now: () => 0, onError: () => {} });
  let j = mk();
  j.writeHeader({ sessionId: "sess_1", workdir: "", profile: "dogfood", model: "m" });
  for (const e of events.slice(0, -1)) j.record(e);
  // The crash: the last entry's line, cut in half, no newline. Built by journaling it into a
  // throwaway copy so the bytes are exactly the ones the host would have written.
  const shadow = path.join(scratch, `${mode}.shadow`);
  fs.rmSync(shadow, { recursive: true, force: true });
  fs.mkdirSync(path.join(shadow, ".motoko", "sessions", "sess_1"), { recursive: true });
  fs.copyFileSync(j.filePath, path.join(shadow, ".motoko", "sessions", "sess_1", "journal.jsonl"));
  const s = new SessionJournal(shadow, "sess_1", { now: () => 0, onError: () => {} });
  s.record(events[events.length - 1]);
  const full = fs.readFileSync(s.filePath, "utf8").split("\n").filter((l) => l !== "");
  const last = full[full.length - 1];
  fs.appendFileSync(j.filePath, last.slice(0, Math.floor(last.length / 2)));
  if (mode === "torn+1") {
    j = mk(); // the next process: adopt()
    j.record({ type: "state_delta", run_id: "sess_1.r0.0", step: 9,
               cumulative: { provider_calls_started: 1, provider_calls_completed: 1, stage_applied_total: 0, stage_rejected_total: 0, compaction_ai_applied: 0 },
               telemetry: { last_input_tokens: 1, last_output_tokens: 1, last_estimated_input_tokens: 1 },
               ext_artifacts_digest: "sha256:ext" });
  }
  out.push(`${ix}\t${mode}\t${j.filePath}\t${j.currentLeaf}\t\t0`);
}
process.stdout.write(out.join("\n") + "\n");
