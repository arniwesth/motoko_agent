# The review protocol — orientation for a fresh reviewing session

Every other artifact in this directory is written for the session that **implements** an item. This one
is written for the session that **hands off and applies** — the other half of the loop, whose method
has until now lived only in a conversation.

> **THE GOAL LINE WAS REACHED 2026-08-09 (WI-D28) AND THE LOOP IS IN ITS SOFT TAPER.** The closing
> note is `NOTE-d28-the-final-acceptance-rerun.md` — read its §9 before choosing any item. The
> maintenance register (its §9.1, nineteen entries) is the queue's ONLY source, ordered by measured
> value, at reduced cadence; continuation is maintenance, not pursuit. Standing rules by exception;
> counters continue as fix-or-file. Everything below still governs HOW an item runs; §9.1 governs
> WHICH items exist.

## The loop

Two instructions alternate, and nothing else happens:

1. **"Write the next handoff."** Choose the next work item, **ground every claim in it against HEAD by
   measurement**, write `HANDOFF-execute-<id>-<slug>.md`, append a cluster entry to
   `NOTE-execution-clustering-and-handoff-generation.md`, commit.
2. **"The plan has been implemented. Refer to NOTE-<id>-*.md."** Read the report, **independently
   verify its central claims**, apply corrections to
   `PLAN-implementation-deterministic-test-world.md` — standing rules and a per-item milestone entry —
   commit, and report back to the user in prose.

**Only the second half of step 2 is optional-looking and is not.** The plan is the durable record; a
report that is read and not folded in is a report that will be re-derived.

## The one rule that makes the loop worth running

**Never accept a report's central claim. Measure it.**

Not because implementers are careless — they are not; the reports are unusually good. Because a claim
that only exists in a report is a claim nothing checks, and this project's entire subject matter is
the difference between those two things.

Verification is cheap: the claims are almost always a `grep -n`, a `sed -n`, or one `make <target>`
away. Budget five to fifteen tool calls per apply. **Run the gates the report says are green.**

### It pays, and here is the evidence rather than the assurance

| Item | Claim | Measurement |
|---|---|---|
| D6 | *"an extension is now installable"* | False — three barriers stood |
| D14 | the stdlib cache's producer is `make sync_packages` | Its evidence is `~/.ailang` (4 files); the open question is `~/.local/share/ailang/std/.ailang` (52). **Still unidentified** |
| D20 | a moved anchor touches **nine** files | Nine is a `tool_phase` move; a `session.ail`-only move is **six** |
| D21 draft | A7 declares **seven** fault classes, so the class has none to name | `required_class_ids()` is asserted at **11**, and `extension_effect_fault` exists — the seven came from reading the `fault_class_*` **accessors**, a subset |
| D22 | the quiet anchor run is *"a data point against D21's finding"* | Outside its scope, not against it — D21's law names `ext_ports_of`, in `session.ail`; D22 edited prose in `types.ail` |
| D24 | silent-wrong goes to **76** (the host-side token rewrite) | Stays **75** — the wrong form never shipped and was not silent (two reachability rows went red), so it is authored-and-closed under D22's rule. Promoted to **S34** instead |
| D27 handoff | registration discloses "through the D5-field-9 mechanism" | Impossible — `DisclosureIds` carries hook ids only; a mechanism named without checking its shape. Field 6 + `DISCLOSED` lines are the home |
| D26 handoff | *"the seam's only subprocess door is `bash -lc`"* — so quote the shell string | **False, and following it would have authored a shell injection** at the one model-text argument. The wrap is a conditional fallback (`tool_runtime.ail:888`); the argv door exists. Premise traced to D21 §8's unconditional record, quoted forward five items |

**And the corrections themselves get corrected.** I corrected D21's catalogue claim and then wrote that
its *other* ground held; the revised report showed it did not. **Verify your own corrections at the
same standard** — see S31.

## Your own output is the other thing that goes wrong

Handoffs are analysis, and analysis has the same failure modes as the code. **Four standing rules were
earned against handoffs written in this role:**

- **S22** — a binding count given as 8 was 15.
- **S25** — a handoff prescribed pinning a distinction (`prepend` vs `append`) that the chosen design
  made **non-existent**. State what a consequence is *conditional on*.
- **S28** — a five-line reachability walk shipped `guard.ail` as effect-bearing; its `readFile(` and
  `exec(` are **string literals** in a substring search. The same walk had a second instance, caught
  before publication. **A textual match is not a call site, including in your own tools.**
