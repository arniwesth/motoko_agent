# Phase-B implementation plan: phase results, ledger emission, compactor chain

Date: 2026-07-03
Status: Draft (implements Phase B of the **Proposed** `ADR-001-phase-oriented-core.md`)
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`, built `2026-07-02_15:03:57`);
`ailang.lock` → `ailang_version: "v0.26.0"`. Verified this session: `ailang --version` =
v0.26.0 / `3b52a24` — the pin has not moved. **Every `file:line` anchor below was re-read
against post-Phase-A HEAD (commit `d0d5b7e`) this session** (see "Anchor re-verification
log"); Phase A rearranged the files this plan edits, so no anchor was inherited from any
earlier document. `ailang test src/core/phase_vocab.ail` (12 pass), the sealing probe
(`IMP010` as required), and `make smoke_parity` (self-diff mode, empty diff) were **re-run**
this session before being relied on.

Authored by a fresh session per `HANDOFF-write-phase-b-plan.md` (same reasoning as
`NOTE-plan-authoring-session-choice.md`); produced from the committed documents plus the five
Phase A commits (`660c4b5`, `6eb735a`, `e8242b3`, `ccd43d2`, `d0d5b7e`), with discrepancies
recorded in "ADR gaps found" rather than guessed around.

Relates to:
- `ADR-001-phase-oriented-core.md` — normative; the Phase B deliverables + gate (including
  the 2026-07-03 G3c/G7 additions) are this plan's acceptance criteria.
- `RESEARCH-phase-core-dst-design.md` — elaboration; cited as **§N** (esp. §7.5 D9 chain
  semantics, §2 P2 ledger, §7.2 pipeline, §11 facts 16–19).
- `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — the provider-call
  recording contract (its lines 142–155) that WI-4 lands; R5/R15 carry 2026-07-03 amendments.
- `PLAN-phase-a-pure-foundations.md` — house style followed here; its G1–G8 record. Its
  `agent_loop_v2.ail` anchors are pre-implementation and were **not** reused.
- `NOTE-ailang-run-exit-code-false-alarm.md` — measurement discipline applied throughout
  (pipefail; minimal repro before any substrate-defect claim; never `$?` after a pipeline).

---

## TL;DR

**What:** the eight Phase B deliverables, in dependency order, each landing with the system
shippable and `make smoke_parity` explicable (byte-identical, or a documented expected diff):

1. **WI-0 — instruments first, zero production code**: freeze the mechanically regenerated
   29-name inventory as a committed artifact; land the **G7 in-repo fixture extension**
   (scripted `Handled` / `InterceptHandled` / `ContinueWithFeedback` / note-carrying
   `on_pre_step`) + a fixture parity smoke; extend the scripted stub with **deterministic
   stream chunks** + a stream-parity smoke; teach the parity harness the
   **additive-[NEW]-only** diff mode; land the **TUI unknown-type tolerance test**; re-capture
   the baseline.
2. **WI-1 — complete the ledger vocabulary** in `phase_vocab.ail` (pure, unused): one
   constructor per production event name with the **exact production kv layout** (the as-built
   projection is a sketch scaffold whose [prod] arms are *not* yet byte-compatible — see
   grounding), restructured as a kv-list projection so the driver adds the
   `schema_version`/`session_id` envelope; byte-level golden tests per constructor.
3. **WI-2 — single emission authority**: `ledger_emit` in `agent_loop_v2.ail` (projection +
   envelope + the Trace fan-out preserved); migrate all 38 `emit_event` + 6 `emit_run_summary`
   call sites to typed `LedgerEvent` construction, in three family-sized sub-commits, each
   byte-identical under the parity harness.
4. **WI-3 — streaming append handle**: `on_chunk` becomes a driver-issued ledger handle
   scoped to `StreamDelta`; `emit_stream_chunk` retires; the stream-parity smoke pins
   `thinking_stream_start → N×delta → thinking_stream_end` byte order.
5. **WI-4 — provider-call recording seam**: `provider_call_prepared` [NEW] emitted before
   every `dispatch_step`, consumed by an executable harness assertion (the L1 consumer).
6. **WI-5 — core-side system-prefix fix**: pin-and-segment split from `phase_vocab`; only
   segment messages reach `dispatch_pre_step`; prefix re-pinned after; the fixture smoke's
   `sys=1 → sys=0` note flip is the `system_messages_hidden_from_compactors`
   verified-in-wiring evidence.
7. **WI-6 — compactor chain (D9)**: `ext/runtime.ail` converts first-`Compacted`-wins to
   fold-through with a per-stage validation gate (`validate_compactor_output` in
   `phase_vocab`); stages return as data, driver emits (`compaction_extension` /
   `ext_compaction_rejected` [NEW]); core's structural call stays put as the shim. New
   deterministic chain smoke replaces the two dead `compaction_ai` smokes.
8. **WI-7 — ladder extraction (D9) + G3c retirement**: new bundled package
   `packages/motoko-ext-compaction-structural` (pure, ABI 2.2.0, registered **last** in all
   four profiles) takes the seven named constants and the elision/emergency machinery; core
   keeps the measurement primitives + the **exhaustion decision** (decided here: the emergency
   path moves too — Open Question 4 remnant); retire `compact_step` / `usage_percent` /
   `try_emergency_compaction` / `context_limit_for`; update the dependent smokes/tests.
9. **WI-8 — the gate checklist**, including the mechanical projection-subset gate.

**Gate (ADR, restated):** the projection's emitted `type` set for [prod] constructors is a
byte-compatible subset (modulo the G4 volatile fields: `MOTOKO_SESSION_ID`-pinned session id,
normalized `duration_ms`) of the frozen pre-B 29-name inventory; [NEW] names
(`provider_call_prepared`, `ext_compaction_rejected` — the only two Phase B emits) admitted
only after the TUI tolerance check (landed WI-0, static survey below); streaming byte-parity
passes; `system_messages_hidden_from_compactors` verified in wiring (WI-5).

---

## Goal

Land Phase B of ADR-001 — ledger-centralized emission, the streaming protocol, the
provider-call seam, the system-prefix fix, the compactor chain, the structural-compaction
extension, the wrapper retirement, and the test extension — with the production wire stream
byte-compatible for [prod] events and additively extended only by the two admitted [NEW]
names, while `loop_v2` keeps its current recursive control flow (inversion is Phase C).

## Out of scope (do not build here)

- **Phase C**: pure `decide`, driver-executes-decisions inversion, `run_v2_with_stub`
  supersession, the scripted TUI approval scenario, the L1 compaction scenario family, and
  the **module split** into `step_machine.ail`/`model_phase.ail`/`tool_phase.ail` — Phase B
  introduces phase-shaped seams inside `agent_loop_v2.ail` only (see decision D-B1).
- **ABI v3** (ports in `ExtCtx`, `telemetry`, `Compacted` artifacts field) and the
  **conformance kit** — parallel track. The one boundary exception the handoff names is
  in scope: `motoko_ext_compaction_structural` ships here against ABI **2.2.0**.
