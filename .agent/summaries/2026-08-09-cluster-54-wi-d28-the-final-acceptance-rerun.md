# 2026-08-09 Cluster 54: WI-D28 — the final acceptance rerun, and the goal line banked

## Context

Branch: `arniwesth/mot-90-wi-d28-the-final-acceptance-rerun-the-closing-note`.

Session span: HEAD `b3953a9`, clean tree at start and at the end of this item's measurements.
Input was `HANDOFF-execute-d28-the-final-acceptance-rerun.md`, grounded against `742af22`. Pin
**v0.33.0**. Fifty-second calibration run.

**A concurrent reviewing session overlapped the tail of this one** and is recorded rather than
elided: at `18:08:59Z` — 18 minutes after this item's sweep finished and 4 after the note was first
written — it wrote the WI-D28 apply entry into the plan and started its own `make dst`. **No
measurement in this note was taken after `18:01Z`**, verified against file mtimes, so nothing here
overlapped a second gate run. D4's lesson is that a concurrent sweep poisons silently; the S9 check
is worth running at the end as well as the beginning, and this is the first item where it mattered.

**Item 6 of the goal line's six-item critical path — the last one, and the only item in the
D-wave whose deliverable is a document rather than a change.** One file from this session, plus one
artifact that does not live in this repo:

```text
.agent/.../NOTE-d28-the-final-acceptance-rerun.md    1012 +   the closing note (new)
upstream filing fb_0f70d66af0fddb2c                        —  door 3, queued 2026-08-09T17:53:32Z
```

**No source edits. No gate weakened. No register item fixed.** Six findings were produced and all
six were reported rather than repaired — the closing note's integrity is that it measures the tree
as it stands, not as one more item could make it. A scratch four-line `repro.ail` was written to
measure the door-3 filing's claim and deleted afterwards; `git status` is clean apart from the note.

## The headline — both goal-line clauses hold, and the register is finally a number

**Clause 1, the demonstration:** `driver_plus_compose` v1 records a real graded session with compose
installed and replays it strictly — `CLAIM clause1 extension_effects=1 origins=[compose]
replayed=1 mismatches=0`.

**Clause 2, the disclosure table:** all fifteen extensions mediated or disclosed with a measured
reason, **zero bare UNRESOLVED cells**. Door 3 closes by disclosure plus the filing.

**Eleven of eleven acceptance rows hold at HEAD, no row red**, so none of the three stop-conditions
fired.

And the thing the item existed to produce — S21's obligation as an output rather than prose:

```
$ cat *.raw | grep '^CLASSIFICATION ' | awk '{print $4,$5,$6,$7,$8,$9}' | sort | uniq -c | sort -rn
  20  effect_free          declared_row           assumed   not_applicable not_applicable not_applicable
  16  world_mediated       ext_ambient_inventory  measured  vacuously      vacuously      substantively
   2  world_mediated       discovery              measured  vacuously      vacuously      substantively
   1  world_mediated       discovery              measured  substantively  substantively  substantively
   1  explicitly_excluded  disclosure             assumed   not_applicable not_applicable not_applicable
```

**Forty classification entries across three profiles. Nineteen are criterion-2; eighteen of those
satisfy the ports and origin-tag clauses vacuously. Twenty-one of forty rest on an ASSUMED basis.
So exactly ONE of forty rests on a basis that is both measured and substantive** —
`compose`/`on_response_intercept`, under `driver_plus_compose` v1, basis `discovery`.

That single number is the computed answer to the question S21 was written to ask: *what does this
green table actually rest on*. It is not a defect — clause 1 asked for *a* demonstration and this is
it. Stating it as one-of-forty is the difference between reporting the demonstration and
overclaiming from it, and it became the successor to D5's mandatory zero-coverage caveat.

## The eleven answers — what moved since D5

Every producer was re-run in this session; nothing was read forward. Five rows moved:

| Row | What changed |
|---|---|
| **3** | **Transformed.** Three profiles; the coverage floor, the exclusion rule, clause 2b's two-field agreement and the per-extension **ids** are all non-vacuous; `driver_plus_compose` carries the project's first non-empty `excluded` list |
| **4** | Identical numbers (9 of 11 classes, 9 of 11 branches, the wire witness byte-for-byte D5's). What changed is the `extension_effect_fault` waiver's **ground**: construction (`driver_only`) → measured inapplicability (`driver_plus_no_ops`, `ext_ports_calls=0`) → a per-**field** fact (`driver_plus_compose`, `ai_step_calls=0`, with an effectful extension installed) |
| **5** | **Re-earned on ROUTING rather than absence.** `driver_plus_compose` is the first profile whose install set reads a clock at all — compose's intercept calls `clock_now` through `ExtPorts` |
| **6, 9** | Same verdicts, strongest subject the tree has ever had: a real traced session with an installed effectful extension, recorded, validated, strictly replayed |
| **10** | The answer now carries a boundary statement. The compose profile **grants `{Env, FS}` across registration**, so the poison pairs say nothing about it; the determinism claim rides the record → strict-replay identity instead. **Hermeticity is enforced PER PROFILE**, and the note says so |

Row 7 still passes on D2's stated reading — the single interpretive dependency, reported rather than
buried, exactly as D5 left it. Its `ScratchpadResult` exemption was re-earned twice on grounds that
are not emptiness, and **survived both times**.

## The register: three grounds replaced, four exemptions surviving

D5 counted four leanings on the empty install list. **All four still exist. Three had their ground
replaced by a measurement. None was removed.** That distinction is the whole of S21 and it is why
the register does not shrink — which the goal line renounced in advance.

- **Row 3** — clauses 1, 2, 2b and 4 are now non-vacuous. **Clause 3 is not, in any profile.**
- **Row 4** — the class is waived by *every* profile in the tree. Un-leaned by nothing.
- **Row 5** — re-earned on routing, but the routed-set claim is `7 = 6 + 1` in all three profiles:
  **installing extensions added no reachable core site in any of them.** The row's extension
  dimension rests on one routed clock read in one profile.
- **Row 7** — re-earned twice; both variants still never reach the returned trace.

## The finding that matters most: a vacuity that belongs to a PRODUCER

**Row 3's clause 3 — "no installed extension calls a classifier-2 `ExtPorts` field" — is vacuous in
all three profiles, and would be vacuous for a profile that installed all fifteen.** The
classifier-2 member set has been empty since WI-B2b, so the clause quantifies over an empty
predicate no matter what any install list contains. `profile_definition` has printed
`! note: check 3 is now VACUOUS (zero classifier-2 member call sites)` on every run; **what did not
exist was anything that counted it.**

**This is the first leaning in the register that no install list can buy**, and it is exactly S21's
shape one level deeper: every per-profile question the project has ever asked would return
"non-vacuous" for this clause forever, because the profile is not where the emptiness lives. D5
found the fourth leaning by asking of each surviving exemption *why* it survives; the same procedure
found the fifth, and it turned out not to be a profile's at all.

## The 15-row classification table — both units, no bare UNRESOLVED

Producers: `derive.py --json` (closure unit, `source_revision` = HEAD in its own output) and
`derive.py --hook-scope` (`make ext_hook_scope`). Yields unmoved: **closure PORT-MEDIATED 4 of 15 ·
AMBIENT 11**, against **HOOK-PORT-MEDIATED 5 of 15 · HOOK-AMBIENT 2 · HOOK-UNRESOLVED 8**. The two
mediated sets are **not nested** — hook scope adds `mcp` and `test_dummy`, drops
`compaction_structural`.

**Both units appear on every row where they differ**, which requires no promotion decision; the
hook-scope promotion stays on the register where D15 left it.

**44 ambient sources across the fifteen closures, in four classes**, each with file, line, symbol
and effect set:

| Class | Sources | How it closes |
|---|---|---|
| registration effects | **26**, 10 extensions | the per-process capability measurement (S22/D6/D13) |
| hook-path ambient, unrouted | **13**, 7 extensions | measured per site; no profile installs any of the seven |
| `println` | **4**, all compose | by decision |
| ambient AI | **1**, compose | by decision — and why `on_tool_handle` is EXCLUDED |

**The doors, which are rejections rather than sources: 17 distinct rejection sites.** `show` at 15
(blocking 8 extensions — `packages/motoko-ext-mcp/exec.ail:6` is shared by `ailang_docs` and
`exa_search`), `intToFloat` at 1, and one `applied-local` at 1.

**Compose's cell is the model the handoff named:** *mediated on dynamic evidence over a recorded
run; classifier 3 reports AMBIENT with 8 sources in three disclosed classes; tool path excluded* —
and it says `discovery` is **EXISTENTIAL** in as many words, because a cell reading bare "mediated"
would be the overclaim D27 built the whole rules change to avoid.

## Door 3 — filed, not worked around

`submit_feedback` (the `ailang-feedback` skill's channel 3, the route the recorded-stream request
used). **Ticket `fb_0f70d66af0fddb2c`, queued `2026-08-09T17:53:32Z`, category `limitation`.**

The ask: a machine-readable way to resolve a non-underscore language builtin to the same evidence
`ailang.iface/v1` already gives a `std/*` export. Three shapes offered; the first — an `iface.json`
for the prelude/builtin namespace — preferred because the classifier already reads that schema.

**The measurement was re-run in this session rather than quoted from D15:**

- `ailang check repro.ail` accepts a four-line module applying `show`; `ailang iface` on it emits a
  clean `ailang.iface/v1` document in which **`show` appears nowhere**.
- **553 cached `std__*/iface.json` files in this checkout, zero carrying a `show` entry** — parsed,
  not text-matched (S28's lesson applied to my own measurement).
- `ailang iface` takes a module path and has exactly one flag (`-compact`); no builtins mode.
- D15's discarded textual route is described in full, including that it classified `f` EFFECTFUL and
  `p` PURE. **A rule that invents evidence is worse than one that reports its absence** — that
  sentence is in the filing, because it is why the door is disclosed rather than worked around.

**And a caveat the filing does not cover:** compose's third door is an `applied-local` rejection at
`ai_compat.ail:6` — a receiver-resolution limit in *our* tool, not a language-builtin limit in the
toolchain. A reader who closes door 3 and expects compose to clear would be wrong.

## The other five findings, all reported and none fixed

1. **The fault catalogue's condition names `driver_only` verbatim** — three profiles now record it,
   two of them recording a sentence about a different profile. Fourth artefact to carry it.
2. **`driver_only` emits no coverage statement at all** — zero `CLASSIFICATION` lines, zero
   `STATEMENT` lines, and the string `coverage` absent from its output. The ZERO branch of
   `coverage_statement` exists and is fixture-tested (`dst_profile.ail:2043`); the record carries
   `hook_classifications: []` (`dst_driver_only.ail:677`). **D5's own correction 4 — "what the label
   does not assert needs to be a checked artifact, not prose" — is still open**, and the two
   successors got the mechanism the baseline never had.
3. **D27 §10.1's "identical shape across all three scripts" is two scripts**, not three. Not schema
   drift: the fields agree exactly, which is what made the fold legal, and `driver_only`'s absence
   is a genuine vacuity. **The schema-drift stop-condition did not fire.**
4. **D27 §10.2's "twelve extensions have no profile and no dynamic evidence" is two figures collapsed
   into one, and neither is twelve.** Re-derived from the profiles' own `INSTALLED` lines: the union
   of every install list is **five**, so **ten** are in no profile, and **fourteen** have no dynamic
   evidence. S22's shape, in inherited prose from this role.
5. **One seeded-generator digest moved** — `722021275` where D5 recorded `2144863192`, at the same
   `n=23` and with the second digest byte-identical. Recorded so no future note quotes D5's constant
   forward as if it were pinned.

## Mechanization — decided, and stated rather than assumed

**No permanent aggregator was built.** The fold commands are printed verbatim in the note and derive
from the profiles' own printed lines rather than pinning copies. Three reasons: the fold is four
lines of `grep`/`awk`; a permanent one needs a home in the sweep, another consumer in the
eleven-file anchor cascade and a fixture set of its own; and **the thing worth mechanising is not
the fold** — it is finding 2, one `STATEMENT` line in `driver_only_dst.ail`, which would make the
aggregate computable from three profiles instead of two. That is the taper's first instrument.

## Sweep, counters, and one methodological difference from D5

`make dst`, logged to a file, no tracked file touched while it ran, no concurrent `ailang`.
`17:35:10Z` → `17:50:37Z` (**15m27s**), **1029 ✓ rows** against D5's 845. **EXIT 2, red set exactly
`test_coverage` and `test_coverage_selftest`, both pinned since D22, and nothing else.**
`effect_inventory_selftest` run separately is unchanged (`agree=0 disagree=0`, the gate correctly
refusing a pass-shaped absence, pinned D25). **Three standing reds, no new ones.**

Final states, all by run: profiles `driver_only` **v22** · `driver_plus_no_ops` **v9** ·
`driver_plus_compose` **v1**, none re-issued; `profile-rules/3` with 4 measured producers; barriers
**33 of 45**; ABI **5.0**, 10 sites across 6 files; anchors `no drift: 6 anchors and 7 references`;
`declared_vs_performed` **46 passed 0 failed**; `hook_guard` **4 passed 0 failed**; inventory
**15/15 extensions, 18/18 std modules, 0 unresolved symbols**.

**Counters UNMOVED: silent-wrong 76 across 49 runs; instrument-weaker-than-its-claim 7.** This item
wrote no production code, so neither counter had a candidate.

**One methodological difference from D5, stated rather than glossed:** this sweep was **not
cache-cold in D5's sense.** Four `.ailang/cache` directories were cleared (the set
`ls -d */.ailang/cache` matches); `find . -type d -name cache -path '*/.ailang/*'` reports **48** in
the tree, including one per extension package. Nothing turns on it — a warm cache cannot turn a red
row green, and `derive.py` establishes its own precondition (`provision_failures: []`) — but a
run-time comparison against D5 would be comparing two different measurements. Per S19 the four
`/tmp/*.out` artifacts were deleted first, so every artifact row was written by this run.

## What the apply owes, and what happens after

The reviewing session's last act on the critical path:

1. The plan's **final full-cadence milestone entry** for WI-D28.
2. **The verdict on the verdict** — measure the central claims, per the protocol's one rule. The
   cheapest three: re-run the fold and confirm the `20/16/2/1/1` distribution; confirm
   `driver_only_dst.ail` emits no `STATEMENT` line; confirm `make dst` is EXIT 2 on exactly the two
   `test_coverage` targets.
3. **The taper's activation in `NOTE-review-protocol.md`** — the maintenance register becomes the
   queue's only source, cadence drops, continuation is explicitly labelled maintenance, standing
   rules are earned only by exception, counters continue as fix-or-file.
4. **Nineteen register entries** carried forward — nine from the goal-line decision, one each from
   D25 and D26, two from D27, six added here (one of which escalates a D27 entry rather than adding
   to it).

## Two corrections that arrived from the concurrent apply, and one defect it exposed in this note

The reviewing session ratified the verdict and applied it. Two things came back:

1. **A review ruling on the counters:** *"the run denominator increments with the item per the
   standing convention, so 76 across 50."* The note records **76 across 49 runs**, inherited from
   D27. The ruling supersedes it and lives in the plan; per S15 the note is left as written rather
   than silently re-dated. **The count 76 itself is unmoved** — only the denominator.
2. **A defect in this note's own §9.1, found because the apply mis-read it.** The register list
   numbered only two of its four blocks, so its last index read **16** while the count was **19**,
   and the apply entry took sixteen. **A register whose last index is not its count is a register
   that reports the wrong number to every reader**, which is the exact failure mode S21 exists to
   catch, committed inside the document computing S21's answer. §9.1 is now numbered continuously
   1–19 with the count stated in its heading. **The plan's apply entry still says sixteen and needs
   the correction** — flagged rather than edited, because the plan is the review role's file and
   that session is actively writing it.

**Fifty-one calibration runs built and measured this axis. The fifty-second says what it rests on,
in a number, and stops.**
