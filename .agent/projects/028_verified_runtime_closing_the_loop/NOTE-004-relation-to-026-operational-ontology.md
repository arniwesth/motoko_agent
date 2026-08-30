# NOTE-004 — 028 ↔ 026: the operational ontology is the *general theory* of what ADR-002 instantiated (2026-08-30)

Relates to: `../026_operational_ontology/RESEARCH-operational-ontology-implications.md`
(2026-08-27, two days before the two assessment sessions).
Evidence base: NOTE-001/002/003, ADR-001/002, PLAN-001/002 in this folder.

## The relation in one line

**026's ontology and 028's ADR-002 are the same epistemic move at two altitudes.**
The ontology says: a semantic layer you cannot branch on is not enough — state
must carry *named, machine-checkable descriptions of itself* (typed actions
with preconditions, refusal codes, authority maps, audited attempts), because
prose-with-no-schema drifts and forces every consumer to parse strings.
ADR-002 says: a rationale layer you cannot branch on is not enough — process
artifacts (WI ids, examples, deprecations, failure modes) must be *generated,
gated artifacts*, because prose-with-no-gate drifts. 026 supplies the general
theory ("the map is the contract"); 028 supplies a second, independent
instantiation of it (rationale instead of domain state), plus the measured
cost of *not* having it (NOTE-003's 861 unresolvable WI mentions; doc drift as
the only finding class both sessions share).

The kinship is visible at the sentence level:

| 026 (ontology, domain state) | 028 (ADR-002, rationale layer) |
|---|---|
| "Business rules at actions: preconditions → machine-readable refusals" | `glossary_check` fails on a `WI-9999` citation; surface check fails on new adapter callers |
| "`Deny(string)` — free text, no code ... forces the model to parse prose" | 861 WI mentions that resolve to nothing; comments are the only doc and nothing protects them |
| "generate tool schemas from it ... so drift is a compile error, not a silent gap" | "generate the artifact, gate the generator" (`registry_gen_check`, vocabulary validator) |
| Authority map: `source-backed / ontology-owned / derived` per field | Provenance tiering per claim: `verified / skipped / unbacked` (VISION-001 Layer 3) |
| Audit log of every attempt, refused or applied | The session JSONL ledger; NOTE-002's fold-wall probe table |

## What this relation *changes* in 028

1. **ADR-002 stops looking like a documentation policy.** Framed by 026, it is
   an *authority map over project knowledge*: sprint-id semantics are
   ontology-owned (one generated glossary), examples are source-backed (CI-run
   code), prose claims in notes are derived (and regenerable). The four
   parallel numbering systems are exactly what 026 calls an untyped semantic
   layer — and NOTE-003 measured the parsing cost Motoko currently pays for it.
2. **PLAN-002 item 1 (glossary) gains a schema, not just a list.** 026's
   objects/links/actions shape maps directly: each `WI-…`/`M-MOTOKO-…` id is an
   *object*; `relates-to`/`supersedes`/`blocked-by` are *links* (WI-A13 cites
   others; PLAN-001 item 2 shares the batch-veto regression); the *actions* are
   the gates (`glossary_check`, `check_surface`) with preconditions
   ("id resolves", "caller is not new"). 026 §6's own mitigation — generate
   schemas so drift is a compile error — is verbatim the ADR-002 posture.
3. **VISION-001 Layer 3 (claim provenance) is confirmed from an unexpected
   direction.** 026 independently derives the same three-vocabulary need
   (`source-backed/ontology-owned/derived`) for *external* state that VISION-001
   derives for *agent claims*. Two projects, no shared authorship, same shape —
   that convergence is itself evidence the vocabulary is the right one.
4. **The failure-mode triage rule (ADR-002 §4) becomes "refusals are domain
   data."** `PAR_INFINITE_LOOP` is a refusal with no code and no retry hint;
   026 §3.1's `Refusal = { code, reason, retry_hint }` is exactly the shape
   the parser hang lacked — and NOTE-002 measured what free-text/hang failures
   cost an agent consumer (~10 bisect steps).

## What 028 adds back to 026

026 was written before either assessment session; two of its implicit
assumptions now have live evidence, and one of its anchors has aged:

1. **Its premise — "Motoko already has the mechanism half ... but none of the
   model half" — is confirmed, and sharpened:** the runtime *does* enforce
   typed decisions at its own boundaries (cells refuse unverified code; DP7
   exists), but the *project's self-description* (comments, examples, Makefile
   pins) is the biggest un-modeled domain in the repo. NOTE-003 is that domain
   surveyed. If 026's pattern is adopted per §7 item 3 (github-ops first), the
   project's own rationale layer is the zero-risk second instance — the schema
   is already written (this folder), only the generator is missing.
2. **Its line-number anchors have begun to drift — gently.** All three anchors
   still resolve today (`types.ail:592` `Deny(string)`, `:594` `Pending`,
   `:1010` `ToolPolicy` — verified 2026-08-30), but 026 cites *positions*, and
   the ABI file is under active change. ADR-002's generate-and-gate posture
   applies to 026's own references: anchor to symbols, not line numbers, so
   research notes survive their substrate moving. (Same class as PLAN-001
   item 3 / NOTE-002 defect 2.)
3. **A convergence worth naming for both projects:** 026 §6 flags
   "ABI churn — batch the next major" as a risk to *wait*; NOTE-002's W1-W3
   are a concrete, low-risk change queued for the same toolchain. If either
   lands, co-schedule: one ABI/verifier major, one changelog entry, both
   rationales updated in the same gated commit.

## Status

Research note; no decisions changed. 028's ADR-002/PLAN-002 stand as written —
026 strengthens their grounding and suggests two refinements (glossary schema
with links; symbol-anchored references) without altering any work item. The
candidate follow-ons in 026 §7 remain open and are unaffected.