- **S16** — a handoff cited an ADR paragraph whose repro did not apply through the imported type.

Plus two framing errors that the items defeated on measurement: *"a file write is not an observation"*
(D16 — true, and the wrong question) and invoking **D1's stop condition** for what was a design cost
(D21). **Escalating a price into a falsification is the characteristic error of this role.**

**Read paths end to end rather than grepping them.** D21's best finding — the seam already emits a
program its own validator rejects — came from following `session.ail` → `ports.ail` →
`tool_dispatch_adapter` → `tool_runtime`, and so did the correction to it. **And read one function
BELOW the seam you are describing**: four items described `proc_exec` correctly and none opened the
dispatcher's own branch (`tool_runtime.ail:888`), so a false "only door is `bash -lc`" premise
survived from D21 to the D26 handoff — where it nearly became a prescribed injection.

## Two counters, and they are deliberately separate

- **Silent-wrong: 76 across 50 runs.** *Production sites where two answers type-check and the wrong one
  ships silently.*
- **Instrument-weaker-than-its-claim: 7.** *A row that passes while measuring less than its label.*
  Opened at D21.

**Do not merge them.** Same cause — a type that does not distinguish — different consequence, which is
what a count is for. **Do not inflate either** with defects an item authored and closed in the same
commit; D22 declined to and was right.

## The recurring shapes, so you recognise them on sight

- **"Absent reads identically to unchanged."** The counted mode. C1, D6, D12, D13, D16, D17, D18, D19.
- **"Present-but-wrong reads identically to correct"** (S26) — an assertion naming its subject by
  ordinal literal, passing while reading a different interaction.
- **Two homes for one fact** — `ADR:340-341`. Produced by an unmediated effect (D16, D17), by the
  world's **key** (D18), and by two codecs for one structure (D22).
- **A guard that fails open** — `derive.py`'s exit code; a pin that iterates itself (S24).
- **A property inferred from a proxy that usually agrees with it** — **S33**, which consolidates eight
  instances across code, instruments and analysis. **Read S33 before writing a handoff**: three of its
  eight are analysis errors made in this role, and its one operating question — *what does this
  actually read, and what input makes that differ from what it means?* — is the cheapest check
  available on your own output.

## Standing rules

**S1–S34, and they are promoted from execution, never written in advance.** A rule with no item that
paid for it does not belong there. They live at the top of the plan; skim the block before writing a
handoff, because three or four will apply to any item.

## Where the work stands (2026-08-09, after WI-D28 — CLOSED, in taper)

Route B is COMPLETE and compose's mediation is done: **8 ambient sources, 36 `ExtPorts` field
calls** (D26 routed the four `exec` call sites and removed the three `std/process` imports — the
first yield-adjacent movement since D15). The remainder is exactly the three disclosed classes:
four `println` (by decision), registration's three (structurally unroutable), one ambient AI.
**BOTH GOAL-LINE CLAUSES HOLD (D27, D28).** `driver_plus_compose` v1 records and strictly replays
a real graded session with compose installed — `extension_effects=1 origins=[compose] replayed=1
mismatches=0` — under `profile-rules/3` and the first dynamic, EXISTENTIAL producer. All fifteen
extensions are mediated or disclosed with a measured reason; door 3 is disclosed and filed
(`fb_0f70d66af0fddb2c`). The vacuity register is computed: **forty classification entries, exactly
one measured-and-substantive** — the honest size of what has been demonstrated, stated so nothing
overclaims from it. Profiles: driver_only v22 · driver_plus_no_ops v9 · driver_plus_compose v1.
Three standing reds (`test_coverage` pair since D22; `effect_inventory_selftest` since D25), all
disclosed, all on the register.

**There is no critical path. The maintenance register (`NOTE-d28` §9.1, nineteen entries numbered continuously) is the
queue.** The one instrument worth building first, per the closing note: `driver_only`'s missing
coverage `STATEMENT` line, which makes the register fold computable from three profiles instead of
two.

**The endgame scope rule: a finding joins the queue only if it blocks the goal line's two clauses;
everything else goes to the plan's maintenance register.** (Door 3's producer, the hook-scope
promotion, the scratchpad loopback successor, the stale classifier-2 literals, classifier 1's
repair, the stdlib cache's producer, the gate-table State column, F3 — all register, none queue.)

## Read order for a cold start

`ADR-001` §Context and the eleven-row table → the plan's **"The goal line"** section → the plan's
**S1–S34** block → the last three milestone entries → this note. **Then measure something before you
write anything.**
