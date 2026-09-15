# ADR-004 v1 adversarial review verdicts

Date: 2026-09-13
Reviewed HEAD: `a0384e45d0acc11871d71d1ee473cebec5fde46c` (`a0384e4`)
Branch: `arniwesth/013-plan003-and-herdr`
Subject: `ADR-004-journal-as-evaluation-source.md`, Proposed v1, untracked
Sources: the complete draft; ADR-003 v6.1, especially O2, D1, D4, retraction 4, Consequences and Not decided; ADR-001 D2; ADR-002 D4; PLAN-003 §0.6; `HANDOFF-2026-09-13-plan001-p2d-sweep-pending.md`; the prototype and stored evidence in `/workspaces/motoko_agent-mem`.

Code coordinates were checked using `git show a0384e4:<path>`, rather than trusting the dirty working tree. The memory worktree is at `de4b4f5`. Only this review was written. No commit, sweep, `make dst`, or replay was run. Targeted Python checks read existing JSONL, TSV and compressed memory profiles. `ailang check scripts/dst/mem_journal_replay.ail` in the memory worktree passed, with toolchain-skew and changed-dependency warnings; no lockfile was updated.

## Overall verdict

**Return for v2.** The pure-reader direction is sound and the 300 request-digest matches are real. The proposed `Faithful` verdict is broader than the evidence supports, and D1 cannot recover all of the response and starting-state information D2 needs from a journal alone. These are decisions to settle before PLAN-004, rather than details to delegate to implementation.

1. **Define the experiment's validity envelope.** Matching retained messages and canonical message-list hashes does not establish byte-identical provider requests, equal provider configuration, equal tool requests, or execution of candidate prompt/extension changes. Pin and independently check the omitted inputs, or exclude those changes from the admissible candidate class. Keep live fidelity distinct from parent-replay agreement.
2. **Define extractable segments and missing-data refusals.** The journal preserves successful input/output telemetry, but not per-call finish reasons, cache usage or failed-call outcomes. It also cannot bootstrap every resumed run from `[Message]` alone. Specify supplementary host evidence or narrower refusals without changing ADR-003. An incomplete snapshot requires a prefix verdict with an explicit cutoff, not an invented successful termination.
3. **Freeze the evaluator outside the candidate.** The digest implementations, reader, adapters, counts, budget and verifier are repository code. Putting corpus files outside git does not make them or the acceptance criteria unwritable by a candidate. Specify the trusted runner and identities it enforces.
4. **Size admission before long execution.** P1 currently requires a 299-step admission before P2 establishes the short gate. The 12 GiB rule concerns aggregate cgroup usage before a sweep, not a per-process RSS ceiling; host `MemAvailable` is insufficient in this container.

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **RETURN** | Successful telemetry is usable under conditions; finish/cache/error data, initial continuation state and boundary rules are incomplete. |
| D2 | **ACCEPT WITH CORRECTIONS** | Cursor and call-id closures fit existing Ports/WorldState; `Ported` starts with an empty world, and missing/mismatched requests need explicit handling. |
| D3 | **RETURN** | Two useful projections, not a complete validity oracle; unchecked seed/configuration and prefix/terminal accounting remain open. |
| D4 | **ACCEPT WITH CORRECTIONS** | Resource and structural claims are legitimate for the stated simulated execution; GC, trace coverage, sampling and prefix limitations need qualification. |
| D5 | **RETURN** | Admission can be self-agreement; withholding and evaluator immutability are not established. Privacy basics are sensible but incomplete. |
| D6 | **RETURN** | Tier omissions must be inherited; T2 needs observations the journal does not contain. Compaction and streaming statements overstate their evidence. |
| D7 | **ACCEPT WITH CORRECTIONS** | A short allocation gate is appropriate; cgroup guards, prior sizing, exact counts and a demonstrated failing control are required. |

## 1. Per-decision verdicts

### D1 — return

**The two telemetry fields are the last successful provider result's per-call usage, not cumulative totals.** `model_phase.ail:17–25` copies `result.input_tokens` and `result.output_tokens` into telemetry, with the sent estimate as the third calibration field. `session.ail:3534` applies that delta; successful assistant paths journal the applied telemetry (`:3581`, `:3629`, `:3690`, `:3731`, `:3768`). In the evidence snapshot's r2.1, all 300 state deltas match the corresponding first live `thinking` event's input/output usage. Serving those fields is an improvement over the prototype's constants.

**The fields are not a universal one-step/one-call recording.** The retry path journals unchanged `st.telemetry` and no assistant message (`session.ail:3485–3518`). A checkpoint journals a delta with carried telemetry and does not advance the step (`:3147`; `phase_vocab.ail:465–480`). Group successful assistant messages with the appropriate delta by run and step, distinguish non-provider deltas, and refuse ambiguous/missing associations. Counting assistant messages misses failed provider attempts. The live evidence session has eight `stream_error_retry` events, although the matched 300-call r2.1 prefix has none.

