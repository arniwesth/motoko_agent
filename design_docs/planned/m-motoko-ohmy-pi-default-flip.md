# M-MOTOKO-OHMY-PI-DEFAULT-FLIP — flip `ohmy_pi` to false until delegation lands

**Status**: Planned
**Target**: motoko_agent (next patch on motoko-bisect-gap1)
**Priority**: P0 (every motoko BashExec attempt currently wastes 25-33% of tool calls)
**Estimated**: ~1 hour, ~50 LOC across 4 config files + 1 startup guard + 1 regression smoke
**Dependencies**: None. M-MOTOKO-M6.5-OHMY-PI-DELEGATION (the proper wire-up) remains a separate planned doc.
**Surfaced by**: motoko_explore agent — bug report msg `7a95e4e8` (2026-05-08), with A/B repro proving 15× slower runs and 6× higher output-token cost when `ohmy_pi: true`

---

## Problem

The shipping config profiles (`default`, `dogfood`, `local`, `openrouter`) all set `tools.ohmy_pi: true + tools.hybrid: true`. With `MOTOKO_AGENT_V2=1` (the default since the v2 cutover), `agent_loop_v2`'s `split_by_backend` routes BashExec to the **Delegated** backend. The Delegated backend's inbox-based wait pipeline was deleted at M10b (~600 LOC) because it was unreachable in v2 standalone mode — the M6 lean fallback ships a structured `delegated_backend_not_wired:true` error in its place. The replacement was always known to be incomplete (Gate 3 option (b)), and the proper wire-up is tracked in [m-motoko-m65-ohmy-pi-delegation.md](m-motoko-m65-ohmy-pi-delegation.md).

Until M6.5 lands, `ohmy_pi: true` is a **structural no-op** that wastes tokens. Every BashExec call:
1. Hits `dispatch_calls` → `backend_for_v2` → returns `Delegated`
2. Returns the `delegated_deferred_message` envelope as a tool-role Message
3. The model sees a tool failure, retries 1-3 times
4. In hybrid mode, falls back to extracting bash from prose — same broken path
5. Eventually gives up and emits prose like "I'm unable to execute scripts due to system limitations"
6. The loop continues for ~10-13 more steps with no formal `done`

### Direct evidence

motoko_explore's A/B repro (msg `7a95e4e8`, openrouter/openai/gpt-4o-mini, fizzbuzz task):

| Setting | Steps | Input tokens | Output tokens | Duration | Outcome |
|---|---|---|---|---|---|
| `ohmy_pi: true` (current default) | 15+ (killed at 90s) | 3,695+ growing | ~1,290 | 90+s | Gave up, prose-only |
| `ohmy_pi: false` (only line changed) | 3 | 3,613 | 201 | 6.1s | ✓ wrote, ran, declared done |

Same model, same task, same workdir — only `tools.ohmy_pi` flipped. Result: **15× faster, 6× fewer output tokens, task actually completes.**

### Storm rate across real eval sessions

Cross-checked against 90+ session JSONLs in `.motoko/logfile/`:

| Benchmark family | Sessions sampled | Avg storm events / session | Avg native calls / session | Wasted ratio |
|---|---|---|---|---|
| `adt_option` | 12 | 4–6 | 8–12 | **23–33%** |
| `balanced_parens` | 11 | 3–6 | 7–13 | **23–33%** |
| `canonical_normalization` | 2 | 3–4 | 8–9 | **23–30%** |

In sessions where the storm triggers, ~25-33% of all tool calls are wasted on `delegated_tool_deferred`. The 0% sessions are runs where the model didn't attempt BashExec at all.

### Token amplification under the executor adapter

The executor-adapter benchmark mode injects a ~21K-token AILANG teaching prompt as the user message. Each wasted step costs ~32K input tokens (system + tool catalog + 21K task + growing history) instead of the ~2K of a fizzbuzz repro. ~5 wasted steps per session × ~32K = **~160K wasted tokens per session**, compounding with growing message history. This accounts for most of the 70× input-token gap between motoko (~350K/session) and claude-code (~5.5K/session) in today's 3-harness comparison; the residual ~10× gap is the prompt-caching gap closed by [M-AI-PROMPT-CACHING (AILANG v0.18.4)](../../../ailang/design_docs/implemented/v0_18_4/m-ai-prompt-caching.md).

