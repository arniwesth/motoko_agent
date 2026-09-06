# ADR-001 v2 review verdicts and independent re-measurement

Date: 2026-09-05. Overall verdict: **reject as written**.
HEAD: `62cb753c04b25ce28c52cbbed34896f384c2fac2`, branch `arniwesth/exit-intent-abi`.
Reviewer: **Codex, independent**. No authorship of either ADR version; no delegated review.

Reviewed: `ADR-001-sequencing-the-dst-architecture-caps.md`, v2, against the v1 review
(read first), RESEARCH, NOTE-165, NOTE-002, the 2026-09-05 learning, the specified 028,
027 and 009 documents, and the implementation and AILANG checkout named in the brief.
References to “ADR” below are to v2; source coordinates were re-read at this HEAD.

Method: source inspection, comment-aware counts, individual gates, a direct capture of the
eight-subject ledger fixture, and an executable model of the proposed ordinal operation.
The model is **not an implemented D2 or a mutation of production code**. It establishes the
arithmetic of the proposed check; the source and real fixture establish its integration
constraints. `AGENTS.md` is empty (`wc -l AGENTS.md` → `0`). No ADR, input document or code
was edited, and no commit or full `make dst` sweep was run. The workspace already contained
uncommitted work; this review makes no claim about concurrent changes by its owner.

Temporary evidence is under
`/tmp/claude-1001/-workspaces-motoko-agent/5090f574-5523-43c4-b8ba-867583589880/scratchpad`
(called **SCRATCH** below). Commands running gates used `TMPDIR=SCRATCH`.

## 1. Verdicts

| Decision | Verdict | Reason |
|---|---|---|
| C1 | ACCEPT WITH CORRECTIONS | The outside-world interpretation and rejection of a same-record observer stand; the enumerated drops are not exhaustive and the wire's effect is misidentified. |
| C2 | ACCEPT | NOTE-165's priority-3 row and NOTE-005's highest-consequence finding are fourteen days apart. |
| C3 | ACCEPT | NOTE-002 §4.5–4.6 supports both the runtime-profile distinction and shrinking's independent route. |
| D1 | ACCEPT WITH CORRECTIONS | Keep the sum and two ABI meanings, but preserve the raw checkpoint denominator, specify the exit zero, and reconcile per-run events with compatibility and D6. |
| D2 | **REJECT** | The observer can go red, but run attribution, the counted domain, event classification, and trace threading do not yet form one implementable acceptance contract. |
| D3 | ACCEPT WITH CORRECTIONS | Three asks plus adoption is right; the shipped work is partial and the claimed immediate coverage/handler payoffs exceed the cited designs. |
| D4 | ACCEPT WITH CORRECTIONS | Relocation and pilot sites stand; purity does not itself establish solver-fragment membership or exclusive emission by the interpreter. |
| D5 | ACCEPT WITH CORRECTIONS | The discarded successor is real; returning only the world or documenting a discard cannot satisfy D2's logical-event and terminal-trace obligations. |
| D6 | ACCEPT WITH CORRECTIONS | The summary mechanism is now described correctly, but D1 edits the loop and LedgerEvent too and contradicts its stated exemption. |
| D7 | ACCEPT WITH CORRECTIONS | The ownership split is reasonable; D2 needs these design corrections before an implementation PLAN, and administrative dispositions do not each have executable gates. |

## 2. Findings, most load-bearing first

### F1. D2 repairs the observer, but has not specified which run its shell assertion observes

**ADR says** (:371–384): “The helper emits before it returns”; “the shell extracts the
`world_request` ordinals from the stdout stream and asserts **no duplicate**,
**non-decreasing**, and **last emitted == final world ordinal**.”

**The central mechanism stands.** `C2LoopState` has `world_state`, `trace`, and `emissions`
at `session.ail:400, :412, :428`. The approval request is at :2445; its successor is stored
in `post` at :2454; :2456–2465 explains exactly the stale-`st` error. After D2's proposed
helper, let `st.world_state.ordinal = n`, let the approval queue be `[yes, no]`, and let
`post` contain ordinal `n+1`, queue `[no]`, and the appended request record. The wire
already contains `n+1`. Passing the whole `st` forward discards all of `post`, but cannot
undo stdout. The next instrumented request from `st` emits `n+1` again. V1's failure has
been repaired for this drop shape.

The explicit construction is retained in `SCRATCH/codex-v2-ordinal-model.py`. Running
`python3 SCRATCH/codex-v2-ordinal-model.py` printed:

```text
whole C2 drop: wire [1, 1] carried 1 approvals ('no',) gate False
drop then no request and no final line: [1] gate True
post-finalization drop: [1] final 0 gate False
hook-only drop: [1, 2] final 2 gate True
two independent honest runs: [1, 1] combined_gate False per_run_gates [True, True]
gap: [1, 3] final 3 gate True
```

**The existing shell pattern does not provide run attribution.** `Makefile:319–320` runs
`scripts/dst/run_ledger_parity_wire.sh`. That wrapper captures the entire AILANG process's
stdout and stderr (:46–54), requires eight `LEDGER_TRACE` lines (:97–104), **removes their
labels and concatenates all returned variants** (:111–113), then compares aggregate counts
per required variant (:122–137). Its wire count is `grep -c '"type":"<name>"'` over the
whole capture (:125), not a per-run `^{` parser. Counting all records works across resets;
checking ordinal uniqueness across resets does not.

I ran the underlying fixture directly:

```sh
TMPDIR=SCRATCH ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --entry main scripts/dst/ledger_parity_dst.ail < /dev/null > SCRATCH/codex-v2-ledger_parity_dst-raw.log 2>&1
```

It exited 0. Parsing JSON lines and grouping them at each `LEDGER_TRACE` line produced:

```text
104 JSON wire lines; session_ids = {'session_0': 104}
native 14; denied 13; pending 14; errored 6;
capped 10; dp7 21; handled 13; delegated 13
unlabelled tail: 0
```

Thus `session_id` demonstrably cannot select one run. `export_trace.ail:26–30` accurately
warns about this. A labelled final line **does have a precedent** at
`ledger_parity_dst.ail:330`. For that fixture's sequential layout, final markers could
partition preceding wire segments, but that is a **new parser rule**, not what the current
shell does. The ADR must require one marker per invocation and reject missing markers;
otherwise the no-next-request construction above has no comparison to fail. It must also
say how initialization requests before a run's first ledger record are attributed.

