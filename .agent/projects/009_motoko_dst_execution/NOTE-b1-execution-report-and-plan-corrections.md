# WI-B1 execution report — repin v0.26.0 → v0.33.0

Sixteenth calibration run, and the first of Milestone B. Written against HEAD `f7d7c19`, branch
`arniwesth/mot-55-execute-wi-b1`.

## Window

**33m25s** git wall-clock: `2026-08-04T14:06:38Z` → `2026-08-04T14:40:03Z`. About a third of that
was building two toolchains (v0.33.0 to install, v0.26.0 to get an honest baseline).

## What landed

| Definition-of-done item | State |
|---|---|
| Pin bumped in all three places | ✅ `ailang.toml:6`, `install-prerequisites.sh:39-40`, `ailang.lock` regenerated |
| `make CI=1 sync_packages` passes | ✅ exit 0 — **and proven non-vacuous** (see below) |
| `walk_agents` `FS` | ✅ `src/core/agents_md.ail` — plus its caller `find_agents_files` |
| omnigraph `register_with_config` `Process` | ✅ `+{Process, Rand}` — `Rand` is surplus, see findings |
| Every reachable effect-row repair, narrowest row | ✅ **zero effect-row failures remain** |
| ABI changes exactly M2's three, or surplus reported | ⚠️ **one, not three** — reported below |
| `make check_core` exit 0 | ❌ **BLOCKED ON WI-B3** — reported below |

**I proved the drift guard fires, not just that it passes.** Set `AILANG_REF=v0.32.0` against a
`v0.33.0` floor: exit 2 with the mismatch message. A guard that only ever passes is not evidence.

## The measurement

**M2's 381 edits across 71 files was `v0.26.0 → v0.31.0`. This is `v0.26.0 → v0.33.0`, measured
fresh.** Instrument: whole-tree `ailang check` over all 235 `.ail` files under
`src packages scripts tools`, with `AILANG_RELAX_MODULES=1` for `packages/` (their module decls are
`sunholo/…`, their paths are `packages/…`).

**A baseline was required and two attempts at it were wrong.** Milestone A's gates were green, so
"newly red" needs a real v0.26.0 comparison, not an assumption:

- *Attempt 1 — worktree at HEAD.* Contaminated: the worktree has no `.packages/`, which is generated.
- *Attempt 2 — v0.26.0 binary in the real repo.* Contaminated worse, and this one is a trap worth
  naming: **the stdlib is global.** `$HOME/.local/share/ailang/std` was already v0.33.0, so this
  measured a v0.26.0 *compiler* against a v0.33.0 *stdlib* — a chimera reporting 144 failures.
  `AILANG_STDLIB_PATH` is the fix.
- *Attempt 3 — matched compiler and stdlib.* **v0.26.0: 213 pass / 22 fail.**

| | files |
|---|---|
| Total `.ail` in scope | 235 |
| Pre-existing red on v0.26.0 (examples, code-graph fixtures, `unrunnable`) | 22 |
| **Newly red from the pin** | **98** |
| Fixed by the pin | 0 |

**Of the 98, split by first error: 27 effect-row (B1), 71 `images` (B3).**

### The number, and the caveat that matters more than the number

**66 effect-row lines changed across 46 source files.** Composition: 46 `ToolHandleDecision += Rand`
cascade sites (one of which is the ABI contract row) and 20 compiler-named function rows.

**That is not comparable to M2's 381, and nobody should treat it as a refutation.** `ailang check`
reports the **first** error per module and stops. A single sweep therefore surfaces a *frontier*, not
a total — the first sweep showed only 17 distinct error sites across 235 files. The real count is a
fixpoint reached by repairing and re-checking, and **this one terminated early because it ran into
B3**, not because it finished. The honest statement is:

> **66 edits / 46 files is the complete count of effect-row repairs reachable on this pin. The
> remainder is behind the `Message` migration and is unmeasured, because unmeasurable.**

M2's 381 remains the floor for the *wave*. Nothing here contradicts it.

## The headline finding: B1's own gate is unreachable without B3

**`make check_core` cannot go green under B1 alone, and it fails earlier than expected.** It does not
reach its type-check loop at all — it dies in its `verify_extensions` prerequisite, where **all 7
extensions fail on one identical line**: `packages/motoko-ext-ai-compat/ai_compat.ail:196`, a
`[Message]` literal missing the new `images` field.

Behind that: **25 of the 51 files in `check_core`'s scope** fail on `images`, along with 91 of the
105 tree-wide failures. Seven `images` sites are currently visible; that is again a frontier, and
M1 measured the migration at 69 additive sites with 7 needing judgement.