**`ScriptedStep.finish_reason` cannot be read from the proposed journal inputs.** `[Message]` contains no finish reason. `StateDeltaInfo` contains telemetry, counts and artifacts (`phase_vocab.ail:862–869`), not the provider finish reason. `run_finished.finish_reason` describes the run's termination, not every response. Inferring `stop` versus `tool_calls`, as the prototype does, loses `length` and other policy-relevant outcomes. The host's `thinking` event carries finish and cache usage (`phase_vocab.ail:611–621`; `model_phase.ail:28–43`), so a selected supplementary excerpt can supply these without modifying the journal. Otherwise refuse or explicitly narrow the supported response class. The two journal token fields also omit cache read/creation usage; 299 of the evidence segment's 300 successful calls have nonzero cache usage in the live log. Existing `ScriptedStep` and `scripted_to_step_result` cannot preserve it—the latter sets both cache fields to zero (`stub_step.ail:89–90`). A custom closure returning a full `StepResult` can, without changing Ports, but that is a shape decision the ADR must make.

**The seed is insufficient for all resumed starts.** The normal message constructor zeros telemetry (`session.ail:957`); the continuation constructor carries telemetry, artifacts, cumulative counts and nudges (`:2554–2608`). D1 returns none of those initial values. A seed after a `history_replaced` can be replayable, as the prototype demonstrates, but that does not prove a budget-suspended continuation can be started through the ordinary traced entry faithfully. Carry the required folded starting state and choose the existing appropriate entry, or refuse continuation starts at T0. Resolve model/profile from settings on the selected path, rather than assuming the session header remains current. The header's `BootInputs` also needs to drive the task, hybrid flag, budget, environment URL and cost settings, or those substitutions must be part of the experiment's declared scope.

**The refusal/end list is incomplete and conflates different events.** Define a selected leaf/path, start-entry identity, exact end-entry or cutoff, and typed reasons for:

- `suspended`, `resumed`, `settings`, another `run_started`, exit/restart, and EOF without `run_finished`; future park/wake must remain unsupported until their decoder/producer exists. Ten entry types exist at this HEAD (`journal.ail:1174–1176`).
- A failed/retried provider attempt, which consumes a provider position but contributes no assistant message. Do not silently extract only the successes and claim the original workload.
- Unknown/malformed entries, corrupt digests and pairing failures, rather than only unknown header schema. Reuse ADR-003's strict discipline.
- Duplicate/ambiguous call IDs, unexpected results and partially completed multi-tool batches. Trimming only a final assistant without any results does not describe a tail with some completed results and some pending calls. End before the entire incomplete turn, recording what was excluded.
- Injected user messages as well as operator input. `session.ail:3080–3110` explicitly journals runtime-injected feedback as a user message; role alone cannot identify an operator interjection. A conservative cutoff for all such messages is valid if named honestly.
- `history_replaced` reasons other than checkpoint. The prototype snapshot contains a replacement with reason `resume` before r2.0. A replacement inside the selected run is a cutoff under this proposal regardless of its reason.
- `replaces_previous`, whose augmented assistant is a replacement of an existing response, not another provider call. End before the affected turn or define an extraction rule; simply treating every assistant entry as a step would invent a call.

Do not obtain evaluation input by letting the resume fold strip the dangling calls of the response being replayed. That repair is correct for resume; evaluation should preserve the observation and refuse/trim its incomplete execution. Folding the prefix to obtain seed history is compatible with leaving the fold untouched.

### D2 — accept with corrections

**The F6 objection is verified.** `stub_step.ail:260–270` explicitly rejects `assistant_count(payload) - assistant_count(initial_history)`: compaction can cap the count and pin the response forever. `scripted_ports` consumes `state.script` on success and error (`:275–302`). Retries without assistant appends and history replacements are additional reasons the count is unsuitable, even before extensions are enabled. The prototype implements exactly the rejected history-count formula (`mem_journal_replay.ail:96–97`).

**A world-cursor provider and call-id tool closure are feasible without changing Ports.** `Ports.model_step` takes and returns WorldState (`ports.ail:823–824`); WorldState has `script` (`:183–184`); `tool_exec` receives `ToolInvocation` and returns a typed outcome plus successor (`:957`; `:621–631`). A closure can capture the recorded tool map and response metadata, consume the script tail, and preserve all unrelated world fields. Cache-aware responses can be restored from captured full metadata rather than `scripted_to_step_result`. The existing prototype type-checks the tool-closure construction.

