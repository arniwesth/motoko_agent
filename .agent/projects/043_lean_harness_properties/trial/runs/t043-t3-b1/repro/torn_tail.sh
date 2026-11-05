#!/usr/bin/env bash
# X-1: the host adopts a journal whose last line is torn (what a crash mid-append leaves,
# session-journal.ts:302-306) and appends the next entry ONTO the torn bytes, so the file's
# torn tail becomes a corrupt line in the MIDDLE and the real reader refuses the whole journal.
#   bash ../out/repro/torn_tail.sh      (from the tree root)
# Process 1: header, run_started, the seed [m0, m1]; then half of the next entry's line is
# written with no newline (the crash). Process 2: a new SessionJournal on the same session
# (adopt), which records that same entry again. Then the REAL parse_journal_text + fold_journal.
# Exit 1 when the resulting journal is refused (defect present), 0 when it folds.
# Control: TEAR=0 bash ../out/repro/torn_tail.sh   skips the torn write (expected: folds, exit 0).
source "$(dirname "$0")/_env.sh"
cp "$here/foldfile.ail" "$mod/repro/"
ail --caps IO --entry one_of --args-json "[0]" diff/gen.ail > "$work/gen.out"
leaf="$(cd "$work" && bun -e '
  const fs = require("fs"); const path = require("path");
  const { SessionJournal } = require(path.join(process.argv[1], "src/tui/src/session-journal.ts"));
  const evs = fs.readFileSync(process.argv[2], "utf8").split("\n").filter(l => l.startsWith("W\t")).map(l => JSON.parse(l.split("\t")[2]));
  const root = process.argv[3];
  const j1 = new SessionJournal(root, "torn", { onError: () => {}, now: () => 0 });
  j1.writeHeader({ sessionId: "torn", workdir: "", profile: "dogfood", model: "m" });
  for (const e of evs.slice(0, -1)) j1.record(e);
  // The crash: the next append got half its bytes out.
  const next = JSON.stringify({ id: "0004", parent_id: j1.currentLeaf, seq: 4, at_ms: 0, type: "history_appended" });
  if (process.argv[4] !== "0") fs.appendFileSync(j1.filePath, next.slice(0, 30));
  // The next process on the same session adopts the file and carries on.
  const j2 = new SessionJournal(root, "torn", { onError: () => {}, now: () => 0 });
  j2.record(evs[evs.length - 1]);
  process.stderr.write(fs.readFileSync(j2.filePath, "utf8").split("\n").map(l => "    | " + l.slice(0, 110)).join("\n") + "\n");
  console.log(j2.filePath + "|" + j2.currentLeaf);
' "$tree" "$work/gen.out" "$work/root" "${TEAR:-1}" 2> "$work/file.txt")"
echo "the journal after the second process's append (lines cut at 110 chars):"; cat "$work/file.txt"
verdict="$(ail --caps IO,FS --entry main --args-json "\"$leaf\"" repro/foldfile.ail)"
echo "real parse_journal_text + fold_journal: $verdict"
if [[ "$verdict" == R\;* ]]; then echo "DEFECT: the adopted journal can no longer be read"; exit 1; fi
echo "folds"; exit 0
