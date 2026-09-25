# Handoff: execute WI-B1 — repin the toolchain to v0.33.0

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**The first item of Milestone B, and the first work in this project not gated on anything external.**
The upstream recorded-stream API shipped in released **AILANG v0.33.0** on 2026-08-04, verified
against the tag rather than the changelog. Milestone A completed the same day: seventeen work items,
ten clusters, `make dst` exit 0 at **762 checks** across 30 targets.

**Read first, in this order:**

1. `HANDOFF-post-upstream-recorded-stream-landing.md` — **its two live sections only**
   (`⚑ TRIGGER FIRED` and `What Milestone B inherits`). It is a briefing, not an executable handoff;
   its Mission and Sequence are dead and its head says so.
2. The plan's `## Standing rules` — **S1 and S8 bind here in a form specific to a repin**, below.
3. The plan's WI-B1 through WI-B4.

## Mission

Repin the toolchain from **v0.26.0 to v0.33.0**, and repair what the new effect checker rejects.

**B1 is preparation-only and is NOT independently green.** B1–B3 are one inseparable wave; **WI-B4 is
the wave's green integration gate**. Do not treat a clean `ailang check` as the end of B1 — the wave
is not green until B4 re-derives both classifiers and re-issues `driver_only`'s manifest.

**Order within the wave is fixed and the reason is measured:** the new pin turns effect rows into
hard errors *everywhere at once*, so **do not run `make dst` until `make check_core` is green.** The
first honest signal after the pin is `ailang check` failing across the tree; running the 30-target
DST gate first produces thousands of lines of downstream noise at roughly twenty minutes per attempt.

## The rule you will break by accident

**The compiler will name every missing effect row. It will not name the *right* row — and a row that
is too wide silences the error, passes every check, and silently reclassifies an extension hook.**

This is the repin's specific form of S8, and it has teeth here that it does not have elsewhere:

- The edits are compiler-driven, which makes them *feel* mechanical and safe. M2 measured 381 of them
  across 71 files and called almost all "mechanical corrections the compiler names precisely."
- But **D5's per-hook classification reads *declared* rows, not performed ones.** A hook declaring the
  nine-effect row while returning a constant is **not** effect-free for classification purposes.
- **Three ABI slots are coverable precisely because they carry no row at all** —
  `on_describe_tools`, `on_build_system_prompt` and `on_tool_policy`
  (`packages/motoko-ext-abi/types.ail`). They are the *entire* coverable extension surface under the
  declared-row rule. `on_budget_plan` is at `! {Env, FS}` and the other four are at nine effects.
- So **an over-wide row added to silence a v0.33.0 error can collapse the coverable surface to
  nothing**, and nothing in the compile output says so. The check that would catch it — profile
  coverage — is a `make` target you have been told not to run yet.

**Therefore, before you widen any row on `ExtensionHooks` or `ExtPorts`, stop and ask whether the
narrowest row that compiles is the one you are adding.** M2's three genuine ABI changes are known and
are *not* discretionary: `ExtPorts.ai_step` gains `Trace` (its declared row was simply wrong, since it
calls `Ports.model_step` which has always been `{AI, IO, Trace}`), and the four `ExtensionHooks` rows
that already carry rows gain `Rand` and `Trace`. **Anything beyond those four is a finding, not a
fix** — report it rather than absorbing it.

## The second trap, and it is measured rather than predicted

**Clear every `.ailang/cache` in the tree before believing any type error that follows a toolchain
change.** M2 hit this mid-repin: `src/core/rpc.ail` and `src/core/supervisor.ail` reported an
`ExtPorts.ai_step` row mismatch against source that was already correct, and clearing the caches
fixed both with **no source change**. The project has now hit stale-cache phantoms twice, once across
a stdlib change and once across a compiler version change. A repin is the highest-risk moment for it.

## Grounding, verified at HEAD while writing this

**Run `git diff --stat 28991c9..HEAD -- src packages scripts Makefile` first**; if non-empty,
re-verify the table.

| Anchor | Current value |
|---|---|
| Pin, floor | `ailang.toml:6` — `ailang = ">=0.26.0"` |
| Pin, source ref | `scripts/install-prerequisites.sh:39-40` — `AILANG_REF="v0.26.0"`, `AILANG_MIN_VERSION="0.26.0"` |
| **The drift guard** | `Makefile:19-30`, inside `sync_packages`, **CI-only** (`if [ "$(CI)" = "1" ]`). It derives `ref="v$$version"` from `ailang.toml`'s floor and requires `AILANG_REF` to equal it. **Bump all three together or CI fails on the mismatch** |
| Installed binary | v0.26.0, commit `3b52a24` |
| The three rowless ABI slots | `on_describe_tools`, `on_build_system_prompt`, `on_tool_policy` — the whole coverable surface |
| Gate size to preserve | **762 checks, 30 targets** in `make dst` |
| A5 attribution anchors | `stub_step.ail:161`; `session.ail`'s 948 / 1053 / 2290 / 2400. `driver_only` is **v3** |

