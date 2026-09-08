# RESEARCH: How should Motoko continuously adopt new AILANG features?

Date: 2026-08-13
Status: Research — **opening draft**. §1–§7 are evidence-backed; §8–§9 are open threads, not conclusions.
Pinned binary: AILANG **v0.33.0** (commit `ae36986`, built 2026-08-10)
Toolchain: `ailang.toml` → `ailang = ">=0.33.0"`; `ailang.lock` → `v0.33.0` (generated 2026-08-09)
Surface under discussion: 150 `.ail` files / 48,961 lines across `src/` + `packages/`
Relates to:
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md` (what the acceptance oracle is)
- `design_docs/planned/m-motoko-verify-ail.md`, `design_docs/planned/m-motoko-extensions-as-packages.md` (the two existing prose-form registry entries)
- `CHANGELOG.md` § M-MOTOKO-EVAL-INSTRUMENTATION → "Deferred to v1.1" (a third, in a different format)
- `ailang-feedback` skill; AILANG docs MCP (`https://mcp.ailang.sunholo.com/mcp/`)

---

## TL;DR

Motoko has tracked AILANG from ~v0.11 to v0.33 — 20+ minor versions of a language moving under a
49-kloc codebase. The question is how to make that tracking **continuous and mostly mechanical**
instead of episodic and manual.

Four findings shape the answer:

1. **The mechanism should be pull-driven, not push-driven.** Scanning each new changelog for
   "features we could use" over 49 kloc is expensive, false-positive-heavy, and generates churn.
   The cheap direction is the inverse: Motoko already knows **where it is compromised and by which
   missing AILANG capability**. Adoption is then a *join* (registered debt × changelog delta), not
   a search.

2. **The registry already exists — in prose.** `design_docs/planned/` has a hand-written
   convention for exactly this: a `**Status**: Planned — blocked on AILANG …` line plus a
   `## Prerequisite` section naming the gap, a **Capability check**, and a **Mitigation**. Two docs
   use it. Nothing consumes it.

3. **It is already stale, and that is the proof of need.** `m-motoko-extensions-as-packages.md`
   still reads *"Planned — blocked on AILANG capability gap"*. The capability
   (`ailang generate-extension-registry`) **shipped**, Motoko **adopted it**, and
   `src/core/ext/registry_generated.ail` is on disk. Nobody closed the loop. (§4)

4. **AILANG already ships upgrade-coordination primitives Motoko isn't using** — `ailang iface`,
   `interface_hash` in the lockfile, `pkg notify-upgrade`, `pkg affected-by`, `replay`. The
   detection half of this problem is closer to solved than it looks. (§7)

The hard part is not detection. It is (a) a **trigger vocabulary** that doesn't produce false
negatives (§5), and (b) an **acceptance oracle** strong enough to let a change land unattended (§6).

---

## 1. The problem, stated precisely

"Adopt new AILANG features as they become available" is two different jobs wearing one sentence:

| | Push-driven | Pull-driven |
|---|---|---|
| Question | "What did v0.34 add that we could use?" | "Which of our known compromises did v0.34 unblock?" |
| Input | changelog delta (unbounded) | registry of registered debt (~dozens) |
| Search space | 49 kloc | the sites named by each entry |
| False positives | high — novelty ≠ value | near zero |
| Failure mode | churn; regression risk spent on rewrites nobody asked for | misses genuinely new capability nobody pre-registered |
| Automatable | no | largely yes |

Both jobs are real. The claim is that they need **different machinery and different trust levels**,
and conflating them is what makes "keep up with AILANG" feel unbounded. Pull-driven adoption can be
routine and frequent. Push-driven discovery is a periodic human-in-the-loop review, and its output
should be a *proposal*, never a PR.

---

## 2. Feed inventory — what's on hand today