**I did not absorb B3.** The handoff scopes it out, it has its own measured plan with a
tooling-first rider, and its 7 judgement sites are exactly where a silently-wrong edit hides. I also
abandoned an attempt to *measure past* B3 in a throwaway worktree: the seam direction differs per
site (some sites need `images` added, others need it dropped), so a crude instrument would have
produced a **wrong** number, which is worse than a scoped one.

**Correction owed to the plan:** WI-B1's definition of done should not carry `make check_core` exit 0.
The plan's own prose is right — B1 is "preparation-only, not independently green" — and the DoD
contradicts it. Suggest the B1 gate become *"zero effect-row failures tree-wide"*, which is
measurable, which is met, and which does not depend on B3.

## The ABI: one change, not three — and the reason is a sizing fact for B2

M2 predicted three: `ExtPorts.ai_step += Trace`, and four `ExtensionHooks` rows `+= Rand, Trace`.

**Measured: exactly one.** `ExtensionHooks.on_tool_handle` gains `Rand`. Nothing else was demanded:

```
-  on_tool_handle: (…) -> ToolHandleDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
+  on_tool_handle: (…) -> ToolHandleDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Rand},
```

**This is S8's shape and I am flagging it as such rather than claiming M2 was wrong.** The other
three hooks and `ExtPorts.ai_step` sit in modules that never reached effect checking, because the
`images` type error precedes it. **Absent reads identically to unchanged.** The correct reading is
*"one demanded so far; the rest is unmeasured until B3 lands"* — not *"M2 over-predicted"*.

**D5's coverable surface survived intact.** The three rowless slots (`on_describe_tools`,
`on_build_system_prompt`, `on_tool_policy`) are byte-identical to HEAD, as is `on_budget_plan` at
`! {Env, FS}` and `ExtPorts.ai_step`. Verified by diff, not by intent.

**Two mechanisms B2 should budget for:**

1. **Rows are closed.** `incompatible closed rows: r1 has extra labels [Rand]`. Widening an ABI hook
   field does not permit narrower implementations — it *forces* every one of them to widen in
   lockstep. That is why one field cost 46 sites. Structurally, the four hook result types carry
   **191 rowed implementation sites** (`ToolHandleDecision` 49, `PreStepDecision` 59,
   `ResponseInterceptDecision` 40, `FinalizeDecision` 43). If all four gain both effects, that is the
   cascade's exact lower bound, and it is how 381 becomes plausible.
2. **The widening propagates *upward*.** Constructing a record whose field holds an effect-declaring
   closure makes the *constructing* function perform that effect — so every `make_hooks` and
   `register_with_config` above a widened hook widens too. **Probed and confirmed NOT a v0.33.0
   regression**: v0.26.0 does the same, and it is the already-filed `fb_74f53de3ae65854c`. It is a
   sizing fact, not a new defect.

## Sites where two answers type-checked and one was silently wrong: 3

**Running total: 37 across sixteen runs. Determinism has still caught none.**

All three were the same defect, mine, and the handoff predicted its exact shape: my cascade tool
widened by **result type**, which over-approximates. Three helper functions carrying deliberately
narrow rows — `context_mode.ail:163` (`{Process, SharedMem}`), `omnigraph.ail:79` and `:113`
(`{Process}`) — were not hook implementations at all, merely functions returning the same type. They
gained `Rand`, compiled clean, and passed every check.

**What caught them: a mutation loop.** Remove the added `Rand`; a site that stays green was never
forced. **What did not catch them: the compiler, the sweep, or the 130 green files.** They are
invisible to all three by construction.

### The mutation loop was itself wrong the first time, and this is the more useful lesson

**A cached result survives a source edit and reports the pre-edit answer.** Dropping `Rand` from the
ABI row read **GREEN on a warm cache and RED on a cold one** — so my first mutation run's verdicts
were partly cache artifacts, and it nearly talked me into reverting a correct, load-bearing ABI
change. Every check now clears `.ailang/cache` first.

**This is the project's third stale-cache phantom** (a stdlib change, a compiler version change, and
now a mutation loop). The first two were about *believing a diagnostic*; this one is new — **it
corrupts a detector**, so the phantom is not merely noise, it inverts a verdict. Recommend the
standing rule be widened from "clear caches before believing a type error after a toolchain change"
to **"clear caches before believing any check whose input you just mutated."**

**One structural blind spot, named rather than fixed.** The loop is per-file, so it cannot see a
mutation whose breakage lands in a *different* file: removing `Rand` from `motoko-ext-abi/types.ail`
leaves `types.ail` green because it declares no implementations. It reads OVER-WIDE and is
load-bearing — proven separately, cache-cold, via `a2a.ail`. That is S8's unwalked-branch complement
arriving inside a detector.