**Specify cursor initialization.** `Ported(p)` normalizes to `empty_world_state()` (`session.ail:1492–1495`), whose script is empty (`ports.ail:763–766`). `Ported(journal_ports(world))` does not pass the supplied world through normalization. One feasible adapter-only design initializes the captured script/env/files once on an existing bootstrap env read, using a private initialization marker in the existing world environment, and then serves only the successor's cursor. It must never reseed when the tail becomes empty. Alternatively use an already suitable world-bearing provider variant and explain its tool addressing. Do not add a production entry, Ports field, or new helped initialization request merely to solve this.

**Call-id lookup is addressing, not request validation.** Bind each record to its run/step and expected tool name/raw arguments as well as ID, track consumption, and grade reordered, duplicate, missing, extra and altered invocations. The journal's assistant call provides name/arguments, so no format change is necessary. Missing IDs can use existing typed tool outcomes or the world's existing observation/log channel, with the runner mapping that observation to `Diverged(ToolRequest)`; Ports cannot directly return `ReplayVerdict`. The missing-ID branch and unexpected script exhaustion must fail closed. Do not inherit the prototype's empty tool output or fabricated terminator.

The journal's tool message does not establish a typed exit status, deadline, elapsed time or failure classification. Declare those omissions/refusals instead of manufacturing `exit_code: 0`. The prototype does manufacture zero (`mem_journal_replay.ail:106`). Header model/profile values are not an environment/filesystem snapshot: context resolution reads env and files during policy initialization (`session.ail:2310–2325`). Use recorded supplementary configuration or declared synthetic values. Report both the recorded extension digest and the digest of the registry actually used; merely printing the recorded digest beside an empty registry could imply fidelity that was never exercised.

This adapter-only design is compatible with ADR-001 D2 if adapters preserve `ordinal`/`pending` and the existing driver remains the sole source of helped-request advancement and witnessing. No new request or between-turn frame is authorized by this ADR. The evaluation script should frame each traced invocation with the existing `WORLD_RUN_BEGIN`/`WORLD_RUN_END` contract, assert the actual starting/final ordinal and empty final pending queue, and check request witnesses inside that frame; changing a label or using `run_summary` as the frame boundary would not satisfy ADR-001 D2.

### D3 — return

**The hash functions seal different projections.** The appended-message chain uses raw content and image source/MIME (`journal.ail:253–255`; `phase_vocab.ail:321–358`). `payload_digest` hashes a message-list canonical form which omits images and normalizes only `make[1]` through `make[20]` to `make[0]` (`phase_vocab.ail:275–300`, `:365–366`). D3's caveat about `canonical_messages` is correct, but it does not describe the stronger append-chain frame. Neither projection establishes the complete provider request.

| Change | Can both proposed checks pass? | Why / necessary qualification |
|---|---|---|
| Model, temperature, output limit, reasoning/cache configuration, provider endpoint or encoding | **Yes** | Not part of either message hash. In the actual evidence all 300 live models differ from `probe/model`, yet all request digests match. Pin/check the full applicable configuration independently. |
| Native or extension tool schema | **Yes** | `live_ports` supplies `tools_with_extensions(rt)` separately (`stub_step.ail:190`; `tool_catalog.ail:143–145`); the custom replay provider skips it. Empty-registry T0 does not test candidate schema changes. |
| Image source/MIME or `make[N]` change in a newly appended retained message | **Normally no** | Raw append-chain framing catches it. Do not say both hashes are blind to these fields. |
| Image or normalized `make[N]` change only in the seed or transient provider payload | **Yes under D3 as written** | The payload hash is blind to it; chaining appended outputs from a supplied old `prev_digest` does not verify the replay seed or transient request. Validate the seed against the independently folded source; request-only transformations need stronger evidence or exclusion. An image URL also does not freeze the bytes served at that URL. |
| Candidate system-prompt or extension build-prompt patch | **Yes if construction is bypassed** | Reusing the recorded seed freezes its old prompt; the candidate builder in `rpc.run_with_config`/extension prompt dispatch is never executed. A materially changed transient text prefix is generally detected if exercised, but normalized text/image differences remain blind spots. |
| Tool dispatch argument/name rewriting, suppressed real effects, or changed tool implementation | **Yes** | A closure keyed only by the original ID can supply the same retained result. Validate the actual invocation; real execution remains outside this experiment. |
| Early termination, omitted/extra messages or calls | **Yes with the prototype checker** | Its min-length prefix comparison ignores missing/extra observations and the synthetic last output. Require exact expected counts and explicit cutoff/terminal semantics. |
| Candidate reader/adapters/digest or verifier code changes | **Yes without an independent evaluator** | The candidate can weaken what is checked, spoof observations or replay the expected arrays. External files alone do not protect the checker. |

**Live request fidelity and parent agreement require distinct verdicts.** Without a live log, parent and candidate can share the same reconstruction error. Chain agreement proves the retained scripted transcript projection, not what the model was asked. An entry with no log must report request fidelity as unknown/parent-relative, not the same `Faithful` used for a live-verified entry. The TL;DR says admission is against the parent; D5's body says an unspecified admission commit. Store source recording commit, admission parent, candidate and evaluator identities separately.

