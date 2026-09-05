# 2026-08-08 Cluster 45: WI-D19 — Route B part 2a, the first routing

## Context

Branch: `arniwesth/mot-81-wi-d19-route-b-part-2a-route-on_response_intercept`.

Session span: `f27c9a3` → **`4bc49f2`** (via `df7fd26` and `136924f`, the second of which
repairs a mutant the first one captured — see *Process failures* below). Input was
`HANDOFF-execute-d19-route-b-part-2a-the-first-routing.md`, grounded against HEAD
`f27c9a3` (`2026-08-08T08:58:27Z`). Pin **v0.33.0**. First command `09:00Z`, final commit
`09:52Z`, **~52 minutes**.

**The first item in this project that adds a call site rather than a surface.** Twelve
files, **1 356 insertions / 63 deletions**, of which **663** are the record and the next
handoff.

```text
.agent/.../NOTE-d19-route-b-part-2a-the-first-routing.md   511   the record
.agent/.../HANDOFF-execute-d20-...-on-tool-handle.md       152   the next item
scripts/dst/discovery_dst.ail                             227 +- the ROUTED GRADED SCENARIO, the
                                                                 witness fields, the executed tripwire
packages/motoko-ext-compose/compose.ail                   133 +- 7 of 9 sites routed; remove_if_file
scripts/dst/declared_vs_performed.ail                     128 +- tracing ports + the S24 reachability arm
src/core/dst_discovery.ail                                113 +- 3 classes: pinned -> witnessed
scripts/dst/run_declared_vs_performed.sh                   82 +- must_die_on moved FS -> Process, +2 rows
packages/motoko-ext-abi/types.ail                          34 +  the driver-drop finding, at the type
src/core/session.ail                                       12 +- FOUR successor drops, line-count-neutral
scripts/dst/strict_replay_dst.ail, seeded_generator_dst    19 +  DiscoveryWitness grew three fields
```

| Definition-of-done item | State |
|---|---|
| All nine sites routed through `ctx.ports` | **7 of 9.** The two `exec` sites cannot route — a seam finding, not a shortfall |
| World threaded from `ctx.world`, successor on `next_state` | **met**, no ABI change |
| The `fileExists` seam decision taken and recorded | **met — `path_stat`** |
| The `:769`/`:771` spelling fixed at the call site, with a note | **met**, and the direction was forced by the compiler |
| The three tripwires answered by name | **met — witnessed, not removed**, and a **fourth** fired |
| The two un-witnessed D18 §7 mutants given a first witness | **1 of 2.** The bridge, yes; `ambient_dir_list`, no — and the reason is not 2b |
| S24: reachability asserted separately from verdict | **met**, and the first draft of one row measured less than its label |
| Anchor cascade should NOT fire | **met**, but its premise was false — see below |
| Yields 4 of 15 and 5 of 15 | **met, explicitly** |

---

## The mission result: 7 of 9

`on_response_intercept` now takes its clock, its directory create, its write, both existence
guards and both removes through `ctx.ports`, and returns the successor on
`ResponseInterceptOutcome.next_state` — which already existed, so **no ABI change**.

**Six of `ExtPorts`' seven world-threading seams got their first caller.** Only `env_get`
did not, and D16 had already declined to widen it on the ground that its callers live in
`register_with_config` and cannot reach a port at all.

---

## FINDING 1 — `ExtPorts.proc_exec` answers a different question

The handoff's third stop condition, and it fired.

**The semantic failure.** `proc_exec` fronts `Ports.tool_exec` → `world_tool` →
`dispatch_one` → `run_native_batch` → `tool_runtime.run_native_call`, which is an
**if-chain over Motoko's own tool names** (`ReadFile`, `Search`, `WriteFile`, `EditFile`,
`BashExec`, `RunTests`) with a final `else`:

```
"${call.tool} requires extension capability and is not available in native runtime"
```

So `proc_exec(w, "ailang", …)` **never invokes the compiler.** It returns a tool-error blob
that `check_snippet` cannot distinguish from a real type error.

