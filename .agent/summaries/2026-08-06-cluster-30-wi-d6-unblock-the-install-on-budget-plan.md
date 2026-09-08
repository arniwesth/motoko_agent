# 2026-08-06 Cluster 30: WI-D6 — the install unblocked, and the name that did not transfer

## Context

Branch: `arniwesth/mot-67-wi-d4-restore-the-three-targets-d3-reddened`.

Session span: `596299f` → **uncommitted**. 49 files changed, 989 insertions, 174 deletions, plus the
execution NOTE. **The work is NOT committed** — stated here because D5's handoff had to spend a
paragraph on exactly this ambiguity for D4, and the next session should not have to guess. Input was
`HANDOFF-execute-d6-unblock-the-install-on-budget-plan.md` (`9f10bf2`), executed against HEAD
`596299f` ("Added summary", which adds only cluster 29's summary file). Thirtieth code session of
project 009. Pin **v0.33.0**.

**Window: ~66 min**, `07:40Z` → `08:46Z`. Two measurements dominate it: `make dst` in full
(`08:23:08Z` → `08:44:27Z`, 21m19s) and the cache-cold sweep (`08:19:25Z` → `08:22:45Z`, 3m20s). The
measurement table cost about twelve minutes; **the narrowing itself cost about four.**

**Grounding was clean.** `git status` clean at `596299f`. **S9's concurrency check: no gate running** —
one live `ailang` process, the same idle `src/core/supervisor.ail` agent session D5 found, now 1d09h
elapsed against 7m33s CPU, holding no `.ailang/cache` or `/tmp/*.out` descriptors. Re-checked
immediately before the sweep.

| Definition-of-done item | State |
|---|---|
| Every `on_budget_plan` binding measured, not read; two producers named per subject | **met** — 15 bindings, 3 producers |
| The row narrowed to what is honestly performed, or Route B, or the blocker named | **met** — Route A |
| `make declared_vs_performed` extended and green, with a control that must die | **met** — 10 → 15 rows, two-sided compile-time control |
| D5's caveat updated wherever it appears, dated not deleted (S15) | **met** — design doc + D5's note |
| The four leaning rows re-examined per S21 | **met** — count held at four; a fifth site found outside the table |
| The owed `motoko-ext-abi` major addressed | **met by reporting** — five changed rows, not cut here |
| S13 sweep cache-cold with `AILANG_RELAX_MODULES=1`, member-for-member | **met** — 226/17 of 243 |
| `make dst` in full | **met** — exit 2, red set exactly the two pre-existing |
| S9: every live cache cleared, `~/.ailang/cache/registry` untouched | **met** — cleared twice, registry verified at 1 entry |
| S17: mutants restore by `cp` | **met** — full `tar` plus four file copies |
| Do not install anything (stop-and-report) | **met** — never triggered; no profile changed |

## THE ANSWER

**Route A. The row is narrowed. Coverage did not move, and it should not have.**

| | D5 | D6 |
|---|---|---|
| `on_budget_plan` ABI row | `! {Env, FS}` closed | **no row** |
| Extensions installable in a conformant profile | **0** | **15** |
| `driver_only` installs | nothing | **nothing** |
| Acceptance rows leaning on the empty install list | 4 | **4** |
| `declared_vs_performed` | 10 rows | **15 rows** |
| Bindings of the slot measured | 1 (compose) | **15** |
| `driver_only` | v10 | **v11** |
| ✓ rows in `make dst` | 845 | **857** (+12, all this item's gate) |
| Whole-tree sweep | 226/17 of 243 | **226/17 of 243**, member-for-member |
| `make dst` red targets | 2 | **2**, unchanged |
| Owed ABI major | 4 changed rows | **5 changed rows** |

**The empty install list moved from FORCED to CHOSEN. That is the whole delivery, and it is a
*weaker* claim than D5's, not a stronger one.**

## The measurement table

Taken **before** anything was narrowed, so every row describes the tree as D5 left it.

| Producer | Coverage | Result |
|---|---|---|
| DECLARED — the annotation, grepped from source | 15/15 | `! {Env, FS}` |
| PERFORMED — the interpreter's capability trap, out of process | **7/15** witnessed (+compose = 8) | `! {}` |
| PERFORMED — the effect checker's inference over the body | **15/15**, total over inputs | `! {}` |

**Zero BLOCKING. Not one dispatch, in either regime, died on `Env` or `FS`.** The one answer that
would have refused Route A did not appear.

Measured cleanly at runtime: `compose`, `test_dummy`, `scratchpad`, `decision_framework`, `microrag`,
`compaction_structural`, `empty_stop_guard`, `progress_contract_guard`. Confounded:
`omnigraph`, `context_mode`, `mcp`, `exa_search`, `ailang_docs`, `a2a`, `compaction_ai`.

## The three findings worth carrying

### 1. The handoff's binding count was wrong by six, and its own argument made the count load-bearing

The handoff names eight extensions besides compose. **There are fourteen** — it misses `mcp`,
`context_mode`, `ailang_docs`, `decision_framework`, `compaction_structural`, `empty_stop_guard`.
All six bind the slot with a constant, so nothing turned on it. **But the handoff also says "a
single binding that genuinely performs `Env` or `FS` blocks Route A"**, which makes an undercount by
six a live risk by its own reasoning.

The list is not a matter of judgement: `src/core/ext/registry_generated.ail` is the host's own
install set. The gate now derives the subject list from it and asserts agreement member for member,
so the next extension added cannot escape measurement by not being noticed.

### 2. REGISTRATION IS THE CONFOUND, and it would have produced nine false positives

**`register_with_config` is not effect-free for most of these packages.** Nine of fifteen read `Env`
at registration — a `getEnvOr` for `MOTOKO_WORKDIR` or `MOTOKO_PROFILE_DIR` — and seven of those also
read `FS`. **Those reads happen before any hook is dispatched.**

So the naive arm — install, dispatch, capability withheld — dies for nine of fifteen subjects, and
**every one of those deaths reads as "the hook performs Env"**. That is a false positive *in the
direction that blocks the narrowing*, and nothing in the exit status distinguishes it from the real
thing. Measured before the arms were written, which is the only reason it is a design note rather
than a wrong conclusion.

Hence every runtime subject is a **pair** — `reg_<ext>` and `budget_<ext>`, same withheld caps,
differing by exactly the dispatch — and the runner reads the pair, classifying each subject
MEASURED / BLOCKING / **CONFOUNDED**. The third outcome is reported as first-class rather than folded
into either of the others.

### 3. The runtime trap has a permanent blind spot here, and narrowing the row unlocks a better producer

Capabilities are per-process, so a registration that performs `Env` **cannot** be granted it while
the dispatch is denied it. Eight of fifteen subjects are unreachable by C5's instrument no matter how
the arm is written. **The fix was not a better arm — it was a third producer.**

The effect checker rejects a body that performs more than its row admits, **over all inputs**, where
the capability trap is a witness over the one path an arm exercises. It is strictly stronger on this
question — and it only became available *by narrowing the row*. C5 could not use it: it was asking
about a hook whose declaration it was not changing.

## The compiler is the enforcer

Verified at three points, each with its control:

```
narrow ONE binding, leave the ABI row wide
  -> REJECTED: failed to unify record field 'on_budget_plan': incompatible closed
     rows: r1 has extra labels [], r2 has extra labels [Env FS]

narrow the ABI row AND the binding
  -> ACCEPTED

narrow both, and make the body actually read env
  -> REJECTED: Effect checking failed for function 'budget_hook'
```

Closed-row equality admits exactly one width, so an extension that starts reading a config file in
its budget hook **fails to build**. Re-widening is a deliberate act, not a drift.

**The third test failed for the wrong reason on the first attempt** — `undefined variable: getEnvOr`,
because `compose.ail` does not import `std/env`. C5's `must_die_on` discipline caught it. The
compile-time control in the gate is therefore **two-sided**: the mutant must be rejected with the
narrowed row **and accepted with a widened one**, so the rejection is attributable to the row.

**The narrowed row rejected the detector's own controls.** `env_reading_budget` and
`fs_reading_budget` stopped compiling the moment the row narrowed. They moved to `on_pre_step`,
dispatched through its own unconditional fold, and still die on the named capability. **The control
that was lost is not lost, it is promoted** — it is the compile-time control, total where the runtime
one was a witness. This is the strongest evidence the narrowing is real: after D6 a performing body
in this slot is not merely absent, it is **unwritable**.

## The guard built to fire on this day, and did

`tools/profile_definition/check_fixtures.py` carried, since WI-B4:

> This goes red the day WI-C5 widens `on_budget_plan` — which is exactly the day the omission has to
> be decided again rather than inherited.

**D6 narrowed it instead of widening it, and the guard fired anyway**, on the same clause. **It did
not care which direction the row moved, only that the basis had changed.** That is the best behaviour
any pin in this project has shown, and it is the standard: pin the fact, not the direction.

Its polarity is now inverted — the row must declare **no** effects — and the new form is falsifiable
in both directions (`check_fixtures.py` exits 1, `make driver_only` exits 2 on a re-widened row, 0 on
restore).

## S21, applied deliberately for the first time. The count held at four.

**None of the four rows closed. Each one's REASON concentrated.**

| Row | Before | After |
|---|---|---|
| 3 | Vacuous, on an install list **no profile could fill** | Vacuous, on an install list **this profile chooses not to fill** |
| 4 | `extension_effect_fault` waived — **doubly** secured, by the empty list AND by the ABI | **Unchanged in words** — the waiver text never named the ABI. One reason where there were two |
| 5 | Compose's eight unrouted clock reads outside reach because nothing is installed | Unchanged, now **actionable**: compose is installable, so the next profile must route or declare them |
| 7 | `ScratchpadResult` unreachable because nothing is installed to emit it | Unchanged. Needs a hook returning `Handled` with a `cells` key |

**D6 removed a barrier, not a vacuity.** S21 exists because the count moved from two to four without
any item noticing; this item re-asked and it held at four, which is the rule working rather than the
rule finding nothing.

**A fifth site concentrated the same way, outside the acceptance table**: `dst_hook_guard`'s
unreachability rested on two reasons and now rests on one. Recorded at the site.

## Four defects the new gate found — three in itself, one in the tree

1. **`.packages/` was two days stale.** The first stale-row grep went red on five rows in the resolved
   tree `make sync_packages` writes, which would have kept `pkg/` imports resolving against pre-D6
   core. Real staleness, found by accident. Synced; the gate is now scoped to source, because
   asserting an ABI property over build output reports staleness as a conformance failure.
2. **A character class truncated `register_a2a` to `a`.** `[a-z_]*` does not match digits, so the
   subject-list row reported a disagreement that did not exist. **A character class is a claim about
   the data too.**
3. **A count that exceeded its own denominator** — "7 measured, 18 confounded" over fifteen subjects,
   because regime B re-counts what regime A could not reach. Now counted as sets of names.
4. **`exit=0` from a `tail` in the pipeline** — `$?` read after a pipe reported success over a script
   that exited 1. S19's exact shape, in a fourth medium.

## Sites where two answers type-checked and one was silently wrong: **2** (55 → 57)

1. **The detector arm without its register-only twin.** Both forms type-check and run; the version
   without the differential reports nine extensions as performing `Env` when what performs it is
   their registration. The wrong answer is a **false conformance fact about a real extension**,
   perfectly reproducible, and nothing else in the tree would have contradicted it. Same species as
   C5's site 1: the instrument's own plumbing producing the evidence.
2. **A control that dies for the wrong reason.** `Effect checking failed` and `undefined variable`
   are both non-zero exits, and a check asserting only "the mutant was rejected" passes on both.

**Per the handoff's S20 pointer, the place to look was anything reading a DECLARED row as evidence of
behaviour — and that is where site 1 was.** Not in the narrowing, where the compiler rejects the
wrong answer, but in the *instrument built to justify* it.

**Not counted, and said so rather than inflating the number:** the three gate defects above were all
**loud** — the gate went red or printed an impossible number on the first run. The counter tracks
answers that are *silently* wrong. **Determinism has still caught none of the 57.**

## Gate state

- **Sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243.** Run first, per S13.
  Failing set matches the expected seventeen member for member. Stable across B4, C1, C3, C5, C4, D3,
  D4, D5 and now D6. *(Raw read 227/17 of 244 — the extra file was this item's own scratch probe,
  deleted. Stated rather than quietly adjusted.)*
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, nothing else.** Both
  pre-existing since B2a with D5's exact symptoms. `make --keep-going` emitted exactly two `Error`
  lines.
- **857 ✓ rows against D5's 845**, same methodology. **The +12 is fully attributable to this item's
  own gate** (`declared_vs_performed` contributes 22 where it contributed 10). No other target moved.
- **Every other target green**, including all eleven rows' producers. `declared_vs_performed` 15/0,
  `hook_guard` 4/0, `driver_only` v11.
- **Corpus artifact unchanged**, read from `/tmp/corpus_pr.out` per S19: nine of nine classes,
  register empty, `declared ⊆ observed`, 15 ≥ 12 seeds, and the same thin margin D5 flagged —
  **13 affordable at 381 ms/seed against a minimum of 12**.
- **`ailang lock` re-recorded 19 interface hashes.** C5's trap checked and did not fire:
  `git diff ailang.toml` is empty, no duplicate dependency key appended.

## `driver_only/10` → `/11`

v8→v9 (D3), v9→v10 (D4) and D2's before them were **re-measurements**: anchors moved, claims did not.
**This one changes a claim** — `omitted_extensions`' reason no longer says the omission is forced by
the ABI. Install list, coverage claim, waived set, hook classifications, catalogue and attribution ref
are all unchanged, so no anchor moved. The bump exists because the reason is part of the definition
and a consumer reading v10's reason would be reading a sentence this tree no longer asserts — S15's
failure mode exactly.

**A reader of v11 must not conclude that anything is covered.** v11 installs what v10 installed:
nothing.

## Corrections owed to the plan

1. **Six consecutive items have now executed with no plan entry.** C4's planning defect 1 stands
   through D1–D6. **WI-C5 is now the only remaining work item and the next one.**
2. **A handoff's subject count is a claim, and it was wrong by six.** *Suggested rule: when an item's
   scope is "every X", derive the list of X from a producer in the tree and assert the agreement in
   the gate; never take it from prose.* S16's independence requirement applied to a work item's
   **scope** rather than to a check's two sides.
3. **A producer's blind spot is a property of the question, not of the instrument.** *Suggested rule:
   before extending an instrument to a larger subject set, ask what fraction of the new set its
   producer can reach, and report the fraction rather than the subset.*
4. **The compiler is an underused producer in this project, and narrowing a row unlocks it.**
   `on_response_intercept`, `on_solver_candidate` and `on_pre_step` are the three slots D5 still
   refuses on declared rows, and the same move is available to each — with its own measurement, none
   of which was taken here.
5. **S19 earned itself again, in a fourth medium** (absent tick, absent count, absent artifact row,
   and now a swallowed exit code).

## Still owed

- **WI-C5, the `compose`-bearing profile.** The next item, the last unbuilt one in the plan, and the
  one that turns this into coverage.
- **The `motoko-ext-abi` major and lockstep re-release** — five changed rows now, lock file moved four
  times. Not cut here because cutting it is a release act.
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds;
  `ExtPorts.proc_exec` and `env_get` widening.
- **`test_coverage` and `test_coverage_selftest`**, red since B2a and untouched here.

## DID COVERAGE MOVE? **NO.**

**`driver_only` installs nothing. It covers nothing. Every clause of its acceptance table that
quantifies over installed extensions is vacuous to exactly the extent it was at WI-D5.** Eleven of
eleven rows still hold, four still lean on the empty install list, and the table was not re-run
because nothing here changes a row's answer.

**D5 called this "the one item that would make the name transfer." It was necessary and it was not
sufficient, and the name did not transfer.** This item removed the blocker; **WI-C5 spends it.**
