# Brief: adversarial review of PLAN-004 v1 (and its dagr graph)

Repo `/workspaces/motoko_agent`, branch `arniwesth/013-plan003-and-herdr`, HEAD **`3920814`**
(verify with `git rev-parse HEAD`; if HEAD has moved, say so and review against what is there).

## Rules

- **Read-only.** Edit nothing under the repo except the one review document you write. No commit.
- No `make dst`, no replay, no prototype run, no profiling, no other heavy execution: memory is
  contended (cgroup 24 GiB, the 12 GiB `memory.current` rule). `ailang check`, `git show`,
  `dagr check`, `dagr view --snapshot` and targeted Python reads of existing files are fine.
- Do not open, close or prompt any herdr pane or agent. Do not edit `.dagr/run-plan004.json`.
- **Privacy:** do not copy conversation content from journals, host logs, `.motoko/memfix/` or any
  corpus file into the review. Counts, digests, indices and identities only.
- Temporary evidence goes under
  `/tmp/claude-1001/-workspaces-motoko-agent/d8b1d53b-1a2d-4c49-b4ec-fc412754e86a/scratchpad/codex-review-plan004/`
  (create it). You may reuse the v4 review's scripts and outputs in
  `/tmp/claude-1001/-workspaces-motoko-agent/0dc4f7fe-4912-46cb-8ed0-5a4e6fc6a2b5/scratchpad/codex-review-v4/`
  if they still exist.

## Under review

1. `.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md` — proposed v1,
   unreviewed, written 2026-09-15.
2. `.dagr/run-plan004.json` — the plan's dagr graph (contract v3), which Motoko will use as its
   `dagr_plan` to delegate the implementation (plan §8).

Governing inputs, read in full:
- `ADR-004-journal-as-evaluation-source.md` **v4** (status Proposed).
- `REVIEW-adr004-v4-verdicts-codex.md` — your own v4 review: **RETURN for v5**; D1, D3, D5
  RETURN; nine "Required changes for v5".
- For format and conventions: `PLAN-003-implement-adr-003.md` (§0 standing rules, the P4 part
  layout, §5 records), `.dagr/run-plan003.json`,
  `HANDOFF-2026-09-12-plan003-p1-and-the-delegation-view.md` §6 (the orchestrator prompt the
  plan's §8 copies), and `.agent/projects/021_herdr_delegation/DESIGN-dagr-as-delegation-view.md`
  §10.5–10.5.1 (`dagr_plan` / `dagr_task`).

## The plan's central choice — judge it first

The ADR's handoff asks for PLAN-004 against the ADR; your review said PLAN-004 should follow a
corrected v5. The plan does **not** wait: it starts P0 (preserve, sweep, pre-scan), P2.1 (guard),
the `PortedWorld` variant commit (P1.1, on your §3.9 joins) and the v5 revision itself now, and
gates every D1/D3/D5-dependent part behind `V5 → V5R → V5G → PSYNC → PREV`, marking unknowns
**⟨v5⟩**. Is that split sound? Specifically: does anything scheduled before `V5G` depend on a
returned decision or on a v5 required change (including P1.1, SCAN0's use of the body16 policy,
P2.1's defaults)? Is anything gated behind v5 that need not be?

## What the review must do

1. **Fidelity to ADR-004 v4 + your nine required changes.** One row per D1–D8 decision and per
   required change 1–9: where the plan carries it (section/part), CARRIED / PARTIAL / MISSING /
   CONTRADICTED, with evidence. Flag anything the plan adds that neither the ADR nor the review
   licenses, and anything it decides that D8 or the ADR left to PLAN-004 (retention, guard margin
   and polling, unlimited `memory.max`, evaluator paths, the E worktree) — are those defaults
   reasonable and marked as overridable?
2. **Code facts at HEAD.** Check every coordinate the plan states as verified at `3920814` (§0.9
   drift table, P1.1's five joins, the anchors at `anchors.sh:614–617`, `BRIDGE_SPAN`,
   `Makefile:697` and the Make target lines in Cross-references, the `ParkOrWake` staleness claim
   against `686da16`). Is P1.1 still line-neutral at HEAD without moving any pin in
   `tools/predicate-anchors/anchors.sh` (all of them, including any `stub_step.ail` pin) or
   `derive.py`'s span? Name any file:line that does not resolve.
3. **Per-part review** (P0 tasks, ADR track, P1.1–P1.9, P1G, P2.1, P2.2, P3.1–P3.3, P3G, P4–P6):
   ACCEPT / ACCEPT WITH CORRECTIONS / RETURN. For each: is the scope one reviewable commit a
   single delegate can finish (estimate realistic?); are the tests real red-first where claimed and
   do they actually exercise the named check; is the gate mechanically checkable; are the
   dependencies right (missing edges, needless edges); does any part build something D8 says is
   **not built** (a second comparison walk, reconstitution, persistence codec, manifest type)?
   Pay particular attention to: P1.4's protected-source checker design; P1.5's seams against the
   exported surface at HEAD (`stub_step.ail:478,635`, `ports.ail` recorder/codec functions after
   the +46 shift); P1.6's use of `run_v2_session_traced` and `validate_manifest(m, driver_only())`;
   P1.9's assembly and refusal mechanics; P2.1's guard semantics; P3.2's suggested same-basis
   control (A with `de4b4f5`'s change reverted as a candidate diff) — is it admissible under D3's
   candidate class and D5's protected regions, and does it actually regress allocation?
4. **The D8 matrix.** Does the union of P1's tests cover D8 P1's list (one known-divergent and
   one known-refused case per refusal family, one per `ReplayMismatch` variant, one per cutoff,
   one per seam fail-closed arm, witness under/over-count) plus your required changes 3–5's new
   cases? List gaps.
5. **Standing rules and safety** (§0): the sweep precondition, the memory and heavy-exclusivity
   rules, privacy and exposure (including "Motoko counts as candidate-producing" and held-out
   handling in P4), the commit rule and its stated exceptions. Anything unenforceable or missing?
6. **The dagr graph.** Run `dagr check .dagr/run-plan004.json --strict --json` and report the
   output. Then check graph ↔ plan consistency: every plan part has exactly one task, deps match
   the plan's stated dependencies and §1 skeleton, gates' fan-in equals the parts they gate,
   criteria agree with the plan's gate text, `owner`/`kind` are honest (questions and gates the
   operator's), the ready set at start is what §1 and §8 claim (PRESERVE, SWEEP, V5, P2.1, QRET),
   and the `V5R` loop policy is sensible. Is the graph usable as Motoko's `dagr_plan` under
   DESIGN-dagr-as-delegation-view §10.5 (plan read, never written by the producer; seeding
   idempotent)? Note that the plan's §8 prompt tells the orchestrator to edit the plan file after
   each settlement — does that conflict with §10.5's one-writer rule, and what should §8 say?
7. **Everything factually wrong** in the plan — code, numbers, what your review said — as a list
   with corrections.
8. **Required changes for v1.1**, numbered, or state that v1 may start as written.

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-plan004-v1-verdicts-codex.md` in the
shape of your ADR-004 v4 review: header (date, HEAD, branch, subject, inputs, method, what you
did not do, evidence directory); overall verdict; §1 the central split; §2 fidelity table; §3
code facts; §4 per-part verdicts; §5 D8 matrix gaps; §6 standing rules; §7 the dagr graph; §8
claim audit; "Required changes for v1.1". Every claim carries a file:line at HEAD or a command and
its output. When finished, reply with only the review file's path.
