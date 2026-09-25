# AILANG: per-hook capability narrowing (`scope=`) — 20 of 40 coverage entries rest on a declared row

## Status

Written 2026-09-05 on branch `arniwesth/013-dst-architecture-adr` at `3fe71b0`.
Measured against the pin, **AILANG v0.33.0**, commit `ae36986`, built 2026-09-04
(`ailang version`).

Upstream: `ailang/design_docs/planned/v1_0_0/m-effect-scope-params.md` — **Planned**,
~16 hours (~2.5 days), sprint 4 of 4 of the `m-effect-refinement` decomposition.
**Rand + AI only**; FS/Net and other effects opt in later by schema row. Budgets and
scopes stay disjoint. Initial scope set carried from the parent: `identity | session |
test-denied | _` (wildcard). Today `scope=identity` parses and type-checks with **no
semantics whatsoever** (live-verified 2026-07-11; after the sprint-1 validation table
lands it is *rejected* until this sprint registers the key). Release-gate note in the
doc itself: weakest v1.0 forcing function of the four carve-outs, candidate for
re-scoring to v1.1.

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

DRAFT §6.3, Table 4 (the vacuity register): **forty classification entries, one measured
and substantive**. Twenty entries — criterion 1, "hooks claimed effect-free" — rest on
the hook's *declared effect row* (an assumed basis: the declaration, not a measurement),
plus the one exclusion whose basis is disclosure. Per RESEARCH §2.C (project 013):
"Zero routed effects" ≠ "zero effects" — an ambient effect is invisible to a
positive-observation instrument, and measuring effect-freedom requires a *negative*
observation. The only mechanism the project already trusts for that is caps-as-conformance
(DRAFT §3.4), which AILANG grants **per process** — so per-hook narrowing is the upstream
fix and the subprocess-under-narrowed-`--caps` sample is the userland fallback (a measured
sample, still strictly stronger than today, but not a declared row).

## Candidate hooks (Rand/AI-scoped subset, listed first)

Narrowing can only convert the subset whose hooks are Rand/AI-scoped — the only effects
that declare scope support in v1.0. Hooks in the tree whose declared rows include Rand
or AI (grep at HEAD; rows, not behaviour):

- `packages/motoko-ext-a2a/a2a.ail:150` — `make_hooks` `! {Net, Rand}`
- `packages/motoko-ext-ailang-docs/ailang_docs.ail:29` — `on_tool_handle`
  `! {Process, FS, Rand}` (and `:39` `make_hooks` `! {FS, Process, Rand}`)
- `packages/motoko-ext-compose/compose.ail:887` — `on_tool_handle`
  `! {IO, AI, Process, FS, Env, Clock, Rand}`
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:109,127,140,492,524,598` —
  `summarize_attempt` / `summarize_with_ai*` / `stub_ai_step` `! {AI, IO, Trace}`
- `packages/motoko-ext-abi/types.ail:294` — `ExtPorts.ai_step` `! {AI, IO, Trace}`
  (the port row every AI-scoped hook funnels through)

Hooks whose rows are Env/FS/Clock-only (the other eight `ExtPorts` forwarding fields,
most no-op atoms) are **out of scope for this ask** — their effects opt in later by
schema row, if ever. FS/Net narrowing belongs to a future sprint, not this ticket.

## Where it comes from

Capabilities today are effect-granular: `--caps Rand` grants ALL Rand operations. A
program that mints identity material and also shuffles a list holds one undifferentiated
grant — the security-sensitive operation is indistinguishable from the trivial one at
the authority layer. The `scope=` parameter is the typed narrowing mechanism; Phase 1
shipped its grammar only.

## How it bites Motoko

Per RESEARCH §2.C: the upstream fix "converts 20 assumed entries to measured using the
exact mechanism §3.4 already defends", and closes the §2.E registration gap (ambient
registration reads environment and files before any hook is dispatched; capabilities are
per-process). Until it lands, criterion-1 measurement in userland beyond the subprocess
sample is explicitly not now (RESEARCH §5).

## Suggested upstream fix

Ship the sprint as designed: schema rows registering `scope` on Rand + AI, per-effect
scope sets on the grant model (default = wildcard, today's behaviour), grant check at
op dispatch (declared scope ∈ granted scopes), `scope=test-denied` failing under the
test-harness profile, unscoped programs byte-identical. Reconcile AI's `byok` scope with
the shipped M-AI-EFFECT-MODES surface rather than shipping conflicting semantics.

## Workaround in this repo

Dispatch hooks in a subprocess under narrowed `--caps` (the RPC machinery exists).
Expensive; gives a *measured sample* rather than a declared row. A static effect-row
audit over extension source explicitly does **not** work — that is a better assumption,
not a measurement.

## Do not claim

- No claim that 20 entries convert on landing. Narrowing *may* convert the subset whose
  hooks are Rand/AI-scoped; the candidate hooks are listed above, first, and the rest
  (Env/FS/Clock-only, FS/Net-scoped) are out of scope.
- The upstream ~16h estimate is a language-implementation estimate, not a Motoko
  integration estimate.
