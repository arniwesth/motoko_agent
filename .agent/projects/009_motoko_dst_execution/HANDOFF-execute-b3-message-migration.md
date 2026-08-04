# Handoff: execute WI-B3 — the `Message` migration

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-B1 landed 2026-08-04** (33m25s): the pin is at v0.33.0 in all three sites, **zero effect-row
failures remain reachable**, and the tree is **130 pass / 105 fail** — of which **91 fail on
`images`**. That wall is this item.

**B3 before B2, and the reason is measured rather than preferential.** Both are unblocked by B1, but
**B2's scope cannot be measured until this lands**: B1 found only *one* of M2's three predicted ABI
changes, because the other three hooks and `ExtPorts.ai_step` sit in modules that never reached
effect checking — the `images` error precedes it. Taking B2 first means working blind against a
frontier, and *absent reads identically to unchanged*.

**Read first:** `NOTE-b1-execution-report-and-plan-corrections.md`, then the plan's
`## Standing rules` — **S9 is new and was earned by B1**, and **S8 governs the measurement here.**

## Mission

Migrate to v0.33.0's `Message`, which has gained a fifth field.

**The wave is still open.** B1–B3 are one inseparable wave and **WI-B4 is its green gate**; B3 does
not have to leave `make dst` green, and it will not. Its own gate is below.

## The rule you will break by accident

**The migration runs in TWO directions, and the compiler cannot tell you which one a site needs —
because the two types are structurally identical apart from the field you are adding.**

Verified at HEAD:

| Type | Fields |
|---|---|
| `std/ai.Message` @ v0.33.0 | `role, content, tool_calls, tool_call_id, ` **`images: [ImagePart]`** |
| `src/core/types.Msg` | `role, content, tool_calls, tool_call_id` — **four, and it stays four** |
| `motoko_ext_abi.Msg` | the same four — **also stays four** |

So the tree contains literals of both shapes, and **the required edit is opposite depending on which
side of the seam a literal is on**:

- [`phase_vocab.ail:830`](.) `msgs_to_messages(msgs: [Msg]) -> [Message]` builds a **four-field
  literal that must gain `images: []`**.
- [`session.ail:1152`](.) `messages_to_msgs(msgs: [Message]) -> [Msg]` builds a **four-field literal
  from a `Message`, and must NOT gain it** — the field is *dropped* at that seam, deliberately.

**A uniform pass that adds `images: []` to everything `Message`-shaped is wrong**, and M1 measured
the cost precisely: **47 over-applications had to be reverted, every one a `Msg`-typed literal**,
against 69 that were correct. That is why M1's rider is *tooling first* — the 14 minutes held only
because a brace-balanced literal rewriter and a compiler-driven fix loop were written before any
edit. **Write the tool so it distinguishes the two types, not so it matches the shape.**

**And B1 hit exactly this and stopped rather than guess**: it abandoned an attempt to measure past
the wall in a throwaway worktree because "the seam direction differs per site, so a crude instrument
would have produced a **wrong** number, which is worse than a scoped one."

## The load-bearing comment that becomes false

`src/core/types.ail:10` says:

> `Msg` is structurally identical to `std/ai.Message` and `motoko_ext_abi.Msg`

**That is true at v0.26.0 and false the moment this lands**, and it is not decoration — the file
records that the codebase *relies* on it, and M1 found `Message` values crossing into `[Msg]`-typed
APIs implicitly in **seven places**. Those seven are M1's judgement sites: each becomes a compile
error needing a written conversion rather than an implicit crossing.

**Correct the comment in this change.** A reader who trusts it after B3 will write an implicit
crossing that no longer exists, and the comment is where they will look.

## The one architectural decision, already settled — do not re-open it

**Motoko's `Msg` and the ext-ABI `Msg` stay at four fields; vision parts are dropped at the seam.**
M1 states this as the decision that gates the other 116 edits and says it should be made explicitly
rather than discovered. Widening the ABI `Msg` is a **separate versioned-surface decision** and is
not B3's — it would be an `motoko-ext-abi` major, which is B2's territory.

## Grounding, verified at HEAD

**Run `git diff --stat` against B1's tree first** — B1 left **48 files modified and uncommitted**
(`ailang.toml`, `ailang.lock`, 46 source). You are building on an uncommitted working tree; confirm
it is intact before starting.

