# Brief: follow-up review of PLAN-004 v1.2 (delta against your v1.1 review)

Same repo, branch and rules as `BRIEF-plan004-v1-review.md`: read-only except the one review document you
write; no commit; no `make dst`, replay, prototype, profiling or other heavy execution; no herdr pane or
agent operations; do not edit `.dagr/run-plan004.json` or the plan; no corpus content in the review. `ailang
check`, `git show`, `dagr check`, `dagr view --snapshot`, reading the AILANG source under `ailang/`, and
targeted Python reads are fine. Evidence under
`/tmp/claude-1001/-workspaces-motoko-agent/d8b1d53b-1a2d-4c49-b4ec-fc412754e86a/scratchpad/codex-review-plan004/v1.2/`.
Verify HEAD; the plan is grounded at `3920814`.

**This is the plan's third round.** Under the plan's own §0.10 (`rounds_max: 3`), a RETURN now blocks for an
operator directive, so distinguish clearly between findings that must block `PLAN1G` and corrections that can
be applied and named under ACCEPT WITH CORRECTIONS.

## Under review

- `.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md`, **v1.2**; its §9 maps each
  of your v1.1 review's five required changes.
- `.dagr/run-plan004.json`, revised to match: new author task `PLANW` (attempts a1, a2 recorded
  retroactively, a3 live), policies moved from review tasks to author tasks, gates depending on author and
  review tasks. `REV2·a2` is this review.
- The synthetic RETURN-transaction documents the plan cites in §6:
  `/tmp/claude-1001/-workspaces-motoko-agent/d8b1d53b-1a2d-4c49-b4ec-fc412754e86a/scratchpad/dagr-round/`
  (`S1`–`S4`, `S2x`).

## What the review must do

1. **Disposition of your five required changes** (`REVIEW-plan004-v1.1-delta-verdicts-codex.md:105–109`), one
   row each: ADDRESSED / PARTIAL / NOT ADDRESSED, with evidence.
2. **The §0.10 transaction.** Reproduce it **independently** — do not rely on the plan's scratch files —
   by building your own sequence (author under review → RETURN → sent back → re-review → third RETURN →
   `blocked` with `unblock` → directive → ACCEPT) and running `dagr check --strict --json` and `dagr view
   --snapshot` on each step. Answer: is each step append-only (no settled attempt or event rewritten)? Does
   the gate stay not-ready on every RETURN and become ready only on ACCEPT? Do the author-task policies
   render sensibly in `review`, `working` and `blocked` states, and does moving the fail future `·aN`→`·aN+1`
   avoid `E164`? Is `PLANW`'s retroactive recording of a1/a2 honest and contract-valid (causes backward,
   timestamps ordered, evidence tier)? Is the no-`a4`-forecast policy for round 3 right?
3. **§8's two files, two authorities**: the authority table, the two-file receipt, and the fresh-session
   receipt, against `packages/motoko-ext-herdr/dagr.ail` and `herdr.ail`. Is anything still unenforceable
   in a way that matters?
4. **M15 and `MATRIX.tsv`**: is each near-miss counterpart actually reachable past its family's refusal and
   caught at the stated check and position? Are the inapplicable rows justified? Is asking V5 to confirm or
   revise D8's sentence the right disposition?
5. **The provenance contracts**: P1.4b's statement-level imports and non-braced type rule against real
   AILANG syntax in `src/core` (find counter-examples if any); P1.6's independent-source table (is each
   "independent" source really a different code path, and does it exist at HEAD?); P1.9a's cache and loader
   evidence against `ailang/internal/pipeline/cache_store.go`, `pipeline_module.go`, `internal/loader/loader.go`
   and `stdlib_resolver.go` — in particular whether `compile/manifest.json`'s module-ID set is a sound record
   of what compiled, whether a fresh cache directory guarantees misses, and whether the `ailang.lock`
   absolute-path finding and its handling are correct.
6. **P3.2**: the provisional-budget ordering against P3.3/P3G and the bounded escalation.
7. **Graph ↔ plan audit**: `dagr check .dagr/run-plan004.json --strict --json`; one task per part; deps equal
   each part's stated "Deps"; gate fan-ins; policies only on author tasks; criteria agree with the plan; the
   ready set (now: `QRET`; `PLANW` in review; after `PLAN1G`: `SWEEP`, `V5`, `P2.1`); §1's skeleton; §1/§7
   sums (18½–22 and 30–37½).
8. **New errors** in v1.2 — facts, citations, numbers — with corrections.
9. **Verdict for `PLAN1G`**: ACCEPT, ACCEPT WITH CORRECTIONS (list each correction precisely enough to apply
   and name in the gate receipt), or RETURN (list what must block, knowing it triggers the operator
   directive).

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-plan004-v1.2-delta-verdicts-codex.md`: header
(date, HEAD, branch, subject, inputs, method, what you did not do, evidence directory); overall verdict; §1
the five dispositions; §2 the transaction; §3 the two files; §4 M15 and the matrix artifact; §5 provenance;
§6 P3.2; §7 graph audit; §8 new errors; "Verdict for PLAN1G". Every claim carries a file:line at HEAD or a
command and its output. When finished, reply with only the review file's path.
