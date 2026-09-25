# Handoff: WI-D20 — Route B part 2b: route `on_tool_handle`

Audience: a fresh session grounded against HEAD. **The second routing, and seventeen times the size of
the first.**

**Read first:** `NOTE-d19-route-b-part-2a-the-first-routing.md` §2 and §3 — they are both blockers you
inherit, and §3 is the one that will waste your afternoon if you skip it — then
`compose.ail:501-521` and `author_tools.ail:139-252`.

## The two things WI-D19 found that change how this item starts

### 1. `ExtPorts.proc_exec` CANNOT TAKE compose's `exec` sites, and you hit it twice more

D19 §2. The seam fronts `Ports.tool_exec`, whose live adapter is `tool_runtime.run_native_call` — an
if-chain over **Motoko's own tool names**. `proc_exec(w, "ailang", …)` reaches its final `else` and
returns *"ailang requires extension capability and is not available in native runtime"*. It also carries
no exit code, and both callers branch on one.

`one_attempt` calls `check_snippet` and `run_snippet` exactly as `on_response_intercept` did. **Decide
the seam question before you start routing, not halfway through.** The two live options:

- a real subprocess seam beside `proc_exec` — an ABI row, and the honest shape;
- routing `ailang` as a `BashExec` **tool dispatch** — no ABI change, but it puts a compiler invocation
  into the run's tool-dispatch census, where `w.tool_dispatches` and `ToolIdentity` will count it.

**Either is a decision with consumers. Neither is a detail.**

### 2. THE DRIVER DROPS HOOK SUCCESSORS, AND YOU MUST WALK `on_tool_handle`'S ARMS FIRST

D19 §3. `session.c2_loop` carried `ResponseInterceptOutcome.next_state` on **one of four arms** and
dropped it on the other three, plus once more into `dispatch_solver_candidate`. **It had been that way
since WI-B2b and no instrument in the tree could see it**, because every hook returned `ctx.world`
unchanged and the two answers produce identical worlds.

**`on_tool_handle` was not audited.** Neither was `on_pre_step` nor `on_solver_candidate`. Route the
hook against a dropped successor and your recorder writes into a world nobody keeps — the symptom is
`check_discovery` reporting `0` against your witness, which is what found it the first time.

**Do the audit BEFORE the routing, and assert it separately.** A `dispatch_tool_handle` whose successor
survives only on the `Handled` arm is the same defect with a different slot name.

## Mission

**Route `on_tool_handle` and the seventeen effect-bearing functions it reaches**, across `compose.ail`,
`author_tools.ail`, `dispatcher.ail`, `store.ail` and `guard.ail`.

D19 measured the partition and it stands: **41 functions must thread `(ports, world)`, 15 exported,
across 8 modules**, of which registration's 4 are structurally unroutable and 3 were part 2a's.

## What part 2a already built that you should copy rather than re-derive

- **`remove_if_file` is the pattern, and it is a FUNCTION rather than a shape.** Seventeen of your sites
  are the `if fileExists(p) then removeFile(p) else ()` guard. Copy the function; do not re-decide it
  per site. D19 §4 has the argument for `path_stat` over `file_read.present` and it does not change.
- **The exhaustive `ExtPathKind` match**, for the reason `ext_ports_of` states at the other end.
- **`compose_intercept_threading`'s tracing ports** (`declared_vs_performed.ail`). They write their own
  name into the world token and return it, so the world that comes out of the dispatcher IS the ordered
  list of seams that were called. That is the cheapest S24 instrument in the tree and it generalises to
  your slot in about twenty lines.
- **`discovery_dst`'s `routing_intercept` scenario** is the graded home. Adding a routed
  `on_tool_handle` beside it is a hook and three lines of witness.

## The path key bites again, identically

`one_attempt:501` creates `"${ctx.workdir}/tmp"` and `:504` writes `"tmp/${snippet_name}.ail"`. **Same
defect, same fix, and the direction is not a choice**: `compose_module_header` emits
`module tmp/${name}` and AILANG resolves a module path against the file's path, so the write cannot
become absolute and the create is what moves. D19 §5.

**Fix it at the call site. Do not teach the world to guess** — still D18's stop condition.

## The tripwires you inherit

