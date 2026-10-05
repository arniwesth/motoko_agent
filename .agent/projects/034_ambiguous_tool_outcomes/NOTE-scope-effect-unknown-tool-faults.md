# NOTE: Scope — tool faults whose effect may have happened

Date: 2026-09-29. Grounded at HEAD `0d5365a8` on `main`.
Prompted by: Havoc (https://github.com/bernardobbl/havoc), which runs Claude Haiku 4.5 against
tools that fail on purpose and finds 0% silent failures across 13 fault types, and 100%
`DESTRUCTIVE` (95% CI 75.8–100, n=12) on `WRITE_SUCCEEDED_REPORTED_FAILED`: the write landed,
the tool said it failed, the agent retried and paid the refund twice.

Status: scope only. No ADR, plan, or code yet.
Updated 2026-10-02 at HEAD `4023bf08`: §6 adds live probes (`evidence/exec_probe.sh`). They add
`OutputLimitExceeded` to Phase 0, show the fault is reachable in ordinary use, and test a
Motoko-side deadline that keeps partial output. §0–§5 are as written except where marked.
Superseded in part by `ADR-001-effect-disclosure-for-tool-faults.md` (Proposed, 2026-10-02): its §5
lists where this note did not hold. In particular Phase 0's `SpawnFailed` and `PermissionDenied`
→ `none` is unsound; the ADR's D2 makes them `unknown` (probe cases 8–12).

## 0. The answer

Motoko cannot currently express Havoc's fault, in the world or on the wire, and its live
runtime already produces it without saying so.

- **World.** Every tool fault row in the catalogue asserts the update did not happen:
  `ToolFailed` "did NOT occur" (`src/core/dst_fault_catalogue.ail:346`), `ToolDeadlineExceeded`
  "no logical update occurred" (`:362`), `ToolCorrelationMismatch` "No logical update occurs"
  (`:354`). `scripted_tool_outcome` (`src/core/ports.ail:1775–1789`) returns a fault without
  touching any modeled state, and `WorldState` has no record of tool effects to touch.
  009 ADR-001 D3 already requires both halves: "Write-like tool faults specify whether the
  all-or-nothing logical update occurred … deadline outcomes specify whether work completed
  before or after the observation" (`ADR-001-deterministic-test-world-architecture.md:833`).
  Only the benign half was built.
- **Live.** `run_process_result` (`src/core/tool_runtime.ail:997–1020`) maps every
  `ProcessError` to `exit_code: 1`, `stdout: ""`. A command killed by the process-timeout wall
  (`Timeout(ms)`) or a signal (`AbnormalExit`) ran and may have done its work (`git push`, a
  migration, an HTTP POST). A command that was `NotFound`, `NotAllowed`, `PermissionDenied`, or
  `SpawnFailed` never started. The model gets the same typed signal for both, and only the
  stderr prose differs. Partial stdout is discarded because `ProcessError.Timeout` carries only
  the milliseconds. In the typed layer, live timeouts arrive as `ToolCompleted` via
  `live_tool_outcome` (`ports.ail:1759`), so they never reach the catalogue's deadline class.
- **Harness policy.** No tool retry exists in the driver today (no retry path in `tool_phase`,
  `tool_stream_phase`, `tool_envelope_dispatch`, `tool_dispatch_adapter`). Retries are the model's
  decision. So the harness is not currently destructive; it is uninformative.

The reframing Havoc suggests: the agent failed because "no distinguishing information reaches
it". Getting that information to the model is a harness obligation, and harness-level DST is the
tool that can check it. DST should not try to measure whether the model is honest. That is
Havoc's question and needs a live model.

## 1. What to test: three properties

Three axes per tool call:

| Axis | Values | Who knows it |
|---|---|---|
| World truth | `applied` ∈ {no, yes} (all-or-nothing; torn effects stay excluded, 007 D1.3) | The world only |
| Observation | completed · failed before dispatch · failed after dispatch · deadline (completion not observed) · mismatch | The harness |
| Disclosure to the model | effects `none` · `unknown` (· completed) | The model |

**P1 — Disclosure is sound (one-sided).** If the harness tells the model an effect did not
happen, the world did not apply it: `disclosure = none ⇒ applied = no`. `unknown` is always
permitted after dispatch. The converse is not asserted, matching the one-sided discipline of
`checkpoint_would_relieve`.

**P2 — No information leak or invention (metamorphic pair).** Two runs that differ only in the
world's `applied` bit for one call produce identical ledger traces. The harness cannot know the
bit, so any difference means it read something it shouldn't, or rendered something it didn't
observe. This reuses the two-run determinism relation (`dst_invariants.ail` ~2075) with a program
transform that flips one `applied` field, instead of a second generator.

**P3 — The driver never re-dispatches a call.** No tool call id is dispatched twice by the
driver. This is modeled on `DeniedCallDispatched` (`dst_invariants.ail:395`, `:1396`), which
reads the world-served interaction log rather than the driver's own account. It holds trivially
today. Its value is as a guard against a plausible "helpful" future change such as retry on
timeout, so it only counts once a mutation fixture (add a retry-on-deadline) shows it fails.

Destructive retries by the model (new call id, same effect key, applied twice) are a
**run-report metric**, not a verdict. In DST the model is the generator, so the number describes
the generator. It becomes meaningful in live or journal-derived evaluation.

## 2. The constraint that shapes the design

Tool fault class ids are wire names: `tool_fault_message` renders `fault_class` into the
tool-role message the model reads (`tool_phase.ail:277–304`), and the catalogue adopted the three
PascalCase ids for that reason (`dst_fault_catalogue.ail:23–34`). **A new class for "applied,
then faulted" must never reach the wire.** If it did, the harness would be telling the model the
world's truth, and P2 would fail by construction. Havoc's core property is that the two cases
are observationally identical.

So the new row is a world-side class (lower_snake id, like the eight non-wire classes), delivered
through the same constructors as its twin, with the model-visible rendering computed from the
observation stage alone. This is a new kind of catalogue row: a class that is deliberately
invisible to the model. The validator needs a field that says so, and a check that the id never
appears in any projected tool message.

## 3. Work, in phases

### Phase 0 — Live disclosure (production; smallest; independent of DST)
- `tool_runtime.ail:997–1020`: split `ProcessError` by whether the process started.
  `Timeout`, `AbnormalExit`, `OutputLimitExceeded` → effects `unknown`. `NotFound`, `NotAllowed`,
  `PermissionDenied`, `SpawnFailed` → effects `none`. (`OutputLimitExceeded` added 2026-10-02: it
  was in neither list, and §6.1 case 4 shows the command runs to completion.) Add the disclosure to the `BashExecResult`/`RunTestsResult` JSON
  so the model can read it, and so `ToolOutcome` can carry it through `live_tool_outcome`.
- Decide whether pre-dispatch refusals (`validate_path_common`, argument decode) also render
  `none`. They should. They never dispatched.
- Upstream (AILANG, via the `ailang-feedback` skill): `ProcessError.Timeout` should carry partial
  stdout and stderr. Today the evidence of how far a killed command got is discarded before
  Motoko sees it.
- Cost: this is a wire change. Every tool fault message the model sees changes shape, which moves
  prompt-sensitive eval baselines.

### Phase 1 — World and catalogue
- `ScriptedTool` gains `applied: bool` and a dispatch stage (`ports.ail:599`). Program schema
  `execution-program/4` → `/5` (`dst_program.ail:132`), with the S30 presence rule. A `/4` payload
  decodes to `applied = false`, because that is exactly what the catalogue said those rows meant,
  so the default is the recorded meaning rather than a guess.
- `WorldState` gains an append-only effect log `{call_id, effect_key}`, where `effect_key` is a
  digest of tool and arguments. This is Havoc's audit log "A". `scripted_tool_outcome` appends
  when `applied` is set, then delivers the fault.
- Catalogue `fault-catalogue/2` → `/3`: one new world-only row. Proposed id:
  `tool_effect_applied_then_faulted`, applicability `AlwaysApplicable`, delivered as `ToolFailed`
  (post-dispatch) or `ToolDeadlineExceeded`, logical transition "the update DID occur; the
  delivered outcome is byte-identical to the not-applied twin". The existing rows keep their
  meaning. Changing `ToolFailed`'s transition in place is the silent reinterpretation D8 forbids.
- Generator: `choose_tool` (`dst_generator.ail:740`) draws `applied` for the post-dispatch
  `Failed` and `Late` arms under its own salt, so the twin in P2 differs in that draw alone. Bump
  `generator_version`, re-pin the canary by hand (no `--update`, by design), and re-derive the PR
  bank.
- Profiles: an `AlwaysApplicable` class enters every profile's coverage accounting, so all four
  profile versions move.

### Phase 2 — Invariants
- P1 as `EffectDisclosureUnsound(ordinal, call_id)` and P3 as `ToolCallRedispatched(call_id)`,
  both under `ToolPairing`. **Independent oracle** (S16; the #165 lesson): read the world's
  interaction log and effect log against the ledger's projected message. Never call
  `tool_outcome_message` or anything it calls.
- P2 as a pair relation beside the determinism pair.
- Mutation fixtures for each: render `none` after dispatch (P1); read the `applied` bit into the
  message (P2); retry on deadline (P3). A family that has not been seen to fail is not evidence.

### Phase 3 — Report
- Class-reached and branch-reached counters pick the row up from the catalogue automatically
  (`required_class_ids()` is the source).
- Add a count of duplicate effect keys, labelled as a generator-side metric in DST, and as
  Havoc's `DESTRUCTIVE` measure when the same count is run over live or journal-derived sessions.

## 4. Not in scope

- **Measuring model honesty.** That is Havoc's question. The cheaper route may be to run Havoc
  against Motoko's tool surface rather than rebuild it here.
- **Torn or partial effects.** `applied` is one bit, and physical faults stay excluded.
- **The extension effect seam.** `ext_effect_exec` runs with `timeout_ms: 0` (`session.ail:1299`),
  so it cannot produce a deadline. Follow-up.
- **Delegation.** A herdr or compose delegate reported `Lost` that actually settled late is the
  same ambiguity one level up (`WakeOutcome`, `ports.ail:788`). Follow-up, and probably the
  higher-stakes one: a re-delegated task repeats a whole agent's worth of writes.
- **Harness-side resolution** (read back after an ambiguous write, idempotency keys). This is a
  product decision that only becomes possible after disclosure exists. One cheap lead: `EditFile`
  already has an `expected_sha256` precondition (`tool_runtime.ail:876`), which makes an edit
  retry safe when the model supplies it. The harness could recommend it after an `unknown`
  outcome.

## 5. Decisions needed

1. **Ship Phase 0 on its own?** It is the only part that changes what a live session does, and it
   is the only part that needs no DST machinery. Recommendation: yes, first. It moves the wire,
   so do it deliberately and not as a side effect of Phase 1.
2. **A new `ToolOutcome` variant, or a stage/disclosure field on the existing ones?** A variant
   makes AILANG's exhaustiveness check find every match site: about 21 `ToolCompleted` sites and
   15 files naming `ToolCorrelationMismatch`. A field is less churn but relies on every site
   reading it. Recommendation: a field on `ToolFailed` and `ToolDeadlineExceeded`, since the
   observation variants themselves don't change, plus a validator row asserting it is set.
3. **Batch Phase 1 with the knob widening** in `013/NOTE-fdb-simulation-cross-check-2026-09-08.md`
   §3.1? Both bump `generator_version`, re-pin the canary, and re-derive the PR bank.
   Recommendation: yes, one batch. That note's own warning applies: do not pay the re-derivation
   twice.
4. **ADR:** the class sits inside 009 D3 as written, so no reopen is needed. But a
   world-only catalogue row and a model-visible disclosure field are both new, so a short ADR in
   this folder before any plan.

Decisions 5–7 were added on 2026-10-02 and are in §6.5.

---

## 6. Update 2026-10-02: live probes

Grounded at HEAD `4023bf08`; `tool_runtime.ail`, `ports.ail`, `tool_phase.ail` and
`dst_fault_catalogue.ail` are unchanged since `0d5365a8`, so every coordinate above still holds.
Prompted by the re-grounding of `../030_harness_playbook/RESEARCH-harness-playbook-implications.md`
§8, which reached the same lines of `run_process_result` from the playbook's "bound output once"
and "cancellation requires a kill boundary" arguments.

Probe: `evidence/exec_probe.sh`, run against the installed AILANG v0.47.2 and GNU coreutils 9.4.
It calls `std/process.exec` directly with small limits, so it measures what `run_process_result`
receives. It does not exercise `run_process_result` or the message the model reads.

### 6.1 Results

| # | Command (under `bash -lc`) | Limits | `exec` returned | Effect |
|---|---|---|---|---|
| 1 | `echo out; echo err >&2; exit 3` | defaults | `Ok`, exit 3, 4 + 4 bytes | — (control) |
| 2 | `echo PARTIAL; sleep 30` | timeout 2 s | `Err(Timeout(2004))` | The 8 bytes already printed are gone. |
| 3 | `echo PARTIAL; (sleep 8; touch m_late) & sleep 30` | timeout 2 s | `Err(Timeout(7005))` | `m_late` absent when `exec` returned, **present 1 s later**. |
| 4 | `head -c 5000 /dev/zero; touch m_over; exit 0` | output 1,000 bytes | `Err(OutputLimitExceeded(1000))` | `m_over` **present**: the command was not stopped at the limit and exited 0. |
| 5 | case 3 under `timeout -k 1 2` | wall 20 s | `Ok`, exit 124, 8 + 8 bytes | `m_group` **absent** 10 s later. |
| 6 | case 5 with the child under `setsid` | wall 20 s | `Ok`, exit 124, 8 bytes | `m_setsid` **present**. |
| 7 | case 4 under `timeout -k 1 5` | output 1,000 bytes | `Err(OutputLimitExceeded(1000))` | `m_over2` present. |

`out.truncated` was `false` in every `Ok`.

### 6.2 What this changes above

- **The fault is reachable in ordinary use (§0, Live).** Case 4 is
  `WRITE_SUCCEEDED_REPORTED_FAILED` with no injection and no race: a command whose output passes
  the limit runs to its own exit, and `run_process_result` renders `exit_code: 1`, `stdout: ""`,
  `output limit exceeded: N bytes` (`tool_runtime.ail:926`, `:1012–1019`). The production limit is
  the binary's default, 10 MB (`-process-max-output`); nothing under `src/tui/src` or the Makefile
  overrides it. A verbose build, install or migration is enough.
- **The tool description promises the opposite.** `BashExec`'s model-facing description says
  "Output is captured to stdout/stderr with truncation past a configured byte cap"
  (`tool_catalog.ail:54`). Past the cap the model gets no output at all, so it has been told to
  expect a truncated result and a failure looks like a failed command.
- **Phase 0's split was incomplete.** `OutputLimitExceeded` was in neither list. It is `unknown`,
  and it is the member where "unknown" most often means "yes" (edited in place in §3).
- **An effect can land after the result (case 3).** This is the second half of 009 D3's "whether
  work completed before or after the observation". The kill reaches the shell and not what the
  shell started. For P1–P3 one `applied` bit is still enough, because `unknown` is sound whenever
  the effect lands. For §4's harness-side resolution it is not: a read-back straight after an
  `unknown` outcome can see "not applied" and be wrong a second later. Read-back needs a kill that
  reaches descendants first.
- **The extra 5 s is a signal.** Case 2 returned at the wall (2,004 ms); case 3 at the wall plus
  5 s (7,005 ms), which is the pipe-close grace `runtime-process.ts:946–950` documents. The grace is
  only spent when something still holds the pipe, so `timeout after 35005ms` in a live session
  suggests a descendant outlived the kill, and `30004ms` suggests none did. Two data points; not
  something to render to the model without upstream confirming the rule.
- **Partial output is lost on every deadline, not only on ambiguous ones (case 2).** This is the
  upstream item in Phase 0, measured.

### 6.3 A Motoko-side lead: a deadline inside the wall

Cases 5–7 put coreutils `timeout -k <grace> <deadline>` between `exec` and the shell, with the
deadline below the runtime's `--process-timeout`.

- **It turns the deadline into an `Ok`.** Exit 124 with stdout and stderr intact, so partial output
  reaches Motoko without an AILANG change.
- **It kills the group.** `timeout` runs the command in its own process group and signals the
  group; the backgrounded work in case 5 never landed.
- **It narrows the ambiguity and does not close it.** A child that calls `setsid` escapes (case 6),
  and work done before the deadline is done. The disclosure after a wrapper deadline stays
  `unknown`. P1 is one-sided, so that is sound.
- **It does nothing for the output limit (case 7).** That needs output spilled to a file by the
  wrapper, or the upstream change. Neither is tested here.
- **It gives `timeout_secs` a meaning.** The `BashExec` schema advertises it
  (`tool_catalog.ail:55`) and the dispatcher does not read it (`runtime-process.ts:946–956`); the
  wrapper's deadline is where it would go, clamped below the wall.

Open points: exit 124 is also a legal exit code for the command itself; `timeout` must exist
wherever the runtime runs (present in this container, unchecked elsewhere); `run_process_result`
only wraps in `bash -lc` when the request has shell tokens or a cwd (`tool_runtime.ail:989–996`),
so the direct-exec arm needs the same treatment. The wrapper changes what the observation is —
`Ok`/124 where there was `Err(Timeout)` — so `live_tool_outcome` (`ports.ail:1759`) classifies it
differently, and P2's "rendered from the observation alone" has to be re-read against it.

### 6.4 Why this moved up

- §0's "not currently destructive; it is uninformative" still holds: there is no driver retry.
  What changed is how often the uninformative case occurs. It needs no fault, only a long or noisy
  command, and the model's ordinary response to exit 1 with no output is to run it again.
- Phase 0 is cheap to schedule. `BashExecResult` and `RunTestsResult` are `ToolResultItem`
  (`src/core/types`), not ABI records, so the 8.x stability rule does not gate the field. The cost
  is the one §3 already names: the eval baselines move.
- The playbook note's diagnostics candidate (030 §4.2, §8.4 item 1) is the same wire change. One
  result shape carrying deadline, output limit and effect disclosure pays the baseline cost once.

### 6.5 Decisions added

5. **`OutputLimitExceeded` → `unknown`.** Recommendation: yes; §6.1 case 4 leaves no other reading.
6. **Is the deadline wrapper part of Phase 0?** Recommendation: no, a Phase 0b. Phase 0 is a
   rendering change over observations that already exist. The wrapper changes the observation, so
   it wants its own probe through `run_process_result` and its own pass over the eval baselines.
7. **File the upstream asks anyway?** Partial stdout and stderr on `Timeout` and
   `OutputLimitExceeded`, and a kill that reaches the process group. Recommendation: yes, via the
   `ailang-feedback` skill; the wrapper covers the deadline case only, and only where `timeout`
   exists.