**Corrected text.** “The gate checks each invocation separately, identified by explicit
begin/end markers with a fixture-owned run label, or by exactly one invocation per
process. It validates the expected run count, each run's initial ordinal, exactly one final
ordinal, all JSON request records, and absence of unassigned records. A missing, malformed,
duplicate or truncated boundary is red. Within that frame, a stale whole-record successor
causes a repeated/backward ordinal or final mismatch. Equal ordinals in different runs
are valid.” Include two honest runs sharing `session_0`, a missing-final-line mutant, and
a dropped last request as acceptance cases. Do not use `RunSummary` or `done` as the
frame boundary: the current post-summary publish is precisely one of the requests under test.

### F2. The ordinal counts helper calls; exempt forwarders create no ordinal gaps, and the census subtraction is false

**ADR says** (:363–390): the helper is the field's “only writer”; “Strict `+1` is the target
once the forwarders are covered”; “until then a gap is attributed, not red.” It also says
(:415–417): “`ordinal − List.length(log)` at finalization is the count of driver-side
unrecorded requests.”

**Evidence.** Under the stated single-advancer design an exempt request leaves ordinal
`n` unchanged. The next helped request emits `n+1`, whether zero or a hundred exempt
requests intervened. There are no forwarder-caused gaps to attribute. The consistent
invariant is **strict +1 over helped requests now**. `[1,3]` passing the proposed weaker
check, demonstrated in F1, excuses an error in its own counted domain. Conversely, a hook
can consume a script entry, return its input token, and leave this ordinal perfectly
consistent; the model's `hook-only drop` is green even with a final line.

The log has a different domain. `recording_ports` (`stub_step.ail:554–571`) records nine
classes and omits file/path/directory reads. `ext_ports_of` forwards extension operations
into those same recording adapters (`session.ail:816, :1084, :1114` etc.), so the log
also contains extension requests which D2 exempts from its counter. Three recorded hook
requests plus two recorded driver requests give `ordinal=2`, `length(log)=5`, subtraction
`-3`, although the driver made **zero** unrecorded requests. The model printed exactly that.
Non-recording adapters and a seeded nonempty log make the universal formula still less
tenable. Only matched, per-run populations can be subtracted.

**ADR also says** (:390–391): extension requests “are `hook_guard`'s business for drops.”
That is the wrong gate. `dst_hook_guard.ail:169–184` checks whether an excluded tool hook
would be dispatched, **before** calling the hook. The allowed arm simply returns
`Ok(Rt.dispatch_tool_handle(rt, ctx, call))`; it never compares predecessor and successor.
It does not protect arbitrary hook-internal drops. `world_state_probe.ail:229–232,
:940, :964` instead has specifically consuming pre-step fixtures for two particular seal
terminal seams, as the session comment at :2621–2625 correctly says.

**Corrected text.** “The ordinal counts instrumented driver requests, not every world
interaction. It advances exactly once per such request, and the framed wire gate requires
strict +1 from the declared starting value. Exempt extension requests are invisible to
this check; their absence is a coverage limitation, not an ordinal gap. No total census
can be derived by subtracting the undifferentiated interaction-log length. A census needs
origin-aware matched counts, and successor coverage for hooks needs its own named,
distinguishing checks.”

### F3. The inventory feeding D2 both double-counts exemptions and omits the model-call indirection

**ADR says** (:385–391): enumerate “the 24 + 3 + 8, the three named-helper indirections,
the six `ext_ports_of` forwarders, and `:3385`”; the forwarders “cannot emit.”

**Evidence.** This command, with comment lines removed, returns **22** direct calls in
`session.ail`, not 24:

```sh
rg -n '\.(model_step|approval_read|clock_now|env_get|file_read|file_write|file_remove|path_stat|dir_list|dir_make|tool_exec|ext_effect_exec)\s*\(' src/core/session.ail \
  | rg -v ':\s*--'
```

The locations are `816, 939, 1084, 1099, 1114, 1119, 1133, 1148, 1153, 1164,
1420, 1423, 1529, 1927, 1928, 1929, 1930, 2445, 2730, 3016, 3126, 3385`.
The first ten already implement extension forwarding, including `ext_ai_step` at :816.
The last already is the post-finalization env request. Neither population is an additive
“plus” to that receiver census. The three `tool_phase` sites and eight `context_usage`
expressions do reproduce.

There are **ten ExtPorts forwarding fields**, in `session.ail:910–1178`, not six.
`ext/runtime.ail` dispatches hooks; it does not define `ext_ports_of`. A separate count of
`rg -n '\bext_ports_of\(' src/core/session.ail` gives six textual matches because it
includes the **definition** and five construction calls. Those are not six forwarders.

The blanket effect-row claim is false even for the existing `ledger_emit ! {IO, Trace}`:
`ExtPorts.ai_step` explicitly carries `{AI, IO, Trace}` (`types.ail:294`;
`session.ail:933`). It can perform both effects. `tool_handle` carries
`{IO, Process, FS}` (:407), so can write stdout, although it cannot call the unchanged
IO+Trace helper. The other eight rows are Env/FS/Clock only. There is a real effect-row
constraint; it is not uniform across all fields.

Most seriously, the driver model call is **`dispatch_step` at `session.ail:2676`**,
forwarding to `ports.model_step` in `src/core/test/stub_step.ail:705–713`. This is absent
from the ADR's three named indirections and outside the proposed three-file scan roots.
A scanner implementing the advertised census could bless an uninstrumented main provider
call. The pre-step chain at :2632 and tool-dispatch helpers at :2481/:2546, meanwhile,
can contain multiple requests; counting them again as requests would double-count the
leaves and change the meaning of `class`.

**Corrected text.** “Derive a de-duplicated inventory of leaf request operations and a
separate call graph of successor-returning helpers. Include `dispatch_step` and its
production dependency in `stub_step.ail`. Forwarder exemptions are per ABI field and
effect row; construction calls are not request sites. Aggregate helpers propagate
request evidence without acquiring another request ordinal.” The inventory mutant must
include an alias/forwarding escape, not merely one easily greppable direct call.

### F4. D2's two classification alternatives are not both legal, and strict replay does not hash all logical events

**ADR says** (:371–372): “A `WorldRequest` … goes through `ledger_emit` — wire and returned
trace, like every event.” At :407–410 and :578–579: logical “moves every replay digest”;
display-only loses the parity signal and otherwise leaves the ordinal gate standing.

**Evidence: emission and append are separate.** `ledger_emit` (`session.ail:335–342`)
returns `()` and does **not** append anything. `ledger_append`
(`phase_vocab.ail:604–606`) returns a new trace. The helper must explicitly perform both
and return the updated trace. “Like every event” is false: `SessionStart` is display-only
and wire-only (`dst_event_vocabulary.ail:395–400`), and two logical variants remain in
`d64_gap_register()` (`dst_invariants.ail:704–707`).

