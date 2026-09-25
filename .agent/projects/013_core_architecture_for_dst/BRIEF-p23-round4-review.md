# BRIEF — P2.3R round-4 review of X9 (P2.3R·a6, FINAL by operator waiver)

Adversarial, read-only. PLAN-004 v2, G1. Verdict: ACCEPT / ACCEPT WITH CORRECTIONS (Cx + owner +
check) / RETURN (Rx + rework + re-evidence, mechanically closable). This is the round-4 verdict:
X9 + full Part-1 tail as it stands. R5/selectors excluded (half ii).

READ FIRST (two files, not the answer-file chain):
  .agent/projects/013_core_architecture_for_dst/STATE-p23-round4.md — identity, env, row status, hazards.
  .agent/projects/013_core_architecture_for_dst/LEDGER-p23-part1-rows.tsv — one line per artifact,
  digests computed not typed (regenerate with LEDGER-p23-part1-rows.sh). RECOMPUTE everything you
  rely on; the ledger is convenience, not evidence.
  Key receipts: X9 commit+launch answer-mot-dlg-1789818540385.md; 1.7-green re-entry
  answer-mot-dlg-1789821598623.md; tail-end answer-mot-dlg-1789802299896.md (1.11–1.15);
  X8 report answer-mot-dlg-1789812988355.md; basis review answer-mot-dlg-1789810872424.md (§§1–7).

Privacy §0.6: counts, digests, indices, identities — never corpus content. Read-only: no commits,
nothing staged, no byte edits in A or the clone. Light verification runs only (ailang check/test,
targeted pytest non-live, git/grep); NO heavy runs, NO MATRIX regen, NO commits, NO real-journal reads.

X9 (frozen): e397d957, ONE file (journal_replay.ail 4+/4-, :437 arm split + :361 comment).
Prior: X8 20f2b27b (3-file §7 worklist), X7 9ed0d389 (2-file test-only), X6 20a78579 (doors).
A = ../motoko_agent-eval, ZERO edits (14 files +1804/−205 pre-existing, detached 2062605).

SCOPE — rule each, with the command and its output for every claim:
1. Part-1 rows on evidence (not prose): 1.1–1.11 + 1.14 GREEN or carried per ledger; 1.7 7/7 at X9
   with mutgate PASS; 1.8 3/3 ScanRefusal (excerpt valid-chain); 1.13/1.12-live/1.15 RED with
   identified harness-invocation causes (below) — confirm each row's log exists with the quoted
   digest, or mark it unproven.
2. Carry-over restatement (use verbatim, verify): six blobs equal X7→X8→X9; scan.ail differs by
   one line inside test_m12_one_hit_per_component (test function only, no production path) —
   attach the diff. Rows 1.3/1.4/1.5/1.6/1.9 remain carryable. A reviewer recomputing blob ids
   otherwise stops at DIFFERS.
3. Three open rulings for the operator (rule each as ACCEPT-DEFERRED with owner, or RETURN):
   (a) guard_lock inside the digested entry (heavy.lock pid-write trips its own
   changed_during_run — correct behaviour; options: move lock out / skip in digest / setup-wrong);
   (b) seams /tmp sentinel hardcoded under /workspaces sandbox (6/7 live green, 1 red);
   (c) r6 observe-tier mismatch (row 629 expects pass/-, test emits refused/MalformedEntry/path —
   BadSelector half asserted but never observed into the matrix).
4. Batch discipline: X9 = 1 file beyond X8; X8 = 3 files; no R5/selectors bytes; void set held;
   nothing staged in A; .gitignore untouched.
5. Mutgate + mutations: X9 GREEN/RED/GREEN/same PASS; MUT-1..5 red+restore+green records present.

OUT OF SCOPE: R5/selectors (half ii); 1.16 teardown (operator-owned); :437 string-match
follow-up (named, not folded into X9).

DELIVERY: WriteFile to ./.motoko/herdr-delegates/answer-<your-handle>.md. First line = verdict.
Per-item verdict with commands + outputs; status token in FIRST column of any table, never an
expected value where a result is read. If RETURN, each Rx needs rework + re-evidence stated
mechanically. If CORRECTIONS, each Cx needs owner + acceptance check + rides-to-G2 vs re-review.
