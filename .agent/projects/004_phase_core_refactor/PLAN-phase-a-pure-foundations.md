# Phase-A implementation plan: pure foundations, zero behavior change

Date: 2026-07-03
Status: Draft (implements Phase A of the **Proposed** `ADR-001-phase-oriented-core.md`)
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`, built `2026-07-02_15:03:57`);
`ailang.lock` → `ailang_version: "v0.26.0"`. Verified this session: `ailang --version` =
v0.26.0 / `3b52a24`. **Every `file:line` anchor below was re-read against HEAD (commit
`8227053`) this session** (see "Anchor re-verification log" at the end); `git log` shows no
commit touching `src/core/` after 2026-07-02 (`d5bb7cc`), so no inherited citation predates a
source move. All sketch/probe artifacts and `scripts/smoke_ports_record.ail` were **re-run**
this session before being relied on (results in the log).

Authored by a fresh session per `NOTE-plan-authoring-session-choice.md`; produced from the
committed documents alone, with discrepancies recorded in "ADR gaps found" rather than guessed
around.

Relates to:
- `ADR-001-phase-oriented-core.md` — normative; Phase A deliverables + gate (ADR "Migration
  plan and gates", Phase A) are this plan's acceptance criteria.
- `RESEARCH-phase-core-dst-design.md` — elaboration; cited as **§N**.
- `sketch/` — the substrate proofs and the vocabulary seed (`sketch_vocabulary.ail`).
- `../003_CSP_core_refactor/PLAN-phase1-run-tool-select.md` — house style followed here.

---

## TL;DR

**What:** the three Phase A deliverables, in dependency order, each landing with the system
shippable and the event stream byte-identical:

1. **WI-0** — build the mechanical **no-diff gate** first: an event-parity harness
   (`scripts/phase_a_event_parity.sh`) that runs a fixed set of scripted (`Scripted`
   provider, no network) smokes with `MOTOKO_SESSION_ID` pinned, normalizes the one
   nondeterministic field (`duration_ms`), and byte-compares JSONL streams before/after. A
   new scripted smoke (`scripts/smoke_phase_a_tool_parity.ail`) closes the discovered
   coverage hole: **no existing scripted smoke drives a native tool dispatch** (zero users of
   `stub_step.tool_step` today).
2. **WI-1** — name the compaction constants in `src/core/compaction.ail` as zero-arg
   `export pure func`s (`elide_tier_pct`=70, `elide_hard_tier_pct`=85, `emergency_pct`=95,
   keep-lasts 10/5, plus the emergency keep-lasts 3/1 found by the survey), replacing the
   inline literals at `compaction.ail:111-138`. The measurement primitives are **already
   exported** (`estimate_tokens_messages`, `usage_percent`, `usage_percent_with_limit` —
   `compaction.ail:34,42,47`), confirming the ADR's "partly done" note (with a naming
   imprecision recorded in ADR gaps).
3. **WI-2** — create the vocabulary module **`src/core/phase_vocab.ail`** (Open Question 1
   resolved: keep the ADR's working name; `transcript.ail` **does not exist at HEAD** to be
   "expanded" — gap G1), seeded from `sketch/sketch_vocabulary.ail`: sealed
   History/Segment/Payload + ops, StepState/StepDecision/PhaseResult/LedgerEvent +
   `to_schema_v1`, checkpoint types + atomic `apply_checkpoint`. Lands **unused** by
   production. `decide` does **not** land (Phase C; it belongs to a future
   `step_machine.ail`). A sealing probe under `scripts/` re-proves `IMP010` opacity against
   the real module.
4. **WI-3** — extract the transcript builders from `agent_loop_v2.ail` into `phase_vocab.ail`
   and re-import them: `step_result_to_message`, `cap_tool_message_content` (+ its two inline
   tests), `tool_result_message`, `envelope_to_tool_message`, plus the survey's finds —
   `result_env_model_content` (dependency), `msgs_to_messages` (provider-facing converter),
   and a new `handled_tool_message` consolidating **three byte-identical inline tool-message
   literals** (`agent_loop_v2.ail:823,886,909`). Every call site enumerated below.
5. **WI-4** — the gate checklist, run as a block.

**Gate (ADR, verbatim):** `ailang check` + existing smokes green; **no event-stream diff** —
made mechanical by WI-0. Empirically validated this session: two pinned-session runs of
`smoke_v2_cost_budget_full_loop.ail` and `smoke_v2_compaction_full_loop.ail` are
byte-identical after `duration_ms` normalization.

**Out of scope (below), ADR gaps found (below):** seven findings, one load-bearing (G3: the
`context_limit_for` static table returns 0 for every model at HEAD — the model-name-keyed pure
compaction path is dead code and `smoke_v2_compaction_tiers` was red at HEAD by its own pass
criterion). *All seven were dispositioned same day (operator sign-off) — see the Addendum in
"ADR gaps found" and the ADR's Plan-Authoring Findings & Dispositions log; the tiers smoke is
repaired and green.*

---

## Goal

Land Phase A of ADR-001 — vocabulary module, named compaction constants, transcript-builder
extraction — with **zero behavior change**, defined operationally as: every gate command green
at every step boundary, and the event-parity harness reporting byte-identical normalized
streams against the WI-0 baseline. Extractions and additions of unused pure code only: no
event-stream changes, no ABI changes, no dispatch changes, no new production code paths.

## Out of scope (do not build here)

Readers of the ADR might expect these; they are explicitly **not** Phase A:

- **Ledger emission / `to_schema_v1` wiring** — Phase B. The `LedgerEvent` type and projection
  land as unused pure code; all 48 production emission call sites (39 `emit_event` + 7
  `emit_run_summary` + 2 `emit_stream_chunk` + 4 `emit_json`; re-measured this session) stay
  exactly where they are.
- **Compactor chain / `dispatch_pre_step` conversion / ladder relocation into
  `motoko_ext_compaction_structural`** — Phase B (D9). WI-1 only *names* the constants where
  they live today; they relocate with the ladder later.
- **Core-side system-prefix fix** (segment, not raw list, to `dispatch_pre_step`) — Phase B.
  The live gap (§7.0; `rpc.ail:231` + `agent_loop_v2.ail:1154`) stays open through Phase A.
- **`decide` / step machine / driver inversion / `run_v2_with_stub` supersession** — Phase C.
- **Streaming ledger-append handle, byte-parity streaming test** — Phase B.
- **Checkpoint content-hash digest, digest-chain validation, `history_from_seed` chain check**
  — the ops land with the sketch's **labeled placeholder** digest; the real hash is due before
  any digest is consumed (Phase B ledger / Phase C scenarios). v1 never emits
  `TakeCheckpoint`.
- **ABI v3, conformance kit, `compaction_ai` v0.3.0** — parallel track, not this plan.
- **The dead `context_limit_for` path** — G3's wrapper retirement (`compact_step`,
  `usage_percent`, `try_emergency_compaction`, `context_limit_for`) rides Phase B's ladder
  relocation (dispositioned 2026-07-03). *(The `smoke_v2_compaction_tiers` repair originally
  listed here was pulled forward and landed 2026-07-03 as part of the gap dispositions —
  test-only, pre-Phase-A.)*
- **L0/L1 DST scenario families** — Phase C. Phase A's only tests are inline pure tests,
  existing smokes, and the parity harness.

## Settled decisions this plan does not re-open

D1–D9 are settled (research doc §9 decision log; operator sign-off). In particular: sealed
types are unexported single-constructor variants with definer-only co-location (D7 + review
adjudication; re-proven this session — see log); compaction policy is extension-resident over
a core scaffold (D9); `PhaseResult` has no continuation field (Q4, proven re-derivation).
Contradictions with HEAD found during implementation go to "ADR gaps found" in this file and
the ADR's Review Comments — never silent divergence.

## Decision: module name and builder home (ADR Open Question 1)

**`src/core/phase_vocab.ail`, one module, transcript builders included.** Justification:

- The ADR's alternative — "expanding `transcript.ail`" — is unimplementable as written:
  **`src/core/transcript.ail` does not exist** (gap G1). The builders live in
  `agent_loop_v2.ail`. Creating a file named `transcript.ail` would under-describe the
  content: `StepState`, `StepDecision`, `LedgerEvent`, and the compaction scaffold types are
  not transcript concerns.
- Keeping the ADR's working name keeps every citation in the ADR, research doc, and sketch
  README valid — no doc churn.
- Builders in the same module (not a sibling): nothing *forces* co-location (the builders
  never name a sealed type — they work on `[Message]`), but D3/D4 make the vocabulary module
  "the single pure transcript builder … the only producer of provider-facing messages" and the
  home of the transcript invariants. One module = one gate = one import for consumers. The
  ADR already accepts "the vocabulary module is large by necessity" (Consequences). A sibling
  would buy reviewability at the cost of splitting the D3 authority across two files from day
  one. Rejected.
- `src/core/ailang.toml` `[exports] modules` (the cross-package export list) does **not**
  gain `phase_vocab` in Phase A — no external package may import it yet; `make check_core`
  picks the new file up automatically (it globs `src/core/*.ail`).

---

## The call-site survey (the ground truth WI-3 executes)

All line numbers as of HEAD `8227053`; **re-grep before editing** — this file is edited often
(house rule from the 003 plan).

**Functions that move to `phase_vocab.ail`** (byte-identical bodies; same purity qualifiers as
today — `pure` only where already `pure` — to keep the diff mechanical; tightening qualifiers
is a later cleanup):

| Function | Def (with doc comment) | Call sites in `agent_loop_v2.ail` | Notes |
|---|---|---|---|
| `msgs_to_messages` | `:361-376` | `:1160` (post-ext-compaction), `:1510` (`run_v2` entry), `:1676` (`run_v2_with_conversation` entry) | `[Msg]→[Message]` wire-parity converter; the 422 comment is a provider-message invariant → belongs to the gate module |
| `step_result_to_message` | `:378-388` | `:1249` (every model step) | needs `StepResult` (std/ai) |
| `cap_tool_message_content` | `:390-399` (`pure`) | `:474`, `:483` (both inside functions that also move) | its two inline tests `:401-423` move with it |
| `result_env_model_content` | `:473-475` | `:497` (inside `envelope_to_tool_message`), `:824`, `:888`, `:911` (the three inline literals, below) | depends on `result_to_model_json` — already `export pure` at `tool_contract.ail:60` |
| `tool_result_message` | `:477-487` | `:856`, `:961` (native dispatch results) | the Bedrock id-correlation comment `:477-479` moves with it |
| `envelope_to_tool_message` | `:489-501` | `:1297` (response-intercept feedback path) | |

**New constructor (survey find):** `handled_tool_message(call_id: string, env:
ToolResultEnvelope) -> Message`. Three inline record literals build the identical
`{role:"tool", content: result_env_model_content(env), tool_calls: [], tool_call_id: call.id}`
shape at `agent_loop_v2.ail:823-828` (tool-policy `Handled`), `:886-891` (scratchpad-adjacent
`Handled`), `:909-914` (extension `Handled`, with the model-id-vs-envelope-id comment
`:905-908`, which moves to the constructor's doc). Consolidating them is exactly D3's "only
producer of provider-facing messages" applied to the paths the named functions missed. It is
the one WI-3 change that is more than a mechanical move, so it is sequenced as its own commit
(WI-3b) with its own rollback.

**Surveyed and deliberately NOT moved:**

- `messages_to_msgs` (`:541-551`; uses `:530`, `:1154`) — converts *to* ABI `Msg` for
  `ExtCtx.history_slice` and `dispatch_pre_step`. It produces extension-facing data, not
  provider messages; its Phase B home is the `CompactableSegment` boundary. Moving it now
  would put an ABI concern in the vocabulary module for no gate benefit.
- `msg_to_wire` / TUI wire-format helpers (`:553` region) — TUI protocol, not provider
  transcript.
- `result_to_model_json` — already correctly homed and exported in `tool_contract.ail:60`.
- The hybrid-bash synthesis + Bedrock rewrite (`:1303-1343` region, comment `:1316-1333`) —
  §5 maps it to the transcript builder *in Phase B/C* (it is behavior, not a pure
  constructor); Phase A must not touch dispatch.

**External visibility check:** no module outside `agent_loop_v2.ail` imports any of the moved
functions (verified: the only cross-module imports of `agent_loop_v2` are entry points —
`rpc.ail:14` `run_v2_with_conversation`; smokes import `run_v2*`). The extraction is invisible
outside the file.

---

## Work breakdown

Each WI lists **Files touched**, **Verification** (commands run at that step's boundary), and
**Rollback**. Order is load-bearing: the harness (WI-0) must capture its baseline **before**
any production edit; constants (WI-1) before the vocabulary module (WI-2) so `phase_vocab`'s
`CompactionPolicy` doc can cite the named exports; extraction (WI-3) last because it is the
only step that edits production control-flow files.

### WI-0 — Event-parity harness + baseline (the no-diff gate, made mechanical)

New test-only artifacts; zero production code.

- **Files touched (new):**
  - `scripts/smoke_phase_a_tool_parity.ail` — a scripted full-loop smoke closing the
    coverage hole found this session: `stub_step.tool_step` has **zero users** in
    `scripts/` today, so no existing deterministic smoke reaches `tool_result_message`
    (`:856`/`:961`). Shape: `run_v2_with_stub` (def `agent_loop_v2.ail:1692`; provider
    `Scripted`, `stub_step.ail:42`) with a script of
    `[tool_step("ReadFile", <fixture path>, "call-1"), prose_step("done")]` against a
    fixture file the smoke writes itself (fixed content ⇒ deterministic tool output), using
    `empty_rt()` (`stub_step.ail:188`). Asserts the run returns `Ok` and — for the harness —
    emits the `v2_tool_dispatch_start/complete` + `native_tool_results` event bracket.
  - `scripts/phase_a_event_parity.sh` — the harness. Contract:
    1. Runs each smoke in the fixed list below with `MOTOKO_SESSION_ID=phase-a-parity`
       (pins the session id — `derive_session_id`, `agent_loop_v2.ail:279-283`, prefers the
       env var) and the caps its header names.
    2. Normalizes the **single** nondeterministic field:
       `sed 's/"duration_ms":[0-9]*/"duration_ms":0/g'` (empirically the only run-to-run
       diff; `duration_ms` is `now()`-derived in `emit_run_summary`,
       `agent_loop_v2.ail:333-356`).
    3. Writes one `<name>.jsonl` per smoke into the output dir given as `$1`.
    4. Also captures `smoke_v2_compaction_tiers.ail` stdout (not JSONL — a ✓/✗ report) as
       `tiers.txt`. *(Updated 2026-07-03: the smoke was repaired as part of the G3
       disposition — explicit-limit calls via `compact_step_with_limit`, seven cases
       including the corrected tier-3 pair, `exit(1)` on any failure — so it is
       absolute-green and a nonzero exit fails the harness like any other smoke.)*
    5. Exit nonzero if any smoke exits nonzero.
    Smoke list (all `Scripted`/pure — no network, no Ollama/OpenRouter, no registry
    hydration; the core-DST gate class per the ADR's gate separation):
    - `smoke_v2_cost_budget_full_loop.ail` (validated this session: 141 events,
      deterministic after normalization)
    - `smoke_v2_compaction_full_loop.ail` (validated this session: 17 events, deterministic)
    - `smoke_v2_pending_full_loop.ail` (stdin: run with `</dev/null` so the EOF→
      `PolicyDefault` path is exercised deterministically; validate at baseline time)
    - `smoke_v2_dp7_gate.ail` (after `bash scripts/setup_dp7_smoke_workdirs.sh`)
    - `smoke_phase_a_tool_parity.ail` (new, above)
    - `smoke_v2_handle.ail`, `smoke_v2_hybrid.ail` (`--caps IO,Env,Clock` unit smokes —
      green checks, output captured)
    - `smoke_v2_compaction_tiers.ail` (`--caps IO`; absolute-green after the 2026-07-03
      repair, see above)
  - `Makefile` — a **`smoke_parity`** target (G6 disposition; the ADR's Phase A gate now
    cites it by name): runs the harness into a fresh dir and, when `PARITY_BASELINE=<dir>`
    is set, `diff -r`s against it; without a baseline it runs the suite twice and
    self-diffs (the determinism check). Canonical CI-runnable name for the gate.
- **Procedure:** commit the two new scripts; then
  `./scripts/phase_a_event_parity.sh /tmp/phase_a_baseline` **twice** and diff the two
  output dirs against each other. Any smoke that self-diffs nonempty is either fixed (pin
  its remaining nondeterminism) or dropped from the list *at baseline time, before any
  production edit* — the committed harness defines the gate's scope. The surviving baseline
  dir is the reference for WI-1/WI-3/WI-4. Re-capture the baseline after any upstream
  commit lands under `src/core/` mid-implementation.
- **Coverage note (honest limits, recorded):** the moved-function paths covered end-to-end
  are `step_result_to_message` (every scripted step), `tool_result_message` (new tool-parity
  smoke), `msgs_to_messages` (every entry). **Not** deterministically reachable today:
  `envelope_to_tool_message` (`:1297` needs an extension returning `ContinueWithFeedback`)
  and the three `Handled` literals (`:823/:886/:909` need extension `Handled` decisions) —
  no scripted extension fixture exists, and building one is more machinery than Phase A
  warrants. For those, equivalence is pinned by **golden-value inline pure tests** in
  `phase_vocab.ail` (WI-3) asserting exact output records for fixed inputs. This limit is
  gap G7 for the ADR's attention.
- **Verification:** harness runs green twice at HEAD; self-diff of the two runs is empty;
  `ailang check scripts/smoke_phase_a_tool_parity.ail` clean.
- **Rollback:** delete the two scripts. Nothing depends on them.

### WI-1 — Name the compaction constants (`src/core/compaction.ail` only)

The ADR's "export the tier constants as named exports replacing inline literals", re-grounded
on the file as it is at HEAD. AILANG has no module-level constant bindings, so constants are
zero-arg `export pure func`s (house precedent: `schema_version()`; note the sketch's
`empty_delta()`); the ADR's conceptual `UPPER_SNAKE` names map to house-style lower_snake:

| Export (new) | Value | Replaces literal at |
|---|---|---|
| `elide_tier_pct()` | 70 | `compaction.ail:138` |
| `elide_hard_tier_pct()` | 85 | `:137` |
| `emergency_pct()` | 95 | `:136`, and the emergency re-checks `:113`, `:118` |
| `elide_keep_last()` | 10 | `:138` |
| `elide_hard_keep_last()` | 5 | `:137` |
| `emergency_keep_last()` | 3 | `:111` (survey addition — same ladder, same inline-literal class; the ADR names only 70/85/95 + 10/5, so this is flagged, not silent) |
| `emergency_final_keep_last()` | 1 | `:116` (survey addition, ditto) |

Not touched: `elide_content`'s 80-char preview (`:66-68`) — presentation detail, not tier
policy; the header comment block `:9-14` is updated to reference the named exports.
**Already done** (verified, nothing to do): `estimate_tokens_messages` (`:34`),
`usage_percent_with_limit` (`:42`), `usage_percent` (`:47`) are `export pure func`; the ADR's
"the export work is partly done" is confirmed — with the naming imprecision recorded as gap
G2 (`estimate_tokens` is a *different function* in `context_usage.ail:12`, `[Msg]`-typed).

Under D9 these seven constants relocate with the ladder into
`motoko_ext_compaction_structural` in Phase B; Phase A just names them where they live.

- **Files touched:** `src/core/compaction.ail`.
- **Verification:** `ailang check src/core/compaction.ail`;
  `ailang test src/core/compaction.ail` (6 pass / 1 skip at HEAD — same after);
  `ailang verify src/core/compaction.ail` (the `elide_old_tool_results` `requires` contract
  still verifies); `make check_core`; harness vs. baseline: **byte-identical**, including
  `tiers.txt`.
- **Rollback:** revert the single file.

### WI-2 — Create `src/core/phase_vocab.ail` (unused pure vocabulary)

Seed from `sketch/sketch_vocabulary.ail` (all sketch artifacts re-run green this session).
What lands vs. what does not — the Phase A inclusion rule is *types and their ops may land
unused; nothing is wired into production*:

**Lands (from the sketch, adapted):**
- Sealed `History` (+ `history_from_seed` with the head-prefix gate, `history_append`,
  `history_len`, `history_digest` — digest kept as the sketch's **labeled placeholder**;
  the content-hash + previous-digest chain is normative ADR mechanics due before any digest
  is consumed, i.e. Phase B/C), `system_is_head_prefix`, `take_system_prefix`.
- Sealed `CompactableSegment`, `ProviderPayload` + `payload_messages`; exported wrappers
  `ModelRequest`.
- `TokenTelemetry` (forward design, per sketch note), `CompactionPolicy` — its doc comment
  now cites WI-1's named exports as the source of the 70/85/95 + 10/5 values.
- `project()` — **labeled scaffold**: sketch body (pin + passthrough + one event), header
  stating "body replaced by the real pin→chain→tiers pipeline in Phase B; not called from
  production". Landing it keeps the sealed-type discipline whole: `project` is the only
  producer of `ProviderPayload`, so the "no other way to obtain one" property is real (and
  probed) from day one.
- `CheckpointPlan`, `checkpoint` (system-prefix-preserving, per the P3-R1 fix), `LoopTotals`,
  `StepPolicy`, `StepState`, `StateDelta`, `empty_delta`, `apply_state_delta`,
  `apply_checkpoint` (the atomic pair — shape proven in the sketch).
- `ExecutorKind`, `ToolPlanEntry`, `ToolPlan`, `ApprovalRequest` (with `default_allow` /
  `stream_id` / `remaining`, per the P1-R5/P2-R5 fix), `FinalizeInfo`, `FailInfo`,
  `StepDecision` (incl. `TakeCheckpoint` — v1 never emits it), `PhaseResult`.
- `LedgerEvent` + the nine info records + `to_schema_v1`, with the **29-name inventory
  comment block and its regeneration command** copied verbatim (re-verified this session: the
  command reproduces exactly the sketch's 27 `emit_event` names, `diff` clean, plus
  `thinking_delta`/`reasoning_delta` at `agent_loop_v2.ail:255,:265`) and the
  `[prod]`/`[NEW]` classification annotations.
- The sketch's inline pure test (`test_empty_delta_is_identity_shape`) plus new pure tests:
  head-prefix acceptance/rejection of `history_from_seed`, checkpoint length/prefix
  preservation, and a `to_schema_v1` name check for `StreamDelta` covering both delta kinds.

**Does not land:**
- `decide` + `plan_native` — Phase C, and per the co-location adjudication they belong in a
  *separate* `step_machine.ail` (consumers of exported wrappers), so putting them in the
  vocabulary module now would create the wrong home to migrate out of.
- The sketch's demo `main` and `mk_msg`/`decision_name` helpers — sketch-only.

**Substrate rules obeyed** (all re-proven this session; do not re-derive): imports lexically
precede all declarations; no zero-arg anonymous `func()`; anonymous `func` never directly in a
record literal (let-bind); match-arm RHS starting with a record literal gets let-bound; sealed
types are unexported single-constructor **variants** (exported records are structurally
forgeable — `probe_rec_structural` re-run green).

- **Files touched (new):** `src/core/phase_vocab.ail`;
  `scripts/probe_phase_vocab_sealed.ail` — a probe importing `MkHistory`/`MkPayload` from the
  *real* module, which **must fail `IMP010`** (mirrors `probe_sealed_forge.ail`, re-run green
  this session). It lives under `scripts/`, **not** `src/core/`, because `make check_core`
  globs `src/core/*.ail` and a deliberately-failing file there would break the target.
- **Verification:** `ailang check src/core/phase_vocab.ail`;
  `ailang test src/core/phase_vocab.ail` (inline tests pass);
  `ailang check scripts/probe_phase_vocab_sealed.ail` **exits nonzero with `IMP010`** (the
  harness asserts the inversion); `make check_core` (auto-includes the new file);
  `make verify_core` (no contracts in the new file → "without contracts", not a failure);
  harness vs. baseline byte-identical (nothing imports the module yet).
- **Rollback:** delete both files — nothing imports `phase_vocab` until WI-3.

### WI-3 — Transcript builder extraction (the only production-file edit)

Split into two commits for independent revert:

**WI-3a — mechanical move.** Move the six functions (+ `cap_tool_message_content`'s two
inline tests, + their doc comments) from `agent_loop_v2.ail` into `phase_vocab.ail`, marked
`export` (same purity qualifiers as today); add
`import src/core/phase_vocab (msgs_to_messages, step_result_to_message,
cap_tool_message_content, tool_result_message, envelope_to_tool_message)` to
`agent_loop_v2.ail`'s import block (`result_env_model_content` needs importing only until
WI-3b, when its last three direct uses become `handled_tool_message` calls). `phase_vocab`
gains imports `src/core/tool_contract (ToolResultEnvelope, result_to_model_json)` and the
std imports the bodies need (`StepResult` via std/ai; `encode` via std/json; `Str.length`,
`substring` via std/string). No import cycle: `tool_contract` does not import
`agent_loop_v2`; `phase_vocab` imports only std + `tool_contract`.