**Evidence: display-only does not merely lose a bonus.** The vocabulary defines Logical
as presence/order/content capable of changing an invariant result (:41–51), which is
the proposed purpose of `WorldRequest`. `parity_findings` calls `display_only_in`
(`dst_invariants.ail:946–950`); that function returns `DisplayOnlyInTrace` for any
display-only `WireRecord` (:854–865). Appending a display-only WorldRequest as part 2
requires is therefore red in existing invariants. Its display-only set is separately
pinned (:609–616, :823–831, :1828).

The brief's suggestion that count parity might include display-only records is **not
borne out**: although `trace_variants` prints every WireRecord, `required_rows`
(`ledger_parity_dst.ail:145–153`) filters to **Logical minus `d64_gap_register`**. The
shell checks only those `LEDGER_REQUIRE` rows (:122–137). Thus v2 is right that a
wire-only, display-only event gets no existing per-variant count comparison; it is wrong
that this alternative is compatible with its mandatory append, and wrong to treat
classification as a cost-only switch.

A new logical row needs its projection, vocabulary version/payload/classification,
sample/golden, truthful reachability flag, and Row 7 parity witness. If it is always
appended, it adds no gap-register entry. `make -s event_vocabulary` exited 0 and printed
`34 LedgerEvent variants == 34 vocabulary rows == 34 golden-pinned variants`; those pins
must move. This is different from inventing a new `Violation` constructor (none is needed).

**Evidence: “every replay digest” has no matching consumer.**

- `dst_replay.strict_replay_findings` (:395–396) calls `walk(StrictMode, …)` over two
  **interaction lists**. `compare_at` (:357–366) compares correlation, request projection
  and outcome; it neither classifies nor normalizes LedgerEvents.
- `strict_replay_dst.ail:737–752` compares `program.interactions` with `replay.world.log`
  and separately checks terminal success/failure. Its trace witnesses include provider
  steps (:805–813); it is not a generic normalized-event digest.
- The separate discovery determinism check compares trace lengths and record **variant
  names** (`dst_invariants.ail:1742–1773`), not every payload. Without an added comparison,
  two WorldRequest records with different ordinal/class payloads have the same key there.
- `dst_corpus.trajectory_key` (:174–181) hashes interactions only.
  `dst_persistence.encode_body` (:543–588) serializes initial world, manifest, bounds and
  interactions; **no LedgerTrace** is serialized. A vocabulary-version bump in the
  manifest can change newly encoded program bytes regardless of logical/display-only
  classification. Merely emitting a new event cannot change an interaction-only key.

**Corrected text.** “WorldRequest is logical under the current D6 criterion and the helper
explicitly appends it as well as emitting it. A wire-only alternative requires a stated
change in the observation contract, not just a different classification label. Price
each affected artifact: returned trace/export, vocabulary and manifest version,
serialized program bytes, and interaction trajectory key. Do not claim universal digest
movement or payload-sensitive replay checks which the tree does not implement.”

Also narrow :383–384's “parity goes red on **any** drop that spans a request”: it applies
when the returned request record is lost, the fixture reaches that request, and the
logical row is required. Carrying `post.trace` with `st.world_state` can leave count parity
green while the ordinal gate fails. The current shell only runs its eight subjects.

### F5. The one helper has no stated state/trace interface before initialization or inside resolution

**ADR says** (:363–375): every driver request passes one helper, which stores its successor,
emits, appends, and returns. The audit covers all eight `context_usage` requests.

**Evidence.** Those requests happen in functions with closed `{Env}` or `{Env, FS}` rows
(`context_usage.ail:49, :88, :110, :129, :164`). `ContextReader`'s fields carry only Env and
FS (`ports.ail:954–957`). `session_policy_init` likewise has `{Env, FS}` and returns only
`{ policy, next_state }` (`session.ail:1923–1925`). `derive_session_id` has `{Env, Clock}`
(:1419), and its result is needed to establish `session_id` at :3015–3017.

The entry chain resolves policy at :3044, then derives identity and reads the initial
clock at :3015–3016, **before a C2LoopState exists**. `c2_initial_state_with_counts`
(:709–730) initializes `trace: empty_ledger_trace()`. Instrumenting these reads and then
retaining that constructor silently discards the entire initialization request trace.
Putting the IO+Trace helper inside the unchanged ContextReader closures does not type-check;
calling it after the reads requires widening the resolver's row and threading its evidence.
Putting it in `context_usage` by importing `session` also creates a module cycle, since
session already imports context_usage. None of this is answered by the count of literals.

**Corrected text.** “Name a lower-level request-evidence carrier/helper usable before
C2LoopState construction, its IO/Trace row, its emission callback/module ownership, the
bootstrap run label, and its returned trace. Widen and thread the resolution and policy
initialization paths explicitly, then seed the loop trace from that result. Keep one
increment per leaf request; do not silently exempt initialization.” This is feasible
additional design work, not an impossibility theorem about a helper.

### F6. The post-finalization red is real; its proposed repair must also preserve the terminal trace, and it is not the only reachable drop

**ADR says** (:397–400): after instrumenting publish's env read “the final world … is one
behind the wire”; D5 (:479–480) says the exit end “threads the render's successor back
into the returned world or records, at the call site, why it cannot.” Consequences (:550)
say D2 makes “one existing production site red by design.”

**The predicted final mismatch stands.** The Finalize arm calls `c2_finalize` at
`session.ail:2368`. That function reads a clock and returns `world: reading.next_state`
(:1529–1533). The arm then calls publish with `finalized.world` as `let _ =` (:2372),
emits done (:2373), and returns **the unchanged `finalized`** (:2374). Publish always
reads the manifest-path env key (:3385), passes `named.next_state` into the exit context
(:3400, :3403), and returns `()` (:3410). Thus the predicted n-versus-n+1 comparison is
real once this read is helped, including when no manifest path is configured.

`TracedSessionResult.world` is at :178. `dst_execution.execution_of` copies it verbatim
into `ExecutionUnderTest.world` (:100–118); the associated DstResult is constructed from
`run.result`, `run.trace` and a projection of `run.world.log` (:128–129). DstResult itself
has no WorldState field (`dst_result.ail:93–98`): a fixture should print `run.world.ordinal`
or `execution.world.ordinal`, not expect to recover the ordinal from the DstResult log.

