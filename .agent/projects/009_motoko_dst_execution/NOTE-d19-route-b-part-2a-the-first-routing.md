# WI-D19 — Route B part 2a: the first routing

Grounded against HEAD `f27c9a3`. Forty-third calibration run, and **the first item in this project that
adds a call site rather than a surface.**

**Seven of nine effect sites routed.** `on_response_intercept` now takes its clock, its directory
create, its write, both existence guards and both removes through `ctx.ports`, and returns the
successor on `ResponseInterceptOutcome.next_state`. **No ABI change was needed**, which is what the item
was scoped on and what held.

**THE TWO THAT DID NOT ROUTE ARE THE REPORT'S MOST VALUABLE LINE, AND THEY ARE A SEAM DEFECT RATHER
THAN A BUDGET DECISION.** `ExtPorts.proc_exec` answers a different question from the one
`check_snippet`/`run_snippet` ask, in two independent ways. §2.

**AND THE FIRST CALLER FOUND A DROP ON THE OTHER SIDE OF THE SEAM.** `session.c2_loop` carried the
intercept hook's successor on **one of the four arms** it can leave the intercept by, and dropped it on
the other three plus once more into `dispatch_solver_candidate`. It had been that way since WI-B2b and
**nothing could see it, because until this item no hook performed a world-threading effect** — dropping
the successor and threading it produced identical worlds. §3.

**The `fileExists` seam decision: `path_stat`.** §4.

**The path key is fixed at the call site, and which spelling wins was decided by the compiler rather
than by taste.** §5.

**All three tripwires fired and are answered by witness, not by removal.** §6. A **fourth** tripwire
fired that the handoff did not name, and it is the mediation showing up in an instrument that was
measuring the ambient effect. §7.

**The anchor cascade did NOT fire.** The prediction held — but it took deliberate work to keep it
testable, because the driver fix landed in `session.ail` above two of the five anchors. §9.

**The yields did not move: 4 of 15 and 5 of 15.** Exactly as predicted, and for the predicted reason.
§10.

---

## 1. The git wall-clock window

WI-D18 ran ~1h03m, WI-D17 ~1h05m.

**This item: 09:00Z -> 09:52Z, ~52 minutes**, first grounding read to final commit.

**TWO PROCESS FAILURES, BOTH FROM RUNNING THINGS CONCURRENTLY, AND BOTH RECORDED BECAUSE THEY COST REAL
TIME AND ONE OF THEM REACHED A COMMIT.**

1. **Two `make dst` sweeps ran at once for about ten minutes.** They corrupted each other's logs and
   produced a `discovery` failure that was an artefact of the collision. **A concurrent sweep is not a
   faster sweep**, and the failure it produced looked exactly like a real one.
2. **A commit was taken while the mutation harness was mid-run, and captured a mutant.** `df7fd26`
   shipped mutant 3 — the reverted path spelling — instead of the fix. The instrument had already
   reported it RED; the commit was the thing that was wrong. Repaired in `136924f`.

**S17 says restore mutants by `cp` rather than `git checkout`, and this is its neighbour: do not touch
git at all while a mutation harness is running.** A harness that edits tracked files makes `git add -A`
a race, and the working tree is only pristine at the instants between mutants.

---

## 2. `proc_exec` ANSWERS A DIFFERENT QUESTION, AND IT FAILS THE CALLER TWICE OVER

This is the third stop condition — *"if routing reveals that a seam built at D16/D17/D18 answers the
wrong question, stop and report before widening it"* — and it is the one that fired.

### 2.1 The semantic failure: it is not a subprocess seam

`ExtPorts.proc_exec` fronts `Ports.tool_exec`. Follow it down:

```
ExtPorts.proc_exec  ->  session.ext_ports_of's closure
                    ->  Ports.tool_exec
                    ->  ports.world_tool          (ports.ail:1250)
                    ->  tool_dispatch_adapter.dispatch_one
                    ->  tool_runtime.run_native_batch
                    ->  tool_runtime.run_native_call   (tool_runtime.ail:165)
```

