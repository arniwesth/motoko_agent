# ADR-002 implementation plan: the single send-gate + DST scenarios for system-prompt and overflow

Date: 2026-07-05
Implements: `ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` (this project)
Branch: `arniwesth/mot-27-phased-core-architecture`
Toolchain pin: AILANG **v0.26.0** (commit `3b52a24`) — verified this session (`ailang --version`).
Grounding HEAD: **`b76dd3e`** ("Updated stale comment"), i.e. **one commit past** ADR-002's
authoring HEAD `64262d1`. That intervening commit rewrote the `session.ail` file-header comment
block and shifted all `session.ail` code anchors **up by 9 lines** — every session line number in
ADR-002's blast-radius table is stale by −9 at this HEAD. This plan carries the re-verified numbers;
see the Anchor Re-Verification Log.

---

## Goal

Land the ADR-002 core send-gate at the one function every model call passes through,
`seal_compacted_payload` (`src/core/phase_vocab.ail:131`), and its two Layer-1 DST scenarios:

1. A typed `SealError = SealExhausted(string) | SealSystemPromptEmpty(string)` so an empty system
   prompt (#76) surfaces as a distinct `SystemPromptEmpty` failure rather than being mislabeled
   `ContextExhausted`.
2. An exported pure `system_prefix_chars` helper and a `system_prefix_chars: int` field on
   `ProviderCallInfo`, so a *present-but-empty* system message is observable on every proceeding
   call.
3. A `require_system_prompt: bool` `StepPolicy` field (default set once at session init), threaded
   to `seal`, so the refusal is policy-gated and headless sessions stay expressible.
4. Session branch: `SealSystemPromptEmpty` → `error` event (`source:"system_prompt"`,
   `code:"SystemPromptEmpty"`, result `Err` coded `SystemPromptEmpty`, `retryable:false`);
   `SealExhausted` → the existing `CompactionExhausted`/`ContextExhausted` path unchanged.
5. Two scenarios in `scripts/phase_c_l1_scenarios.ail`: `empty_system_prompt_rejected` (new teeth
   for #76, fail-then-pass) and `oversized_payload_rejected` (#75.2 regression guard, expected
   green).

Each work item leaves the tree `ailang check`-green and shippable (strangler discipline).

## Out of scope (owned elsewhere — do not touch here)

- **Host-side env-manifest work** (`NOTE-env-manifest-single-source-and-drift-guard.md`): the
  `runtime-process.ts` allowlist / `CORE_MAP` unification. Separate WI. ADR-002 §5.
- **`project` cleanup** (reducing it to a bare decision now its payload/events are discarded). We
  add `system_prefix_chars:` to its `ProviderCallPrepared` stub (`phase_vocab.ail:168`) *only to
  keep it compiling*; we do not fix its logic. ADR-002 §5 / D4.
- **#75.1** (chars/4 over-count → thrash) and **#75.3** (dead cloud summarizer): compaction
  *policy*, extension-resident under ADR-001 D9, conformance-kit DST. ADR-002 §5.
- **The ABI / compactor-extension conformance track** (#75.1/#75.3, ADR-001 D9).
- Any change to ADR-002, the NOTE, or a prior plan/ADR/research doc. This plan is a new file only.

## TL;DR

The whole ADR hinges on one structural fact, re-verified at HEAD `b76dd3e`: the live loop has
**exactly one** `seal_compacted_payload` call (`session.ail:1393`) and **exactly one** provider
`dispatch_step` (`session.ail:1415`), and the dispatch sits inside the seal's `Ok` branch — so no
model call bypasses the gate (`grep` for both symbols across `session.ail` returns only the import
line and that single call site each; confirmed this session). The overflow (#75.2) is therefore
already structurally prevented, which is exactly why `oversized_payload_rejected` is a *regression
guard*, not a fix.

The change is four additive-then-atomic steps:
- **WI-1** — observability field: `system_prefix_chars` helper + `ProviderCallInfo` field
  (additive; no gate behavior change). `phase_vocab` + `session`.
- **WI-2** — policy field: `StepPolicy += require_system_prompt` at all **7** literal sites
  (additive; dormant until WI-3). `phase_vocab` + `session` + `step_machine` + scenarios.
- **WI-3** — the atomic behavior change: `SealError` type, `seal` signature/body
  (empty-check-before-exhaustion), thread `require_system_prompt`, split the session `Err` arm,
  update the 3 seal unit tests + add 1. `phase_vocab` + `session`.
- **WI-4** — the two L1 scenarios + registration.
- **WI-5** — the ADR-002 acceptance-criteria gate.

I deliberately reordered relative to the handoff's suggested cut (which put the `seal`
signature change in its WI-1). Because AILANG has **no default arguments** and closed record
literals, changing `seal`'s arity/return type is a hard break that its one caller in `session.ail`
must absorb *in the same commit* — so the signature change and the session branch are one atomic
WI (WI-3), while the two genuinely-additive surfaces (the observability field, the policy field)
land first and independently. This is exactly the "sequence it however keeps each step compiling"
licence the handoff grants; the four deliverables are unchanged.

---

## Grounding: ADR-002 as written vs HEAD `b76dd3e`

**Re-verified structural facts (the ADR's load-bearing claims, checked this session):**

- **Single unconditional send-gate.** `session.ail:1382` `CallModel(_) => { … }` runs
  `split_for_compaction (:1385) → dispatch_pre_step_chain (:1390) → seal_compacted_payload (:1393)`
  for every model step. `seal` gates on the actual constructed payload
  `usage_percent_with_limit(split.pinned ++ chain_msgs, limit) >= exhaustion_pct()`
  (`phase_vocab.ail:133-135`). `grep -n 'seal_compacted_payload' src/core/session.ail` → import
  `:109`, call `:1393` (only). `grep -n 'dispatch_step' src/core/session.ail` → import `:118`,
  call `:1415` (only), inside the `Ok` branch (`:1401`). **The single-gate invariant holds at
  HEAD. No second dispatch, no second seal.** (ADR finding 1 confirmed; no ADR gap.)
- **`provider_call_prepared` is emitted only on the `Ok` branch** (`session.ail:1407-1414`,
  inside the `Ok(payload) =>` arm opened at `:1401`). The empty-prompt reject path has no
  prepared-event; its observability is the `error` event (ADR D5 — do **not** plan a `chars:0`
  prepared-event on the reject path).
- **`project` is vestigial.** `session.ail:1382` matches `CallModel(_)` and discards the payload;
  `step_machine.ail:74` returns `CallModel({ payload: projection.payload, … })` but
  `call_model_or_fail` discards `projection.events`. Its `system_prefix_count: 0` stub lives at
  `phase_vocab.ail:168`. We only compile-fix it (WI-1).
- **`MkSegment` is NOT exported** (`phase_vocab.ail:107`, `type CompactableSegment =
  MkSegment([Message])` — no `export`). Scenarios must build splits via the exported
  `split_for_compaction` (`:123`). Confirmed.

**Anchor drift (ADR-002 blast-radius table → HEAD).** `phase_vocab.ail`, `step_machine.ail`, and
`scripts/phase_c_l1_scenarios.ail` were **not** touched since authoring; their anchors are exact.
`session.ail` anchors are all **−9** (the header comment block went 34→25 lines in `b76dd3e`):

| ADR-002 says | HEAD `b76dd3e` | What |
|---|---|---|
| `session.ail:118` (seal import) | `:109` | `seal_compacted_payload,` in import block |
| `session.ail:722` (count) | `:713` | `func count_system_prefix` |
| `session.ail:968` (origin) | `:959` | origin `StepPolicy` literal (`step:` block in `session_policy_init`) |
| `session.ail:989` (derived) | `:980` | derived `StepPolicy` in `session_policy_with_model` |
| `session.ail:1391` (handler) | `:1382` | `CallModel(_) =>` |
| `session.ail:1402` (seal call) | `:1393` | `match seal_compacted_payload(...)` |
| `session.ail:1403` (Err map) | `:1394-1399` | `Err(...) => CompactionExhausted … ContextExhausted` |
| `session.ail:1410/1416` (Ok/emit) | `:1401 / :1407` | `Ok(payload) =>` / `ProviderCallPrepared({…})` |
| `session.ail:1424` (dispatch) | `:1415` | `dispatch_step(...)` |
| `session.ail:1685` (derived) | `:1676` | third `StepPolicy` literal (`run_v2_from_messages_traced`) |

Non-session anchors that held exactly: `phase_vocab.ail` `seal:131`, `take_system_prefix:80`,
`split_for_compaction:123`, `StepPolicy:310`, `ProviderCallInfo:438`, wire projection `:611`,
`project` stub `:168`, seal unit tests `:857/:874/:884`, ledger test
(`test_ledger_trace_records_wire_and_stage_passed`) `:839`, golden test `:1023`;
`step_machine.ail` `mk_policy:109` + inline literals `:209/:221`; scenarios `policy():98`, main
list `:371`.

## Plan-level decisions (implementation choices ADR-002 leaves open; none re-litigate D1–D5)

- **D-P1 — `require_system_prompt` origin default is `!headless`, not a hardcoded `true`.**
  `session_policy_init` (`session.ail:952`) already reads `MOTOKO_HEADLESS` into a local `headless`
  (`:957`) and stores `headless: headless` on `SessionPolicy` (`:974`). ADR-002 §3/D1 say the flag
  is "set once at session init (default `true`)" *and* that its purpose is to "preserve reuse of
  `seal` for headless invocations" per ADR-001's "config/env → `StepPolicy` at init." A literal
  `true` makes the seam unreachable at runtime (headless callers could never opt out without a code
  edit), contradicting that rationale; wiring it to the existing flag as
  `require_system_prompt: !headless` honors both "default `true` for a normal session" and the
  headless opt-out. **Recommended: `!headless`.** This is flagged in *ADR Gaps Found* for operator
  confirmation; if the operator prefers the literal `true`, change one token at the origin site —
  everything else in the plan is unaffected (the two derived sites inherit; the scenario/test
  literals set the value explicitly).
- **D-P2 — new `seal` parameter is appended last:**
  `seal_compacted_payload(split, chain_msgs, model, limit, require_system_prompt: bool)`. Minimizes
  churn at the call site and in the three unit tests.
- **D-P3 — empty-prompt check runs before exhaustion**, inside `seal` (ADR-002 §1: "a wiring error
  should trump 'also too big'"). Only when `require_system_prompt` is true.
- **D-P4 — the emit-site `system_prefix_chars` reads `compacted_msgs`**, mirroring the sibling
  `system_prefix_count: count_system_prefix(compacted_msgs)` at `session.ail:1410`. This equals
  `system_prefix_chars(split.pinned)` because `seal` re-pins `split.pinned ++ chain_msgs` and
  `chain_msgs` is the non-system tail — the head system run is identical. Use `compacted_msgs` for
  line-local consistency.
- **D-P5 — JSON field order:** insert `kv("system_prefix_chars", jnum(...))` **immediately after**
  `system_prefix_count` in the wire projection (`phase_vocab.ail:611`); the golden string
  (`:1023`) and the ledger-test literal (`:839`) update in lockstep with the same position.
- **D-P6 — `emit_run_summary` finish_code on the reject path:** the `CompactionExhausted` arm
  passes `3` (`session.ail:1397`), stream-error passes `5` (`:1443`). The `SystemPromptEmpty` arm
  emits a run-summary for parity with the exhaustion arm; reuse the error-class code (**recommend
  `5`**, "errored"). This int only labels the `run_summary.finish_reason`; DST asserts on the
  `error` event's `code`, never on this. Confirm against the TUI's finish_reason mapping when
  implementing; it is a labeling detail, not a gate.

---

## Work breakdown

Baseline established this session (all green at HEAD `b76dd3e`): `ailang check` on
`phase_vocab.ail` and `session.ail` clean; `ailang test src/core/phase_vocab.ail` **25/25**;
`ailang test src/core/step_machine.ail` **16/16**; `ailang run --caps IO --entry main
scripts/phase_c_l1_scenarios.ail` **10/10 PASS**.

### WI-1 — `system_prefix_chars` helper + `ProviderCallInfo.system_prefix_chars` (observability)

**Purpose.** Add the missing observable (chars, not just count) on every proceeding call. Purely
additive; no gate behavior changes. Leaves the tree green.

**File-level changes.**
- `src/core/phase_vocab.ail`: add, next to `take_system_prefix` (`:80`), an exported pure helper
  ```
  export pure func system_prefix_chars(msgs: [Message]) -> int {
    match msgs {
      [] => 0,
      m :: rest => if m.role == "system" then String.length(m.content) + system_prefix_chars(rest) else 0
    }
  }
  ```
  (mirror `count_system_prefix`'s recursion; confirm the in-repo length primitive — `String.length`
  vs a local `strlen` — against how `phase_vocab.ail` already measures `content`, e.g. the
  `estimate_tokens_messages`/`payload_digest` neighbourhood; match the existing idiom).
- `src/core/phase_vocab.ail:438`: `ProviderCallInfo` gains `system_prefix_chars: int` (append after
  `system_prefix_count`).
- `src/core/phase_vocab.ail:611`: wire projection — insert
  `kv("system_prefix_chars", jnum(_int_to_float(i.system_prefix_chars)))` after the
  `system_prefix_count` kv (per D-P5).
- `src/core/phase_vocab.ail:168`: `project` stub `ProviderCallPrepared({...})` — add
  `system_prefix_chars: 0` (compile-fix only; do not touch `project` logic — out of scope).
- `src/core/phase_vocab.ail:839`: ledger test `test_ledger_trace_records_wire_and_stage_passed`
  literal — add `system_prefix_chars: <n>` to the `ProviderCallPrepared({...})`.
- `src/core/phase_vocab.ail:1023`: golden test — add `system_prefix_chars: <n>` to the literal
  **and** insert `,"system_prefix_chars":<n>` into the expected JSON string after
  `"system_prefix_count":1` (byte-exact; this is the criterion-4 lockstep).
- `src/core/session.ail:1407`: the live `ProviderCallPrepared({...})` emit — add
  `system_prefix_chars: system_prefix_chars(compacted_msgs)` (per D-P4). Add `system_prefix_chars`
  to session's `phase_vocab` import block (near `:109`).

**Verification.**
```
ailang check src/core/phase_vocab.ail
ailang check src/core/session.ail
ailang test src/core/phase_vocab.ail          # 25/25 still; golden + ledger updated in place
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # 10/10 PASS
```
Confirm the golden diff is exactly the one new field on `provider_call_prepared` and nothing else
(`provider_call_prepared` is `[NEW]` per ADR-001 §3, so the additive field is admitted; a one-line
sanity check against the TUI parser's unknown-field tolerance is the gate — see WI-5).

**Rollback.** Revert `phase_vocab.ail` and the `session.ail` emit-line/import; re-run
`ailang test src/core/phase_vocab.ail` to prove 25/25 restored.

### WI-2 — `StepPolicy += require_system_prompt: bool` at all 7 literal sites

**Purpose.** Add the policy seam. Purely additive and dormant (nothing reads it until WI-3), so the
whole tree stays green. AILANG's closed record literals make this compiler-enforced-complete: a
missed site is a compile break, which is the point.

**File-level changes (the complete site list, re-verified at HEAD — `grep -n 'step_budget:'`
plus type def):**
- `src/core/phase_vocab.ail:310`: `StepPolicy` type — add `require_system_prompt: bool`.
- `src/core/session.ail:959` (**origin**, `session_policy_init` `step:` block): add
  `require_system_prompt: !headless` (per D-P1; `headless` is already in scope at `:957`).
- `src/core/session.ail:980` (derived, `session_policy_with_model`): **inherit** —
  `require_system_prompt: policy.step.require_system_prompt` (do not re-default).
- `src/core/session.ail:1676` (derived, policy literal in `run_v2_session_traced_with_persist_retries`,
  `:1658`, built from `base = session_policy_init(...)`): **inherit** —
  `require_system_prompt: base.step.require_system_prompt`.
- `src/core/step_machine.ail:109` (`mk_policy`): add `require_system_prompt: true` (test policy
  factory — true keeps the default posture; no existing `step_machine` test exercises the empty
  prefix, so true is inert here).
- `src/core/step_machine.ail:209` and `:221` (inline `StepPolicy` literals in tests): add
  `require_system_prompt: true`.
- `scripts/phase_c_l1_scenarios.ail:98` (`policy()` helper): add `require_system_prompt: true`.

**Verification.**
```
ailang check src/core/phase_vocab.ail
ailang check src/core/session.ail
ailang check src/core/step_machine.ail
ailang test src/core/step_machine.ail          # 16/16 (field dormant)
ailang test src/core/phase_vocab.ail           # 25/25
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # 10/10 PASS
```
If any file fails to check, a `StepPolicy` construction site was missed — the compiler names it;
add the field and re-run. That is the intended safety net.

**Rollback.** Remove the field from the type and all 7 sites; re-run the four checks above.

### WI-3 — `SealError`, `seal` signature/body, threading, session branch, seal tests (atomic)

**Purpose.** The one behavior change. Because `seal`'s return type and arity change, its single
caller (`session.ail:1393`) and its three unit tests must change in the same commit; this WI is
atomic and is where the empty-prompt refusal becomes live.

**File-level changes.**
- `src/core/phase_vocab.ail` (near `seal`, `:131`): add
  ```
  export type SealError = SealExhausted(string) | SealSystemPromptEmpty(string)
  ```
- `src/core/phase_vocab.ail:131-137`: change `seal_compacted_payload` to
  ```
  export pure func seal_compacted_payload(
    split: PinnedSplit, chain_msgs: [Message], model: string, limit: int, require_system_prompt: bool
  ) -> Result[ProviderPayload, SealError] {
    let payload_msgs = split.pinned ++ chain_msgs;
    if require_system_prompt && system_prefix_chars(split.pinned) == 0 then
      Err(SealSystemPromptEmpty("system prompt required but system prefix is 0 chars"))
    else {
      let pct = usage_percent_with_limit(payload_msgs, limit);
      if pct >= exhaustion_pct() then
        Err(SealExhausted("compaction_exhausted: context at ${show(pct)}% of ${model} limit after compactor chain"))
      else Ok(MkPayload(payload_msgs))
    }
  }
  ```
  Empty-check first (D-P3); the `SealExhausted` message is byte-identical to the current string so
  the exhaustion path is unchanged (criterion for the overflow guard and for the existing
  exhaustion unit test's reason string). The `SealSystemPromptEmpty` message reports the 0-char
  prefix (criterion 3).
- `src/core/phase_vocab.ail:857/:874/:884` (the three `seal` unit tests): pass `false` as the new
  `require_system_prompt` arg (keep them exhaustion-only), and change the exhaustion test's match
  from `Err(reason) => reason == "…"` to `Err(SealExhausted(reason)) => reason == "…"`
  (`:879`). The repin/fail-open tests only need the extra `false` arg.
- `src/core/phase_vocab.ail` (new test, alongside the seal tests): add
  `test_seal_compacted_payload_rejects_empty_system_prompt` — `split_for_compaction([mk_msg("user",
  "hi")])` (empty pinned) and separately a `[mk_msg("system",""), mk_msg("user","hi")]`
  (present-but-empty) case; `seal(..., require_system_prompt=true)` ⇒ `Err(SealSystemPromptEmpty(_))`
  for both; and one control asserting `require_system_prompt=false` over the same empty-pinned input
  does **not** return `SealSystemPromptEmpty` (returns `Ok`, given a generous `limit`).
- `src/core/session.ail:109`: add `SealError`, `SealExhausted`, `SealSystemPromptEmpty` to the
  `phase_vocab` import block (`ErrorEvent` is already imported at `:91`).
- `src/core/session.ail:1393`: thread the flag —
  `match seal_compacted_payload(split, msgs_to_messages(chain.msgs), model, context_limit, policy.step.require_system_prompt) {`
  (`policy.step.require_system_prompt` is in scope: `policy: SessionPolicy` with `.step: StepPolicy`,
  already dereferenced as `policy.step.*` at `:1415/:1421`).
- `src/core/session.ail:1394-1399`: split the single `Err` arm into two typed arms, mirroring the
  existing exhaustion arm's shape:
  ```
  Err(SealSystemPromptEmpty(reason)) => {
    let event = ErrorEvent({ source: "system_prompt", code: "SystemPromptEmpty", message: reason });
    let _ = ledger_emit(session_id, event);
    let _ = emit_run_summary(session_id, model, st.totals, step_idx, 5, reason, started_at_ms);   // D-P6
    let result: Result[[Message], AIError] = Err({ code: "SystemPromptEmpty", message: reason, retryable: false });
    { result: result, trace: ledger_append(trace_after_stages, WireRecord(event)) }
  },
  Err(SealExhausted(compaction_reason)) => {
    // …existing CompactionExhausted body unchanged (session.ail:1395-1399)…
  },
  Ok(payload) => { …unchanged… }
  ```
  (`ErrorEvent` projects to the production `error` name at `phase_vocab.ail:639` — no new wire
  type, per the ADR's rejected-alternative. There is already a live `ErrorEvent({...})` emit
  precedent at `session.ail:1852` to mirror for shape/idiom.)

**Verification.**
```
ailang check src/core/phase_vocab.ail
ailang check src/core/session.ail
ailang test src/core/phase_vocab.ail    # 26/26 expected (3 seal tests updated + 1 new)
ailang test src/core/step_machine.ail   # 16/16 (mk_policy passes require_system_prompt=true; inert)
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # 10/10 still (WI-4 adds the 2 new)
```
Substrate note (per `NOTE-ailang-run-exit-code-false-alarm.md`): read each command's own exit
status directly, not through a pipe; do not `tail | grep` and then trust `$?`.

**Rollback.** Revert `phase_vocab.ail` (type, `seal`, tests) and the `session.ail` import + branch;
`seal` returns to `Result[_, string]`. Re-run `ailang test src/core/phase_vocab.ail`. WI-1/WI-2
additive surfaces are independent and can stay.

### WI-4 — the two Layer-1 scenarios

**Purpose.** Turn both bug classes into standing `--caps IO` law. `empty_system_prompt_rejected`
is #76's teeth (fail-then-pass); `oversized_payload_rejected` is #75.2's regression guard
(expected green).

**File-level changes (`scripts/phase_c_l1_scenarios.ail`).**
- Import block (`:14-33`): add `seal_compacted_payload`, `SealSystemPromptEmpty`, `SealExhausted`
  from `src/core/phase_vocab`. (`split_for_compaction`, `payload_messages`, `StepPolicy` already
  imported; `system_prefix_chars` optional — import it only if the scenario asserts the char count
  in its trace.) `SealError` variants are constructors, imported like `CallModel`/`Fail` already
  are.
- Add `scenario_empty_system_prompt_rejected() -> Result[(), ScenarioFailure]`, modelled on
  `scenario_provider_payload_vs_uncompacted_history_pressure` (`:177`):
  - Build `let split = split_for_compaction([msg("user", "hi")]);` (⇒ empty `pinned`) — and/or the
    present-but-empty head `[msg("system",""), msg("user","hi")]`.
  - `match seal_compacted_payload(split, [msg("user","hi")], "phase-c-model", 1000, true) {
    Err(SealSystemPromptEmpty(_)) => ok_or_failure(true, "empty system prompt rejected", […]),
    _ => Err({ failed_invariant: "empty system prompt rejected", trace: […] }) }`.
    Use a generous `limit` (1000) so the reject is unambiguously the empty-prompt arm, not
    exhaustion.
- Add `scenario_oversized_payload_rejected() -> Result[(), ScenarioFailure]`, modelled on the unit
  test `test_seal_compacted_payload_exhausts_with_live_reason` (`phase_vocab.ail:874`):
  - `let split = split_for_compaction([]);` (empty pinned) and a long chain message (inline a
    ~40-char-content `Message`, or add a local `long_msg` helper mirroring the unit test).
  - `seal(split, [long chain], "test-model", 10, false)` — **`require_system_prompt = false`** is
    load-bearing: with empty `pinned`, `true` would fire `SealSystemPromptEmpty` first and mask the
    exhaustion this scenario asserts (D-P3 ordering). Assert `Err(SealExhausted(_))`.
- Add the two `Scenario` builders (alongside `:335-369`):
  `func empty_system_prompt_rejected_scenario() -> Scenario { { id: "empty_system_prompt_rejected", run: scenario_empty_system_prompt_rejected } }` and the `oversized_payload_rejected` twin.
- Register both in `main`'s `scenarios` list (`:372`).

**Verification.**
```
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # expect 12/12 PASS, no network
```
**Teeth check (criterion 1, fail-then-pass).** Prove `empty_system_prompt_rejected` actually
bites: temporarily flip its `seal(..., true)` to `seal(..., false)` and re-run → the scenario must
report **FAIL** (named `empty_system_prompt_rejected`, invariant "empty system prompt rejected"),
because `false` returns `Ok`/`SealExhausted`, not `SealSystemPromptEmpty`. Flip back to `true` →
PASS. Record both outputs as the fail-then-pass evidence. (This toggles the scenario's own arg, not
production code — cleaner than reverting WI-3, and it isolates the refusal arm precisely.)

**Rollback.** Remove the two scenario funcs, the two builders, the two `main` registrations, and the
added imports; re-run the harness for 10/10.

### WI-5 — ADR-002 acceptance-criteria gate (final step)

Run top-to-bottom; every line must hold before this plan is done. Mirrors ADR-002 §"Acceptance
criteria".

```
# 1. Empty-prompt scenario is fail-then-pass and names id + code on failure  (WI-4 teeth check)
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
#    -> with seal(...,false): scenario=empty_system_prompt_rejected FAIL (invariant named)
#    -> with seal(...,true) : scenario=empty_system_prompt_rejected ok

# 2. oversized_payload_rejected green under --caps IO, no network
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # 12/12 PASS

# 3. ailang check green (both core files under change)
ailang check src/core/phase_vocab.ail
ailang check src/core/session.ail
ailang check src/core/step_machine.ail

# 4. existing unit tests green with updated literals + typed match arms
ailang test src/core/phase_vocab.ail     # 26/26 (golden+ledger updated, seal tests typed, +1 new)
ailang test src/core/step_machine.ail    # 16/16

# 5. no scenario depends on effect-handler mocking, real providers, or registry hydration
grep -nE '--caps (AI|Net)|real_ports|live_ports|registry' scripts/phase_c_l1_scenarios.ail || true
#    -> the two new scenarios must appear nowhere in that output
```

Manual gate items (not shell-automatable here):
- **Criterion 3, live loop.** Confirm by inspection that on an empty prompt the live handler
  (`session.ail:1394` new arm) emits an `error` event coded `SystemPromptEmpty` whose message
  reports the 0-char prefix, and emits **no** `provider_call_prepared` on that path; and that a
  proceeding call still emits `provider_call_prepared` carrying `system_prefix_chars`
  (`:1407`). DST/consumers assert on the `code`, never the message text.
- **TUI tolerance (ADR-002 §2, one-line check).** Confirm the TUI event parser tolerates the new
  `provider_call_prepared.system_prefix_chars` field (unknown-field/`[NEW]`-type tolerance,
  ADR-001 §3). Point check against the parser; no production-byte regression beyond the single
  additive field on `provider_call_prepared`.

---

## ADR gaps found

**No blocking ADR gap.** ADR-002 plus the committed source at HEAD `b76dd3e` was sufficient to
produce this plan without guessing. The single-gate invariant the whole ADR rests on
(one `seal`, one `dispatch_step`, dispatch inside seal's `Ok`) still holds at this HEAD.

Non-blocking notes for the implementer / operator:

- **`require_system_prompt` origin default — interpretation, not gap (see D-P1).** ADR-002 §3/D1
  say "default `true`" and, in the same breath, that the flag exists to keep headless sessions
  expressible. The ADR does not name the seam that realizes the opt-out. HEAD already has one: a
  `headless` flag computed from `MOTOKO_HEADLESS` at the origin site (`session.ail:957`, stored at
  `:974`). Hardcoding `true` leaves the opt-out unreachable at runtime; `require_system_prompt:
  !headless` satisfies both halves of the ADR. **Recommend `!headless`; operator confirm.** Either
  way it is a one-token change at one site and does not perturb the rest of the plan.
- **Anchor drift, not a gap.** All `session.ail` line numbers in the ADR's blast-radius table are
  −9 at HEAD `b76dd3e` (header comment shrank in the intervening commit). Corrected in the drift
  table above and the Anchor Re-Verification Log. The ADR's non-session anchors are exact.
- **Future merge overlap (note, do not resolve).** PRs #75/#76 live on other branches; this plan
  targets *this* tree. #76's `c5b0924` overlaps the env-manifest NOTE's WI-1, not this plan. No
  overlap with WI-1..WI-4 here beyond the shared `session.ail:CallModel` region, which #75/#76 also
  edit — flag at merge time; nothing to resolve now.

---

## Toolchain and artifacts verified this session

| Check | Command | Result |
|---|---|---|
| Toolchain pin | `ailang --version` | v0.26.0 / `3b52a24`, matches ADR-002 pin |
| Lock pin | `grep ailang_version ailang.lock` | `"v0.26.0"` (matches; `ailang.lock` shows as modified in `git status` but the version field is unchanged) |
| Grounding HEAD | `git log --oneline -10` | `b76dd3e` = HEAD, one commit past ADR authoring `64262d1` |
| Intervening commit scope | `git show b76dd3e -- src/core/session.ail` | header comment block only, 34→25 lines; **−9 shift** for all code below; no logic change |
| `phase_vocab` check | `ailang check src/core/phase_vocab.ail` | ✓ no errors |
| `session` check | `ailang check src/core/session.ail` | ✓ no errors |
| `phase_vocab` tests | `ailang test src/core/phase_vocab.ail` | 25 pass / 0 fail |
| `step_machine` tests | `ailang test src/core/step_machine.ail` | 16 pass / 0 fail |
| L1 harness | `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` | 10/10 PASS, no network |
| Single-gate invariant | `grep -n 'seal_compacted_payload\|dispatch_step' src/core/session.ail` | one seal call (`:1393`), one dispatch (`:1415`); imports at `:109`/`:118` |
| `MkSegment` export | `grep -n 'MkSegment' src/core/phase_vocab.ail` | `:107` unexported → scenarios use `split_for_compaction` |

## Anchor re-verification log

All read against HEAD `b76dd3e` this session (2026-07-05). `file:line` confirmed before entering
the plan; drift from ADR-002's numbers is called out.

- **`src/core/phase_vocab.ail`** (no drift from ADR): `take_system_prefix:80`;
  `CompactableSegment/MkSegment:107` (unexported); `PinnedSplit:110`; `split_for_compaction:123`;
  `seal_compacted_payload:131` (body `:132-136`); `StepPolicy:310`; `project` +
  `ProviderCallPrepared` stub `:160/:168`; `ProviderCallInfo:438`; `ErrorInfo:477`;
  `ErrorEvent` variant `:566`; wire projection `to_schema_v1_kvs` `ProviderCallPrepared` `:611`,
  `ErrorEvent`→`"error"` `:639`; `ledger_record_name` `:503/:507`; ledger test
  `test_ledger_trace_records_wire_and_stage_passed` literal `:839`; seal unit tests
  `:857/:874/:884` (exhaustion reason match at `:879`); golden test `:1023`; `ErrorEvent` golden
  `:1054`.
- **`src/core/session.ail`** (**−9** vs ADR): import block `seal_compacted_payload:109`,
  `ErrorEvent:91`, `StepPolicy:93`, `ProviderCallPrepared:68`, `CompactionExhausted:76`,
  `dispatch_step` import `:118`; `count_system_prefix:713`; `session_policy_init:952`
  (`headless` read `:957`, origin `step:` literal `:959-973`, `headless:` store `:974`);
  `session_policy_with_model:978` (derived literal `:980-994`);
  `emit_run_summary:575` (`finish_code` param); existing `ErrorEvent({...})` emit precedent `:1852`;
  `CallModel(_) =>` handler `:1382`
  (`split_for_compaction :1385`, `dispatch_pre_step_chain :1390`, `seal` call `:1393`,
  `Err→CompactionExhausted/ContextExhausted` `:1394-1399`, `Ok(payload) =>` `:1401`,
  `ProviderCallPrepared` emit `:1407-1414` with `count_system_prefix(compacted_msgs)` `:1410`,
  `dispatch_step` `:1415`); third `StepPolicy` literal in
  `run_v2_session_traced_with_persist_retries` (`:1658`) `:1675-1687` (inherit anchor `base.step.*`,
  `:1676-1684`); `AIError` result-type sites
  `:132/:1245/:1313/:1398`.
- **`src/core/step_machine.ail`** (no drift): `call_model_or_fail:67`
  (`project`-events discarded at `:72-75`); `decide:78`; `mk_policy:109` (literal `:110-119`);
  inline `StepPolicy` literals `:209`, `:221`.
- **`scripts/phase_c_l1_scenarios.ail`** (no drift): imports `:14-33`; `Scenario` type `:43`;
  `run_one/run_all` `:58/:72`; `policy()` `:98` (literal `:99-108`); `ok_or_failure:111`;
  split-based template scenario `:177-204`; `Scenario` builders `:335-369`; `main` list `:371`.
- **`src/core/compaction.ail`** (measurement law seal uses, no drift):
  `estimate_tokens_messages:17`; `usage_percent_with_limit:25`; `exhaustion_pct:30` (=95).