**The green repair is incomplete.** The actual render-outcome discard is deeper than
the ADR locates it: `ext/exit_manifest.ail:182–205` returns a **bool**; at :191 it obtains
`rendered = dispatch_exit_intents(...)` but only reads `rendered.intents`. Returning a
world from the session wrapper alone cannot recover a successor already discarded there.

For a logical WorldRequest, merely appending the publish request to `finalized.trace`
also appends it **after RunSummary**. `terminal_summary_findings` and `after_summary`
(`dst_invariants.ail:788–806`) then produce `RecordAfterTerminal`. Returning only the
world cures final ordinal equality but leaves the request missing from returned trace.
A comment excusing either discard satisfies neither check.

There is another reachable drop at **`session.ail:2730`**: the non-retryable provider-error
path calls `st.provider.env_get(st.world_state, "MOTOKO_CAPTURE_FAILED_PAYLOAD", "").value`,
discarding its successor. It even starts from `st.world_state`, before the provider's
`exchange.next_state`. The terminal call at :2759 takes `exchange.next_state`, not the
env successor. Once leaf requests are helped, the env request can repeat the provider
ordinal (or go backwards after a consuming pre-step chain), and its own successor/record
must be carried too. This is in the deterministic loop, unlike :3265.

**Corrected text.** “Show the post-finalization mismatch before fixing it. Then perform
publish/render before the finalizing clock and terminal RunSummary, thread its world
and request trace through both exit functions, and preserve publication-before-done.
Alternatively specify another ordering that demonstrably preserves the terminal trace.
An explained discard remains a D2 failure. Also cover the non-retryable payload-capture
env read at :2730. Treat outer live-loop publish calls at :3294/:3479 as separately
framed/out-of-scope lifecycle operations.”

The :3265 reachability exclusion **stands**: `conversation_loop_v2_with_policy` is private,
reads stdin (:3245), and is called by the live conversation wrappers and itself. The traced
entry points call :2994's helper and `c2_loop` directly (:3021, :3045). No deterministic
profile enters the multi-turn stdin loop. This does not excuse :2730.

One deferred D5 condition also needs correction. ADR :483–488 says **both** new fault
classes enter the required list when the **first** lifecycle end is driven. Driving
registration alone does not make `exit_action_unexecutable` reachable, especially while
exit execution remains in the TUI. 009 ADR-001 :816–830 requires a production outcome,
recovery branch, transition and explicit applicability/waiver for each class.
`dst_fault_catalogue.ail:216–228, :288, :835` currently has four boundaries and an
eleven-class pin. Correct the trigger to **each class's own driven boundary and reachable
outcome**, or explicitly record the other class's conditional waiver; do not promote
both coverage claims merely because one end has been implemented.

### F7. D1 correctly separates ABI meanings but still conflates checkpoint denominators and leaves the exit constant unspecified

**ADR says** (:288–308): the raw function serves the named ordinary contexts and exit;
the working-budget function serves pre-step; `should_checkpoint`'s two callees take
`InputBudget`. Rule 4 promises “No behaviour changes under `Bounded`.”

**The two ordinary meanings stand.** Raw policy limits reach approval (:2466), tools
(:2510), post-step (:2774), and RPC's budget/system contexts (:142, :337, from resolutions
at :128/:323). Pre-step computes `max(0, effective_input_limit(raw) - pinned_tokens)`
(:2626–2631). The seal currently subtracts the output allowance internally
(`phase_vocab.ail:145–153`). Keeping EmptyStopFinalize's **raw** int preserves that
field's projection (:803) and golden (:1244), and the status's raw limit int can likewise
be projected unchanged. Moving the seal argument to the sum is internal, not an ABI change.

**The checkpoint denominator is raw today.** `should_checkpoint`
(`step_machine.ail:85–90`) passes `pol.compaction.context_limit` directly.
`history_usage_percent_calibrated` and `checkpoint_would_relieve`
(`phase_vocab.ail:387–394`) both take `int`; they use it without subtracting output
reservation. The only proposed producer of InputBudget is
`effective_input_limit(ContextLimit)`, whose Budget is net of 65,536 tokens. Substituting
that value changes policy under Bounded. The retained model prints a concrete boundary:

```text
checkpoint threshold=90, estimated_tokens=220000, raw=262144: raw_pct 83 net_pct 111
```

With checkpoint relief true, this changes whether the checkpoint branch is taken.
The fix needs a raw-denominator measurement interface or an explicitly different raw
budget constructor; “take InputBudget” is not enough to preserve the existing meaning.

`rg -n 'history_usage_percent_calibrated|checkpoint_would_relieve' src packages scripts
-g '*.ail'` finds their definitions/internal call in phase_vocab and the two calls in
step_machine, with no extension/script callers. However, the lower helper
`calibrated_usage_percent_anchored` **is imported by an extension**
(`packages/motoko-ext-compaction-ai/compaction_ai.ail:16, :32–37`). Do not change that
shared int signature incidentally while migrating core wrappers.

The exit context is **an explicit `context_limit: 0`** (:3399), not a call to
`mk_v2_ext_ctx`, and its function has no SessionPolicy argument (:3362–3379).
Passing the run's Bounded limit via the proposed raw projection would change extension
behavior there. To preserve zero, retain a named exit-context exception or explicitly
model “no window supplied for this context”; silently inventing Disabled would contradict
the rule that Disabled is a declared user opt-out.

**Corrected text.** “Preserve raw denominators for checkpoint/status measurement and net
input budgets for pre-step/sealing. Keep the existing extension-facing int helpers where
packages call them. Preserve exit's zero explicitly and name why it is zero. There are
four `mk_v2_ext_ctx` calls, plus one exit record literal and two RPC record literals;
`:2630` is the pre-step arithmetic, `:2631` its one context-construction call.”

Finally, the raw projection's proposed `result >= 0` and `Bounded → result == raw_window`
contracts (:354–357) cannot both hold for unrestricted `Bounded({raw_window: -1, …})`.
Name the positive-window constructor/requirement or change the contract. The public sum
sketch itself enforces neither positivity nor the declared scenario-class semantics.

### F8. D1 can observe status through DST, but its compatibility, per-run and D6 statements contradict one another

**ADR says** (:317–327): live per-run data extends SessionStart; traced data is a new
event; a display-only choice leaves the arms asserting “on the status surface.”
It promises the “same trace before and after” for Bounded (:333–336), “no wire schema
change” (:542), and exemption from D6 (:503–504).