---

## Goals

**Primary Goal:** Ship motoko configs where the default-out-of-the-box BashExec flow works end-to-end without delegating to an unwired backend, so motoko users (and the AILANG eval-harness) stop paying a 25-33% wasted-tool-call tax.

**Success Metrics:**
- All 4 shipping config profiles set `tools.ohmy_pi: false`
- A motoko run with the default config produces **zero** `delegated_tool_deferred` events on a hello-world BashExec task
- A user explicitly setting `tools.ohmy_pi: true` gets a clear startup error pointing to the cause and the fix (defense-in-depth)
- Existing motoko smokes (`scripts/smoke_v2_*.ail`) continue passing without modification

---

## Non-Goals

- **NOT** implementing M-MOTOKO-M6.5 (the proper env-server inbox-wait pipeline). That remains a separate ~1-2 day planned sprint
- **NOT** changing `tools.hybrid: true` — hybrid mode (synthesizing BashExec from fenced bash in prose) is genuinely useful for cheap models that don't emit structured tool_calls. With `ohmy_pi: false`, hybrid bash routes through Native and works correctly (post v0.18.3 hybrid-tool correlation fix on AILANG)
- **NOT** removing the `delegated_deferred_message` code path — it stays as a defense-in-depth fallback for the case where someone re-enables ohmy_pi against a build that hasn't shipped M6.5 yet
- **NOT** touching the env-var override (`OHMY_PI_TOOLS=1`) — operators who explicitly opt in get the fail-fast error, which is the right behavior

---

## Solution Design

### M1: Config default flip (~4 LOC)

Change `tools.ohmy_pi: true → false` in all 4 shipping profiles:

- `.motoko/config/default/config.json`
- `.motoko/config/dogfood/config.json`
- `.motoko/config/local/config.json`
- `.motoko/config/openrouter/config.json`

`tools.hybrid` stays at `true` (independent feature, unblocked by ohmy_pi flip).

The code-side default in `config.ail:335` is already `false` — this milestone aligns the shipped JSON with that intent.

### M2: Fail-fast startup guard (~25 LOC)

Add an early check in `run_with_config` ([rpc.ail:131](../../src/core/rpc.ail)) right after config parse: if `cfg.tools.ohmy_pi == true`, emit a structured error event and exit before entering the agent loop.

```ailang
if cfg.tools.ohmy_pi then {
  let _ = emit_error("ohmy_pi_unsupported",
    "Config sets tools.ohmy_pi=true but the env-server inbox-based " ++
    "delegation pipeline is not yet wired in this build (see " ++
    "design_docs/planned/m-motoko-m65-ohmy-pi-delegation.md). Every " ++
    "BashExec would fail with delegated_backend_not_wired:true. Set " ++
    "tools.ohmy_pi=false in your profile (config dir: ${cfg.profile_dir}) " ++
    "or unset OHMY_PI_TOOLS=1 in the environment.");
  exitWith(2)
} else { ... existing path ... }
```

**Why fail-fast over auto-correct:** the explorer's analysis (msg `7a95e4e8` P0b) was right — silent token waste is worse than a clear startup error. A user who explicitly sets `ohmy_pi: true` deserves to know it's broken; auto-correcting would mask the real problem.

### M3: Regression smoke (~30 LOC)

New `scripts/smoke_no_delegated_storm.ail`:
- Spawn a BashExec via the agent loop
- Assert the result is NOT a `delegated_tool_deferred` envelope
- Assert no `delegated_backend_not_wired:true` substring in the session log

Wire into `make smoke` so any future regression that re-enables ohmy_pi-by-default fails CI immediately.

### M4: Commit + update upstream PR #7

This work lives on `motoko-bisect-gap1`. The branch is already the head of upstream PR #7 (sunholo-voight-kampff:motoko-bisect-gap1 → arniwesth/motoko_agent:main). After commit, update the PR description to include this fix in the changelog list.

---

## Examples

### Before (current)

