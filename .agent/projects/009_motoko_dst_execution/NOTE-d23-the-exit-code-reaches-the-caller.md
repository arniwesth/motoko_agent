# WI-D23 — the typed exit code reaches the caller

**Result: ALL FOUR REMAINING LINKS SHIPPED AND THE ADOPTION ROW DROVE THE CLOSURE.** The typed
sibling exists and `dispatch_one` is its projection; `world_tool`'s live arm binds both of the
sibling's fields; `ExtProcOutcome` carries `exit_code` at ABI `5.0`; and the bridge projects
`ToolCompleted.exit_code` through the seam that existed for four items with no caller. No stop
condition fired. One visibility change was needed on contact — an `export`, not a signature — and
the seam itself worked on the first call.

---

## 0. THE HEADLINE

**The surface built across WI-D16..D22 survived its first caller without a shape change.** Four
items built and measured this seam with nothing calling it; the handoff asked explicitly whether
anything would need changing on contact. Measured: the bridge closure, the codec, and the typed
sibling composed on the first run — the adoption row (a scripted exit code 5 through
`ext_ports_of`'s own `proc_exec` closure) was green the first time it executed. The one thing
contact demanded was VISIBILITY: `ext_ports_of` was private to `session.ail`, and S14's
two-subjects rule forbids substituting a substrate probe for the real bridge, so the function is
now exported with the reason at the site. That is the entire cost of first contact.

**And one expectation of the handoff did not survive measurement: the fault-catalogue gap is
NARROWED, not closed** (§6).

---

## 1. The git wall-clock window

Handoff commit `338156c` at `2026-08-09T08:39:56Z`; commit closing the item at ~`09:22Z`. **The
window is ~42m**, against D22's ~1h25m, D21's ~1h03m, D20's ~1h13m — the shortest of the run,
and the reason is the handoff's own accuracy: every one of its seven census sites, three
re-tense targets and two named obstacles survived re-derivation, so the time went to building
rather than correcting. It divides: ~20m grounding (every handoff row re-measured per S22, and
two harness facts that changed the test plan — §5), ~15m edits, mutants and cascade, and the
sweep ran unattended (~15m wall, overlapping this note).

---

## 2. WHAT SHIPPED, PER LINK — the handoff's table, closed out

| # | Link | What shipped |
|---|---|---|
| 4 | `dispatch_one`'s contract | **`dispatch_one_typed -> { content: string, exit_code: int }`**, and `dispatch_one` is now the one-line projection `dispatch_one_typed(...).content`. The upstream `(workdir, ToolCall) -> string` contract did not move. The defensive zero-or-many arm carries **1** — an error surface gets the error mapping's code, not `0` (a success no process produced) and not `-1` (which would file an adapter defect under "no subprocess ran") |
| — | the per-variant mapping (S23) | **`tool_result_exit_code`**, one accessor. `tool_result_item_to_json`'s seven per-arm literals (four `0.0`, two real fields, one `1.0`) now read it, and the typed path reads the same function — the JSON a model sees and the field a caller branches on cannot drift |
| 3 | `world_tool`'s live arm | binds **both** of the sibling's fields from one dispatch. The site comment's "OUT OF THIS ITEM'S SCOPE" clause re-tensed two-part per S15 |
| 1 | `ExtProcOutcome` +`exit_code: int` | shipped at **ABI `5.0`**, per the D16/D17/D18 precedent: extensions READ this record — the harness constructs it — so the widening is additive for every consumer, categorically unlike the `proc_exec` rename (which invalidates every `ExtPorts` literal and stays deferred at `6.0`). The expired "WHICH IS WHY THE SECOND WIDENING IS STILL NOT TAKEN" paragraph re-tensed two-part; the D21 measurement paragraph above it kept verbatim |
| — | the unnumbered link: the bridge | **`tool_outcome_exit_code`**, a second projection beside `tool_outcome_text`, deliberately not folded in — the string is the model-facing message and is byte-unchanged. `ToolCompleted(c) => c.exit_code`; the three fault variants `-1`, because none of them is a process that exited and their discrimination already travels rendered in `output` |
| — | content/field authority | decided and written at the codec (`encode_tool_outcome`'s header): **the typed field is authoritative; `content` is an opaque rendering this schema makes no claims about.** No validator parses content's JSON — the stop-and-report parser was never needed |

Links 2, 5, 6, 7 were D22's and were re-verified at HEAD rather than inherited, exactly as the
handoff's own table did.

## 2.1 The construction census, as executed

**SEVEN sites, re-derived by grep over `ExtProcOutcome` constructions per S22 — and the handoff's
seven survived re-derivation exactly.** The bridge (`session.ail`) binds the projection; the six
noops write `exit_code: -1` with the reason at each site (a no-op executes nothing; `0` asserts a
success no process produced): `ctx_defaults.ail`, the three guard/conformance packages,
`declared_vs_performed.ail`'s probe, `long_qwen_compaction_dst.ail`'s fixture.

**The three parameter-name stragglers were renamed with the census**: `ctx_defaults.ail`
(`_cmd, _cwd` — the sixth binding D21's rename census missed, said so at the site),
`declared_vs_performed.ail` (`_cmd, _args`), `long_qwen_compaction_dst.ail` (`_name, _args`). All
three now read `_tool, _args_json`. This does not move the silent-wrong counter: the SITE (the
seam's two positional strings) is the one D21 already counted; these are additional bindings of
the counted site, recorded as census corrections rather than new defects.

---

## 3. THE THREE ROWS, AND WHY THEY LIVE WHERE THEY LIVE

All three are in `scripts/dst/world_state_probe.ail` under a NEW entry point,
`exit_code_witness`, invoked by `make world_state` under full caps. Two harness facts forced that
shape, and both are worth more than the inconvenience they caused (§5):

1. **`ailang test` grants no capabilities and has no `--caps` flag** — measured with a scratch
   module performing `Process` under a declared row: "effect 'Process' requires capability, but
   none provided; Hint: Run with --caps Process", and the hint's flag does not exist on the test
   runner. So the rows cannot be inline `tests` blocks; they must be `ailang run --caps` entries.
2. **`world_state_probe.main` must COMPLETE with Process withheld** — it is the subject half of
   the typed-tool poison pair ("fully-seeded world completes with Process withheld"). A real
   subprocess in `main` would turn the pair's subject into its control. Hence the separate entry,
   with the reason in its header.

The rows, with S7-distinct quantities (7, 5, 3, duration 11; `-1/0/1` semantically loaded, 137
taken by D22's round trip):

| Row | Subject | Value |
|---|---|---|
| live | a real `BashExec` through `world_tool`'s `[]` arm, `cmd: "exit 7"` (space → `bash -lc` wrap) | typed `exit_code == 7` |
| adoption | **`ext_ports_of`'s own `proc_exec` closure** — not a substrate probe — against a world seeded with a `ScriptedTool` carrying 5 | `ExtProcOutcome.exit_code == 5` AND `output == "d23-scripted"` |
| projection | `dispatch_one` and `dispatch_one_typed` on one call exiting 3 | byte-identical content AND `exit_code == 3` |

**The adoption row drove the closure, per S14's two subjects**: the live row alone proves the
substrate; only the adoption row proves OUR bridge hands the value across the ABI, and it is the
row that went red when the bridge projection was dropped (§4). It passed on first execution
against the finished chain — §0's finding.

---

## 4. THE MUTANTS: 3 applied, 3 killed their named row

Save and restore by file copy per S17; restore verified byte-identical by `diff` against the
snapshot AND by re-running the witness to green.

| Mutant | Edit | Named row | Result |
|---|---|---|---|
| M1 | live arm reverted to `exit_code: -1` | live | **✗ live only** — adoption and projection stayed green, which is precisely the handoff's warning that every in-process fixture is blind to this arm |
| M2 | sibling hardwired to `exit_code: 0` | projection | **✗ projection** (`got 0`), and the live row went red with it — expected, since the live arm now feeds from the sibling. The projection row exists because M2 is the one mutant the 7-row and 5-row cannot pin alone if the live arm is also mutated |
| M3 | bridge projection dropped (`exit_code: -1` at the closure) | adoption | **✗ adoption only** (`got exit_code -1`) — the two rows below the ABI cannot see the bridge, which is why S14 demanded this subject |

---

## 5. HARNESS FACTS DISCOVERED ON CONTACT, recorded because the next item will hit them

1. **`ailang test` runs capability-less and its own error hint suggests a flag it does not
   have** (§3). Effectful inline tests exist in `session.ail` (`! {IO, Trace}`) and pass, so IO
   and Trace appear exempt; Process is not. Any future row that performs a real effect belongs in
   an `ailang run --caps` entry point, not a `tests` block.
2. **A first draft of this section claimed `session.ail`'s inline tests run in no target, and
   the sweep falsified it** — `make test_coverage` discovers and runs every src/core inline
   suite, session.ail's 23 included (it reported them 23/23 this run). What is true is narrower:
   no target invokes `ailang test src/core/session.ail` BY NAME, and the discovered run is
   capability-less, which is fact 1's constraint. Recorded with the correction because the wrong
   form nearly went into this note as a finding.
3. **`ext_ports_of` is now exported** — the one seam change contact demanded, visibility only.
   The export comment pins the production call-site census: exactly four `mk_v2_ext_ctx` sites.

---

## 6. THE FAULT-CATALOGUE ENTRY: NARROWED, NOT CLOSED — a deviation from the handoff, measured

The handoff's counter section says this item "closes the gap the fault catalogue's coverage-gap
entry has named since C5: *an extension can observe that a tool failed and not which fault class
it was*". **Measured against the entry's own sentence, that is half true, and the half matters.**
An extension can now observe that a subprocess failed — and with what code — typed, without
parsing a string. What it still cannot observe is WHICH FAULT CLASS a non-completed outcome was:
`ToolFailed`'s D3 code, a mismatch's two ids and a deadline's two times all cross the ABI rendered
into `output`'s fault text, projected to `exit_code: -1`. The four-variant discrimination is a
further widening on D1's part-3 ground, exactly as the `ExtProcOutcome` note has said since D16.

The entry is re-tensed as **"NARROWED A THIRD TIME AT WI-D23"** — the catalogue's own idiom for
this (B4 narrowed ai_step, C5 narrowed the clock) — rather than deleted. Deleting it on the
handoff's word would have retired a residue that is still real.

---

## 7. THE CASCADE: fired as priced, six-file form, +35

The bridge work sits at and above `ext_ports_of`, so all five `session.ail` clock anchors moved
`1061/1320/1426/2871/2981 -> 1096/1355/1461/2906/3016`, all +35. Each anchored expression
compared character-for-character against `git show HEAD:` — **byte-identical, pure offset
drift**. `tool_phase.ail:318` did not move, so the three discovered-site fixtures were untouched:
the six-file `session.ail`-only form, exactly as D21 §11.1 predicted.

| File | Change |
|---|---|
| `tools/predicate-anchors/anchors.sh` | the five-element loop + the fifth re-baseline's history note |
| `src/core/dst_attribution_table.ail` | five rows + the `:657` test literal |
| `scripts/dst/attribution_table_dst.ail` | the `omitted_site` fixture literal |
| `src/core/dst_driver_only.ail` | version **19 → 20**, hash re-recorded |
| `src/core/dst_driver_plus_no_ops.ail` | version **6 → 7**, same hash |

`sha256:c007fb3e… -> sha256:f23a1166…` (derived by running `table_content_hash()`, not
hand-computed); `source_revision` unchanged at `c0fbf10` per D4's rule. Per S18, every comment
re-tense was finished BEFORE the anchors were computed, so they were derived once.

---

## 8. WHAT WAS RE-TENSED, all two-part per S15

1. `types.ail` — the ABI row's "SECOND WIDENING IS STILL NOT TAKEN" paragraph (the widening is
   taken; the old reason quoted, then the new state). The D21 measurement paragraph above it:
   untouched, still exactly right. The "WHAT IT REACHES" clause gains "and — since WI-D23 — typed".
2. `ports.ail` — the live arm's scope clause (now states the closure and names the mutant its
   witness row kills); `ScriptedTool`'s "WHAT DOES NOT SET IT TODAY — nothing" paragraph (now
   "WHAT SETS IT", with the D22 sentence quoted and the -1 writers enumerated).
3. `session.ail` — the seam comment's "the remaining gap… scheduled rather than absorbed"
   paragraph, and the "PROJECTED onto a string" paragraph (now "PROJECTED TWICE", with the
   fault-class residue pointed at the catalogue entry).
4. `compose.ail` — the D19/D21 note's "the deterministic side has none… program-schema version
   bump" clause: the typing obstacle is gone, and the note now names the REAL blocker (the
   identity work — the blank call id's rejected program, D21 §4/S27) instead.
5. `author_tools.ail` — the rg note's "the exit code has to become a TYPED field, which is a
   program-schema bump": the field exists; the two remaining obstacles (byte-stdout shape, the
   identity blocker) named with pointers rather than restated.
6. `dst_fault_catalogue.ail` — §6's narrowing.
7. `ctx_defaults.ail` + the two dst probes — §2.1's renames, with the missed-census fact at the
   ctx_defaults site.

---

## 9. THE COUNTERS, KEPT APART

**Silent-wrong: 75, unchanged, across forty-five runs.** No new production site where two answers
type-check and the wrong one ships was found. The three renamed bindings are additional instances
of the site D21 already counted (§2.1). The defects this item authored and closed in the same
commit (none survived to a test failure) count nothing, per D22's rule.

**Instrument-weaker-than-its-claim: 7, unchanged.** D21's rename census claiming five bindings
when the tree held eight is a defect in a NOTE's claim, not in an instrument — no row measured
less than its label. Recorded here as a census correction; if the project ever counts note-claim
errors, D21 §6 gains one.

---

## 10. THE YIELDS AND THE AMBIENT INVENTORY — asserted, not assumed

Re-run after all edits: `ext_hook_scope_selftest` **5 of 15** HOOK-PORT-MEDIATED, shipped closure
verdict **4 of 15**; `ext_ambient_inventory` PORT-MEDIATED **4 of 15**, compose **11 ambient
sources, 32 ExtPorts field calls**. All unmoved — this item added no seam and routed no caller,
so a moved yield would have meant an instrument reading something other than what it claims.
Compose's `std/process.exec` stays ambient at three import sites / four call sites, for the S27
reason the handoff carries: the first `proc_exec` call in a recorded run still emits a program the
validator rejects, so routing waits on the eighth recording adapter and `ExtCtx.ext_id`.

---

## 11. THE SWEEP

`make sync_packages` re-run **after** the `types.ail` edit (and again after the compose re-tense
moved the lock — D22's stale-lock lesson held twice). `check_core`: **56 passed, 0 failed**.
`AILANG_RELAX_MODULES=1 make -k dst` to a log file, never through `tail`, with **no tracked file
touched while it ran** (this note was drafted in the scratchpad and copied in afterwards).

**The sweep's only two red targets are `test_coverage` and `test_coverage_selftest`, and both
are the SAME failures WI-D22 §12 recorded and stash-confirmed at its HEAD**: `[failing]
src/core/prompts_test.ail` (0 of 6), `[stale_skip_record] "Named test blocks not yet
implemented"`, and the selftest's identical `stale_skip_record` leak into its `named_only.ail`
fixture (`self-test: 2 failure(s)`). No finding names any file this item touched, there is no
`[untracked]` row, and the coverage census moved only where this item's tests were added.
NOT re-confirmed by stash-and-run this time, deliberately: D22 measured that `git stash` is
unsafe for a HEAD baseline while another session shares this worktree, D22's own stash-run
already pinned these two failures to HEAD, and every failing subject is a file this item never
edited.

Inside the sweep, `test_coverage`'s census is itself a witness worth quoting: src/core **65
files, 42 carry tests, 413 tests, 403 passed, 4 skipped** — including `ports.ail` 5/5,
`session.ail` 23/23, `dst_replay.ail` 21/21, `dst_attribution_table.ail` 14/14, i.e. every
module this item edited passes its whole inline suite in the same run that exercises the new
anchors and profiles.

Targets run individually before the sweep, all green: `world_state` (including the new witness
and every poison pair), `execution_program`, `program_persistence`, `discovery`,
`declared_vs_performed`, `conformance`, `attribution_table`, `predicate_anchors` ("no drift: 6
anchors and 7 references"), `driver_only`, `driver_plus_no_ops`, `ext_call_inventory` +
selftest, `ext_ambient_inventory` + selftest, `ext_hook_scope_selftest`.

---

## 12. WHAT THE NEXT ITEM (the identity work) INHERITS

1. **The typed surface is complete end to end.** Script → codec → `world_tool` → bridge → 
   `ExtProcOutcome.exit_code`, with witnesses at every joint. Routing a compose `exec` site now
   needs NO type work — only identity.
2. **The blocker is unchanged and asserted**: `recording_tool`'s
   `ToolIdentity("loop_v2", "", …)` on a bridge-initiated dispatch is a rejected program
   (`dst_program:697` region). The eighth recording adapter + `ExtCtx.ext_id` are D21 §5's plan;
   the `absent_classes` pin is untouched and its ground is still the one D21 reported.
3. **The rg shape residue is separate from identity**: `author_tools.grep_impl` needs byte
   stdout, and the seam renders JSON. Typing the exit code did not touch it; the note at the site
   now says exactly what remains.
4. **`ext_ports_of` is exported** — the identity item's tests can reach the real bridge without
   re-deciding §5.3.
5. **The fault-class discrimination across the ABI is still open** (§6) and now has a precise
   residue statement at the catalogue entry.
6. The bridge's `workdir: "."` and `timeout_ms: 0` remain, named at the site (D21 §8) — this seam
   still cannot produce `ToolDeadlineExceeded`.