**A prefix needs a measurement boundary.** A differing request at call N invalidates using its recorded response. A differing retained history message invalidates from its earliest affected execution, not just when a later digest notices it. The checker must stop/mark the first mismatch, establish exact counts and distinguish an intentional truncated segment from observed completion. Whole-process allocation, GC count, peak RSS and wall time measured after divergence cannot be assigned to `valid_prefix`. The prototype profiles the whole run and has no per-prefix allocation instrumentation. Define measurement snapshots before the excluded step, or rerun only the already verified bounded prefix when resources allow; do not salvage the final total by assertion.

**“Divergence is a verdict” partially answers O2 for this restricted experiment.** ADR-003 O2 explicitly rejects replay for resume, and no resume policy change is needed. Detecting a changed canonical message request avoids one silent failure in evaluation. It does not answer O2's code/profile/extension-change objection for changes never exercised or invisible to the oracle. State that boundary, and weaken “byte-identical” and “still valid evidence for that candidate” accordingly.

### D4 — accept with corrections

Allocation and recursion depth over a frozen workload can expose defects missed by small fixtures. The exclusions of task quality, latency and provider behavior are appropriate. Describe results as measurements of the selected traced simulation, with its synthetic tools, empty registry, response construction, trace/wire traffic, interpreter and profiling setup. Changes to tool bodies, streaming handlers, prompt builders and omitted extensions cannot be accepted on performance paths the replay never executes. “Tool choice” can be checked for consistency with the recorded sequence, but cannot be credited as a new model's quality.

`GODEBUG=gctrace=1` reports GC count and live heap at that replay's collection points, not a deterministic memory bound or live-session GC behavior. It is still a useful secondary observation with Go version, `GOGC`/`GOMEMLIMIT`, container limits and host contention recorded. The stored baseline repeats have 97/99/93 GCs and maximum live heap 1898/2450/2343 MiB; fixed repeats have 34/34/33 and 1213/1271/1272 MiB. Timing sensitivity applies to these numbers as well as RSS. The final stored profile is taken after the replay returns and retains only a few MiB, so its `inuse_space` is not the maximum live workload heap.

Treat allocation as profiled cumulative allocation for a pinned measurement scope. Profile parsing here confirms that the TSV's “GB” totals are actually GiB (§2.2). The baseline 299-step repeats stay within ±0.115% of their mean; fixed repeats reach ±0.279%. Thus “±0.2% across repeats” is not a universal tolerance. The fixed 200-step probe's first repeat is 22.12 versus 10.88/10.86 GiB, another reason to pin the runner setup before turning observational repeatability into a gate promise. Separate startup, extraction, oracle and response-construction costs from driver costs, or explicitly include them consistently.

Existing invariant families can run on the replay's actual execution bridge and trace, but list the families/coverage and declared omissions in each result. PLAN-003 §0.6 says the deterministic harness never reaches the conversation loop. Passing all applicable families at T0 does not verify input waits, TUI behavior, cross-turn lifetime, extension effects or streaming chunks. Assert expected observations so absent traffic is not a vacuous invariant pass. Recursion-depth claims likewise need a defined measurement phase and toolchain, with preprocessing/checker recursion excluded or named.

### D5 — return

Snapshots outside git and a private directory are good defaults. Implement the ignore rule before copying content: `git check-ignore .motoko/eval-corpus/test` does not match anything at this HEAD. Keep snapshot files, selected host excerpts, generated replay inputs, stdout/stderr and profiles inside a private corpus/result hierarchy; creating only the entry directory with mode 0700 does not specify the permissions/location of every derived artifact. Traced replay emits full `history_seeded` and `history_appended` payloads. Ordinary run output can therefore duplicate the private corpus unless the runner deliberately contains it. A request excerpt can select the needed request/result metadata without copying unrelated content-bearing host events. Define local retention/deletion, including copies; keep exporting/redaction unscheduled and default this corpus to local use pending that decision. Redaction would require fresh identities and fresh admission, not reuse of old hashes.

**Admission must be against independent evidence.** Hash the snapshot and supplementary excerpt, but also pin the selector/leaf/end, frozen expected observations, actual replay settings, tool/schema configuration where available, candidate scope, evaluator implementation and runtime. Require both source-chain validity and the appropriate independently sourced request checks. A no-log entry cannot graduate from parent self-agreement to live fidelity (§D3). Re-admission after canonical changes must retain the old identity/evidence and be approved as a change of experimental basis; do not let the candidate automatically replace its oracle. An output-identical performance refactor such as `de4b4f5` changes implementation identity, not the canonical bytes/semantics; distinguish those versions.