Call sites updated (none change shape — the names simply resolve via the import):
`:1249` (`step_result_to_message`), `:856`/`:961` (`tool_result_message`), `:1297`
(`envelope_to_tool_message`), `:1160`/`:1510`/`:1676` (`msgs_to_messages`), `:824`/`:888`/
`:911` (`result_env_model_content`, until WI-3b).

Golden-value inline pure tests added in `phase_vocab.ail` pinning exact outputs for fixed
inputs of each moved function — this is the equivalence evidence for the two paths the
harness cannot drive end-to-end (`envelope_to_tool_message`, the `Handled` literals; WI-0
coverage note / gap G7).

Expected side effect, asserted not forgotten: `ailang test src/core/agent_loop_v2.ail` drops
19 → 17 (the two cap tests move); `ailang test src/core/phase_vocab.ail` gains them.

**WI-3b — consolidate the three `Handled` literals.** Add
`export func handled_tool_message(call_id: string, env: ToolResultEnvelope) -> Message` to
`phase_vocab.ail` (body = the shared literal; doc = the model-id-vs-envelope-id comment from
`:905-908`); replace the literals at `:823-828`, `:886-891`, `:909-914` with calls; drop the
now-unneeded `result_env_model_content` import from `agent_loop_v2.ail`. Golden-value test
pins the output record.

