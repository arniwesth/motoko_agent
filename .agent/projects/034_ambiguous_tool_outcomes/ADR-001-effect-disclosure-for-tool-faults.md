# ADR-001: Effect disclosure for tool faults whose effect may have happened

Date: 2026-10-02. Status: **Proposed — the operator has ruled on nothing below; nothing is
executed.** Grounded at HEAD `4023bf08` on `main`, installed AILANG v0.47.2. The local `ailang/`
checkout is `v0.33.1-87`; anything cited from its Go source is a claim about that checkout, not
about the installed binary, and is marked "(checkout)".

Asked for by `NOTE-scope-effect-unknown-tool-faults.md` §5 item 4 (this folder). The note's
analysis and its probe table (§6.1, `evidence/exec_probe.sh`) are the evidence and are not restated.
Every coordinate below was re-checked at `4023bf08`. §5 lists where the note did not hold.

## TL;DR

- **Problem.** When the harness reports a tool fault, the model cannot tell "the tool never
  started" from "it ran, and its effect may have landed". Today that difference is untyped prose in
  `stderr`, which no property can check.
- **Decision.** Every harness-reported fault carries a `fault` object whose `effects` is `none`
  (the effect was never entered) or `unknown` (it was entered and the harness holds no completion
  to report). The value comes from what the harness observed, never from what the world did, so
  there is no `applied` value. (D1, D3)
- **Mapping.** `none` only where the fault is observed before the effect is entered; everything
  else is `unknown`. Against the note, `SpawnFailed` and `PermissionDenied` are `unknown`: case A
  (§0) is a command that exited 0 with its work done and was reported as a spawn failure. (D2)
- **Deterministic world.** "The update applied and the call still faulted" becomes two world-only
  catalogue rows that can never appear in a model message. P1–P3 check that `none` is sound, that
  `applied` leaks nothing, and that no call id is dispatched twice. (D4, §2)
- **Order.** Phase 0 (the mapping and the object in the live renderer) ships alone and first, and
  moves the eval baselines. The upstream asks are filed in parallel; the deadline wrapper
  (Phase 0b) and the DST work (Phases 1–3) follow. (D5–D8, §4)
- **Status.** Proposed. Nothing is ruled and nothing is executed; §6 lists the seven rulings asked
  of the operator.

## 0. The decision in brief

A tool result in which the harness reports a fault tells the model one of two things about the
tool's effect: it never started (`none`), or it started and the harness cannot say what happened
(`unknown`). The value is computed from what the harness observed and from nothing else. The
deterministic world gains the case the harness cannot see — the update applied and the call still
faulted — as catalogue rows that can never be shown to the model. Three properties (§2) check that
the disclosure is sound, that it leaks nothing, and that the driver never dispatches a call twice.

One measurement was added for this record, because the note's mapping rests on it. It uses the
note's probe harness (the same AILANG program calling `std/process.exec` directly, v0.47.2) with
four new argument lists, run in a scratch directory. Like the note's probe, it does not go through
`run_process_result` and does not read the message the model gets. (Added after delivery,
2026-10-02: cases A–D are now cases 8 and 10–12 of `evidence/exec_probe.sh` and reproduced there.
Its case 9 is case A with the background child detached from the pipe; that returns `Ok`, exit 0.)

| # | `exec(...)` arguments | `exec` returned | Effect |
|---|---|---|---|
| A | `"bash", ["-lc", "echo DONE; touch m_fg; (sleep 9; touch m_bg) & exit 0"]`, wall 20 s | `Err(SpawnFailed("exec: WaitDelay expired before I/O complete"))` after about 5 s | `m_fg` **present** at return. `m_bg` absent at return, present when checked later. The command exited 0. |
| B | `"definitely-not-a-command-034", []` | `Err(NotFound(...))` | nothing ran |
| C | `"./noexec.sh", []` (mode 644) | `Err(NotFound(./noexec.sh))` | its marker absent |
| D | `"bash", ["-lc", "touch m_sig; kill -9 $$"]` | `Err(AbnormalExit(9, killed))` | `m_sig` **present** |

Case A is a command that succeeded and is reported as a spawn failure. It needs no fault and no
long output, only a command that leaves a background child holding the output pipe.

## 1. Decisions