The draft's Consequences says the journal, host log and “digest definitions” are external and unwritable by the candidate. The definitions are in `phase_vocab.ail` and `journal.ail`, and the candidate repository also owns the proposed reader and driver. A gitignored local directory is normally writable by the same process. Specify a separately controlled runner/verifier that checks frozen observations with pinned trusted definitions and verifies corpus hashes, and keeps held-out evidence and acceptance pins outside the candidate's write scope. This is the RSI document's rule at `design_docs/planned/m-motoko-dst-recursive-self-improvement.md:57–65`; withholding a tag is not an enforcement mechanism.

Both named P1 entries have already been used in this investigation. The recent 57-step entry has stored baseline/fix runs. Tagging one `held-out` now does not make it withheld for the already measured fix or tuning performed with that observation. It may be held out for future candidates under a documented exposure rule, or choose a new independently withheld entry after the pipeline and safe sizing exist. Report per-entry outcomes and failures, rather than dropping non-admitted entries from transfer claims.

### D6 — return

**Make omissions cumulative.** T1's omissions column drops provider HTTP encoding, real tools, live GC timing and compaction even though synthetic chunks and resumed-entry chaining restore none of them. T2 and T2b show “—” despite retaining streaming-boundary, live-tool, encoding and timing omissions. Each tier should add coverage to the preceding tier and carry its remaining omissions; every result should state the actual configuration, not just a tier number.

**T2 needs a source of extension observations.** Existing Ports and the ExtPorts forwarding exemption make serving extension effects possible; they do not make a journal a recording of those effects. ADR-003 D1 explicitly excludes the trace, live Ports and emissions, and retained tool messages do not record every pre-step/solver/extension provider call, file read or effect. Name the additional recorded input, supported effects and missing-observation refusals, or leave T2 as an investigation rather than promising profile-faithful reproduction. The 028 dependency is not by itself evidence that this source session can be reconstructed. Enabling real hooks also requires demonstrating every reached effect is served; an empty/default effect queue must not fall through to a real subprocess.

**The compaction statement needs scope.** Retained history and per-call compacted payload are different, as ADR-003 retraction 4 states; a message-changing pre-step compactor normally causes a canonical request mismatch at T0. But the categorical “sessions whose pre-step compaction applied fail request fidelity” is stronger than the oracle: no-op/equivalent payloads or changes invisible to its canonical form need not fail. A trusted parent replay that reproduces the same wrong T0 request can also pass the no-log fallback. T2 may reconstruct a recorded compaction only with its additional required observations. Journaling only a compaction payload *digest* could detect disagreement, but cannot reconstruct the missing payload.

**The streaming event count is verified; the cost claim is not.** The host log has 801 `thinking_delta`, 57 `reasoning_delta`, and 693 main `provider_call_prepared` events. Nine extensions were loaded, not nine individual hook executions. The host may coalesce deltas; count alone says nothing about byte volume, callback frequency, parser work or allocation share. Say “few stored delta events in this log”; measuring a small streaming resource share requires a cost/bytes experiment. `chunked_prose_step` only synthesizes content chunks with fixed usage (`stub_step.ail:731–739`); richer usage/reasoning/tool/error streams need their own specified adapters and scope.

T1 can exercise fold → plan → resumed traced entry, as `journal_resume_dst` does, without rewriting resume. It still does not reach the production conversation loop. Operator input and true cross-turn threading/frame coverage remain ADR-002 D4 debt, which requires more than calling the resumed export. Preserve that distinction when saying “multi-run lifetime.”

### D7 — accept with corrections

The stored fixed 100-step run's RSS is 2749 MiB (2.685 GiB), substantially below the long run. It is one observation at one setup, not an upper bound for a candidate, a new metadata-aware adapter or a neighboring 100-step segment. “100 steps” does not bound memory without also pinning seed/message/tool bytes and trace/chunk volume. Baseline 100-step RSS was 4307 MiB. Calibrate the final reader/adapters/measurement runner again before choosing the gate and tolerance.

The handoff requires aggregate `/sys/fs/cgroup/memory.current` well under 12 GiB and no other work in flight before a sweep. It does not authorize a job whose own RSS is less than 12 GiB regardless of aggregate usage. In this container, guard cgroup current/max/headroom and coordinate exclusive heavy execution; host `MemAvailable` alone can miss the container ceiling. Monitor during the run and terminate on a conservative threshold, leaving headroom for profiles, other processes and a regressing candidate. An allocation budget checked after process exit cannot prevent OOM. Keep 299-step admissions outside sweeps and sequential, as proposed, but give them the same aggregate safety prerequisite.