**The 381-edit figure is a FLOOR, not the number.** M2 measured `v0.26.0 → v0.31.0`. The target is
**v0.33.0** — two releases further on, one of which added the recorded-stream API. Per
`re-ground-inherited-anchors-before-building.md`, re-measure rather than re-cite: **the first
`ailang check` sweep after the pin is the measurement**, and reporting it is part of this item.

## Definition of done

**The pin is bumped in all three places** — `ailang.toml`, `install-prerequisites.sh` (both vars), and
whatever the drift guard requires — and `make CI=1 sync_packages` passes, which is the guard's own
test.

**`make check_core` is exit 0** on v0.33.0, with every effect-row repair made at the narrowest row
that compiles.

**The two latent under-declarations M2 found are fixed**, since v0.33.0 rejects what v0.26.0 accepted:
`src/core/agents_md.ail`'s `walk_agents` performs `FS` undeclared, and
`packages/motoko-ext-omnigraph/register.ail`'s `register_with_config` performs `Process` undeclared.

**The ABI changes are exactly the three M2 names, or the surplus is reported.** Note that changing
`ExtensionHooks` is by declaration a **major version of `motoko-ext-abi`** — that is WI-B2's, not
yours; B1 makes the tree compile, B2 owns the version and the lockstep re-release.

**`make dst` is NOT required to be green at the end of B1.** Say what it does, and expect red.

## Out of scope

- **WI-B2's ABI major and the world-token widening** — including the two `ScriptedStep` widenings,
  which B2 is the free moment for (the cascade is paid once inside that wave rather than twice).
- **WI-B3's `Message` migration** (M1: 14 min, 28 files, 69 additive sites, 7 needing judgement, and
  its rider that tooling comes first).
- **WI-B4's classifier re-derivation and manifest re-issue** — the wave's green gate.
- **Adopting the recorded-stream API** — that is WI-C1, one closure in `live_ports`, and WI-C2's
  positive integration probe is what proves it.
- **The deferred register**: `max_resource_size` (a one-draw item), `seed_state`'s version axis
  (site 22), shrinking. All have named owners in the briefing.

## Stop and report rather than deciding inline

- **If a repair needs a row wider than the narrowest that compiles**, stop — see the rule above. On
  `ExtensionHooks` or `ExtPorts` specifically, anything beyond M2's three known changes is a finding.
- **If the measured edit count differs materially from 381**, that is the headline of your report, not
  a footnote: it re-sizes B2 and B3 for whoever takes them.
- **If v0.33.0 rejects something that looks like a compiler regression rather than a real
  under-declaration**, reduce it to a minimal repro and file it — this project has filed five AILANG
  defects and four had one-line workarounds found in minutes.

## Traps

**Read `make dst`'s exit status, never a scan of its output** — it was red for two clusters under
`--keep-going` because a failure was one line among 233 green ones. **Do not run other `make` targets
concurrently with it.**

**Three filed AILANG defects have workarounds and will recur**, all written up in `.agent/issues/`:
`fb_e44ba922db1c42be` (a call in the field-value position of a record update is not a dependency —
`let`-bind it; it also has a sibling in the head position of a cons), `fb_b39697480a4e8bbc` (an
out-of-scope constructor name in a pattern binds as a fresh variable, `ailang check` clean), and
`fb_2ad074d754cd2c25` (the cluster harness fails non-deterministically at ~6/10 in large modules).
**All three were found on v0.26.0 — check whether v0.33.0 fixed any of them**, and if so say which,
because the workarounds are in the tree and can be removed.

**Never probe from `/tmp`** — `MOD010` auto-relaxes there.

## Report back

Sixteenth calibration run, and the first of Milestone B.

- **The git wall-clock window**, not a felt ratio.
- **The measured edit count and file count**, against M2's 381/71 floor. This is the most valuable
  number in the report.
- **Recorded bindings, split decided versus discovered.** Cluster 15 found the discovered count can
  over-predict when one instrument surfaces several at once; a repin may be the opposite shape —
  many mechanical edits, few decisions.
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** **34 across fifteen clusters; determinism has caught none.** A repin is exactly the
  shape that feels like it needs no detectors and exactly the shape where a silently-wrong edit hides
  in 71 files of diff — budget mutation loops as the cost of the wave, not as verification after it.
- **Whether any of the three filed AILANG defects is fixed on v0.33.0.**
