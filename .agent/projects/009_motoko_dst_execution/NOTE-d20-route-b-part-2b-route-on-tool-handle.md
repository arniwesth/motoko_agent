# WI-D20 — Route B part 2b: route `on_tool_handle`

Grounded against HEAD `f9cb5bf`. Forty-fourth calibration run, and **the second routing — seventeen
effect-bearing functions where WI-D19 moved nine.**

**Fifteen of the seventeen thread a world; the other two correctly do not, and §4.1 says why that is
the right answer rather than a shortfall.** Plus an eighteenth that has no callers, and eight more
functions that changed signature purely to carry the world. §4. Compose's `on_tool_handle` now takes
its clock, its directory creates, its writes, its removes, its path kinds, its file reads and its
directory listings through `ctx.ports`, and returns the successor on `ToolHandleOutcome.next_state`.

**THE DRIVER-ARM AUDIT IS THE REPORT'S MOST VALUABLE LINE AGAIN, AND IT FOUND A WORSE SHAPE THAN WI-D19
DID.** `on_tool_handle`'s successor was dropped on **every arm, not three of four** — and the drop was
not in the dispatcher, which has been correct since WI-B2b. It was one frame above, in
`tool_phase.execute_allowed_tool_call`, which projected `.decision` off the dispatch and discarded the
successor at the point of use. **And there is a second, independent defect on the READ side that the
obvious fix would have turned into a world REGRESSION.** §2.

**`ExtPorts.proc_exec` still cannot take compose's `exec` sites, and this item found a THIRD binary it
also cannot take.** `rg`, in `author_tools.grep_impl`, fails for exactly the reason `ailang` does —
which makes it a property of the seam rather than a property of compose. §3.

**The anchor cascade FIRED, and it was not avoidable.** The handoff predicted it should not fire for an
item that only adds call sites. The premise did not hold: the driver fix needs `ext_world`'s codec
inside `tool_phase.ail`, and an import can only go above the anchors. §7.

**Criterion 2 moved a long way: 28 ambient sources -> 11, and 5 `ExtPorts` field calls -> 32.** §6.

**The yields did not move: 4 of 15 and 5 of 15**, exactly as predicted and for the predicted reason.
§9.

**Three rows in this item measured less than their own labels. Two were repaired; the third could not
be, and is named as a gap instead.** §8 — and that is the fourth consecutive item to hit this.

---

## 1. The git wall-clock window

WI-D19 ran ~52 minutes, WI-D18 ~1h03m, WI-D17 ~1h05m.

**This item: 10:07Z -> 11:20Z, ~1h13m**, first grounding read to final commit — the longest in the
cluster, and roughly D19 plus one wasted sweep. The size ratio predicted most of it (seventeen
functions against nine call sites); the rest is §1's process failure and the three anchor consumers
§7.1 found the hard way.

**D19 §1's two process failures did not recur** — every mutant was restored by `cp`, and no git
operation was performed while a mutation was in the tree.