**Status reachability stands and has an existing fixture.** `runtime_status_json`
(:555) is called from the real `c2_loop` RunTools builtin lambda at :2542–2546, under the
MotokoRuntimeStatus name check. `scripts/dst/runtime_status_tool_dst.ail:221–233` drives
`[status_step(...), prose_step("done")]`, reads `traced.result`'s tool message and asserts
its JSON (:189–203). Direct execution with the same caps as F1 exited 0 and printed:

```text
scenario=runtime_status.basic ok
scenario=runtime_status.mixed_pending ok
runtime_status_tool_dst PASS count=2
```

Its Makefile home is `compaction_dst` (:2159–2162), not a standalone
`runtime_status_tool` target. I first tried that nonexistent target (exit 2), then ran
the specified script directly; I did not run the much larger compaction target.
Thus the ADR needs to name **this witness**, not invent a new status surface. Each arm
must actually request the builtin and parse the correlated returned tool message.
If the per-run event is display-only, asserting the status field alone does not establish
that the promised per-run wire record was emitted: capture and assert that channel too.

The status currently emits three numeric zero percentages for unknown limits
(`session.ail:566–570, :591–599`). Adding `context_limit_source` alone does not implement
Arm A's “usage renders as unmeasured, not `0%`.” Specify how those three fields or their
consumer represent unknown; preserving the raw context_limit field does not imply that
all percentage handling stays unchanged.

**The live/traced split is not disjoint.** There is one production SessionStart emission
expression (:3288), but it executes per follow-up `user_message`, not once per process.
The live initial turn at :3478 calls the **same traced helper** and emits no SessionStart.
Follow-up turns emit SessionStart and then call that helper (:3293). Adding a new event
at the common helper therefore also reaches live turns; extending the banner does not
by itself cover the live initial turn and may produce two “per-run” records on follow-ups.
Choose one common resolved-policy record and state the banner relationship.

**The three compatibility promises cannot all stand.** A new logical per-run event
changes the returned trace even for Bounded; extending SessionStart changes its wire
payload and golden (`phase_vocab.ail:809, :1250`). The vocabulary explicitly treats a
payload/schema/classification change as a version change (:107–111). Even if
EmptyStopFinalize is unchanged, **D1 as a whole is not wire-schema-neutral**. If the new
event is display-only, it changes wire/version surfaces while leaving the returned trace
without that record. Rule 4 must identify a comparison projection excluding deliberately
added telemetry, and separately test that telemetry.

D6 says **any work changing `Ports`, `c2_loop`, or `LedgerEvent`** waits for the baseline
(:497–499). D1 changes the context-limit expressions in c2_loop and adds a LedgerEvent
(:320–326); saying it changes neither Ports's “shape” nor the loop's “structure” switches
the criterion mid-rule. Rule 4 already says “D6 applies.”

**Corrected text.** “Run the baseline before D1 as well as D2. Emit one resolved-policy
record at the shared per-run entry, including initial live and follow-up turns. The
acceptance fixture explicitly polls MotokoRuntimeStatus, distinguishes Unknown from
Disabled in the returned message, and independently witnesses the per-run record.
Bounded policy decisions and existing event payloads remain equivalent under a named
projection that excludes new telemetry; new wire fields/events are versioned and tested.”

Two remaining design details should be named in the PLAN: final Unknown reasons must
describe the **failed resolution chain**, not report ProfileConfigAbsent when catalogue
fallback successfully returns Bounded (:330; `context_usage.ail:165–167`); and the new
types need an acyclic home. Defining ContextLimit in context_usage then importing it into
phase_vocab would close `context_usage → ports → phase_vocab → context_usage`
(`context_usage.ail:9`, `ports.ail:44`). A small leaf module avoids that cycle.
`rg` found no `CompactionPolicy` or `StepPolicy` reference in `packages/**/*.ail`; carrying
the sum inside these core policies does **not** inherently leak it into ABI 7.0.

### F9. Several “re-measured” numbers inherited the v1 review's counting errors

**ADR says** (:40–43, :545): “17 `WorldState` literals in 6 files”; (:313–316, :554):
“38 + 6 fixture signatures.”

**Evidence and corrections.**

| Claim | Re-measurement and corrected statement |
|---|---|
| 17 WorldState literals, six files | `rg -n 'clock_ms:' src scripts -g '*.ail'` prints 17 **textual matches**: three full literals, eight record updates, the WorldState field declaration, and five `initial_clock_ms` matches. The latter include parameters and an ExecutionUnderTest field. |
| Every such literal gains a field | Full WorldState constructors start at `ports.ail:725`, `ext_world.ail:544`, and `ext_world.ail:651`: **three full literals in two files**, plus the type declaration and serializer. The eight `{ base \| ... }` updates preserve unspecified fields; they do not each require an ordinal initializer. Replay's :808 and :1133 explicitly update `empty_world_state()`. |
| mk_policy 18, mk_state 16, mk_state_with_messages 4 call sites | Comment-aware `\bNAME\(` search excluding the `func NAME(` declaration gives **17, 15, 3 call expressions = 35**, respectively. The third includes the mk_state-to-mk_state_with_messages delegation at :179. 18/16/4 includes each declaration. There are three definitions, not 38 signatures. |
| Six script constructors | Six definitions reproduce at the stated coordinates, but `state_with_pressure` (:49) and `state_from_msgs` (:313), like step_machine's state helpers, use the int as **last_input_tokens telemetry**, not a policy limit. `step_machine.ail:167` shows that directly. They should not mechanically become ContextLimit parameters merely because the old parameter name is context_limit. |
| 198 hand-threaded next_state sites, 185 + 13 | Per-file line counts reproduce: session 90, ports 64, context_usage 18, tool_phase 13; the remaining 13 are driver_only 4, compose 3, no_ops 2, fault_catalogue 2, ext_world 1, rpc 1. But **31 of 198 are comment lines**; the remaining 167 still include types and expressions with different roles. Call these textual lines, not 198 request sites. |
| phase_vocab fan-in 15 | `rg -l '^import src/core/phase_vocab\b' src packages -g '*.ail'` gives **15**, of which two are under src/core/test. Stands. |
| session/tool-phase/DST sizes | Python line counts reproduce **3,813 / 642 / 20,858**; c2_loop remains **682** lines. Stands. |
| 37 Violation constructors and no new one for D2 | Counting `^  [=\|] ` in the Violation declaration gives **37**, matching `sample_violations`' test at :1887. A shell-only check needs no additional Violation constructor. Existing matches/pins can still need changes for a new event. |
| 29 adapters, 12 Ports fields | Counts reproduce from `^export func (scripted\|ambient\|recording\|generating\|world\|virtual)_` and the Ports declaration. Stands; these are not 29 independent places to increment. |

