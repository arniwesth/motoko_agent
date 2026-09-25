# Handoff: execute WI-A4, WI-A5, WI-A11 — the three detectors

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

This is **cluster 2 of Milestone A, and it is the last unstarted independent work.** Four clusters
have landed (1, 3, 4, 6). **A10 is blocked on this cluster alone**, and A10 blocks A13, A14 and A15
— so everything remaining is behind it.

**Read the plan's `## Standing rules` first — S1 and S3 both bind here.**

## Mission

Build three detectors, as **three separate commits**:

- **WI-A4** — classifier 2, the `ExtPorts` typed-call inventory.
- **WI-A5** — the site-to-hook attribution table and its profile-load validation. D4's producer
  clause requires A4 and A5 **in the same change**, so A5 may share A4's commit if that is cleaner;
  what it may not do is land without A4's site enumeration.
- **WI-A11** — the predicate documentation check.

`tools/effect-inventory/derive.py` (classifier 1) is the working precedent: same language, same
`make` target + selftest shape, same fail-closed posture. **Do not re-specify classifier 1; extend
its patterns.**

## The rule you will break by accident — and this one is a live ADR conflict, not a slip

**D5's explicit non-member list for classifier 2 is stale, and following it would fail *open*.**

D5 states the membership criterion and then names exclusions:

> `clock_now`, `proc_exec`, and `env_get` are explicitly *not* members … Those three fields lose no
> cursor. They are point reads and effect crossings.

**That was true when it was written and WI-A12 falsified it three commits ago.** Verified at HEAD:

| Field | Core seam it fronts | Returns a successor? | The ext closure… |
|---|---|---|---|
| `ai_step` | `Ports.model_step` | yes, `ProviderExchange.next_state` | discards it — the known member |
| **`proc_exec`** | **`Ports.tool_exec`** | **yes, `ToolExecution.next_state`** | **`session.ail:773-781` takes `.outcome` only** |
| **`env_get`** | **`Ports.env_get`** | **yes, `EnvRead.next_state`** | **`session.ail:763-765` takes `.value` only** |
| `clock_now` | — | n/a | ambient by design (S2); cannot be bridged on this pin |

The criterion — *"a field whose call is the extension-side entry to a core seam that D1 requires to
thread successor state, and which cannot return it"* — now selects **three** fields, not one. The
ADR's own escape clause anticipated this: *"the set grows only when D1 requires another cursor
threaded through an extension-side entry."* A12 is exactly that event.

**Measured before you have to ask: the exposure is nil today.** `grep -rn '\.proc_exec(\|\.env_get(\|\.clock_now(' packages`
returns **zero** calls outside the ABI package itself. So this changes no profile that exists — but
a classifier built to D5's stale list would be **structurally unable** to see the seam the moment an
extension uses it, and would report a clean routing audit over a dropped world cursor. That is a
fail-open detector, which is the exact defect classifier 1 was rewritten four times to avoid.

**What to do:** build the classifier against the **criterion**, not the list; report all three
fields; and **file the D5 discrepancy as an ADR amendment** (the ADR is Accepted — amend, do not
open a review round). If you conclude the criterion should *not* select `proc_exec`/`env_get`, that
is a legitimate finding — but argue it from the source, and say what makes a discarded
`ToolExecution.next_state` different from a discarded `ProviderExchange.next_state`.

## Re-ground before you rely on anything

Re-measured at HEAD 2026-08-03. **Run `git diff --stat 0615637..HEAD -- src packages scripts Makefile`
first; if non-empty, re-measure.** Every count below came from a command run while writing this
table — the commands are given so you re-run them rather than trust me.

| Anchor | Now | Command |
|---|---|---|
| `.ai_step(` call sites | **2** — `compaction_ai.ail:106`, `reject_fixtures.ail:90` | `grep -rn '\.ai_step(' src packages scripts` |
| Other `ExtPorts` field calls in packages | **0** for all three | `grep -rn '\.proc_exec(\|\.env_get(\|\.clock_now(' packages` |
| `ExtPorts` shape — **unchanged by A12** | 4 fields, `motoko-ext-abi/types.ail` | `sed -n '/export type ExtPorts/,/^}/p'` |
| `Ports` shape — **fully state-threaded by A12** | 5 fields, all taking `WorldState` | `sed -n '/export type Ports = {/,/^}/p' src/core/ports.ail` |
| A5 row 1: the `test_dummy` clock site | `ext/runtime.ail:190`, unchanged | `grep -n 'now()' src/core/ext/runtime.ail` |
| A5 row 2: the scratchpad mixed guard | **moved** — helpers now at `tool_phase.ail:164`/`:168`; find the guarded call site itself | `grep -n 'is_scratchpad_tool_name\|scratchpad_extension_active' src/core/tool_phase.ail` |
| A11's six anchors | `ADR:57`, `:384-385`, `:405`, `:460`, `:1934`, plus handoff item 2 | `grep -n 'classifier-2 field on an\|every hook it registers'` |