**The shape failure, independent of the above.** `ExtProcOutcome` is `{ output: string,
next_state }`. `check_snippet:260` branches on `out.exitCode` and reads `stdout`/`stderr`
separately; `run_snippet:275` also reads `truncated`. There is no exit code. Recovering one
means parsing the rendered string (the silent-wrong shape) or widening the ABI (out of
scope by the item's own framing).

**Not widened.** Both sites stay ambient and documented. The standing witness is
`must_die_on compose_intercept_inline Process` — the day `proc_exec` grows an exit code and
compose routes through it, that row stops dying and says so.

> Four items built and argued about this seam without a caller. The first caller found it
> in ten minutes. That is the whole case for routing being a different activity from
> building a surface.

---

## FINDING 2 — the driver dropped hook successors on three arms of four

**Not looked for, and worth more than the seven call sites.**

`c2_loop` dispatches the intercept at `session.ail:2539` and can leave it four ways:

| Arm | Carried, before |
|---|---|
| `InterceptHandled` | `token_to_world(intercepted.next_state)` — correct |
| `NoIntercept` + tool calls | `exchange.next_state` — the world **before** the hook ran |
| `NoIntercept` + hybrid bash | same |
| `NoIntercept` + terminal | **dropped twice** — `post_ctx` was reused for `dispatch_solver_candidate` (so the *solver* hook also got the pre-intercept world) and `c2_after_dp7` then passed `exchange.next_state` again |

**Why seven items could not see it.** Every hook binding in the tree returned `ctx.world`
unchanged, so dropping the successor and threading it produce **identical worlds**. Not the
compiler, not the effect checker, not `ext_ambient_inventory` (it counts call sites), not
the capability trap (no capability differs), not `check_discovery` (all classes zero).

**It became visible on the first run where a hook actually performed something.** The
census reported `dir_make=0 file_write=0 file_remove=0` against a witness of 4 — the
recorder had logged four interactions into worlds the driver then discarded.

**Fixed at all four sites, every edit line-count-neutral**, because two of the five
`session.ail` attribution anchors sit below them and a comment block would have destroyed
this item's own anchor prediction before it could be tested. The durable explanation lives
at `ResponseInterceptOutcome` in the ABI, which has no anchors.

**Owed:** `on_pre_step`, `on_tool_handle` and `on_solver_candidate` have the same shape and
the same invisibility. Not audited. It is the first line of the WI-D20 handoff.

---

## The `fileExists` decision — `path_stat`, and why

1. **The guard protects a `removeFile`, which is defined over a file.** `ExtPathFile` *is*
   that predicate. `ExtFileRead.present` is two-valued, so it answers the same for a
   directory — and **D18 §3.2 measured the two adapters disagreeing on exactly that input.**
2. **`file_read` returns content this site does not want**, and D17 §3 / D18 §6 would then
   have to decide what the recorder does with bytes nobody reads. `path_stat` writes no
   interaction at all.
3. **"One bit of three" is not a cost.** The narrower answer is the wrong one.

The match is **exhaustive**, for `ext_ports_of`'s reason at the other end of the seam.
`remove_if_file` is the one home, so 2b copies a function rather than a pattern — it has
seventeen of these sites.

---

## The path key — fixed at the call site, and the compiler picked the direction

The handoff left *which* spelling open. **It is not open.** `compose_module_header` emits
`module tmp/${name}` and AILANG resolves a module path against the file's path, so the write
cannot become absolute without breaking the `ailang check` two lines later. **The create is
the free half, so the create moves:** `dir_make("tmp")`.

It is also a **repair on a real filesystem**: when cwd ≠ workdir the old pair created
`workdir/tmp` and wrote into a `./tmp` nothing had created.

**Pinned twice, because a census cannot see a path key** — the counts balance either way:

* `run_declared_vs_performed.sh` compares the routed sequence against a literal carrying
  `dir_make(tmp)` and `file_write(tmp/inline_7.ail)` side by side;
* `discovery_dst`'s scenario wires `dir_list("tmp")` to **guard** the remove, so a spelling
  failure stops the removes and `file_remove` balances 0 against a witnessed 4.

---

## The tripwires — three named, one not, and they did not fire on their own

`absent_classes` pinned `file_write`, `file_remove`, `dir_make` at zero in both directions.

**They stayed green, and the reason mattered: no graded profile in this tree installs
compose.** C5's compose-bearing profile is still owed. Left there, the item would have
shipped a routing with **zero graded evidence** — the handoff's *"do not silence it by not
grading the profile"*, arrived at from the other direction.

**So the graded run was built.** `discovery_dst` gained `routing_intercept` — compose's
chain in miniature, same registry, same production dispatcher, same `RecordingWorld`
adapters — and all three fired immediately.

**Answered by WITNESS, not removal.** `DiscoveryWitness` gains `file_writes`,
`file_removes`, `dir_makes`. `ExtensionEffect` and `RandomDraw` stay at literal zero — their
unreachability is *structural*, not "nothing calls them yet". **Every other graded run
passes 0**, so the pin is still armed for 2b.

**The counts are not read off the log** (that would make the balance an identity with the
thing it grades). They come from the scenario's control flow, anchored to the
independently-witnessed provider-call count.

**The tripwire is executed rather than described**: three rows re-run the *pre-D19
expectation* against the *post-D19 log* and require it to go red by name.

**The fourth, unnamed one.** `must_die_on compose_intercept_inline FS` stopped dying —
the probe ports are constants, so the routed branch performs no ambient FS. **That is
mediation measured from outside**, not a regression. Moved to `Process`, which names the
seam that could not route, plus a second row asserting the arm now *completes* with FS
withheld. A stale comment (*"these ports are never CALLED by any arm below"*) was corrected
rather than left.

---

## Reachability (S24)

`compose_intercept_threading` runs the real hook through the production dispatcher with
**tracing ports** that write their own name into the world token and return it, so the world
that comes back **is** the ordered list of seams called:

```
clock_now;dir_make(tmp);file_write(tmp/inline_7.ail);path_stat(tmp/inline_7.ail);file_remove(tmp/inline_7.ail);
```

Compared against a **literal**, because a witness derived from the run is satisfied by a run
that did nothing. Every part is load-bearing: the spelling; `inline_7` (the routed clock's
reading, so an ambient `now()` cannot match); `file_remove` present at all (the guard took
its removing arm); and the string surviving to the end (`next_state: ctx.world` yields the
empty token).

**A first draft measured less than its own label** — the graded scenario's reachability row
asserted `provider_calls > 0` as a proxy for "the hook was dispatched", which is satisfied by
a run where the driver called the model and the hook never ran. Now reads the three classes
out of the log, which is the right side of the S24 split: **the log knows whether the call
ran; the non-log witness knows whether the recorder counted it right.**

---

## The mutants — six, all red, one after the fixture was repaired

| # | Mutation | Result |
|---|---|---|
| 1 | `session.ext_ports_of`'s `dir_list` derives `present` from `List.length(entries) > 0` | **PASS first time.** RED, 3 rows, after the fixture was fixed |
| 2 | compose returns `next_state: ctx.world` | RED — *"the hook returned an EMPTY world token"* |
| 3 | the spelling reverts to `"${ctx.workdir}/tmp"` | RED — both spellings printed side by side |
| 4 | the clock stays ambient — `show(now())` | RED — `inline_1786181903184` vs `inline_7` |
| 5 | `remove_if_file` stats and never removes | RED — the trace ends at `path_stat` |
| 6 | `dir_make`'s successor skipped | RED — `dir_make(tmp);` missing from the middle |

**Mutants 2–6 are caught by ONE row.** The routed sequence is a single value, so every way
of getting the routing wrong is a different string and the message prints both. **Mutant 4
shows why it had to be a value rather than a call-site count**: the port is still called
(`clock_now;` is still at the head), its result is simply discarded — which
`ext_ambient_inventory` counts as mediation and the effect checker has nothing to say about.

**Mutant 1 reproduced D18's own mutant 5 exactly.** It passed, and **the fixture was wrong
rather than the code**: the scenario listed a *populated* directory, where `present` and
`length > 0` agree, so the bridge's forwarding was pinned by nothing. The distinguishing
input is a directory that **exists and is empty** — the state D18's kinded table was built
for — so the hook gained a deliberately childless second directory outside `tmp`.

> **Second consecutive item to find a green row measuring less than its label by mutating
> the thing the label names, and both times the repair was to the FIXTURE.** Standing risk
> for any row whose subject is a *derived* answer: the derivation and the truth agree on
> most inputs by construction.

**D18 §7's two un-witnessed mutants: one closed, one not.** The `session.ail` bridge is now
witnessed (the routed scenario is `ExtPorts.dir_list`'s first executed caller).
**`ambient_dir_list` without the sort is still unwitnessed** — nothing in the tree performs
an ambient directory read, and that is **not** blocked on 2b either.

---

## The anchor cascade — did not fire, but the premise was false

The handoff predicted no cascade because "this changes an extension package, not the ABI and
not `session.ail`". **The prediction held. The premise did not** — the driver fix is in
`session.ail`, above two of the five anchors.

**It held because the fix was made line-count-neutral on purpose.** `make anchors` is green
without a re-baseline; `driver_only_attribution_ref` and both profile versions untouched.

D18's law still stands (*every seam added to `ExtPorts` lands inside `ext_ports_of`, which
sits above all five anchors, so every Route B **surface** item re-baselines*). This adds the
corollary: **a routing item can touch `session.ail` and still not cascade, if it is willing
to write the explanation somewhere else.**

---

## The yields — said explicitly

| Instrument | Before | After |
|---|---|---|
| HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| shipped closure verdict | 4 of 15 | **4 of 15, "unmoved"** |
| door-3 residue | `intToFloat, show` | **unchanged** |
| `ext_ambient_inventory` PORT-MEDIATED | 4 of 15 | **4 of 15** |

Exactly as predicted. Door 3 is live in this very chain — the routed `show(reading.now_ms)`
is still a `show` — so compose stays HOOK-UNRESOLVED however well it routes. **A yield that
had moved would have meant the instrument was reading something other than what it claims.**

**What DID move:** compose's closure went from **0 to 5 `ExtPorts` field calls** (28 ambient
sources). That is criterion 2 — mediation — appearing in the instrument for the first time
in the project. **Criterion 1 did not move and could not**: `ExtPorts.file_write` declares
`! {FS}`.

