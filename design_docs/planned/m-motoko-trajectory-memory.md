# M-MOTOKO-TRAJECTORY-MEMORY — cross-run trajectory recall for the agent loop

**Status**: Deferred (accepted as a future improvement, not scheduled)
**Priority**: P3 — no current regression; the previous implementation never functioned
**Estimated effort**: ~1 day
**Dependencies**: none blocking. Must NOT be built on the `SharedMem` / `SharedIndex` effects (see below).
**Source**: fallout from [#159](https://github.com/arniwesth/motoko_agent/issues/159); investigation 2026-08-20

---

## Intent

When the agent meets a task, check whether a similar task was resolved before, and inject
the prior trajectory summary into the system prompt as a hint. After a successful run, store
the trajectory so later runs benefit.

This is a real capability worth having. It is deferred, not rejected.

## Why the previous attempt is gone

`src/core/cache.ail` implemented exactly this shape and never worked. It was removed on
2026-08-20 (same change that closed #159) after the following was established:

1. **Nothing ever wrote to it.** `put_trajectory` had zero call sites in the repo. `get_hint`
   was called once, at `rpc.ail:209`, reading a store nothing populated — so it returned `""`
   on every run, forever, and `with_cache_hint` took its `hint == ""` short-circuit every time.

2. **It could not have worked even if wired.** The cache stored frames via `std/sem`
   (`store_frame` / `load_frame`), which run on the `SharedMem` effect. At `ailang run` time
   `SharedMem` is unconditionally backed by an in-memory map — `setupSharedMemHandler`
   (`cmd/ailang/run_helpers.go`) passes `nil` to `NewSharedMemContext`, yielding
   `NewInMemorySharedCache()`, with the comment *"Future: could add flags for Redis,
   memcached, etc."* Process-lifetime only. "So future runs can benefit" was not achievable
   on that substrate.

3. **The persistent store exists but is not reachable from AILANG code.** `SQLiteSharedCache`
   (M-BRAIN) is a competent embedded vector store — WAL, SimHash search, FTS5 keyword search,
   cosine similarity over float32 embeddings, TTL/GC, namespaces, pluggable `Embedder` with
   auto-embedding on write, two tiers (`~/.ailang/state/brain.db` user, `.ailang/state/brain.db`
   project). But `NewBrainStore` is constructed only by the `ailang cache` / `ailang brain` /
   `ailang microrag` CLI commands. No running `.ail` program reaches it through `SharedMem`.

Verified against AILANG `v0.33.1-84-g127c1443e` (vendored) and `v0.33.0` (PATH).

## Why not wait for AILANG to close the gap

Wiring the persistent backend into the effect was planned and did not ship. It is a single
unchecked line in M-BRAIN Phase 1 — *"Wire into `run_helpers.go`: when `SharedMem` cap
requested, check config for backend preference"* — while every neighbouring item in that phase,
and all of Phase 2's CLI, did ship. The earlier plan (`semantic-caching-future.md`,
"1. Persistent Backends (DX-18)", Redis + Firestore, High priority) was never built either, and
the `DX-18` identifier was subsequently reused twice for unrelated work.

Timeline: the in-memory handler was written 2025-12-16; M-BRAIN M1 landed 2026-03-13; five
further months of persistent-store development followed (M-BRAIN M2, M-BRAIN-VECTORS M1–M3,
microrag). The effect's backend selection was never revisited.

Treat effect-level persistence as unavailable.

## Recommended approach when picked up

Follow `motoko-ext-microrag`, which is the one component in this repo doing real semantic
retrieval and deliberately bypasses both effects: `microrag_context_for` is `! {Process}` and
shells out to the `ailang microrag` CLI.

- Store and query over `! {Process}`, against `ailang cache` (the brain DB already on disk,
  which gives SimHash + FTS5 + cosine for free) or a vector DB of choice.
- Keep it an **extension**, not core. It is optional behaviour with an external dependency,
  which is what the extension ABI is for; core should not grow another effect ceiling for it.
- Do not add `SharedIndex` to `[extensions] effects` — that is the row stamped on the generated
  registry, and widening it breaks every consumer (see #159). Note that `SharedIndex` *is*
  legitimately in `[effects] max` and must stay: the ceiling is checked against every non-`pkg/`
  module the project loads, the stdlib included, and `std/sem` declares
  `! {SharedMem, SharedIndex}` on `store_frame_ns` (:466). `motoko-ext-context-mode` imports
  `std/sem`, so the ceiling has to cover it even though nothing here performs it. The two keys
  are not interchangeable — that is the whole point of the split.

## Seam left in place

`with_cache_hint(system, hint)` remains exported and tested in `src/core/prompts.ail`
(`prompts_test.ail:38,45`). It is a pure function that returns `system` unchanged when
`hint == ""`. That is the injection point — a future implementation supplies the hint;
nothing else in the prompt path needs to change.

`rpc.ail` no longer calls it, so re-wiring means restoring one call at the
`system_with_agents` binding.

## Related

- [#159](https://github.com/arniwesth/motoko_agent/issues/159) — registry effect-row regression that surfaced this
- [sunholo-data/ailang#800](https://github.com/sunholo-data/ailang/issues/800) — the upstream generator fix
- AILANG `design_docs/implemented/v0_9_2/m-brain.md` — M-BRAIN plan, incl. the unshipped wiring line
- AILANG `design_docs/planned/v0_29_0/m-ailang-semantic-context.md` — R7 plans on `std/sem`/`SharedMem`
  as if the brain were reachable from them; it is not