Order the work as: preserve the existing prototype/evidence without executing it; build and type-check the strict reader, adapters and verifier with tiny cases; build the cgroup guard and calibrate short admission; admit a short dev entry and establish the gate/independent held-out process; then admit a long entry only under the stated exclusive resource conditions; finally T1. This resolves P0's urgency without putting P1's 299-step replay ahead of sizing. The handoff's pending P2D/P3ORD and operator-owned canaries/profile re-issues remain separate work; no sweep or repin is licensed here.

Like `depth_canary`, the budget gate must pin observation counts and fail closed on loader errors, missing profile, premature termination, divergence and changed measurement scope. The prototype prints refusals/results instead of a robust failure status and accepts a shortened comparison; it is not a gate. Demonstrate that the pinned short gate rejects the known allocation regression using stored evidence or a separately authorized bounded control, and protect repinning outside candidate control. Resolve the contradiction between P2 specifying 100 steps and Not decided leaving segment length open.

## 2. Claim audit

### 2.1 Evidence fidelity: independently rechecked

| Claim | Result | Qualification |
|---|---|---|
| 598/598 appended-message digests match | **Verified for the first 598** | Python independently reproduced `sha256(previous ++ canonical_message_frame(message))`, with raw content, tool calls and images; frame lengths count Unicode characters. The next replay message differs. |
| 300/300 payload digests equal the live host log, in order | **Verified** | Exactly one contiguous match in the 693 live request events, starting at zero-based provider position 351. The 300 hashes are nonempty, valid-shaped SHA-256 values and all distinct; live steps 0–299 have message counts 694–1292. All 300 system-prefix digests also match. |
| That means every provider request was reproduced | **Overclaimed** | All 300 `model` fields differ, and tool schemas/parameters/encoding are unchecked. The last matched request receives a fabricated terminal response in replay. |
| The run is 299 steps | **Correct only as a replay cutoff description** | The prototype serves 299 recorded turns, then one synthetic provider turn. It emits 300 provider calls, 599 appended messages and a successful terminal summary. The source snapshot ends mid-turn without a `run_finished` for r2.1. |
| Empty extensions reproduce the live profile | **No; only the checked projections match** | Nine loaded extension names are reported. The replay does not run their hooks or advertise their schemas. |
| All 1,756 candidate payload digests unchanged | **Tally not reproduced; equality verified more broadly** | The nine `fix_*.out` files corresponding to `results.tsv` contain **1,806** request digests, all equal to their matching baseline file in exact count/order. The two `runs-new` pairs add 142, for 1,948 total. Name the subset behind 1,756 or correct the tally. |
| Recent 57-step prefix is usable | **Prefix evidence verified** | `fix_57.out` has 58 request hashes matching the live log's first 58 and 114 reported chain matches; it includes the same extra synthetic terminal-call issue. It is not evidence of observed successful termination. |
| The recent longer pair validates replay generally | **No** | Both `prefix_84.out` and `fix_84.out` report chain divergence at message 114. Their 84 request hashes agree with each other, but live agreement stops after 58 requests. Parent/candidate agreement does not rescue source fidelity. |

The 300-match result is **meaningful but limited**. It is not an empty-hash check or a comparison of a log with itself: replay actually emits hashes after the traced entry builds each payload. It verifies that this simulated path preserves the recorded seed/assistant/tool sequence into the selected canonical request projection. It is also largely expected when fixed recorded responses rebuild the same retained history and omitted hooks do not change that projection. The chain check similarly verifies data plumbing rather than independent response behavior. Neither result validates paths/configuration bypassed by the adapter.

The prototype's `report` takes `min(2 * steps, len(appended), len(expected))` (`mem_journal_replay.ail:126–131`), and `first_divergence` treats either list ending as success (`:110–118`). The input has 599 expected digests; replay has 599 appended messages; Python finds the first mismatch at 598, the synthetic “replay done” assistant. The printed `MATCH compared=598` deliberately excludes it. Generalize neither the `2 * steps` assumption nor the tail truncation: a turn can append multiple tool results, feedback or replacements. Source r2.1 has a leading user entry after `run_started` and a final assistant with one pending tool call, reinforcing the need for explicit seed/cutoff selection.

A compact reproduction of the request check, requiring no execution:

```python
import json
from pathlib import Path

def prepared(path):
    out = []
    for line in Path(path).open():
        try:
            event = json.loads(line)
        except ValueError:
            continue  # stored stdout includes non-JSON measurement lines
        if event.get("type") == "provider_call_prepared":
            out.append(event)
    return out

live = prepared(".motoko/logfile/session_1789244855221-63164319c7d765ff.jsonl")
replay = prepared("/workspaces/motoko_agent-mem/.motoko/memfix/runs/baseline_replay_299_r1.out")
want = [e["payload_digest"] for e in replay]
starts = [i for i in range(len(live) - len(replay) + 1)
          if [e["payload_digest"] for e in live[i:i + len(replay)]] == want]
assert len(replay) == 300 and len(set(want)) == 300 and starts == [351]
assert all(a["model"] != b["model"] for a, b in zip(replay, live[351:651]))
```

