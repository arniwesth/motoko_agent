# NOTE-005 — Third session: the compaction blind spot, ungated examples, and a session that cannot delegate (2026-09-01)

Evidence base: a third, independent Motoko session (53 live steps), run two
days after the second (NOTE-002, 2026-08-30). Unlike the first two sessions,
this one was run **without a task**: the operator's instruction was to exercise
Motoko's capabilities broadly in order to find weaknesses a targeted task would
never reach. That framing is why the findings below are different in kind —
they are not "the agent failed at X" but "a whole subsystem was never on".

Marks follow NOTE-002: `[new]` (first sighting), `[x-confirm]` (independently
reproduced), `[extend]` (deepens a known finding).

## What was verified

| Item | Result |
|---|---|
| `make check_core` | 56 passed, 0 failed; `verify_extensions (default): 9 booted, 0 failed` `[x-confirm]` |
| `make verify_core` | 11 contracts proven, 0 unstated, 1 blocked, 0 files failed, 48 bare `[extend]` |
| `make test_core` | 19/19 passed `[x-confirm]` |
| `make profile_coverage` | PASS (incl. the B3 atom unit and the 8-kind enumeration guard) `[new]` |
| `make conformance` | self-test PASS, registry probe PASS; ABI 6.0, conformance kit 5.0.0 `[new]` |
| `make attribution_table` | rc 0, anchors intact `[new]` |
| Z3 commit gate (planted false contract) | `check: passed / verify: failed / committed: no` — the cell was rejected `[x-confirm]` |
| Z3 accept gate (true contracts) | 3/3 verified `[x-confirm]` |
| AILANG hashline edit + SHA-256 guard | applied on fresh hash; **stale hash rejected**, no silent clobber `[new]` |
| ctx_batch_execute (context-mode extension) | 2 commands indexed, query returned scoped hits `[new]` |
| `ailang test` on a fresh `.ail` file | type-check + effect-check clean `[new]` |
| Python scratchpad plotting (`display(fig)`) | rendered to `.motoko/artifacts/core_ext_v2/cell1-1.png`; the py kernel's `display` path works `[new]` |
| JavaScript scratchpad kernel | ran; cross-checked `compaction.ail:26` arithmetic independently `[new]` |
| `make world_state` (poison-pair routing) | PASS — 68 checkmarks, both witnesses PASS; all 5 capability classes (AI, Clock, Env, FS, Process) proven routed, plus "no driver module reaches `std/rand`" `[new]` |
| AILANG `run` path (real execution) | entrypoint executed and printed; effect-check held `[new]` |

The verifier honesty probe deserves its own line because it is the control that
makes every other "verified" claim in this project mean anything: a contract
that is **true** commits, and one that is **deliberately false**
(`ensures { result == a + b + 1 }` on a body returning `a + b`) is **rejected
and not committed**. That is ADR-001's cell boundary holding on demand, three
sessions running.

## Defects found

### 1. `[new]` Compaction is silently, permanently disabled on the default profile

The highest-consequence finding of the session, and it is invisible unless you
go looking.

`MotokoRuntimeStatus` reported, on every poll across the whole session:

```json
"context_limit": 0,
"last_sent": { "input_tokens": 71787, "usage_pct": 0 },
"uncompacted_pending": { "estimated_tokens": 51304, "calibrated_tokens": 71852, "calibrated_pct": 0 }
```

Real traffic, 51K tokens of retained history — and **0%** on every percentage.
Compaction cannot fire.

The chain, verified end to end:

1. The active model is `openrouter/tencent/hy4-preview` (`.motoko/config/default/config.json`).
2. `.motoko/model-catalog.json` carries 23 `context_limits` entries —
   including sibling entries `openrouter/tencent/hy3` and
   `openrouter/tencent/hy3:free` (262144 each) — but **no entry for
   `hy4-preview`**, in either the prefixed or unprefixed form.
3. The default profile sets no `agent.context_limit` override. Only 2 of 14
   profiles do (`local`, `deepseekv4-flash-compaction-live`).
4. `resolve_context_limit` (`src/core/context_usage.ail:164`) therefore falls
   through to its documented else-branch: `0`, "unknown".
