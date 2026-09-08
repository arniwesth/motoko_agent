# Handoff: WI-D19 — Route B part 2a: route `on_response_intercept`

Audience: a fresh session grounded against HEAD. **The first routing in this project.** Every seam
built at C5, D16, D17 and D18 has zero callers; this item gives six of the seven their first.

**Read first:** `NOTE-d18-the-directory-seam-and-the-path-key.md` §5 (the path-key rule you must obey)
and §14, then `compose.ail:761-800`.

## Why routing starts now, when door 3 is still open

**Door 3 gates the VERDICT, not the BUILD** — D16's rule, and this project conflated the two for nine
consecutive items before D16 named it. D18's report says *"part 2 is blocked on ONE thing: door 3's
producer"* and then, in the same sentence, that all nine sites **are routable**. The second half is the
accurate one. **Repeating the conflation now would be the same error with a different blocker.**

## Part 2 is too big for one item, and here is the measurement

**41 functions must thread `(ports, world)` — 15 of them exported, across 8 modules.** That is the
transitive closure of the 21 functions that call a routable builtin, and it is the real price of "route
compose". D15 estimated *6 modules holding ~23 hook-reachable sources* and called it a lower bound; it
was.

### A correction to my own measurement, because it reproduces a trap this project already named

A naive call-graph walk from `register_with_config` reports **20 of the 21** effect-bearing functions as
reachable. **That number is wrong and the reason matters:** registration *constructs* the
`ExtensionHooks` record, so every hook body is reachable *through the constructor* without being
executed at registration time. **That is classifier 3's coarsening — "an import alone is a rejection;
a call site is not required" — reproduced in a five-line reachability walk**, which is worth knowing
before anyone trusts a similar walk to price 2b.

**The honest partition, by what actually runs when:**

| Entry | Effect-bearing functions | Status |
|---|---|---|
| **Registration** — `register.ail:9` `getEnvOr`, `:10` `read_compose_host_config` → `read_compose_config`, `read_snippet_caps`, `read_json_silent` | **4, all in `config.ail`** | **Structurally unroutable** — registration runs before the world exists (D15). Disclosure, not routing. |
| **`on_tool_handle`** | **17**, across `compose.ail`, `author_tools.ail`, `dispatcher.ail`, `store.ail`, `guard.ail` | **Part 2b.** The large half. |
| **`on_response_intercept`** | **3**, all in `compose.ail` | **THIS ITEM.** |

## Mission

**Route `on_response_intercept` and the two functions it reaches**, and nothing else.

Nine effect sites, three functions, one module — the complete inventory, verified:

| Site | Call | Seam |
|---|---|---|
| `:767` | `now()` | `ExtPorts.clock_now` |
| `:769` | `mkdirAll("${ctx.workdir}/tmp")` | `ExtPorts.dir_make` |
| `:771` | `writeFile(path, …)` | `ExtPorts.file_write` |
| `:774`, `:785` | `fileExists(path)` | **your decision — see below** |
| `:774`, `:785` | `removeFile(path)` | `ExtPorts.file_remove` |
| `check_snippet:260` | `exec("ailang", ["check", …])` | `ExtPorts.proc_exec` |
| `run_snippet:275` | `exec("ailang", ["run", …])` | `ExtPorts.proc_exec` |

**Six of the seven `ExtPorts` seams get their first caller here.** Only `env_get` does not, and it is
the one D16 deliberately declined to widen.

**And this is the twin of the chain every decision so far was argued from.** D16 measured
`compose.ail:502-521` — write, exec-reads-the-path, branch, `fileExists`/`removeFile` — inside
`one_attempt`, which is 2b's subtree. **`:769-785` is the same chain in the smaller hook**, so this
item validates D16's, D17's and D18's reasoning against the code that motivated it, at a tenth of 2b's
size.

## The decision this item owns

**`fileExists` at `:774` and `:785`: `path_stat` or `file_read.present`?**

D18 built `path_stat` deliberately as a *different question* — *"what kind of thing is at this path"*
against D3's *"does this path hold bytes I can read"* — and kept both narrow rather than widening
`FileRead`. **Here the question is "is there a file to remove", and both seams can answer it.**

`file_read` returns the content too, which this site does not want and which the recorder would then
have to decide about. `path_stat` returns a three-valued kind, of which this site uses one bit.
**Choose, and say which question the call is actually asking** — this is the first time either seam has
had to answer a real caller, and the choice sets the pattern 2b will copy seventeen times.

## The rule you inherit and must obey

**One spelling per path. The world keys on raw strings and does not normalise** — D18's decision,
written at `WorldState.files`.

**`compose.ail:769` and `:771` violate it today.** `:769` creates `"${ctx.workdir}/tmp"`; `:771` writes
`"tmp/${name}.ail"`. On disk they agree whenever the process runs in `workdir`; **in the world they are
two different directories.**

**Route them unchanged and the run produces a `dir_make` on one path and a `file_write` under another**
— `dir_list` then reports an **empty directory** where the file is. **The symptom is `entries: []`,
which is a plausible answer rather than a crash**, and `world_state_probe` row 8 already pins exactly
this shape as decided behaviour.

