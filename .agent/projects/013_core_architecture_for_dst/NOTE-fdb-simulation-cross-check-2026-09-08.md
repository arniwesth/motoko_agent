# NOTE: FoundationDB's simulation framework, cross-checked against Motoko's DST

Date: 2026-09-08. Grounded at HEAD `7d02e6a` on `arniwesth/021-herdr-delegation-remaining`.
Source: Pierre Zemb, *Diving into FoundationDB's Simulation Framework* (2025-10-30),
https://pierrezemb.fr/posts/diving-into-foundationdb-simulation/ — an implementation-level walk
through `Sim2`/`Net2` interface swapping, `deterministicRandom()`, BUGGIFY, the Flow event loop,
`SimulatedCluster`, the workload model (`Cycle` + `RandomClogging` + `Attrition` + `Rollback`), and
the three verification patterns FDB workloads use.

Question asked: *could Motoko's DST system be further informed by this post?*

## 0. The answer

**Yes, in five specific places — and none of them is the thing the post is most famous for.**
The repo already cites FoundationDB in 007's taxonomy ADR, the paper's §2.1/§5.2, and 011's
survey, and has a standing rule against Buggify-style in-code fault points (009 D3; 011 ADR-001 §81;
ADR-002 §307). That rule survives this reading intact: the post's own examples
(`g_network->isSimulated() && BUGGIFY_WITH_PROB(0.01) ? Never() : …` inside
`DDShardTracker.actor.cpp`) are exactly the "second test-only transition system" D3 rejects.

What the post adds is not the fault points. It is (1) the *other* half of BUGGIFY — configuration
randomisation — which Motoko has already built for exactly one knob and stopped; (2) the
`Attrition` / `RebootAndDelete` / disk-swap workload family, which becomes obligatory the moment
ADR-003 lands, because ADR-003 trips the fault catalogue's own physical-fault reopen triggers and
nothing in ADR-003 or PLAN-003 says so; (3) the discrete-event shape for ADR-002's `wake_read`;
(4) application-versus-chaos workload composition as the shape for 021's seeded families; and
(5) search economics. Ordered by leverage below.

## 1. Mechanism-by-mechanism map