These corrections reduce the record-construction work; they **do not erase** F3–F6's
missing request/evidence plumbing. Repeating the v1 review's numbers is not a substitute
for re-measuring the unit being counted.

### F10. D3's paths and estimates stand; its shipment scope and payoff claims need narrowing

**ADR says** (:431–438): handlers make “§2.A, §2.B, §2.D collapse into `handle … with`”;
scope narrowing “converts [20 entries] to measured”; replay contracts “shipped in v0.30.0.”

**Evidence.** The three paths, Status lines and estimates reproduce directly:

| Local AILANG design | Lines read | Result |
|---|---|---|
| `planned/v1_1_0/m-effect-handlers.md` | :3–6, :189 | Planned; target v0.21.0 Phase 1 → v0.22.0/v1.0.0; ~30–40h Phase 1. |
| `planned/v1_0_0/m-effect-scope-params.md` | :3–6 | Planned; ~16h (~2.5 days). |
| `planned/v1_0_0/m-effect-clock-net-fs-modes.md` | :3–6 | Planned; ~20h (~3 days). |
| `implemented/v0_30_0/m-effect-replay-contracts.md` | :3, :24–28 | **LANDED (PARTIAL)**: M0–M5, Rand dispatch pilot, Rand+AI contract labels; Clock/Net/FS rows belong to another sprint. |
| `planned/v1_0_0/m-effect-refinement.md` | :3, :18 | Decomposed; the P3 Planned row is stale. |
| `planned/m-motoko-fork-disposition.md` | :40 | R34 is the resolved-gates broadcast absence row. |

`rg -n 'ReplayContract|mode=|AILANG_SEED|replay/contracts' src packages scripts -g '*.ail'`
returned no matches. A broader replay-contract search returned only Motoko's prose
comments about its own strict-replay contract, not registry adoption. That supports an
**evaluation/adoption entry**, not a claim that Motoko already uses the shipped registry.
It also does not imply the absence of bare effects internally dispatched by AILANG.

The scope design freezes **Rand + AI only**, flat grants with unscoped wildcard behavior
(:61–95, :163); FS/Net scopes are future work (:194). It supplies neither a demonstrated
per-hook production grant installation nor measurements of all twenty existing assumed
entries. The handlers design's :179–195 describes language/runtime work, not a proof that
Motoko's corpus, invariants, schema compatibility and pure step decomposition disappear.
20,858 is the size of all dst_ modules, not a measured handler-replacement subset.

**Corrected text.** “File three requests and evaluate the partially shipped Rand/AI
replay-contract registry. The local estimates are upstream design estimates, not Motoko
integration estimates. Scope grants and handlers may reduce selected boundary plumbing;
list candidate consumers and measure adoption before claiming twenty coverage conversions
or deletion of the complete userland architecture.” Replace :442's “the week they ship”
with an adoption objective, not a scheduled measurable payoff.

### F11. D4, anchors, D6 and the remaining gate claims still overstate their mechanisms

**ADR says** (:463–465): “`step` is pure and in fragment after 028 W1–W3; the interpreter
alone carries IO/Trace; sole emission is then a type property.”

The **placement and pilot facts stand**: `tool_phase.ail` is 642 lines; exports at
:304/:459; requests at :413/:414/:421; the driver dispatch call is :2546 and RunTools
occupies :2495–2590. It already imports phase_vocab without importing session.
028 PLAN-002 items 2–3 and their amendment markers exist. They help sequencing, not
compilation of this pilot. One marker still calls the split a “precondition” (PLAN-002
:49–50), so the future amendment should agree with the ADR's corrected decision.

**But the goal is not earned by purity.** Removing effects from step prevents that
function from emitting. It does not establish that all its calls/data are supported by
the solver fragment, and it does not prevent IO-capable hooks, ports or callbacks from
printing. `ExtPorts.ai_step` and Compactor rows explicitly permit IO/Trace
(`types.ail:294, :1108`); existing `ext_ai_step` has an IO callback
(`session.ail:809–816`). `verify_core` proves eleven individual contracts, not this future
step. Name a fragment classification/contract gate and an emission-ownership mechanism
before demoting parity to something less than evidence. D4 should state these as pilot
acceptance goals, not consequences of W1–W3.

**ADR says** (:536): “`make anchors` re-baselines every pin in the file.” It does not.
`Makefile:2744–2745` executes `tools/predicate-anchors/anchors.sh`; its :384–385 loop
**checks** five pinned lines `1164 1423 1529 3016 3126`. It never edits the pins.
The seven-file cascade list (:285–293, six consumers plus session) and “contract-frozen”
sentence (:301–303) reproduce. The script's “AN EIGHTH TIME” at :309 is a historical
counter, not the total number of subsequently recorded movements. Correct the verb to:
“Re-baseline every moved pin manually/with the chosen edit tool, then run make anchors;
run attribution_table and the profile gates to derive the required reissues.”

**D6's corrected known-red mechanism stands.** `DST_KNOWN_RED :=` is empty
(`Makefile:493`). `sweep_summary.sh:82–86` computes listed targets that passed; :106–111
prints a NOTE; `Makefile:512` returns the original rc. A listed target passing does not
fail the summary. The full sweep remains unestablished here. D6 is a workflow precondition,
however: the Makefile does not prevent editing a boundary before running the baseline.
The PLAN must retain the baseline evidence; do not call that precondition automatically
enforced by the summary script. Apply it consistently to D1 (F8).

**Missing named gates / escape clauses.** The universal statement at ADR :210–212,
“each decision states the gate that goes red if it is violated and the fixture that proves
the gate can see,” is false for administrative D3/D7, D4's solver/emission end-state, and
deferred D5. D3 has deliverable evidence, D7 has ownership dispositions; that is acceptable
when named honestly. D4 needs its pilot gates. D5's comment alternative cannot waive D2.
D2's :580–583 fallback explicitly permits landing without the derived site audit: say
that this drops the **no-bypass gate**, and restrict the coverage claim to helped sites.
Calling parts 1–3 a complete gate against arbitrary request bypass would reintroduce
the learning's §7 fail-open parser problem.

**Options considered.** No need to resurrect v1's rejected same-record design or accuse
the stated inside-world interpretation of being RESEARCH's only interpretation: C1 now
states the ambiguity fairly. The limit options and D4 placement options are real choices.
Two comparisons remain unfairly loaded: “all forwarders cannot emit” overstates why they
must be excluded (F3), and logical-versus-display-only is presented as a cheap corpus
tradeoff while omitting its different validity obligations (F4). D2-4's “parts 1–3 are
unchanged by D4” is a proposed preservation constraint; it is not demonstrated for an
interpreter, request framing, initialization or lifecycle that have not been designed.

