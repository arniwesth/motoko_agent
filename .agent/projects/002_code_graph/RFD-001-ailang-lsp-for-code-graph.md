# RFD-001: Should the AILANG LSP feed `ailang-graph`?

Date: 2026-06-30
Status: Open for decision (proposed: **Defer / optional experiment**)
Pinned binary: AILANG **v0.26.0** (commit `3b52a24`)
Relates to: [ADR-002](./ADR-002-ailang-code-graph-architecture.md) (architecture),
[HANDOFF-lsp-investigation.md](./HANDOFF-lsp-investigation.md) (the task this answers)
Evidence + prototype: `tools/code-graph/experiments/lsp/`
(`LSP_INVESTIGATION.md`, `lsp_probe{,2,3}.py`)

## Question for decision

Should the AILANG Language Server (`ailang lsp --stdio`) **improve, replace, or
complement** the current `ailang-graph` extractor (source parser + `ailang iface` +
`builtins list --by-effect`), and should anything change **before** the pending
upstream `ailang debug ast --json` / public-stdlib-iface feature requests land?

## Proposed decision

**Defer.** Keep the LSP as an **optional, isolated experiment** under
`tools/code-graph/experiments/lsp/`. Do **not** wire it into `extract.sh` or the core
extractor now, and do **not** replace the call graph or effect graph with it — the LSP
cannot produce them. The headline precision upgrade stays with the already-filed
`ailang debug ast --json` ask. Two flag-gated, additive **enrichment** wins are worth a
low-priority follow-up issue but are not adopted by this RFD.

This is proposed, not decided — see Open Questions.

## Why this came up

ADR-002 shipped a deliberately approximate, hydration-free call/effect graph and noted
two upstream asks (AST `--json`; machine-readable public-stdlib effect rows). The LSP
is a newer AILANG surface that could, in principle, supply structured semantic data the
source parser only approximates. This RFD records whether it actually does, with
evidence against the local binary (not just docs).

## Evidence summary

Full detail and sanitized JSON-RPC responses are in
`tools/code-graph/experiments/lsp/LSP_INVESTIGATION.md`. Headlines:

- **Protocol works.** `initialize` advertises `hover`, `definition`, `references`,
  `documentSymbol` (+ `publishDiagnostics`). No completion/signature-help/semantic
  tokens (MVP). The server runs **`--relax-modules` automatically**, so it reads
  modules `iface` refuses (e.g. `agent_loop_v2.ail`).

- **It CANNOT rebuild the call/effect graph — the headline features:**
  - `definition` returns **null** for cross-module repo calls (`agent_loop_v2` →
    `stub_step.dispatch_step`, 3/3); only stdlib + same-file resolve.
  - `references` is **identifier-text match** (`Ok` → 11 hits across same-named
    symbols), **close-world** (opened docs only; `httpGet` → 1 hit, `std/net` not
    open), must sit on a *usage* not a decl, and gives **no enclosing-function**
    attribution. Weaker than the current source parser for `invokes`.
  - `documentSymbol` functions == source-parser set **exactly** (compaction: identical
    17 names), with **no body spans** (`range` = name token) and **no exported flag**.
  - `diagnostics` report relaxed-mode parse/typecheck errors — orthogonal to the iface
    `ok/partial/failed` classifier (`agent_loop_v2` is iface-`failed` yet has **0**
    diagnostics).

- **It DOES expose two things hydration-free that the pipeline gets weakly or not at
  all:**
  - **`hover` returns the full typed signature _with effect row_ for exported/stdlib
    symbols even in iface-unloadable modules** — `dispatch_step : (…) ! {AI[mode=fixed],
    IO}` from `agent_loop_v2`, `httpGet : string -> string ! {Net}`. (Internal funcs
    deferred; declarations null; it is a **Markdown string**, so effects must be
    text-parsed — the coupling ADR-002 removed.)
  - **`documentSymbol` ADTs + constructors structured** (`StepOutcome → Continue|Done|
    …`) — a clean hydration-free source for `types`/`ctors`.

- **Performance:** init 0.01s; open 24 core modules 0.01s (async); `documentSymbol`×24
  = 2.82s; vs source parser 0.12s, iface ~0.06s/module. Acceptable, but a
  references-based call graph (open all docs + one query/func + caller mapping) is far
  costlier and still approximate.