---

## Gate and sweep

`make dst`, cache-cold, run **alone**. **Two red targets of forty-one, and both were red
before this item**, measured on a `git worktree` at `f27c9a3`:

* `test_coverage_selftest` — *"Named test blocks not yet implemented [stale_skip_record]"*
  and *"named_only.ail: also fired ['failing']"*;
* `test_coverage` — `src/core/prompts_test.ail` 0 of 6, every one
  *"LDR001: module not found: src/core/prompts"*.

Nothing in `prompts*.ail` or `tools/test_coverage` is in this item's diff. Named in the note
so the next item does not re-spend the measurement.

Everything else green, including every gate this item could have disturbed: `discovery`,
`strict_replay`, `seeded_generator`, `declared_vs_performed` (39 rows, 0 failed),
`world_state`, `invariants`, `program_persistence`, `predicate_anchors`/`anchors`, the three
inventories, `conformance`, `hook_guard`, `smoke_*`.

---

## Process failures — two, both from concurrency, one reached a commit

1. **Two `make dst` sweeps ran concurrently for ~10 minutes.** They corrupted each other's
   logs and produced a `discovery` failure that was an artefact of the collision. **A
   concurrent sweep is not a faster sweep**, and the failure looked exactly like a real one.
2. **A commit was taken while the mutation harness was mid-run and captured a mutant.**
   `df7fd26` shipped mutant 3 — the reverted path spelling — instead of the fix. The
   instrument had already reported it RED; **the commit was the thing that was wrong.**
   Repaired in `136924f`.