`run_native_call` is an **if-chain over Motoko's own tool names** — `ReadFile`, `Search`, `WriteFile`,
`EditFile`, `BashExec`, `RunTests` — with a final `else`:

```
ToolErrorResult({ ..., message: "${call.tool} requires extension capability and is not available in native runtime" })
```

So `proc_exec(w, "ailang", …)` on a live run **does not invoke the compiler**. It reaches that `else`
and returns a tool-error blob, which `dispatch_one` encodes as JSON and `tool_outcome_text` hands back
as `ExtProcOutcome.output`. `check_snippet` would then be holding a string that says the check failed,
for a reason that has nothing to do with the snippet, and it has no channel to tell that from a genuine
type error.

**The field is named for the effect and typed for the seam, and the two are not the same thing.** D16
widened it to thread the world and did not re-examine what it dispatches; nothing had a reason to,
because it had no callers.

### 2.2 The shape failure, which is independent

Even granting the semantics, `ExtProcOutcome` is `{ output: string, next_state }`. Both callers branch
on an **exit code**:

| Site | Reads |
|---|---|
| `check_snippet:260` | `out.exitCode == 0`, then `out.stderr` and `out.stdout` separately |
| `run_snippet:275`   | `out.exitCode`, `out.stdout`, `out.stderr`, `out.truncated` |

There is no exit code to read. The two ways to get one are **parse the rendered string** — the
silent-wrong shape this project exists to remove, and it would put the tool-error blob and a real
compiler failure on the same code path — or **widen `ExtProcOutcome`**, which is an ABI change and is
the thing this item was scoped on not needing.

`ExtProcOutcome`'s own comment already anticipated half of this: *"widening the ABI to carry the
discrimination is a SECOND widening on a second ground — D1's part-3 typed-fault argument."* What it did
not anticipate is that the seam's live adapter cannot run the process at all.

### 2.3 What was done about it

**Nothing, deliberately, beyond recording it.** Both sites stay ambient, both are documented at the
call site, and the standing witness is in `run_declared_vs_performed.sh`: `compose_intercept_inline`
now dies on `Process` rather than on `FS`, so the day `proc_exec` grows an exit code and compose routes
through it, that row stops dying and says so. §7.

**This is not a claim that the seam should be widened.** It might be right for the ABI to grow a real
subprocess seam beside `proc_exec`; it might be right for compose's `ailang check` to become a
`BashExec` tool dispatch, which is a different and larger decision about whether a compiler invocation
belongs in the run's *tool-dispatch* census. Both are decisions with consumers, and neither is this
item's.

---

## 3. THE DRIVER DROPPED THE SUCCESSOR ON THREE ARMS OF FOUR

**This is the finding the item did not go looking for, and it is the reason the first routing is worth
more than the seven call sites it moved.**

### 3.1 What was wrong

`c2_loop` dispatches the intercept at `session.ail:2539` and can leave it four ways:

| Arm | Carried |
|---|---|
| `InterceptHandled` | `token_to_world(intercepted.next_state)` — **correct** |
| `NoIntercept` + tool calls | `exchange.next_state` — the world **before** the hook ran |
| `NoIntercept` + hybrid bash | `exchange.next_state` — same |
| `NoIntercept` + terminal | **dropped twice**: `post_ctx` was reused for `dispatch_solver_candidate`, so the *solver* hook was also handed the pre-intercept world, and the terminal `c2_after_dp7` then passed `exchange.next_state` again, discarding the solver hook's successor as well |

That is the F6 defect the world-token protocol exists to prevent, sitting in the driver, on the
majority of its own arms.

### 3.2 Why seven items could not see it

**Every hook binding in the tree returned `ctx.world` unchanged.** Under that condition, carrying
`exchange.next_state` and carrying `token_to_world(intercepted.next_state)` produce **identical
worlds** — the round trip is total and the hook contributed nothing. So:

* the compiler cannot see it: both are a `WorldState` in a `world_state` field;
* the effect checker cannot see it: no effect is involved;
* `ext_ambient_inventory` cannot see it: it counts call sites in extensions;
* the capability trap cannot see it: no capability is withheld or performed differently;
* `check_discovery` cannot see it: with no routed hook, the classes are all zero on both sides.

