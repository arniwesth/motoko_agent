# 2026-08-04 WI-B1: repin the toolchain v0.26.0 → v0.33.0

## Context

Branch: `arniwesth/mot-55-execute-wi-b1`

Session span: `f7d7c19` → `c013f69`, **3 commits**. Input was `HANDOFF-execute-b1-repin-toolchain.md`,
executed cold against HEAD. Sixteenth code session of project 009, and **the first of Milestone B** —
the first work in the project not gated on anything external.

Execution window **33m25s** (`14:06:38Z` → `14:40:03Z`). About a third of that was building two
toolchains: v0.33.0 to install, and v0.26.0 to get a baseline honest enough to subtract.

| | |
|---|---|
| Pin bumped in all three places, drift guard green | **done** — and the guard proven to *fire*, not just pass |
| Every reachable effect-row repair, at the narrowest row | **done** — zero effect-row failures remain |
| The two named latent under-declarations | **done** — `walk_agents` `FS`, omnigraph `register_with_config` `Process` |
| The three filed AILANG defects, retested | **done** — two fixed, one untestable |
| `make check_core` exit 0 | **not met — unreachable in B1's scope**, and the reason became the session's headline |
| WI-B3's `Message` migration | **not taken** — out of scope, and deliberately not absorbed |

## What landed

| Commit | Item |
|---|---|
| `c013f69` | the repin itself — 48 files, 89 insertions, 89 deletions |
| `3bd754d` | the plan corrections my report argued for: **S9 promoted**, and B1's contradictory gate rewritten |
| `aef2f5e` | `HANDOFF-execute-b3-message-migration.md` — B3 taken before B2, on this session's evidence |

`c013f69` is **66 effect-row lines across 46 source files**, plus `ailang.toml` and `ailang.lock`:
23 files under `packages/`, 19 under `scripts/`, 4 under `src/`. One of the 66 is the ABI contract
row; 46 are the `ToolHandleDecision += Rand` cascade; 20 are compiler-named function rows.

**`make dst` was not run, as instructed, and would be red** — two expected reasons, neither a break:
91 files still fail on `images`, and every DST script still carries
`driver_only_manifest("HEAD", "ailang 0.26.0", …)`, whose re-issue is **WI-B4's**.

## The order the work took

1. **Grounding**, ~8 minutes: the drift-check diff (clean), the briefing's two live sections, S1/S8,
   WI-B1→B4, and the ABI's hook rows read before touching anything.
2. **Install and pin**, with the v0.33.0 build backgrounded while the pins were edited — then the
   guard's *negative* test before its positive one.
3. **Baseline**, which took three attempts and was the most valuable detour of the session.
4. **Repair loop**, compiler-driven, tooling first.
5. **Mutation loop**, which found three defects of my own — and was itself wrong the first time.
6. **Defect probes**, each proven to reproduce on v0.26.0 before any "fixed" was claimed.

## The baseline took three attempts, and the third trap is worth keeping

Milestone A closed green, so "newly red" needed a real comparison rather than an assumption.

- **Worktree at HEAD** — contaminated: worktrees have no `.packages/`, which is generated.
- **v0.26.0 binary in the real repo** — contaminated worse, and this is the one to remember:
  **the stdlib is global.** `$HOME/.local/share/ailang/std` was already v0.33.0, so this measured a
  v0.26.0 *compiler* against a v0.33.0 *stdlib* — a chimera reporting 144 failures. `AILANG_STDLIB_PATH`
  is the fix.
- **Matched compiler and stdlib** — **v0.26.0: 213 pass / 22 fail** across 235 `.ail` files.

Against that: **98 files newly red from the pin, 0 fixed**, splitting **27 effect-row / 71 `images`**.
Final state after the session: **130 pass / 105 fail** (91 `images`, 14 pre-existing).

## The number, and why it does not refute M2

**66 edits across 46 files**, against M2's floor of 381 across 71. It is not a refutation and the
report says so twice.

`ailang check` reports the **first** error per module and stops, so a sweep surfaces a *frontier*,
not a total — the very first sweep showed only 17 distinct error sites across all 235 files. The real
count is a fixpoint reached by repairing and re-checking, and **this one terminated early because it
ran into B3**, not because it finished. The defensible claim is narrow: *66/46 is the complete count
of effect-row repairs **reachable** on this pin.* The rest is unmeasured because unmeasurable.

I also **abandoned** an attempt to measure past B3 in a throwaway worktree. The seam direction differs
per site — some need `images` added, others need it dropped — so a crude instrument would have
produced a **wrong** number, which is worse than a scoped one.

## Headline: B1's own gate was unreachable, and the plan was corrected

`make check_core` never reaches its type-check loop. It dies in its `verify_extensions` prerequisite,
where **all seven extensions fail on one identical line** — `motoko-ext-ai-compat/ai_compat.ail:196`,
a `[Message]` literal missing the new `images` field. Behind it: 25 of the 51 files in `check_core`'s
scope, and 91 of 105 tree-wide failures.

