# Brief: adversarial review of PLAN-004 v2 + its v2 graph (same shape as the v1 review)

Repo `/workspaces/motoko_agent`, branch `arniwesth/013-plan003-and-herdr`, HEAD **`51978b5`**
(verify with `git rev-parse HEAD`; if HEAD has moved, say so and review against what is there).
Code pin for all code facts: **`3920814`** (read code with `git show 3920814:<path>`; HEAD adds
only docs + `scripts/eval/` guard files — verify with
`git diff 3920814 HEAD --stat -- src/ scripts/dst/ Makefile tools/`).

## Rules

- **Read-only.** Edit nothing under the repo except the one review document you write. No commit.
- No `make dst`, no replay, no prototype run, no profiling, no other heavy execution: memory is
  contended (cgroup 24 GiB, the 12 GiB `memory.current` rule). `ailang check`, `git show`,
  `dagr check`, `dagr view --snapshot` and targeted Python reads of existing files are fine.
- Do not open, close or prompt any herdr pane or agent. Do not edit `.dagr/run-plan004.json`
  or `.dagr/run-plan004-v2.json`.
- **Privacy:** counts, digests, indices and identities only — no corpus content.
- Temporary evidence goes under `/tmp/` (create a scratch dir).
- You are **claude** (Codex is not available in this container): state that in the header and
  name the review file `REVIEW-plan004-v2-verdicts-claude.md` so provenance stays honest.

## Under review

1. `.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md` — now **v2**
   (commit `51978b5`, `PSYNC`), re-grounded on ADR-004 v5. §9 lists the v1.2→v2 deltas and the id
   supersede map; §5's ⟨v5⟩ table is closed as answered; §8's prompt is rewritten for the fresh
   session on the v2 graph. No ⟨v5⟩ marker may remain outside §9's history sentence
   (verify: `grep -c "⟨v5⟩"` on the file must print 1).
2. `.dagr/run-plan004-v2.json` — the NEW v2 operator graph (run `run-plan004-v02`, 40 tasks),
   strict-clean. Its evidence copy at
   `.agent/projects/013_core_architecture_for_dst/evidence/plan004-v2/run-plan004-v2.json`
   must be byte-identical (compare sha256).

Governing inputs, read in full:
- `ADR-004-journal-as-evaluation-source.md` **v5 Accepted** (status flipped by PSYNC citing V5G).
- `REVIEW-adr004-v5-verdicts-claude.md` — the v5 review: ACCEPT WITH CORRECTIONS (C1–C6 +
  cosmetic, applied in `988a863`); "Required changes for v6: None".
- Your operator's V5G ruling (in `.dagr/run-plan004.json`'s directive events): M15 near-misses
  satisfy the per-check requirement, inapplicable rows stand.
- For format: `REVIEW-plan004-v1-verdicts-codex.md` and
  `REVIEW-plan004-v1.1-delta-verdicts-codex.md` (the two prior returns and their required-change
  lists — confirm each is disposed in v2).

## What the review must do

1. **⟨v5⟩ closure.** Every v1.2 ⟨v5⟩ site (§5 rows D8,1–8 + park/wake + decoders; inline sites in
   §0.9, §2 V5/PSYNC, §3 M1/M15/P1.2a/P1.3/P1.4b/P1.5/P1.6/P1.7a/P1.7b/P1.8/P1.9a/P1.9b, §4 P3.2)
   is replaced by the v5 decision §5 names. One row per site: REPLACED / PARTIAL / LEFT OPEN.
2. **Fidelity to ADR-004 v5.** One row per D1–D8 decision: where v2 carries it, CARRIED /
   PARTIAL / MISSING / CONTRADICTED. In particular: the Parked cutoff with the C1 wording; copies
   (not imports) pinned by span hash; C2's seam count; C3's digest span rule; C4's module list;
   C5's closure-as-starting-set + §3.8 transitive names; C6's brace rule; same-basis control
   primary; the revised D8 per-check sentence + M15 ruling. Flag anything v2 adds that v5 does not
   license, and anything it decides that D8/v5 left to a part (defaults still marked overridable?).
3. **Id supersede map.** The nine new ids (`P1.2a-v2`, `P1.2b-v2`, `P1.3-v2`, `P1.7a-v2`,
   `P1.7b-v2`, `P1.9b-v2`, `P1R-v2`, `P3.2-v2`, `P3.3-v2`) — is the rule ("new id when v5 changed
   what a part must build or test; kept when v5 only confirmed values/coordinates") applied
   consistently? Contest any kept id that should have changed (`P1.5`, `P1.4b`, `P1.6`, `P1.8`,
   `P1.9a`, `P1G`) and any new id that need not have changed, with reasons.
4. **Code facts at HEAD/pin.** The v2 plan's §0.9 (incl. `tool_outcome_record :2133`, C4's module
   list, park row withdrawn), P1.1's five joins (line-neutral, anchors, bridge span), `Makefile:697`
   and Make target lines. Name any file:line that does not resolve at `3920814`.
5. **Per-part review** of every part whose scope/deps/criteria changed (at minimum the nine new
   ids): ACCEPT / ACCEPT WITH CORRECTIONS / RETURN. For each: one reviewable commit for one
   delegate; real red-first/mutation tests; mechanically checkable gate; deps right; nothing built
   that D8 says is not built. Unchanged parts: confirm the v1/v1.1 verdicts still stand, or
   re-open with reasons.
6. **The D8 matrix.** Does the v2 matrix cover D8's revised per-check contract (refused + twin per
   refusal family; cutoff/N/end; A1–A9/A9b + K1–K7 pinned first finding + location; ReplayMismatch
   variants; seam arms; witness under/over-count; census zero-by-name + twin; one vacuous family)?
   List gaps.
7. **Standing rules and safety** (§0): sweep, memory/heavy-exclusivity, privacy/exposure, commit
   rule + PSYNC's exception, QRET record. Anything unenforceable or missing?
8. **The v2 graph.** `dagr check .dagr/run-plan004-v2.json --strict --json` output; graph ↔ v2-text
   consistency (every part exactly one task, deps = §1 skeleton, fan-ins, criteria, honest
   owner/kind, ready set, `PSYNC`/`PREV`/`PLAN2G` and `P1.1`/`P1.1R`/`P1.1G` loop policies,
   `supersedes` map present); usable as a fresh session's `dagr_plan` (new run id, no copied
   attempts/events/policy — terminal summaries only); the fresh-session/PLAN2G design (§2/§8: PSYNC
   + PREV settled in v01, mirrored as summaries in v2, first Delegate outside PLAN2G) — sound?
9. **Everything factually wrong**, with corrections.
10. **Required changes for v2.1**, numbered, or state that v2 may start as written (PLAN2G may be
    settled and the fresh session started).

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-plan004-v2-verdicts-claude.md` in the
shape of the v1 review: header (date, HEAD, branch, subject, inputs, method, what you did not do,
evidence directory, claude-not-Codex statement); overall verdict; §1 ⟨v5⟩ closure; §2 fidelity;
§3 id map; §4 code facts; §5 per-part verdicts; §6 D8 matrix gaps; §7 standing rules; §8 the v2
graph; §9 claim audit; "Required changes for v2.1" (or "None: PLAN-004 v2 may start as written").
Every claim carries a file:line at HEAD/pin or a command and its output. When finished, reply with
only the review file's path.