| FDB mechanism (post) | Motoko counterpart | Status |
|---|---|---|
| `g_network` → `Net2` / `Sim2` interface swap; same binary in both | `Ports` at `ports.ail:783`, 12 request classes × 4 adapter families, world state threaded by the driver (`session.ail:401`) | **Matched, and stronger**: caps-as-conformance gives a *negative* observation (`world_state_poison.ail`) FDB has no analogue of |
| `deterministicRandom()` — one seeded stream for every choice | `GeneratorState`, Lehmer PRNG, salted draws (`dst_generator.ail:339–456`); no ambient RNG asserted by `make world_state` | **Matched** |
| Seed = reproduction key | Program + manifest = reproduction key; seed re-derives only while `generator_version` stands (009 D8) | **Exceeded** — FDB's contract is weaker |
| BUGGIFY in-code fault points (25 %, `Never()`) | Faults are modeled outcomes at the typed boundary (009 D3) | **Deliberately rejected**; stands |
| BUGGIFY knob randomisation (`if (randomize && BUGGIFY) DD_SHARD_METRICS_TIMEOUT = 0.1`) | `choose_environment` draws **one** key, `MOTOKO_TOOL_TIMEOUT_MS ∈ [20, 90]`, "because its value is what makes D3's tool deadline class reachable" (`dst_generator.ail:844`) | **Partial — one knob of many.** §3.1 |
| Event loop: all actors wait → jump clock to next event | `WorldState.clock_ms`, advanced by drawn latency at delivery; sequential by D9 | **Matched for one actor**; the multi-wait case arrives with ADR-002. §3.3 |
| `SimulatedCluster`: random topology per run | Three fixed, versioned profiles; 10 of 15 extensions in no profile (013 RESEARCH §2C) | **Absent**; gated on the generic profile runner. §3.4 |
| `Attrition`: `KillInstantly`, `RebootAndDelete`, disk swap on reboot (`BUGGIFY_WITH_PROB(0.75)`), machine actor reboot loop | None. Physical faults excluded by 007 D1.3 / 009 D3 **until** a resume-from-ledger contract exists | **Absent, and about to be required.** §3.2 |
| `RandomClogging` (+ `swizzle`: unclog in reverse order), `Rollback` | Provider/tool fault classes; no ordering-of-recovery dimension | Marginal; one line in §3.4 |
| Workloads: SETUP / EXECUTION / CHECK / METRICS; app workloads vs chaos workloads stacked in TOML | One generator stream chooses both model behaviour and faults; 12 global invariant families; no per-workload CHECK | **Partial.** §3.4 |
| Pattern 1 reference implementation (`ApiCorrectness` vs `std::map`) | PLAN-003's `JournalFold` family folds the journal and compares field-by-field with `x.final` — this *is* pattern 1 | Present |
| Pattern 2 operation logging (`AtomicOps` log keyspace → recompute) | Interaction log vs `LedgerTrace` parity (`parity_findings`, `declared_vs_performed`) | Present |
| Pattern 3 invariant tracking (`Cycle` ring) | The 12 families over the whole execution (009 D7) | Present |
| "Run twice, same seed" determinism | D7's thirteenth statement over a pair (`dst_invariants.ail:1676–1780`) | Present |
| Thousands of seeds per MR, tens of thousands nightly | PR: 12 seeds / 5 s; scheduled: 240 seeds / 600 s over a **1024-seed space** (`dst_corpus.ail:340–470`) | **Two orders of magnitude apart**, and the space is the binding constraint once knobs are drawn. §3.5 |
| `fdb-sim-visualizer`: per-run chaos timeline from JSON traces | `export_trace.ail` (010 D9 exporter) exists; viewer unbuilt; `dst_run_report.ail` is aggregate, not a timeline | Partial. §3.5 |
| Rust workloads via `ExternalWorkload` FFI | `packages/motoko_ext_conformance` (invariants only) | Partial; §3.4 last paragraph |
| Auto-merge on green simulation | — | Not applicable; noted for what it says about oracle trust |

## 2. Where nothing needs to change

The world boundary, the seeded generator, the program-as-reproduction-key, the invariant oracle, the
determinism pair and the hermeticity poison pairs are each at or beyond what the post describes.
The post's determinism story rests on discipline ("use `deterministicRandom()` everywhere") plus an
`unseed` check; Motoko's rests on the effect system and a withheld-capability run that *dies* if
discipline slipped. That is the stronger instrument and the paper already says so (§5.2). Nothing in
the post argues for reopening D3's rejection of decision injection, D1's boundary, or D8's artifact.

## 3. What the post can inform, priced

### 3.1 Knob randomisation is the half of BUGGIFY the no-Buggify rule does not touch — and it is one key wide today

The post separates two BUGGIFY mechanisms and Motoko's rule only rejects the first:

1. In-code fault points (`Never()`, `BUGGIFY_WITH_PROB`) — rejected, correctly.
2. Knob randomisation at startup: `init(DD_SHARD_METRICS_TIMEOUT, 60.0); if (randomize && BUGGIFY) … = 0.1;`.
   "Hundreds of randomized knobs … each run picks a different configuration." The 600× shorter
   timeout is what makes timeout branches *routine* instead of a seed-hunt.

Motoko already does (2) — for one key. `choose_environment` (`dst_generator.ail:844`) draws
`MOTOKO_TOOL_TIMEOUT_MS` in [20, 90] ms up front, records it as the synthetic environment, and the
comment says why: it is what makes `ToolDeadlineExceeded` reachable at all. 009 D2 licenses this
explicitly: "Generation may also choose ordinary configuration and message inputs" (ADR-001:797).
And it is *cleaner* than FDB's version: the knob arrives through the env port as a value, so
production code carries no `randomize && BUGGIFY` branch.

What stopped at one key is the extension to the rest of the time- and budget-bearing surface. Every
other knob is a fixture literal in the gates: `budget() = { total: 10, solver: 6, verifier: 4 }`
(`seeded_generator_dst.ail:250`), `max_interactions: 96` (`:261`), and the config.ail defaults
(`startup_timeout_ms` 5000, `delegated_timeout_ms` 30000, the four `timeout_ms` at 25–30 s,
`config.ail:335–429`). Candidates, each within declared bounds and each recorded in the manifest the
program already carries:

- the `BudgetPlan` triple, drawn so that `CostExhausted` and solver/verifier starvation are reached
  by search rather than by construction;
- the resolved context limit (routed through the ports since WI-D3), drawn low enough that
  compaction and `CompactionExhausted` occur mid-trajectory;
- `delegated_timeout_ms` / herdr's `check_wait_ms` and `start_timeout_ms`, drawn *below* the wait
  they guard — the post's "development environment is deliberately harsher than production" — so the
  overrun branch the 021 note measures as a margin (`NOTE-2026-09-03-herdr-under-dst.md` §4.4)
  becomes an asserted branch;
- an **approval deadline duration**, which does not exist: `approval_deadline_exceeded` is
  structurally unreachable because `DenyAfterTimeout` is a decision, not a duration
  (`ports.ail:1737`; `dst_run_report.ail:39`). The post's lesson here is not "add a hang"; it is
  that a deadline is a knob, and ADR-002's own "Not decided: Timeouts. Whether a park without a
  `TimerWait` is unbounded" is the same question in a different room. Settle it once as a duration
  and both the catalogue class and the park bound become drawable.

**Cost and hazards, from the project's own history.** Cheap in code (the env class is a keyed
lookup chosen up front; `draw_between` exists). Not free in artifacts: every widening of the
generator moves every member of the PR bank (WI-D1 and WI-D4 both re-derived all twelve,
`corpus_pr_dst.ail` header), requires a `generator_version` bump and a by-hand canary re-pin
(D8; the canary has no `--update` by design), and each new drawn key must keep "absence is safe"
or `OutcomeMissing` on the env class stops being reachable. Do it as one batch, not one knob per
PR. It should also land *after* 3.5's seed-space question, because a combinatorial knob space
inside a 1024-seed rotation is a search that reports movement while covering little.

### 3.2 `Attrition` is the family ADR-003 needs, and the catalogue already says so

This is the sharpest item and it is a timing claim.

009 D3 closes with the physical-fault exclusion's reopen triggers, carried verbatim into code:
`physical_fault_reopen_triggers() = ["crash-recovery", "fsync", "WAL", "resume-from-ledger", "replicated-state"]`
(`dst_fault_catalogue.ail:471–473`), with the sentence "the moment it has one, the physical-fault
exclusion stops being a scope decision and becomes an untested gap." ADR-003 (Proposed, v6.1)
introduces a JSONL journal written one entry per event, a pure `fold_journal`, and cross-process
resume whose D6 row reads "a crash leaves the journal one entry short and the next resume strips
the dangling tool call." PLAN-003's judged number is "a run that dies at step N resumes with N steps
of history." That is a crash-recovery *and* a resume-from-ledger contract. Neither ADR-003, PLAN-003,
nor the six review rounds mention the triggers (grep: no hit for `physical`, `reopen`, or `D1.3` in
any of them). The `JournalFold` family PLAN-003 adds folds the journal-class records of a
**complete** trace and compares with `x.final`; it never sees a journal a crash left behind.

The post's `simulatedMachine` loop and `Attrition` workload are the template, and each of its
variants maps onto a distinct ADR-003 branch:

| FDB kill | Journal fault | ADR-003 branch it drives |
|---|---|---|
| `KillInstantly` at a seed-chosen moment | Truncate the journal after entry *k*, *k* drawn | D6's dangling-call strip; D4's fold; PLAN-003's "N steps of history" claim, for *every* N rather than the one a fixture picks |
| Torn write | Truncate mid-line at entry *k* | Strict-decode refusal (D4 rule 2) — this is the one genuinely *physical* fault, and it is the writer's contract, not the driver's |
| `RebootAndDelete` | Journal absent or header-only | Refusal path; the "fresh disk" case |
| Disk swap on reboot (75 % under BUGGIFY) | Resume against **another session's** journal, or one whose header digests disagree | D5's refusals on schema, workdir, extension set, prompt digest — today a list; under a swap fault, a reached branch each |
| Machine reboot loop (die → 10 s → reboot, forever) | Crash → resume → crash again, *n* times | `run_id = <session_id>.r<resume_count>.<run_ordinal>` across resumes; the invariant is over the **concatenated** trace |

