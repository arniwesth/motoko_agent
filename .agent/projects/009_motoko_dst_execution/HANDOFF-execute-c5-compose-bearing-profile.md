# Handoff: execute WI-C5 — the `compose`-bearing profile, and the blocker its own text predates

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-C3 landed 2026-08-05** (~72 min): `dst_execution.execution_of` bridges a real run to an
`ExecutionUnderTest`, `make stream_parity` evaluates all sixteen D7 families over a real run, and
`d64_gap_register` went 14 → 13 with `StreamDelta` **appended** rather than reclassified. Verified at
review: `make dst` exit 2 cache-cold, **770 pass rows / 7 fails**, and the only red targets are
`test_coverage` and `test_coverage_selftest` — the same two since B4. **Confirm tree state with
`git status`**, not with this paragraph.

**Read first:** `NOTE-c3-execution-report-and-plan-corrections.md`, then the plan's
`## Standing rules` — **S16 and S17 are new, and S16 binds this item's central deliverable by name.**

## Mission

**The second profile: `compose`-bearing.** Route compose's clock reads through `ExtPorts.clock_now`,
make the effectful hooks world-mediated, land `routing_violation_at`'s production call site, and claim
the routed set — **12 sites post-table, 13 as the fail-closed figure** when the attribution table is
absent or invalid.

**This is also the item B4 named as deciding whether any extension can ever be covered**, and C4 —
the name gate — cannot run before it. Milestone A's boundary says it delivered *"everything the name
gate needs except streaming parity and extension-model coverage"*; C3 supplied the first, and the
second is yours.

## The finding that resizes the item, and C5's own text predates it

**The plan says compose is un-installable "until B2's world-token/coverage widening lands." B2
landed. Compose is still un-installable, for a different reason found one item later.**

B4 established, and I re-verified at HEAD: `packages/motoko-ext-abi/types.ail:298` declares

```ailang
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},
```

The row is **closed**, the slot is **unconditionally dispatched**, and `Env`/`FS` are not
world-mediated — so under D5 the hook is coverable under neither criterion, and an extension with an
unconditionally-dispatched hook excluded **may not be installed**. **Compose binds that slot**
(`compose.ail:829`, `on_budget_plan: budget_hook`). So does every other extension in the tree, which
is why `driver_only`'s empty install list is *forced* rather than chosen.

**C5 as scoped cannot deliver a compose-bearing profile without also moving that ABI row.** Decide
that explicitly and early — it is a second ABI major on top of the one Milestone B already owes, and
it is not a detail to absorb mid-item. If you conclude it is out of scope, then **say plainly that the
item delivers the routing and the detector but not the install**, because C4 reads this answer and a
profile that cannot install compose is not a compose-bearing profile.

## The rule you will break by accident

**You cannot narrow a declared hook row to match what it performs. Measured, not argued.**

Compose's `intercept` closure declares **nine** effects at `compose.ail:820` while the function it
wraps declares four at `:761`, and its body is a constant record. That looks exactly like an
over-declaration waiting to be tightened, and tightening it is the obvious route to coverage under
D5's declared-row rule. **I narrowed it 9 → 4 and the compiler rejected it:**

```
failed to unify record field 'on_response_intercept': failed to unify effect rows:
incompatible closed rows: r1 has extra labels [], r2 has extra labels [AI Env Net SharedMem Stream]
```

**So B2a's closed-row argument HOLDS for record fields, and B4's refutation is correctly scoped to
function-typed PARAMETERS** — the plan says so at two places and this measurement confirms rather than
corrects it. The consequence for you: **the ABI row is a hard constraint, not a convention.** The only
two routes to coverage are changing the ABI row, or building the detector and having D5 accept
performed rows over declared ones. **Narrowing at the binding site is not a third route; it does not
compile.**

**And the asymmetry that makes this dangerous in the other direction:** a wider row on a function-typed
*parameter* type-checks silently and propagates to every caller. So declared rows are simultaneously
*rigid* where you want to tighten them and *unreliable* as evidence of what a hook performs. That is
the gap the detector exists to close, and it is why D5's declared-row rule is a stopgap rather than a
design.

## The declared-versus-performed detector, and S16 binds it

This is the item's durable output. **S16 applies to it directly and by name:** a check whose two sides
share a producer tests threading, not the property. C3 measured that the hard way — an in-process
parity gate stayed green through the exact defect it existed to find, because both sides derived from
one channel.

**So before writing the detector, name its two producers.** "Declared" is the ABI row — static, cheap,
already rigid. "Performed" must come from somewhere the hook does not control: the world protocol's
own record of what was requested, the interaction log, or an out-of-process observation as C3's wire
gate did. **If "performed" is derived from the same declaration, the detector reports agreement by
construction and every extension passes.** That failure would be green, and it would be the fourth
instrument in this project to certify nothing while exiting 0.

## Grounding, verified at HEAD