### F12. The sixteen Retractions mostly correct v1, but several repeat or over-correct its evidence

The v1 quotations here were checked against `REVIEW-adr001-verdicts.md`'s quoted passages,
not a reconstructed v1 ADR. The retraction-first form correctly follows 027 ADR-001
§Retractions (:44–72). This table accounts for **all sixteen** entries.

| Retraction | Verdict against v1 review and tree |
|---|---|
| 1, “unrecorded keyed lookups” | Correct: the four WI-D4 comments at session :2327–2346/:2456–2465/:2501–2509/:2594–2602 describe removed resolutions; no request remains at those sites. V1 review F2 accurately quoted the error. |
| 2, four immediate violations | Correct: no request means no new ordinal transition or red. V1 review F2 stands. |
| 3, trace survives whole-record drop | Correct: C2LoopState fields and stale-st approval example establish v1 review F1. |
| 4, high-water mark withdrawn | Correct withdrawal; the replacement's actual reach is F1–F6 here. |
| 5, 29 adapter increments | Correct withdrawal: recording_clock/env/file_write/approval wrap the underlying functions at ports :1550/:1570/:1630/:1719. Per-layer increments can double-count. |
| 6, encounter-ordinal anticipation | Correct: ports :219 anticipated the interaction-log ordinal, assigned at :1532. |
| 7, exactly two erasures | Correct about raw/pre-step/wire/seal/status surfaces; incomplete about checkpoint semantics, exit zero, and the mistaken context-construction count (F7/F9). |
| 8, tiny fixtures cannot be written | Correct: naming Bounded does not prevent a small or invalid raw number. Keep the correction; do not imply arm naming prevents later arithmetic from changing that fixture's behavior. |
| 9, no resolved-policy event | **Over-corrected wording.** SessionStart exists, but its fields are task/model/mode, not resolved policy (`phase_vocab:585`). The literal v1 sentence about no resolved-policy event was true; the useful correction is “an existing banner can be extended.” It is also absent from the initial live turn, not just DST (F8). |
| 10, fail-closed label | Correct: 028 ADR-001 requires Err→Reject and accepts blocking; D1 instead names non-blocking measurement failure. |
| 11, shipped fourth ask/R34 | Correct disposition and path; preserve **LANDED (PARTIAL), Rand pilot + AI labels**, not an implication of full per-effect adoption (F10). |
| 12, mechanical preconditions/tool phase file | Correct: the file and dispatcher already exist; inspect the lingering PLAN marker too (F11). |
| 13, passing known-red fails summary | Correct: printed NOTE, unchanged exit status (F11). |
| 14, delete WI-D4 comment | Correct withdrawal: an ordinal says nothing about stored-versus-fresh policy equivalence. |
| 15, grounding errors | Driver/result distinction and 15 importers corrected; “everything else reproduces” under-corrects the fixture, literal and request-site counting errors (F3/F9). |
| 16, re-derived costs | Higher allowance is sensible, but copying F11's incorrect site counts is not a fresh derivation; see F13. |

Also correct the v2 opening (:4–6): the v1 verdict table rejected **C1 and D2**; it accepted
D1 with corrections. “Two of its decisions could not go red” is not what that table or
the surviving D1 acceptance says. Write “D2's designed observer and its proposed
four-site red demonstration failed review; C1 contained factual errors.”

### F13. Costs should follow the corrected interfaces and gates, not the copied constructor counts

**ADR says** (:553–558): D1 5–8 days, D2 4–6 after D6, D3 and D6 half a day each,
10–15 total; “38 + 6 fixture signatures, three arms and two contracts.”

These are estimates, not facts a gate can prove. My replacement estimate, based on the
source obligations above, is:

| Work | Review estimate | Basis |
|---|---|---|
| D1 | **5–8 days**, provisional | Keep the ADR's allowance. Less mechanical fixture work than claimed; compensate for separate raw/net arithmetic, the acyclic type home, new wire/version surfaces, status witness and checkpoint boundary control. D1 actually lists **three** contract candidates at :354–357, not two. |
| D2 | **6–9 days after the design corrections and D6**, provisional | Three full world literals rather than seventeen, but add complete leaf inventory, bootstrap/resolve trace threading, per-run shell framing and malformed/missing-marker controls, logical vocabulary integration, two production drop repairs and terminal-summary preservation. Four to six days is not supported until these interfaces are concretely scoped. |
| D3 | **Half a day plus owner filing/adoption investigation** | Three records and a bounded evaluation entry; do not include an unperformed integration study as free filing. |
| D6 | **Half a day for baseline capture/disclosure, plus unpriced repairs** | The observed historical sweep time can justify run time, not the cost of each red. No full sweep was run here. |
| Cluster | **12–18 working days**, excluding standing-red repairs and substantial replay-contract adoption | Arithmetic range for D1+D2+D3+D6 above; not a delivery commitment. D4/D5 execution remains outside it except the exit-path repair required to complete D2. |

The anchor cascade is a real cost, but putting two separately swept commits on one branch
does not by itself pay it once (ADR :535–536): if each commit moves pinned lines, each
commit needs coherent pins to pass. Sequence edits so one lands final positions or budget
both updates. Gates, not branch count, decide the work.

## 3. Additional prose corrections and limits of evidence

These sentences are not additional invented defects; they delimit claims which the
source inspection did not establish.