```bash
$ ailang run --caps AI,IO,FS,Process motoko/main.ail \
    --task "Write fizzbuzz.py and run it." \
    --ai openrouter/openai/gpt-4o-mini

[step 0] BashExec → delegated_backend_not_wired:true
[step 1] BashExec → delegated_backend_not_wired:true (retry)
[step 2] hybrid bash extracted → delegated_backend_not_wired:true
[step 3] BashExec → delegated_backend_not_wired:true
... (10+ more wasted steps) ...
[step 14] (model gives up) "I'm unable to execute scripts due to system limitations."

15+ steps · ~3,700 input tokens · ~1,290 output tokens · 90s · DID NOT COMPLETE
```

### After (this sprint)

```bash
$ ailang run --caps AI,IO,FS,Process motoko/main.ail \
    --task "Write fizzbuzz.py and run it." \
    --ai openrouter/openai/gpt-4o-mini

[step 0] BashExec → wrote fizzbuzz.py
[step 1] BashExec → ran python3 fizzbuzz.py, output captured
[step 2] declared done

3 steps · ~3,613 input tokens · ~201 output tokens · 6.1s · ✓ DONE
```

### After + explicit-true override (M2 fail-fast)

```bash
$ OHMY_PI_TOOLS=1 ailang run --caps AI,IO,FS,Process motoko/main.ail ...

[error] ohmy_pi_unsupported: Config sets tools.ohmy_pi=true but the
env-server inbox-based delegation pipeline is not yet wired in this build
(see design_docs/planned/m-motoko-m65-ohmy-pi-delegation.md). Every BashExec
would fail with delegated_backend_not_wired:true. Set tools.ohmy_pi=false
in your profile (config dir: /path/to/.motoko/config/dogfood) or unset
OHMY_PI_TOOLS=1 in the environment.

(exit 2, no agent loop entered)
```

---

## Success Criteria

- [ ] All 4 config profiles (`default`, `dogfood`, `local`, `openrouter`) have `tools.ohmy_pi: false`
- [ ] `tools.hybrid: true` is preserved (no change)
- [ ] `run_with_config` rejects `ohmy_pi: true` with a clear error referencing the M6.5 design doc
- [ ] New `scripts/smoke_no_delegated_storm.ail` passes against post-fix code
- [ ] Existing smokes in `scripts/smoke_v2_*.ail` continue to pass without modification
- [ ] motoko-bisect-gap1 commit includes a reference to msg `7a95e4e8` (the explorer's bug report)
- [ ] Upstream PR #7 description updated with this fix

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Some user has `ohmy_pi: true` in CI and the fail-fast breaks them | Medium | Error message names the config dir + fix; opt-out is one config edit. Far better than silent token-waste-at-runtime |
| `tools.hybrid: true` alone (without ohmy_pi) has its own issues | Low | v0.18.3 AILANG fix (M-MOTOKO-HYBRID-TOOL-CORRELATION) closes the synthesized-tool_use-id correlation issue. Real-world hybrid use post-v0.18.3 should work cleanly |
| Future M6.5 lands and forgets to remove the fail-fast | Low | M6.5 design doc explicitly acknowledges this fail-fast — its "Acceptance criteria" first item should include "remove the M2 startup guard" |
| Config profiles in external consumers (motoko-multivac etc.) override to true | Low | Cross-repo consumers can set `tools.ohmy_pi: true` only after they've verified their build has M6.5 |

---

## Related Documents

- [m-motoko-m65-ohmy-pi-delegation.md](m-motoko-m65-ohmy-pi-delegation.md) — the proper wire-up. M6.5 must include "remove the M2 fail-fast" in its acceptance criteria
- AILANG v0.18.4 [M-AI-PROMPT-CACHING](../../../ailang/design_docs/implemented/v0_18_4/m-ai-prompt-caching.md) — closes the residual ~10× input-cost gap; this sprint closes the ~70× gap
- AILANG v0.18.3 [M-MOTOKO-HYBRID-TOOL-CORRELATION](../../../ailang/design_docs/implemented/v0_18_3/m-motoko-hybrid-tool-correlation.md) — fixes the synthesized hybrid-bash tool_use_id correlation issue, unblocking hybrid mode independently of this sprint
- motoko_explore msg `7a95e4e8` — A/B repro evidence
- arniwesth/motoko_agent PR #7 — upstream PR carrying motoko-bisect-gap1, will include this fix

---

**Document created**: 2026-05-08
**Author**: Claude Opus 4.7 + Mark, surfaced by motoko_explore
