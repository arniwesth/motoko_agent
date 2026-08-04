# 2026-08-04 Cluster 17: WI-B3 — the `Message` migration, and a third frontier

## Context

Branch: `arniwesth/mot-55-execute-wi-b1` (B1's branch; B3 was taken before B2 on that same branch).

Session span: `c013f69` → **uncommitted working tree, 43 files**. Input was
`HANDOFF-execute-b3-message-migration.md`, executed cold against HEAD. Seventeenth code session of
project 009. Pin **v0.33.0** (B1 repinned from v0.26.0 the same day).

**Window: 48m40s**, `15:22:45Z` → `16:11:25Z` — roughly half machine time (three cache-cold
whole-tree sweeps, a 147-site mutation loop, `make dst`, `make check_core`, `make sync_packages`).

| | |
|---|---|
| Zero `images` failures tree-wide | **met — 0, from 91** |
| `src/core/types.ail:10` identity claim corrected | **met** |
| The judgement sites named individually | **met — 7** |
| `make check_core` exit 0 | **NOT met** — a third frontier is behind the wall |
| `make dst` green | **not required, and not achieved** — exit 2 |

**Tree: 161 pass / 74 fail**, from 135 / 100 at session start.

## Grounding correction, taken in the first two minutes

The handoff opens by saying B1 left "48 files modified and uncommitted" and instructs a
`git diff --stat` to confirm the tree is intact before starting. **It was committed**, as `c013f69`
("Finished implementation"), and the tree was clean. Contents matched the description exactly; only
the commit state differed. Worth recording because the handoff made the uncommitted state a
precondition to verify, and verifying it is what surfaced the discrepancy.

A second, smaller instrument difference: B1 reported 130 / 105 where I measured 135 / 100 at the same
HEAD. Not a tree change — I applied `AILANG_RELAX_MODULES=1` across the whole sweep rather than to
`packages/` alone, which fixes five module-path failures. **The `images` count, 91, matched B1's
exactly**, which is the number that mattered.

## The order the work took

1. **Grounding**, ~10 minutes: B1's execution report, the plan's S8/S9, the stdlib's actual
   `Message` (5 fields, `images: [ImagePart]`), both `Msg` declarations (4 fields each).
2. **A cache-cold whole-tree sweep before touching anything.** 91 `images` failures — but only
   **7 distinct error sites**, the other 84 files failing transitively. That reframed the item: the
   sweep surfaces a frontier, never a total, exactly as B1 warned.
3. **Tooling before edits**, per M1's rider. A brace-balanced literal scanner, then a rewriter, then
   a round-trip proof. **This caught two rewriter corruption bugs before a single tree edit.**
4. **Bulk apply to all 147**, then a governing-annotation classifier, then compiler adjudication of
   the remainder — three rounds of sweep-and-repair to fixpoint.
5. **The one genuine crossing**, by hand.
6. **The mutation loop**, 147 sites, cache-cold.
7. **`check_core`, then `dst` alone, then `sync_packages`** — each read as an exit status.

## The two bugs the round-trip test caught, pre-edit

The rewriter was proven lossless before use: **147 adds + 147 deletes across 53 files,
byte-identical**. Its first run was not:

1. When a literal's closing brace shares a line with fields, the computed "indent before `}`" was not
   whitespace — it was the field text, which the rewriter then **duplicated**.
   `smoke_compaction_e2e.ail` came out with four literals each carrying a repeated field line.
2. Single-line literals lost the space before `}`.

Both would have silently corrupted source. **A shape-matching pass with no round-trip proof ships
both**, and this is the concrete evidence for M1's tooling-first rider that the plan did not yet have.

## The finding worth carrying forward: a diagnostic's labels are a context-dependent interface

The handoff predicted I would break the two-directional rule by accident. I did — **but one layer up
from where it expected, in the instrument rather than in the source.**

`ailang check` reports `expected` / `actual` in an order that **flips by error context**:

| Context | `expected` is | `actual` is |
|---|---|---|
| `let annotation` / `return type annotation` | the **literal** | the annotation |
| `function application, parameter N` / `list element N` | the **parameter type** | the literal |

So `extra fields: images` means *add* in one context and *remove* in the other, and the `Hint:` is
generated from whichever order was used — **on revert sites it reads "add the field(s) to the
literal" when the correct fix is to delete it.**

My first compiler-driven fix loop assumed a single mapping. It **re-added `images` to three sites I
had already correctly reverted** (`compaction_structural.ail` 104 / 199 / 203) and **oscillated 30
times** on a fourth. The rebuild stopped reading labels entirely: **flip the literal, ask whether
that site's error moved.** Immune to label order, converged in 60 edits.

The oscillating site was not a shape problem at all — it was the run's single genuine implicit
crossing, which is why no flip could satisfy it. **The oscillation was the detector working.**

## Numbers, against M1's 69 / 47 / 7

| | M1 | measured |
|---|---|---|
| Additive sites | 69 | **85** |
| Over-applications reverted | 47 | **62** |
| Judgement sites | 7 | **7** |
| Files | 28 | **42 net-changed** (53 carry literals) |

**The divergence is population, not method.** The tree holds **147** `Msg`-shaped literals against
M1's 116 touched. The additive/revert **ratio** is nearly identical — M1 59/41, here 58/42 — which is
the stronger evidence this is the same migration: the split between directions did not move, only the
count did.

**Ten files contain literals of BOTH types.** `phase_vocab.ail` alone: 4 `Msg`, 12 `Message`.
`smoke_compaction_tool_call_id.ail` holds two converters of **opposite direction, thirteen lines
apart**. That is the number that justifies the rider — a per-file decision is wrong in ten places and
a per-repository decision is wrong in 147.

**Five converters in four files, not the two the handoff named.** The third
(`compaction_ai.ail:19 msg_to_message`) and the mirrored pair in
`smoke_compaction_tool_call_id.ail` were found by reading call sites, not by the compiler.

## The third frontier — reported, not absorbed

**`make check_core` exits 2.** It still dies in `verify_extensions` with all 7 extensions failing on
one identical line, but the line moved from `ai_compat.ail:196` (`images`) to
`compose.register_with_config` (missing `AI, Clock, IO, Process, Rand`).

Of 74 remaining failures: **65 newly reachable, 9 pre-existing.** Three effect-row blockers account
for 56 files; a genuinely new species — `cannot unify record with unexpandable type constructor
GeneratorBounds` at `dst_replay.ail:998` — accounts for 8. **Nothing in the plan anticipates
`GeneratorBounds`.**

B1's "zero effect-row failures remain reachable" was true when written and is now superseded,
correctly and predictably: those rows sat behind the `images` error. **Absent still reads identically
to unchanged**, one layer down.

## Mutation: 0 measurable silent-wrong sites, 64 unmeasurable

Running total stays at **37 across seventeen runs. Determinism has still caught none.**

| | sites | forced | unforced |
|---|---|---|---|
| In **green** files | **72** | **72** | **0** |
| In files red for a non-`images` reason | 75 | 11 | **64** |

**Every measurable site is compiler-forced.** The structural reason: AILANG records are closed, so a
wrong-direction literal is a type error at first typed contact. This migration has no silent-wrong
band *where the type checker runs* — a stronger result than a two-directional migration across
structurally identical types suggested.

**The 64 must not read as verified.** Their files die on the third frontier before type checking. B4
inherits them alongside B1's 20 cascade files.

What caught the run's real defects: the round-trip test and the flip-and-verify loop. What did not:
the compiler's `Hint` (backwards on every revert site) and the 161 green files.

## Handoff corrections owed to the plan

1. **B1's work was committed, not uncommitted.**
2. **`make dst` is not red for B4's reason.** It exits 2 on the third frontier's effect row, in
   `dst_seeded`, and never reaches a manifest check. **`driver_only_dst` PASSES** — the manifest
   string is data passed into `driver_only_manifest`, not a value validated against the running
   toolchain, so it gates nothing. It is **stale, not red.**
3. **13 files carry `ailang 0.26.0`**, not "every DST script" — 8 via `driver_only_manifest`, 5 as
   inline `toolchain:` fields.
4. **Seven DST suites now pass** that could not run before this item.
5. **`fb_2ad074d754cd2c25` is still untestable**, but for a new reason — its probe module
   `src/core/dst_invariants.ail` now fails on `stub_step.live_ports`, not on `images`.

## What this delivers to B2

**B2 is measurable now, which was the entire reason for taking B3 first.** 65 previously-dark files
reach effect checking. B1's single measured ABI change (`ExtensionHooks.on_tool_handle += Rand`)
remains the only *contract* row demanded; M2's other three predictions are still neither confirmed
nor refuted, but the modules holding them now type-check far enough to be asked.

`make CI=1 sync_packages` **exits 0** — B1's drift gate intact. Running it regenerated three
`ailang.lock` content hashes for the packages edited here, resolving the `content changed` advisory.
Package-level `ailang` floors left alone, as B1 left them.

## Deliverables

- `.agent/projects/009_motoko_dst_execution/NOTE-b3-execution-report-and-plan-corrections.md`
- 43 files modified, uncommitted: 42 source + `ailang.lock`.
- Scratchpad instruments worth keeping: `litscan.py`, `rewrite.py`, `classify.py` (governing-annotation
  classifier — 116 of 147 correct with no compiler round trip), `adjudicate2.py` (flip-and-verify),
  `mutate.py`, `sweep.sh`. **B4 needs the mutation loop.**
