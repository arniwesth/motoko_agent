# motoko_agent post-cutover roadmap (2026-05-06)

**Status**: Active planning
**Owner**: motoko_agent team
**Last updated**: 2026-05-06 (post v0.16.1 cutover)

---

## Context

The [M-MOTOKO-RPC-LOOP-FULL-MIGRATION](m-motoko-rpc-loop-full-migration.md) sprint completed (PR #4 ready for review). motoko_agent now runs on stock upstream AILANG v0.16.1 with no parser or AI-provider patches; the `arniwesth/ailang@motoko` fork is retirement-ready.

This roadmap captures **everything that didn't ship in v0.16.x but should land in some order** — both motoko-side work and AILANG-side work that motoko depends on. It's the answer to "what's next?".

The document is organised by **producer**: motoko-side work that we do ourselves, and AILANG-side work that we wait for upstream and then consume.

---

## motoko-side follow-ups (we author these)

| Priority | Sprint | Effort | When | Doc |
|---|---|---|---|---|
| **P2** | Workdir-vs-cwd resolution | 2-3h | Next post-cutover patch | [m-motoko-workdir-cwd-resolution.md](m-motoko-workdir-cwd-resolution.md) |
| **P2** | M6.5 ohmy_pi delegation channel | 1-2d | When motoko deploys to Pi | [m-motoko-m65-ohmy-pi-delegation.md](m-motoko-m65-ohmy-pi-delegation.md) |
| **P3** | AG-UI protocol adoption | 5-7d | When motoko's product strategy benefits from external UI interop | [m-motoko-agui.md](m-motoko-agui.md) |

### Recommended sequence

1. **Workdir-vs-cwd first.** Smallest, most user-visible, observed during M9 testing. ~2-3h so it should ship as a focused patch immediately after PR #4 lands. No external dependencies. **Action: file as a focused commit in the post-cutover patch series.**

2. **AG-UI second** (subject to product question). The AG-UI sprint has a "stage 1: parallel emission" phase that's purely additive (emits both bespoke + AG-UI shapes alongside) — that stage can land independently of any product decision. The big call is when to drop the legacy emission. **Action: the design doc has a "Open questions for arni" section that should be answered before scheduling.**

3. **M6.5 ohmy_pi third** (deployment-driven). Only triggered when motoko gets deployed to a Pi/env-server in production. Until then the M6 lean handles every standalone-mode case fine. **Action: park until deployment timeline firms up.**

---

## AILANG-side follow-ups motoko benefits from (upstream authors these)

These are filed in the AILANG repo's `design_docs/planned/`. motoko picks them up automatically by bumping the AILANG version constraint in `ailang.toml`.

| Priority | Sprint | Target version | Status | Doc |
|---|---|---|---|---|
| **P1** | M-EXTERNAL-CONSUMER-DX | v0.17.0 | Planned | [ailang/design_docs/planned/v0_17_0/m-external-consumer-dx.md](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/v0_17_0/m-external-consumer-dx.md) |
| **P2** | M-AI-OPENAI-LOCAL-ENDPOINT-RELAX | v0.17.0 (or v0.16.x patch) | Planned | [ailang/design_docs/planned/v0_17_0/m-ai-openai-local-endpoint-relax.md](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/v0_17_0/m-ai-openai-local-endpoint-relax.md) |

### What M-EXTERNAL-CONSUMER-DX gives motoko

Four DX fixes targeted at exactly the surfaces motoko hits, sourced directly from `motoko_agent/.agent/learnings/`:

1. **`MOD012` module_prefix overlap diagnostic** — fixes the silent-misroute issue captured in [`2026-05-03-motoko-core-package-sync.md`](../../.agent/learnings/2026-05-03-motoko-core-package-sync.md). Today motoko fixed it by removing the `motoko_core` dep from root; with `MOD012` the compiler will *say* what's wrong.
2. **Effect-row mismatch with call-site pointer** — the "you're missing `! {FS}` somewhere in this body" error currently doesn't say WHICH call. Cited in [`ailang_csp_implementation.md`](../../.agent/learnings/ailang_csp_implementation.md) rule #4 as the dominant friction point.
3. **`error_codes.json` release artifact** — machine-readable error code table. Unlocks motoko's planned hint-table extension that's currently waiting on a stable upstream artifact (research doc: [`AILANG_performance_evidence_gates.md`](../../.agent/research/AILANG_performance_evidence_gates.md) lever 4).
4. **(Stretch) `ailang.ebnf` release artifact** — versioned grammar file. Unlocks grammar-constrained decoding (xgrammar/llguidance) for AILANG-targeting models — directly relevant to motoko's TM-fine-tuning research arc.

### What M-AI-OPENAI-LOCAL-ENDPOINT-RELAX gives motoko

Restores the local-OpenAI-endpoint-without-API-key support that motoko's fork had ([`2026-05-03-local-openai-endpoint-key-relaxation.md`](../../.agent/learnings/2026-05-03-local-openai-endpoint-key-relaxation.md)) but was lost during the v0.16.x fork retirement. Required for motoko's local-DGX deployment (`OPENAI_BASE_URL=http://100.79.48.75:8000/v1` against an unauthenticated vLLM/TGI server).

---

## What's already shipped (closed loops)

For the audit trail — these were motoko-surfaced pains that have been resolved:

| Pain | Source | Shipped in |
|---|---|---|
| `WriteFile` runtime panic on missing parent dir | M-MOTOKO-RPC-LOOP-FULL-MIGRATION M10b live testing | AILANG v0.16.0 (M-AILANG-FS-RESULT) + motoko commit `be10cab` |
| OpenAI `gpt-5` rejected `max_tokens` | M9 provider matrix | AILANG v0.16.0 |
| Gemini `GOOGLE_CLOUD_LOCATION` env not honored | M9 provider matrix | AILANG v0.16.1 |
| Gemini safety-block returned cryptic "no candidates" | M-AI-TOOL-LOOP M3 work | AILANG v0.16.1 |
| `gemini-3-flash-preview` model alias missing | M9 provider matrix | AILANG v0.16.1 |
| `MOTOKO_AGENT_V2` env-gate confusion | M-MOTOKO-RPC-LOOP-FULL-MIGRATION M10a | motoko cutover PR #4 |
| Bash command with shell tokens / spaces failed | M-MOTOKO-RPC-LOOP-FULL-MIGRATION M10 live testing | motoko commit `966778e` (bash -lc wrapping) |
| Streaming migration boilerplate | M-AI-CALL-STREAM-HELPER (AILANG v0.15.1) | motoko PR #3 |
| Tool-loop dispatch boilerplate | M-AI-TOOL-LOOP (AILANG v0.17.0 work) | motoko PR #4 |
| `[λ] motoko` terminal title (vs `bun.exe`) | UX polish | motoko commits `0944f96` + `e670744` + `d80e3ec` |

---

## Open pains NOT yet filed

Two motoko-internal items that aren't AILANG-blocking and aren't currently scheduled:

1. **EditFile under-selection** — the model rationally avoids `EditFile` because of the read-before-edit policy and strict-matching semantics. Captured in [`2026-04-21-editfile-selection-regression.md`](../../.agent/learnings/2026-04-21-editfile-selection-regression.md). Fixable by either (a) updating the system prompt to document the read-before-edit contract explicitly, or (b) relaxing the runtime policy to allow EditFile without a same-batch ReadFile when the file is already in the model's prior context. Worth a small dedicated sprint when motoko's model-behaviour metrics suggest EditFile usage is below the desired rate.

2. **Discovery First / `ailang docs` for sub-module exports** — captured in [`ailang_csp_implementation.md`](../../.agent/learnings/ailang_csp_implementation.md) rule #1. The pain: types like `StreamEvent` live in sub-modules and aren't visible from the parent module's `ailang docs` output without explicitly drilling in. Already addressed by the recent `ailang docs search` improvements (neural + SimHash). No further action needed unless concrete cases keep surfacing.

---

## Sequence summary (the answer to "what's next?")

```
TODAY (2026-05-06):
  ✅ AILANG v0.16.1 released
  ✅ motoko PR #4 ready for review (full M3-M10 migration)
  ✅ motoko PR #3 cross-linked, descriptions current

NEXT MOTOKO-SIDE PATCH (after PR #4 merges):
  → m-motoko-workdir-cwd-resolution (P2, ~2-3h)

NEXT AILANG-SIDE WORK (currently planned for v0.17.0):
  → M-EXTERNAL-CONSUMER-DX (P1, 14-18h) — 4 motoko-surfaced DX gaps
  → M-AI-OPENAI-LOCAL-ENDPOINT-RELAX (P2, 30min) — local-DGX support

WHEN MOTOKO DEPLOYS TO PI:
  → m-motoko-m65-ohmy-pi-delegation (P2, 1-2d)

OPPORTUNISTIC (product strategy decision needed):
  → m-motoko-agui (P3, 5-7d) — external UI interop

PARK / WATCH:
  → EditFile under-selection (motoko-internal, behaviour-driven)
  → Discovery First (already addressed by ailang docs search neural)
```

The cross-cutting story is that **AILANG v0.17.0 is the next high-value release for motoko** — it bundles the four M-EXTERNAL-CONSUMER-DX items + the OpenAI local-endpoint fix, both of which directly attack pains motoko documented in `.agent/learnings/`. Once v0.17.0 ships, motoko bumps `ailang.toml` to `>=0.17.0` and picks them all up at once.

In the meantime motoko's own backlog (workdir / M6.5 / AG-UI) is small + manageable + each item is independently shippable.