Shape: this is a **pair-of-runs relation**, the form 011 ADR-002 already established for resource
growth — run to interaction *k*, hand the journal-as-written to a second run, fold, continue, and
evaluate the families over both halves plus the join. `fold_journal` is pure, so the truncation,
torn-line, and foreign-journal cases are L0 property tests before any driver is involved; the
in-memory FS the world already has (`FileWriteIdentity`, `FileRemoveIdentity`) holds the journal
during the driver-level pair.

**What it costs, and where it belongs.** The world side needs one new interaction class, "terminate
here as if killed" — a fault whose logical transition is "the run ends with no terminal record and
the FS as written." That contradicts 009 D6 ("every run returns one complete terminal trace") for
exactly that class, so it is an ADR-level change, not a plan item: the honest move is a scoped
reopen of 007 D1.3 / 009 D3 for the journal boundary only, cited from ADR-003 rather than
discovered later, and a family in PLAN-003 P3/P5 rather than a fixture. The host writer
(TypeScript, ADR-003 D3) stays L2; what DST tests is the fold's tolerance of whatever a crashed
writer leaves.

### 3.3 The event loop is the right model for `wake_read`

FDB's determinism under concurrency is one queue: when every actor is waiting, the loop takes the
earliest-timestamped pending event and jumps the clock to it. The interleaving is a function of the
drawn delays, not of a scripted order.

ADR-002 D2 gives `C2LoopState` `open_waits: [WaitDescriptor]` and `Ports` a
`wake_read: (WorldState, ParkRequest) -> WakeInput`, one wake per park, `WakeOutcome = Settled |
Lost | OperatorInput | TimedOut | HostError | Aborted`. With two or more open waits, *which* settles
first is now a seeded dimension — 021's note already lists it as a family ("draw the interleaving
of: answer file appears before/after a check; `agent wait` returns `working`/`idle`", §4.5). D9's
tripwires (ledger-sharing subagents, background callbacks) are not crossed: it is still one actor,
one world state. But the world's implementation of `wake_read` decides whether that dimension is
searchable or scripted.