**The three filesystem classes are now WITNESSED rather than pinned** (`DiscoveryWitness.file_writes`,
`file_removes`, `dir_makes`), and **every graded run except D19's routed scenario passes 0**. So the pin
is still armed: the moment an `on_tool_handle` write reaches a graded profile, that run's witness has to
be filled in by hand and `check_discovery` names the class if you get it wrong.

**`ExtensionEffect` and `RandomDraw` stay at literal zero** and should — their unreachability is
structural, not "nothing calls them yet".

**Watch `declared_vs_performed` for the same move D19 made.** Routing a hook removes the ambient effect
its `must_die_on` row was asserting. D19's `compose_intercept_inline` went from dying on `FS` to dying
on `Process`; whichever of your sites is the last ambient one in a slot decides what that slot's row can
still claim. **Move the row and say why — do not delete it.**

## What this will NOT move, said in advance

**The yields.** 4 of 15 and 5 of 15, unchanged through D19 and unchanged here: door 3 is live in
`one_attempt` too (`show(now())`, `show(attempt)`), so compose stays HOOK-UNRESOLVED however completely
2b routes. **Criterion 1 does not move either** — `ExtPorts.file_write` declares `! {FS}`.

What moves is `ext_ambient_inventory`'s **`ExtPorts` field calls in closure**, which D19 took from 0 to
5. That is criterion 2, and it is the whole of the prize.

## Definition of done

- **All seventeen functions threaded**, or a named list of what did not and why.
- **The `proc_exec` decision taken and recorded** — including "not routed, again", if that is the answer.
- **The driver-arm audit for `on_tool_handle`**, asserted rather than read.
- **The `one_attempt:501` spelling fixed**, with the compiler reason at the site.
- **A graded, routed `on_tool_handle` scenario** in `discovery_dst`, with witnesses that are not read
  off the log.
- **Per S24** — reachability asserted separately from verdict, and check that your reachability row does
  not measure less than its own label. D19's first draft did exactly that (§8) and it is the third
  consecutive item to.
- **Per S13/S9/S17/S26** — `make sync_packages` first (seventeenth consecutive item); sweep cache-cold;
  restore mutants by `cp`, never `git checkout`; append to shared fixtures.
- **Do not start two `make dst` sweeps.** D19 did, they corrupted each other's logs, and the failure
  they produced looked exactly like a real one (§1).

**A prediction to falsify: this item SHOULD trigger the anchor cascade if it touches `ext_ports_of`, and
should NOT if it only adds call sites.** D19 touched `session.ail` and avoided the cascade by making
every edit line-count-neutral, at the cost of putting the explanation in the ABI file instead. If you
need more than an expression swap in `session.ail`, **plan to re-baseline** — that is D18's law, and D19
is the corollary rather than a counterexample.

## Out of scope

- **Door 3's producer** and the hook-scope promotion. Still parallel.
- **Registration's four `config.ail` functions.** Disclosure, not routing.
- **Removing compose's unused imports** — part 3, and note that D19 made none unused: `one_attempt`
  still uses every one.
- **`InitialWorld.files` and the program-schema bump**, owed since D17.
- **The eight stale classifier-2 literals**, now seven items stale.
- **`ambient_dir_list`'s sort mutant.** D19 §11 — it is blocked on there being any target that drives
  an ambient directory read, which 2b does not create either.

## Stop and report rather than deciding inline

- **If routing forces a change to `ToolHandleOutcome` or any hook slot's type**, stop. That is an ABI
  change and the successor field already exists.
- **If a routed call cannot be made without production code branching on test mode**, that falsifies D1.
- **If the driver-arm audit finds a drop you cannot fix line-count-neutrally**, do not skip the fix to
  protect the anchors. **The anchors are an instrument; the drop is a defect.** Re-baseline and say so.

## Report back

Forty-fourth calibration run.

- **The git wall-clock window.** D19, D18 and D17 are the comparison.
- **How many of the seventeen threaded**, and any that did not.
- **The `proc_exec` decision.**
- **What the driver-arm audit found for `on_tool_handle`** — this is the report's most valuable line,
  the same way §2 and §3 were D19's.
- **Whether the anchor cascade fired**, and whether it was avoidable.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **80 across
  forty-three runs** after D19's six. Two of D19's were rows that measured less than their own label,
  and both were repaired by fixing the FIXTURE rather than the code — treat any row whose subject is a
  *derived* answer as suspect until a fixture separates the derivation from the truth.
- **The yields**, which should be 4 of 15 and 5 of 15. Say so explicitly if they are.