### 2.2 Measurement table

Stored pprof protobuf samples were decoded directly with Python and their `alloc_space` values summed. No benchmark was rerun.

| Draft measurement | Verified source | Correction / limit |
|---|---|---|
| Synthetic 200-step allocation ~33 GB; real 150-step ~129 GB | TSV: 33.32/33.21/33.20 and 128.92 | These are GiB. Different seeds/workloads demonstrate a size-dependent gap, not a controlled synthetic-versus-real causal comparison. |
| Baseline 299: 323.0/322.7/323.4 GB | Profiles: 346.841/346.438/347.240 billion bytes | **323.02/322.65/323.39 GiB**. Rounded quantities are consistent; units are wrong. |
| Fixed 299: ~73 GB | Profiles: 78.191/78.353/77.946 billion bytes | **72.82/72.97/72.59 GiB**. Large reduction verified. |
| Baseline RSS 9.3/11.8/11.7 GB | TSV: 9280/11802/11703 MiB | Use **9.06/11.53/11.43 GiB**, or retain raw MiB. The draft mixes binary RSS units with decimal-style division. RSS itself was not remeasured. |
| Fixed RSS ~7.0 GB | TSV: 6969/7058/6987 MiB | **6.81/6.89/6.82 GiB**; same unit issue. |
| Fixed 100-step RSS 2.75 GB | TSV: 2749 MiB | **2.685 GiB**, one stored run. |
| ±0.2% allocation repeatability | Baseline mean 323.02 GiB, maximum deviation 0.115%; fixed mean 72.793 GiB, maximum deviation 0.279% | Supported as a rounded baseline observation, not as an unconditional gate tolerance. |
| Replay compresses hundreds of steps into a minute | Baseline 299: 121/144/83 s; fixed: 56/59/61 s | Approximately a minute for the fixed implementation; baseline takes 1.4–2.4 minutes. Both omit live waits. |
| 1.17 MB, 694-message seed | **Verified under Python default JSON serialization:** 1,170,593 bytes for 694 messages | Compact UTF-8 JSON is 1,148,108 bytes; content alone is 903,364 UTF-8 bytes. Specify the serialization and decimal MB convention. |

`git show de4b4f5` confirms the change is confined to the canonical message builder and claims byte-identical canonical output. Its commit body repeats the 1,756 tally; that is a claim source, not independent confirmation of the count. The stored baseline/fix output comparisons and profiles support the performance finding independently.

### 2.3 Every cited code coordinate at a0384e4

Paths below are under `src/core/`, except `scripts/`. All listed coordinates resolve correctly. Correct coordinates do not establish the broader conclusions in §1.

| Cited coordinate | Verified contents / qualification |
|---|---|
| `session.ail:2985` | `c2_loop` declaration. |
| `session.ail:4014` | `run_v2_session_traced`; normalizes provider and initializes policy before the shared traced entry. |
| `session.ail:4294` | `conversation_loop_v2_with_policy`; outside the deterministic replay entry's coverage. |
| `session.ail:4860` | `run_v2_session_resumed_traced`; policy initialization and `SessionResumed` emission, then continuation entry and trace/emission prepend. |
| `journal.ail:264` | `chain_digest_over`, final chain value over a list. |
| `journal.ail:292` | `chain_digests_over`, intermediate incremental digests. |
| `journal.ail:550` | Strict `messages_of_json` decoder. |
| `journal.ail:1174` | `all_entry_types`, ten types; no park/wake support at this HEAD. |
| `journal.ail:1558` | Pure `fold_journal(entries: [Json], leaf)`; path/decode/fold/validation, not driver replay. |
| `journal.ail:2002` | `journal_lines_of_records`, core twin constructing journal lines from actual wire records. Seeding expectations from source is legitimate; grading expected arrays against themselves is not. |
| `journal.ail:2112` | `plan_resume`, compatibility and resume planning; no need to modify it for an evaluator. |
| `phase_vocab.ail:299` | `canonical_messages`, one concat of per-message frames; normalizes content and omits images. Normalization is at `:275–284`. |
| `phase_vocab.ail:357` | `canonical_message_frame`, raw body **plus images** for the append chain. |
| `phase_vocab.ail:365` | `payload_digest` delegates to `digest_messages`; message projection only. |
| `test/stub_step.ail:69` | StepProvider includes `Ported(Ports)` and world-bearing variants. |
| `test/stub_step.ail:186` | `live_ports`; provider calls recorded stream API with separately supplied extension tool schemas/cache breakpoint (`:190`). |
| `test/stub_step.ail:271` | `scripted_ports`, consuming world script rather than history; F6 explanation immediately precedes it. |
| `test/stub_step.ail:554` | `recording_ports`, harness recording adapter bindings. |
| `test/stub_step.ail:731` | `chunked_prose_step`, text chunks with fixed 100/50 usage and stop finish. |
| `dst_program.ail:229` | `ExecutionProgram` type with initial world, manifest and recorded interactions. It is the artifact definition, not the driver entry. |
| `dst_replay.ail:395` | `strict_replay_findings`, pure strict interaction comparison. |
| `dst_replay.ail:793` | `world_state_of`, reconstructs a world from a program and starts its actual log empty; it is world reconstruction, not itself re-execution. |
| `rpc.ail:273` | `run_with_config`, runtime/configuration/prompt setup before session entry. |
| `rpc.ail:540` | `resume_from_journal`, ambient file read, fold, runtime/prompt rebuilding and resume planning. |
| `rpc.ail:591` | `main`, loads runtime and invocation config and calls `run_with_config`. |