5. Every consumer defines 0 as *disabled*, and they all do it correctly per
   their own contract:
   - `usage_percent_with_limit` (`src/core/compaction.ail:26`, mirrored at
     `packages/motoko-ext-compaction-structural/compaction_structural.ail:42`)
     → `if limit == 0 then 0`
   - `calibrated_usage_percent_with_limit`
     (`compaction_structural.ail:61`) → same
   - `compaction_ai.ail:533` guards its `hard_override_pct` safety refresh on
     `ctx.context_limit > 0`

So a single missing catalogue row propagates into: no threshold comparison, no
calibrated safety refresh, no oversized-tool-output handling (guarded by
`limit > 0` at `compaction_structural.ail:89`). The compaction extensions are
installed and booting — `verify_extensions` passes 9/9 — and are doing nothing.

**Why this is the right kind of finding for this project.** It is a *fail-open*
boundary, the exact shape ADR-001 exists to eliminate, but it sits one layer
below where ADR-001 has been looking: ADR-001/PLAN-001 concern the
**finalization** boundary (DP7's `Err(_) => Approve`). This is the
**measurement** boundary, and it fails open in the same direction — an absent
input becomes "no problem detected" rather than "cannot measure". The
difference is that DP7's fail-open is a one-line inversion, whereas here the
fail-open is *load-bearing for correctness elsewhere*: every consumer has a
deliberate, individually-documented `limit == 0` branch, so no single one of
them is wrong. The defect is compositional.

Note also the interaction with NOTE-002's fold-verification wall: the
compaction math is pinned to verification tier 4 (unit tests) because folds
auto-skip. The one number that decides whether this session gets compacted is
both unverified *and* — on this profile — permanently zero.

**Not established:** whether this ever *should* have fired on this profile, or
what the correct limit for `hy4-preview` is. The catalogue is the missing
input; I did not add an entry, because a guessed window is worse than an
honest unknown (see README's "compaction is skipped rather than guessed from
provider-family prefixes"). What is established is that the absence is silent:
nothing in the status output, the gate results, or the logs distinguishes
"healthy, low usage" from "measurement disabled".

### 2. `[extend]` Example rot — now reproduced in this repo, and the cause is pinned

NOTE-002 found the teaching example `ailang/examples/.../discount_calculator.ail`
broken because examples are not CI-gated. This session found the same failure
mode **inside motoko_agent**, in both shipped examples:

| File | `ailang test` |
|---|---|
| `examples/smoke_registry_roundtrip.ail` | **0 passed, 6 failed** |
| `examples/smoke_a2a_delegate.ail` | **0 passed, 3 failed** |

Both fail on the same root cause: `a2a_hooks_register_capabilities` uses
effects not declared in its signature — `Missing effects: Net, Rand`, with the
fix suggested as `! {Net, Rand[mode=os]}`.

`git log` pins the regression precisely: **`8df66011` (2026-08-26), "MOT-129
B8: ABI 6.0 — Capability list, ExtEntry { id, caps }, ExtRegistry { entries };
17 packages + host + fixtures migrated"**. The migration updated 17 packages
plus the host and fixtures. `examples/` was not in that list, and neither file
appears anywhere in the `Makefile`, `scripts/`, or `.github/` — confirmed by
search. The rot is five days old and undetected.

This upgrades NOTE-002's finding from anecdote to pattern: **the ABI-6.0
migration is a general producer of this defect class.** NOTE-002 had the
mechanism (examples ungated → silent rot); the addition here is the *predictor*
— every surface a migration does not enumerate is a surface that rots — which
is precisely the argument ADR-002 makes for generated-and-gated artifacts. A
gate enumerating `examples/` would have gone red on 2026-08-26.

### 3. `[x-confirm]` + `[extend]` Optional-backend fragility, and now delegation itself

NOTE-001 and NOTE-002 both recorded Lean/Lake missing. Confirmed again: Lean
cells report "Lean/Lake unavailable; cells were skipped".

This session adds three more absent or broken backends, and the consequence is
larger than before:

- **`ExaSearch` is non-functional**: `mcp bundled bridge unavailable: package
  not installed: sunholo/motoko_ext_mcp` (exit 127). The extension is listed
  in the default profile's `extensions.order`, so it advertises a tool that
  cannot run.
- **`CodexExec` is unauthenticated**: 401 Unauthorized on every attempt,
  WS then HTTPS fallback, `turn.failed`.
- **`Delegate` cannot spawn**: herdr matched no screen rule for the new pane —
  it is sitting on a sign-in screen or a modal — so the pane was closed.

The compound effect is that **a long-running session has no way to run a long
gate.** `make check_core` alone outlasts the 35s `BashExec` ceiling (measured:
the harness killed it at 35,016ms). With delegation dead and Codex dead, the
only path was `setsid` background jobs plus polling. That is a workaround an
operator has to *discover*, and the failure surface is confusing: an
unauthenticated delegate looks like a tooling problem, not like "you cannot
run your own test suite".

### 4. `[new]` Exit codes are masked by pipes in gate recipes

`ailang run … --entry main examples/smoke_registry_roundtrip.ail 2>&1 | tail -12; echo "RC=$?"`
printed `RC=0` on a run that had genuinely failed. Re-run without the pipe:
**true rc 1**. `tail` owned the exit status.

Two things make this worth recording. First, it is a live trap for any agent
or script auditing this repo — a piped gate can report success while failing.
Second, `check_core`'s own recipe is in this family (its loop runs
`ailang check "$$f" >/dev/null 2>&1` and counts, which is correct, but the
pattern is one careless edit from inverting). Worth a `set -o pipefail`
sweep, or at minimum a convention note.

### 5. `[new]` Cumulative token counters reset mid-session, and it is not a bug

Worth recording because it looks exactly like one, and I reported it as an
unresolved caveat before tracing it.

Two consecutive `MotokoRuntimeStatus` polls in this session:

| Poll | `current_step` | `provider_calls_completed` | `usage.input_tokens` |
|---|---|---|---|
| step 52 | 52 | 53 | 2,718,262 |
| step 66 | **0** | 66 | **92,599** |

The cumulative input-token total *decreased* by ~2.6M while the provider-call
count rose. Cumulative counters should not go backwards.

**Resolution — the loop was re-entered, and the reset is deliberate.**
`c2_initial_state_with_counts` (`src/core/session.ail:707`) resets the
per-loop accumulators:

```
step_idx: 0,
totals: zero_totals(),
```

but **threads `prior_counts` through unchanged** (`prior_counts: prior_counts`).
`runtime_status_json` (`:558`) then reports
`runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace))`
— so the call counters are cumulative *across* loop re-entries and the token
totals are cumulative *within* one. The two numbers in the same status block
are counting different things, by construction.

This is correct, but it is quietly a third instance of the session's theme:
**the status surface reports two separate accumulators under the same `usage`
heading with no marker of which is which.** A reader comparing them across a
re-entry sees an impossibility. `steps_executed_so_far` is documented in this
note's own finding 1 as deriving from `provider_calls_completed` (`:574`), so
even the step count and the displayed `current_step` are different clocks —
`current_step` is the tool-step index passed in (`tool_step_idx`, `:571`),
reset per loop; `steps_executed_so_far` is not.

No fix proposed beyond a naming or note change; recorded so the next reader
does not chase it as a defect, and because "two counters, same block, no
marker" is the same legibility gap as finding 1.

### 6. `[new]` Recursion: the verifier says "counterexample" where the repo says "blocked"

Found by running the AILANG `run` path (an entrypoint that actually executes,
which no prior session had exercised) against a recursive function carrying a
*true* contract:

```
pure func sum_to(n: int) -> int
  requires { n >= 0 }
  ensures { result >= 0 }
{ if n <= 0 then 0 else n + sum_to(n - 1) }
```

Result: `check: passed | verify: failed | committed: no | ran: yes`, with
`not committed: verifier found a counterexample`.

The contract is true and the function is correct — it ran fine and printed
from its entrypoint. So "counterexample" is doing something different from
what it says.

Cross-checking the repo, recursion is a **known, documented** verifier
limitation at three core sites, and they describe it two ways:

- `src/core/agents_md.ail:38` — `contracts: BLOCKED — RECURSIVE`, with the
  termination property ("dirname's result is strictly shorter than its
  input") needing the callee de-recursed first.
- `src/core/tool_runtime.ail:57` — the sharper statement: with a trivial
  contract "the verifier does not SKIP it, it errors — 'unrolling recursive
  function: ... unsupported pattern type *core.ListPattern in SMT encoding'
  — which `verify_core` reports as a FAILED file."
- `src/core/tool_runtime.ail:103` — same class.

And `verify_core`'s own taxonomy (Makefile ~L2413) lists `RECURSIVE` as a
**`blocked`** cause: "an ensures exists and the Z3 fragment rejected it".
Blocked is reported, never failed.

So the same underlying condition is called `blocked` by `verify_core`,
`ERROR` by `tool_runtime.ail`'s comment, and **"verifier found a
counterexample"** by the scratchpad gate. Those three descriptions have
different engineering consequences: `blocked` invites a workaround, `ERROR`
invites a fix, and "counterexample" asserts the code is **wrong** — which, for
`sum_to`, is false.

This matters more than a naming quibble because of the direction of the error.
`verify_core` deliberately refuses to fail the build for `blocked`, on the
reasoning that failing would make deleting the contract the cheapest route to
green. But the scratchpad's `verify: required` path **rejects the cell** on the
same condition. The two surfaces disagree about whether an unprovable-but-true
contract is a build failure, and the scratchpad's message actively
misattributes it to a logic error. An agent reading "verifier found a
counterexample" will rewrite correct code.

**Not established:** whether the scratchpad path is a different codepath from
`verify_core`'s (likely — it gates a single cell rather than a file) or exactly
which recursive shapes produce `counterexample` vs `unsupported pattern`. What
is established is that at least one recursive function with a true contract is
rejected with a message that says its logic is wrong.

### 7. `[new]` A DST smoke script is hardcoded outside the FS sandbox

`make dst DST_JOBS=1` (the full sequential sweep) reports:

```
✗ scripts/smoke_phase_a_tool_parity.ail
Error: execution failed: path "/tmp/phase-a-tool-parity" escapes sandbox "/workspaces/motoko_agent"
```

The script hardcodes its workdir at `scripts/smoke_phase_a_tool_parity.ail:58`
(`let workdir = "/tmp/phase-a-tool-parity";`) while `AILANG_FS_SANDBOX` is set
to the project root — so every run of this script inside the sandbox dies
regardless of correctness.

Two things make this worth more than a one-line fix:

- **`DST_KNOWN_RED` is empty at this commit** (Makefile:493), yet the sweep
  is red. So this is not a tolerated-known failure; it is a
  not-currently-passing target in the sweep the project points at as its
  primary gate.
- The target is one of eight in the DP7 smoke loop (Makefile:2127-2134), and
  the loop is preceded by `scripts/setup_dp7_smoke_workdirs.sh` — i.e. the
  repo *already knows* these scripts need prepared workdirs. This one simply
  was not migrated to whatever convention the setup script establishes.

**Now established — environment-dependent, and proven so.** I previously
flagged this as unverified; it is now settled by direct experiment. With the
sandbox variable removed, the same script passes:

```
$ env -u AILANG_FS_SANDBOX ailang run --caps ... scripts/smoke_phase_a_tool_parity.ail
phase_a_tool_parity PASS          # rc 0
```

`AILANG_FS_SANDBOX=/workspaces/motoko_agent` is set in this container and
exported into the make child. So two of the sweep's three red targets
(`smoke_parity`, `smoke_driver`) are **environment artifacts, not code
defects**: the script is fine wherever the sandbox is unset, and fatally
red wherever it is set. That materially lowers their severity — but it does
not make them unreal, because the container the project ships
(`.devcontainer/`, and the one these sessions run in) is one where the
variable is set.

Note the second, independent `/tmp` dependency:
`smoke_parity`'s own recipe (Makefile:232-241) writes to
`/tmp/phase_a_parity_{a,b}` via `scripts/dst/phase_a_event_parity.sh`, which
takes its output dir as `$1`. That path is outside the sandbox too, though
the observed failure came from the `.ail` script's hardcoded workdir first.
A fix that moves only the `.ail` script's workdir may expose this one.

7 of the 32 `scripts/smoke_*.ail` files reference `/tmp/`, so this is a
pattern and not a one-off.

A fix is likely one or two lines — point the workdirs inside the project (e.g.
under `tmp/`) or have the setup script create them — but I did not apply it,
because choosing the right home for them is the repo's convention to set, not
mine to guess.

#### The full sweep: `make dst DST_JOBS=1` is red, 3 targets, 789s

The complete sequential sweep ran to completion and **failed**:

```
─── make dst ──────────────────────────────────────────────────
  789s wall, -j1, load 1.55 2.08 1.82
  FAILED (3):
    ext_hook_scope_selftest      NEW — this one is yours
    smoke_driver                 NEW — this one is yours
    smoke_parity                 NEW — this one is yours
  exit 2 — make's "errors were encountered". See the NEW rows above.
```

With `DST_KNOWN_RED` empty (Makefile:493), all three are `NEW` — i.e. the
sweep is not in a tolerated-red state. Roughly 1,100 checkmarks passed. Three
distinct causes, none of them flaky:

1. **`smoke_parity`** and **`smoke_driver`** — both the `/tmp` sandbox escape
   above (`smoke_parity` calls the script directly; `smoke_driver` reports
   `1 failed` for the same reason). One root cause, two targets.
2. **`ext_hook_scope_selftest`** — a genuinely different and more interesting
   failure:

   ```
   FAIL DOOR-3 RESIDUE: expected ['intToFloat', 'show'], got ['f', 'intToFloat', 'show'].
   This set is pinned because it is a PRODUCER gap, not a verdict: it must
   neither grow unnoticed nor be quietly assumed away.
   ```

   A pinned set grew by one member (`f`) and the gate caught it. That is a
   gate doing exactly its job — and it is the best counter-evidence to this
   note's running "absence renders as health" theme: here, presence rendered
   as failure. Worth recording alongside finding 6, because together they say
   the enforcement surface is not uniformly permissive; it is *inconsistent
   about which direction it errs in*.

The sweep's own summary mechanism deserves credit: it names the failing
rows, marks them `NEW` vs known, and points at the full log. A red sweep
that tells you which three of its targets are yours is substantially more
useful than one that prints `Error 2`.

**Caveat on attribution:** I did not verify whether these three are red at
HEAD for everyone or only in this container. Finding 7's `/tmp` cause is
very likely environment-dependent (it depends on `AILANG_FS_SANDBOX` being
set, which it is here). The `ext_hook_scope_selftest` residue failure looks
environment-independent. I report the sweep as observed: rc 2, three named
targets, this container, this commit (`47db38a`).

#### The `ext_hook_scope_selftest` failure, fully resolved

This one is worth the detail because it is the only one of the three that is
not an environment artifact, and because tracing it shows the gate working
exactly as designed.

The gate is a **pin**: `tools/ext_ambient_inventory/hook_scope.py:1225`
compares the derived DOOR-3 residue set against
`fixtures/hook_scope/expected.json` (`door_3_residue`, line 197), which is
 pinned to `["intToFloat", "show"]`. The derived set is now
`["f", "intToFloat", "show"]`. The gate's own message states why it is a pin
and not a verdict:

> This set is pinned because it is a PRODUCER gap, not a verdict: it must
> neither grow unnoticed nor be quietly assumed away.

**What the residue means.** DOOR-3 is the classification door for a name
applied inside a hook body that resolves to no declaration, import, or
builtin with producer evidence — `hook_scope.py:883`, reached only after the
declared/imported/local checks at `:853-874` all miss. Such a name cannot be
classified port-mediated or ambient, so the extension is marked
unresolved. The residue is the set of names that block that classification.

**Where `f` comes from.** Running the report target attributes it exactly:

```
DOOR-3 RESIDUE -- applied names no producer at HEAD can classify:
  show        blocks 9 extension(s): ailang_docs, compaction_ai, compaction_structural,
              compose, context_mode, exa_search, herdr, microrag, omnigraph
  intToFloat  blocks 1 extension(s): compose
  f           blocks 1 extension(s): herdr
```

One extension, `herdr`. The source is
`packages/motoko-ext-herdr/types.ail:997`, inside a `tests [...]` block that
pins every `ProcessError` arm:

```ailang
let f = pe_spawn_failed("x");
...
a != b && b != c && c != d && d != e && e != f && f != g && ...
```

The binding is a plain `let`-bound local, and the checker has an
`applied-local` branch (`:876`) that would catch `f(x)` — but here `f`
appears only in an **infix comparison** (`e != f`, `f != g`), not in
application position. So it falls through to `unresolved_callees` and lands
in the residue. The tool is being conservative, and arguably correctly so: it
cannot see that this `f` is a value rather than a callee.

**Timeline.** `git log -S` dates the line to **`51ee9bf7` (2026-08-23),
"test(herdr): pin every ProcessError arm, closing acceptance criterion 5"**.
The fixture was last touched by **`8b82fb26` (2026-08-29), "Review fixes"** —
six days *later* — and that commit did not add `f` to the pin. So the drift
was introduced on 08-23, survived a fixture edit on 08-29, and the gate has
been red since.

**The asymmetry worth noting.** `make ext_hook_scope` (the *reporting*
target) exits **0** and prints the three-name residue, `f` included, as
information. Only `ext_hook_scope_selftest` (the *pinning* target) fails.
Both are in `DST_TARGETS`. So the sweep contains a target that will happily
show you a changed producer gap and a sibling that refuses to pass because of
it — which is a reasonable division of labour, but it means the information
was on screen and unred for at least the life of this drift.

**What a fix looks like** (not applied — this is a pin, and re-pinning is the
producer's call, not mine): either add `"f"` to
`expected.json`'s `door_3_residue`, or teach the checker that a `let`-bound
name appearing only in non-application position is a value rather than an
unresolved callee. The second is more correct and more work; the first is a
one-token edit that also *legitimises* `f` as a permanent producer gap. The
gate's own comment argues the pin exists precisely so this choice is made
deliberately.

### 8. `[new]` A "still running" process that was not

Trivial but costly in practice: polling `pgrep -f "make check_core"` kept
returning yes long after the gate had finished. The match was the **supervisor
`ailang run …` process** (whose command line contains that string via the
session), not the make job. Confirming completion required checking that
`/tmp/cc.log` had stopped growing (stable at 88 lines) and that no `make`
process existed. Any agent-side "wait for the gate" loop can hang forever on
this. Recorded because it wasted several steps.

## Structural observation `[extend]`

All three sessions now agree on the shape of Motoko's failure modes, and that
shape is not "the verifier is wrong" — it is **"a boundary that should have
stopped did not"**:

| Session | Fail-open boundary |
|---|---|
| 001 | DP7 finalization: `Err(_) => Approve` when the verifier cannot run |
| 001 | Scratchpad batch: one unavailable backend voids the whole batch as rc 0 |
| 002 | Fold contracts: annotation says "unencodable", real cause is gate ordering |
| **005** | **Context measurement: a missing catalogue row disables compaction silently** |
| **005** | **Examples: not enumerated by any gate, so a migration rots them invisibly** |
| **005** | **Delegation: three backends down, and no ceiling on gate runtime** |

The unifying property is that **absence is rendered as health**. Missing
verifier → approve. Missing backend → rc 0. Missing context limit → 0%
(healthy). Missing from the gate list → not failing. Each individual
`limit == 0` / `Err(_) => Approve` branch is a defensible local decision; the
defect is that nothing upstream distinguishes *"I measured and it is fine"*
from *"I could not measure"*. ADR-001's fail-closed rule is the right
instrument, and this session's contribution is two more boundaries to point it
at — both of them cases where the fail-open is invisible in the telemetry
rather than visible in a test result.

## Verdict

Consistent with NOTE-001's 9/10 / 7/10 / 6/10 and NOTE-002's agreement. The
scores hold for the same reason they held last time: the verification
machinery, when it runs and when it is pointed at something, is honest — three
sessions, three independent confirmations of the planted-bug control. What
this session moves is the *coverage* question: findings 1 and 2 were found
only because the session had no task and went looking, and neither is
reachable by a gate that exists today. Finding 5 is the mirror image and worth
separating from them: it looked like a defect, was traced, and turned out to
be correct behaviour rendered illegibly. Both classes matter — the first two
are the case for more gates, the fifth is the case for clearer surfaces.

Finding 6 is the one that moves a score. It is the first finding in three
sessions where the verification surface is *wrong in the direction of
claiming a bug that does not exist* — every prior finding was a gate too
permissive or a subsystem silently off. That is the opposite failure, and it
is the one that costs an agent the most: "verifier found a counterexample"
sends you editing correct code. It belongs on the same list as ADR-001's
work, because ADR-001 is about boundaries failing in the unsafe direction and
this is a boundary failing in the *accusatory* direction.

The session also ran the full sweep for the first time in this note series:
**`make dst` is red — rc 2, three named targets, 789s** (finding 7). That
does not move the concept score, but it changes what "the gates are green"
can be taken to mean. Sessions 001 and 002 both reported `check_core` and
`verify_core` green and left `dst` unrun; this session ran it, and the
project's most comprehensive gate does not currently pass in this container.
Traced, the three split cleanly: two (`smoke_parity`, `smoke_driver`) are one
environment artifact — a `/tmp` workdir outside `AILANG_FS_SANDBOX`, proven
rc 0 with the variable unset — and the third (`ext_hook_scope_selftest`) is a
real, dated code drift: a `tests [...]` block added `let f = ...` on
2026-08-23 (`51ee9bf7`) and the pin it invalidated was edited six days later
(`8b82fb26`) without absorbing it. One real defect, one environmental trap,
and a gate that caught the real one.

One qualifying note, because it cuts against this note's own thesis: the
`ext_hook_scope_selftest` failure is a gate that caught a pinned set growing
by one element and **failed loudly**. Alongside the sweep summary mechanism
that names and classifies its own red targets, that is enforcement working as
ADR-001 intends. The picture after three sessions is therefore not "the
boundaries are uniformly too permissive" but "the boundaries are
inconsistent about which direction they err in — some fail open, one accuses
correct code, and at least one fails correctly." Consistency of direction is
the thing ADR-001 should be extended to demand.

## Suggested work items (for PLAN-001 / PLAN-002, not yet filed)

Ordered by (consequence × invisibility) / cost:

1. **Make an unresolvable context limit observable.** One line in
   `MotokoRuntimeStatus` — a `context_limit_source` field
   (`catalog` / `profile_override` / `unknown`) — so "0% because healthy" and
   "0% because unmeasured" are distinguishable at the surface where the
   operator looks. Does not require deciding the right limit for any model.
   Cheap, and it converts finding 1 from invisible to visible.
2. **Gate `examples/`.** Add `examples/*.ail` to a `make` target that runs
   `ailang test` on each, and fix the two broken files (declare `Net`, `Rand`
   on `a2a_hooks_register_capabilities`, or whatever the ABI-6.0-correct
   signature is). Pins finding 2 and closes the class NOTE-002 predicted.
3. **Audit the default profile for advertised-but-dead tools.** ExaSearch is
   in `extensions.order` with its bridge package absent. Either install
   `motoko_ext_mcp` or drop the extension from profiles that cannot serve it —
   an advertised tool that fails at call time is the failure mode
   `verify_herdr_gate` already exists to prevent, generalised.
4. **`set -o pipefail` sweep on gate recipes** (finding 4).
5. **Raise or delegate around the 35s tool ceiling**, or document the
   `setsid` workaround (finding 3).
6. **Disambiguate the two accumulators in the status surface** (finding 5).
   `usage.input_tokens` (per-loop) and `provider_calls_completed`
   (cross-loop) sit in one JSON block and reset differently on re-entry. A
   `current_step` / `steps_executed_so_far` pair already shows the same
   split. Cosmetic, but it is currently indistinguishable from a
   counting bug.
7. **Reconcile the recursion verdict across surfaces** (finding 6). One
   condition, three names: `blocked` (`verify_core`), `ERROR`
   (`tool_runtime.ail:57`), "verifier found a counterexample" (scratchpad
   `verify: required`). The last one is the dangerous one — it asserts a
   logic error where there is none, and it rejects a cell that
   `verify_core` would only have reported. At minimum the scratchpad's
   message should distinguish "cannot encode" from "disproved".
8. **Move the `/tmp` workdirs inside the sandbox** (finding 7) —
   `smoke_phase_a_tool_parity.ail:58` and `smoke_parity`'s
   `/tmp/phase_a_parity_{a,b}`; 7 of 32 smoke scripts reference `/tmp/`.
   Environment-dependent (rc 0 with `AILANG_FS_SANDBOX` unset), so this is
   about making the shipped devcontainer green, not about broken code.
9. **Re-pin or fix the DOOR-3 residue** (finding 7). `f` from
   `motoko-ext-herdr/types.ail:997` (added `51ee9bf7`, 2026-08-23) is not in
   `expected.json`'s `door_3_residue`, last edited `8b82fb26` six days
   later. Either add `"f"` to the pin, or teach the checker that a
   `let`-bound name used only in non-application position is a value, not
   an unresolved callee. **This is the one real code-level red in the
   sweep.**
