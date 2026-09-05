# 2026-08-06 Cluster 31: WI-D7 — the three remaining barriers, and the install claim withdrawn

## Context

Branch: `arniwesth/mot-68-wi-d6-unblock-the-install`.

Session span: `b1cc558` → **uncommitted**. 47 files modified plus the execution NOTE. Input was
`HANDOFF-execute-d7-the-three-remaining-barriers.md` (`87e11fd`), executed against HEAD `b1cc558`.
Thirty-first code session of project 009. Pin **v0.33.0**.

**The handoff's first instruction was wrong in the session's favour.** It warned that D6's source
work was uncommitted — 50 modified files — and said to confirm with `git status`. **It was
committed**, as `7677e24` "Implementation" (47 files) plus `b1cc558` "Added summary", and the tree was
clean at start. Nothing had to be recovered.

**Window: ~52 min**, `10:26:46Z` → `11:19Z`. Three runs dominate it: `make dst` in full
(`10:54:34Z` → `11:05:23Z`, **10m49s** — half D6's, because the caches were warm from the sweep before
it) and **two** cache-cold whole-tree sweeps at 3m22s each. **The measurement cost about ten minutes
and the narrowing about five**; the expensive half was neither, it was reconciling six artifacts that
disagreed about what D6 had done.

**Grounding was clean.** **S9's concurrency check: no gate running** — the same idle
`src/core/supervisor.ail` agent session D5 and D6 both found, now 1d12h elapsed against 7m47s CPU,
plus four days-old `make claude` shells and a `make run`. Re-checked before the sweep.

| Definition-of-done item | State |
|---|---|
| Each of the three slots measured across every binding, route decided and recorded | **met** — 3 slots × 15 bindings, all three refuse Route A |
| For any slot refusing Route A, the refusing binding NAMED | **met** — `compaction_ai`, `compose`, `context_mode`, each named by the compiler |
| Whatever narrows, narrows; whatever does not, reported with what must change | **met** — two rows narrowed, one did not, each with its reason |
| The install question answered plainly, with a number | **met** — **3 barriers, nothing installable** |
| D5's caveat and `driver_only`'s omission reason kept in agreement | **met** — and four *further* disagreeing artifacts found |
| S21: re-ask the four leaning rows | **met** — count held at four; **three D6 concentrations withdrawn** |
| Producer reach reported as a fraction, per S16 | **met** — runtime trap reaches **0/15** on these slots |
| Subject list derived from `registry_generated.ail`, per S22 | **met** — 15 subjects, 71 files |
| The owed `motoko-ext-abi` major addressed | **met by reporting** — seven changed rows, not cut here |
| S13 sweep cache-cold with `AILANG_RELAX_MODULES=1`, member-for-member | **met** — 226/17 of 243, run **three times** |
| `make dst` in full | **met** — exit 2, red set exactly the two pre-existing |
| S9/S17: caches cleared, registry untouched, mutants restored by `cp` | **met** — 8 apply/restore cycles from a `tar` |
| S19: never read `$?` after a pipe | **met** — `PIPESTATUS[0]` throughout |
| Do not install anything (stop-and-report) | **met** — never triggered |
| Report Route B rather than building it (stop-and-report) | **met** — reported for all three slots |

## THE ANSWER

**All three slots refuse Route A. Two rows narrowed. No barrier fell. The count is three.**

| | D5 | D6 | **D7** |
|---|---|---|---|
| `on_budget_plan` ABI row | `! {Env, FS}` | no row | no row |
| `on_pre_step` ABI row | ten effects | ten effects | **ten effects — did not move** |
| `on_response_intercept` ABI row | nine effects | nine effects | **`! {IO, Process, FS, Clock}`** |
| `on_solver_candidate` ABI row | nine effects | nine effects | **`! {Process}`** |
| **Barriers to installing any extension** | 4 | *reported as 0* | **3, DERIVED AND CHECKED** |
| **Extensions installable in a conformant profile** | 0 | *reported as 15* | **0** |
| `driver_only` install list | FORCED empty | *reported CHOSEN* | **FORCED empty** |
| Acceptance rows leaning on the empty install list | 4 | 4 | **4** |
| `declared_vs_performed` | 10 rows | 15 rows | **26 rows** |
| `driver_only` | v10 | v11 | **v12** |
| ✓ rows in `make dst` | 845 | 857 | **870** (+13, all attributed) |
| Whole-tree sweep | 226/17 of 243 | 226/17 | **226/17**, member-for-member |
| `make dst` red targets | 2 | 2 | **2**, unchanged |
| Owed ABI major | 4 changed rows | 5 | **7 changed rows** |