**It became visible on the first run where a hook actually performed something**, which is the run this
item built. The census reported `dir_make=0 file_write=0 file_remove=0` against a witness of 4 — the
recorder had logged four interactions into worlds the driver then threw away.

### 3.3 The fix, and why it is four one-token edits

All four sites now carry the live successor. **Every edit is line-count-neutral**, and that is not
tidiness: `tools/predicate-anchors/anchors.sh` pins five `session.ail` line numbers and two of them
(2775, 2885) sit below all four edit sites. A comment block at any of them would have moved the anchors
and destroyed this item's own prediction (§9) before it could be tested. The durable explanation
therefore lives at `ResponseInterceptOutcome` in the ABI, which has no anchors, and here.

### 3.4 What was NOT done, and it is owed

**`on_pre_step`, `on_tool_handle` and `on_solver_candidate` have the same shape and the same reason for
being invisible.** They were not audited. `on_tool_handle` is part 2b's, and 2b should walk its arms
before it routes anything, because a routed hook whose successor the driver drops is not a routed hook —
it is a recorder writing into a world nobody keeps.

---

## 4. THE `fileExists` SEAM DECISION: `path_stat`

The handoff asked which question the call is actually asking. It is asking **"is there a FILE to
remove"**, and that is `path_stat`'s question, not `file_read`'s.

**1. The guard protects a `removeFile`, and `removeFile` is defined over a file.** `ExtPathFile` *is*
that predicate. `ExtFileRead.present` is two-valued, so it answers the same for a directory as for a
file — and WI-D18 §3.2 measured the two adapters **disagreeing** on exactly that input. Routing this
guard through `file_read` would put a known adapter disagreement between compose and a host call that
refuses over a directory.

**2. `file_read` returns content this site does not want, and the recorder would then have to decide
about it.** WI-D17 §3 and WI-D18 §6 decide per class what the recorder does; a read issued only for its
boolean hands the recorder a body with no consumer and forces that decision on bytes nobody asked for.
`path_stat` writes no interaction at all, which is the answer those sections already reached for a pure
observation.

**3. `path_stat` costing "one bit of three" is not a cost.** The narrower answer is the one that is
wrong, not the one that is cheap: the third value is what distinguishes the input on which the remove
would fail.

**The match is exhaustive**, for `ext_ports_of`'s reason at the other end of the same seam — the whole
point of typing `ExtPathKind` rather than rendering it to a string was that a fourth constructor must
not have a default arm. `remove_if_file` is the one home for this, so part 2b copies a function rather
than a pattern.

---

## 5. THE PATH KEY: FIXED AT THE CALL SITE, AND THE COMPILER PICKED THE SPELLING

WI-D18 §5's rule is *one spelling per path; the world does not normalise*. `compose.ail:769` created
`"${ctx.workdir}/tmp"` and `:771` wrote `"tmp/${name}.ail"` — absolute create, relative write.

**The handoff left which-spelling open. It is not open: `compose_module_header` emits
`module tmp/${name}`, and AILANG resolves a module path against the file's path.** Making the write
absolute would require the header to move with it and would break the `ailang check` two lines later.
The create is the free half, so **the create is what moves**: `dir_make("tmp")`.

**It is also a repair on a real filesystem, not only in the world.** When cwd is not `workdir` the old
pair created `workdir/tmp` and then wrote into a `./tmp` that nothing had created. The old code only
worked when cwd == workdir, which is the same condition under which the new code is byte-identical.

**Scoped to this hook.** `one_attempt:501` has the identical defect and is 2b's.

**And it is pinned twice**, because a census cannot see a path key — the counts balance whether or not
the two paths agree:

* `run_declared_vs_performed.sh` compares the routed sequence against a literal that contains
  `dir_make(tmp)` and `file_write(tmp/inline_7.ail)` side by side;