The four unnumbered script references also resolve: `fold_live_journal.ail` is a file-reading fold caller; `journal_resume_dst.ail` exercises existing fold/plan/resumed entry; `run_depth_canary.sh` pins record counts as well as depth and requires a deliberate reason for repinning; `recorded_stream_server.py` is a small fixed SSE probe, not a journal server or tool-result interceptor.

### 2.4 Cross-ADR consistency and remaining overclaims

| Claim / obligation | Disposition |
|---|---|
| No journal format/writer/fold/resume change | **Compatible with the direction**, provided missing finish/cache/error/config observations are supplementary evaluator inputs or typed refusals. Do not amend ADR-003 to make D1 appear journal-complete. Moving request digests into the journal remains separately undecided. |
| ADR-003 O2 said nothing about evaluation | **Verified in scope**: it rejects replay for resume and retains reproduction. That absence is not evidence that these two projections are a complete evaluation oracle. |
| Compaction never rewrites retained history; checkpoint does | **Verified with ADR-003's qualification**: transient pre-step payloads differ from retained history; hybrid tool finish can also replace the tail via `replaces_previous`. D1's cutoff must honor all of these. |
| No frame gates move | **Achievable**, with reader-only core changes and adapter overrides that do not add helped requests or reset ordinal/pending. Recording live provider/tool/effect traffic through new production leaves would be a different decision. |
| ADR-001 extension exemption makes T2 faithful | **No**: the exemption declares uncounted forwarding coverage; it supplies neither recorded effects nor additional validity checks. |
| T1 covers the conversation loop / ADR-002 D4 | **No**: a resumed traced-entry fixture does not implement between-turn OperatorWait, model-change successor threading or production loop world ownership. PLAN-003 §0.6 and ADR-002 D4 keep that debt explicit. |
| Synthetic DST fixtures are all small | **Overbroad**: PLAN-003's measurements include `long_qwen_compaction_dst` with a 1,050,218-byte maximum seed event. The evidence demonstrates a missing realistic workload shape/scale, not the absence of any large existing fixture. |
| “The first change accepted on a journal replay” | **Historical description supported by the handoff/commit**, not proof of the proposed admission, withholding or independent-verifier process. That process did not exist for the experiment. |
| Request fidelity depends on host-log retention | **Correct**; capture the selected immutable excerpt at admission, rather than requiring indefinite retention of the entire source log. |

## Required changes for v2

1. D1: specify exact leaf/path/start/cutoff selection, successful-call/delta association, supplementary finish/cache/error metadata or refusals, and initial continuation/configuration state. Preserve incomplete observations without borrowing resume's repair as evaluation evidence.
2. D2: specify one-time initialization for `Ported`'s empty world; use cursor consumption on every attempted call, full supported responses and validated tool invocations; reject exhaustion/missing IDs rather than inventing output or successful status.
3. D3: separate source fidelity, parent agreement and unknown request fidelity; pin/check the applicable configuration and seed; define an admissible candidate class and bounded prefix measurement semantics. Remove the byte-identical/full-validity claims the existing hashes cannot support.
4. D4: state simulation/trace coverage and profiling scope; make GC/live-heap secondary and timing-dependent; correct GiB/MiB units and avoid turning three baseline repeats into a universal tolerance.
5. D5: establish independent runner/verifier and corpus/pin write protection; retain admission identities and exposure history; implement ignore/private handling for all derived artifacts before copying content.
6. D6: inherit omissions at every tier, identify additional extension/compaction observations, and replace the streaming-cost and categorical compaction claims with their verified scope.
7. D7: calibrate and guard short execution before long admission, use aggregate cgroup headroom/exclusive heavy execution, pin counts and show the gate rejects a real bounded regression. Resolve segment-length ambiguity.
8. Evidence/context: distinguish 299 recorded turns from 300 requests and the excluded synthetic tail; reconcile the 1,756 tally; call the observed nine extensions “loaded extensions”; narrow the claim that all existing synthetic fixtures are small.