**D6's row in that table is struck through by this item, not by hindsight.** Its summary recorded
"extensions installable: 15". `on_budget_plan` was one of four unconditionally-dispatched slots, and
D5 forbids installing an extension with any of them excluded.

## The measurement

Subject list **derived from `registry_generated.ail`** (S22): 15 extensions, **71 `.ail` files**, all
green at baseline. For each slot: narrow the row to nothing *tree-wide*, re-check all 71 files. Then
narrow the refusing helper's *own* row, so the second verdict comes from the **body** rather than from
a comparison of two annotations.

| Slot | Accept `! {}` | Refused by | Effects, named by the compiler |
|---|---|---|---|
| `on_pre_step` | **14/15** | `compaction_ai` | `AI Clock Env FS IO Net Process SharedMem Stream Trace` |
| `on_response_intercept` | **14/15** | `compose` | `Clock FS IO Process` |
| `on_solver_candidate` | **14/15** | `context_mode` | `Process` |

Confirmed from the bodies: `Effect checking failed for function 'fresh_compaction'`,
`'on_response_intercept'`, `'finalize_with_index'`.

### Producer reach, per S16

| Producer | Reach |
|---|---|
| DECLARED — the annotation, grepped from source | 15/15 |
| PERFORMED — runtime capability trap | **0/15** |
| PERFORMED — effect checker over the body | **15/15**, total over inputs |

**The runtime trap reaches none of these slots.** D6's per-process confound applies harder here: the
effects at stake (`Process`, `FS`, `IO`, `Clock`) are the same ones `register_with_config` performs,
so no regime separates them. **For D7 the compiler is not the third producer, it is the only one**,
and the gate's rows say so rather than implying a witness they do not have. D6's rule — *ask what
fraction of the new subject set your producer can reach* — returns **zero**, which is what it was
written to make visible.

## What the handoff predicted, and what it got

It predicted `A, probably` for `on_solver_candidate`, `A or B — genuinely open` for `on_pre_step`,
`B` for `on_response_intercept`. **Right once.**

- **`on_solver_candidate`** — the handoff said "bindings return constants". **Twelve of fifteen do.**
  `context_mode.finalize_with_index` spawns a `node` bridge fire-and-forget to index the final
  output: a real subprocess, default path, not a fixture. No document in this project names it.
- **`on_response_intercept`** — C5's `must_die_on compose_intercept_inline FS` predicted this. The
  compiler is **more specific than the runtime witness was**: four effects, not one.
- **`on_pre_step`** — the sharpest finding, and it is a **shape** finding. `compaction_ai` reaches all
  ten effects through **one call**, `ctx.ports.ai_step` — which **is** a D1 world-mediated port
  returning `next_state`, which `compact_with_ai` returns rather than `ctx.world`. **Criterion 2's
  substance is already satisfied by the only binding that performs anything.** What refuses the slot
  is that criterion 2 reads the *declared row*, and a declared row has no vocabulary for saying an
  effect arrives through a world-mediated port. **The barrier is the row's vocabulary — not the
  behaviour, and not the row's width.** No narrowing reaches it.

## Neither narrowing removes a barrier, and saying so is the point

A non-empty row fails criterion 1 at four effects exactly as at nine, and none of `Process`, `FS`,
`IO`, `Clock` is a world-mediated port, so criterion 2 fails too — even though both outcome records
already carry `next_state`.

**What the narrowings buy is the compiler.** A binding that starts reading `Env` in either slot now
**fails to build**, verified two-sided. At nine effects it would have compiled silently.

**Cascade: three lines**, all in `src/core/ext/runtime.ail` — `decide_one_finalize`,
`collect_finalize_decisions`, `dispatch_solver_candidate` — held at `! {Process, IO, Clock}`, where
the extra `{IO, Clock}` is the **host's** own `emit_dummy_hook`, not any extension's. Recorded at the
site so the difference from the ABI row does not read as staleness.

## The disagreement D6 left: SIX artifacts, TWO of them executable

