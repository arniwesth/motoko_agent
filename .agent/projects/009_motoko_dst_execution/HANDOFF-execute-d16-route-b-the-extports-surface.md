# Handoff: WI-D16 — Route B, part 1: the `ExtPorts` effect surface

Audience: a fresh session grounded against HEAD. **This is the build.** Route B has been named and
deferred in nine consecutive reports; this item starts it.

**Read first:** `NOTE-d15-registration-versus-hooks.md` §8 (Route B's re-derived cost), then B2b's
report for the precedent — widening `ExtPorts.ai_step` to thread the world token is exactly the move
this item repeats twice.

## Why this starts now, and what it is not blocked on

**Route B's verdict is blocked; its build is not.** Measured at review:

- Compose's one registration-only ambient source is `register.ail:3 — import std/env (getEnvOr)`, and
  **registration runs before the world exists**, so it can never be world-mediated. Under classifier
  3's **closure** unit that keeps compose AMBIENT no matter how well its hooks are routed.
- So compose clears only if the **hook-scope** verdict is promoted, which is an ADR-scope decision
  WI-D15 explicitly did not ask for and which needs a review round.

**But every line of work below is needed under either unit.** Routing an extension's effects through
world-mediated seams is the same job whichever verdict eventually reads it. **The promotion review can
run in parallel; it does not gate this.**

## Mission

**Give `ExtPorts` the effect surface compose's hooks actually need**, and discharge the long-owed
`proc_exec` widening while doing it. **This item does not route compose** — that is part 2.

`ExtPorts` at HEAD, verified:

```ailang
ai_step:    (ExtWorld, string, [Msg]) -> AiStepOutcome    ! {AI, IO, Trace}    -- world-threading
clock_now:  (ExtWorld)                -> ExtClockReading  ! {Clock}            -- world-threading
proc_exec:  (string, string)          -> string           ! {IO, Process, FS}  -- NOT
env_get:    (string, string)          -> string           ! {Env}              -- NOT
```

**`proc_exec` and `env_get` are the two remaining classifier-2 members**, and they are members for
exactly the reason `ai_step` was before B2b: *"a field whose call is the extension-side entry to a
core seam that D1 requires to thread successor state, and which cannot return it."* They have **zero
call sites**, which is the same "first exercise of a seam with no callers" D3 hit with `clock_now` —
**budget for it not surviving contact unchanged.**

Compose's hook-reachable effects, derived from its modules:

| Effect | Where | Seam |
|---|---|---|
| `std/process (exec)` | `author_tools.ail`, `compose.ail` | **`proc_exec`, widened** |
| `std/clock (now)` | `author_tools.ail`, `compose.ail` | `clock_now` — already world-threading |
| `std/fs` read side — `readFile`, `fileExists`, `isFile`, `isDir`, `listDir` | `author_tools.ail`, `config.ail`, `compose.ail` | **a new file seam** |
| `std/fs` write side — `writeFile`, `mkdirAll`, `removeFile` | `store.ail`, `compose.ail` | **see the decision below** |
| `std/io (println)` | four modules | **see the decision below** |

## The decision this item owns, and it is not plumbing

**D1's boundary is "external observations that can affect session control flow or the ledger". A file
WRITE is not an observation, and neither is `println`.**

So the question is not *how* to route them but **whether they belong in the world at all**. Three
answers are available and the item must choose explicitly:

1. **World-mediated, recorded and replayed** — the write becomes an interaction in the log. Faithful,
   and it makes a deterministic run reproduce filesystem effects. Costly, and it puts emissions in a
   channel D1 scoped to observations.
2. **World-mediated, recorded, not replayed** — the world sees the write, the log records it, replay
   does not perform it. This is closest to how `Ports.tool_exec` already behaves.
3. **Out of the world, and disclosed** — writes and prints are emissions, not observations; they are
   named in the profile's disclosure the way registration effects are in WI-D15's draft.

**Note that the read side is not in doubt** — `readFile`/`fileExists` are observations that plainly
affect control flow, and D3 already built the core analogue (`Ports.file_read`, a **point read**).
**Copy that shape; do not generalise it.**

## The rule you will break by accident

**Widening `proc_exec` moves a pinned artifact, and that is correct rather than a regression.**

Classifier 2's membership criterion selects a field *because it cannot return successor state*.
**Giving `proc_exec` a world token is exactly the condition that removes it from the set** — the set
goes from `{env_get, proc_exec}` to `{env_get}`, and `tools/ext_call_inventory/fixtures/expected.json`
carries a pinned membership block that will go red.

**This is B2b's situation verbatim**, and B2b's handoff recorded the trap: *"A session that edits the
pin to keep the selftest green has destroyed the signal. The pin exists to make this exact transition
loud."* **Move it deliberately and say which field left the set and why the criterion no longer
selects it.**

**And `env_get` is the one to leave alone.** Widening it buys nothing: the reads that matter happen at
**registration**, before any world exists, which is the whole of WI-D6's confound and WI-D15's
reading. **Widening a seam whose problematic callers cannot use it is motion without progress** —
name that rather than doing it for symmetry.

## Definition of done

**`proc_exec` world-threading**, on `AiStepOutcome`/`ExtClockReading`'s shape — B2b and D3 both chose a
record with `next_state`, and P1's argument for a record over a sum still holds.

**A file seam on `ExtPorts`**, with the read side copying `Ports.file_read`'s point-read shape, and
**the write/print decision taken and recorded with its reasoning.**

**The classifier-2 pin moved deliberately**, with the membership read rather than the exit code —
`derive.py` fails open and its failure is indistinguishable from a pass, which B4 recorded after
nearly shipping it twice.

**`env_get` explicitly not widened**, with the reason.

**Nothing routed.** Compose is part 2. If this item routes a call, it has taken part 2's scope and the
ABI change stops being separable from the extension change.

**Per S24 — assert reachability separately from verdict.** Two of WI-D15's four tooling slips were
fail-open and its fixture suite caught neither.

**Per S13/S9/S17** — targets in `make dst`; sweep cache-cold with `AILANG_RELAX_MODULES=1` including
the stdlib-adjacent cache; `make sync_packages` first (thirteenth consecutive item); restore mutants by
`cp` or `tar`.

**And expect the ABI major to move.** It stands at eight changed rows, deferred by D6, D7, D8 and D14
on the correct ground that a lockstep re-release is a release act. **This item adds at least two more.
State the count; the release is still not this item's to cut.**

## Out of scope

- **Routing compose** — part 2, and the larger half. D15 prices it at **6 modules holding ~23
  hook-reachable sources** for compose, roughly halved for `context_mode`, both **lower bounds**.
- **Removing the now-unused imports** — part 3, and it is what a closure-unit verdict would need.
- **Promoting the hook-scope verdict.** ADR-scope, needs a review round, runs in parallel.
- **Door 3's producer** (`show`), which leaves compose HOOK-UNRESOLVED regardless of Route B — WI-D15's
  largest finding and its own item.
- **Installing anything**; the full eleven-row table for either profile; criterion 1's basis;
  repairing classifier 1; the stdlib cache's 52-file producer; the gate-table State column; F3; the
  fourteen `register_with_config` rows.

## Stop and report rather than deciding inline

- **If the write/print decision cannot be made without an ADR reading**, draft and stop. D1's boundary
  sentence is the governing text and this project routes ADR corrections through a review round.
- **If widening `proc_exec` cannot thread without production code branching on test mode**, that
  falsifies D1 and is an ADR-level finding — B2b's stop condition, unchanged.
- **If the file seam's shape forces a change to `ai_step` or `clock_now`**, stop. Those are settled and
  a third widening of either is a different item.

## Report back

Fortieth calibration run, **and the first Route B build item.**

- **The git wall-clock window**, and how it compares to B2b's ~2h05m for the same shape.
- **The write/print decision, with its reasoning.** The item's durable output.
- **Which field left the classifier-2 set**, and the state of every artifact that encodes it.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **70 across
  thirty-nine runs.** This is a source-shaped item on the ABI surface, which is where B2a, B2b and D6
  each found one.
- **The ABI changed-row count**, and whether anything now forces the major.
