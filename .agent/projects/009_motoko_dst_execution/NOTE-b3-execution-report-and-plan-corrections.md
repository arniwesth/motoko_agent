# WI-B3 execution report — the `Message` migration (v0.33.0's fifth field)

Seventeenth calibration run, second of Milestone B. Written against HEAD `c013f69`, branch
`arniwesth/mot-55-execute-wi-b1`.

## Window

**48m40s** wall-clock: `2026-08-04T15:22:45Z` → `2026-08-04T16:11:25Z`. Roughly half of that is
machine time — three whole-tree sweeps, a 147-site mutation loop, `make dst` and `make check_core`,
all cache-cold.

**A grounding correction first.** The handoff says B1 left "48 files modified and uncommitted".
They were committed, as `c013f69` ("Finished implementation"), and the tree was clean at start. The
48-file contents are exactly as described; only their commit state differed.

## What landed

| Definition-of-done item | State |
|---|---|
| Zero `images` failures tree-wide | ✅ **0**, from 91 |
| `make check_core` exit 0 | ❌ **NO** — a third frontier is behind the wall, reported below |
| `src/core/types.ail:10` identity claim corrected | ✅ rewritten, and it says more than "not identical" |
| The judgement sites named individually | ✅ **7**, below |
| `make dst` — say what it does | ✅ **exit 2**, and *not* for the predicted reason |

