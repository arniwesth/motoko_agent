# Handoff: WI-D28 — the final acceptance rerun: the closing note

Audience: a fresh session grounded against HEAD (`742af22`). **The last item on the goal line's
critical path.** Its deliverable is a DOCUMENT — `NOTE-d28-…`, the project's closing note — in
D5's shape (the eleven answers, then the name decision) plus the two computed outputs the goal
line names: **S21's vacuity register as a computed result**, and **the 15-row classification
table**. When this note exists and its apply lands, the goal line is banked and the loop inverts
to the soft taper.

**Read first:** the goal-line section end to end (both clauses are this note's acceptance test,
and §Renounced bounds what the note may not claim); `NOTE-d5-…` (the shape: eleven answers →
verdict → gate state); `NOTE-d27-…` §10 (the machine-readable inputs, enumerated for exactly this
item).

## The discipline, before the content

1. **Every number in the note is command-traceable.** A figure with no command beside it is
   narration, and narration is what this document exists to replace. Run the gates; paste what
   they print.
2. **Nothing is fixed in passing.** A finding — a red row, an uncounted leaning, a stale claim —
   is REPORTED in the note and goes to the maintenance register. The closing note's integrity is
   that it measures the tree as it stands, not as one more item could make it.
3. **No re-arguing.** The eleven rows were argued at C4 and D5; this rerun RE-RUNS them and
   records what changed since D5's answers. Deltas, with their producing items named.

## Part 1 — the eleven answers, re-run

The table is `ADR-001` §"Acceptance test for the name" (`ADR:2533`). For each row: the gates that
produce its evidence (re-derive the row→gate mapping from D5's note rather than from memory — D5
answered all eleven and named its evidence), run them at HEAD, record the answer and the delta.
The deltas this session's grounding already knows about, which the rerun must confirm rather than
inherit:

- **Row 3 (the honest boundary)** is transformed: three profiles now, the first non-empty
  `excluded` list, per-extension covered/excluded **ids** non-vacuous, and the coverage floor,
  exclusion rule and disclosure all exercised (D27).
- **Row 5 (virtual time)** was re-earned on routing rather than absence (`clock_now` through the
  world — D19/D27 §3.3).
