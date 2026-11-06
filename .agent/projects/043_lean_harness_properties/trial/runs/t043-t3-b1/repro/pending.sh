#!/usr/bin/env bash
# D1's exit.pending_tool_calls against the fold's dangling calls, on the REAL code: the REAL
# host is fed the step sequence's wire events, then `writeExit("abort")`; the exit entry's
# `pending_tool_calls` is compared with what the REAL fold reports dangling for that journal.
#   bash ../out/repro/pending.sh 0,6        (from the tree root)
# Exit 1 when they differ (defect present), 0 when they agree.
source "$(dirname "$0")/_env.sh"
steps="${1:?usage: pending.sh <comma-separated steps>}"
ail --caps IO --entry one_of --args-json "[${steps}]" diff/gen.ail > "$work/gen.out"
fold="$(host_verdict "$work/gen.out" | cut -f3)"
pending="$(cd "$work" && bun -e '
  const fs = require("fs"); const path = require("path");
  const { SessionJournal } = require(path.join(process.argv[1], "src/tui/src/session-journal.ts"));
  const evs = fs.readFileSync(process.argv[2], "utf8").split("\n").filter(l => l.startsWith("W\t")).map(l => JSON.parse(l.split("\t")[2]));
  const j = new SessionJournal(process.argv[3], "p", { onError: () => {}, now: () => 0 });
  j.writeHeader({ sessionId: "p", workdir: "", profile: "dogfood", model: "m" });
  for (const e of evs) j.record(e);
  j.writeExit("abort");
  const last = fs.readFileSync(j.filePath, "utf8").trim().split("\n").pop();
  console.log(JSON.parse(last).pending_tool_calls.join("+"));
' "$tree" "$work/gen.out" "$work/exitroot")"
dangling="$(echo "$fold" | cut -d';' -f3)"
echo "steps $steps"
echo "  real fold of the host's journal: $fold  (dangling: '${dangling}')"
echo "  host exit.pending_tool_calls:    '${pending}'"
if [[ "$pending" != "$dangling" ]]; then echo "exit.pending_tool_calls DISAGREES with the fold"; exit 1; fi
echo "agree"; exit 0