| ADR sentence | Evidence and corrected wording |
|---|---|
| :30, “The wire is an AILANG Trace effect”; :34, “in-process wire capture … rejected” | `session.ail:222–224` calls `println` under **IO**; :335–342 sends every wire JSON there. The separate `emit_trace_event` (:280–288) only calls Trace.event for session_start/run_summary (:226–228). WorldRequest as proposed would not reach Trace.event. The export header repeats the Trace description, but the implementation is authoritative: “The durable wire observer is stdout IO; the exporter rejected using that stream as its trace source.” |
| :17, “No RESEARCH §4 item has been started; no Linear issue names one” | NOTE-002 §2 records an earlier tree/Linear search. This review can confirm absent ordinal/runner/interpreter symbols in the reviewed tree, not current external issue state. Attribute the Linear claim to that dated search instead of labelling it independently verified at HEAD. |
| :368, a missing codec field makes the gate fire “on every run” | `world_of_json:543–553` has per-field fallbacks and the token roundtrip is :562–567. Missing serialization would reset a newly added ordinal if decoded with the same zero fallback. But not every run dispatches a hook with a positive ordinal or makes a subsequent helped request/final check. Require a distinct nonzero round-trip fixture; say “can silently reset at decoding and is detected when a covered observation follows.” |
| :349, Unknown and Disabled “project to the same 0 at every ABI and budget site” | They project to 0 at the ABI. D1's budget result is **NoBudget(reason)**, not an int 0 (:297–299). Say “same ABI int and same non-enforcement policy, with distinct reasons retained in InputBudget.” |
| :542, D1 “adds no wire schema change” | Only the EmptyStopFinalize int surface stays unchanged; SessionStart's payload and the new event are separate schema work (F8). |
| :560–565, the gate “names the ordinal at which a successor was dropped”; fixtures “cannot be unlabelled about which scenario class” | The ordinal localizes an inconsistent observed sequence in a **framed covered run**; it does not uniquely diagnose a dropped successor versus a corrupted encoder, reset, or double emission. A sum labels Bounded/Unknown/Disabled, not whether Bounded(10) is a usable window. Narrow both claims to these measured distinctions (F1/F7/F9). |
| :575–577, Disabled may be dropped while :348–352 requires Arm C Disabled | That fallback removes the specified decoy. If adopted, define another same-int/distinct-reason control and revise acceptance explicitly; an absent required arm is not satisfied by a two-arm landing. |

## 4. Verification performed

The individual commands below exited 0; full output is retained in SCRATCH. None establishes
the state of `make dst`, and none tests the unimplemented D2 helper.

| Command | Observed result / log |
|---|---|
| `make -s verify_core` | `11 contracts proven, 0 unstated, 1 blocked; 0 files failed, 48 bare`; `9 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified`. `codex-v2-verify_core.log`. |
| `make -s fault_catalogue` | `fault_catalogue_dst PASS`; eleven classes and physical-fault tripwire clear. `codex-v2-fault_catalogue.log`. |
| `make -s event_vocabulary` | PASS; 34 variants/rows/goldens. `codex-v2-event_vocabulary.log`. |
| `make -s ledger_parity` | `ledger_parity wire gate PASS`; witnessed 17 required variants. `codex-v2-ledger_parity.log`. |
| Direct `ledger_parity_dst.ail` run, caps in F1 | PASS; 104 JSON lines, eight labelled subjects, one session_id. `codex-v2-ledger_parity_dst-raw.log`. |
| Direct `runtime_status_tool_dst.ail` run, same caps | `runtime_status_tool_dst PASS count=2`. `codex-v2-runtime_status_tool_dst-raw.log`. |
| `python3 SCRATCH/codex-v2-ordinal-model.py` | Demonstrates the proposed duplicate/final mismatch, honest cross-run reset, unobserved hook drop and allowed-gap counterexamples in F1/F2/F7. |

Additional counts reproduced: fourteen runtime config directories; exactly two config files
containing context_limit (`local`, `deepseekv4-flash-compaction-live`); 23 catalogue rows.
`git diff --stat 2192092 62cb753` reproduces the ADR's five-file historical diff, including
exit_manifest; it does not remove the need to read that module's current discarded render
outcome. All AILANG roadmap conclusions above are about the **local checkout read**, not a
new upstream release-status lookup.

## 5. What v2 got right

- It abandons the same-record observer and identifies a wire write that stale state cannot
  undo. The specific approval-style whole-record drop really does generate a duplicate.
- It correctly rejects the four WI-D4 sites as red-before-fix demonstrations and preserves
  the stored-versus-fresh policy rationale.
- It correctly predicts the post-finalization ordinal mismatch and excludes the untraced
  multi-turn model-change loop from deterministic coverage.
- The two existing ABI limit meanings, fail-loud departure, explicit Disabled requirement,
  and a same-int/different-reason decoy are useful decisions once the detailed acceptance
  conflicts above are resolved.
- The codec's fallback hazard is real; one increment site avoids recording-wrapper double
  increments; shell observation is already an independently produced channel.
- Three upstream asks plus evaluation of the partially shipped registry, relocation of
  the tool pilot, and D6's corrected disclosure semantics are sound dispositions.
- The source sizes, fifteen phase_vocab importers, 37 Violation constructors, three
  tool-phase request sites, and the seven-file anchor cascade reproduce.

## 6. What a v3 must change

1. **Specify and test run framing.** Begin/end identity or one invocation per process;
   initial/final ordinals, strict +1, missing-marker failures, and two honest runs sharing
   session_id. Keep the concrete whole-record-drop demonstration.
2. **Define the counted domain once.** Helped leaf requests only at adoption; no forwarder
   gaps and no unmatched ordinal-minus-log census. Replace the incorrect hook_guard claim.
3. **Repair the inventory before calling it a gate.** Ten forwarding fields, their actual
   rows, no double-counted construction sites, and dispatch_step/provider coverage beyond
   the three scan roots. Make bypass mutants include named indirection.
4. **Choose a classification consistent with D6.** Logical WorldRequest with explicit
   returned-trace append is the current-compatible choice. Price actual version and
   artifact consumers; remove the universal replay-digest claim.
5. **Give the helper a complete interface and lifecycle.** Bootstrap identity, IO/Trace
   rows, resolution/policy evidence, initial trace seeding, terminal ordering, and both
   reachable production drops. Show the publish mismatch red, then restore world and trace
   with RunSummary last and publication before done. A comment is not a green repair.
6. **Keep D1 behavior precise.** Raw checkpoint denominator versus net seal/pre-step budget;
   exit's zero; shared extension helper signatures; valid Bounded construction; acyclic
   type home. Poll the existing runtime-status fixture, independently assert the per-run
   record, and define unknown percentage rendering and a replacement decoy if Disabled
   is deferred.
7. **Reconcile compatibility and sequencing.** D1 changes wire/version surfaces and is
   D6-gated; define the projection under which existing Bounded behavior is unchanged.
   Apply the common per-run record consistently to initial live, follow-up and DST runs.
8. **Correct the evidence and scope language.** Three full WorldState literals, 35 helper
   call expressions, six script definitions with different semantic roles, IO wire,
   check-only anchors, partial upstream shipment, and conditional D4 solver/emission goals.
   Re-price from those obligations and distinguish executable gates from administrative
   deliverables.

V2 has a viable observer. It does not yet have a coherent, scoped gate and integration
design around that observer; that is the reason for rejection, rather than a claim that
its redesigned D2 can never go red.
