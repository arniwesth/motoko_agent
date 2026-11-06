// The TypeScript half of the differential test: the REAL `SessionJournal.updatePending`, over
// the same histories, in the same order, as enumerate.lean.tail. Prints
// `<message indices>|<pending_tool_calls>` per history.
//
//   bun enumerate.ts <repo root> <scratch dir>
//
// `updatePending` and `openCallIds` are private; they are reached through a cast, and the open
// set is reset between histories by assigning `openCallIds = []`, which is what the class itself
// does on a new seed. Nothing else on the instance is read or written.

import { SessionJournal } from "/home/motoko/trial-043/s/t043-dry-b/tree/src/tui/src/session-journal.ts";

const scratch = process.argv[3];
if (!scratch) throw new Error("usage: bun enumerate.ts <repo root> <scratch dir>");

const call = (id: string) => ({ id, name: "bash", arguments: "{}" });
const msg = (role: string, ids: string[], toolCallId: string) => ({
  role,
  content: "",
  tool_calls: ids.map(call),
  tool_call_id: toolCallId,
  images: [],
});

// Same eleven messages, same order, as `alphabet` in enumerate.lean.tail.
const alphabet = [
  msg("assistant", [], ""),
  msg("assistant", ["a"], ""),
  msg("assistant", ["a", "b"], ""),
  msg("assistant", ["b"], ""),
  msg("tool", [], "a"),
  msg("tool", [], "b"),
  msg("tool", [], ""),
  msg("user", [], ""),
  msg("tool", ["b"], "a"),
  msg("assistant", [], "a"),
  msg("assistant", ["a", ""], ""),
];

function seqsOfLen(n: number): number[][] {
  if (n === 0) return [[]];
  const out: number[][] = [];
  for (const s of seqsOfLen(n - 1)) for (let i = 0; i < alphabet.length; i++) out.push([...s, i]);
  return out;
}

const journal = new SessionJournal(scratch, "diff-enumerate", { onError: () => {} });
const j = journal as unknown as { updatePending(m: unknown): void; openCallIds: string[] };

const lines: string[] = [];
for (let len = 0; len <= 4; len++) {
  for (const s of seqsOfLen(len)) {
    j.openCallIds = [];
    for (const i of s) j.updatePending(alphabet[i]);
    lines.push(`${s.join(",")}|${journal.pendingToolCalls.join(",")}`);
  }
}
process.stdout.write(lines.join("\n") + "\n");