| Artifact | Said |
|---|---|
| `dst_driver_only.ail` `omitted_extensions` | *"The three other former barriers stand"* — **correct** |
| `dst_driver_only.ail` **header** | *"now CHOSEN rather than FORCED"* — wrong |
| `tools/profile_definition/check_fixtures.py` | *"an extension IS installable"*, **`print`ed every run** |
| `scripts/dst/hook_guard_dst.ail` | *"an extension IS now installable"*, **`println`ed every run** |
| `src/core/dst_fault_catalogue.ail` | *"so an extension IS now installable"* — wrong |
| `src/core/dst_hook_guard.ail` | same — wrong |

**`driver_only.ail` disagreed with itself, header against omission reason, thirty lines apart, same
item, same day.** All six now agree. They could disagree indefinitely because **no artifact computed
the count** — each passage reasoned locally about the slot in front of it and every one was locally
sound.

**`NOTE-d6-…md` was deliberately NOT edited.** The plan's review ruled it stands per S15 as a
historical record of what D6 concluded. Current assertions were all moved; the record was left dated.

## The count is now a checked artifact

`make profile_definition` derives it from the ABI rows **and** `dst_profile_coverage.hook_dispatch`
(two producers, neither derived from the other) and prints a number:

```
✓ barrier count DERIVED from the ABI rows and the dispatch table: 3
    BARRIER  on_pre_step / on_response_intercept / on_solver_candidate
    coverable on_budget_plan     gated on_tool_handle
  → 3 barrier(s) stand, so NO extension is installable in a conformant profile
```

**It goes RED at zero**, verified two-sided (`FAIL: … That is WI-C5's trigger and it must be DECIDED,
not inherited as a side effect of an ABI edit`, exit 1; restored, exit 0). **This is D5 planning
defect 4 — "the caveat needs to be a checked artifact, not prose" — discharged for this claim.**

## S21: the count held at four, and three D6 concentrations are WITHDRAWN

| Row | D6 said | D7 says |
|---|---|---|
| 3 | vacuous on a list this profile **chooses** not to fill | **WITHDRAWN** — no profile *can* fill it |
| 4 | waiver rested on two reasons, **now one** | **WITHDRAWN** — still two |
| 5 | compose's clock reads **now actionable** | **WITHDRAWN** — compose is not installable |
| 7 | needs a hook returning `Handled` with `cells` | unchanged; D6 did not claim otherwise |
| `dst_hook_guard` unreachability | concentrated two → one | **WITHDRAWN** — still two |

**A new failure mode for S21: a concentration is a claim about what a closure removed, so a closure
that did not happen produces concentrations that did not happen** — and it propagates into every
reason the closing item touched. D6 recorded three, in three files, each locally consistent, all
downstream of one wrong sentence.

## Gate state

- **Sweep 226 pass / 17 fail of 243, run THREE times** — after the narrowings, after the
  documentation edits, and after the final `hook_guard_dst.ail` edit. **Identical failing set
  member-for-member** across all three and to D6's expected seventeen. The repeats are S18: tensing a
  comment is a source edit, and this item rewrote a great deal of commentary after the code was green.
- **`make dst` exit 2**, red set exactly `test_coverage` + `test_coverage_selftest`, pre-existing
  since B2a. Exactly two target `Error` lines.
- **870 ✓ vs D6's 857. The +13 was checked, not assumed:** `declared_vs_performed` 22 → 33 rows
  (**+11**) and the barrier-count row **+2**, because `check_fixtures.py` runs twice in a `make dst`.
  11 + 2 = 13. No other target moved.
- `declared_vs_performed` **26 passed / 0 failed** (D6: 15). `hook_guard` 4/0. `driver_only` 6/6.
- **Corpus artifact unchanged**, read from `/tmp/corpus_pr.out` per S19: unreachable register EMPTY,
  subset in **both** directions, 15 ≥ 12 seeds, both budget mutants fire, **13 affordable at
  381 ms/seed** — identical to D6.

Eleven new gate rows, each mutation-tested: three slot rows, three refusing bindings read from their
*own* declarations, a scoped stale-row grep, and two two-sided compile-time controls. Re-widening
`on_solver_candidate` takes the target to exit 2.

## Sites where two answers type-checked and one was silently wrong: **2** (57 → **59**)