| Feed | Location | Machine-readable | Notes |
|---|---|---|---|
| AILANG changelog | `ailang/CHANGELOG.md`, `ailang/changelogs/v0.18-current.md` | Markdown, sectioned | **Local checkout is the most complete feed.** But `ailang/` is **gitignored** (`.gitignore:16`) — see §8.1 |
| AILANG design docs | `ailang/design_docs/{planned,implemented}/` | Markdown | Gives *intent* ahead of release — lets a registry entry name a capability before it exists |
| Per-version changelog | MCP `changelog_for_version` | JSON | **Sparse** — see §2.1 |
| Known limitations | MCP `limitations_list` | JSON | Version-keyed; see §2.1 |
| CLI surface | `ailang --help`, `ailang builtins list`, `ailang docs --list` | text / listable | Direct capability probe — what §3's "capability check" steps actually want |
| Module interfaces | `ailang iface <module>` → normalized JSON | JSON | Underused; see §7 |
| Version pin | `ailang.toml` (`>=0.33.0`), `ailang.lock` (`ailang_version`, per-package `interface_hash` + `content_hash`) | JSON | Lock already records interface hashes |
| Motoko's own debt | 3 `.ail` comments, 2 design docs, 1 CHANGELOG entry (§3) | **no** | The gap this note is about |
| Acceptance oracle | `make check_core`, `verify_extensions`, `test_core`, `dst`, `strict_replay`, `conformance`, `effect_inventory` | exit codes | The reason automation is safe at all (§6) |
| Upstream channel | `ailang-feedback` skill, MCP `submit_feedback`, `ailang messages send` | — | The other end of the loop (§8.4) |

### 2.1 The MCP version feed has holes — it cannot be the sole detector

`mcp__ailang-docs__ailang_versions` returns 51 versions, but jumps **0.16.4 → 0.33.0**. Every
version in between — including the v0.18/v0.21/v0.26 releases that Motoko demonstrably migrated
across, per the version strings embedded in `src/core/ai_compat.ail` and `src/core/types.ail` — is
absent — including every release Motoko demonstrably migrated across, per the version strings
embedded in the source: `v0.17.0` (`tool_catalog.ail:4`, `tool_dispatch_adapter.ail:3`), `v0.18.x`
(`session.ail:1232`, `test/stub_step.ail:143,633`, `motoko-ext-omnigraph/omnigraph.ail:42`),
`v0.19.0` (`motoko-ext-mcp/assets.ail:3`), `v0.21.1` (`motoko-ext-ai-compat/ai_compat.ail:157`),
`v0.26.0` (`ports.ail:2546`, `session.ail:793`). And `limitations_list` for `v0.33.0` returns:

```json
{ "error": "unknown_version", "nearest": "latest", "requested": "v0.33.0" }
```

(`0.33.0` without the `v` is in the list; `v0.33.0` is not. Unclear whether this is a prefix-parsing
bug or genuinely distinct keys — **worth filing via `ailang-feedback` either way**.)

**Implication:** treat the MCP as an *enrichment* feed, not the detection trigger. The local
`ailang/CHANGELOG.md` + the CLI surface are the authoritative signals; the MCP adds structure when
it happens to have the version.

---

## 3. Finding: the registry already exists, written by hand, in prose

`design_docs/planned/m-motoko-verify-ail.md` and `m-motoko-extensions-as-packages.md` independently
converged on the same four-part shape:

```markdown
**Status**: Planned — blocked on AILANG `ailang verify <file.ail>` runtime mode (see Prerequisite)
**Dependencies**: AILANG `ailang verify <module.ail>` as an agent-invocable runner; ...

## Prerequisite: AILANG `ailang verify <verify.ail>` runner

**Capability check** (to perform before starting motoko-side work):
- Does `ailang verify <file.ail>` exist as a CLI subcommand?
- If not, is it in the AILANG roadmap (`design_docs/planned/v0_17_0/` or later)?
- Can the motoko-side `verify.ail` modules work today using `ailang run` with a structured exit code?

**Mitigation if not available**: implement `verify.ail` modules as standard `ailang run` programs ...
```