Recommendation: implement the world's `wake_read` as a **settle-time queue**, not a cursor. At park,
draw a latency per open wait (`settle_at = clock_ms + draw`), deliver the earliest, advance
`clock_ms` to it, and derive `TimedOut` from the comparison against the park's deadline — the
pillar-5 form the tool class already proved with `latency_pair_dst.ail` — rather than as a chosen
outcome. Two things fall out: the interleaving is a draw (search finds orderings no fixture author
would), and the timeout is a *duration* (3.1's knob), which is what ADR-002 left undecided. The
`ext_effects` queue being served in order rather than matched by argv (`ports.ail:1498`, per the
021 note §6) is the same design question one level down; the answer should be the same.

### 3.4 Application workloads and chaos workloads are different things, and the seed should say which is which

FDB stacks independent workloads on one cluster: `Cycle` generates load and owns a CHECK; `Attrition`,
`RandomClogging`, `Rollback` inject faults and "just return true." Composition is by configuration,
and the four-phase shape (SETUP / EXECUTION / CHECK / METRICS) is what makes a workload reusable.

Motoko's generator draws both halves from one stream: `choose_provider` decides what the fake model
says (the *application* workload — tool-heavy, prose, delegate) and `choose_tool` /
`choose_provider`'s fault arms decide what breaks (the *chaos* workload). They are separable today
only by salt string. Three consequences the post makes visible:

- **Per-cell coverage.** D11 reports classes and branches reached per run; it cannot say "the
  delegation lifecycle was never run under a provider fault" because there is no lifecycle axis to
  cross with the fault axis. Naming application workloads (the 021 note's "delegation lifecycle";
  compaction pressure; approval-heavy) and chaos schedules (fault mix, latency distribution) as
  separate generator sub-streams makes that a table.
- **Metamorphic pairs for free.** Holding the chaos sub-stream fixed while the application
  sub-stream varies, or the reverse, is exactly the relation 011 §3.6 wants ("latency scaling below
  deadline thresholds changes only clock readings, not decisions") without a second generator.
- **Per-workload CHECK.** The 12 families are global. `Cycle`'s ring is a *workload* invariant. The
  021 note's list — every published run file decodes, task states never move backwards,
  `DelegateCheck` idempotent after settle, sweep at most once — is a workload CHECK, and the
  four-phase shape gives it a home next to the global oracle rather than inside it.

`clientId`/`clientCount` do not apply while D9 holds. `swizzle` (unclog in reverse order) is a
recovery-*ordering* fault; the nearest Motoko analogue — several outstanding provider faults
clearing in an order different from onset — is marginal until 3.3 exists.

The post's Rust `ExternalWorkload` (setup/start/check over FFI, run on the same loop) is the shape
for letting an extension package ship its own DST workload; 013 RESEARCH §2C's generic profile runner
is the prerequisite, and `packages/motoko_ext_conformance` is where the `check` half already lives.

### 3.5 Search economics: the seed space, not the seed count, is the constraint

FDB: thousands of seeds per merge request, tens of thousands nightly, on hundreds of cores. Motoko:
12 per PR in a 5 s budget, 240 per scheduled run against 1574 affordable, drawn from
`scheduled_rotation() = { space_size: 1024, window_size: 240 }` — the whole space repeats after
~4.3 epochs. That is deliberate ("the whole space is covered before any seed repeats") and sound
for today's generator, whose choice space is small enough that 260 seeds found eight of the nine
reachable classes. It stops being sound the moment 3.1 lands: a drawn knob vector multiplies the
trajectory space and a 1024-seed rotation then samples a sliver while reporting full coverage.
Two things before scaling the count, in order:

1. **Shrinking and auto-promotion** (011 ADR-001, Proposed). More seeds means more failures to
   triage; FDB's scale is only survivable because a failing seed is a one-line reproduction. At
   381 ms/seed a 100-probe ddmin is ~40 s; that is the prerequisite, not the seed count.
2. **A per-run chaos timeline in the run report.** The post's `fdb-sim-visualizer` table — seed,
   profile, simulated vs real time, then a time-ordered list of injected events with a summary —
   is what makes a failing seed readable before shrinking. `export_trace.ail` already writes the
   returned trace; `dst_run_report.ail` aggregates. A textual timeline over the interaction log is
   an afternoon, and it is the part of project 010 that needs no GPU.

## 4. What the post does not justify

- **In-code fault points.** The paper's §5.2 defence stands and the post's examples strengthen it:
  every `isSimulated()` branch is production code that behaves differently under test.
- **A multi-process cluster or a concurrent scheduler.** D9's tripwires are not tripped by anything
  in 021 or ADR-002; 3.3 is single-actor.
- **Auto-merge on green.** Worth noting only for what it says: FDB trusted its oracle enough to
  remove the human. 011's untaken mutation study ("reachability is not oracle strength") is the
  measurement that would say whether Motoko's could be trusted that far.
- **Disk-level physical faults** beyond the journal (bit flips, stalls, throttles from
  `DiskFailureInjection`). The journal is the only durable artifact ADR-003 creates; the reopen in
  3.2 should be scoped to it.

## 5. Suggested actions

1. **ADR-003**: add a paragraph citing `physical_fault_reopen_triggers()` and 009 D3's closing
   sentence, and scope a reopen of 007 D1.3 to the journal boundary. **PLAN-003**: add the crash
   family of §3.2 (L0 fold properties first; pair-of-runs second) beside `JournalFold`.
2. **ADR-002 D2 implementation**: specify the world's `wake_read` as a settle-time queue (§3.3) and
   fold the "Timeouts" open item into a duration knob.
3. **009 D2 / `choose_environment`**: one batched widening to the knob set in §3.1, with the
   `generator_version` bump, canary re-pin and bank re-derivation done together; sequence it after
   the seed-space decision.
4. **011 ADR-001** (shrinking) before any seed-count increase; run-report timeline as a 010 task.
5. **021 seeded families**: adopt the application/chaos split and the four-phase shape (§3.4) when
   the `driver_plus_herdr` profile is written.