- **`compaction_ai` v0.3.0** migration — ABI track.
- **Checkpoint content-hash digest / digest-chain validation** — the placeholder digest in
  `phase_vocab.ail:39-43` stays labeled; nothing in Phase B consumes it as a security
  property (WI-4's `payload_digest` is likewise labeled interim — see D-B6).
- **`TakeCheckpoint` emission** — v1 never emits it.
- **The G8 repo-hygiene remainder** beyond what Phase B touches: of the 11 scripts still
  failing `ailang check` at HEAD (re-measured this session, list in the log), Phase B
  resolves only `smoke_v2_compaction_ai.ail` + `smoke_v2_compaction_ai_registry.ail` (by
  replacement, WI-6/7 — their imports name modules that do not exist at HEAD) and touches
  `smoke_v2_compaction.ail`/`smoke_v2_compaction_tiers.ail` because WI-7 moves their subject.
  The other broken scripts and a `check_scripts` CI target remain flagged repo hygiene.
- **`ExtCtx.history_slice` filtering** — extensions still see system-message *content* via
  `history_slice` (`agent_loop_v2.ail:437`); the ADR scopes deliverable 4 to the
  `dispatch_pre_step` compaction input, and the §7.0 exploit is closed by WI-5's re-pin.
  Recorded as gap G-B5 for the ADR's attention, not silently absorbed.

## Settled decisions this plan does not re-open

D1–D9 and dispositions G1–G8 are settled (ADR review log; operator sign-off). In particular:
chain semantics replace first-`Compacted`-wins with fold-through and a per-stage gate (D9);
the streaming resolution is the driver-issued append handle scoped to stream-delta events
(P1-R3/P2-R4 fix); `[prod]`/`[NEW]` are the two normative name classes with subset/tolerance
gates (P3-R2 fix); byte-compatibility is modulo the G4 volatile set. Contradictions with HEAD
found during implementation go to "ADR gaps found" here and the ADR's log — never silent
divergence.

---

## Grounding: Phase A as-built vs. its plan (deviations found)

Read from the diffs of `660c4b5..d0d5b7e` and the files at HEAD, as the handoff mandates:

1. **The parity harness normalizes more than the plan said.** The Phase A plan specified
   only `duration_ms` normalization; as built, `scripts/phase_a_event_parity.sh:30` also
   normalizes `make[N]` → `make[0]` and filters output to JSONL lines (`awk '/^\{/'`),
   discarding non-JSON stdout. Consequence for Phase B: the harness compares **JSON lines
   only** — assertions about non-JSON smoke output live in `tiers.txt` capture or in the
   smokes themselves.
2. **The as-built `to_schema_v1` is a scaffold, not a byte-compatible projection.** Checked
   arm-by-arm against production emitters this session; the [prod] arms diverge from the
   wire layout they must reproduce. Examples (not exhaustive): `StreamDelta` emits field
   `text` (`phase_vocab.ail:305`) where production emits `text_delta`
   (`agent_loop_v2.ail:260,:270`); `CostWarning` (`phase_vocab.ail:301`) lacks production's
   `pct`, `total_cost_usd`, `cap_millicents` and orders `step` before `threshold`
   (`agent_loop_v2.ail:1154`); `ProviderResult → thinking` (`phase_vocab.ail:296`) lacks
   `text`, `tool_calls`, `cost_usd`, and the omit-when-absent cache fields
   (`agent_loop_v2.ail:1130-1135` + `per_step_usage_kvs` `:295-307`); `DoneEvent`
   (`phase_vocab.ail:306`) adds a `source` field production's `done` does not have
   (`:1250-1252`,`:1306-1309`); `ToolPolicyDecided`/`ToolResultAppended` lack `stream_id`.
   None of this is live (the projection is unused by production), but **WI-1 is real work**,
   not a wiring exercise.
3. **`project()` is a labeled scaffold** (`phase_vocab.ail:91-105`): pin + passthrough + one
   placeholder event. Phase B replaces its role with the WI-5/WI-6 pipeline; see D-B4 for
   what `project` becomes.
4. **Emission-site counts, recounted at HEAD**: 38 `emit_event` call sites (+1 definition
   `:204` = the ADR's grep-hit 39), 6 `emit_run_summary` call sites (+def `:325` = 7),
   1 `emit_stream_chunk` call site `:1089` (+def `:250` = 2), 3 direct `emit_json` call
   sites — `:205` (inside `emit_event`), `:253`, `:263` (inside `emit_stream_chunk`) — +def
   `:106` = 4. The ADR's 39/7/2/4 figures are `grep -c` hits including definitions; the
   call-site truth WI-2/WI-3 must migrate is **38 + 6 + 1**, and the 3 `emit_json` calls
   collapse into the single emitter. Full site list in the survey below.
5. **Phase A's WI-1 constants landed exactly as planned** (`compaction.ail:51-63`, seven
   zero-arg `export pure func`s), and the transcript builders + `handled_tool_message`
   landed with call sites at `:729,:788,:802` (handled), `:758,:849` (tool_result),
   `:1137` (step_result), `:1185` (envelope), `:1048,:1398,:1564` (msgs_to_messages).

---

## The survey (ground truth this plan executes against)

All line numbers as of HEAD `d0d5b7e`; **re-grep before editing** (house rule).

### Emission sites in `agent_loop_v2.ail` (WI-2/WI-3's work list)

Envelope on every event: `schema_version`, `session_id`, `type` (`emit_event` `:204-211`),
plus the Trace fan-out (`emit_trace_event` `:150-159` — fires only for `session_start` and
`run_summary` per `trace_event_enabled` `:110-112`, with key redaction `:114-148`).

| Event name | Call sites | kv layout after `type` (verified) |
|---|---|---|
| `scratchpad_result` | `:218` (in helper, called `:728`) | tool_call_id, request_id, step, cells_json |
| `run_summary` | `:349` (helper; callers `:1015,:1029,:1066,:1112,:1249,:1305`) | model, motoko_commit, finish_reason, steps_executed, usage (nested object, cache fields omit-when-absent `:337-346`), total_cost_usd, total_cost_millicents, **duration_ms (volatile)**, error |
| `native_tool_denied` | `:655`, `:706` | step, stream_id, tool, id, reason |
| `tool_pending` | `:667` | step, stream_id, tool, id, reason — **emitted before `readLine()` `:676`; event-before-read is a protocol invariant** |
| `ext_tool_handled` | `:721`, `:780`, `:794` | step, stream_id, tool, id, exit_code |
| `delegated_tool_deferred` | `:736`, `:823` | step, stream_id, tool, id |
| `v2_tool_dispatch_start` | `:746`, `:837` | step, stream_id, tool, id |
| `v2_tool_dispatch_complete` | `:753`, `:844` | step, stream_id, id |
| `dp7_verifier_rejected` | `:928` | (enumerate at implementation) |
| `cost_exhausted` | `:1023` | step, total_cost_millicents, total_cost_usd, cap_millicents |
| `compaction_extension` | `:1044` | step, note |
| `compaction_exhausted` | `:1061` | step, model, reason |
| `thinking_stream_start` | `:1075` | step, stream_id, model |
| `thinking_stream_end` | `:1094` (errored), `:1125` (completed) | step, stream_id, status |
| `stream_error_retry` | `:1106` | step, error |
| `thinking` | `:1130` | step, text, finish_reason, tool_calls, + `per_step_usage_kvs` (input_tokens, output_tokens, cost_usd, cache fields omit-when-absent) |
| `cost_warning` | `:1154,:1157,:1160` | threshold, step, pct, total_cost_millicents, total_cost_usd, cap_millicents |
| `ext_intercept_handled` | `:1180` | step, tool, exit_code |
| `hybrid_bash_extracted` | `:1199` | (enumerate at implementation) |
| `done` | `:1250`, `:1306` | step, output |
| `ext_solver_feedback` | `:1264` | step, feedback |
| `persist_nudge` | `:1286` | step, nudge_num, budget |
| `native_tool_calls` | `:1336` | request_id, step, stream_id, tool_calls (Json array via `ja`) |
| `native_tool_results` | `:1343` | request_id, step, stream_id, results (Json array) |
| `session_suspend` | `:1505` | session_id, target_profile |
| `session_start` | `:1520` | task, model, mode |
| `error` | `:1528`, `:1569` | source, code, message |
| `thinking_delta` / `reasoning_delta` | `emit_stream_chunk` `:250-274`, called from `on_chunk` `:1089` mid-call | step, stream_id, seq (constant 0), **text_delta** |

Where a row says "enumerate at implementation": WI-1's method (copy the site's kv list
verbatim into the constructor's projection; golden test pins the encoded bytes) makes the
enumeration self-verifying — a wrong copy fails its golden test.

### The compaction / pre-step region (WI-5/6/7's seam)

`:1037` `catalog_context_limit_for(model)` (the catalog is the live limit source; the static
`context_limit_for` returns 0 for every model — `context_usage.ail:27-40`, fact 19);
`:1039` `mk_v2_ext_ctx` (passes `context_limit` into `ExtCtx` — the structural extension's
limit source); `:1042` `dispatch_pre_step(rt, ctx, messages_to_msgs(msgs))` — the **raw,
system-message-carrying list** (the §7.0 live gap; `rpc.ail:230-233` builds the system
message into `init`); `:1043-1051` Compacted → `compaction_extension` event + convert back;
`:1059` `compact_step_with_limit(msgs_after_ext, model, context_limit)` — today's sequential
structural stage; `Err` → `compaction_exhausted` `:1061` with reason from
`compaction.ail:135` (`"compaction_exhausted: context at ${pct2}% of ${model} limit after
emergency compaction"`). Chain target: `first_compacted` / `dispatch_pre_step`
`ext/runtime.ail:144-166` (first-`Compacted`-wins; test_dummy instrumentation `:149-155`).

### TUI event consumption (the unknown-type tolerance survey — first read of `src/tui` in this project)

- `parseAgentEventLine` (`src/tui/src/runtime-process.ts:103-115`): accepts **any** JSON
  object with a string `type`; unknown types pass through as `AgentEvent` (cast, no
  validation).
- `index.ts` `PlainLogger.handleEvent` switch (`:468`): no `default` arm → unknown types
  no-op. `done`/`error` exits key off specific types (`:612-613`) — unaffected by additions.
- `ui.ts` `handleEvent` switch (`:2291`): no `default` arm → unknown types no-op.
- `session-logger.ts`: `logTranscriptEvent` switch (`:272`) has `default: break` (`:343`);
  `log()` (`:348-350`) writes **every** parsed event verbatim to the session JSONL.
- No `assertNever` / exhaustiveness guard anywhere in `src/tui/src/*.ts` (grepped).

Conclusion: unknown `type` values are silently ignored by all three consumers and preserved
in the session log. WI-0 turns this survey into an executable jest test so it cannot rot.
TUI tests run via `npm test` in `src/tui` (jest under bun, `package.json`).

### Packaging precedent (WI-7)

Path-dep extension packages exist and are registered:
`"sunholo/motoko_ext_context_mode" = { path = "packages/motoko-ext-context-mode" }` and
`"sunholo/motoko_ext_scratchpad" = { path = "packages/motoko_scratchpad" }` in the root
`ailang.toml` `[dependencies]`, listed in `[extensions].packages`, with
`registry_generated.ail` regenerated by `ailang generate-extension-registry` (header of
`src/core/ext/registry_generated.ail`). Package manifest shape:
`packages/motoko-ext-context-mode/ailang.toml` (name `sunholo/motoko_ext_*`, dep
`"sunholo/motoko_ext_abi" = "2.2.0"`, `[exports] modules`). Extension order is
config-profile data: `.motoko/config/{default,dogfood,local,openrouter}/config.json`
`.extensions.order` (all four currently start with `compaction_ai`; none has a structural
entry). `make sync_packages` mirrors `src/core/ext/<name>` dirs into `.packages/` and is
**not** the mechanism for `packages/`-resident path deps (all `src/core/ext/*/` dirs are
empty at HEAD — fact 12 confirmed). **Risk, probed in WI-7**: no existing `packages/`
package depends on `sunholo/motoko_core`, and `src/core/ailang.toml` `[exports]` lists only
`compress`, `config`, `tool_contract`, `types` — importing core's measurement primitives
from the new package is unproven substrate territory.

### Wrapper-retirement blast radius (G3c, WI-7)

Verified consumers of the dead model-keyed path: `compaction.ail`'s own inline tests
(`:167,:177,:244`); `scripts/smoke_v2_compaction.ail` (`:21,:35,:41,:61`);
`scripts/smoke_v2_compaction_tiers.ail` (uses `_with_limit` + the ladder — moves with it);
`src/core/test/integration_tests.ail:42` (`compact_step_with_limit("test/tiny", 100)`);
`context_usage.ail:70-79` (`catalog_context_limit_for`'s fallback arms). Production uses
only `compact_step_with_limit` (import `agent_loop_v2.ail:58`, call `:1059`). `test/tiny` =
100 tokens in `.motoko/model-catalog.json` `context_limits` (verified).

### Scripted-stub facts (WI-0/WI-3/WI-4)

`run_v2_with_stub(rt, task, env_url, hybrid_tools, budget, model, history, workdir,
step_budget, ohmy_pi, max_cost_millicents, cost_rates, script)` (`agent_loop_v2.ail:1581`)
accepts an arbitrary `ExtRuntime` — the fixture-extension seam. `stub_step.ail`'s `Scripted`
branch **never invokes `on_chunk`** (`:121-135`, deliberate) — deterministic streaming
coverage requires extending `ScriptedStep` (D-B8). Constructors: five in `stub_step.ail`
(`prose_step`, `tool_step`, `token_step`, `continuing_token_step`, `terminal_step`) plus
exactly one inline record literal in the fleet (`smoke_v2_pending_full_loop.ail:112-118` —
grep-verified; every other smoke uses the helpers). A second load-bearing stub fact:
**compaction is per-step ephemeral** (`compaction.ail:16-18`; the loop recurses on the
original `msgs`, `agent_loop_v2.ail:1138`) — chain output is observable only via the
provider payload (`provider_call_prepared.msg_count` after WI-4), the emitted stage events,
or a direct `dispatch_pre_step_chain` call, never via the loop's returned history.

---

## Plan-level decisions (with justification; recorded once, applied throughout)

**D-B1 — What "phases return `PhaseResult`" means in Phase B.** `loop_v2` keeps its recursive
shape, so in Phase B **`loop_v2` is the driver**: single logical emission authority =
every site constructs a typed `LedgerEvent` and exactly one function (`ledger_emit`)
projects + emits. Phase-shaped extraction (a function returning batched events for the
driver to emit) is applied only where ordering semantics permit batching: the **pre-step
compaction phase** (WI-5/6 — its events never interleave with reads) and the **model phase's
post-call events**. Events with protocol-ordering constraints stay constructed-and-emitted
in place: `tool_pending` **must** precede the `readLine()` block (`:667→:676` — batching it
would break the live approval protocol the ADR defers to Phase C), and stream deltas are
mid-call by nature (the ADR's append handle, WI-3). Full `PhaseResult` returns for tool and
model phases as separate modules land in Phase C with the inversion; doing it now without
`AwaitApproval` would either break event-before-read or need handle-scope creep the ADR
forbids ("scoped to stream-delta events"). The ADR's Phase B deliverable list (the
acceptance criteria per the handoff) is fully covered without it.

**D-B2 — Projection shape.** `to_schema_v1` is restructured as
`to_schema_v1_kvs(e: LedgerEvent) -> [{key,value}]` returning the `type`-first kv list;
`to_schema_v1(e) = jo(to_schema_v1_kvs(e))` remains for L0 tests. The driver's
`ledger_emit(session_id, e)` emits `jo(envelope(session_id) ++ to_schema_v1_kvs(e))` and
preserves the Trace fan-out (redaction rules unchanged, keyed on the projected type name).
This reproduces the current byte layout exactly: envelope first, then `type`, then the
site's kvs in order.

**D-B3 — Chain API.** `ext/runtime.ail` exports
`dispatch_pre_step_chain(rt, ctx, msgs) -> { msgs: [Msg], stages: [PreStepStage] }` where
`PreStepStage = { ext_id: string, outcome: StageOutcome }`,
`StageOutcome = StageApplied(string) | StageRejected(string) | StagePassed`. The runtime
returns **data**; the driver converts outcomes to events (`StageApplied` →
`compaction_extension`, `StageRejected` → `ext_compaction_rejected`; `StagePassed` → no
JSONL event — see gap G-B1). The gate predicate `validate_compactor_output(msgs_in, msgs_out)
-> Result[(), string]` lives in `phase_vocab.ail` operating on `[Msg]` (no import cycle:
`phase_vocab` imports only std + `tool_contract` + `types`); v1 checks: (a) no system-role
messages in output, (b) every tool-role message has a non-empty `tool_call_id`, (c) pairing
preserved **relative to input**, not as absolute well-formedness: no `tool_call_id` appears
in output that was absent from input, and for every id present in output, the presence of
its assistant call and of its tool result each match input's — a compactor may drop a pair
entirely but may not sever one or invent one. The relative form is load-bearing: valid
production transcripts contain **orphan** tool-result messages by design
(intercept-synthesized envelopes, `envelope_to_tool_message` — the model never emitted the
call, `agent_loop_v2.ail:1178-1187`), so an absolute "every result pairs with a call" check
would reject an identity pass-through of a legal transcript. These predicates migrate into
the conformance kit's `invariants.ail` when the ABI track builds it (one source of law, per
D8); until then `phase_vocab` is their home.

**D-B4 — What `project()` becomes.** The scaffold body is replaced by the pure parts of the
pipeline it always advertised: pin head prefix → `CompactableSegment`. Because the chain is
effectful (extension hooks), `project` cannot run it; instead `phase_vocab` exports the
split/reassemble ops (`split_for_compaction : [Message] -> PinnedSplit` with
`PinnedSplit = { pinned: [Message], segment: CompactableSegment }`, and
`segment_messages : CompactableSegment -> [Message]`) and the driver composes
split → chain → gate → re-pin. Exported wrapper records naming sealed types cross module
boundaries per the settled co-location adjudication (fact 17); `MkSegment` stays unexported.

**D-B5 — Exhaustion decision stays in core; the emergency path moves.** This closes the ADR
Open Question 4 remnant, following its recorded lean. The structural extension implements
the full ladder including both emergency tiers (it *cannot* signal failure —
`PreStepDecision` has no error arm, ABI 2.2.0 `types.ail:124-127` — so it returns its best
effort), and returns **`PassThrough` whenever elision changed nothing** (below the first
tier, or all tool messages inside the keep-last window) — matching today's semantics where
an unchanged `Ok(msgs)` from `compact_step_with_limit` is silent, and keeping no-op stages
out of the event stream. Core's scaffold keeps exactly one policy value:
`exhaustion_pct() = 95`, a new named export in `compaction.ail`, applied **after** the
chain and measured over the **re-pinned full list against the catalog limit** (today's
exact safety basis): `limit > 0 && usage_percent_with_limit(repinned, limit) >=
exhaustion_pct()` ⇒ `Err(ContextExhausted)` with reason
`"compaction_exhausted: context at ${pct}% of ${model} limit after compactor chain"`;
`limit == 0` stays fail-open (unknown models — `compaction_full_loop` case 4 pins this).
Zero-compactor behavior is honest exhaustion at the same threshold. The 95 in core
(exhaustion gate, full-list basis) and the 95 in the extension (emergency tier trigger,
segment basis — see the effective-limit convention in WI-5) are semantically distinct and
numerically coupled; both docs cross-reference. Byte-level residue: the reason string
changes (today's says "after emergency compaction", `compaction.ail:135`) — a documented
expected diff (gap G-B3), visible only on the exhaustion path.

**D-B6 — `payload_digest` is a labeled interim digest.** WI-4 needs a deterministic digest
of the provider payload. AILANG v0.26.0 has no vetted content-hash in this repo's stdlib
usage, and the real content-hash is a checkpoint-seam obligation (ADR D7, deferred). WI-4
ships a cheap pure rolling digest over role/content bytes in `phase_vocab`
(`payload_digest([Message]) -> string`), **labeled** like the history digest: collision
resistance is not claimed; DST ADR-001's contract explicitly allows "bounded projection plus
hashes". The checkpoint content-hash work replaces both labels at once.

**D-B7 — Parity protocol for a phase that intentionally adds events.** The harness gains a
**transient admission mode**: `PARITY_STRIP_TYPES="provider_call_prepared,
ext_compaction_rejected"` (env, consumed by `phase_a_event_parity.sh`) diverts lines whose
`type` matches into a **sibling directory** `<out_dir>.new/` (not into `<out_dir>` — the
`smoke_parity` target's `diff -r` must see only the main captures), and the harness asserts
every diverted line's `type` is in the allowlist. At the WI that admits a [NEW] name
(WI-4, WI-6): verify strip-mode diff vs. the old baseline is empty (proves the [prod]
stream untouched and the additions allowlisted), then **re-bless a new baseline captured
without strip mode** — i.e. blessed baselines always include the [NEW] lines, and every
subsequent WI (and the final WI-8 gate) runs a **strict** byte diff. For the two WIs whose
expected diffs touch [prod] bytes (WI-5's fixture note flip; WI-7's compaction-smoke
changes), the protocol is: run the strict diff, check it line-for-line against the WI's
**expected-diff table** (committed in this plan), record the verified diff in the commit
message, re-bless. Never re-bless without the table check.

**D-B8 — Deterministic streaming via the stub.** `ScriptedStep` gains `chunks: [string]`;
the `Scripted` branch of `dispatch_step` plays each entry as `ContentDelta` through
`on_chunk` (in list order, before returning the result). Existing constructors set
`chunks: []` — zero behavior change for existing smokes (`on_chunk` currently unused in the
Scripted branch, `stub_step.ail:121-135`). New constructor
`chunked_prose_step(text, chunks)`. This is what makes the ADR's streaming byte-parity test
scripted and hermetic instead of live-provider-dependent. Blast radius of the record-field
addition (grep-verified this session): the five constructors in `stub_step.ail` itself plus
**exactly one** inline `ScriptedStep` record literal in the fleet —
`smoke_v2_pending_full_loop.ail:112-118` — which gains `chunks: []` in the same commit
(every other smoke builds steps via the constructor helpers).

**D-B9 — Replace, don't repair, the two compaction-AI smokes.** `smoke_v2_compaction_ai.ail`
imports `src/core/ext/compaction_ai` and `smoke_v2_compaction_ai_registry.ail` imports
`src/core/ext/compaction_ai_register` — **neither module exists at HEAD** (all
`src/core/ext/*/` dirs are empty; the extension lives in the registry as
`sunholo/motoko_ext_compaction_ai@0.2.0`). They are unrepairable as written and their
subject (chain-position behavior of an effectful compactor) is exactly what WI-6's
deterministic chain smoke covers with fixtures. They are deleted when their replacement
lands; the registry package's own certification is the ABI track's conformance-kit job.

**D-B10 — Fixture extension design (G7).** `src/core/test/ext_fixture.ail` (sibling of
`stub_step.ail`; not a package — no hydration, no registry, importable by scripts) exports
`fixture_rt() -> ExtRuntime` with one hooks record (`id: "phase_b_fixture"`):
`provided_tools: ["FixtureEcho"]`; `on_tool_handle` → `Handled` with an envelope whose
`tool_call_id` is a fixed extension-internal id **different from the model call id** (pins
`handled_tool_message`'s id-selection semantics e2e); `on_response_intercept` →
`InterceptHandled` when the response contains `[FIXTURE_INTERCEPT]` (drives
`envelope_to_tool_message`); `on_solver_candidate` → `ContinueWithFeedback` when the
candidate contains `[FIXTURE_CONTINUE]`, else `NoDecision`; `on_pre_step` →
`Compacted(msgs unchanged, "fixture_prestep sys=${count of system-role msgs seen}")` —
identity output (gate-clean) whose **note makes the compactor's view of system messages
observable in the JSONL**, turning WI-5's fix into a byte-visible event change. G7's ADR
wording names `Handled` + `ContinueWithFeedback`; `InterceptHandled` is additionally needed
because `envelope_to_tool_message`'s only call site is the intercept path
(`agent_loop_v2.ail:1185`) — recorded as gap G-B4.

---

## Work breakdown

Each WI lists **Files touched**, **Verification** (commands at that step's boundary), and
**Rollback**. Order is load-bearing: instruments before any production edit (WI-0);
vocabulary before wiring (WI-1 → WI-2); emission authority before the seams that extend it
(WI-2 → WI-3/4); prefix fix before the chain so the chain's gate never sees system messages
(WI-5 → WI-6); chain before the ladder relocation that depends on it (WI-6 → WI-7).
**Strangler discipline**: after every WI, `make check_core`, `make test_core`,
`make test_integration` are green and `make smoke_parity` (vs. the current blessed baseline)
is byte-identical or matches that WI's expected-diff table exactly.

### WI-0 — Instruments and baseline (test-only; zero production code)

- **Files touched (new):**
  - `scripts/phase_b_inventory_baseline.txt` — the frozen pre-B inventory: the 29 names,
    regenerated this session with the command from `phase_vocab.ail:251-263` (27
    `emit_event` names + `thinking_delta` + `reasoning_delta`; output matches the sketch
    inventory exactly). Committed **before** any emission site moves, because Phase B
    itself invalidates the regeneration command's source; the file header records the
    command and the commit it was run against.
  - `src/core/test/ext_fixture.ail` — the G7 fixture extension (D-B10 shape).
  - `scripts/smoke_v2_ext_fixture_parity.ail` — scripted full-loop smoke:
    `run_v2_with_stub(fixture_rt(), …, "anthropic/claude-sonnet-4-6", …)` (200k catalog
    limit — tier compaction never triggers), **history seeded `[system, user]`** — no
    existing parity smoke seeds a system message (survey), and both the `sys=1` assertion
    here and WI-4's `system_prefix_count` assertion need one — with script
    `[tool_step("FixtureEcho", "{}", "call-fix-1"), prose_step("[FIXTURE_CONTINUE] draft"),
    prose_step("[FIXTURE_INTERCEPT] trip"), prose_step("done")]`. Asserts `Ok`; the harness
    asserts the event bracket: `ext_tool_handled`, `ext_solver_feedback`,
    `ext_intercept_handled`, and `compaction_extension` with note containing
    `fixture_prestep sys=1` (the pre-WI-5 truth: the compactor sees the system message).
    This closes G7: all three extension-path message constructors
    (`handled_tool_message`, `envelope_to_tool_message`, plus the feedback path) are now
    e2e-parity-covered before emission rewires.
  - `scripts/smoke_v2_stream_parity.ail` — scripted smoke, history seeded `[system, user]`
    (same reason), using `chunked_prose_step("full text",
    ["chunk-a","chunk-b","chunk-c"])`; the harness asserts the exact line sequence
    `thinking_stream_start` → 3× `thinking_delta` (with `text_delta` values in script
    order) → `thinking_stream_end` (status completed) → `thinking`. This is the ADR's
    streaming byte-parity instrument, captured **before** WI-3 flips the emission path.
  - `src/tui/src/runtime-process.unknown-events.test.ts` — the TUI tolerance check made
    executable: `parseAgentEventLine` accepts `{"type":"provider_call_prepared",…}` and
    `{"type":"ext_compaction_rejected",…}`; plus a survey-pinning test that the
    session-logger transcript switch tolerates an unknown type without throwing. (The
    `ui.ts`/`index.ts` switches have no default arm and are covered by the static survey
    above; their classes are not cleanly importable — recorded honestly.)
- **Files touched (edited, test-only):**
  - `src/core/test/stub_step.ail` — `ScriptedStep` gains `chunks: [string]`; `Scripted`
    branch plays chunks through `on_chunk`; five existing constructors gain `chunks: []`;
    new `chunked_prose_step`. Plus the one inline literal outside this file:
    `smoke_v2_pending_full_loop.ail:112-118` gains `chunks: []` (D-B8 blast radius).
  - `scripts/phase_a_event_parity.sh` — adds the two new smokes to the fixed list; adds the
    `PARITY_STRIP_TYPES` additive mode (D-B7); adds the fixture/stream assertion blocks
    (same pattern as the existing `smoke_phase_a_tool_parity` grep block `:44-48`).
- **Procedure:** land everything, then capture the Phase B baseline:
  `./scripts/phase_a_event_parity.sh /tmp/phase_b_baseline` twice, self-diff empty
  (determinism), keep the survivor as the blessed baseline. Every later WI diffs against
  the **current blessed** baseline.
- **Verification:** `ailang check` clean on both new smokes + `ext_fixture.ail` +
  `stub_step.ail`; `make smoke_parity` self-diff green;
  `cd src/tui && npm test` green (new test included); `make check_core` / `make test_core`
  / `make test_integration` green (stub edit is additive);
  inventory file diff-clean against a fresh regeneration.
- **Rollback:** delete the new files, revert the two edited test files. Nothing in
  production references any of it.

### WI-1 — Complete the ledger vocabulary (`src/core/phase_vocab.ail` only; still unused)

Extend `LedgerEvent` to one constructor per production event name (the 27 `emit_event`
names — `StreamDelta` already covers the two delta types) with info records carrying
**exactly** the production kv fields in production order (survey table above; re-grep each
site while writing). Structural points:

- Restructure to `to_schema_v1_kvs` + thin `to_schema_v1` wrapper (D-B2).
- Fix every as-built [prod] mismatch found in grounding item 2 (`text_delta`,
  `cost_warning` fields/order, `thinking` full layout with omit-when-absent cache kvs —
  the info record carries the four token ints and the projection reproduces
  `per_step_usage_kvs`'s conditional shape, `done` drops `source`, tool events gain
  `stream_id`).
- Genuinely structural payloads (`native_tool_calls.tool_calls`,
  `native_tool_results.results`, `scratchpad_result.cells_json`) are carried as `Json` in
  the info records — the driver builds them with the existing helpers, the projection
  embeds them. **Conditionally shaped** payloads (`thinking`'s usage kvs, `run_summary`'s
  nested `usage` object — both with omit-when-absent cache fields) are carried as typed
  ints and the projection reproduces the conditional shape, so the layout logic lives in
  exactly one place and the golden tests can pin both branches.
- `run_summary`'s `duration_ms` is **data** in the info record (the driver computes it from
  Clock); the projection stays pure.
- Constructor classes annotated [prod]/[NEW] as now; `TotalsUpdated`/`CheckpointTaken`
  remain in the type, still unemitted (their [NEW] names are **not** admitted in Phase B).
- **Golden byte tests per constructor**: `encode(jo(to_schema_v1_kvs(e)))` compared to a
  string literal transcribed from the production emitter for a fixed input — the mechanical
  equivalence evidence WI-2 relies on. The existing 12 inline tests are updated where
  layouts change (e.g. `test_stream_delta_projection_names` gains a `text_delta` field
  assertion).

- **Files touched:** `src/core/phase_vocab.ail`.
- **Verification:** `ailang check` + `ailang test src/core/phase_vocab.ail` (12 existing +
  new golden tests all green); `make check_core`; `make smoke_parity` vs. blessed baseline
  **byte-identical** (module still unused by emission);
  `ailang check scripts/probe_phase_vocab_sealed.ail` still fails `IMP010`.
- **Rollback:** revert the single file.

### WI-2 — Single emission authority + site migration (production edit, 3 sub-commits)

Add to `agent_loop_v2.ail`:
`func ledger_emit(session_id: string, e: LedgerEvent) -> () ! {IO, Trace}` — body:
`emit_json(jo(envelope ++ to_schema_v1_kvs(e)))` + the Trace fan-out (redaction preserved,
keyed on the projected type). Then migrate sites family by family, each sub-commit
parity-checked:

- **WI-2a — session/summary/error family**: `run_summary` (rebuild `emit_run_summary` as a
  thin builder that constructs the `RunSummary` event — its 6 callers unchanged in shape),
  `session_start`, `session_suspend`, `error`, `cost_exhausted`, `cost_warning`,
  `stream_error_retry`, `done`, `persist_nudge`, `ext_solver_feedback`,
  `dp7_verifier_rejected`, `hybrid_bash_extracted`.
- **WI-2b — model-step family**: `thinking_stream_start`, `thinking_stream_end` (both
  sites), `thinking`, `compaction_extension`, `compaction_exhausted`,
  `ext_intercept_handled`. In the same commit, the post-call event pair
  (`thinking_stream_end` completed + `thinking`) and the assistant-message construction are
  grouped into an internal model-phase seam returning
  `{ result, next_provider, events: [LedgerEvent] }` with the driver emitting the batch —
  the D-B1-scoped "phase returns its events" shape, byte-order-identical because batch
  order = construction order and nothing interleaves.
- **WI-2c — tool-dispatch family**: `native_tool_calls`, `native_tool_results`,
  `native_tool_denied`, `tool_pending`, `ext_tool_handled`, `delegated_tool_deferred`,
  `v2_tool_dispatch_start`/`_complete`, `scratchpad_result`. These stay
  construct-and-emit-in-place inside `dispatch_calls` (D-B1: `tool_pending` before
  `readLine()` is a protocol invariant; the recursion is driver code in Phase B).

After WI-2c: `emit_event` and its `extra`-kv plumbing are deleted; `emit_json` has exactly
two remaining callers (`ledger_emit`, `emit_stream_chunk` — the latter falls in WI-3);
`emit_trace_event` survives inside `ledger_emit` only.

- **Files touched:** `src/core/agent_loop_v2.ail` (+ `phase_vocab.ail` only if a layout
  correction surfaces — any such correction must first fail a WI-1 golden test).
- **Verification (after each sub-commit):** `ailang check` + `ailang test` on both files;
  `make check_core` / `make test_core` / `make test_integration`;
  `make smoke_parity` vs. blessed baseline **byte-identical** (this is the WI the harness
  exists for — the 9 captured smokes exercise every family: the fixture smoke covers
  ext/tool events, the stream smoke covers the model family, cost/dp7/pending/handle/hybrid
  cover the rest).
- **Rollback:** revert per sub-commit (each family is independently revertible).

### WI-3 — Streaming append handle (byte-identical)

Replace `on_chunk = \chunk. emit_stream_chunk(…)` (`:1089`) with a driver-issued handle:
`let stream_append = \e. ledger_emit(session_id, e)` and a chunk adapter building
`StreamDelta({step, stream_id, seq: 0, kind, text})` from `ContentDelta`/`ThinkingDelta`
(`Usage` still dropped). The handle is constructed by the driver and scoped to stream-delta
events by construction — single logical authority holds (ADR streaming resolution).
`emit_stream_chunk` and its two `emit_json` sites are deleted; the match-in-lambda parser
constraint still applies, so the adapter is a named top-level func (house precedent
`:248-249`).

- **Files touched:** `src/core/agent_loop_v2.ail`.
- **Verification:** the full WI-2 command set; `make smoke_parity` **byte-identical** — the
  stream-parity smoke's pinned `start → delta×3 → end → thinking` sequence is the ADR's
  streaming byte-parity test passing against the new path; negative grep:
  `grep -c 'emit_json(' src/core/agent_loop_v2.ail` = 2 (def + `ledger_emit`).
- **Rollback:** revert the commit (restores `emit_stream_chunk`).

### WI-4 — Provider-call recording seam ([NEW]: `provider_call_prepared`)

Before `dispatch_step` (`:1090`), emit
`ProviderCallPrepared({step, msg_count, system_prefix_count, payload_digest, model})` —
fields chosen against DST ADR-001's contract (its lines 142–155): bounded projection +
digest in lieu of the full payload; `system_prefix_count` is the pinned-prefix observation;
the result-side fields (tokens, finish_reason, tool-call count) are already carried by the
[prod] `thinking` event. `payload_digest` per D-B6 (labeled interim), computed over
`compacted_msgs` — the *actual* payload `dispatch_step` receives. Info record extended in
`phase_vocab` accordingly (`ProviderCallInfo` gains `system_prefix_count`, `model`).

The **L1 consumer** (ADR acceptance criterion 2): the harness gains an assertion block
**scoped to the two WI-0 smokes** (the only ones with system-seeded histories — survey) —
count of `provider_call_prepared` lines equals the scripted step count, each with
`system_prefix_count` = 1 and a non-empty digest; plus a golden pure test pinning the
projection. (A scripted smoke consuming the seam *is* an L1 test: scripted provider, no
network, fake-free ports pending Phase C.) The legacy smokes' histories have no system
prefix; their `provider_call_prepared` lines are verified additive-only by the strip mode,
not field-asserted.

- **Files touched:** `src/core/agent_loop_v2.ail`, `src/core/phase_vocab.ail`,
  `scripts/phase_a_event_parity.sh` (assertion block).
- **Verification:** WI-2 command set; `make smoke_parity` with
  `PARITY_STRIP_TYPES=provider_call_prepared` — strict diff vs. the WI-0 baseline empty,
  diverted lines contain only the allowed name, assertion block green; then **re-bless**
  the baseline without strip mode (D-B7 — the blessed stream now includes the [NEW]
  lines). TUI tolerance test (WI-0) is the admission evidence for the [NEW] name.
- **Rollback:** revert the commit + re-bless the prior baseline; the harness assertion
  block reverts with it.

### WI-5 — Core-side system-prefix fix (closes the §7.0 live gap)

In `phase_vocab.ail`: `PinnedSplit` + `split_for_compaction` + `segment_messages` (D-B4);
`project()`'s scaffold body is replaced by delegation to the split (its
"real pipeline in Phase B" header promise, kept honest); `validate_compactor_output` lands
here as **pure code + tests only** — its rejection wiring is WI-6's (no
`ext_compaction_rejected` is emitted before the chain exists; a `Compacted` result is
applied unvalidated in WI-5 exactly as today). In `agent_loop_v2.ail` (`:1039-1051`): split
before the pre-step dispatch; pass `messages_to_msgs(segment_messages(split.segment))` to
`dispatch_pre_step`; on `Compacted`, **re-pin**:
`split.pinned ++ msgs_to_messages(compacted)`. The structural stage
(`compact_step_with_limit`, `:1059`) operates on the re-pinned list exactly as today
(elision never touches non-tool messages — behavior unchanged).

**Effective-limit convention (lands here, because this WI changes what compactors can
measure):** compactors now see only the segment, so a threshold measured as
`segment_tokens / catalog_limit` under-reads by the pinned prefix's share, deferring
compaction relative to today. Compensation: the pre-step `ExtCtx` (`:1039`) gets
`context_limit = catalog_limit − estimate_tokens_messages(split.pinned)` (floor 0) — "the
limit available to the compactable segment". This is core scaffold measurement, not policy;
the per-purpose ctx at `:1039` feeds only `dispatch_pre_step` (the ctx at `:1139` for
intercept/solver hooks is separate and keeps the raw catalog limit). Exactness note: with a
pinned-prefix share `s` of the limit, a compactor tier `t` now fires at total usage
`t + s(1−t)` instead of `t` — identical when `s = 0`, slightly later otherwise; all current
parity smokes have `s = 0` (no system messages in their histories — survey), so this is
byte-invisible in the harness and recorded as a designed deviation in G-B3.
`ExtCtx.history_slice` is deliberately not touched (out of scope; gap G-B5).

- **Expected diff (the only one):** the fixture smoke's `compaction_extension` note flips
  `fixture_prestep sys=1` → `fixture_prestep sys=0` — this **is** the
  `system_messages_hidden_from_compactors` verified-in-wiring evidence the ADR gate names.
  The harness's fixture assertion is updated to require `sys=0` in the same commit;
  baseline re-blessed per D-B7.
- **Files touched:** `src/core/phase_vocab.ail`, `src/core/agent_loop_v2.ail`,
  `scripts/phase_a_event_parity.sh` (assertion flip).
- **Verification:** WI-2 command set; strict parity diff = exactly the note flip
  (`fixture_prestep sys=1` → `sys=0` in the fixture smoke's `compaction_extension` lines,
  nothing else); new pure tests: `split_for_compaction` pins/rejoins correctly, segment
  never contains system messages, `validate_compactor_output` accepts identity — including
  identity over a segment containing an **orphan** intercept-synthesized tool message
  (D-B3's relative-pairing rationale, pinned as a test) — and rejects a system-injecting /
  pair-severing / id-inventing output (three negative fixtures).
- **Rollback:** revert the commit + re-bless the previous baseline (recorded in the WI's
  commit message).

### WI-6 — Compactor chain (D9; `ext/runtime.ail` + driver wiring)

`first_compacted`/`dispatch_pre_step` (`ext/runtime.ail:144-166`) are replaced by the
fold-through `dispatch_pre_step_chain` (D-B3): each hook receives the previous stage's
msgs; per-stage gate via `validate_compactor_output` (import from `phase_vocab`); invalid ⇒
`StageRejected(reason)`, stage skipped, chain continues (subsumes the old hard-coded
fallback); registry order = pipeline order; the test_dummy instrumentation (`:149-155`)
moves into the fold unchanged. The driver (`agent_loop_v2.ail:1042-1051`) consumes
`{msgs, stages}`: `StageApplied` → `compaction_extension` (same layout as today),
`StageRejected` → `ExtCompactionRejected` [NEW]. The core structural call (`:1059`) is
**unchanged in this WI** — it is the shim that makes the conversion behavior-preserving
until WI-7 relocates it (chain(ext…, structural-last) ≡ today's sequential composition,
§7.5; with at most one registered compactor, fold-through ≡ first-wins).

New deterministic chain smoke `scripts/smoke_v2_compaction_chain.ail` (replaces the two
dead compaction-AI smokes, D-B9). Compaction is per-step ephemeral (survey), so the smoke
has two sections with different observation channels:
- **Direct section** — calls the exported `dispatch_pre_step_chain` itself with a
  constructed rt of three inline fixture compactors: A returns
  `Compacted(msgs ++ [user-role marker "chain-A"], "A")` (gate-clean: no system role, no
  tool ids invented), B returns a **pair-severing** output (gate must reject; chain
  continues on A's output), C rewrites tool content validly. Asserts on the returned
  record: `msgs` show C applied *on top of* A's marker (fold-through, B skipped), `stages`
  in registry order with `[Applied, Rejected, Applied]` outcomes. ✓/✗ report + `exit(1)`,
  tiers-smoke style.
- **Full-loop section** — `run_v2_with_stub` with the same rt, so the harness JSONL carries
  the driver's view: per step, two `compaction_extension` events (notes `A`, then C's) and
  one `ext_compaction_rejected`, in registry order; after WI-4 the
  `provider_call_prepared.msg_count` reflects the chain's output (marker added), pinning
  that the compacted view actually reached the provider payload.
Added to the harness list (`ailang check`-gated like every member).

- **Files touched:** `src/core/ext/runtime.ail`, `src/core/agent_loop_v2.ail`,
  `scripts/smoke_v2_compaction_chain.ail` (new), `scripts/phase_a_event_parity.sh` (list +
  strip-type `ext_compaction_rejected`), deletion of `scripts/smoke_v2_compaction_ai.ail` +
  `scripts/smoke_v2_compaction_ai_registry.ail`.
- **Verification:** WI-2 command set + `ailang test src/core/ext/runtime.ail` (its inline
  dispatch tests updated to the chain API); `make smoke_parity` with
  `PARITY_STRIP_TYPES=ext_compaction_rejected` — strict diff vs. the **WI-5** baseline
  (the current blessed one) empty for all pre-existing smokes (the fixture smoke's single
  valid compactor behaves identically under fold-through; the rejected name appears only
  in the new chain smoke); chain smoke green (both sections); then re-bless without strip
  mode, adding the chain smoke's capture (D-B7).
- **Rollback:** revert the commit (restores first-wins + the two deleted smokes).

### WI-7 — Ladder extraction + registration + G3c retirement (the relocation WI)

**7a — probe (must pass before anything moves):** add
`"sunholo/motoko_core" = { path = "../../src/core" }` to a skeleton
`packages/motoko-ext-compaction-structural/ailang.toml`, add `"src/core/compaction"` to
`src/core/ailang.toml [exports] modules`, and `ailang check` a one-line module importing
`pkg/sunholo/motoko_core/core/compaction (estimate_tokens_messages)`. This dependency shape
is **unproven** (no `packages/` package depends on `motoko_core` today — survey). If the
probe fails: fallback is an in-package copy of the two measurement primitives with a pure
parity test against core's (the D9 anti-duplication tension recorded and flagged to the
ABI-v3 track), and the probe result goes in "ADR gaps found" either way.

**7b — the package** (`packages/motoko-ext-compaction-structural/`, name
`sunholo/motoko_ext_compaction_structural`, version **1.0.0** per the ADR's ABI-track
naming, dep `"sunholo/motoko_ext_abi" = "2.2.0"`, `[effects] max` mirroring the ABI hook
row (scratchpad precedent) — the hook *bodies* are pure and subsume into the declared rows,
fact 2):
- `compaction_structural.ail` — the relocated ladder: `elide_content`, `elide_walk`,
  `elide_old_tool_results`, `count_tool_msgs`, both emergency tiers, and the tier selection
  from `compact_step_with_limit` (`compaction.ail:78-154`), rewritten over `[Msg]` (the
  hook's type; structurally identical fields) with the limit taken from
  `ctx.context_limit` (the WI-5 effective limit); returns `PassThrough` below
  `elide_tier_pct()` **or whenever elision changed nothing** (D-B5 — e.g. all tool
  messages inside the keep-last window, today's silent no-op), else
  `Compacted(elided, "structural: tier=<t> keep_last=<k>")` — best effort at ≥95%, no
  error arm. The **seven named constants** relocate here as exports.
- `register.ail` — `register_with_config` (scratchpad precedent,
  `packages/motoko_scratchpad/register.ail`).
- In-package pure tests: the relocated `compaction.ail` ladder tests plus
  `single_tier_ladder_selects_correctly` (the ADR's Phase C note relocates that scenario
  with the ladder — landing it now as a package test costs nothing).

**7c — registration, last**: root `ailang.toml` `[dependencies]` path-dep +
`[extensions].packages` entry; `ailang generate-extension-registry` regenerates
`registry_generated.ail`; append `"compaction_structural"` **last** to
`.extensions.order` in all four profiles (`default`, `dogfood`, `local`, `openrouter`) —
registered-last is the D9 semantics (specialized compactors first, elision as universal
fallback); `make sync_packages` + `ailang lock`; `check_core`'s `verify_extensions`
boot-probes it.

**7d — core retirement**: delete from `compaction.ail` the relocated ladder machinery and
the G3c wrappers (`compact_step`, `usage_percent`, `try_emergency_compaction` — all
model-keyed, dead per fact 19), keeping `estimate_tokens_messages`,
`usage_percent_with_limit`, and the new `exhaustion_pct()`; delete `context_limit_for` from
`context_usage.ail` and inline its `0` fallback into `catalog_context_limit_for`'s arms
(`:70-79`); `agent_loop_v2.ail:1059` region becomes the post-chain exhaustion check (D-B5);
`compact_step_with_limit` import (`:58`) dropped.

**7e — dependent tests/smokes** (blast radius from the survey):
- `compaction.ail` inline tests: model-keyed cases rewritten to `_with_limit` /
  measurement-only; ladder cases move to the package (7b).
- `integration_tests.ail:27-45` `test_compaction_fires_above_70pct`: retargeted at the
  package's ladder entry (or, if the 7a probe forced the fallback, at the package via a
  script-level test — `ailang test` targets the file it is given).
- `scripts/smoke_v2_compaction_tiers.ail`: imports retargeted to the package module; its
  ✓/✗ stdout (`tiers.txt` in the harness) must be byte-identical — the ladder logic is a
  move, not a rewrite.
- `scripts/smoke_v2_compaction.ail`: rewritten to the `_with_limit` measurement surface
  (removes its dead model-keyed calls — one more G8 script off the broken list, since it
  currently type-checks but tests a vestigial path).
- `scripts/smoke_v2_compaction_full_loop.ail`: registers the structural package's hooks in
  its `rt` (imports `pkg/sunholo/motoko_ext_compaction_structural/...`; replaces
  `empty_rt()` for the tier cases) so it exercises the relocated ladder through the chain
  — the e2e evidence for behavior preservation. **Grounding caveat that shapes the
  expected diffs**: its histories are `[user, tool×1]` (`mk_history`, verified this
  session), and a single tool message sits inside *every* keep-last window (10/5/3/1) —
  today's elision changes nothing at any tier, so under D-B5's PassThrough-when-unchanged
  the relocated ladder emits **no** `compaction_extension` for the existing cases either.
  The exhaustion case (385 chars ≈ 96%) Errs today because emergency elision cannot touch
  the lone kept tool message — same decision post-relocation via core's exhaustion check.
  To get a *positive* elision case into parity coverage, the smoke gains a **new case 5**:
  a multi-tool-message history (e.g. 12 tool messages, ~80% usage) where tier-1 elision
  genuinely rewrites — asserting `Ok` plus, in the harness, a `compaction_extension` line
  with a `structural:` note.

**Expected diffs (the WI-7 table; re-bless per D-B7):** in
`smoke_v2_compaction_full_loop.jsonl` only — (1) the exhaustion case's
`compaction_exhausted.reason`, the `error` copy, and `run_summary.error` change bytes to
the "after compactor chain" wording with the post-chain percentage (D-B5); (2) the **new
case 5** appends its event block (including the first `compaction_extension` with a
`structural:` note — a new occurrence of a [prod] name with unchanged layout, from a new
test case). Every other smoke: byte-identical.

- **Files touched:** the new package (3+ files), root `ailang.toml`, `ailang.lock`,
  `src/core/ailang.toml`, `src/core/ext/registry_generated.ail` (regenerated), 4×
  `.motoko/config/*/config.json`, `src/core/compaction.ail`, `src/core/context_usage.ail`,
  `src/core/agent_loop_v2.ail`, `src/core/test/integration_tests.ail`, 3 compaction smokes,
  `scripts/sync-extension-packages.sh` only if 7a shows the import-rewrite list needs the
  compaction module added.
- **Verification:** WI-2 command set + `ailang check`/`ailang test` on the package files +
  `ailang verify src/core/compaction.ail` (the `elide_old_tool_results` contract moves with
  it — `ailang verify` the package file instead) + `make sync_packages` idempotent +
  `make build` (registry + TUI still assemble) + parity diff == the WI-7 table exactly +
  `tiers.txt` byte-identical + negative greps: `grep -rn 'compact_step\|usage_percent('
  src/core --include=*.ail` hits only `_with_limit` forms; `grep -n context_limit_for
  src/core/context_usage.ail` hits nothing.
- **Rollback:** revert the commit set (7b–7e are one logical relocation and revert
  together; in particular **7c and 7d land in the same commit** — registering the ladder
  extension while the core shim still runs would elide twice per step; 7a's export-list
  line is harmless standalone). Baseline re-bless recorded.

### WI-8 — Gate checklist (final; all must pass on the finished branch)

```
ailang --version                                    # v0.26.0 / 3b52a24 (else STOP)
make check_core && make test_core && make test_integration
ailang test src/core/phase_vocab.ail                # golden byte tests green
ailang test src/core/ext/runtime.ail                # chain tests green
ailang test packages/motoko-ext-compaction-structural/compaction_structural.ail
ailang check scripts/probe_phase_vocab_sealed.ail   # MUST FAIL IMP010 (sealing holds)
(cd src/tui && npm test)                            # incl. unknown-type tolerance test
bash scripts/setup_dp7_smoke_workdirs.sh
PARITY_BASELINE=/tmp/phase_b_blessed make smoke_parity     # STRICT byte diff (D-B7:
                                                           # blessed baselines include the
                                                           # [NEW] lines; strip mode was
                                                           # transient, WI-4/WI-6 only)
./scripts/phase_b_projection_gate.sh                # see below
```

`scripts/phase_b_projection_gate.sh` (new, small): extracts every `"type":"…"` value from
the harness output dirs (main + `.new.jsonl` side files), sorts unique, and asserts each is
either in `scripts/phase_b_inventory_baseline.txt` (the frozen pre-B 29) or in the admitted
[NEW] pair — the mechanical form of "emitted type set for [prod] is a subset of the
regenerated inventory; [NEW] admitted additively". The byte-compatibility half of the gate
is carried by WI-1's golden tests + the parity diffs; the streaming gate by the
stream-parity smoke; `system_messages_hidden_from_compactors` by the fixture smoke's
`sys=0` assertion (WI-5).

Negative checks: `grep -c "emit_event(" src/core/agent_loop_v2.ail` = 0;
`grep -c "emit_json(" src/core/agent_loop_v2.ail` = 2 (def + `ledger_emit`);
no diff under `src/tui/` beyond the WI-0 test file; `ailang.lock` consistent
(`make sync_packages` idempotent).

---

## ADR gaps found

Per the handoff: discrepancies between the committed documents and post-Phase-A HEAD, found
while producing this plan. None blocks Phase B; each has a plan-level resolution above.

- **G-B1 — "each stage ledger-recorded" (D9) collides with the closed [NEW] whitelist.**
  §7.5 and Decision detail 4 say every chain stage is ledger-recorded, but the normative
  [NEW] name set (ADR D5 bullet) admits only four names, none of which can carry a
  `PassThrough` stage record, and Phase B has no in-memory ledger — events *are* the JSONL.
  Resolution here: applied stages → `compaction_extension` [prod], rejected stages →
  `ext_compaction_rejected` [NEW], pass-through stages **unrecorded on the wire** (they
  remain reconstructible: registry order is pipeline order). Full per-stage records need
  either Phase C's in-memory ledger or a newly admitted name — ADR's call.
- **G-B2 — the as-built projection is not yet byte-compatible for [prod] arms.** Expected
  for a sketch-seeded scaffold, but the ADR reads as if `to_schema_v1` were
  shape-complete; the mismatch list (grounding item 2, incl. the `text`-vs-`text_delta`
  stream field) is exactly the WI-1 work. No doc change strictly required; noted so the
  next reader does not mistake the scaffold for the contract.
- **G-B3 — "behavior-preserving relocation" is result-level, not byte-level.** Three
  residues the ADR does not mention: (1) core elision is silent today, so the relocated
  ladder's genuinely-applied stages add `compaction_extension` occurrences (type-set subset
  holds — the gate's wording — but the handoff's "none for [prod]" summary reads stricter
  than the ADR gate); (2) the exhaustion `reason` string changes wording/percentage
  (D-B5); (3) compactors now measure the **segment** — with the WI-5 effective-limit
  compensation, a tier `t` fires at total usage `t + s(1−t)` where `s` is the pinned
  prefix's share of the limit, i.e. slightly later than today when a large system prompt
  is in play (exact at `s=0`, which covers every parity smoke), and in the narrow band
  this opens, exhaustion can fire where today's emergency keep-last-3/1 would have
  recovered. Designed, bounded (by `s`·5% of the limit at the 95 threshold), and confined
  to large-prefix sessions; recorded here for the ADR's attention rather than silently
  shipped.
- **G-B4 — G7's fixture wording under-covers the envelope path.** The ADR names "scripted
  `Handled` + `ContinueWithFeedback`", but `envelope_to_tool_message`'s only call site is
  the `InterceptHandled` path (`agent_loop_v2.ail:1185`); a fixture without an intercept
  hook cannot e2e-cover it. The fixture adds `InterceptHandled` (D-B10).
- **G-B5 — system messages remain visible to extensions via `ExtCtx.history_slice`**
  (`agent_loop_v2.ail:437`) after deliverable 4 closes the `dispatch_pre_step` input path.
  Read-only visibility, not the §7.0 corruption exploit (the re-pin makes prefix loss
  impossible regardless of compactor output), but "extension `on_pre_step` never receives
  system messages" (DST ADR-001 invariant) is satisfied only for the compaction argument,
  not the ctx. Candidate for the ABI v3 design.
- **G-B6 — emission-surface accounting.** The 48-site figure counts definitions
  (38+6+1+3 call sites — grounding item 4), and two emission surfaces exist outside
  `agent_loop_v2.ail` that the 29-name inventory and Phase B deliverable 1 do not cover:
  `rpc.ail:235-239` emits a raw `v2_mode` event (no envelope), and `src/core/ai_compat.ail`
  emits call-stream events. Both untouched by Phase B; the ADR may want the inventory's
  scope ("the loop's wire stream") stated explicitly.
- **G-B7 — the `motoko_core`-dependency shape for bundled extensions is unproven substrate.**
  D9 requires the structural package to import core's measurement primitives rather than
  duplicate them, but no `packages/` package depends on `sunholo/motoko_core`, and
  `src/core/ailang.toml` exports only four modules. WI-7a probes it before relying on it;
  outcome to be recorded here either way.

---

## Toolchain and artifacts verified this session

| Check | Command | Result |
|---|---|---|
| Toolchain pin | `ailang --version` | v0.26.0 / `3b52a24`, built 2026-07-02 — matches the pin |
| Vocabulary tests | `ailang test src/core/phase_vocab.ail` | 12 pass / 0 fail |
| Sealing | `ailang check scripts/probe_phase_vocab_sealed.ail` | rc=1, `IMP010: 'MkHistory' not exported` (as required) |
| Parity instrument | `make smoke_parity` (self-diff mode) | green — two runs byte-identical, 7 JSONL captures + `tiers.txt` |
| Inventory | regeneration command from `phase_vocab.ail:251-263` | **29** names, matches the module's comment block exactly |
| Script fleet | `ailang check` per file, no pipes | **11 fail** at HEAD: `smoke_v2_compaction_ai`, `smoke_v2_compaction_ai_registry`, `smoke_v2_conversation`, `smoke_v2_factual`, `smoke_v2_intercept`, `smoke_v2_pending`, `smoke_v2_policy`, `smoke_v2_policy_denial`, `smoke_v2_tool_build`, `smoke_v2_tool_read`, `smoke_v2_tool_write` (= G8's 13 minus the two WI-0 repairs; Phase B resolves the two compaction-AI ones by replacement) |
| Emission counts | `grep -c` + full site enumeration | 39/7/2/4 grep hits = 38+6+1+3 call sites + defs (grounding item 4) |
| `test/tiny` limit | `jq '.context_limits["test/tiny"]' .motoko/model-catalog.json` | 100 |

## Anchor re-verification log (HEAD `d0d5b7e`, 2026-07-03)

Source anchors read (not inherited) this session — the load-bearing set:
`agent_loop_v2.ail` (1702 lines): `emit_json` `:106`, trace gate `:110-159`,
`schema_version` `:169`, `emit_event` `:204-211`, `emit_stream_chunk` `:250-274` (delta
types `:256,:266`), `derive_session_id` `:280-284`, `per_step_usage_kvs` `:295-307`,
`emit_run_summary` `:325-360`, `mk_v2_ext_ctx` `:414-441` (`history_slice` `:437`),
`messages_to_msgs` `:448-458`, tool-dispatch family `:648-849` (approval read `:676`;
`handled_tool_message` `:729,:788,:802`; `tool_result_message` `:758,:849`), dp7 `:928`,
budget/cost gates `:1015-1035`, pre-step + compaction region `:1037-1073`, stream region
`:1074-1135` (`on_chunk` `:1089`, `dispatch_step` `:1090`), `step_result_to_message`
`:1137`, cost warnings `:1150-1163`, intercept `:1178-1187`, solver/finalize family
`:1249-1319`, native tool batch events `:1336-1348`, `run_v2` entry `:1398`,
conversation-loop events `:1495-1541`, `run_v2_with_conversation` `:1564`,
`run_v2_with_stub` `:1581-1607`.
`ext/runtime.ail`: `first_compacted`/`dispatch_pre_step` `:143-166`, test_dummy
instrumentation `:98-110,:149-155`, inline dispatch tests `:382-474`.
`compaction.ail` (248 lines): exports `:34,:42,:47`, seven constants `:51-63`, ladder
machinery `:78-154` (exhaustion message `:135`), inline tests `:161-248`.
`context_usage.ail`: `estimate_tokens` `:12`, `context_limit_for` `:27-40`,
`catalog_context_limit_for` `:68-83`.
`phase_vocab.ail` (542 lines): sealed types `:23,:66-67`, `project` scaffold `:91-105`,
checkpoint `:113-131`, `StepState`/deltas `:152-210`, decision/phase types `:216-246`,
inventory block `:251-263`, `LedgerEvent` `:279-292`, `to_schema_v1` `:293-308`, builders
`:319-418`, inline tests `:424-542`.
`rpc.ail`: system message into `init` `:230-233`, raw `v2_mode` emit `:235-239`.
`stub_step.ail`: `ScriptedStep` `:32`, `dispatch_step` `:110-138` (Scripted ignores
`on_chunk` `:121-135`), fixtures `:142-196`.
TUI: `runtime-process.ts:103-115`; `index.ts:468,:612-613`; `ui.ts:2291`;
`session-logger.ts:272,:343-345,:348-350`; no exhaustiveness guards (grep).
Build surface: `Makefile` `:15,:42-51,:59,:117,:125,:137,:144`; harness
`phase_a_event_parity.sh` (64 lines, normalization `:30`, assertion block `:44-48`);
root `ailang.toml` (path-dep + `[extensions]` blocks); `src/core/ailang.toml` `[exports]`;
`packages/motoko-ext-context-mode/ailang.toml` + `packages/motoko_scratchpad/*`
(manifest/register precedent); `sync-extension-packages.sh` (import-rewrite list `:31-39`,
toml rewrites `:44-49`, `main` `:97-105`); four profile configs' `.extensions.order`;
ABI cache `sunholo/motoko_ext_abi/2.2.0/types.ail` (`PreStepDecision` `:124-127`,
`ExtensionHooks` rows `:128-142`).
Line numbers are exact as of this read; **re-grep before editing**.