- **Files touched:** `src/core/agent_loop_v2.ail`, `src/core/phase_vocab.ail`.
- **Verification (after each of 3a and 3b):** `ailang check` both files;
  `ailang test` both files (17 + moved tests all green); `make check_core`; `make test_core`;
  `make test_integration`; **harness vs. baseline: byte-identical** (this is the step the
  harness exists for); `ailang check scripts/probe_phase_vocab_sealed.ail` still fails
  `IMP010`.
- **Rollback:** revert WI-3b alone (restores the three literals) or WI-3a+b together
  (restores the functions into `agent_loop_v2.ail`; `phase_vocab.ail` reverts to its WI-2
  state). Two-file blast radius; no consumer outside `agent_loop_v2.ail` exists (survey).

### WI-4 — Gate checklist (final; all must pass on the finished branch)

The ADR Phase A gate, expanded to commands. Core-DST gate class: no network, no registry
hydration beyond what `check_core`'s existing `verify_extensions` dependency already does.

```
ailang --version                                   # must be v0.26.0 / 3b52a24 (else STOP: re-validate substrate)
make check_core                                    # all src/core/*.ail type-check (incl. phase_vocab.ail)
make test_core
make test_integration
ailang test src/core/compaction.ail                # 6 pass / 1 skip (unchanged)
ailang test src/core/agent_loop_v2.ail             # 17 pass (19 - 2 moved)
ailang test src/core/phase_vocab.ail               # sketch-seeded + golden-value tests pass
ailang verify src/core/compaction.ail              # contract still proves
make verify_core                                   # no regressions
ailang check scripts/probe_phase_vocab_sealed.ail  # MUST FAIL with IMP010 (sealing holds)
bash scripts/setup_dp7_smoke_workdirs.sh
./scripts/phase_a_event_parity.sh /tmp/phase_a_after
diff -r /tmp/phase_a_baseline /tmp/phase_a_after   # MUST be empty — the no-event-stream-diff gate
```

