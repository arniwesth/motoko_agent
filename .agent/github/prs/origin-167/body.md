---
repo: arniwesth/motoko_agent
pr: 167
branch: arniwesth/mot-159-registry-effect-row
ticket: MOT-159
title: "MOT-159: declare the performed effect row for the generated extension registry"
---

## Summary

`ailang generate-extension-registry` stamped the generated dispatch functions from `[effects] max`, which is the project's *ceiling* rather than a claim about what `resolve` performs — so regenerating widened the row with `SharedIndex` and broke 9 core modules plus the extension-boot verifier. This declares `[extensions] effects` explicitly as the union of the registered packages' `register_with_config` rows, so the generated registry carries only what `resolve` performs, and removes the inert trajectory cache found while tracing where `SharedIndex` came from.

`SharedIndex` **stays** in `[effects] max`. An earlier revision of this branch dropped it and CI caught the mistake: `validateEffectCeiling` exempts dependencies by the `pkg/` module-path prefix, and the stdlib is not `pkg/`-prefixed, so `std/sem` is checked against this project's ceiling — and `std/sem:466` declares `! {SharedMem, SharedIndex}` on `store_frame_ns`. `motoko-ext-context-mode` imports `std/sem`, so the ceiling must cover it even though nothing here performs it.

That is precisely the case the two-key split exists for: the ceiling covers what imported modules *declare*, the registry row carries only what `resolve` *performs*, and no single value serves both.

Stacked on #166 (`arniwesth/mot-100-fix-output-headroom`); one commit on top of that base.

Per file:

- **`ailang.toml`** — new `[extensions] effects` key with the honest 11-effect row; `[effects] max` keeps `SharedIndex`, now with a comment recording why.
- **`src/core/cache.ail`** *(deleted)* — the trajectory cache. `put_trajectory` had zero call sites, so `get_hint` read a store nothing wrote and returned `""` on every run.
- **`src/core/rpc.ail`** — drops the `get_hint` call and the now-identity `with_cache_hint` call; `system_with_agents` threads straight through.
- **`design_docs/planned/m-motoko-trajectory-memory.md`** — records cross-run trajectory recall as deferred, with why the old approach could not have worked and what to build instead.
- **`ailang.lock`** — re-locked.

## Changes

- Fixed
- fix(effects): keep SharedIndex in the ceiling, narrow only the registry row

5 files changed.

## Governing docs

No `.agent/projects/` document governs this change — it originates from issue #159 rather than a planned project.

- `design_docs/planned/m-motoko-trajectory-memory.md` — added here; governs the deferred follow-up
- Upstream: sunholo-data/ailang#800 — the generator fix this configuration depends on

## Predicted outcome

`ailang generate-extension-registry` becomes a safe instruction again — the action its own header documents (`Do not edit. Regenerate: …`) stops being the thing that breaks the build. Adding, removing or renaming an extension should no longer produce a red `check_core`, and no one should need to hand-edit the generated file afterwards.

Checked by regenerating and confirming the output is byte-identical to what is committed, then running the type-check and test suites. The durable check is that `registry_generated.ail` no longer appears in `git status` after a regeneration.

Because `max` legitimately keeps `SharedIndex`, an **unpatched** generator still emits the wide row — so the upstream fix (sunholo-data/ailang#800) is load-bearing rather than cosmetic. Regenerating requires a toolchain carrying it; the committed file is correct either way, and CI does not regenerate.

Two things this deliberately does not do. It does not widen the nine consumers to `[effects] max` (that propagates a row nobody performs and re-breaks whenever `max` grows), and it does not restore trajectory caching — see the design doc for why that needs a different substrate.

## Test evidence

Regeneration is now a true no-op, and stable across repeated runs:

```
$ ./ailang/bin/ailang generate-extension-registry
generated src/core/ext/registry_generated.ail (16 packages)
$ git status --short src/core/ext/registry_generated.ail
                                    ← empty; three consecutive runs, still empty
```

Motoko, after the change. **Run with the compile caches cleared** — a warm cache skips re-checking `std/sem`, which is how the ceiling regression passed locally before CI caught it:

```
$ find . -type d -name cache -path '*.ailang*' | xargs rm -rf
$ make check_core
src/core/ type-check: 56 passed, 0 failed        (57 before, minus the deleted cache.ail)

$ make verify_extensions
verify_extensions (default): 8 booted, 0 failed

$ make test_core
19 tests: 19 passed, 0 failed, 0 skipped
All core runtime module tests passed!
```

Backwards compatibility — the **unpatched** `v0.33.0` on PATH ignores the new key and falls back to `max`, emitting the same set in declaration order. Cosmetic diff, no breakage:

```
$ ailang --version
AILANG v0.33.0
$ ailang generate-extension-registry --dry-run | sed -n '29p'
... ! {IO, Env, AI, Net, FS, Process, SharedMem, Clock, Stream, Rand, Trace}
```

The `check_core` / `verify_extensions` runs above used that unpatched binary, so they double as the compatibility check.

Upstream generator patch (`fix/ext-registry-effect-row`, not yet pushed):

```
$ go test ./cmd/ailang/ ./internal/pkg/ -count=1
ok  github.com/sunholo-data/ailang/cmd/ailang   24.055s
ok  github.com/sunholo-data/ailang/internal/pkg  0.120s
```

Supporting checks: `SharedIndex` is performed by nothing in the repo — it appears in the `.ail` surface only in one comment about a future phase — but is *declared* by `std/sem`, which the ceiling check reaches because the exemption is by `pkg/` prefix and the stdlib does not carry one. Hence narrow registry row, wide ceiling.

Closes #159