1. **A closed-row rejection read as a statement about behaviour.** `incompatible closed rows: r1 has
   extra labels [Clock FS IO Process]` looks exactly like the effect checker reporting what a body
   performs. **It is not** — it is two *annotations* failing to unify, and an over-wide annotation on
   an effect-free body gives a byte-identical message. Had the three helpers been merely
   over-annotated, this item would have reported three barriers that were not there and left two
   narrowings untaken. **Exactly the handoff's S20 pointer — reading a DECLARED row as evidence of
   behaviour — inside the instrument built to escape that mistake.**
2. **An instrument excerpt naming the wrong cause.** The check harness printed the first three
   non-filtered lines, and for `compaction_ai` those are a **VER001 toolchain-skew warning** (that
   package's lock is at v0.26.0 against a v0.33.0 binary). The real error was four lines down. A
   reader concludes the failure is skew and the slot unmeasured — the answer that *stops* the
   investigation. D6's site-2 species one level up: not a control dying for the wrong reason, but a
   report naming the wrong reason for a correct verdict.

**Not counted, and said so rather than inflating:** a greedy `->` match that read `on_pre_step` as
declaring no row, `grep` reading `->` as an option, and a stale-row grep matching hook *callers*
(the conformance harness's scenario runners, whose nine-effect row is honest). All three were
**LOUD** — each turned a gate row red on first execution.

## Corrections owed to the plan

1. **The plan now has a D7 entry.** C4's planning defect 1 stood through D1–D6; **D5's and D6's are
   still owed**, and **WI-C5 remains the only unbuilt work item and the next one.**
2. **A barrier count is a completeness claim and it was wrong by three.** S22 was earned against a
   *subject* count; the identical failure recurred one level up in a *barrier* count, **in the item
   that wrote S22**. *Suggested extension: when an item's conclusion is "X is now unblocked", derive
   the list of things that block X from a producer and assert the count — not just the list of things
   you changed.*
3. **A reported concentration is falsifiable and nothing was falsifying these.** *Suggested extension
   to S21: when an item reports a concentration, the reason it says was REMOVED must be checked as an
   artifact, not asserted.*
4. **S16's independence cannot be met for these rows**, because the runtime producer reaches 0/15.
   Recorded so a reader knows which rows rest on a single producer by necessity rather than choice.
5. **`.packages/` staleness recurs.** `make sync_packages` was needed again, exactly as D6 found.
   Two consecutive items; worth a gate rather than a step each item remembers.
6. **`make hook_guard` filters its own disclosure block out of its output** — the recipe pipes through
   `grep -v '^  '` and every disclosure line is indented two spaces, **so the false claim was never
   displayed by the target carrying it.** S19's shape inverted: the rule is about a *check* that
   vanishes; this is a *caveat* that vanishes. A gate that filters its own caveats will filter a real
   one the same way.

## Out of scope, unchanged and still owed

- **WI-C5, the `compose`-bearing profile** — next, and now **larger** than D6 left it: three barriers
  to clear, not zero, and `on_pre_step` needs a port-surface change or a criterion that can read
  world mediation.
- **Route B for all three slots** — world-mediating `Process`, `FS`, `IO`, `Clock` on the extension
  surface. **Reported, not built**, per the stop-and-report condition. Larger than D6 and D7 combined.
- **The `motoko-ext-abi` major and lockstep re-release** — seven changed rows, lock moved five times.
  `git diff ailang.toml` empty, so C5's duplicate-key trap did not fire.
- Compose's eight unrouted clock reads; `ExtPorts.proc_exec`/`env_get`; the two sibling
  `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.
- **`test_coverage` and `test_coverage_selftest`**, red since B2a, untouched.

## DID COVERAGE MOVE? **NO — AND UNLIKE AT D6, NOTHING EVEN LOOKS LIKE IT DID.**

`driver_only` installs nothing and covers nothing. **The axis's extension-model coverage is ZERO.**
Eleven of eleven rows hold, four still lean on the empty install list, and the acceptance table was
not re-run because nothing here changes a row's answer.

**D6 removed one barrier of four and reported it as unblocking the install. D7 measured the other
three, narrowed two rows that needed narrowing, and removed none.** The empty install list is
**FORCED**, exactly as at D5. The difference between this item and D6 is not the result but that
**the count is now something the tree computes rather than something a report asserts.**