Plus the negative checks: `grep -n "phase_vocab" src/core/*.ail` shows imports **only** in
`agent_loop_v2.ail`; `grep -c emit_event src/core/phase_vocab.ail` = 0 (no emission wired);
no diff under `src/tui/`, `packages/`, `src/core/ext/`.

---

## ADR gaps found

Per the handoff: discrepancies between the committed documents and HEAD, discovered while
producing this plan. Candidates for the ADR's Review Comments / next disposition pass; none
blocks Phase A (each has a plan-level resolution above).

> **Addendum (2026-07-03, same day):** all seven gaps were dispositioned with operator
> sign-off — see the ADR's **Plan-Authoring Findings & Dispositions** log. Doc fixes were
> applied to the ADR (G1/G2/G4/G5/G6 wording; Open Question 1 closed), the research doc
> (§7.1 case 7, §7.5, new §11 fact 19), and DST ADR-001 (dated amendment notes on R5, R15,
> and its tier-facts line). The tiers smoke (G3b) was repaired: explicit-limit calls,
> `exit(1)` on failure — and the repair exposed that the old tier-3 expectation (Err at 97%
> tool-heavy load) was itself wrong: emergency elision recovers tool-heavy overload;
> exhaustion requires non-tool content, so tier 3 is now an emergency-recovers /
> exhausted-errs pair (7 cases, all ✓, rc=0; failure path verified rc=1). G3c (wrapper
> retirement) and G7 (minimal in-repo test extension) are now named Phase B deliverables in
> the ADR. The G-entries below are preserved **as found**, for the record.

