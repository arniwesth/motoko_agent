# Handoff: execute WI-A12 — thread `world_state` through the driver

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

This is **cluster 6 of Milestone A, and it is the critical path.** A13, A14 and A15 all wait on it.
Two clusters have landed on this same source surface and both left findings aimed directly at this
item — **read both reports before starting**:
`NOTE-cluster-1-execution-report-and-plan-corrections.md` and
`NOTE-cluster-4-execution-report-and-plan-corrections.md`.

## Mission

Thread `world_state` through the driver, **one effect class per commit**, each ending green.

The plan is your specification — read WI-A12 and decisions P2 and P3 there. Order is fixed by the
plan: **provider** (subsuming A2's interim field), then the **four driver clock sites**, then
**approval**, then **env reads**, then **runtime randomness**, then the **typed tool contract**.

**Partial A12 is a legitimate stopping point.** Each effect class is behaviour-preserving and ends
green on its own, so if the session runs long or a class surfaces a hazard, finish the current class,
commit, and report. Do not carry a half-threaded class across a stop.

## The rule you will break by accident — and it has already been measured twice

**Land an executable advancement assertion for each cursor *before* you thread it. Not after.**

This is binding, it is in the plan, and it exists because two clusters proved the failure empirically
rather than predicting it:

- **Cluster 1**: thirteen successor literals gained a field. The compiler forces the field to be
  *present* everywhere but accepts the carry-forward value at every one. Six had to carry the
  successor. Flipping those six type-checks clean — `✓ No errors found!` — and serves
  `[s0,s0,s0,…]` in every scenario. A total freeze, worse than the defect it replaced.
- **Cluster 4**: four more such sites, **worse in kind**. These were *trace arguments*, where the
  wrong value yields a trace that **still passes its own invariant** — hand `c2_finalize` `st.trace`
  instead of the trace carrying the decision record and the record silently vanishes while the
  one-`RunSummary` assertion stays green. One was caught only by reading emitted JSONL, because
  `smoke_parity` diffs a build against itself and a consistent reordering is consistent.

**A12 threads more cursors through those same literals, and now also through a finalizer that takes
a trace argument.** So the assertion requirement is the strengthened form: **it must cover trace
completeness, not only cursor advancement.** An assertion that only checks "the cursor advanced"
will pass while a record is being dropped.

`scripts/dst/scripted_cursor_probe.ail` is the shape to copy — it drives the real traced entry point
twice and compares served sequences. `make terminal_trace` is the shape for trace assertions.

## Re-ground before you rely on anything

**Every anchor in the plan's survey and in cluster 1's report is stale.** A2 and A9 rewrote
`session.ail` between them. Re-measured at HEAD 2026-08-02 after cluster 4 — **re-run
`git diff --stat ff8d8e5..HEAD -- src packages scripts Makefile` first; if non-empty, re-measure the
table.**

| Anchor | Now |
|---|---|
| `Ports` — 5 fields, `model_step` already state-threaded | `ports.ail`; `model_step: (ProviderState, string, [Message], callback) -> ProviderExchange` |
| Interim cursor field (A12 subsumes and deletes it) | `C2LoopState.provider_state: ProviderState`, `session.ail:359` |
| `provider_state` occurrences — the literal population | **25** in `session.ail`; the dispatch carry sites are `1829`, `1881`, `1914` |
| `dispatch_step` call | `session.ail:1809` |
| `ported_provider` — returns `PortedProvider {ports, state}` | `session.ail:730`, **7 call sites**; its `_history` param is **dead and A12 deletes it** (cluster 1, C5) |
| Driver clock sites — **4** | `session.ail:826`, `908`, `2079`, `2177` (`:820` is a comment, not a site) |
| Repo-wide clock inventory | **13**, unchanged — 4 driver, 1 `ext/runtime.ail:190`, 8 `motoko-ext-compose` |
| Approval `readLine` | `session.ail:1692` (in-loop), `:2284` (conversation loop, above the traced entry) |
| `c2_finalize` — takes a trace argument | `session.ail:897`, called from every terminal return |
| Extension model path — stays excluded | `session.ail:689`, hands `empty_provider_state()` by design (D1) |

## Scope, and the two things in it that are not "threading"

1. **Delete `ported_provider`'s dead `_history` parameter** at all 7 call sites. It existed only to
   compute the `base_assistant_count` that A2 retired (cluster 1, C5).
2. **The typed tool contract is all three of D1's parts**: a typed `ToolCallEnvelope`,
   timeout/deadline information, **and a typed result/error** replacing
   `tool_exec: (string, string) -> string`. A request-only widening passes the poison probes while
   leaving the return an undifferentiated string — weaker than D1 requires and unable to carry D3's
   typed tool fault classes. This is the last class in the order and the largest; it is a legitimate
   place to stop and hand off if the session is long.

## Definition of done, per class

Behaviour-preserving throughout — live adapters delegate to today's code paths.

- **Its advancement/completeness assertion exists and is in a CI-invoked target, committed before
  the threading commit** (or in the same commit, but written first — the point is that it must be
  able to fail).
- `make check_core`, `make dst`, `make terminal_trace`, and the driver smoke targets green. Cluster 4
  wired those; use them.
- **The class's poison probe**: with that capability withheld, the deterministic entry point
  completes and the live world dies. This is D4's F3-corrected per-run backstop and it is a *run-time*
  check — `{Clock}` staying in the effect row is expected; AILANG only fails when a read is performed.
- After the clock class, `driver_only`'s **4-site** routed claim becomes true. **Do not record that
  claim yet** — per D4's scheduling prohibition it also needs WI-A5's attribution table, which is
  cluster 2 and is not built. Route the sites; leave the claim to A10.

## Out of scope — actively do not do these

- **The extension model path.** `session.ail:689` hands `empty_provider_state()` and that is D1's
  deliberate exclusion, not an oversight. Widening `ExtPorts.ai_step` is the Milestone B ABI major.
- **The eight `motoko-ext-compose` clock sites and `ext/runtime.ail:190`.** Nine of the thirteen are
  extension-side; A12 routes the four driver sites only. `ExtPorts.clock_now` still has zero call
  sites and stays that way until WI-C5.
- **Any profile, manifest, or conformance claim** — A10's.
- **Discovery, replay, or program types** — A13's. A12 threads state; it does not record it.

## Stop and report rather than deciding inline

- **If a class needs an interim approval or clock cursor before `world_state` subsumes it**, that is
  P2's named reopening trigger. Report it; do not widen `approval_read` or `clock_now`
  bidirectionally on your own authority — two reviewer probes established that doing so is a second
  bidirectional port widening, and the plan owns that decision.
- **If threading a class requires production code to branch on test mode**, stop. That falsifies D1
  and is an ADR-level finding, not a workaround.
- If the typed tool result/error forces a wire-visible change to tool output, stop — that is a
  compatibility decision the plan owns, like the one A9 correctly declined (cluster 4, C4).

## Traps

Clear `.ailang/cache` before believing a contradicting type error. **Rebuild the parallel
`ailang check` closure tool before editing** — cluster 1 ran it over 22 modules in 12 s, cluster 4
over 19 in 2.6 s, and both reported it is what makes the site-convergence cost linear instead of one
round-trip per site. Never probe from `/tmp`. `make dst` and CI both use `--keep-going`, so read exit
status rather than the last line. `scripts/dst/probe_phase_vocab_sealed.ail` fails at baseline
(`IMP010`, pre-existing, in no target — WI-A17 owns it); do not chase it.

## Report back

Third calibration run, and the first on an item the plan sized in *days*.

- **Time and sites touched per effect class**, against the estimate. The plan says "several days";
  the sizing rule now says count sites — 25 `provider_state` occurrences for the class already
  half-done, and clusters 1 and 4 came in at ~5–14 minutes for 11–35 sites each. **If this lands in
  under an hour, say so plainly**: three confirmations would let the plan re-size A13, A14 and B2,
  which are the remaining schedule risk.
- **Judgement ratio** against the bands: 19% for port widenings, 27% for contract rewrites. A12 is
  both, so which band it lands in is genuinely informative.
- **Whether any site admitted two type-checking answers with a silent wrong one** — the question that
  has paid twice. If A12's assertions caught one *before* it shipped, that is the strongest available
  evidence the requirement was worth imposing, and it should be recorded as such.
- Anything the plan got wrong, as a plan correction. A12 deletes the interim field cluster 1 added,
  so cluster 1's report is invalidated by this landing and should be marked accordingly.
