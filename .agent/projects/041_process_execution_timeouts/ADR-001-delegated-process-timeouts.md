# ADR-001: Retire dormant delegated execution; ground timeout work on the native path

Date: 2026-10-24
Status: **Proposed, fifth revision making the AILANG v0.54.14 pin in scope**
Grounded at: `origin/main` `28451207`; removal candidate on `fix/delegated-process-timeout`
(draft PR #284). AILANG v0.52.5.

Requested by the operator after independent Claude Opus 5.5 reviews of the initial delegated
timeout proposal and this removal revision. The second review accepted removal with amendments:
the upstream pin move, retained-type distinctions, behavioral guard, and factual corrections are
applied here. Neither review nor this ADR is presented as operator acceptance.

Relates to:

- [BashExec timeout-knob issue](../../issues/bashexec-timeout-knobs-are-dead.md).
- [Effect disclosure for tool faults](../034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md).
- [M6.5 delegation design](../../../design_docs/planned/m-motoko-m65-ohmy-pi-delegation.md),
  which describes a possible future pipeline rather than a supported current execution path.
- [Native tool-calling plan](../../plans/Native_Tool_Calling_For_Motoko.md).

## TL;DR

**Decision.** Remove the unreachable TypeScript delegated process executor and its ohMyPi-only
dispatcher instead of adding timeout policy to it. Retain only the shared types and presentation
helpers with active or deliberately scoped compatibility consumers. Do not revive the legacy
execution path implicitly; a future M6.5 protocol must be designed explicitly. (D1–D3)

**Adopt the native fix through the upstream pin, not new fork work.** The observed
timeout-and-surviving-descendant failure is in native AILANG `std/process.exec`, not in the deleted
TUI executor. Upstream v0.54.14 already implements process-group cancellation with `WaitDelay`.
Project 034's accepted ADR assigns the pin move to `>=0.54.14` to project 012. This PR now includes that pin and its native verification rather than leaving them as follow-up. (D4, D7)

**Do not compound the existing knob problem.** This patch does not add a second duration parser
or new constructor-time validation. It also does not pretend `timeout_secs` works: the cheap
interim is to remove that argument from the live schema or reject it, with consistent per-call
semantics left for a later design. (D5, D6)

**Timeout remains ambiguous.** Tree cleanup is containment, not rollback or proof that no effect
landed. Native timeout results continue to carry `effects: unknown`. (D8)

## 1. What the first proposal got wrong

The initial ADR selected the TUI's `RuntimeProcess.runDelegatedCall` as the source of the
long-demo failures. It added a Go-duration parser, constructor validation, a configurable timer,
and process-tree cleanup there. Direct probes using
`Object.create(RuntimeProcess.prototype)` showed that this method could time out and leave
children alive. Those probes did **not** go through a running Motoko session and therefore did
not establish production reachability.

Independent review then established the following against current source and history:

1. `runDelegatedCall` is called only by `handleToolCalls`, reached when the TUI reads a
   `tool_calls` event from runtime stdout. No current AILANG producer emits that event.
2. Commit `6350b7ad` (M10b) deleted the legacy AILANG producer and result consumer, including
   `wait_for_tool_results`, `delegated_wait_attempts`, and `delegated_timeout_results`.
3. `run_with_config` rejects `ohmy_pi=true`. With `ohmy_pi=false`, `tool_phase.ail` maps
   `Delegate` to `Native`. Shell-shaped and `cwd` commands run through native `std/process.exec`;
   streaming and hard-cancel requests are refused.
4. The long-demo build returned a **native** `fault.kind: deadline`, `effects: unknown`, and
   `timeout after 30003ms`. It was not the TUI delegated string `timed out after ...`.

Consequently, the first proposal's central reachability premise was false. Its green tests proved
properties of a directly invoked dormant method, not a fix for the operator-visible behavior.
The independent recommendation was rejection and re-grounding, which the operator accepted.

## 2. The live native defect remains

The reviewer reproduced the real failure against native AILANG v0.52.5:

- the command ran with `--process-timeout 1s`;
- a delayed descendant inherited its stdout pipe;
- `exec` returned `Err(Timeout(6003))`, approximately the one-second wall plus the five-second
  `WaitDelay`;
- the descendant subsequently wrote its marker.

In `ailang/internal/effects/process.go`, `exec.CommandContext` uses the default cancellation,
which kills the immediate process. There is no `Setpgid` in that implementation. `WaitDelay`
correctly bounds the wait for inherited pipes; it does not constitute descendant cleanup.

This is why removing or fixing only `RuntimeProcess.runDelegatedCall` cannot close the live
issue. The issue record and all PR descriptions must state the native defect explicitly rather
than imply it has been fixed by delegated-path work.

## 3. Forces and invariants

- **Production evidence before architecture.** A direct method probe is not a session routing
  proof. A timeout design must identify the actual producer, dispatcher, executor, and result
  renderer.
- **Delete unreachable mechanism rather than maintain speculative policy.** Dormant execution
  code creates a second architecture to reason about and invites precisely the mistaken repair
  made in the first proposal.
- **Preserve active presentation contracts precisely.** `DelegatedCall` and
  `resolveDelegatedExec` have active native-rendering/tool-planning consumers. `DelegatedResult`
  and `ToolResultsPhase` are legacy-presentation-only, not native-result types. Their names alone
  do not make any of them unreachable.
- **Separate presentation compatibility from execution compatibility.** Legacy `tool_calls` and
  `tool_results` event variants may remain for display/rendering while no executor consumes them.
  Removing every legacy rendering arm or changing journal behavior is a separate protocol task.
- **No resurrection by accident.** A future delegated protocol needs an explicit producer,
  consumer, correlation rule, timeout relationship, and versioned acceptance tests.
- **Keep native `WaitDelay`.** The existing regression protects against a descendant-held pipe
  hanging the native call forever. Tree cancellation must not remove it.
- **Fault honesty.** A timeout cannot establish that no write occurred or that every descendant
  died. Cleanup does not change `effects: unknown` to `effects: none`.

## 4. Decisions

### D1. Remove the dormant TypeScript delegated executor

Delete:

- `RuntimeProcess.runDelegatedCall`;
- `RuntimeProcess.handleToolCalls` and its dispatch on the legacy `tool_calls` event;
- `runDelegatedCallsSequential` and `resolveDelegatedSpawn`;
- the ohMyPi-only dispatcher and session adapter, once their only caller is removed;
- tests that directly exercise the removed process executor as though it were production code.

The `tool_calls` branch in `RuntimeProcess` no longer spawns work or sends results. The retained
UI/logger arms are scoped legacy presentation only. A stray event would still look queued and could
say "Waiting for delegated tool results..." without a result arriving; it must not be mistaken for
proof of old-session replay support or a supported execution fallback.

This is intentionally more than removing the method's signature: retaining the helper machinery
would preserve the impression of a supported alternate executor and make accidental reconnection
more likely.

### D2. Retain shared rendering types and helpers for now

Do not delete `DelegatedCall`, `DelegatedResult`, or `resolveDelegatedExec` merely because their
names contain "Delegated". `DelegatedCall` is the payload of `native_tool_calls` and is used in
tool planning; `resolveDelegatedExec` is used by `ui.ts` for native call metadata (and by
`index.ts` only for the legacy arm). `DelegatedResult` and `ToolResultsPhase` are retained solely
for legacy `tool_results` presentation; native results use `NativeToolResult`. Renaming or
relocating shared definitions is a separate mechanical cleanup.

The legacy `tool_calls` / `tool_results` variants and their UI/plain/session-logger arms are
retained to scope this patch, not because an old-event replay path was found. Current events come
from the live child's stdout. Their protocol and journal compatibility policy is outside this
change; future removal must not leave a misleading indefinite delegated wait.

### D3. Add a no-execution regression guard, not more dormant-path timing tests

The guard has two layers:

1. a source tripwire for the removed executor helpers and the old `tool_calls` execution branch,
   with its source path anchored through `import.meta.url`;
2. a behavioral fake-runtime test that emits a legacy `tool_calls` containing a marker-writing
   BashExec. The real `RuntimeProcess` forwards the event once, the marker never appears, and no
   delegated result path runs.

The first is only a structural tripwire, not a proof of runtime behavior. The second establishes
the relevant no-spawn property through the actual child-event path. Any future protocol
restoration must change the guard deliberately and supply a real end-to-end round trip.

### D4. Adopt the already-existing native fix through project 012's pin move, included here

Upstream AILANG v0.54.14 already implements the relevant native behavior:
`proctree.ConfigureContained(cmd)` puts the command in its own process group, a timeout kills that
group, and `WaitDelay = 5s` remains. This was independently read from the upstream tag, not inferred
from the shared checkout's older `ailang/` fork.

The accepted project 034 ADR (D7 and rulings 4 and 6) already assigns Motoko's adoption to the
`>=0.54.14` pin move in project 012. This ADR must not schedule redundant fork development or
contradict that ruling. The `ailang.toml` / `ailang.lock` and installer pin now move to v0.54.14 as part of this PR;
it is not deferred to a separate removal-only patch.

The pin is now part of this PR: `ailang.toml` and `ailang.lock` move to v0.54.14, and
`scripts/install-prerequisites.sh` uses the same tag/minimum. Project 012 retains continuous
adoption ownership; this change does not reassign that role or create a second AILANG fork.

This PR adds `scripts/verify_native_process_tree.ail` and `make verify_native_process_tree` to
`check_core`, using the exported native batch path to exercise the real dispatcher. The probe uses
a one-second wall, an independently delayed descendant write, and checks:

- `Timeout` returns near the wall rather than the wall plus the five-second `WaitDelay`;
- the late write does not land;
- native `fault.kind: deadline` and `effects: unknown` remain unchanged;
- `setsid` escape remains a documented exception, not silently claimed to be contained.

Observed with the downloaded v0.54.14 binary: about 1003ms, no late marker, deadline/unknown
preserved. The v0.52.5 binary is the negative control: about 6006ms and failure of the wall-latency
assertion. The old binary did not leave its late marker in that particular run, so the old behavior
is not misreported as a guaranteed marker write.


### D5. Do not add the first proposal's parser or constructor validation

Do not carry forward `src/tui/src/process-timeout.ts`, its tests, or the constructor-time
delegated timer validation introduced by the first patch. They served the unreachable executor and introduced a
new live restriction: configurations accepted by native AILANG, including values above Node's
32-bit timer range, could be refused before the runtime started. Throws in UI restart callbacks
also bypassed the established error path.

No new duration parser or validation policy is needed for dead-code removal. Native process-wall
parsing remains AILANG's responsibility.

### D6. Stop advertising `timeout_secs` as working; defer full per-call semantics

The live `BashExec` schema still advertises `timeout_secs`, and models have supplied it while
`parse_exec_from_args` ignored it. The first patch left this more production-relevant defect
untouched while fixing a dormant path.

This patch removes `timeout_secs` from the advertised schema, so a new call cannot reasonably
believe it changed the wall. Existing callers that still send it remain subject to the old
argument decoder; providers do not reject it under the current non-strict schema. Rejecting those
calls explicitly is optional follow-up, not claimed here.

Project 034's PLAN-001 W0b had proposed a GNU `timeout` wrapper, clamped below the wall, but the
operator withdrew that phase on 2026-10-18 after its probe (including macOS availability and the
limits of the wrapper). This removal is consistent with that ruling, not a new claim that per-call
semantics were never explored. Full support requires a separate native design for replacement
versus capping, extension beyond the session wall, validation, and result semantics. A
delegated-only implementation is not acceptable.

### D7. Record the legacy configuration history accurately

`tools.delegated_timeout_ms` did once govern the AILANG-side delegated-result wait; it was not
meaningless throughout its history. M10b deleted that consumer along with the execution producer.
It must not be presented as a setting that should suddenly become authoritative for a new TUI
executor.

If M6.5 is implemented, its result-wait budget and executor process wall must be related
explicitly: the wait normally needs to exceed the process wall plus cleanup slack, rather than
both independently defaulting to 30 seconds. Existing `MOTOKO_PROCESS_TIMEOUT` and herdr's
`process_wall_ms` parser are part of that future design discussion. Herdr floors for sizing a
wait and uses a conservative invalid-value fallback; that is not automatically the policy for an
executor.

For completeness, `MOTOKO_TOOL_TIMEOUT_MS` is read on every native dispatch and placed in
`ToolInvocation.timeout_ms`, but only scripted/DST execution enforces it; the live outcome path
ignores it. It is not the live AILANG `--process-timeout` process wall.

### D8. Preserve the observation/effect distinction

The native timeout path already carries a structured deadline fault with `effects: unknown`.
That remains the correct disclosure. Killing a process group, destroying pipes, or returning a
timeout message does not prove no effects occurred, no writes are pending, or no descendant
escaped containment.

The first ADR incorrectly implied its delegated result had that disclosure while returning only
`exit_code: 1` and stderr text. Any future delegated protocol must carry an equivalent structured
fault; it must not inherit that contradiction.

## 5. Alternatives considered

### A. Keep and harden the dormant delegated executor

Rejected. It cannot repair current sessions, adds policy to an unsupported path, and already
introduced a live configuration regression. Its tests gave false architectural confidence.

### B. Delete only `runDelegatedCall`, leaving all helper machinery and events implicit

Rejected as incomplete. The remaining dispatcher and helpers would still suggest an alternate
supported executor. Shared types and presentation arms are retained explicitly for different,
active reasons; process machinery is removed.

### C. Remove every `Delegated*` type and all legacy presentation code

Deferred/rejected for this patch. Those names also serve native rendering and tool planning, and
wire/journal compatibility deserves its own analysis. Broad deletion would obscure the useful
boundary between execution removal and presentation compatibility.

### D. Restore M6.5 around the old method now

Rejected. M6.5 requires a new AILANG producer/consumer, inbox correlation, result-wait semantics,
and end-to-end tests. Restoring a process spawn under an event with no current producer is not an
M6.5 implementation.

### E. Fix the descendant problem only in the TUI

Rejected. The defect is in native AILANG execution. A TUI timer or parser cannot kill native
children correctly and can only add another competing deadline.

### F. Remove native `WaitDelay` when adding process-group kill

Rejected. `WaitDelay` protects against orphaned pipe holders causing an indefinite wait even when
cancellation is imperfect. Process-group cancellation and bounded pipe handling solve different
problems and should remain together.

## 6. Scope and consequences

This removal change:

- deletes the unreachable TypeScript process executor and ohMyPi-only dispatch helpers;
- does not carry forward the first proposal's delegated timeout parser or tests;
- moves `ailang.toml`, `ailang.lock`, and the installer to v0.54.14 and adds a native process-tree
  verification to `check_core`;
- retains shared rendering types and legacy presentation behavior;
- adds a no-execution regression guard;
- records the actual native defect on the old pin and includes the upstream pin and probe that
  address it, without claiming every containment case.

Expected consequences:

- one fewer apparent execution architecture to misread;
- no constructor-time rejection of previously accepted native timeout configurations;
- no new session/process-group behavior on the live path from the rejected patch;
- a future M6.5 must be explicit about protocol and budgets instead of silently inheriting this
  dormant implementation;
- shared type names remain temporarily misleading until a separate mechanical rename.

## 7. Validation for the removal candidate

The removal candidate is checked with:

- `bun run build` in `src/tui` — TypeScript compilation passes;
- the focused no-execution regression suite — **4 tests passed**, including an asynchronous-spawn
  mutation control and assertions for no generated `tool_results` and no stdin reply;
- `make check_core` and the existing TUI/runtime tests before publication;
- the tool-catalog regression asserting that ignored `timeout_secs` is not advertised;
- source inventory confirming no remaining references to the deleted executor or ohMyPi adapter.

The previous **34 delegated timing tests are not retained as validation evidence**. They tested
an unreachable path and are not carried forward.

Historical full-suite comparison at `5125a649` (Jest, branch versus an archived base): **44 of 49
suites loaded, with 467/467 executed tests passing on the branch and 468/468 on base**. The
expected delta was −3 removed helper tests +2 initial guard tests. Five suites failed to load on
both trees (four `depd` loader errors and the bare `test/path-guard.test.ts` script). That
comparison is historical evidence for that commit, not for the amended head.

At `e0eedc8a`, the final Codex Sol reviewer measured **48/48 suites and 494/494 tests passing under
Node/Jest**, and **44/48 suites loading under Bun/Jest with 468/468 executed tests passing and four
`depd` loader failures**. The fifth former failure is gone because this revision removed the
orphaned bare path-guard script. At this amendment head, the focused runtime/rendering selection
passes 20 suites/249 tests after adding the mutation control. A full Bun/Jest invocation loads 44
of 48 suites with 469/469 executed tests passing and the same four `depd` loader failures. A direct
Node invocation without the repository's Bun-backed loader is not counted as validation because it
fails on ESM loading; the reviewer's Node/Jest result above remains attributed to the reviewer.
`make check_core`, `make tool_catalog_registry`, `tsc`, and the catalog tests passed independently.

Acceptance of this ADR should explicitly rule on:

1. deleting the execution machinery rather than merely marking it dormant (D1);
2. retaining shared types and legacy presentation in this patch (D2);
3. the structural plus behavioral no-execution guard (D3);
4. including the upstream `>=0.54.14` pin and its native process-tree probe in this PR (D4);
5. removing/rejecting `timeout_secs` as the interim, rather than leaving it silently accepted
   (D6).

## 8. Follow-up sequence

1. Land the removal with a draft-then-reviewed PR; make no native-fix claim.
2. Correct the timeout issue text wherever it implied the delegated patch fixed live behavior.
3. This PR moves the AILANG pin to `>=0.54.14` and runs the native process-tree probe from D4.
   Do not reimplement the upstream group kill in a local fork; disclose `setsid` escape. Project
   012 owns subsequent continuous adoption.
4. Keep `timeout_secs` out of the advertised schema until a consistent per-call design exists;
   consider rejecting it explicitly for legacy callers.
5. If M6.5 is later funded, design its protocol and result-wait/process-wall relationship from
   current native architecture, not from the deleted executor.
6. Rename shared `Delegated*` presentation types only as a separate mechanical cleanup.


## 9. Second-review amendments applied

The following corrections are part of this revision, not new decisions requiring a hidden scope
expansion:

- D4 and the follow-up now select the upstream pin move already assigned to project 012.
- Retained-type claims distinguish active native types from legacy-only result types.
- Presentation retention no longer claims an old-event replay path was found.
- The no-execution guard has a behavioral fake-runtime test, and its source path is anchored.
- The first proposal's parser is described as not carried forward, not deleted from `main`.
- D6 records the withdrawn 034 wrapper probe; `MOTOKO_TOOL_TIMEOUT_MS` is described precisely.
- M6.5's stale "no-op" compatibility assumption is corrected in its design note.
- The orphaned inline `src/tui/test/path-guard.test.ts` is removed with its deleted dispatcher;
  live native path coverage remains in `check_core`.
- Dead `resolveCwd`/`truncate` helpers left by executor deletion are removed.


## 10. Final review amendments applied

The Codex Sol review accepted the architecture with amendments and found no production blockers.
Its remaining findings are addressed here:

- The behavioral guard now keeps the fake runtime alive through the deferred handler turn,
  captures stdin, checks for generated `tool_results` events, and uses a mutation control to show
  that asynchronous execution would be observed. Restoring an asynchronous spawn in a scratch
  mutation makes the suite fail; the clean source passes.
- Validation counts identify historical evidence by commit and separate the amended head's
  focused and full-suite results. The focused count is 4 after adding the mutation control.
- The issue body is explicitly marked as the original 2026-09-26 report, with current status taking
  precedence over stale schema, profile, and fault-shape claims.


## 11. Pin and native verification included

The operator subsequently ruled that the v0.54.14 pin belongs in this ADR rather than as deferred
work. The branch now carries the manifest/lock/installer pin and the native probe. The decision is
not merely documentary: the probe is part of `check_core`, has a below-30s budget so it cannot
pass by waiting out the harness wall, and has an old-binary negative control for the latency arm.

The remaining limitation is that the probe is Unix-specific in practice. Upstream documents that a
policy-owned run remains in its owner's group and that Windows lacks equivalent descendant
cleanup. This PR does not claim those cases are fixed. The existing `effects: unknown` disclosure
continues to describe the timeout outcome, not prove rollback or total containment.