**Unverified, and it must not read as verified: 20 files** carrying cascade sites could not be
mutation-tested because they are behind the `images` wall. Among them exactly one has a *narrow* row
(`compose.ail:756`, `{IO, AI, Process, FS, Env, Clock, Rand}`) and is therefore the one remaining
over-widening candidate. The other 41 full-row sites are forced structurally by closed-row assignment
to the ABI field. **B4 should re-run the mutation loop once B3 lands.**

## Filed AILANG defects on v0.33.0: two fixed, one untestable

Each retested with a probe that was **first proven to reproduce on a matched v0.26.0 compiler and
stdlib** — otherwise "fixed" is unfounded.

| Ticket | Verdict |
|---|---|
| `fb_e44ba922db1c42be` — call in field-value position of a record update is not a dependency | ✅ **FIXED.** v0.26.0: `undefined variable: bump`. v0.33.0: clean. |
| `fb_b39697480a4e8bbc` — out-of-scope constructor name in a pattern binds as a fresh variable | ✅ **FIXED behaviourally, diagnostic still absent.** v0.26.0: `trap(Full(42)) = -1` (swallowed). v0.33.0: `= 42`. The name no longer binds irrefutably; an unmatched scrutinee is now a loud runtime `no pattern matched`. **`ailang check` still reports nothing** — the silent-wrong-answer mode is gone, the check-time diagnostic is not. |
| `fb_2ad074d754cd2c25` — `ailang test` cluster harness fails ~6/10 in large modules | ⬜ **UNTESTABLE on this pin.** Its probe module `src/core/dst_invariants.ail` is behind the `images` wall: 10/10 runs fail, but on `images`, not `record has no field`. Weak counter-signal only: `dst_generator.ail` (1519 lines, 21 test blocks) is 0/10 failures. **Retest after B3.** |

**Both fixed defects have workarounds live in the tree and they can now be removed** — but that is a
separate change, not B1's, and removing them should be a deliberate item since each workaround
carries a comment pointing at its issue file. Note the second is only *half* clear: code relying on
the compiler to reject an out-of-scope constructor still gets no diagnostic.

## Findings and surplus, reported rather than absorbed

**Surplus beyond M2's two named latent under-declarations.** M2 named `walk_agents` `FS` and
omnigraph `register_with_config` `Process`. Measured, the compiler also demanded, each at exactly the
row it named:

- `agents_md.find_agents_files` `+{FS}` (the caller — trivially implied)
- omnigraph `register_with_config` also `+{Rand}`, beyond M2's `Process`
- context-mode `register_with_config` `+{Process, SharedMem}`
- a2a `make_hooks` / `register_with_config` `+{Net, Rand}`
- ailang-docs, exa-search `make_hooks` / `register_with_config` `+{Process}`
- scratchpad `make_hooks` / `register_with_config` `+{Rand}`
- five `motoko_ext_conformance/harness.ail` scenarios, each `+{9 effects}`
- `compose/author_tools.mk_ok` `+{Clock}`; `compaction_policy_dst.main` `+{9 effects + Trace}`

Most of these are the upward propagation described above, not independent under-declarations.

**Stale doc comment.** `src/core/agents_md.ail`'s header still says "Pure function — no side effects".
It was already false at HEAD (`walk_agents` always called `fileExists`); v0.33.0 merely made the row
say so. Left alone deliberately — it is not an effect-row repair and I would rather flag it than
quietly widen this item's diff.

**Package `ailang` floors were left alone.** Three packages declare `ailang = ">=0.26.0"` and eleven
others declare older floors. All are satisfied by 0.33.0, none is read by the drift guard, and
bumping them is package metadata belonging with **B2's** lockstep re-release.

## `make dst`

**Not run, as instructed, and it would be red.** Two independent reasons, both expected: 91 files
still fail on `images`, and every DST script still carries `driver_only_manifest("HEAD", "ailang
0.26.0", …)`. **Re-issuing that manifest is WI-B4's**, so those strings were deliberately not touched.

## State handed to B2 / B3

- Tree: **130 pass / 105 fail** (91 `images`, 14 pre-existing). v0.26.0 baseline was 213 / 22.
- **Zero effect-row failures reachable.** The next honest signal is B3's first `images` repair.
- 48 files modified: 46 source + `ailang.toml` + `ailang.lock`. Nothing committed.
- Instruments left in the scratchpad and worth keeping: the sweep, the compiler-driven `effectfix.py`
  (module→file resolution, refuses the ABI file, refuses `.packages/` mirrors), the result-type
  cascade `hookrow.py`, and the cache-cold `mutate.sh`.