> **S17 says restore mutants by `cp` rather than `git checkout`. This is its neighbour: do
> not touch git at all while a mutation harness is running.** A harness that edits tracked
> files makes `git add -A` a race — the working tree is pristine only in the instants
> between mutants.

---

## Recorded bindings

**Discovered** — a tool, a compiler or a measurement forced it:

1. `ExtPorts.proc_exec` dispatches Motoko's own tool names, not a subprocess.
2. The driver dropped the intercept successor on three arms of four, plus once into the
   solver dispatch.
3. Which spelling wins is pinned by the compiler, through `compose_module_header`.
4. The tripwires could not fire on their own — no graded profile installs compose.
5. `must_die_on compose_intercept_inline FS` had to move to `Process` — a fourth tripwire.
6. Mutant 1 passed against a populated directory.
7. `test_coverage_selftest` and `test_coverage` are pre-existing reds.

**Decided** — the code admitted more than one answer:

1. `path_stat` over `file_read.present`.
2. `dir_make("tmp")` — direction forced, but *fixing at the call site rather than teaching
   the world to normalise* is D18's rule being obeyed.
3. Witness rather than removal for the three pinned classes.
4. **Fix the driver rather than report it** — a routing whose successor the driver discards
   is not a routing.
5. Line-count-neutral in `session.ail`, paying a comment for a testable prediction.
6. Build the graded scenario rather than report the tripwires as un-fireable.
7. Do **not** widen `proc_exec`.

---

## Owed

* **`on_tool_handle`** — 2b, 17 effect-bearing functions across five modules.
* **The successor audit for the other three hook slots.** 2b's first job.
* **The `proc_exec` seam question** — a real subprocess row, or `ailang` as a `BashExec`
  tool dispatch (which puts a compiler invocation in the tool-dispatch census).
* **`one_attempt:501`** — the identical path-key defect.
* **`ambient_dir_list`'s sort mutant** — blocked on there being any target that drives an
  ambient directory read, which 2b does not create either.
* **Registration's four `config.ail` functions** — structurally unroutable; D5's disclosure.
* **Door 3's producer**, and the hook-scope promotion.
* **Compose's unused imports** — part 3. Note that D19 made **none** unused: `one_attempt`
  still uses every one.
* **`InitialWorld.files` and the program-schema bump**, owed since D17.
* **The eight stale classifier-2 literals**, now seven items stale.