| Note item | Here | Proposed |
|---|---|---|
| §5.1 ship Phase 0 on its own | D5 | adopted |
| §5.2 new `ToolOutcome` variant, or a field | D3 | field adopted, narrowed to `ToolFailed` |
| §5.3 batch Phase 1 with the knob widening | D8 | adopted with a condition |
| §5.4 ADR; no reopen of 009 D3 | D9 | adopted; checked |
| §6.5.5 `OutputLimitExceeded` → `unknown` | D2 | adopted |
| §6.5.6 deadline wrapper is a Phase 0b | D6 | adopted |
| §6.5.7 file the upstream asks | D7 | adopted, two asks added |
| §3 Phase 0 arm lists | D2 | **amended**: `SpawnFailed`, `PermissionDenied` → `unknown` |
| §3 Phase 1, one world-only row | D4 | **amended**: two rows |

### D1. The disclosure has two values, both derived from the observation

- `none` — the harness did not enter the tool's effect. No write, exec or update was started.
- `unknown` — the effect was entered and the harness holds no completion it can report. It may have
  happened, may not have, or may still land after the result (note §6.1 case 3; case A above).

A call that ran to its own exit carries no disclosure. Its result is the tool's own report.

Alternatives, and why they lose:

- **A third value (`applied`, or `likely applied`).** The harness cannot know the world's bit. Any
  rendering that tracks it fails P2 by construction. The note's "extra 5 s" signal (§6.2) is two data
  points and is not rendered.
- **Prose in `stderr` only (today).** `process_error_to_string` (`src/core/tool_runtime.ail:920–930`)
  is the only thing that differs between "never started" and "ran". It is untyped, so no property
  can check it.
- **An exit-code convention.** Exit codes belong to the command (124 is a legal exit, note §6.3), and
  `-1` already means "no subprocess, or a seam that cannot say" (`src/core/ports.ail:645–646`).

### D2. Mapping: `none` only where the effect was provably not entered

Rule: a site renders `none` only if the fault is observed before the effect is entered. For a
`ProcessError` arm that additionally requires a probe on the pinned binary showing the arm returned
with no child process having existed. Everything else is `unknown`, which is always sound (P1 is
one-sided).

| Observation | Coordinates | Value |
|---|---|---|
| Arguments not valid JSON | `src/core/tool_phase.ail:347–355` (already says "the tool was NOT run") | `none` |
| Policy denial | `src/core/tool_phase.ail:569–579` | `none` |
| Validation refusal: path guard, missing argument, unknown tool, `expected_sha256` mismatch, edits that do not apply, delegated-backend refusal | `tool_runtime.ail:443–480`, `:590`, `:870–880`, `:248`, `:986–987` | `none` |
| Any failure of `ReadFile` or `Search` | `tool_runtime.ail:520–529`, `:594–596` | `none` (no update to apply) |
| `WriteFile` after `mkdirAllResult` or `writeFileResult` was called; `EditFile` after `atomic_write` | `tool_runtime.ail:700–703`, `:898–899` | `unknown` |
| `NotFound` | cases B, C | `none` |
| `NotAllowed` | returned before spawn at `ailang/internal/effects/process.go:104` (checkout); unmeasured on v0.47.2 | `none` once a probe row shows it; `unknown` until then |
| `PermissionDenied` | classified by substring from the error of a call that both starts and waits, `process.go:200` (checkout); not produced by case C | `unknown` until upstream states it is start-only (D7) |
| `SpawnFailed` | case A | `unknown` |
| `Timeout`, `OutputLimitExceeded`, `AbnormalExit` | note §6.1 cases 2–4; case D | `unknown` |
| `Ok`, any exit code | `tool_runtime.ail:1020–1022` | no disclosure |

This departs from the note in two arms. The note lists `SpawnFailed` and `PermissionDenied` as
"never started". Case A shows `SpawnFailed` returned for a command that exited 0 with its work done,
so rendering it `none` would be the exact unsoundness P1 exists to catch, shipped in Phase 0. By
reading `tool_runtime.ail:927` and `:1012–1019` (not by running them), the model is told
`exit_code: 1`, `stdout: ""`, `spawn failed: exec: WaitDelay expired before I/O complete`.

`ToolErrorResult` cannot carry one value per variant: the same constructor is built before the
effect (`:870`) and after it was attempted (`:703`). The value is stated at each construction site.

### D3. Where it lives, and how the model reads it

