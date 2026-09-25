# AILANG: fund `m-effect-handlers` Phase 1 — 20,858 lines of userland boundary plumbing are the sponsorship case

## Status

Written 2026-09-05 on branch `arniwesth/013-dst-architecture-adr` at `3fe71b0`.
Measured against the pin, **AILANG v0.33.0**, commit `ae36986`, built 2026-09-04
(`ailang version`).

Upstream: `ailang/design_docs/planned/v1_1_0/m-effect-handlers.md` — **Planned**.
Target v0.21.0 (Phase 1) → v0.22.0 / v1.0.0 for full surface. Estimate ~80–120h
across 2–3 sprints, **Phase 1 alone ~30–40h** (doc lines 4–6). Priority line, verbatim:
*"strategic language feature, **unblocks deterministic testing story**"*. Tree at v0.33.0 —
the doc has been Planned across twelve minor versions past its Phase 1 target.

## Not yet filed upstream

Not submitted to `sunholo-data/ailang` — filing is an outward-facing action and was not
part of the diagnosis this came out of. Worth routing through the `ailang-feedback` skill
(Channel 2 if the CLI is configured, Channel 1 otherwise).

Filing pre-flight, measured 2026-09-05 rather than assumed: Channel 2 is unavailable —
`gh auth status` reports "You are not logged into any GitHub hosts" and
`~/.ailang/config.yaml` is absent. The `ailang-feedback` skill is not installed in this
session (no skills directory), and the Channel 3 MCP `submit_feedback` POST is not
reachable from the available tool set, so Channel 3 was not attempted either. No ticket
exists; there is no URL and nothing to poll. See the identical channel caveat recorded in
`ailang-no-warning-for-unreachable-match-arm.md`'s *How it was filed* section: Channel 3
is fire-and-forget with no URL and no status to poll.

## Symptom

Motoko's deterministic-test-world boundary — world threading, virtual clock, synthetic
FS, replay — is implemented in userland AILANG because the language ships tracked
effects but no user-definable handlers (`handle e with H` does not exist; each effect
name maps to a hard-coded Go handler). Measured at HEAD:

```
$ wc -l src/core/dst_*.ail | tail -n 1
  20858 total
```

Twenty files, 20,858 lines, implementing exactly the feature the upstream doc was
commissioned to provide (its comparison: Koka-style handlers turning effects from
"tracked" into "programmable"; its success metric: the eval harness replacing `AI` with
`handle AI with recorded` without touching Go).

## Where it comes from

Upstream problem statement (`m-effect-handlers.md`, consequences 1–4): testing is awkward
(env-var coupling, Go edits, or fake provider plugins — none reachable from inside an
`.ail` test file); no domain effects; the eval harness cannot ship deterministic test
doubles in-language; the Leijen 2014 citation covers row algebra but not handlers.

Motoko-side, the cost is concrete: the ports-swap mechanism, the `WorldState` threading
through every leaf (`next_state` at 198 textual sites across the boundary modules —
167 non-comment lines), and the §2.A / §2.B / §2.D userland programme exist because
there is no `handle … with …` to meet.

## How it bites Motoko

Per RESEARCH §3 (project 013): "a substantial fraction of the 20,037 lines of
`src/core/dst_*.ail` is a userland implementation of AILANG features that are already
designed and unshipped", first row the handlers doc. The ordering constraint is filed
with the ask: **file before starting §2.D** (commands + interpreter), so that if
Phase 1 handlers land, §2.D is shaped to *meet* them, not duplicate them.

## Suggested upstream fix

Fund and ship Phase 1 (`effect E { op : T -> U }`, `handle expr with H`, row subtraction
on handle, one-shot deep handlers, `Yield[a]` / `State[s]` / `Reader[r]` reference
effects). Motoko is the strongest available evidence for funding it: a 20k-line userland
proof of exactly that feature, with a paper attached.

## Workaround in this repo

None — the userland boundary is the workaround, and it stays until adoption is measured.
Which boundary plumbing handlers may replace is **measured after adoption, not claimed
here**.

## Do not claim

- No coverage conversions and no deletion of the userland architecture are claimed from
  handlers. Handlers *may* replace selected boundary plumbing; which parts is measured
  after adoption.
- The upstream ~30–40h Phase 1 estimate is a language-implementation estimate, not a
  Motoko integration estimate.
