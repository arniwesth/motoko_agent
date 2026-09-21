# PLAN-003 v3.1 delta verdicts (REV31)

Date: 2026-09-12
Reviewed HEAD: `e69df2cfca45bbc2cdff4f0c49a51157cbd265fd`
Subject: `PLAN-003-implement-adr-003.md` §6, paragraph "v3 → v3.1" — the six
deltas the v3 review (`REVIEW-plan003-v3-verdicts-fable.md`, Required changes
1–6) asked for — against what P1 (`cbf50f3`, `110c3b7`, `784f354`, `06b07ca`,
`253438b`, `20c3e87`) and P3 (`54e44ff`, `c5f0893`, `a629dbc`, `51bfae0`,
`845239c`, `ffe1833`) actually landed.
Method: each landing commit's body is the specification record; the tree was
spot-checked only where a body was ambiguous (`src/core/rpc.ail`,
`src/core/phase_vocab.ail`, `scripts/dst/phase_c2_wiring_scenarios.ail`,
`Makefile:637`). No sweep was run (memory ceiling); gate evidence is quoted
from the commit bodies.

## Overall verdict

**Five held, one drifted, none wrong.** The v3.1 repair did what the v3 review
asked: P3 compiles in order, the digest gate recomputes, the frame sees
images, the resume count never touches the port, and the four helpers are
exported. The one drift is delta 6's second half: `history_digest` landed as a
`{ at, prev }` pair at 19 literal sites, not the single field at fifteen the
plan priced — and the pair is the reason the `:2251` replacement is
unfakeable, so the drift is load-bearing rather than sloppy.

| # | delta | verdict | short reason |
|---|---|---|---|
| 1 | P3 reordered: vocabulary → fold+family (red) → emits (green); Parts 4–6 renumbered | **held** | `54e44ff` (vocabulary, five variants, rows, goldens, zero emits — measured `grep -c` 0/0/0/0/0), `c5f0893` (fold + family, red on purpose: `stream_parity` × 6 `journal-fold-disagrees`), `a629dbc` (emits, family green, `expected_family_rules` untouched). Order compiles; Parts 4–6 are host writer → `--resume` → wire. |
| 2 | wiring-fixture digest gate recomputes the incremental chain, not whole-list `digest_messages` | **held** | `phase_c2_wiring_scenarios.ail:1041–1095`: chain recomputed over `suspended.history` from `chain_empty_base()`, compared with the run's last `digest_after`; the row states comparing with `digest_messages(suspended.history)` would never pass. `a629dbc` further records the base is `chain_empty_base()`, not the seed's `digest_messages` — the plan's sentence quoted and corrected at the row. |
| 3 | Open question 8 settled: per-message frame includes `images` | **held** | `phase_vocab.canonical_message_frame` (`:346`, exported) is `canonical_messages_raw`'s frame plus an `images` frame; `c5f0893` asserts the negative first (old form blind to an image change) then the frame seeing it. `canonical_messages_raw` bytes unchanged (28 goldens green). |
| 4 | `MOTOKO_RESUME_COUNT` read ambiently in `rpc.run_with_config`, not through the port | **held** | `rpc.ail:218` `resume_count_env()` reads ambient `getEnv`, on `headless_mode()`'s pattern, with the §0.8 comment; called at `:434` and `:552`. No `ports.env_get` for the key anywhere (`session.ail` env reads are `MOTOKO_SESSION_ID`, persist/retry, `OPENAI_BASE_URL`, `MOTOKO_HEADLESS` only). `51bfae0` confirms the rule holds; `845239c` forwards it through the `--resume` spawn with `bumpSessionResumeCount()`. |
| 5 | four `phase_vocab` helpers exported in P1 Part 3; `History` via `history_from_seed` | **held** | `784f354`: `system_is_head_prefix` (`:81`), `take_system_prefix` (`:91`), `canonical_messages_raw` (`:298`), `digest_messages` (`:350`) exported, each with its ADR-rule note; `History`/`MkHistory` stay sealed, reached through `history_from_seed` (`:28`) — `probe_phase_vocab_sealed.ail` still fails `IMP010`, which is its pass. Verified at HEAD. |
| 6 | `history_digest` literal sites named; canary carried as Open question 9 | **drifted** | Canary half held: `depth_canary` under `DST_KNOWN_RED` (`Makefile:637`, with `driver_plus_herdr herdr_graded` per the P3G ruling `e69df2c`) and the re-measure pending as the owner's call — exactly the carried question. Field half drifted: the plan priced one field at fifteen literals; the tree has `history_digest: { at, prev }` — a pair — at 19 `history_digest:` sites (`session.ail`), plus the `{ at, prev }` type. `a629dbc` states why: the hybrid `:2251` replacement chains from the digest *before* the replaced entry, so a child carrying only the running digest cannot produce what the fold demands. One field is what §0.2 priced; a pair is what D4's unfakeability needs. Load-bearing drift, recorded in the landing commit, not silently taken. |