**Tree: 161 pass / 74 fail**, from 135 / 100 at start. (B1 reported 130 / 105; the 5-file difference
is instrument, not tree — I applied `AILANG_RELAX_MODULES=1` across the whole sweep rather than to
`packages/` alone. The `images` count, 91, matches B1's exactly.)

## The measurement, against M1's 69 / 47 / 7

**M1 transferred in shape and diverged in magnitude by about a quarter.**

| | M1 | measured here |
|---|---|---|
| Additive sites (gained `images: []`) | 69 | **85** |
| Over-applications reverted | 47 | **62** |
| Judgement sites | 7 | **7** |
| Files | 28 | **42 net-changed** (53 carry literals) |

**The divergence is real and it is in the population, not the method.** The tree holds **147**
`Msg`-shaped record literals, against M1's 116 touched — the codebase grew ~27% more of them between
the v0.31.0 measurement and now. The additive/revert *ratio* is nearly identical (M1 59/41, here
58/42), which is the stronger signal that this is the same migration: the split between the two
directions did not move, only the count did.

**The judgement count landing exactly on 7 is a coincidence I did not engineer**, and the seven are
not the same seven M1 would have named — M1's were "`Message` values crossing into `[Msg]`-typed
APIs implicitly in seven places", and only **one** of mine is that. The rest are the converters
themselves, which M1 counted separately.

### The tooling-first rider held, and it paid twice before touching the tree

Nothing was edited until a brace-balanced rewriter existed and had been proven lossless: **147 adds
+ 147 deletes across all 53 files, byte-identical round trip, zero errors.** The round-trip test
caught **two real rewriter defects** on its first run, both of which would have silently corrupted
source:

1. When a literal's closing brace shares a line with fields, the "indent before `}`" was not
   whitespace — it was the field text, which the rewriter then duplicated. `smoke_compaction_e2e.ail`
   came out with four literals each carrying a repeated field line.
2. Single-line literals lost the space before `}` (`tool_call_id: "" }` → `""}`).

A shape-matching pass would have shipped both.

## The rule I broke by accident, exactly where the handoff said I would — but at the instrument

The handoff warned the migration runs in two directions. It does, and the source-level rule held
cleanly. **What went wrong was one layer up: my compiler-driven fix loop read the direction off the
compiler's own labels, and those labels are not stable.**

**`ailang check` reports `expected` / `actual` in an order that flips by error context.**

| Context | `expected` is | `actual` is |
|---|---|---|
| `let annotation` / `return type annotation` | the **literal** | the annotation |
| `function application, parameter N` / `list element N` | the **parameter type** | the literal |

So `extra fields: images` means *add* in one context and *remove* in the other, and the compiler's
`Hint:` is derived from whichever order was used — **on revert sites the hint reads "add the
field(s) to the literal" when the fix is to delete it.** My first adjudicator assumed a single
mapping, and it **re-added `images` to three sites I had already correctly reverted**
(`compaction_structural.ail` 104 / 199 / 203) and then **oscillated 30 times** on a fourth.

The fix was to stop reading the labels at all: the second adjudicator **flips the literal and asks
the compiler whether that site's error moved**, which is immune to label order. It made 60 edits and
converged. The oscillating site turned out not to be a shape problem at all — it was the one genuine
implicit crossing (below), which is why no flip could satisfy it.

**This is the run's most transferable finding: a diagnostic's *labels* are an interface, and this one
is context-dependent. Drive tooling off the compiler's verdict, never off its prose.**

## The seven judgement sites, named

The handoff named two converters. **There are five, in four files**, and every one had to be decided
individually because the compiler cannot infer which side of the seam a literal is on.

| # | Site | Direction | What the crossing became |
|---|---|---|---|
| 1 | `src/core/phase_vocab.ail:830` `msgs_to_messages` | `[Msg] → [Message]` | **adds** `images: []` — no source to copy from; `Msg` has no such field |
| 2 | `src/core/session.ail:1153` `messages_to_msgs` | `[Message] → [Msg]` | **drops** `images` — deliberate, per the settled decision |
| 3 | `packages/motoko-ext-compaction-ai/compaction_ai.ail:19` `msg_to_message` | `Msg → Message` | **adds** `images: []`. A third converter the handoff did not name; feeds `calibrated_usage_percent_anchored` |
| 4 | `scripts/smoke_compaction_tool_call_id.ail:36` `messages_to_msgs` | `[Message] → [Msg]` | **drops** — a deliberate mirror of #2, kept in sync by comment |
| 5 | `scripts/smoke_compaction_tool_call_id.ail:49` `msgs_to_messages` | `[Msg] → [Message]` | **adds** — mirror of #1 |
| 6 | `scripts/smoke_catalog_compaction.ail:20` `msg()` | implicit `Message` → `[Msg]` | **retyped to `Msg`**; `std/ai (Message)` import replaced by `pkg/…/motoko_ext_abi/types (Msg)` |
| 7 | `src/core/types.ail:10` | the identity claim | rewritten — see below |

**#4 and #5 are the sharpest instance of the trap in the tree: two converters of opposite direction,
in the same file, thirteen lines apart, structurally identical apart from the field.** A uniform
`images`-adding pass breaks #4 and a uniform stripping pass breaks #5. Both are green.

**#6 is the only true implicit crossing that surfaced** — M1 predicted seven of these. The other six
are either behind the third frontier (below) or no longer exist. It compiled before v0.33.0 because
the types were aliases; it is now a type error. Fixed by retyping the script to `Msg` rather than by
inserting a conversion, because the script's only consumer is `compact_step_with_limit`, which is
`Msg`-typed end to end — no vision parts are ever in play.

### The number the handoff did not have, and it is the one that justifies the rider

**Ten files contain literals of BOTH types.** `phase_vocab.ail` alone carries **4 `Msg` and 12
`Message`**; `session.ail` 1 and 8; `smoke_v2_compaction_chain.ail` an even 4 and 4. A per-file
decision is therefore wrong in ten places, and a per-repository decision is wrong in 147.

## `src/core/types.ail:10` — corrected, and it now carries the seam

The old comment claimed `Msg` is structurally identical to `std/ai.Message` **and**
`motoko_ext_abi.Msg`. Half of that is still true. The replacement states that the `Message` half is
false as of v0.33.0, names both converters and their directions, and says explicitly that widening
`Msg` is a versioned-surface decision rather than a migration detail — so the next reader finds the
decision at the place the handoff correctly predicted they would look.

## The third frontier: `check_core` does not go green, and the wall moved rather than fell

**`make check_core` exits 2.** It still dies in `verify_extensions`, and **all 7 extensions still
fail on one identical line** — but it is no longer `ai_compat.ail:196`. It is now:

```
Error: effect checking failed in pkg/sunholo/motoko_ext_compose/compose:
  Effect checking failed for function 'register_with_config'
  Missing effects: AI, Clock, IO, Process, Rand
  Current signature:  func register_with_config(...) -> T ! {Env, FS}
```

**Reported, not absorbed**, per the handoff. This is B1's class of work, not B3's, and it was
invisible to B1 for precisely the reason B1 named: it sat behind the `images` error. The 74
remaining failures split cleanly:

| Blocker | Files blocked | Class |
|---|---|---|
| `motoko_ext_compose.register_with_config` — missing `AI, Clock, IO, Process, Rand` | **31** | effect row |
| `src/core/test/stub_step.live_ports` — missing `AI, Clock, Env, IO` | **21** | effect row |
| `src/core/dst_replay.ail:998` — `cannot unify record with unexpandable type constructor GeneratorBounds` | **7** | type error |
| `compaction_ai.test_ai_drip_projected_relief_passthrough` — missing 9 effects | **4** | effect row |
| `scripts/dst/execution_program_dst.ail:87` — same `GeneratorBounds` | 1 | type error |
| `IMP010: 'MkHistory' not exported by src/core/phase_vocab` | 1 | export |
| `LDR001: module not found: stub_step` | 1 | fixture |
| Pre-existing on v0.26.0 (examples `++`, parse errors, `unrunnable`) | **9** | baseline |

**65 newly reachable, 9 pre-existing.** And this is a *frontier*, not a total, for the same reason
B1's was: `ailang check` stops at the first error per module, so three effect-row repairs and one
type-constructor repair are all that is currently visible behind 65 files. **Absent still reads
identically to unchanged.**

**B1's "zero effect-row failures remain reachable" was true when written and is now superseded** —
correctly so, and its own report predicted this exact shape. The `GeneratorBounds` failures are the
genuinely new species: they are neither effect rows nor `images`, and nothing in the plan anticipates
them.

## Sites where two answers type-checked and one was silently wrong: 0 measurable, 64 unmeasurable

**Running total stays at 37 across seventeen runs. Determinism has still caught none.**

The detector was a full mutation loop: flip every one of the 147 literals in turn, cache-cold (S9),
and ask whether the compiler's verdict for that file changes. A site whose flip goes unnoticed was
never *forced* — both answers type-check there, and my answer was chosen rather than derived.

| | sites | forced | unforced |
|---|---|---|---|
| In files that are **green** | **72** | **72** | **0** |
| In files **red for a non-`images` reason** | 75 | 11 | **64** |

**Every one of the 72 measurable sites is compiler-forced.** That is a stronger result than I
expected from a two-directional migration across structurally identical types, and the reason is
structural: AILANG records are closed, so a wrong-direction literal is a type error at its first
typed contact. The migration has no silent-wrong band *where the type checker runs*.

**The 64 must not read as verified.** Their files never reach type checking — they die on the third
frontier's effect rows first — so the mutation is unobservable, not benign. This is B1's situation
repeating exactly one layer down, and it inherits B1's other blind spot too: **the loop is per-file,
so a flip whose breakage lands in a different file reads as unforced.** No site in a green file read
unforced, so that spot did not bite here; it remains live for the 64.

**What caught the run's actual defects:** the rewriter round-trip test (2 corruption bugs, pre-edit)
and the flip-and-verify adjudicator (3 wrong-direction edits + 1 oscillation, mid-run). **What did
not:** the compiler's `Hint`, which was actively backwards on every revert site, and the 161 green
files, which are green under both the correct and the label-inverted reading of the sites they do
not constrain.

## `make dst` — exit 2, and the predicted reason is not the actual one

**Handoff correction.** It says `make dst` "will still be red for B4's reason — every DST script
carries `driver_only_manifest("HEAD", "ailang 0.26.0", …)`". Measured:

- **`make dst` exits 2 on the third frontier**, the same `compose.register_with_config` effect row,
  in `dst_seeded`. It never reaches a manifest check.
- **`driver_only_dst` PASSES.** The manifest string is *data passed into* `driver_only_manifest`, not
  a value validated against the running toolchain, so it gates nothing. It is **stale, not red.**
- **13 files carry `ailang 0.26.0`**, not "every DST script" — 8 via `driver_only_manifest`, 5 as
  inline `toolchain:` record fields.

**Seven DST suites now pass** that could not run before this item: `compaction_policy`,
`profile_coverage`, `profile_definition`, `driver_only`, `event_vocabulary`, `attribution_table`,
`compaction_seeded`. That is the clearest positive signal that the wall genuinely fell.

B4's manifest re-issue is still owed — the recorded toolchain is now wrong — but it is an accuracy
item, not a gate failure, and sizing it as "what makes `dst` red" would be wrong.

## What this delivers to B2, which was the point of taking B3 first

**B2 is now measurable.** With the `images` wall gone, `check_core` and the whole-tree sweep reach
effect checking in 65 previously-dark files. The immediately visible ABI-adjacent demand is the three
functions tabled above; B1's single measured ABI change (`ExtensionHooks.on_tool_handle += Rand`)
still stands as the only *contract* row demanded so far, and M2's other three predictions remain
neither confirmed nor refuted — the modules holding them now type-check far enough to be asked, which
they did not before.

**`sync_packages` still exits 0**, so B1's drift gate is intact. Running it regenerated three
`ailang.lock` content hashes for the packages I edited (`ai_compat`, `compaction_ai`,
`compaction_structural`); that is included in the diff and resolves the `content changed` advisory
`ailang run` was emitting. Package-level `ailang` floors were left alone, as B1 left them — B2's.

## Out of scope, untouched, and deliberately so

- **WI-B2's ABI major** and the two `ScriptedStep` widenings.
- **WI-B4's classifier re-derivation and manifest re-issue**, and the re-run of B1's mutation loop —
  now with **64 additional unverified `images` sites** on its list alongside B1's 20 cascade files.
- **Removing the two v0.33.0-fixed defect workarounds** (`fb_e44ba922db1c42be`,
  `fb_b39697480a4e8bbc`). Untouched. Note `fb_2ad074d754cd2c25`'s probe module
  `src/core/dst_invariants.ail` is *still* unreachable — it now fails on `stub_step.live_ports`
  rather than on `images`, so that ticket remains untestable on this pin for a new reason.
- **Widening either `Msg`.** Settled, and now documented at `src/core/types.ail:10` rather than only
  in the plan.

## Instruments left in the scratchpad

`litscan.py` (string/comment-aware brace-balanced literal scanner), `rewrite.py` (lossless add/delete,
refuses type declarations), `classify.py` (governing-annotation classifier — 116 of 147 correct
without any compiler round trip), `adjudicate2.py` (flip-and-verify fix loop), `mutate.py`
(cache-cold mutation loop), `sweep.sh` (cache-cold whole-tree sweep). The classifier and the
flip-and-verify loop are the two worth keeping; B4 needs the mutation loop.
