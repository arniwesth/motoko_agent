# Investigation: AILANG LSP as a source for `ailang-graph`

Date: 2026-06-30
Author: MOT-25 code-graph follow-up
Status: Research + light prototype. **No change to the shipping extractor.**
Pinned binary: **AILANG v0.26.0** (commit `3b52a24`)
Prototype: `lsp_probe.py`, `lsp_probe2.py`, `lsp_probe3.py` (minimal stdio JSON-RPC client)

## TL;DR

**Recommendation: keep as an optional enrichment experiment; do NOT adopt into the
core extractor now, and do NOT replace the call/effect graph with it. Defer the
headline upgrade to the existing `ailang debug ast --json` ask.**

The LSP is a real, working MVP, but its strengths and weaknesses are almost the mirror
image of what would let it replace the current extractor:

- It **cannot** recover the call graph or effect graph (the headline features):
  `textDocument/definition` does not resolve cross-module repo calls;
  `textDocument/references` is identifier-text matching, close-world (opened docs
  only), with no enclosing-function attribution. Both are weaker, not stronger, than
  the current source parser for `invokes`/`effect_edges`.
- It **does** expose two things the current extractor gets only weakly or not at all,
  both **hydration-free**: (1) `textDocument/hover` returns full typed signatures
  **with effect rows** for exported functions *even in modules `ailang iface` cannot
  load* (e.g. `agent_loop_v2.ail`); (2) `textDocument/documentSymbol` returns ADTs +
  constructors structured, hydration-free.

Two concrete, optional enrichment wins are worth a follow-up issue (below), but neither
justifies adding a long-lived server process to the batch extractor today, and both
would re-introduce string-parsing of effects that ADR-002 deliberately avoids.

---

## 1. Exact environment

```
$ ailang --version
AILANG v0.26.0
Commit: 3b52a24

$ ailang lsp --help
Usage of lsp:
  -stdio    Communicate over stdin/stdout (LSP standard) (default true)
  -verbose  Log to stderr
```

**Startup command used:** `ailang lsp --stdio --verbose`, cwd = repo root.

**Advertised server capabilities** (from `initialize`):

```json
{ "textDocumentSync": { "openClose": true, "change": 1, "save": {"includeText": true} },
  "hoverProvider": true, "definitionProvider": true,
  "referencesProvider": true, "documentSymbolProvider": true }
```