* `discovery_dst`'s routed scenario wires `dir_list("tmp")` to **guard** the remove, so a spelling
  failure stops the removes happening and `file_remove` balances 0 against a witnessed 4. A `dir_list`
  whose answer nothing consumed would have been a call site, not a test — WI-D18's mutant 5 is what
  taught this tree that a claim nothing reads is pinned by nothing.

---

## 6. THE THREE TRIPWIRES: FIRED, AND ANSWERED BY WITNESS

`dst_discovery.absent_classes` pinned `file_write`, `file_remove` and `dir_make` at zero in both
directions, so that the first routing would have to answer for them by name.

**They did not fire on their own, and the reason matters: no graded profile in this tree installs
compose.** C5's compose-bearing profile is still owed. Left there, the item would have shipped a
routing with **zero graded evidence** and three green rows that were green for the wrong reason — which
is the handoff's *"do not silence it by not grading the profile"*, arrived at from the other direction.

**So the graded run was built.** `discovery_dst` gained `routing_intercept` — compose's routed chain in
miniature, in the same registry, through the same production dispatcher and the same `RecordingWorld`
adapters — and the tripwires fired immediately.

**The answer is WITNESS, not removal**, and the reason is that removal throws away the pin for every
other run:

* `DiscoveryWitness` gains `file_writes`, `file_removes`, `dir_makes`.
* The two classes that stay pinned at literal zero are `ExtensionEffect` and `RandomDraw` — the ones
  whose unreachability is **structural** rather than "nothing calls them yet", which is the distinction
  `test_an_unrouted_filesystem_mutation_is_over_recorded` was already written to keep.
* **Every other graded run in the tree passes 0** and gets exactly the assertion D17 and D18 wrote, so
  the tripwire is still armed for part 2b.

**The counts are not read off the log**, which would make the balance an identity with the thing it
grades. They come from the scenario's control flow — two `dir_make`s and one each of the others per
dispatch — anchored to the independently-witnessed provider-call count. That is
`MOTOKO_TOOL_TIMEOUT_MS`'s discipline in `expected_env_reads`, one class over.

**The tripwire is executed rather than described.** Three rows in the routed scenario re-run the
*pre-D19 expectation* against the *post-D19 log* and require it to go red by name, so the prediction
D17 and D18 wrote is a passing assertion rather than a paragraph.

**And the other direction now exists.** While the expectation was a literal `0` the class could only
ever be over-recorded; a witness makes "the driver did it and the recorder did not log it"
representable, and `test_a_witnessed_filesystem_mutation_must_be_recorded` asserts it three times —
each against a log containing the other two, so a balance wired to the wrong kind cannot come out right
for the wrong reason.

---

## 7. THE FOURTH TRIPWIRE, WHICH THE HANDOFF DID NOT NAME

`run_declared_vs_performed.sh` asserted `must_die_on compose_intercept_inline FS`. **After routing, the
arm no longer dies on FS**, because the probe ports are constants and the inline branch performs no
ambient filesystem effect at all.

**That is not a regression; it is mediation, measured from outside.** The arm stopped needing a
capability because the effect now leaves through a seam. The row was moved to `Process` — which names
the one thing that could not route (§2) — and the lesson it exists for is intact: same hook, same
declared row, two different performed answers selected by an argument. Only the class it is
demonstrated on moved.

**A second row was added, because "dies on Process" is not the FS claim.** A hook that still performed
FS and merely reached the subprocess first would satisfy the first row. So the same input with FS alone
withheld and Process granted must now **complete**, and that row goes red if any of the five routed
sites is put back.

**And a stale comment was corrected rather than left.** `probe_ports`' note read *"these ports are
never CALLED by any arm below"*. That was true from C5 through D18 and is now false for five of the
ten. A reader who trusted it would mis-read every FS row in the file.

---

## 8. REACHABILITY, ASSERTED SEPARATELY (S24)

**A routed call that compiles and never runs is this item's version of the silent-wrong shape**, and it
gets its own instrument rather than an inference from a green build.

`compose_intercept_threading` runs the real hook on the real input through the production dispatcher,
with **tracing ports** that write their own name into the world token they are handed and return it. The
world that comes back out **is** the list of seams that were called, in order:

```
clock_now;dir_make(tmp);file_write(tmp/inline_7.ail);path_stat(tmp/inline_7.ail);file_remove(tmp/inline_7.ail);
```

Compared against a literal, because a witness derived from the run is satisfied by a run that did
nothing. Every part is load-bearing: `dir_make(tmp)` is the spelling; `inline_7` is `trace_clock_now`'s
reading, so an ambient `now()` cannot match; `file_remove` present at all means the routed guard took
its removing arm; and the string surviving to the end means every seam threaded its successor and the
hook returned the last one — `next_state: ctx.world` yields the empty token, which is the same answer a
hook that routed nothing gives.

**`trace_path_stat` answers `ExtPathFile` deliberately.** `ExtPathMissing` would send `remove_if_file`
down its no-op arm and the row would witness four seams while its label claimed five.

**A first draft of the graded scenario's reachability row measured less than its own label**, and it is
recorded because it is this item's contribution to the count: it asserted `provider_calls > 0` as a
proxy for "the hook was dispatched", and that is satisfied by a run in which the driver called the model
and the hook never ran — which is precisely the state the file was in before the scenario existed. It
now reads the three classes out of the log, which is the right side of the S24 split: **the log knows
whether the call ran; the non-log witness knows whether the recorder counted it right.**

---

## 9. THE ANCHOR CASCADE DID NOT FIRE

The handoff's prediction was that it should not, because this item changes an extension package rather
than the ABI or `session.ail`. **The prediction held**, and the five anchors at
`965/1224/1330/2775/2885` are untouched — but **the premise was false halfway through**: the driver
defect (§3) is in `session.ail`, above two of them.

**It held because the fix was made line-count-neutral on purpose.** Four expression swaps and one
four-line comment rewritten to the same four lines. `make anchors` is green without a re-baseline, and
`driver_only_attribution_ref` and the profile versions are untouched.

**The law D18 stated still stands and is not weakened by this:** *every seam added to `ExtPorts` lands
inside `ext_ports_of`, which sits above all five anchors, so every Route B **surface** item re-baselines
this list.* This was not a surface item. What it adds is the corollary: **a routing item can touch
`session.ail` and still not cascade, if it is willing to write the explanation somewhere else.**

---