## Capability → artifact mapping

| LSP capability | Maps to | Verdict |
|---|---|---|
| `documentSymbol` (funcs) | `funcs` | No gain (identical set; no body span; no exported flag) |
| `documentSymbol` (ADTs+ctors) | `types`, `ctors` | Minor win — structured, hydration-free |
| `definition` | `invokes`/`imports`/`uses` | No — cross-module repo calls null |
| `references` | `invokes` | No — identifier-match, close-world, no caller attribution |
| `diagnostics` | `extraction_status` | No — different signal; doesn't see hydration failure |
| `hover` (exported/stdlib) | `funcs.type_sig`, `declared_effects`, `effects` | Candidate win — hydration-free incl. iface-unloadable modules; effect text-parsing cost |
| `hover` (stdlib usage) | `seed_catalog` per-symbol | Candidate win — per-symbol stdlib effects without the upstream FR; same caveat |
| `hover` (internal funcs) | internal types | No — deferred |

## Options considered

1. **Adopt now (replace/augment core extractor with LSP).** Rejected: the LSP cannot
   produce the call/effect graph, adds a long-lived server to a batch tool, and its one
   typed-layer gain only arrives as effect-strings that violate ADR-002's
   effects-from-array discipline.
2. **Defer / optional experiment (PROPOSED).** Status quo extractor unchanged; LSP
   kept as a researched, reproducible experiment; two enrichment wins recorded for a
   future flagged pass; precision upgrade stays with `--json`.
3. **Adopt only the enrichment wins now, behind a flag.** Viable but premature: both
   wins require committing to effect-string parsing and a close-world LSP session in the
   build; defer until the oracle-coverage delta is measured to justify it.

## Decision guardrails honored (from the handoff)

- No weakening of metadata discipline — nothing here changes the extractor; any future
  enrichment must carry `incomplete`/`approximate` and a `hover` provenance tag.
- Exact import extraction untouched (LSP gives no better import edges).
- `iface` typed/effect rows **not** replaced — LSP hover is a *string*, not the
  structured `effects` array; treated as enrichment only, never a substitute.
- Optional enrichment is preferred over a server dependency in the core extractor.
- Stated plainly: **LSP does not expose call edges; it cannot build the effect graph.**
  It is useful for typed-signature/effect enrichment and ADT/ctor symbols, not for the
  graph.

## Risks (if a future RFD adopts the enrichment wins)

- Markdown effect-string parsing reintroduces the textual-effect coupling ADR-002
  removed.
- Close-world references/symbols add a "must open all docs" failure mode.
- Long-lived process lifecycle + relax-modules semantics are an extra dependency
  surface that must re-validate per AILANG bump (extension `0.3.0` tracks the binary).

## Fallback

The status quo is fully intact and unweakened: source parser + `iface` +
`builtins --by-effect` needs no LSP and keeps all metadata discipline.

## Open questions (for the decision-maker)

1. Accept the proposed **Defer**, or greenlight the flagged enrichment pass now?
2. Is hydration-free **hover-backfill of `type_sig`/effects for iface-`failed`/
   `partial` modules** worth the effect-string parsing, given it directly attacks the
   oracle coverage gap (currently 74/108 `ok` exported funcs)? Decide after measuring
   the coverage delta on a prototype, or before?
3. Does **per-symbol stdlib effects via hover** change the priority of upstream ask (c)
   (machine-readable public-stdlib iface), or do we keep that FR as the clean fix and
   treat hover as a stopgap only?

## Proposed follow-up (if Defer is accepted)

- File a low-priority issue: "LSP hover enrichment for the code-graph typed layer" —
  prototype a flagged, post-`iface` pass that (1) backfills `type_sig`/effects for
  exported funcs in `failed`/`partial` modules and (2) fills per-symbol stdlib effects,
  both tagged `typed_source=hover` with parsed-effect caveats, measured against the
  oracle coverage delta before any ship decision.
- Keep both existing upstream asks unchanged: the LSP does not obsolete
  `ailang debug ast --json` (still the only path to a real call graph) and only
  partially overlaps the stdlib-effect FR.
```