No completion, signature-help, semantic-tokens, rename, or workspace-symbol provider
(matches the doc's "MVP" scope). Init needs no special options; `rootUri` +
`workspaceFolders` accepted. File URIs are standard `file://` absolute paths.

**Workspace-root / module handling:** the server runs with `--relax-modules`
**automatically**. Every `didOpen` logged
`WARNING MOD010 (relaxed): module 'src/core/X' does not match canonical path …
mismatch ignored`. This is the key reason it can read modules `ailang iface` refuses
(see §8).

## 2. Document symbols — accurate, hydration-free, but no body spans, no exported flag

`textDocument/documentSymbol` returns a **flat** list (no `children` for functions;
ADTs *do* nest their constructors). Tested files:

| File | `iface` loads? | documentSymbol result |
|---|---|---|
| `version.ail` | yes | 1 symbol (`print_version`, kind 12) |
| `compaction.ail` | yes | 17 symbols, all kind 12 |
| `agent_loop_v2.ail` | **no (hydration)** | **78 symbols** — works fine |
| `types.ail` | yes | functions (kind 12) + ADTs (kind 5) with ctor children (kind 9) |

Findings:

- **Function set == current source parser, exactly.** For `compaction.ail`,
  documentSymbol functions and `source_parser.func_spans` produced the **identical
  17-name set** (symmetric diff empty). LSP includes internal functions
  (`elide_walk`, `count_tool_msgs`, …). No accuracy gain over the regex for `funcs`.
- **No body spans.** `range` == `selectionRange` == the **name token only** (e.g.
  `print_version` → line 12 char 12–25). LSP does **not** give function end-of-body
  extents, so it cannot improve `source_chunks` chunking, where the current parser's
  next-top-level heuristic is what matters.
- **No exported/internal signal.** Exported `print_version` and internal `elide_walk`
  are both `kind:12` with no `detail`/`tags`. The current `funcs.exported` (source-
  derived `export` keyword) remains the only source of that bit.
- **ADTs + constructors are structured and hydration-free** — the one real symbol win.
  `types.ail` → `StepOutcome` (kind 5 Class) with children `Continue, Done,
  LimitReached, ParseFailed, Aborted` (kind 9), `ToolCallReq` → `ReadFile … RunTests`,
  etc. This is the `types`/`ctors` data, with parent-type linkage and exact positions,
  **without** the hydration `iface` ctors require. (`source_parser.parse_source_ctors`
  already gets these via regex; LSP is a cleaner source for the same rows.)

## 3. Definition & references — cannot rebuild the call graph

`textDocument/definition`:

| Position | Result |
|---|---|
| `httpGet(` call site (backend) | ✅ jumps to `std/net.ail:54` (stdlib) |
| `try_emergency_compaction_with_limit(` **same-file** call (compaction) | ✅ resolves to its decl `compaction.ail:108` |
| `dispatch_step(` **cross-module** call (agent_loop_v2 → stub_step) | ❌ **null** (3/3 retries) |

→ **Definition does not resolve cross-module repo calls** — exactly the edges the
`invokes` graph is built from. Useless for cross-module call recovery.

`textDocument/references` (the more capable of the two, but still unsuitable):

- **Must be positioned on a _usage_, not the declaration.** On a decl position it
  returns `null`; on a usage it works. (Quirk worth recording.)
- **Cross-file across _opened_ documents.** `dispatch_step` usage → returned both the
  call in `agent_loop_v2.ail:1202` and the decl in `stub_step.ail:110`.
- **Close-world.** `httpGet` usage → 1 result (only `backend.ail`); `std/net.ail` was
  not opened, so its users/decl are invisible. A repo-scale reference graph therefore
  requires opening **every** file (the docs confirm "workspace-wide reference scan" is
  out of MVP).
- **Identifier-text match, not type-resolved.** `Ok` constructor usage → 11 hits;
  it matches the bare identifier and will conflate same-named symbols across modules —
  the precise false-edge risk ADR-002 calls out for the call graph.
- **No enclosing-function attribution.** References give `(file, line)` of each use,
  but not *which function* contains the use. Mapping line→caller still needs the
  function spans documentSymbol doesn't provide.

Net: references could only produce an approximate, close-world, identifier-matched
edge set — **strictly weaker** than the current whole-program source parser, at a much
higher cost (open all docs + one query per symbol). Not a path to `invokes`.

## 4. Diagnostics — a different signal from `iface` classification

- All five well-formed modules (incl. `agent_loop_v2.ail`) → **0 diagnostics**.
- A deliberately broken module → **1 diagnostic**, `severity:1` (Error),
  `"module loading error: … parse errors"`.

So diagnostics report **parse/typecheck errors in relaxed mode**, which is orthogonal
to the `iface` `ok/partial/failed` classifier (that classifies hydration/iface-JSON
outcomes). Notably, `agent_loop_v2.ail` — `failed` under `iface` for lack of hydration —
is **clean** under the LSP. Diagnostics cannot replace the iface classifier, the
hydration check, or stale-cache detection; they answer a different question ("does this
file parse/typecheck in relaxed mode").

## 5. Hover — the genuinely interesting capability (typed sigs + effects, hydration-free)

`textDocument/hover` (Markdown), positioned on a **usage**:

| Hover target | Returned `value` |
|---|---|
| `println` (stdlib) | `println : string -> () ! {IO}` |
| `httpGet` (stdlib) | `httpGet : string -> string ! {Net}` |
| `dispatch_step` (exported, **in `agent_loop_v2` which `iface` can't load**) | full record type ending `… ! {AI[mode=fixed], IO}` |
| `try_emergency_compaction_with_limit` (**internal**) | `_local binding — type info for non-exported names is deferred to M-AILANG-LSP-LOCAL-TYPES_` |
| any symbol at its **declaration** | `null` |

Findings:

- **Hover exposes the full typed signature _with the effect row_ for exported / stdlib
  symbols, hydration-free.** `dispatch_step`'s effects `! {AI[mode=fixed], IO}` came
  from a module `iface` cannot load. This is the data `iface` provides — obtained
  without hydration — for exactly the modules where the typed layer is currently
  empty.
- **Internal functions are deferred** (no type) — same exports-only limitation as
  `iface`, so hover does not extend the typed layer to internal funcs.
- **It's a Markdown string, not a structured array.** To use the effects you must
  text-parse `! {…}` out of the type string — the exact thing ADR-002 forbids
  ("effects come from the `effects` array, full stop"). That is the cost of this win.

## 6. Stdlib / effect data — partially available, but via string parsing

Hover on a stdlib **usage** yields per-symbol effects directly:
`httpGet : string -> string ! {Net}`, `println : string -> () ! {IO}`. The current
`std_calls.csv` already records a `(from_slug, std_module, symbol)` row for every
stdlib call site, so one representative hover per distinct `(std_module, symbol)` could
produce the **per-symbol** stdlib effect map that the FLAG-1 upstream feature request
(`seed_catalog.py`) is waiting for — **hydration-free, today**.

Caveat: it is per-*used*-symbol (only stdlib functions the repo actually calls), and it
re-introduces effect-string parsing. So it is a *candidate* alternative to upstream
ask (c), not a clean replacement. The `builtins list --by-effect` module-granular seed
remains the robust, structured baseline.

## 7. Performance

| Operation | Time |
|---|---|
| LSP `initialize` | 0.01 s |
| `didOpen` all 24 core modules (async, fire-and-forget) | 0.01 s |
| settle (typecheck) | ~2 s |
| `documentSymbol` × 24 modules | **2.82 s** (24/24 ok, 443 symbols) |
| — current `source_parser.parse_all` (core) | **0.12 s** |
| — current `ailang iface` (1 module) | 0.06 s (≈1.4 s × 24) |

documentSymbol over core is ~20× slower than the source parser but small in absolute
terms (~5 s incl. settle). A references-based call graph would be far costlier: open
all files + one query per function (443) + enclosing-function post-processing — and
still approximate. Hover enrichment is one request per target symbol; bounded but
linear in the symbols you choose to enrich.

## 8. Robustness / hydration

- **The LSP does _not_ require hydration for the modules `iface` does.** It runs
  `--relax-modules` and typechecks in-session; `agent_loop_v2.ail` gave full symbols
  **and** a hover-derived typed signature with effects — the module `iface` cannot
  load at all. This is the LSP's standout robustness property.
- It **fails cleanly**: broken module → one Error diagnostic, server stays up; other
  open documents keep answering.
- Long-lived stateful process: must manage lifecycle, `didOpen` every file, wait for
  typecheck, and treat results as close-world over the opened set.

## 9. Capability → current artifact mapping

| LSP capability | Maps to | Verdict for `ailang-graph` |
|---|---|---|
| `documentSymbol` (functions) | `funcs` | **No gain** — identical set to source parser; no body span; no exported flag |
| `documentSymbol` (ADTs+ctors) | `types`, `ctors` | **Minor win** — structured, hydration-free (vs `iface` ctors needing hydration; vs regex ctors) |
| `definition` | `invokes`, `imports`, `uses` | **No** — cross-module repo calls return null; stdlib/same-file only |
| `references` | `invokes` | **No** — identifier-match, close-world, no caller attribution; weaker than source parser |
| `diagnostics` | `extraction_status` | **No** — parse/typecheck signal, orthogonal to iface classification; doesn't see hydration failure |
| `hover` (exported/stdlib) | `funcs.type_sig`, `funcs.declared_effects`, `effects` | **Candidate win** — typed sig + effects **hydration-free, incl. iface-unloadable modules**; but Markdown string ⇒ effect text-parsing |
| `hover` (stdlib usage) | `seed_catalog` per-symbol effects | **Candidate win** — per-symbol stdlib effects without the upstream FR; same text-parsing caveat |
| `hover` (internal funcs) | internal func types | **No** — deferred ("non-exported names") |

## 10. Recommendation, risks, fallback

**Recommendation: keep as an optional, isolated experiment (this folder). Do not wire
LSP into `extract.sh` or the core extractor now. Defer the call/effect-graph precision
upgrade to the already-filed `ailang debug ast --json` request — the LSP does not
deliver it.**

Rationale: the headline value (call graph, effect reachability) is precisely what the
LSP cannot provide, and what it adds (symbols, typed sigs) is either already covered or
available only as effect-strings that violate the ADR's effects-from-array discipline.
Adding a long-lived server to a deliberately batch/CLI extractor is not justified by a
symbol set we already have and a typed layer we can only get by string-parsing.

**Two enrichment wins worth a scoped follow-up issue (optional, additive, behind a
flag — never replacing the structured `iface`/source paths):**

1. **Hover-backfill of the typed layer for `iface`-`failed`/`partial` modules.** For
   exported funcs in modules `iface` cannot hydrate, hover yields `type_sig` +
   effects hydration-free — directly attacking the oracle coverage gap
   (currently 74/108 `ok` exported funcs). Encode as a distinct provenance
   (`typed_source = hover`) and keep `incomplete`/`approximate` metadata; the effect
   text-parse is the explicit cost to weigh.
2. **Per-symbol stdlib effects via hover** as an alternative path to the FLAG-1
   precision upgrade, keeping `SEED_GRANULARITY` discipline (module-granular stays the
   baseline; hover fills `symbol_effects`).

**Risks:** (a) Markdown effect-string parsing re-introduces the textual-effect coupling
ADR-002 removed; (b) close-world references/symbols add a "must open all docs" failure
mode; (c) long-lived process lifecycle + the relax-modules semantics are an extra
dependency surface; (d) MVP capability set may shift between binary releases (extension
`0.3.0`), so any adoption must re-validate per AILANG bump like the `iface` pass does.

**Fallback (the status quo) is fully intact:** the source parser + `iface` +
`builtins --by-effect` pipeline needs no LSP and keeps all metadata discipline. Nothing
here weakens it.

## 11. Proposed follow-up

- **Issue (optional, low priority):** "LSP hover enrichment for the code-graph typed
  layer" — prototype a flagged, post-`iface` enrichment pass that (1) backfills
  `type_sig`/effects for exported funcs in `failed`/`partial` modules and (2) fills
  per-symbol stdlib effects, both tagged with `hover` provenance and parsed-effect
  caveats, measured against the oracle coverage delta before deciding to ship.
- **Keep the existing upstream asks unchanged.** The LSP does not obsolete the
  `ailang debug ast --json` request (still the only path to a real call graph) and only
  partially overlaps the stdlib-effect FR (the structured `builtins`-based ask is still
  the clean fix).
```
