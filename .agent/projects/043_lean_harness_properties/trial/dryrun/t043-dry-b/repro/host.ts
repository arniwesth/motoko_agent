// host.ts '<json [[role, ids, tool_call_id], ...]>': prints the REAL updatePending's open set.
import { SessionJournal } from "/home/motoko/trial-043/s/t043-dry-b/tree/src/tui/src/session-journal.ts";
import { mkdtempSync } from "node:fs"; import { tmpdir } from "node:os"; import { join } from "node:path";
const hist = JSON.parse(process.argv[2]) as [string, string[], string][];
const j = new SessionJournal(mkdtempSync(join(tmpdir(), "t0-")), "repro", { onError: () => {} }) as any;
j.openCallIds = [];
for (const [role, ids, tcid] of hist)
  j.updatePending({ role, content: "", tool_calls: ids.map((id) => ({ id, name: "bash", arguments: "{}" })), tool_call_id: tcid, images: [] });
process.stdout.write(j.pendingToolCalls.join(","));
