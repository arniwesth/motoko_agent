# Brief: adversarial review of ADR-004 v5 (same shape as the v4 review)

Same repo, branch and HEAD (`21c1728`) and the same rules as `BRIEF-adr004-v4-review.md`:
read-only; edit nothing under the repo except the one review document you write; no commit; no
`make dst`, replay, prototype run or other heavy execution (memory is contended); `ailang check`
and targeted Python reads of existing files are fine; do not open, close or prompt any pane or
agent. Temporary evidence goes under `/tmp/` (create a scratch dir); do not copy any corpus
content anywhere (counts, digests, indices, identities only, per PLAN-004 §0.6).

## Under review

`.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md` —
Proposed, **v5**, unreviewed. It claims to fold all nine required changes of the v4 review
(`REVIEW-adr004-v4-verdicts-codex.md`, "Required changes for v5", :282–292). The v1→v4 history is
carried verbatim; the new material is the "v4 → v5" retraction block (nine items, each ending with
the M-rows it implies) plus the table mapping every PLAN-004 §5 ⟨v5⟩ marker to its answering
decision, and the rewritten TL;DR, Context, D1–D8, Consequences, Not decided, handoff and
Cross-references, re-pinned to HEAD `3920814` (v5 commit `21c1728`).

## What the review must do

1. **Disposition of the nine required changes**, one row each: ADDRESSED / PARTIAL / NOT
   ADDRESSED, with the evidence, in the shape of the v4 review's §1.2.
2. **Disposition of the nine v4→v5 retractions**, one row each, as the v4 review's §1.1 did.
3. **Per-decision verdicts** D1–D8, ACCEPT / ACCEPT WITH CORRECTIONS / RETURN, with reasons.
4. **Check the new mechanisms against HEAD** (`21c1728`, coordinates at `3920814`), each with
   file:line — the same nine checks as the v4 brief, re-applied to v5's text:
   - D1's **stopping contract** and the T0 settings table: is the set of reachable ends under
     those settings exactly what D1 says? Is any arm still reachable that D1 does not name? Is
     the `StopBeforeEnd` cutoff coherent? (v5 change 1: `CallFreeToolCallsFinish`, `BlankStop`,
     hybrid predicate asserted at admission, `HybridExtraction` cutoff.)
   - D1's **runtime-status cutoff** and the claim that no other tool bypasses the queued seam at
     T0.
   - D2's **guarded-delegation seams**: writable as specified with only exported names? Does
     replacing the last interaction's `request_projection` preserve everything downstream reads?
     Is "assert exactly one interaction appended" always true (fault and mismatch paths)?
   - D2's **exhausted marker** handling: `{served:false}`, non-retryable `Err`; `script_of`
     skips it; `ProgramExhausted`/counts see it; a run containing one can never satisfy A6/K6.
   - D2's **program sketch** and manifest: does `validate_manifest(m, driver_only())` accept what
     D2 fills, and is every required field sourced? (v5 change 5: A9b, seven run-specific values,
     `driver_only_manifest`.)
   - D3's **witness** construction: per-key env-read counts for the T0 settings; `env_balance`,
     `absent_classes`, clock delta for a zero-approval run; does the synthetic profile config in
     `files` get read by the recording adapters' file port? (v5 change 3: `witness_C` from C's
     own trace/queues/worlds.)
   - D3's **A8/K4**: can `execution_of` be called with the listed inputs, and which families are
     vacuous at T0? (v5 change 4: eight-argument `execution_of`, `decision_budget`, sub-obligation
     census.)
   - D5's **protected regions** by function-text hash: is the listed closure the right set, and is
     a hash of function text implementable from existing tooling or new tooling? (v5 change 6:
     dependency closure of `recording_ports`, checker contract, execution provenance.)
   - D5's **line-neutral variant commit**: achievable at `3920814` for all sites without moving
     `anchors.sh`'s pinned lines or `derive.py`'s bridge span? Say which lines would be joined.
     (PLAN-004 §3 P1.1 lists the five joins; verify them.)
   - D6's **contextual scan policy**: the recorded r2.1 counts (v5 change 8) — are they consistent
     with the policy text, and is the body-16 sharpening sound against `credential_value_prefixes()`?
   - D4's **measured process**: is "the seed fold runs inside the measured process" consistent
     with what the profile captures, and does it change the control comparison?
   - D8's **per-family sentence / M15 ruling** (v5 change answering PLAN-004 §5 ⟨v5⟩ D8): does the
     revised sentence ("per refusal family one refused case + clean twin; per cutoff ...; per
     A1–A9/A9b and K1–K7 ...; per `ReplayMismatch` variant ...; per seam arm ...; witness
     under/over-count; census rows zero-by-name + non-zero twin; one vacuous family") hold
     together, and is the ruling (M15's `AdmissionCheck` near-misses satisfy the per-check
     requirement, not required per refusal family) coherent?
5. **Everything factually wrong** in v5 — code, numbers, or what the reviews said — as a list
   with corrections, including any coordinate in the Cross-references that does not resolve.
6. **Anything a v6 must still change**, as a numbered list, or state that PLAN-004 v2 may be
   written against v5.

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-adr004-v5-verdicts-claude.md` in
the shape of the v4 review: header (date, HEAD, branch, subject, prior, method, what you did not
do); overall verdict; §1 the two disposition tables; §2 per-decision verdicts; §3 the mechanism
checks; §4 claim audit; "Required changes for v6" (or "None: PLAN-004 v2 may be written against
v5"). Every claim carries a file:line at `21c1728`/`3920814` or a command and its output. State
in the header that Codex is not available in this container so the review was run with claude,
per the operator's delegation orders. When finished, reply with only the review file's path.