| Anchor | Value |
|---|---|
| Files failing on `images` | **91 tree-wide**; 25 of the 51 in `check_core`'s scope |
| The first wall `check_core` hits | `packages/motoko-ext-ai-compat/ai_compat.ail:196` — a `[Message]` literal, and **all seven extensions fail on this one line** |
| The two seam converters | `phase_vocab.ail:830` (add), `session.ail:1152` (drop) |
| The identity claim to correct | `src/core/types.ail:10` |
| M1's measurement | 14 min, 28 files, **69 additive sites**, **47 reverts**, **7 judgement sites** |
| A5 attribution anchors | `stub_step.ail:161`; `session.ail`'s 948 / 1053 / 2290 / 2400. `driver_only` is **v3** |

**M1 should transfer cleanly this time, and that is unusual enough to say.** It was measured against
the **released v0.31.0 record shape**, and v0.33.0's `Message` carries the same `images: [ImagePart]`
field. So unlike M2's 381 — which B1 correctly reported as a frontier rather than a total — M1's 69
and 7 are measurements of the same migration. Treat a large divergence as a finding.

## Definition of done

**Zero `images` failures tree-wide.** That is B3's gate, and it is the analogue of B1's corrected one:
measurable, and not reaching across the wave. **`make check_core` is expected to go green here** —
B1's could not, because `check_core` dies in `verify_extensions` on precisely this field — but
**verify that rather than assuming it**, and if something else is behind the wall, report it as the
next frontier rather than absorbing it.

**`src/core/types.ail:10`'s identity claim corrected.**

**The seven judgement sites named individually in the report**, with what each crossing became. M1
warns that a grep-derived estimate counts the 69 and misses all seven, and those seven are where a
silently-wrong edit would live.

**Per S9 — new, and earned by B1 — clear `.ailang/cache` before believing any check whose input you
just mutated.** B1's mutation loop read GREEN on a warm cache and RED on a cold one, and nearly
argued for reverting a correct ABI change. This item runs a compiler-driven fix loop over ~120 sites;
it is the same exposure at higher volume.

**`make dst` is NOT required green.** Say what it does. It will still be red for B4's reason — every
DST script carries `driver_only_manifest("HEAD", "ailang 0.26.0", …)`, and **re-issuing that manifest
is WI-B4's**, deliberately untouched by B1.

## Out of scope

- **WI-B2's ABI major**, including the two `ScriptedStep` widenings, which B2 is the free moment for.
  Note B2 becomes *measurable* the moment this lands — that is the main thing B3 delivers to it.
- **WI-B4's classifier re-derivation and manifest re-issue**, including **re-running B1's unfinished
  mutation loop**: twenty files carrying cascade sites were behind this wall and are **unverified,
  which must not read as verified**. Exactly one has a narrow row (`compose.ail:756`) and is the
  remaining over-widening candidate.
- **Removing the workarounds for the two AILANG defects v0.33.0 fixed** (`fb_e44ba922db1c42be`,
  `fb_b39697480a4e8bbc`) — a deliberate item, since each workaround carries a comment pointing at its
  issue file. Note the second is only *half* clear: the silent-wrong-answer mode is gone, the
  check-time diagnostic is not.
- **Widening either `Msg`.** Settled above.

## Stop and report rather than deciding inline

- **If a crossing cannot be written without widening `Msg`**, stop — that is the versioned-surface
  decision B3 does not own.
- **If the site count diverges materially from M1's 69/7**, that is the headline of your report.
  Unlike M2, M1 measured this exact migration, so a divergence means something changed.
- **If clearing the `images` wall reveals a third frontier** rather than a green `check_core`, report
  what it is; B1's sweep could not see past this wall and neither could its ABI measurement.

## Traps

**Read `make dst`'s exit status, never a scan of its output.** **Do not run other `make` targets
concurrently with it.**

**The stdlib is global**, and B1 lost time to it: `$HOME/.local/share/ailang/std` is shared, so a
baseline taken with an older binary measures that compiler against the *current* stdlib — a chimera.
`AILANG_STDLIB_PATH` is the fix. Relevant if you compare against v0.26.0 for any reason.

**`AILANG_RELAX_MODULES=1` is needed to sweep `packages/`** — their module declarations are
`sunholo/…` while their paths are `packages/…`.

**Never probe from `/tmp`** — `MOD010` auto-relaxes there.

## Report back

Seventeenth calibration run.

- **The git wall-clock window**, not a felt ratio.
- **Sites and files against M1's 69 additive / 47 revert / 7 judgement**, and whether the tooling-first
  rider held.
- **The seven judgement sites, named** — this is the part a grep cannot produce and the part B2 will
  need.
- **Recorded bindings, split decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** **37 across sixteen runs; determinism has caught none.** A two-directional migration
  across two structurally-identical types is a strong candidate for the thirty-eighth.
- **What `check_core` does once the wall clears** — that number sizes B2.