**ONE NEW PROCESS FAILURE, RECORDED BECAUSE IT COST A SWEEP.** A comment-only edit to
`src/core/ports.ail` (§11's tensing) was made **while a `make dst` sweep was running**. Nothing can
have changed behaviourally, but the sweep was reading that file, so its result could not be quoted as a
measurement of a fixed tree — and a sweep you have to caveat is a sweep you have to re-run. It was
re-run after all edits were final, and §14 reports the second one.

**D19's rule was "do not touch git while a mutation harness runs". The generalisation is: do not touch
TRACKED FILES while any long instrument runs**, including for edits you are certain are inert. The cost
of being wrong is a full sweep; the cost of waiting is a few minutes.

---

## 2. THE DRIVER DROPPED THE SUCCESSOR ON EVERY ARM, AND STALED THE INPUT AS WELL

This is the audit WI-D19 §3.4 owed and the handoff made a blocker. **It found two independent defects,
and the second is the one that matters, because the obvious fix for the first makes it worse.**

### 2.1 Where the drop was, and where it was NOT

`ext/runtime.first_handle` and `dispatch_tool_handle` are **correct and always have been.** They thread
the world hook to hook, and `first_handle` even carries a WI-B2b comment explaining why a *delegating*
hook still threads its successor. Nothing there needed changing.

The drop is one frame above, at two call sites, and both discard the successor by **projection**:

| Site | Shape |
|---|---|
| `tool_phase.ail:334` | `dispatch_tool_handle(rt, ctx, envelope).decision` — then `next_state: world` on every arm |
| `tool_envelope_dispatch.ail:44` | `dispatch_tool_handle(rt, ctx, call).decision` — into a function whose return type has **no successor field at all** |

So where WI-D19 found the intercept's successor carried on one arm of four, this slot carried it on
**none**. `.decision` is a field access; there was never an arm at which the world could have been
kept.

### 2.2 The read side, which makes the obvious fix a REGRESSION

`ctx` is built **once per batch** at `session.ail:2307` and passed unchanged through
`dispatch_tool_entries_with_builtin`'s fold, while `world` advances per entry. **From the second tool
call in a batch onward, `ctx.world` is the batch-start world.**

Writing `token_to_world(handled.next_state)` back without re-seating would therefore hand the loop a
world **rewound past everything the earlier entries did** — a regression written by the very edit that
repairs the drop, and it type-checks exactly as readily as the correct version. Both halves had to move
together.

The fix re-seats from the live `world` on the way in — `{ ctx | world: world_to_token(world) }` — and
carries `token_to_world(handled.next_state)` out on all three arms, including into the native
dispatch's `ports.clock_now`, which had been starting from the pre-hook world.

### 2.3 Why nothing could see either half

**The same reason WI-D19 §3.2 gives, one slot over: no `on_tool_handle` binding in this tree performed
a world-threading effect until this item routed compose's.** Under that condition all three answers —
drop, re-seat, rewind — produce identical worlds. The compiler sees a `WorldState` in a `WorldState`
field; the effect checker sees no effect; `ext_ambient_inventory` counts call sites in extensions;
`check_discovery`'s classes are zero on both sides.

**Two hook slots audited, two drops found.** At this point the finding is about the pattern rather than
about either slot, and `on_pre_step` and `on_solver_candidate` are still unaudited — §13.

### 2.4 What was NOT fixed, and it is a real one

**The scratchpad loopback path is still structurally unable to carry a successor**, and it is reported
rather than patched. `tool_envelope_dispatch.dispatch_tool_envelope` returns `ToolResultEnvelope`; its
only caller is `ws_loopback.dispatch_deferred_request`, inside `loop_until_done`'s recursive WS event
loop, reached from `exec_scratchpad_cell_ws`, which returns `CellExecResult` (`src/core/types`).

Threading a world through that means changing two function return types **and** a type in core **and**
the event loop's recursion — in a different package, on a path compose's `on_tool_handle` never
travels. It is the same defect class as §2.1 and it is named here so the next item does not rediscover
it, but it is not this item's, and pretending otherwise would have doubled the diff for a path the
mission does not touch.

---

## 3. `proc_exec` — THE DECISION, AND A THIRD BINARY THAT CONFIRMS IT

**Decision: NOT ROUTED, again, and the same for all four sites.** Recorded at each call site.

**The seam was re-verified at HEAD rather than taken from WI-D19's note.** `run_native_call`
(`tool_runtime.ail:165`) is an if-chain over exactly six names — `ReadFile`, `Search`, `WriteFile`,
`EditFile`, `BashExec`, `RunTests` — with a final `else` returning *"<tool> requires extension
capability and is not available in native runtime"*.

**WHAT IS NEW: THIS ITEM HIT A THIRD BINARY, AND IT IS NOT `ailang`.** `author_tools.grep_impl` shells
out to **`rg`**. It fails for the identical reason, which upgrades the finding:

> D19 could be read as "compose's compiler invocation is an awkward fit for a tool-dispatch seam".
> `rg` is an ordinary subprocess with no relationship to compose's compiler at all, and it fails the
> same way. **The seam does not front subprocesses; it fronts Motoko's own tool names.** That is a
> property of `ExtPorts.proc_exec`, not of what compose happens to run.

The shape failure is independent and now has a second form. `check_snippet`/`run_snippet` branch on
`out.exitCode`; `grep_impl` branches on `Ok`/`Err` and needs `out.stdout` as **bytes**. `ExtProcOutcome`
carries one rendered `output` string and no status, so under it an `Err` and a successful search that
matched nothing become the same value — and `grep_impl`'s fallback scan would fire on the second.

**The two live options are unchanged and neither is taken here:** a real subprocess seam beside
`proc_exec` (an ABI row), or routing these as `BashExec` **tool dispatches** — which would put a
compiler invocation and a ripgrep into the run's tool-dispatch census, where `w.tool_dispatches` and
`ToolIdentity` count them. Both are decisions with consumers.

**What this leaves is an honest partial rather than a silently complete one.** `grep_impl`'s FS half —
both `grep_fallback_scan` calls and `mk_ok`'s clock — routes; its subprocess does not. `std/process`
stays imported in three modules and `std/fs` and `std/clock` leave all of them, and that asymmetry is
the residue of this finding rather than an unfinished edit.

---

## 4. THE SEVENTEEN, AND THE MODULE THAT HAD NONE

**All seventeen were reached and decided; fifteen thread a world.** The partition the handoff carried
was accurate in count and wrong in one member:

| Module | Effect-bearing functions | Threaded |
|---|---|---|
| `compose.ail` | `check_snippet`, `run_snippet`, `snippet_meta_json`, `one_attempt`, `run_attempts`, `handle_compose_tool` | 6 |
| `author_tools.ail` | `mk_ok`, `normalize_type`, `read_file_impl`, `list_dir_impl`, `file_exists_impl`, `stat_impl`, `grep_fallback_scan`, `grep_impl` | 8 |
| `store.ail` | `store_stdout_and_elide`, `store_snippet_with_meta` | 2 |
| `authoring/dispatcher.ail` | `check_snippet` | 1 |
| `guard.ail` | **none** | — |

**`guard.ail` HAS NO EFFECT SITES AND NEVER DID.** It imports `std/string` alone. What looks like
`readFile(` and `exec(` at `:59-60` and `:80` are **string literals** — the guard searches a snippet's
*text* for those substrings. A grep for effect names finds them; a grep that strips comments still finds
them. Named here because it is the kind of false member that survives being copied from handoff to
handoff.

`store_snippet` is an **eighteenth** and is not in the seventeen: it has no callers anywhere in the
tree. It was routed anyway, because leaving one ambient `mkdirAll`/`writeFile` pair behind would have
kept `std/fs` imported in `store.ail` and left the module AMBIENT for a function nobody runs — §6's
measurement counts imports, so a dead ambient source measures identically to a live one.

**Beyond those, eight more functions changed signature purely to CARRY the world between them** —
`on_tool_handle`, `author_loop.loop` (eleven exit literals and twelve recursive calls),
`run_author_loop`, `dispatch_author_tool`, `dispatch_author_tool_with_globs`,
`dispatch_authoring_tool`, `handle_finalize` and `mk_err`. **Twenty-four signatures moved in total**:
fifteen of the seventeen, the unreferenced eighteenth, and these eight.

### 4.1 THE TWO THAT TAKE NO WORLD, AND WHY THAT IS THE RIGHT ANSWER

**`compose.check_snippet` and `compose.run_snippet` are unchanged.** They are in the seventeen because
they are effect-bearing, and they were decided rather than skipped: **each performs exactly one effect,
`exec`, and that one cannot route (§3).**

**A function that performs nothing world-observable has no successor to carry**, so giving these two a
`(p, w)` pair and a `next_state` would have been threading as decoration — a world in and the same
world out, at two call sites, asserting a mediation that had not happened. That is the shape this
project exists to remove, pointing the other way.

**The contrast inside the same item is what makes it a rule rather than an excuse.**
`authoring/dispatcher.check_snippet` and `author_tools.grep_impl` ALSO perform an unroutable `exec` —
and both thread, because they perform routable effects as well. The test is not "does this function
shell out"; it is "does this function perform anything the world can see". Two of the four `exec` sites
answer no, and they are the two that keep their signatures.

### 4.2 Three shape decisions, and they went different ways on purpose

**`AuthorToolResult` gained a `next_state` FIELD.** All five `*_impl` functions perform effects and each
has an error path through `mk_err` and a success path through `mk_ok` — ten returns. A wrapper record
would have let one of the ten forget the world while the other nine carried it; a field the constructor
demands makes every return state its answer once.

**`AuthoringToolResult` did NOT, and took a wrapper instead.** Eleven of its twelve handlers are pure —
only `finalize` shells out. A field on the type would have forced a world parameter through eleven
functions that observe nothing and made `mk_ok`/`mk_err` look effectful for one caller's benefit.
**The shape follows the effect, not the module.**

**`AuthorLoopResult` gained a field**, for `AuthorToolResult`'s reason at larger scale: eleven exit
literals and twelve recursive calls, of which only three sit below a dispatch that moved the world. A
wrapper would have meant writing `next_state: w` twenty times — the same information with twenty more
chances to write the wrong one.

### 4.3 Two sites where routing was also a repair

**`author_tools.normalize_type` collapsed two syscalls into one observation.** It was
`isDir(path) ? "dir" : isFile(path) ? "file" : "missing"`, which is `ports.ambient_path_stat`'s body and
`path_kind_label`'s vocabulary arrived at independently. Two syscalls can disagree — a path that is a
directory at `isDir` and gone by `isFile` reports `"missing"` — where one `path_stat` is a single
observation.

**`file_exists_impl` collapsed `fileExists` and `normalize_type` into one, and the equivalence was
MEASURED rather than assumed**, because this is the site where getting it wrong is silent. `found` was
`fileExists(path)` and is now `kind != "missing"`. Those agree only if `fileExists` is true for a
directory, which was checked against `std/fs` directly:

```
dir : exists=true  isDir=true  isFile=false
file: exists=true  isDir=false isFile=true
gone: exists=false isDir=false isFile=false
```

So `exists` is exactly `not missing` on all three inputs and the emitted payload is byte-identical. Had
it gone the other way, the old code would have been reporting `exists=false type=dir` — self-
contradictory — and the collapse would have been a behaviour change wearing a refactor's clothes. The
same probe establishes that `read_file_impl`'s `"not_a_file"` arm is live rather than dead code.

---

## 5. THE PATH KEY, FIXED AT THE SECOND OF ITS TWO SITES

`one_attempt` created `"${ctx.workdir}/tmp"` and wrote `"tmp/${snippet_name}.ail"` — absolute create,
relative write, WI-D19 §5's defect verbatim.

**The direction was not a choice and the compiler picked it, exactly as D19 said it would.**
`compose_module_header(snippet_name)` emits `module tmp/${snippet_name}` and AILANG resolves a module
path against the file's own path, so the write cannot become absolute without the header moving with it
and the `ailang check` two lines below failing. **The create is the free half, so the create moved**:
`dir_make("tmp")`.

**Fixed at the call site. The world was not taught to normalise** — still D18's stop condition.

`authoring/dispatcher.check_snippet` was checked for the same defect and **does not have it**: it
creates `".motoko-store/tmp"` and writes and removes `".motoko-store/tmp/…"`, one relative spelling
throughout. It is what `one_attempt` should have looked like, and now does.

---

## 6. CRITERION 2: 28 -> 11 AMBIENT, 5 -> 32 FIELD CALLS

`make ext_ambient_inventory` reports compose at **11 ambient sources and 32 `ExtPorts` field calls in
closure**, from 28 and 5 at HEAD.

**SIX OF THE SEVENTEEN REMOVED WERE DEAD IMPORTS, AND FINDING THAT OUT CHANGED WHAT THIS ITEM HAD TO
DO.** Classifier 3 reads **import lines, not call sites**: every symbol on an ambient import counts
whether or not anything calls it. After routing, `compose.ail`'s `std/clock (now)` and
`std/fs (writeFile, fileExists, removeFile, mkdirAll)` and `dispatcher.ail`'s `std/clock (now)` were all
dead — six ambient sources for effects the extension can no longer perform.

**The handoff put "removing compose's unused imports" in part 3, and this is not that.** Part 3's
question is the closure-unit verdict for imports that were already unused. These were made dead **by
this item's own edit**, in the same commit, and leaving them would have left the instrument reporting a
state that had ceased to exist. That is the silent-wrong shape one level up from the code, and cleaning
up after oneself is not scope creep. WI-D19 correctly left compose's imports alone because
`one_attempt` still used all five; routing `one_attempt` is what killed them.

**Criterion 1 did not move and could not**, as predicted: `ExtPorts.file_write` declares `! {FS}`, so
`author_loop`'s row is still `! {IO, AI, FS, Process, Env, Clock}` and the hook's declared row is
unchanged.

**The eleven that remain**, counted rather than estimated: `ai_compat`'s `stepWithStream` (ambient AI);
**four** `println`s (`ai_compat`, `author_loop`, `claimcheck`, `compose`); **three**
`std/process.exec`s (`author_tools`, `authoring/dispatcher`, `compose` — §3); `config.ail`'s two
registration reads; and `register.ail`'s `getEnvOr`. The last three are registration's, structurally
unroutable, and D5's disclosure obligation rather than this item's. `1 + 4 + 3 + 2 + 1 = 11`.

---

## 7. THE ANCHOR CASCADE FIRED, AND IT WAS NOT AVOIDABLE

**The handoff's prediction was that the cascade should fire only if the item touched `ext_ports_of`, and
not if it only added call sites. The premise did not hold**, and the reason is worth recording because
it is the second consecutive item to find this prediction's framing incomplete.

WI-D19 showed that a routing item **can** touch a driver file without cascading, by making every edit
line-count-neutral. This item could not. The `on_tool_handle` successor fix needs
`src/core/ext_world`'s codec inside `tool_phase.ail`, and **an import can only go above the anchors**.
Holding them would have meant compressing an unrelated import block to buy back four lines — the
cosmetic edit `ext/runtime.ail:24` already carries once. Twice is a habit, and per the handoff's own
stop condition **the anchors are an instrument while the dropped successor is a defect.**

Re-baselined deliberately: `tool_phase.ail` 313/314/373 -> **317/318/413**, with the reason in
`anchors.sh`. `driver_only_version` 17 -> 18, `no_ops_version` 4 -> 5, both attribution refs re-recorded
at `sha256:5f000167…`.

**TWO OF THE THREE ARE PURE OFFSET DRIFT AND THE THIRD IS NOT, AND THAT DISTINCTION IS RECORDED RATHER
THAN AVERAGED AWAY.** `is_scratchpad_tool_name` and `exec_scratchpad_cell_ws` were compared to
`git show HEAD:` character by character and are identical. **`tool_phase.ail:373` -> `:413` also
CHANGED**: it read `ports.clock_now(world)` and now reads `ports.clock_now(handle_world)`, because a
delegating `on_tool_handle` may have advanced the world before the native dispatch begins. Same site,
same effect, same routing, different starting world. Every previous re-baseline in this cluster could
say "character-identical, only the offset moved"; this one cannot, so the row's `note` says what moved
inside it and a reader who diffs it is not left to wonder.

**The law D18 stated is now known to have an exception**: it is not only Route B *surface* items that
re-baseline this list. A routing item does too, if it needs a codec on the driver side.

### 7.1 THE RE-BASELINE HAS NINE CONSUMER SITES AND THIS ITEM FOUND SIX OF THEM BY HAND

**Three were missed, and only `make dst` found them.** `scripts/dst/driver_only_dst.ail:75`,
`driver_plus_no_ops_dst.ail:110` and `profile_definition_dst.ail:111` each carry their **own literal
copy** of the attributed Process site, so that the unaccounted-site rule has something to reject. All
three went red with

> `[site-unaccounted] discovered core effect site 'src/core/tool_phase.ail:314' … appears in neither
> the attribution rows nor the unconditional-core set`

which reads exactly like a real routing-claim defect and is not one.

**They were missed because every search that finds the other six misses these.** They are not in
`src/core/`, not in the attribution table, and not named by `anchors.sh` — the header talks about "the
table identity hash and `driver_only_attribution_ref`" and stops there. The grep that finds all nine is
now written into `anchors.sh`, with the enumeration, because the cost of missing one is a full sweep.

**This is the third consecutive item to re-baseline these anchors and the first to discover the true
size of the blast radius.** D16, D17 and D18 all moved `session.ail` anchors, which the three fixtures
do not reference — so the fixtures had never been touched by a re-baseline before and nothing recorded
that they existed.

---

## 8. THREE ROWS THAT MEASURED LESS THAN THEIR LABELS

**This is the fourth consecutive item to find one, and this item found three.** All three were caught
the same way — by mutating the thing the label names — and the three repairs went three different ways,
which is the useful part.

### 8.1 Repaired by building a new FIXTURE

`discovery_dst`'s `routing_handle_scenario` was written claiming its threading row caught **both**
driver defects of §2. Reverting the successor turned it red. **Reverting the re-seating left it GREEN.**

The reason is structural: `ctx` is rebuilt per batch, and `script()` emits one tool call per assistant
step, so every batch holds exactly one call and a per-batch `ctx` is never stale within it. **The two
answers agree on every single-call batch by construction** — WI-D18's empty-directory shape and WI-D19's
populated-directory shape for the third time.

The distinguishing input is a **batch of two**, and it needs both halves: two tool calls in one
assistant step *and* a policy that **allows** rather than suspends, because the pending path resolves
one call at a time through `c2_loop` and builds a fresh `ctx` for each — so an approval-gated batch of
two is still, for this defect, two batches of one. `batch_handle_scenario` is that fixture and it
catches the mutant by name.

### 8.2 Repaired by narrowing the LABEL, because no fixture could

`declared_vs_performed`'s `compose_tool_handle_threading` claimed to pin three links of the threading
spine. Measured: it pins **two**.

* `on_tool_handle` reverting to `next_state: ctx.world` — witness comes back **empty**. Red.
* `handle_compose_tool` passing its own `w` instead of `started.next_state` — witness shortens to
  `clock_now;`. Red.
* **`run_attempts` recursing on `w` rather than `w2` — witness UNCHANGED. Green.**

The third cannot be pinned in this process at all: without a model, `one_attempt` reaches its early
`NeedRetry` before any routed seam, so `w2` and `w` **are the same world**. The distinguishing input is
an attempt that actually performed something, which needs the model the probe does not have. **Named as
a gap rather than covered by a row that would pass either way.**

### 8.3 Avoided by writing the reachability row against the right subject

`routing_handle_scenario`'s S24 reachability row reads the two classes **the hook itself performs**
(`dir_make`, `file_write`). It deliberately does not read `provider_calls` or `tool_dispatches`: both
are non-zero in a run where the driver dispatched tools and `provided_tools` was left `[]` — which is
the state the file was in before the scenario existed, and is exactly the defect WI-D19 §8 recorded
about its own first draft. The `provided_tools: ["T"]` line carries a comment for the same reason:
`on_tool_handle` is the one **gated** slot, and left at `[]` the whole scenario passes while measuring
nothing.

---

## 9. THE YIELDS, SAID EXPLICITLY

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope_selftest` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| `ext_hook_scope_selftest` — shipped closure verdict | 4 of 15 | **4 of 15, "unmoved"** |
| door-3 residue | `intToFloat, show` | **`intToFloat, show`** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |

**Exactly as predicted, and for the predicted reason.** Door 3 is live throughout the routed chain —
`show(reading.now_ms)`, `show(attempt)`, `show(seen)` — so compose stays HOOK-UNRESOLVED however
completely 2b routes. A yield that had moved would have meant the instrument was reading something
other than what it claims to.

---

## 10. THE MUTANTS

Restored by `cp` throughout (S17). No git operation was performed while a mutant was in the tree
(D19 §1's second failure).

| # | Mutation | Result |
|---|---|---|
| 1 | `tool_phase` Delegate arm returns `world`; native clock starts from `world` | **RED**, 3 rows — `dir_make=0 file_write=0`, `handled/` empty |
| 2 | `tool_phase` drops the `ctx` re-seating only | **PASS against `routing_handle_scenario`** — see §8.1; **RED** against `batch_handle_scenario`, `handled/ holds [call_0.ail]` |
| 3 | `run_attempts` recurses on `w` instead of `w2` | **PASS** — see §8.2, and it is a gap rather than a repair |
| 4 | `handle_compose_tool` passes `w` instead of `started.next_state` | **RED** — witness `clock_now;` |
| 5 | `on_tool_handle` returns `next_state: ctx.world` | **RED** — witness empty |

**Mutant 2 is the one worth reporting**, and it reproduced WI-D18's mutant 5 and WI-D19's mutant 1 in
form: a row that passed first time because the fixture could not present the distinguishing input.
Under it the census stays perfectly balanced — both `dir_make`s and both `file_write`s are logged — and
what breaks is *which path each write names*. **A count cannot see a collision on a path key**, which is
the same lesson WI-D19 §5 recorded about the spelling and is why the graded row reads the final world's
directory rather than the log.

---

## 11. A WI-D18 PARAGRAPH IN `ports.ail` THAT THIS ITEM FALSIFIED

`Ports.dir_make`'s comment carried WI-D18's observability measurement in the present tense: *"all six of
compose's `mkdirAll` sites … are immediately followed by a `writeFile` … so no compose session TODAY
can observe a created-but-empty directory."*

**After this item there are ZERO ambient `mkdirAll` sites in compose** — D19 routed one and D20 routed
the other five — so a reader following that sentence would go looking for six sites and find none.
Tensed rather than deleted, per S15: it is the argument that decided the field's existence.

**Both of its own predictions were borne out and are now recorded as such.** It said the measurement
was "falsified by any future site that creates a directory and lists it before writing" —
`routing_intercept`'s `probe_empty` is exactly that, and `routing_tool_handle` goes further by listing a
directory to *derive* the name it then writes. And it said the measurement "is false the moment the
path key bites"; it bit twice, at `compose.ail:769` (D19) and `one_attempt` (D20), and the create moved
both times for the same `compose_module_header` reason.

---

## 12. RECORDED BINDINGS: DECIDED VERSUS DISCOVERED

**Discovered — a tool, a compiler or a measurement forced it:**

1. **`on_tool_handle`'s successor was dropped on EVERY arm, by a `.decision` projection one frame above
   a dispatcher that was correct** (§2.1). Found by walking the arms before routing, as the handoff
   required. Not predicted — the handoff anticipated "a `dispatch_tool_handle` whose successor survives
   only on the `Handled` arm", and the truth was that no arm survived and the dispatcher was innocent.
2. **`ctx.world` goes stale after the first tool call in a batch** (§2.2). Found while writing the fix
   for 1, and it inverts it: the obvious repair is a regression. Not predicted by anything.
3. **`ExtPorts.proc_exec` cannot take `rg` either** (§3). A second, unrelated binary makes the finding a
   property of the seam rather than of compose.
4. **`guard.ail` has no effect sites at all** (§4) — the handoff's fifth module is a false member; its
   apparent `readFile(`/`exec(` are string literals.
5. **`fileExists` is TRUE for a directory** (§4.3), measured against `std/fs` directly. It is what makes
   `file_exists_impl`'s two-call collapse behaviour-preserving, and it establishes that
   `read_file_impl`'s `"not_a_file"` arm is live rather than dead.
6. **Classifier 3 counts IMPORT LINES, not call sites** (§6). Found by reading the inventory after
   routing and seeing six ambient sources for effects nothing could still perform.
7. **The anchor re-baseline has NINE consumer sites, not six** (§7.1). Found by `make dst`, not by
   inspection, and the three that were missed produce a failure that reads like a real routing defect.
8. **`routing_handle_scenario` could not see the stale-ctx defect** (§8.1), and
   **`compose_tool_handle_threading` cannot see the `run_attempts` recursion** (§8.2). Both found by
   running the mutant rather than by reasoning about the row.
9. **`test_coverage`'s failure mode is not what WI-D19 recorded** (§14) — the module is found and six
   assertions fail; D19's `LDR001: module not found` was an artefact of measuring in an unsynced
   worktree. The target is red either way and is not this item's.

**Decided — the code admitted more than one answer and this item chose:**

1. **Fix the driver rather than report it, and fix BOTH halves together** (§2). Half a fix is a
   regression here, which is the reason the two are one decision.
2. **Report the scratchpad loopback rather than fix it** (§2.4) — a real defect of the same class, on a
   path `on_tool_handle` never travels, needing a core type change in another package.
3. **Do not widen `proc_exec`; leave four `exec` sites ambient** (§3), and accept the asymmetry of a
   module that keeps `std/process` while losing `std/fs` and `std/clock`.
4. **Leave `compose.check_snippet` and `run_snippet` UNTHREADED** (§4.1). A function performing only an
   unroutable effect has no successor to carry, and threading it would assert a mediation that did not
   happen.
5. **A `next_state` FIELD on `AuthorToolResult` and `AuthorLoopResult`, a WRAPPER for
   `AuthoringToolResult`** (§4.2) — the shape follows where the effects are, not the module.
6. **Route `store_snippet` although nothing calls it** (§4), so `store.ail` drops `std/fs` entirely.
7. **Remove the six imports this item made dead** (§6), against the handoff putting import removal in
   part 3 — because a stale ambient count is a measurement error rather than untidiness.
8. **Re-baseline the anchors rather than buy line-count neutrality with a cosmetic edit** (§7).
9. **Build a second graded fixture rather than narrow the first row's claim** (§8.1), and
   **narrow the label rather than fake a fixture** where none could exist (§8.2).
10. **Tense the WI-D18 `ports.ail` paragraph rather than delete it** (§11), per S15.

---

## 13. WHAT THIS ITEM DID NOT DO

* **`on_pre_step` and `on_solver_candidate` successor audits.** Two slots audited, two drops found; these
  two are still unaudited and the base rate is now 2 of 2.
* **The scratchpad loopback successor** (§2.4) — a real defect, structurally larger, different package.
* **`ExtPorts.proc_exec`'s widening or a `BashExec` routing** (§3).
* **Registration's four `config.ail` functions.** Disclosure, not routing.
* **Door 3's producer** and the hook-scope promotion.
* **`InitialWorld.files` and the program-schema bump**, owed since D17.
* **The eight stale classifier-2 literals**, now eight items stale.
* **`ambient_dir_list`'s sort mutant.** Still blocked on there being any target that drives an ambient
  directory read; 2b creates none either, because the routed scenarios run on `RecordingWorld`.
* **Compose's remaining unused imports**, if any beyond the six §6 removed — part 3's question is
  unaffected.

---

## 14. THE SWEEP

`make dst`, run ALONE on a frozen tree — the second attempt, for §1's reason.

**Two red targets, and both were red before this item:** `test_coverage_selftest` and `test_coverage`.
(`make dst` itself reports a third failure, `Makefile:199: dst`, which is the aggregate target
propagating those two under `--keep-going` rather than a distinct one.) `declared_vs_performed` reports
**40 passed, 0 failed**, up from 39 by this item's new reachability row.
Neither `src/core/prompts.ail`, `src/core/prompts_test.ail` nor anything in `tools/test_coverage/` is in
this item's diff, and `git diff f27c9a3 f9cb5bf` over those paths is **empty** — so they are unchanged
since WI-D19's own baseline measurement.

**One refinement to WI-D19's §12 binding 7, and it matters for whoever measures next.** D19 recorded
`test_coverage`'s failure as *"`src/core/prompts_test.ail` 0 of 6, every one `LDR001: module not found:
src/core/prompts`"*, measured in a `git worktree`. At HEAD in place the module IS found —
`src/core/prompts.ail` exists — and the failure is **6 of 6 assertions failing**
(`with_cache_hint empty hint identity`, `fmt_msgs empty`, …) plus the same `stale_skip_record`. The
target is red either way and not this item's, but **D19's recorded symptom was an artefact of measuring
in an unsynced worktree**, and repeating that method would keep reproducing the wrong diagnosis.

**Everything else is green**, including every gate this item touched or could have disturbed:

| Target | What it had to survive |
|---|---|
| `discovery` | two new scenarios, the batch fixture, the witness fields and the S24 rows |
| `declared_vs_performed` | 40 rows, including the new `on_tool_handle` spine arm and the raised arm count |
| `predicate_anchors` / `attribution_table` | the three re-baselined `tool_phase.ail` anchors |
| `driver_only`, `driver_plus_no_ops`, `profile_definition` | two version bumps, two content hashes and the three discovered-site fixtures — §7.1 |
| `world_state`, `invariants`, `program_persistence` | `tool_phase.ail`'s re-seating and three successor sites |
| `ext_ambient_inventory`, `ext_call_inventory`, `ext_hook_scope_selftest` | compose 28 -> 11 ambient, 5 -> 32 field calls |
| `conformance`, `hook_guard`, `smoke_*` | the rebuilt compose package and its four changed module signatures |

---

## 15. WHAT THE NEXT ITEM SHOULD KNOW

1. **AUDIT THE HOOK SLOT'S DRIVER ARMS BEFORE ROUTING IT — TWO FOR TWO.** And look one frame ABOVE the
   dispatcher: `dispatch_tool_handle` was correct, and the drop was in its caller's `.decision`
   projection. A grep for the slot name in the driver finds the dispatcher and misses the defect.
2. **CHECK THE READ SIDE AS WELL AS THE WRITE SIDE.** §2.2 — `ctx` is built per batch and the fold
   advances the world without it. Fixing the drop alone would have been a regression.
3. **`ExtPorts.proc_exec` fronts Motoko's TOOL NAMES, not subprocesses.** §3. Two unrelated binaries
   now confirm it. Any future site that shells out hits the same wall.
4. **Classifier 3 counts IMPORT LINES.** §6. An item that routes the last caller of an ambient import
   must remove the import in the same edit or the measurement goes stale in its favour.
5. **A row whose subject is a DERIVED answer needs a fixture that separates the derivation from the
   truth — fourth consecutive item.** §8. And when no fixture can, narrow the label and name the gap;
   a row that would pass either way is worse than no row.
6. **The anchor law has an exception.** §7 — a routing item re-baselines too, if it needs a driver-side
   codec. Price it.
7. **A MOVED ANCHOR TOUCHES NINE FILES, NOT SIX.** §7.1. The three `*_dst.ail` discovered-site fixtures
   are invisible to every obvious grep and their failure message reads like a real routing-claim defect.
   The enumeration and the grep that finds them are now in `anchors.sh`.
8. **Do not edit ANY tracked file while a long instrument runs**, not just during a mutation harness.
   §1 — this item lost a sweep to a comment-only edit it was certain was inert.