## 10. THE YIELDS, SAID EXPLICITLY

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope_selftest` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| `ext_hook_scope_selftest` — shipped closure verdict | 4 of 15 | **4 of 15, "unmoved"** |
| door-3 residue | `intToFloat, show` | **`intToFloat, show`** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |

**Exactly as predicted, and a yield that had moved would have meant the instrument was reading
something other than what it claims to.** Door 3 is live in this very chain — the routed
`show(reading.now_ms)` is still a `show` — so compose stays HOOK-UNRESOLVED however well it routes.

**What DID move, and it is the number this item is actually about:** `ext_ambient_inventory` reports
compose at **28 ambient sources and 5 `ExtPorts` field calls in closure**, up from 0 field calls. That
is criterion 2 — mediation — appearing in the instrument for the first time in the project. Criterion 1
did not move and could not: `ExtPorts.file_write` declares `! {FS}`, so the hook's declared row is
unchanged.

---

## 11. THE MUTANTS

Restored by `cp` throughout (S17 — WI-D18 lost its own work to a `git checkout`).

| # | Mutation | Result |
|---|---|---|
| 1 | **`session.ext_ports_of`'s `dir_list` derives `present` from `List.length(entries) > 0`** | **PASS first time — see below.** RED, 3 rows, against the repaired scenario |
| 2 | compose returns `next_state: ctx.world` (the F6 drop, hook side) | **RED** — *"the hook returned an EMPTY world token"* |
| 3 | the spelling reverts to `"${ctx.workdir}/tmp"` | **RED** — `dir_make(./tmp)` against `file_write(tmp/…)`, both spellings printed side by side |
| 4 | the clock stays ambient — `show(now())` | **RED** — `inline_1786181903184` where the routed reading gives `inline_7` |
| 5 | `remove_if_file` stats and never removes | **RED** — the trace ends at `path_stat` |
| 6 | `dir_make`'s successor is skipped — `file_write` takes the clock's world | **RED** — `dir_make(tmp);` is missing from the middle of the trace |

**Mutants 2 through 6 are all caught by ONE row**, `compose_intercept_threading`, and that is the
argument for the tracing ports rather than five separate assertions: the routed sequence is a single
value, so every way of getting the routing wrong shows up as a different string, and the failure message
prints both. **Mutant 4 is the one that shows why it had to be a value and not a call-site count** —
the port is still called (`clock_now;` is still at the head of the trace), its result is simply
discarded. `ext_ambient_inventory` counts that as a mediated call and the effect checker has nothing to
say about it.

**Mutant 1 is the one worth reporting, and it reproduced WI-D18's own mutant 5 exactly.** It passed the
first time, and **the fixture was wrong rather than the code**: the scenario listed a *populated*
directory, where `present` and `List.length(entries) > 0` agree, so the bridge's forwarding was pinned
by nothing. The distinguishing input is a directory that **exists and is empty** — the state D18's
kinded table was built to represent — so the routed hook gained a second, deliberately childless
directory outside `tmp`, and the mutant went red.

**This is the second consecutive item to find a green row measuring less than its label by mutating the
thing the label names**, and both times the repair was to the fixture. D18 §7 called it "a distinction
the label claimed turned out not to be measured"; it is worth treating as a standing risk for any row
whose subject is a *derived* answer, because the derivation and the truth agree on most inputs by
construction.

**D18 §7's two un-witnessed mutants: one is now witnessed, one is not.**

* **The `session.ail` bridge deriving `present` from the entry count — WITNESSED**, mutant 1. The routed
  scenario is `ExtPorts.dir_list`'s first executed caller, through the production bridge.
* **`ambient_dir_list` without the sort — STILL UNWITNESSED.** Nothing in this tree performs an ambient
  directory read: the routed scenario runs on `RecordingWorld`, whose reads are the scripted adapters.
  Witnessing it needs a live-adapter target, and it is **not** blocked on part 2b — it is blocked on
  there being any target that drives `ambient_dir_list` at all. It stays a gap and is named as one.

---

## 12. RECORDED BINDINGS: DECIDED VERSUS DISCOVERED

**Discovered — a tool, a compiler or a measurement forced it:**

1. **`ExtPorts.proc_exec` dispatches Motoko's own tool names, not a subprocess** (§2.1). Found by
   following the seam down to `run_native_call`'s final `else`, not predicted by any handoff — D16
   argued at length that compose's `exec` sites were `proc_exec`'s and never checked what the live
   adapter does with the name.
2. **The driver dropped the intercept successor on three arms of four, plus once into the solver
   dispatch** (§3). Found by `check_discovery` reporting `0` against a witness of `4`. Not predicted.
3. **Which spelling wins is pinned by the compiler**, through `compose_module_header`'s
   `module tmp/${name}` (§5). The handoff framed it as an open choice.
4. **The tripwires could not fire on their own**, because no graded profile installs compose (§6).
5. **`must_die_on compose_intercept_inline FS` had to move to `Process`** (§7) — a fourth tripwire.
6. **Mutant 1 passed against a populated directory** (§11).
7. **`test_coverage_selftest` and `test_coverage` fail at HEAD and failed before this item.** These are
   the ONLY two red targets in the sweep (§15), so a reader would otherwise attribute them here.
   Measured against a `git worktree` at `f27c9a3`:
   * `test_coverage_selftest` — the same two rows, *"Named test blocks not yet implemented
     [stale_skip_record]"* and *"named_only.ail: also fired ['failing']"*;
   * `test_coverage` — `src/core/prompts_test.ail` 0 of 6, every one
     *"LDR001: module not found: src/core/prompts"*, identical at the baseline commit.

   Neither `prompts.ail` nor `prompts_test.ail` nor anything in `tools/test_coverage` is in this item's
   diff. Named here so the next item does not spend the measurement again.

**Decided — the code admitted more than one answer and this item chose:**

1. **`path_stat` over `file_read.present`** for the existence guard (§4).
2. **`dir_make("tmp")` over an absolute write** (§5) — forced in direction by 3 above, but the decision
   to fix at the call site rather than teach the world to normalise is D18's rule being obeyed.
3. **Witness rather than removal** for the three pinned classes (§6).
4. **Fix the driver rather than report it** (§3). The mission is to route the hook; a routing whose
   successor the driver discards is not a routing.
5. **Line-count-neutral in `session.ail`** (§9), paying a comment for a testable prediction.
6. **Build the graded scenario rather than report the tripwires as un-fireable** (§6).
7. **Do not widen `proc_exec`** (§2.3).

---

## 13. WHAT THIS ITEM DID NOT DO

* **`on_tool_handle`** — 2b, 17 effect-bearing functions across five modules.
* **Registration's four `config.ail` functions.** Structurally unroutable; D5's disclosure obligation.
* **Door 3's producer**, and the hook-scope promotion.
* **Removing compose's now-unused imports.** All five std/fs and std/clock symbols are still used by
  `one_attempt`, so nothing became unused — part 3's closure-unit verdict is unaffected either way.
* **`InitialWorld.files` and the program-schema bump**, owed since D17.
* **The eight stale classifier-2 literals**, now seven items stale.
* **The successor audit for the other three hook slots** (§3.4).
* **`ambient_dir_list`'s sort mutant** (§11).

---

## 14. THE SWEEP

`make dst`, cache-cold, run ALONE — see §1 for why that sentence is in this report.

**Two red targets out of forty-one, and both were red before this item:** `test_coverage_selftest` and
`test_coverage`. §12, discovered binding 7, has the baseline measurement. **Everything else is green**,
including every gate this item touched or could have disturbed:

| Target | What it had to survive |
|---|---|
| `discovery` | the new routed scenario, its witness fields, and the three executed tripwire rows |
| `strict_replay`, `seeded_generator` | `DiscoveryWitness` grew three fields |
| `declared_vs_performed` | 39 rows, including the moved `must_die_on` and the new reachability arm |
| `world_state`, `invariants`, `program_persistence` | `session.ail`'s four successor sites |
| `predicate_anchors` / `anchors` | the five `session.ail` anchors — §9 |
| `ext_ambient_inventory`, `ext_call_inventory`, `ext_hook_scope_selftest` | compose's closure went from 0 to 5 `ExtPorts` field calls |
| `conformance`, `hook_guard`, `smoke_*` | the ABI comment and the rebuilt package |

---

## 15. WHAT THE NEXT ITEM SHOULD KNOW

1. **WALK THE DRIVER'S ARMS BEFORE ROUTING `on_tool_handle`.** §3 found the intercept's successor
   dropped on three arms of four, and the same shape and the same invisibility apply to every other
   slot. A routed hook whose successor the driver discards records into a world nobody keeps, and
   nothing but a graded run with a *performing* hook can see it.
2. **`ExtPorts.proc_exec` cannot take compose's `exec` sites.** §2. 2b hits this again — `one_attempt`
   has the same two calls — so 2b should decide the seam question before it starts, not halfway
   through. The two live options are a real subprocess seam beside `proc_exec`, or routing `ailang` as
   a `BashExec` tool dispatch, and the second puts a compiler invocation into the run's tool-dispatch
   census.
3. **`remove_if_file` is the pattern to copy, and it is a function rather than a shape.** Seventeen of
   2b's sites are this guard.
4. **The path key bites again at `one_attempt:501`**, identically, and the write's spelling wins there
   for the same compiler reason.
5. **The three tripwire classes are now witnessed, and still pinned at zero everywhere else.** A 2b
   write reaching a graded profile reopens §6 by name; the fields are there to take the count.
6. **The anchor cascade is avoidable but not free.** §9 — line-count-neutrality bought the prediction,
   and the explanation had to live somewhere without anchors.
7. **A row whose subject is a DERIVED answer needs a fixture that separates the derivation from the
   truth.** §11, twice in two items.