The plan's prose already said B1 is "preparation-only, not independently green"; its *definition of
done* contradicted that. **Both corrections were accepted into the plan** (`3bd754d`): B1's gate is
now **"zero effect-row failures tree-wide"**, which is measurable and met.

## The ABI: one change, not three — reported as unmeasured, not as M2 being wrong

M2 predicted three (`ExtPorts.ai_step += Trace`; four `ExtensionHooks` rows `+= Rand, Trace`).
Measured: **exactly one** — `ExtensionHooks.on_tool_handle` gains `Rand`.

**Flagged as S8's shape rather than banked as a finding.** The other three hooks and `ExtPorts.ai_step`
sit in modules that never reached effect checking, because the `images` type error precedes it.
*Absent reads identically to unchanged.*

**D5's coverable surface survived** — the three rowless slots, `on_budget_plan` and `ExtPorts.ai_step`
are byte-identical to HEAD, verified by diff rather than by intent.

Two mechanisms handed to B2:

1. **Rows are closed.** Widening an ABI hook field does not permit narrower implementations, it
   *forces* every one to widen. One field cost 46 sites; the four hook result types carry **191 rowed
   implementation sites** in total, which is how 381 becomes plausible.
2. **The widening propagates upward** through record-held closures, so every `make_hooks` and
   `register_with_config` above a widened hook widens too. Probed and confirmed **not** a v0.33.0
   regression — v0.26.0 does the same, and it is the already-filed `fb_74f53de3ae65854c`.

## Sites where two answers type-checked and one was silently wrong: 3

**Running total 37 across sixteen sessions. Determinism has still caught none.**

All three were mine, and the handoff predicted the exact shape: my cascade tool widened by **result
type**, which over-approximates. Three narrow-rowed *helpers* — `context_mode.ail:163`,
`omnigraph.ail:79` and `:113` — were not hook implementations at all, gained `Rand`, and compiled
clean. Caught by a mutation loop; invisible to the compiler, the sweep, and 130 green files.

### The mutation loop was wrong first time, and that became S9

Dropping `Rand` from the ABI row read **GREEN on a warm cache and RED on a cold one**. The first run's
verdicts were partly cache artifacts, and it nearly argued for reverting a correct, load-bearing ABI
change.

This is the project's **third stale-cache phantom and the first of a different species**: the earlier
two corrupted a *diagnostic*, this one corrupts a *detector* — noise versus an inverted verdict, with
C5 mutation testing now required by most remaining items. Promoted to **S9**: *clear the cache before
believing any check whose input you just mutated.*

**One blind spot named rather than fixed:** the loop is per-file, so it cannot see a mutation whose
breakage lands elsewhere. Removing `Rand` from `motoko-ext-abi/types.ail` leaves that file green
because it declares no implementations — it reads OVER-WIDE and is load-bearing, proven separately
and cache-cold via `a2a.ail`. That is S8's unwalked-branch complement arriving *inside a detector*.

**Unverified and recorded as such: 20 files** carrying cascade sites could not be mutation-tested
behind the `images` wall. Exactly one has a narrow row — `compose.ail:756` — and is the remaining
over-widening candidate.

## Filed AILANG defects on v0.33.0: two fixed, one untestable

Each probe was **first proven to reproduce on a matched v0.26.0 compiler and stdlib**; otherwise
"fixed" is unfounded.

| Ticket | Verdict |
|---|---|
| `fb_e44ba922db1c42be` — call in a record-update field-value position is not a dependency | **FIXED** (`undefined variable: bump` → clean) |
| `fb_b39697480a4e8bbc` — out-of-scope constructor binds as a fresh variable | **FIXED behaviourally, diagnostic still absent.** `trap(Full(42))`: `-1` → `42`. The silent-wrong-answer mode is gone, replaced by a loud runtime `no pattern matched`; **`ailang check` still reports nothing** |
| `fb_2ad074d754cd2c25` — `ailang test` cluster harness, ~6/10 in large modules | **UNTESTABLE on this pin** — its probe module is behind the `images` wall (10/10 fail, but on `images`). Weak counter-signal: `dst_generator.ail` is 0/10 |

Both fixed defects have **workarounds still live in the tree**, now dead code — a deliberate separate
change, not B1's.

## Instruments left behind

In the session scratchpad, and worth keeping for B2/B3: the whole-tree sweep; `effectfix.py`
(compiler-driven, resolves module→file so a diagnostic is repaired where it *lives*, refuses the ABI
contract file, refuses `.packages/` mirrors); `hookrow.py` (result-type cascade); and the cache-cold
`mutate.sh`.

## What the next session inherits

- **Zero effect-row failures reachable.** The next honest signal is B3's first `images` repair.
- `HANDOFF-execute-b3-message-migration.md` — **B3 taken before B2**, on this session's evidence that
  B3 is what blocks the tree.
- Three open follow-ups, all blocked on B3: `check_core`'s gate, re-running the mutation loop over
  the 20 unverified files, and retesting `fb_2ad074d754cd2c25` plus removing the two dead workarounds.