**Fix the spelling at the call site. Do not teach the world to guess** — D18's stop condition on giving
`WorldState` a working directory still stands.

## Three tripwires will go red, and that is this item's success condition

`dst_discovery.absent_classes` pins **`file_write`, `file_remove` and `dir_make` at zero in both
directions**, added at D17 and D18 deliberately so that the first routing would have to answer for
itself by name.

**The moment this routes on a graded profile, `check_discovery` fails with `file_write over-recorded:
expected 0, got n`.** That is the mechanism working. **Give each class a real witness, or move it out of
the list — in both cases having said which, and why.** Do not silence it by not grading the profile.

## What this will NOT move, said in advance so a flat number is not read as failure

**The yield.** Classifier 3 closure is **4 of 15** and hook scope **5 of 15**, unchanged since D15.
**Door 3 is live in this very chain** — `:767` is `show(now())`, and `show` is the non-underscore
builtin D15 found — so compose stays HOOK-UNRESOLVED however well this routes. **A yield that moved
here would mean the instrument was reading something other than what it claims to.**

**And criterion 1 is not what this buys.** `ExtPorts.file_write` declares `! {FS}`, so a caller that
routes through it still carries `FS`. `on_response_intercept`'s declared row does not narrow.
**Criterion 2 — mediation — is the whole of the prize, and D9/D10/D13/D15 are what make it countable.**

## Definition of done

**All nine sites routed through `ctx.ports`**, with the world threaded from `ctx.world` and the
successor returned on `ResponseInterceptOutcome.next_state` — **which already exists
(`types.ail:551`), so no ABI change is required.**

**The `fileExists` seam decision taken and recorded.**

**The `:769`/`:771` spelling fixed at the call site**, with a note saying why.

**The three tripwires answered by name.**

**The two un-witnessed mutants from D18 §7 given their first witness** — `ambient_dir_list` without the
sort, and the `session.ail` bridge deriving `present` from the entry count. Both are covered by comment
and nothing else. **Assert them; do not assume the comments held.**

**Per S24** — reachability asserted separately from verdict. A routed call that is never executed
proves nothing, and "the seam has a caller" is not "the caller ran".

**Per S13/S9/S17/S26** — targets in `make dst`; sweep cache-cold with `AILANG_RELAX_MODULES=1` clearing
the **dependents** of any edited interface; `make sync_packages` first (sixteenth consecutive item);
restore mutants by `cp` or `tar` — **S17 was violated at D18 by a `git checkout` that reverted the
item's own work**; extend shared fixtures by **appending**.

**A prediction to falsify rather than inherit: this item should NOT trigger the anchor cascade.** Four
consecutive items re-baselined five `session.ail` anchors and re-issued both profiles, because each
changed a surface `session.ail` sits above. **This one changes an extension package, not the ABI and
not `session.ail`.** If the anchors move anyway, that is a finding — say what moved them.

## Out of scope

- **`on_tool_handle`** — part 2b, 17 effect-bearing functions across five modules.
- **Registration's four `config.ail` functions.** Structurally unroutable; D5's disclosure obligation is
  their home, and the fourteen `register_with_config` rows are the artifact that carries it.
- **Door 3's producer**, and the hook-scope promotion. Still parallel, still not this.
- **Removing compose's now-unused imports** — part 3, and it is what a closure-unit verdict needs.
- **`InitialWorld.files` and the program-schema bump** — owed since D17, and D18 grew it a field.
- **The eight stale classifier-2 literals**, now six items stale.
- Installing anything; the eleven-row table for either profile; classifier 1's repair; the stdlib
  cache's producer; the gate-table State column; F3; the ABI major at fifteen rows.

## Stop and report rather than deciding inline

- **If threading the world through `check_snippet`/`run_snippet` forces a change to
  `ResponseInterceptOutcome` or to any hook slot's type**, stop. That is an ABI change and this item was
  scoped on the fact that it needs none.
- **If a routed call cannot be made without production code branching on test mode**, that falsifies D1
  — B2b's stop condition, unchanged and now finally testable against a real caller.
- **If routing reveals that a seam built at D16/D17/D18 answers the wrong question**, stop and report
  before widening it. Four items built these on measurements taken without callers; **the first caller
  is the first real test**, and a seam that needs changing is a finding, not a defect to patch quietly.

## Report back

Forty-third calibration run, **and the first item in this project that adds a call site rather than a
surface.**

- **The git wall-clock window.** D18 ran ~1h03m, D17 ~1h05m.
- **Whether all nine sites routed**, and any that did not, with the reason.
- **The `fileExists` seam decision.**
- **What the three tripwires were answered with.**
- **Whether the anchor cascade fired.** The prediction above is that it should not.
- **Whether any seam needed changing on contact with its first caller.** This is the report's most
  valuable line either way.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **74 across
  forty-two runs**, and D18 contributed two — one of them a green row measuring less than its own label.
  **A routed call that compiles and never runs is this item's version of that shape.**
- **The yields**, which should be 4 of 15 and 5 of 15. Say so explicitly if they are.