| Anchor | Value |
|---|---|
| `ExtPorts.clock_now` | `() -> int ! {Clock}` (`types.ail:147`) — **zero call sites**, confirmed; the 5 live `.clock_now(` sites are all **`Ports`**, routed by A12 |
| Compose's clock reads | **8**, matching the plan: `compose.ail` 362, 503, 597, 651, 681, 767; `author_tools.ail:101`; `authoring/dispatcher.ail:217` |
| `routing_violation_at` | `dst_profile.ail:1096`; its **only** three call sites (`:1518`, `:1538`, `:1554`) are self-tests. The production consumer is the hook dispatch fold in `ext/runtime.ail` |
| `proc_exec`, `env_get` | still classifier-2 members, left deliberately by B2b so C5 keeps a real target (`types.ail:142-144`) |
| `on_response_intercept` | bound at `compose.ail:820` with nine effects; body at `:761-790` declares four |

**`ExtPorts.clock_now` is `() -> int` and therefore cannot thread state at all** — it must be widened
before compose's reads can route into it. That is a third `ExtPorts` widening, and it is the first
exercise of a seam with no callers, so **budget for it not surviving contact unchanged.**

## Definition of done

**The install question answered explicitly** — compose installable, or not, with the `on_budget_plan`
ABI row named as the reason either way. **C4 reads this.**

**The eight clock reads routed**, `ExtPorts.clock_now` widened, and its first call sites landed.

**`routing_violation_at` called from production**, with the in-runner probe as acceptance: reaching an
excluded hook returns a typed `HarnessFailure` **with partial evidence**. Per the plan this is part of
this item's acceptance rather than assumed from load-time validation — **an exclusion checked only at
load time is an exclusion nothing enforces at dispatch.**

**The routed set claimed at 12 post-table, with 13 as the fail-closed figure** when the table is
absent or invalid. Both numbers, not one.

**The detector's two producers named at the site**, per S16 — and if you cannot find a second
producer, **say the mitigation is weaker than a check** rather than shipping something that reports
agreement by construction.

**Per S13 — sweep the whole tree cache-cold with `AILANG_RELAX_MODULES=1`**, and confirm the failing
set member-for-member rather than the count. Without the flag the sweep reads 146/93 against 222/17;
**and note the mechanism, because it bit three items silently — a warm cache masks `MOD010` entirely**,
so the flag's necessity appears only under the cache-cold discipline S9 requires.

**Per S17 — the mutation loop saves and restores by `cp`, never `git checkout`.** C3 lost its whole
implementation to a path-scoped checkout and recovered only from a backup taken seconds earlier.

**Per the anchor rule — finish every source edit, including comments, BEFORE running the cascade.**
C3 paid it twice in one item because three lines of prose landed after the first payment, and the
second was found by `make dst` rather than by remembering. Two consumers no checklist names: the
`predicate-anchors` script itself, and `attribution_table_dst`'s `omitted_site()` fixture.

## Out of scope

- **WI-C4, the name gate.** **No target adopts the "DST"/"simulation" name in this item**, whatever
  the coverage answer turns out to be. D10 gates the name on the full acceptance table and C4 runs it.
- **Wiring the seeded runners through `execution_of`.** Fifteen D7 families currently run on a real
  run only because they ride along with parity in one script, on one profile, with two adapters. Its
  red surface is unknown; the one measurement is that the scripted adapter already trips
  `clock-balance`.
- **The extension bridge's emission channel.** `ext_ai_step` still drops `exchange.emissions`; closing
  it needs `ExtPorts.ai_step` widened to carry a chunk log the ABI has no type for.
- The `motoko-ext-abi` major and lockstep re-release, the `ailang iface` MOD010 filing, the 7
  `TC_ARITY_001` scripts, the two v0.33.0-fixed workarounds. **If this item moves an ABI row, the owed
  major stops being deferrable** — say so rather than adding a fourth changed row to the backlog.

## Stop and report rather than deciding inline

- **If making compose installable requires changing `on_budget_plan`'s ABI row**, that is a
  conformance and ABI-major decision with a profile version bump behind it. Report the coverage delta
  before re-issuing anything.
- **If the detector cannot find a second producer for "performed"**, stop and report it as a D5-level
  finding. D5 names this detector and states it is unavailable; establishing *why* it is unavailable is
  worth more than a detector that agrees with itself.
- **If widening `ExtPorts.clock_now` forces changes to the three rowless slots**
  (`on_describe_tools`, `on_build_system_prompt`, `on_tool_policy`), **stop.** They are D5's entire
  coverable surface today, four consecutive items have left them byte-identical, and
  `make profile_coverage` passes so a regression is visible.

## Report back

Twenty-third calibration run.

- **The git wall-clock window.**
- **The install answer**, with the ABI row named — this is the item's durable output and C4's input.
- **The detector's two producers**, or the reasoned statement that there is only one.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **48 across
  twenty-two runs; determinism has caught none** — and note that two of C3's three were visible only
  to instruments C3 itself built, which is the argument for building this item's detector before its
  routing rather than after.
- **Whether `driver_only` still covers nothing provably.** If this item does not change that sentence,
  say so plainly — it is the one C4 most needs, and a green `make dst` will not contain it.
