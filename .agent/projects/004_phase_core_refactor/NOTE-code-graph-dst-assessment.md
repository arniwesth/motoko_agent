# Code-graph DST architecture assessment

Date: 2026-07-05
Status: Finding (post-Phase-C2, pre-ADR-002 disposition)
Tool: code-graph profile=core (34 modules, 588 funcs, 793 invokes, 903 effect edges)
Req: run `tools/code-graph/extract.sh` to refresh

## What the graph reveals about DST readiness

### 1. Pure core is real and graph-verified

The graph confirms the inversion is structural, not aspirational:

- **33 pure functions** in `step_machine.ail` — zero effect edges. `decide(s, pol)` has no
  outgoing edges to `Clock`, `Env`, `FS`, `IO`, or any impure call target. All 11 test
  functions in `step_machine.ail` are tagged `pure func` and checkable with
  `ailang test --pure`.

- **phase_vocab.ail** (84 funcs) imports only `compaction.ail` (pure helper functions) and
  `tool_contract.ail` (pure conversion). The sealed history type `MkHistory` is never
  exported — the graph shows all construction goes through `history_from_seed` /
  `history_append` / `apply_state_delta`, all of which are either pure or gated by
  validation.

- **No `decide` call escapes the pure boundary.** The graph shows the only callers of
  `step_machine.decide` are in `session.ail` — and `session.ail` is the sole module bearing
  the full effect row. The decision/separation boundary is 100% graph-enforced.

### 2. Port seams are single-use

The `ports.ail` module defines 6 function-valued seams. The graph shows each seam is consumed
at exactly one call site in `session.ail`:

| Seam | Consumed at | Effect isolated |
|------|-----------|----------------|
| `model_step` | `session.ail` dispatch_step call | AI, IO, Trace |
| `approval_read` | `session.ail` AwaitApproval handler | IO |
| `clock_now` | `session.ail` duration/retry timing | Clock |
| `env_get` | `session.ail` policy init (moved to entry in WI-C10) | Env |
| `tool_exec` | `session.ail` hybrid bash extraction | IO, Process, FS |
| `hooks_runtime` | `session.ail` extension dispatch points | all effect rows |

This is clean. Every nondeterminism source is narrow, replaceable in isolation, and
graph-provable.

### 3. The ledger is the trace log — but aggregated, not recorded

44 `ledger_emit` / `emit_run_summary` / `emit_stream` call sites exist across `session.ail`.
However, the graph shows no `LedgerRecord` serialization to a persistent store — all event
emission is `println(encode(...))` over `IO`. The in-memory `LedgerTrace` type (from
`phase_vocab.ail`) is threaded through `c2_loop` state and appended via `c2_append_decision`,
but the trace is used only for final return in the `TracedSessionResult`, not streamed or
persisted. This means:

- **No replay log exists today.** DST replay would need to capture the full ordered
  `LedgerTrace` as a serialized artifact.
- **The shape is correct.** The decision record variants (`DecisionRecord`, `WireRecord`,
  `CompactionApplied`, etc.) already distinguish internal decisions from external
  observations — which is exactly what DST trace comparison needs.

### 4. Extension hooks are not yet ported

The graph shows `dispatch_tool_policy`, `dispatch_tool_handle`, `dispatch_pre_step_chain`,
etc. in `ext/runtime.ail` import directly from extension modules. They are **not** routed
through a port seam — they live on the `ExtRuntime` record passed through `c2_loop`.
The `ext/runtime.ail` module's effect row is `{IO, Process, FS, AI, Env, Net, SharedMem,
Clock, Stream}` — equal in scope to the session driver's. This means:

- Any extension hook could (in principle) call any effect, and the graph cannot statically
  prove it won't.
- The `ext_fixture.ail` test fixture uses `pure func` hooks that are graph-visible as
  effect-free — but this is a test artifact, not an architecture constraint.
- **DST for extensions requires a `Ports.hooks` seam** that can be replaced with a pure or
  scripted hook table. Today that seam is the `ExtRuntime` record, which has no enforcement.

### 5. `env_client.ail` is the only untestable layer

Every module except `env_client.ail` has either:
- A test file in `src/core/test/` (stub_step, scripted_ports, ext_fixture, integration_tests),
- A pure test suite in the module itself (`step_machine.ail` has 11 `pure func test_*`), or
- A port seam for DST replacement.

`env_client.ail` (3 funcs) calls `exec_in` over HTTP to the env-server. Its effect row is
`{Net}` — pure network, no seam. The env-server protocol (`exec`, `scratchpad`) is the single
production service dependency that cannot be deterministically faked without a dedicated
env-server stub. This matches the DST research finding (RESEARCH-phase-core-dst-design.md §7.1)
that the env-server is the last nondeterminism source.

### 6. `persist_nudge` counting is still steganographic

The graph confirms the steganographic pattern identified in the research: `count_persist_nudges`
scans message content for the magic string `[motoko-persist-nudge]`. This appears in the graph
as a call to `contains(m.content, persist_nudge_marker())` — a string search over all user
messages. The porter state (`nudges_used`) exists in `C2LoopState` and is threaded correctly
(the graph shows the increment at `session.ail#1268`), but the *initial* value is derived from
history scanning at session init (session.ail#431, `nudges_used: count_persist_nudges(history)`).
A DST replay would reproduce the scan faithfully — the bug class is observability, not
determinism — but the design is brittle and the graph can't distinguish it from legitimate
content scanning.

### 7. Module dependency chain is DST-friendly

The 75 import edges form a clean DAG. No circular imports. The dependency chain is:

```
types → tool_contract → phase_vocab → step_machine → session → agent_loop_v2 → rpc
                                                                    ↓
                                                              supervisor (entry)
```

Every arrow goes one direction. The pure modules (`step_machine`, `phase_vocab` core,
`compaction`, `tool_contract`) sit at the left edge of the DAG and import nothing impure.
The effect-bearing modules (`session`, `tool_runtime`, `ext/runtime`) are downstream sinks.
This means a DST runner can import and drive the pure core without pulling in any impure
dependency — the type system and the import graph agree.

## DST gap inventory (post-Phase-C2)

| Gap | Graph evidence | Severity |
|-----|---------------|----------|
| No record-replay ledger | `c2_append_decision` exists but trace is returned, not persisted | High — no DST without replay |
| `env_client.ail` unstubbed | 3 funcs, `{Net}` effect, no port seam | High — env-server must be faked |
| Extension hooks not ported | `ext/runtime.ail` has full effect row; no pure test harness for arbitrary extensions | Medium — fixtures exist but pattern is unwritten |
| No cost oracle port | Cost rates passed as config, not through a replaceable seam | Low — cost is pure anyway |
| No fault injection schedule | `recovery.ail` policy is hardcoded by env vars, no injection point for "fail step 3" | Medium — required for DST completeness |
| No seeded deterministic scheduler | `Clock` port exists but `fake_clock() → 0` is not seedable | Low — single-threaded loop doesn't need scheduling |

## Bottom line

The graph confirms what the Phase C research claimed: the architecture is **structurally ready**
for DST at the module boundary level. The pure decision core is graph-verifiably pure, the
import DAG is acyclic with impure sinks downstream, and the port seams cover all nondeterminism
except `env_client`. The gaps are in the **recording and scheduling** layers — the ledger is
emitted but not captured for replay, and fault injection requires a scheduler that doesn't yet
exist. Neither gap requires refactoring the session driver; both are additive infrastructure
that slots into existing abstraction boundaries.