That is a registry entry: **blocked-status + named capability + an executable capability check +
a fallback**. `m-motoko-extensions-as-packages.md` adds a fifth useful field — evidence of *how* the
gap was confirmed ("`ModuleLoader.Load()` resolves paths statically; there is no
`import_symbol(pkg_name, symbol_name)` builtin; `ImportDecl` AST nodes contain fixed string paths
only").

Three properties make this the right thing to build on rather than replace:

- **It is already the team's habit.** No new discipline to introduce — only formalisation.
- **The capability check is already written as a runnable question.** "Does `ailang verify` exist as
  a CLI subcommand?" is one `ailang --help | grep` away from being a trigger predicate.
- **The mitigation is already recorded**, so the entry documents both the current shim *and* the
  target state — which is exactly what a retirement diff needs.

What's missing is only that (a) the format is prose, so nothing can join it against a changelog, and
(b) the debt is scattered across three incompatible carriers:

| Carrier | Count | Example |
|---|---|---|
| `design_docs/planned/**` status + Prerequisite | 2 | `m-motoko-verify-ail.md`, `m-motoko-extensions-as-packages.md` |
| `.ail` source comments | 4 sites | `src/core/ai_compat.ail:149` (`M-IFACE-NESTED-EFFECTS` effect-row inference bug) — **duplicated verbatim at `packages/motoko-ext-ai-compat/ai_compat.ail:149`**; `dst_driver_plus_compose.ail:296` + `dst_driver_plus_no_ops.ail:324` ("AILANG cannot read the ABI's effect rows"); `packages/motoko-ext-abi/types.ail:836` |
| `CHANGELOG.md` "Deferred" prose | 1 | "Cache token plumbing … `std/ai.step` doesn't surface upstream cache-token data today; **will land when AILANG-side support arrives**" |

Seven entries, in three formats, none machine-joinable. That is small enough to migrate by hand in
an afternoon — an argument for doing it now, before it's seventy.

The duplicated `ai_compat.ail:149` comment is instructive: one debt, two retirement sites, and
nothing links them. A registry entry has to carry the **full site list**, or retiring a shim leaves
a copy behind that keeps working around a bug that no longer exists.

---

## 4. Finding: the registry is already stale — and that's the load-bearing evidence

`design_docs/planned/m-motoko-extensions-as-packages.md` currently reads:

> **Status**: Planned — blocked on AILANG capability gap (see Prerequisite)
> …
> **This blocks the "fully dynamic" registry design** …
> ### Mitigation: static-dispatch code generation
> 2. **Generation phase**: a build step (new `ailang generate-extension-registry` command or
>    Makefile target) reads `ailang.toml` and writes `src/core/ext/registry_generated.ail` …

Verified against the current tree and binary:

| Claim in doc | Reality on v0.33.0 |
|---|---|
| `ailang generate-extension-registry` is hypothetical ("new … command") | **Ships.** `ailang --help` → `generate-extension-registry  Emit static extension dispatch file from [extensions]` |
| `[extensions] packages = [...]` in `ailang.toml` is a proposal | **Live.** `ailang.toml` declares 15 extension packages plus `config_import` / `hooks_import` / `registry_import` / `output` |
| `src/core/ext/registry_generated.ail` would be written by that step | **Exists.** 3,962 bytes, mtime 2026-08-11 |
| Status: "blocked on AILANG capability gap" | **Unblocked, adopted, shipped** — status never updated |

So the mitigation didn't just become unnecessary; **the full proposal landed** and the doc that
tracks it never noticed. The doc lifecycle corroborates this: `design_docs/planned/` holds 24 files,
`design_docs/implemented/` holds **1**.

This is the failure mode in its pure form. It isn't that Motoko fails to adopt AILANG features —
it adopted this one. It's that **nothing closes the loop**, so the record of what Motoko is waiting
on decays into fiction, and the next reader budgets "+2 days for the AILANG-side prerequisite" that
was delivered several versions ago.

**A registry that isn't mechanically re-evaluated is worse than no registry**, because it is
confidently wrong. Whatever gets built here, the *first* job is a `stale-blocked` check: for every
entry claiming to be blocked, re-run its capability check and fail loudly when it now passes.

---

## 5. Trigger design: exact-name predicates produce false negatives

`m-motoko-verify-ail.md` asks: *"Does `ailang verify <file.ail>` exist as a CLI subcommand?"*

Run against v0.33.0, that predicate answers **no**. But the help output shows:

```
ai-check <file>      Unified check+verify JSON output (for AI)
replay <trace.jsonl> Replay and verify against recorded trace
```

`ai-check` is "check+verify, JSON output, *for AI*" — which addresses three of the five weaknesses
the doc lists (not type-checked → compiler-backed; no structured output → JSON; outside AILANG
provenance → in-toolchain). It may or may not satisfy the design's intent; that needs a real spike.
But a name-equality trigger would have silently answered "still blocked" while a partial answer sat
in the help text.

Working conclusion — a trigger needs **two** predicates:

- **`fires_when`** — a cheap, exact, high-precision check. Grep the CLI surface, `builtins list`,
  `iface` output, changelog headings for a specific symbol. Cheap enough to run on every version
  bump; when it fires, confidence is high.
- **`review_when`** — a fuzzy semantic check for the *capability*, not the name. This is where the
  docs MCP and an LLM read of the changelog delta earn their cost. Fires rarely, produces a
  human-facing note ("`ai-check` may partially satisfy M-MOTOKO-VERIFY-AIL — spike needed"), never
  a code change.

The asymmetry matters: `fires_when` may auto-open work; `review_when` may only ever raise a
question. Without the second predicate the registry drifts toward stale-blocked (§4) whenever
AILANG solves a problem under a different name — which, given a language moving 20 minor versions,
is the normal case, not the exception.

---

## 6. Three tiers of adoption, three different oracles

The safety property is that the tier is **decidable from the registry entry**, not from an agent's
in-the-moment judgment.

| Tier | What it is | Oracle | Automation |
|---|---|---|---|
| **0 — Mechanical** | Deprecated/renamed stdlib symbols, effect-row syntax, signature changes. The compiler names the site. | `make check_core` + `verify_extensions` is *complete* — if it compiles and hashes match, it's done | Full. Auto-PR. |
| **1 — Debt retirement** | Delete a shim because upstream now does it natively (e.g. `ai_compat.ail`'s effect-row workaround, once the inference bug is fixed) | **Behaviour-preserving by construction** → `make strict_replay` at fixed seed is an exact oracle: identical trace, or reject. Plus `dst`, `conformance`, `effect_inventory` | Full, gated on trace equality. Highest value. |
| **2 — Architectural** | New effects, CSP/session types, capabilities that change design | None. There is no oracle for "should we restructure around this" | **Proposal only.** Never a PR. |

Tier 1 is the sweet spot and it's worth being explicit about why: shim removal is the one class of
change where "correct" has a *mechanical* definition. The shim exists to reproduce a behaviour
AILANG couldn't provide; if removing it changes the observable trace, either the shim was doing
more than documented or the new capability isn't equivalent — and both are exactly the cases that
should block. This repo's DST investment is what makes that oracle available, which is the
non-obvious reason this whole idea is tractable here and wouldn't be in a typical codebase.

Open: whether `strict_replay` trace equality is *actually* tight enough (does it capture effect
ordering? token accounting? see project 011). Needs verification before anything auto-lands.

---

## 7. AILANG-native machinery Motoko isn't using yet

v0.33.0 ships several primitives that look purpose-built for this loop:

- **`ailang iface <module>` → normalized JSON interface.** Combined with the `interface_hash` /
  `content_hash` already recorded per-package in `ailang.lock`, this gives a **mechanical
  breaking-change detector** across a version bump — diff the interface, don't diff the prose. This
  is probably the single highest-leverage unused primitive here.
- **`ailang pkg notify-upgrade <pkg>@<ver>`** — *"Compares current lockfile state with the published
  version to determine interface hash changes and change class."* AILANG has already built the
  detection half, including a notion of **change class**.
- **`ailang pkg affected-by <pkg>`** — lists workspaces depending on a package. With 15 first-party
  extension packages in `ailang.toml`, this is the blast-radius query for any core change.
- **`ailang replay <trace.jsonl>`** — replay-and-verify against a recorded trace, i.e. a
  toolchain-native version of the Tier 1 oracle.
- **`ailang messages send <inbox>`** — the transport the motoko-explore inbox already uses
  (`m-motoko-verify-ail.md` cites source msg `5481bdc0`; extensions-as-packages cites `046df945`).
  Both existing registry entries *arrived by message*. That's the natural intake path.

Not yet verified: whether `notify-upgrade`'s "change class" taxonomy maps onto the Tier 0/1/2 split
above; whether `iface` covers effect rows (relevant to the three `.ail` debts, all of which are
effect-row problems).

---

## 8. Open threads

### 8.1 `ailang/` is gitignored — provenance is thin
`.gitignore:16` ignores `/ailang/`. The compiler Motoko builds against is **ambient**; the only
in-repo record is `ailang.lock`'s `ailang_version` field. For a loop that must attribute *"this
regressed at v0.34"* or reconstruct *"what did the changelog say when we retired this shim"*, that's
weak. Options: pin a commit in `ailang.toml`; snapshot the relevant changelog delta into the
registry entry at retirement time; or vendor `ailang/changelogs/` only. **Undecided.**

### 8.2 The ratchet
Rejected adoptions must stay rejected, with a reason and a version stamp, or every run re-proposes
them. Symmetrical to §4's stale-blocked problem: a `rejected` entry needs re-evaluation triggers
too (rejected *because* of X — does X still hold?), or it becomes its own species of fiction.

### 8.3 Where does the registry live?
Candidates: frontmatter on `design_docs/**` (preserves the existing habit, §3); a single
`ailang-debt.toml`; or generated from structured `.ail` comments. Trade-off is between "one file an
agent can join in one read" and "the fact lives next to the code it constrains". Leaning toward
frontmatter + a generated index, but unresolved.

### 8.4 Closing the loop with `ailang-feedback`
The genuinely novel structure: filing an upstream limitation and registering the future adoption are
**the same act**. Hit a gap → `ailang-feedback` files it → the same action writes a registry entry
with a `fires_when` trigger → AILANG ships it → trigger fires → shim retires under the Tier 1
oracle. Motoko's debt registry *is* its upstream feature-request queue, viewed from the other end.
Both existing entries came in via `ailang messages` (§7), so the intake path exists.

### 8.5 Cadence and trust
Unresolved: what invokes the loop (version-bump hook? cron? `make`-time check?), what it may touch
without approval, and whether Tier 0/1 auto-PRs or auto-merges on green.

---

## 9. Not yet researched

- Whether `strict_replay` trace equality is tight enough to be the Tier 1 gate (§6) — **blocking**
  for any auto-landing change; overlaps project 011.
- Whether the `M-IFACE-NESTED-EFFECTS` effect-row inference bug (`ai_compat.ail:149`) is fixed in
  v0.33.0 — the most valuable single debt to test the mechanism against, since it has a shim, a
  named upstream ticket, and a mechanical oracle.
- Whether `std/ai.step` now surfaces cache tokens (`CHANGELOG.md` deferred item) — a second live
  test case, and one where the trigger is a *field on a return type*, not a CLI symbol. Would
  exercise `ailang iface` as the trigger substrate.
- `ailang pkg notify-upgrade` change-class taxonomy vs. the Tier 0/1/2 split.
- Cost of a `review_when` pass: how many tokens to LLM-read a version delta against ~30 registry
  entries, and how often it's worth paying.