- **G1 — `transcript.ail` does not exist at HEAD.** The ADR calls the vocabulary module
  "`transcript.ail`'s successor" (Decision detail 4) and Open Question 1 offers "expanding
  `transcript.ail`" as an option; research §7.1 case 7 says normalization lives "inside
  `transcript.ail`'s projection". There is no such file (`ls src/core/transcript.ail` fails);
  the transcript helpers live in `agent_loop_v2.ail:361-501`. OQ1's second option is
  unimplementable as written. Resolved here by keeping the working name (`phase_vocab.ail`).
- **G2 — measurement-primitive naming imprecision.** ADR Phase A and D9 say
  "`estimate_tokens`, `usage_percent` — already `export pure func` in `compaction.ail`".
  Actual HEAD: `compaction.ail` exports `estimate_tokens_messages` (`:34`), `usage_percent`
  (`:47`), `usage_percent_with_limit` (`:42`); **`estimate_tokens` is a different function**
  (`[Msg]`-typed, `context_usage.ail:12`, also exported). Matters for Phase B: the "shared
  measurement surface compactors build on" must name the right symbols.
- **G3 — the model-name-keyed pure compaction path is dead at HEAD** (load-bearing find).
  `context_limit_for` returns **0 for every model** (`context_usage.ail:27-40` — the ensures
  block's test table expects 0 even for known names; body is `0`); production gets its limit
  from effectful `catalog_context_limit_for` (`Env, FS`; `context_usage.ail:68`) at
  `agent_loop_v2.ail:1149` and passes it to `compact_step_with_limit` (`:1171`).
  Consequences: (a) `compact_step`/`usage_percent`/`try_emergency_compaction` (the
  model-name variants) can never trigger compaction — vestigial surface; (b)
  `scripts/smoke_v2_compaction_tiers.ail` is **red at HEAD by its own pass criterion** (3 of
  6 cases print ✗, exit code still 0) because it calls `compact_step(msgs,
  "anthropic/claude-sonnet-4-6")` → limit 0 → permanent PassThrough. The ADR/research call
  structural compaction "fully pure — L0-ready" (§11 fact 7) without noting the pure
  entry points are limit-parameterized only. Phase B's ladder relocation and the D9
  "measurement primitives" story should be written against the `_with_limit` variants.
- **G4 — the no-diff gate's nondeterminism is unspecified.** The ADR gate says "no
  event-stream diff" but the stream contains `duration_ms` (wall-clock) and a
  `now()`-derived session id fallback. Resolvable exactly (this plan: pin
  `MOTOKO_SESSION_ID`, normalize `duration_ms` — empirically the complete set at HEAD), but
  the ADR should say byte-compatibility is *modulo declared volatile fields*, or Phase B's
  "byte-compatible subset" gate inherits the same ambiguity.
- **G5 — the constants list is incomplete against source.** The ladder's inline literals
  include the emergency keep-lasts **3/1** (`compaction.ail:111,:116`) and two additional
  `95` occurrences (`:113,:118`) beyond the `:136-138` tier table the ADR cites. Phase A
  names them too (WI-1) — flagged since the ADR enumerates only 70/85/95 + 10/5.
- **G6 — "existing smokes" has no canonical runner.** No Make/CI target executes
  `scripts/smoke_v2_*.ail` (the Makefile's only smoke target is the config-lint
  `smoke_no_delegated_storm`); several smokes require a live model (`smoke_v2_intercept.ail`
  header: `--ai openrouter/...`), and one is red at HEAD (G3b). "Existing smokes green" is
  therefore not currently executable as an absolute gate; this plan operationalizes it as
  the WI-0 harness (deterministic subset, baseline-relative). The ADR may want to adopt the
  harness as the named gate artifact.
- **G7 — two extracted paths are not end-to-end coverable without extension fixtures.**
  `envelope_to_tool_message` (`:1297`, needs `ContinueWithFeedback`) and the `Handled`
  literals (`:823/:886/:909`, need a `Handled` tool decision) have no scripted extension
  fixture; the registry packages are external and hydration is out of the core gate class.
  Phase A pins them with golden-value pure tests instead. If the ADR wants e2e parity
  coverage for extension-path message construction before Phase B rewires emission, a
  minimal in-repo test extension is a missing (small) deliverable.

---

## Anchor re-verification log (v0.26.0 / `3b52a24`, HEAD `8227053`, 2026-07-03)

Artifacts re-run this session, as the handoff mandates:

| Artifact | Command | Result |
|---|---|---|
| `sketch_vocabulary.ail` | `ailang check` / `run --caps IO --entry main` / `test` | ✓ / ✓ (demo: `d0=CallModel d1=RunTools(1) d2=Finalize(model_stop)`, `len=2 (system prefix retained)`, `reasoning_delta` line) / ✓ 1 pass |
| `probe_opacity_forge.ail` | `ailang check` | ✓ passes (export type exports ctors) |
| `probe_sealed_forge.ail` | `ailang check` | ✗ `IMP010: 'MkSealed' not exported` (as required) |
| `probe_sealed_name.ail` | `run --caps IO` | ✗ `IMP010: 'Sealed' not exported` (as required) |
| `probe_sealed_thread.ail` / `probe_opacity_legal.ail` / `probe_rec_structural.ail` | `run --caps IO` | ✓ run (thread / legal-op / record-forgeable, as documented) |
| `probe_consumer_decide.ail` (+ `vocab_probe.ail` lib) | `run --caps IO` | ✓ `decide=CallModelP payload=20 hist=3` (wrapper adjudication holds) |
| `scripts/smoke_ports_record.ail` | `check`; `run --caps IO --entry main`; `run --caps IO --entry main_live` | ✓; ✓ fake path under IO alone; `main_live` fails `effect 'Clock' requires capability` (caps at performance time) |
| Event inventory | sketch's regeneration grep | 27 names, `diff` vs sketch list clean; + `thinking_delta`/`reasoning_delta` at `:255`/`:265` = **29** |
| Emission counts | `grep -c` | 39 `emit_event`, 7 `emit_run_summary`, 2 `emit_stream_chunk`, 4 `emit_json` (ADR's 48 confirmed) |
| No-diff feasibility | 2× pinned-session runs of `smoke_v2_cost_budget_full_loop` (raw) and `smoke_v2_compaction_full_loop` (normalized) | only `duration_ms` differs raw; byte-identical after normalization |
| Tiers smoke baseline | `run --caps IO smoke_v2_compaction_tiers.ail` | 3 ✗ / 3 ✓, exit 0 (gap G3) |

Source anchors re-read at HEAD (all cited lines above were read, not inherited): the
transcript builders and their call sites (`agent_loop_v2.ail:361-501`, `:823-828`,
`:856`, `:886-891`, `:909-914`, `:961`, `:1249`, `:1297`, `:1160`, `:1510`, `:1676`);
`messages_to_msgs` `:541-551` (uses `:530`, `:1154`); ten-effect row `:1125`;
`dispatch_pre_step` forward `:1154`; `compact_step_with_limit` call `:1171` with
`catalog_context_limit_for` at `:1149`; `emit_event` def `:203`, `emit_json` def `:105`,
stream types `:255`/`:265`, `derive_session_id` `:279-283`, `duration_ms` `:333-356`;
`run_v2_with_stub` `:1692`; compaction ladder `compaction.ail:134-140`, emergency literals
`:111-118`, exports `:34/:42/:47/:101/:134/:142`; `context_limit_for`
`context_usage.ail:27-40`, `estimate_tokens` `:12`, `catalog_context_limit_for` `:68`;
`result_to_model_json` `tool_contract.ail:60`; `StepProvider`/`Scripted`
`stub_step.ail:42`, fixtures `:142-196`; Make targets `Makefile:48/126/133/144`
(`check_core` globs `src/core/*.ail`; no smoke-suite target — G6); `src/core/ailang.toml`
`[exports]` list (no `phase_vocab` needed in Phase A). Line numbers are exact as of this
read; **re-grep before editing**.