**Typed layer.** `src/core/types.ail` gains a two-arm sum for the disclosure and a small fault
record (observation kind, disclosure, that kind's numbers). `ToolErrorResult` (`types.ail:173–177`)
gains it as a required field; `BashExecResult` and `RunTestsResult` (`:154–172`) gain it as absent
on the `Ok` arm. A required record field breaks every literal until it states a value, so the 13
`ToolErrorResult` and 4 process-result construction sites under `src/`, `packages/` and `scripts/`
are each forced to choose. That is the exhaustiveness the note wanted from a new variant, obtained
where the value is decided. These are `ToolResultItem` arms, not extension-ABI records.

**`ToolOutcome` (note §5.2).** `ToolFailed` (`ports.ail:649`) gains a dispatch stage, before or
after, which is an observation; the renderer derives the disclosure from it. `ToolDeadlineExceeded`
and `ToolCorrelationMismatch` gain nothing: a deadline is measured from dispatch and a mismatch
answers a dispatched call, so both are `unknown` by construction. A field there would make `none`
representable where it is always wrong (the argument `ports.ail:634–643` already makes for
`exit_code`). The note proposed the field on `ToolDeadlineExceeded` too, and did not say what a
mismatch discloses. A new variant loses: the observation variants do not change, and a variant
named for applied-ness is the leak D4 forbids.

**Wire.** One JSON object under one key, `fault`, in both renderers that reach the model for native
tools: `tool_result_item_to_json` (`src/core/tool_dispatch_adapter.ail:95–160`, the live path) and
`tool_fault_message` (`tool_phase.ail:297–304`, the typed-fault path).

```json
{"tool":"BashExec","cmd":"make build","exit_code":1,
 "fault":{"kind":"output_limit","effects":"unknown","note":"<fixed sentence for unknown>"},
 "stdout":"","stderr":"output limit exceeded: 1000 bytes","truncated":false}
```

- `effects` is `"none"` or `"unknown"`. The key name, the two values and one fixed sentence per
  value come from one constants home, as the `fault_class_*` names do
  (`src/core/dst_fault_catalogue.ail:61–63`). The sentence exists because the precedent that works is
  prose (`tool_phase.ail:353`); its wording is settled by the plan with the eval pass.
- `kind` names the observation (deadline, output limit, signal, not started, refused), never the
  world's truth.
- `fault` is emitted before `stdout` and `stderr`. Tool messages are cut from the front at 65,536
  bytes (`src/core/phase_vocab.ail:1559–1568`), and Phase 0b makes large faulted results possible.
- `exit_code` stays `1` on a harness-reported fault. `tool_result_exit_code`
  (`tool_dispatch_adapter.ail:72–82`) feeds typed consumers; changing it is not this decision.
- `BashExec`'s description (`src/core/tool_catalog.ail:54`) promises truncation past the cap. It is
  corrected in the same change, so the baseline moves once.

**One shape with 030: yes.** 030 §8.4 item 1's diagnostics are this object with more kinds. 030
places them "in `metadata`", which is `ToolResultEnvelope.metadata`, the path for extension-handled
tools (`handled_tool_message`, `phase_vocab.ail:1629`). Native results do not pass through it. So
the shared thing is the object, not the field it hangs from: top-level in the native result now,
under `metadata` when 030's candidate reaches extension-handled tools (no ABI change, 030 §8.2 row 2).

**Rejected for Phase 0: reclassifying live faults.** `live_tool_outcome` (`ports.ail:1759–1762`)
keeps returning `ToolCompleted`. Turning a live `Timeout` into `ToolDeadlineExceeded` would change
`fault_class` on the wire and the typed exit code for every consumer. Consequence: P1 checks the
typed-fault renderer, not the live one, so Phase 0 has its own acceptance (§2).

### D4. The "applied, then faulted" class never reaches the wire

Tool class ids are wire names (`dst_fault_catalogue.ail:22–35`; `tool_phase.ail:277–304`). A class
that says the update happened must be invisible to the model, or the harness would be telling it
the world's truth.

- **Two world-only rows, not one.** `FaultClass` has one `delivery_constructor` and one
  `recovery_branch` (`dst_fault_catalogue.ail:234–241`), so the note's single row "delivered as
  `ToolFailed` or `ToolDeadlineExceeded`" does not fit. Proposed: `tool_effect_applied_then_failed`
  and `tool_effect_applied_then_deadline`, each naming its wire twin and copying the twin's
  constructor and branch. Catalogue `fault-catalogue/2` → `/3` (`:55`), eleven rows → thirteen
  (`:795`). List-valued fields on one row lose: they change the row shape for all eleven classes.
- **A visibility field on every row**: wire name, or world-only with a twin id. `validate_catalogue`
  (`:565–570`) rejects a world-only row whose twin is missing, is itself world-only, or differs in
  constructor or branch.
- **No carrier.** `applied` lives on `ScriptedTool` (`ports.ail:599–606`) and in a `WorldState`
  effect log. `ToolOutcome` gains nothing that carries it; `scripted_tool_outcome`
  (`ports.ail:1775–1788`) stays a function of the observation fields. The driver does hold
  `next_state` (`ports.ail:653–656`), so the types do not prevent a read. P2 is what does.
- **Lexical guard**: no projected tool message contains a world-only class id.
- **Existing rows are not edited.** Changing `ToolFailed`'s transition (`:346`) in place is the
  silent reinterpretation 009 D8 forbids (009 `ADR-001`:2311–2312).
- A program with `applied` set on a before-dispatch fault is rejected at validation.

### D5. Phase 0 ships on its own, first (note §5.1)

Adopted. It is the only part that changes a live session, it needs no DST machinery, and the fault
needs no injection (note §6.1 case 4; case A). Waiting for P1 loses: P1 does not check the live
renderer (D3). Cost: every faulted tool message changes shape, which moves the prompt-sensitive eval
baselines. They are measured before and after, once, together with 030's diagnostics.

### D6. The deadline wrapper is Phase 0b (note §6.5.6)

Adopted. Phase 0 renders observations that already exist; the wrapper changes the observation
(`Ok`/124 where there was `Err(Timeout)`). Its open points are the note's (§6.3). One more: case A
has no deadline, so the wrapper is not expected to help it. That is untested.

### D7. File the upstream asks (note §6.5.7)

Adopted, four asks: (a) partial stdout and stderr on `Timeout` and `OutputLimitExceeded`; (b) a kill
that reaches the process group; (c) a clean exit whose pipe outlives it returns `Ok` with the exit
code and output, not `SpawnFailed` (case A); (d) a statement of which `ProcessError` arms are
returned only before the child exists. Filing is outward-facing and waits for the ruling.

### D8. Batch Phase 1 with the knob widening (note §5.3), conditionally

Adopted if the widening is scheduled. Both bump `generator_version`, re-pin the canary by hand and
re-derive the PR bank. But 013's note also says the widening should land after its seed-space
question (`013_core_architecture_for_dst/NOTE-fdb-simulation-cross-check-2026-09-08.md:101–108`), so
an unconditional batch puts Phase 1 behind that. If the widening has no date when Phase 1 is
planned, Phase 1 goes alone. Phases 0 and 0b are not affected.

The note's `execution-program/4` → `/5` is not available as written: `/5` is claimed by 031
`PLAN-001` P2.1 (`031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md:434`), unlanded at
HEAD (`src/core/dst_program.ail:132` is `/4`). Read it as "the next program schema version".

### D9. No reopen of 009 ADR-001 D3 (note §5.4)

Checked; it holds. D3 already requires both halves — "whether the all-or-nothing logical update
occurred … whether work completed before or after the observation" (009 `ADR-001`:832–836) — and
lets the catalogue grow without a new ADR while the boundary is preserved (`:878–879`). `applied`
is one all-or-nothing bit, so the physical-fault exclusion stands (`:879–884`). The deadline twin
uses the same derived deadline (`:870–873`).

One clause needs a stated reading: "a decorative fault variant that cannot influence the production
session does not satisfy this decision" (`:820–822`). The twin rows are delivered through a real
constructor to a real branch, so by the artifact's own test they influence the session. What they
cannot do is influence it differently from their twin, and that is the property under test.

## 2. Acceptance

**Phase 0 (live path).** P1–P3 do not cover it.

- The `ProcessError` → disclosure mapping is one pure function with an exhaustive match and a test
  row per arm, so a new upstream arm is a compile error and not a default.
- A live witness through `run_process_result`, reading the rendered message, for one `unknown` arm
  and one `none` arm. Neither probe does this. Precedent: `ports.ail:1741–1743`.
- A probe row on the pinned binary for every arm rendered `none`.
- Eval baselines recorded before and after.

**P1–P3 (deterministic world, Phase 2).** A property is accepted only when its mutation fixture
has been seen red.

| | Property | Oracle reads | Mutation fixture |
|---|---|---|---|
| **P1** | `effects = none` ⇒ the world did not apply the update; and every harness-reported fault message carries `effects`. One-sided: `unknown` is always permitted after dispatch. | The world's interaction log and effect log against the ledger's projected message. Never `tool_outcome_message` or anything it calls. | Render `none` for an after-dispatch `ToolFailed`; and drop the key. |
| **P2** | Two programs differing only in one `applied` field produce identical traces, outcomes and served interactions. | A pair relation beside `discovery_contract_findings` (`src/core/dst_invariants.ail:2154–2168`); not a family, for the reason at `:2078–2081`. | Read `applied` from `next_state` into the message. |
| **P3** | The driver dispatches no tool call id twice. | The world-served interaction log, as `DeniedCallDispatched` does (`dst_invariants.ail:395`, `:1429–1441`). | A retry-on-deadline in the driver. |

P1 and P3 are findings under `ToolPairing` (`dst_invariants.ail:232`). P3 holds trivially today —
no retry path exists in `tool_phase`, `tool_stream_phase`, `tool_envelope_dispatch` or
`tool_dispatch_adapter` — so its fixture is its only evidence. Duplicate effect keys from the model
(new call id, same effect) are a run-report metric, not a verdict.

## 3. Out of scope

From note §4, unchanged: measuring model honesty (Havoc's question); torn or partial effects; the
extension effect seam (`src/core/session.ail:1299`, `timeout_ms` 0); delegation (`WakeOutcome`,
`ports.ail:788`); harness-side resolution such as read-back or idempotency keys. Added here:
reclassifying live faults into typed fault variants (D3); changing `exit_code` on a faulted result;
extension-handled tools' `metadata` (030's candidate).

## 4. What a plan would sequence

1. **Phase 0** — the D2 mapping, the D3 object in the live renderer, the description fix, Phase 0
   acceptance. Independent of everything below.
2. **Upstream filing** (D7), in parallel.
3. **Phase 0b** — the wrapper, with its own probe through `run_process_result` and its own baseline
   pass.
4. **Phase 1** — `ScriptedTool` gains `applied` and a stage; next program schema version, with the
   legacy default stated (recommended: after dispatch, not applied); `WorldState` effect log;
   catalogue `/3` (D4); `choose_tool` (`src/core/dst_generator.ail:740`) draws `applied` under its
   own salt; `generator_version` bump, canary re-pin by hand, PR bank re-derived; all four profile
   versions move. Batched per D8, numbered against 031 P2.1.
5. **Phase 2** — P1–P3 and their fixtures (§2).
6. **Phase 3** — class and branch counters pick the rows up from `required_class_ids()`
   (`dst_fault_catalogue.ail:254`); the duplicate-effect-key metric.

## 5. Where the note did not hold

| Note says | At `4023bf08` |
|---|---|
| `SpawnFailed`, `PermissionDenied` → `none` (§3) | `SpawnFailed` is returned for a command that exited 0 (case A). `PermissionDenied` is unestablished. D2. |
| One world-only row with two delivery constructors (§3) | `FaultClass` has one of each. D4. |
| `execution-program/4` → `/5` (§3) | `/5` is claimed by 031 P2.1. D8. |
| Pre-dispatch refusals "should" render `none` (§3) | True of refusals, but `ToolErrorResult` is also built after a write was attempted. D2. |
| P1 covers the disclosure (§1) | It covers `tool_outcome_message`. The live result is rendered by `tool_result_item_to_json`. D3, §2. |
| Batch with the knob widening (§5.3) | 013 §3.1 orders the widening after its §3.5. D8. |
| `DeniedCallDispatched` at `dst_invariants.ail:1396`; determinism relation "~2075"; `ports.ail:1775–1789` | `:1396` is a comment, the check is `:1429–1441`; the relation is `:2154–2168`; the function ends at `:1788`. |

Not established anywhere, and needed: whether `NotAllowed` and `PermissionDenied` can be returned
on v0.47.2 after the child exists; what the wrapper does in case A; the wording of the two sentences.

## Related records

- `NOTE-scope-effect-unknown-tool-faults.md`, `evidence/exec_probe.sh` — scope and probes
- `mmd/README.md` — diagrams of this ADR: `mmd/effect-disclosure-decisions.svg` (the decisions by
  phase), `mmd/effect-disclosure-mapping.svg` (D1–D3, the live path),
  `mmd/effect-disclosure-world.svg` (D4 and §2, the deterministic world)
- `009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` D3, D8 — governing
- `030_harness_playbook/RESEARCH-harness-playbook-implications.md` §8 — the diagnostics candidate
- `013_core_architecture_for_dst/NOTE-fdb-simulation-cross-check-2026-09-08.md` §3.1 — the knob batch
- `031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md` P2.1 — the other claim on `/5`

## 6. For the operator to rule on

1. **D2**: `SpawnFailed` and `PermissionDenied` render `unknown`, against the note.
2. **D3**: the wire shape — a `fault` object with `effects` and a fixed sentence, shared with 030 —
   and that Phase 0 leaves live faults as `ToolCompleted`.
3. **D4**: two world-only catalogue rows and a visibility field on every row.
4. **D5/D6**: Phase 0 alone and first, moving the eval baselines once; the wrapper as Phase 0b.
5. **D7**: permission to file the four upstream asks.
6. **D8**: batch Phase 1 with the knob widening, or let it go alone if the widening has no date.
7. **D9**: the reading of 009 D3's "decorative fault" clause. If it is read the other way, D3 reopens.