- **Row 6 (production logic)** and **row 9 (discovery/replay stability)** now have the strongest
  instance in the tree: a real traced session with an installed effectful extension, recorded,
  validated, strictly replayed (D27's demonstration).
- **Row 4 (faults reach production recovery)**: `extension_effect_fault`'s waiver condition
  changed shape across three profiles (D27 §3.4 — the catalogue names `driver_only` verbatim);
  report the waiver's state per profile honestly.
- **Row 10 (hermeticity)**: the compose profile GRANTS `Env`/`FS` across registration, disclosed
  bidirectionally (D27 §6). The row's answer must carry that boundary statement — hermeticity is
  enforced *per profile*, and the compose profile's determinism claim rides the replay identity.

If any row is **RED at HEAD, stop and report** — a red acceptance row blocks the verdict and is
not this item's to fix.

## Part 2 — the vacuity register, computed

S21's obligation, finally as output rather than prose. The known state going in: the count stood
at **four** leanings after D5 (row 3's install list, row 4's two-reason waiver, row 5's
absence-grounds, row 7's `ScratchpadResult` exemption), and D27 changed three of them — row 3
carries a red-capable assertion now, rows 5 and 7 were re-earned on routing and on
exclusion-plus-absence. **Compute what remains**: fold the three profiles' `CLASSIFICATION` /
`STATEMENT` lines (nine fields, identical shape across all three scripts — D27 §10.1), enumerate
every surviving exemption in every row, and for each state what it leans on and which profile's
evidence, if any, un-leans it. **The register does not shrink to zero and was never meant to**
(the goal line renounced that); vacuous entries that remain are LISTED with their reasons —
`driver_only`'s four leanings did not vanish because a third profile exists. If the fold finds a
leaning nobody counted, that is a finding: include it, register it, do not fix it.

## Part 3 — the classification table, 15 rows, computed

Clause 2's acceptance: every extension **mediated** or **disclosed with a measured reason**, no
UNRESOLVED cell without a disclosure attached. The producers and the cell algebra:

- `python3 tools/ext_ambient_inventory/derive.py --json` — per extension: `verdict`, every ambient
  source as `{file, line, symbol, effects, why}`, `ext_ports_calls` (verified working at HEAD,
  `source_revision` in the output — quote it).
- The hook-scope producer — the current distribution is **5 HOOK-PORT-MEDIATED, 2 HOOK-AMBIENT,
  8 HOOK-UNRESOLVED**; for each UNRESOLVED, the producer's own rejection reason names the door.
- The `DISCLOSED` lines (registration, compose) and the disclosed-by-decision classes
  (`println`, ambient AI) — the goal line's own enumeration.

A **mediated** cell cites the hook-scope verdict. A **disclosed** cell cites the ambient sources
(file/line/symbol/effects) and the class each belongs to. An **UNRESOLVED-verdict** cell closes by
disclosure of the door with its measurement — door 3 (`show`: no producer at HEAD can classify a
non-underscore builtin; the textual route was tried and discarded because it invents evidence,
D15) and any sibling doors the 8 rest on. Both units appear per row where they differ (closure
verdict AND hooks verdict) — presenting both requires no promotion decision, which stays on the
register. **Compose's cell is the model** (D27 §10.2): *mediated on dynamic evidence over a
recorded run; classifier 3 reports AMBIENT with 8 sources in three disclosed classes; tool path
excluded*.

**The upstream filing for door 3 is in scope and bounded.** The goal line closes door 3 by
disclosure **plus an upstream filing**. File it through the established channel (the
`ailang-feedback` skill / `submit_feedback` — the project's precedent is the recorded-stream
request): the ask is a way to resolve non-underscore language builtins (`show`, `intToFloat`) as a
classifiable unit — cite D15's measurement and the discarded textual route. The table's door-3
cells cite the filing.

## Part 4 — the name decision, and the taper

D5's verdict was YES on the evidence then. Re-answer with the evidence now — the two clauses, the
demonstration, the register's computed state — and say what the answer rests on in one paragraph.
Then the note's final section states the transition the goal line prescribes: **the goal line is
reached; the loop inverts to the soft taper** — the maintenance register (reproduce it, at its
closing state, with the additions this note makes) becomes the queue's only source, at reduced
cadence, continuation explicitly labeled maintenance. Include the three standing reds and the
counters at their final full-cadence state (**silent-wrong 76; instrument-weaker 7** — plus
anything this rerun's own measurement adds under the standing rulings).

## Mechanization, decided by the item

A small aggregator (a script or make target folding the `CLASSIFICATION`/`CLAIM` lines into the
register and table) is welcome if it DERIVES from the printed lines rather than pinning copies —
but a one-shot closing document does not require permanent machinery, and building an instrument
this late must not become the item. If built: it joins the sweep; if not: the note shows the fold
commands verbatim. Either is honest; say which and why.

## Definition of done

1. `NOTE-d28-…` exists with all four parts; every gate it cites was run in this session; every
   number traceable.
2. The eleven answers each carry answer + delta + evidence commands. No row red (or the item
   stopped and reported).
3. The register computed, with survivors listed and the fold shown; the table's 15 rows complete
   with no bare UNRESOLVED.
4. The door-3 filing submitted via the channel and cited.
5. Yields, inventory, profiles, counters, standing reds — final states recorded, all by run.
6. Nothing else changed: no source edits beyond the optional aggregator and the filing artifact;
   no gate weakened, no row re-argued, no register item fixed.

## Out of scope, absolutely

Everything on the maintenance register — including the three standing reds, the
registration-effects amendment, the hook-scope promotion, the `proc_exec` rename, the fault
catalogue's `driver_only`-naming condition, and every finding this rerun itself produces. The
closing note reports the tree; it does not improve it.

## Stop and report rather than deciding inline

- Any acceptance row red at HEAD.
- The register fold finding the evidence lines inconsistent between profiles (a schema drift in
  the nine fields would poison the computation — that is an instrument finding).
- Clause 2 unclosable for any extension without a build — that would mean the goal line's
  "disclosure is a decision plus a measurement" premise fails somewhere, which the user decides,
  not this item.

## Report back

The note IS the report. Its apply — the plan's final full-cadence milestone entry, the verdict on
the verdict, and the taper's activation in the protocol note — is the reviewing session's last
act of the critical path.
