# The review protocol — orientation for a fresh reviewing session

Every other artifact in this directory is written for the session that **implements** an item. This one
is written for the session that **hands off and applies** — the other half of the loop, whose method
has until now lived only in a conversation.

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
`tool_dispatch_adapter` → `tool_runtime`, and so did the correction to it.

## Two counters, and they are deliberately separate

- **Silent-wrong: 75 across 44 runs.** *Production sites where two answers type-check and the wrong one
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

**S1–S33, and they are promoted from execution, never written in advance.** A rule with no item that
paid for it does not belong there. They live at the top of the plan; skim the block before writing a
handoff, because three or four will apply to any item.

## Where the work stands (2026-08-08, after WI-D22)

Route B is built and compose is mediated: **11 ambient sources, 32 `ExtPorts` field calls** — the
remainder are four `println` (disclosed by decision), three `exec` (the seam cannot type them),
registration's three (structurally unroutable) and one ambient AI. **`execution-program/2` shipped** and
D17's two-tier compatibility surface is closed at zero classes.

Yields **4 of 15** and **5 of 15**, unmoved since D15 — door 3 (`show`) keeps compose HOOK-UNRESOLVED.
ABI at **15 rows + 5 added types**, still `5.0`; **the `proc_exec` rename forces `6.0`** and is a
release decision with consumers outside this project. Profiles at `driver_only` **19**,
`driver_plus_no_ops` **6**.

Open, roughly by readiness:

1. **The typed subprocess discrimination** — now unblocked by D22's `exit_code`; blocked only on
   `dispatch_one`'s `(workdir, ToolCall) -> string` contract.
2. **The eighth recording adapter + `ExtCtx.ext_id`**, which is what `ExtensionEffectIdentity` actually
   needs. `absent_classes` stays untouched until it lands.
3. **`on_pre_step` and `on_solver_candidate` successor audits.** Base rate **2 of 2** (S29).
4. **C5's compose-bearing profile** — no graded profile installs compose, which is why D19 had to build
   a scenario to make its own tripwires fire. A growing debt.
5. Door 3's producer; the hook-scope promotion (needs a review round); the scratchpad loopback
   successor (`tool_envelope_dispatch.ail:44`); the eight stale classifier-2 literals (**ten items
   stale**); classifier 1's repair; the stdlib cache's producer; the gate-table State column; F3.

## Read order for a cold start

`ADR-001` §Context and the eleven-row table → the plan's **S1–S33** block → the last three milestone
entries → this note. **Then measure something before you write anything.**