**A5's second row moved and the plan still cites `tool_phase.ail:222`.** A12 rewrote that file. The
mixed guard (`is_scratchpad_tool_name(...) && scratchpad_extension_active(rt)`) is the ADR's worked
example of why clause 3 is an attribution table rather than a semantic test — locate the current
call site, do not cite the plan's line.

## Definition of done

**A4 green.** A type-aware field-call inventory over `src` + `packages`, failing closed on every
alias, wrapper, re-export, or computed access it cannot resolve. At HEAD it reports the two known
`ai_step` sites and zero unresolved. **A synthetic fixture using each unresolvable form is reported
as unresolved → triage, not as a pass** — that fixture is the acceptance, per S1. `make` target plus
selftest, modelled on classifier 1. Re-derivation wired into the repin checklist (WI-B4).

**A5 green.** Validation rejects unknown hook ids, stale source-revision bindings, and malformed
rows; permits known-but-uninstalled ones; the empty-intersection rule is exercised. **And the
set-completeness fixture, which is the one that matters** (S1, and cluster 3's C8 made the same point
for A6): a fixture in which a classifier-discovered core effect site appears in **neither** the
attribution rows **nor** the explicit unconditional-core set must be rejected at profile load. A
row-shape validator accepts it. Table identity is `(source revision, content hash)`.

**A11 green.** An anchor-set **drift** check, not a containment check — the ADR records its six sites
as deliberately *not* word-identical, so a containment check is red on the unmutated ADR by
construction. Each anchor by location, with a content hash and a named reviewer who accepted that its
formulation states the predicate. **Acceptance is both halves: green on the unmutated ADR at HEAD,
and red when one anchor is mutated in a scratch copy.** The first is the falsifiable half.

Note the ADR has been **amended twice since A11's anchor list was drafted** (D6.1/D6.2 on 2026-08-02,
D5 on 2026-08-02) and will be amended again by this cluster's own D5 finding. Hash the anchors after
your amendment lands, not before.

## Out of scope — actively do not do these

- **The profile definition and manifest** — A10's, and it is the direct consumer of all three.
- **The interprocedural attribution-necessity validator.** D4 assigns it as its own future
  obligation; until it exists, necessity rests on the recorded named reviewer, and that is a
  *stated* exception to the automated-gate promise. Do not build a mechanical necessity check —
  the ADR withdrew one attempt already and explains why a check that fails its own worked example is
  worse than none.
- **`driver_only`'s routed-set claim.** A12 routed the four driver clock sites so the claim is
  *true*; recording it needs A5's table plus A10's machinery. Build the table; leave the claim.
- **Widening `ExtPorts`.** The stale-exclusion finding above is a *detector* and *amendment*
  question. Actually widening the ABI is Milestone B's major.

## Stop and report rather than deciding inline

- If the D5 discrepancy turns out to change which of the fourteen checked-in configurations can form
  a conformant profile, stop and report before amending — that is a scope question, not a wording fix.
- If a required attribution row cannot be written because the site's guard cannot be related to a
  hook id without interprocedural reasoning, that is D4's known gap, not a blocker: record the row
  with its named reviewer and say so.

## Traps

Clear `.ailang/cache` before believing a contradicting type error. Never probe from `/tmp` —
`MOD010` auto-relaxes there and classifier 1 refuses to run from a temp directory for exactly that
reason; classifier 2 should inherit the refusal. `make dst` and CI both use `--keep-going`; read exit
status. `scripts/dst/probe_phase_vocab_sealed.ail` fails at baseline (`IMP010`, pre-existing, in no
target — WI-A17 owns it). The pin is v0.26.0, Makefile-guarded.

**`ailang iface`'s three defects are filed upstream and unfixed** (ticket `fb_d230853828108783`):
`pure` contradicts `effects` on 12 `std/ai` exports, `iface <module>` does not resolve stdlib
modules, and `std/secret` fails `MOD010` outside a temp directory while auto-relaxing inside one. If
A4 uses `iface --json` as its parsed input, inherit classifier 1's four documented repairs rather
than rediscovering them.

## Report back

Fifth calibration run, and the first on **detector** work — a third kind, after widen-and-converge
(clusters 1, 4, 6) and constructed artifacts (cluster 3).

- **Time and sites per detector**, and which sizing model fit. S4 says price rows by whether their
  content must be *discovered* or *transcribed*; a classifier is neither — it is a program with a
  test suite. If a third model is needed, say what it is.
- **Judgement ratio.** Classifier 1 is a working precedent, so A4 may come in low like A6 did (16%,
  rules fixed verbatim). If it does, that further confirms the corrected predictor.
- **Whether any site admitted two type-checking answers with a silent wrong one.** For a detector the
  characteristic form is a matcher that passes while failing open — which is what classifier 1 was
  rewritten four times for, and what the D5 stale-exclusion finding above is an instance of.
- **Anything the plan or ADR got wrong.** This cluster already has one ADR amendment queued before
  it starts; expect more, and file them as amendments.