## 1. Sequencing (v3 review items 1–2)

- **Vocabulary → family → emits.** Item 1's three-commit split is exactly
  `54e44ff` → `c5f0893` → `a629dbc`. Part 1 declares five variants with 41
  rows / 41 variants / 41 goldens and constructs none (measured, not claimed).
  Part 2's family is red only where a real run becomes an `ExecutionUnderTest`
  — `stream_parity`, two executions — and the commit says so rather than
  claiming the ADR's "every fixture" (drift worth the owner's attention,
  recorded in the body). Part 3 turns it green by emits alone.
- **D6.4 gap register** went 2 → 7 (Part 1) → 3 (Part 3) → 2 (Part 5), the
  shrink-only rule working in the direction it was written for.
- **Renumbering.** Parts 4–6 are the host writer (`51bfae0`), `--resume`
  (`845239c`), the wire (`ffe1833`) — the plan's renumber, landed.

## 2. Digest gate (v3 review item 2)

Held, with one correction recorded at the row: the base is
`chain_empty_base()`, because the journal has no `history_seeded` entry type
— the host expands a seed into N `history_appended` entries — and every digest
the fold reads must be recomputable from the entries alone. A gate based at
the seed's `digest_messages` would refuse its own first entry. The plan's
sentence is quoted at the fixture row and resolved toward Part 2's chain
decisions (base empty, `history_replaced` re-bases to
`chain_digest_base(prefix ++ messages)`, `replaces_previous` chains from the
pre-replacement digest).

## 3. Frame with images (v3 review item 2, second half)

Held. The shared four fields moved into private `canonical_message_body` so
the two forms cannot drift; `journal.chain_digest_after` is the frame's only
caller — one definition of the chain digest, no second message encoder.

## 4. Ambient resume count (v3 review item 3)

Held. P1 Part 5 (`253438b`) is where the rule is exercised live: the loop's
`resume_count` parameter threads from `rpc.run_with_config`'s ambient read,
and `run_id_for` (`<session_id>.r<resume_count>.<run_ordinal>`) is correct
under `resume_count > 0` precisely because the initial traced run is a `Some`
caller rather than taking the default arm.

## 5. Exported helpers (v3 review item 4)

Held. Plus the scope note the commit states honestly: two pure one-liners
(`chain_digest_base`, `chain_digest_after`) came with the exports so the
exports are live beside the codec — one step past the plan's bullet list, no
entry type, no fold, no Refusal with them.

## 6. Literal sites and the canary (v3 review items 5–6)

- **Fifteen sites named: drifted to a pair at nineteen.** Item 5 asked for the
  fifteen `C2LoopState` literal sites the field touches so the estimate holds.
  What landed (`a629dbc`) sets the field at all full literals — 13 loop + 2
  constructors + 2 test literals — and the field is `{ at, prev }`, not one
  digest. The estimate held anyway (P3 stayed inside 9–12d envelope per the
  sweep record), but a future plan that prices "one field" for a chain with a
  replacement rule will undercount again.
- **Canary as Open question 9: held.** `DST_KNOWN_RED := depth_canary
  driver_plus_herdr herdr_graded` (`Makefile:637`); every P3 sweep gate reads
  "green, with depth_canary reported as known red". The two herdr entries are
  the P3G ruling (`e69df2c`), disclosed not waived.

## Required changes

None — REV31 is a review, and there is nothing to repair. Two notes for the
owner, neither gating:

1. The `history_digest` pair vs the plan's single field (delta 6): ratify the
   pair as the decided shape, since `:2251`-class replacements need `prev`.
2. `event_vocabulary_version()` is still `"event-vocabulary/1"` after two
   variant-adding commits (P1 Part 4's `RunSuspended`, P3 Part 1's five) —
   flagged in `54e44ff` as wanting one deliberate commit covering both
   variants, still open at HEAD.
