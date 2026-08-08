# WI-D22 — `execution-program/2`, and the freeze it finally makes possible

**Result: the bump is TAKEN and all three payloads shipped; the rename is REPORTED AND NOT TAKEN,
because one of the handoff's three stop conditions fired.** `program_schema_version()` is at
`execution-program/2`, the v1 decode path is kept and asserted, `InitialWorld.files` is kinded and
seeded, `ScriptedTool.exit_code` exists and a v1 tool payload REFUSES rather than defaulting, and
`scripts/dst/fixtures/execution-program-v2.artifact` closes WI-D17 §7b's two-tier compatibility surface
at zero classes remaining. The v1 bytes are untouched.

---

## 0. THE HEADLINE

**The handoff's "three payloads" were three, and a fourth one was found on the way: the decoder was
rewriting the schema version it had just read.**

`dst_persistence.project` stamped `program_schema_version()` on every decoded program. With ONE
decodable version that is behaviour-preserving and invisible. With two it is a decoder discarding a
fact it was handed — and it made `program_diff`'s `schema_version` row, which
`scenario_the_frozen_v1_specimen_still_decodes` runs and whose whole claim is "field by field",
**structurally incapable of failing on that field.** The bump is what armed it; the bump is also what
exposed it. Fixed in the same commit, and `frozen_v1_program()` now declares `execution-program/1` so
the row compares two things that can disagree.

---

## 1. The git wall-clock window

Handoff commit `a816bcd` at `2026-08-08T14:32:09Z`; commit closing the item at ~`16:20Z`. **The window
is ~1h48m**, against D21's ~1h05m, D20's ~1h13m and D19's ~52m.

**It is the longest of the four and the comparison is not like-for-like.** D19–D21 were measurement
items that routed nothing; this one edited **22 files** and produced **+995/−130 lines**. The time
divides roughly: ~35m grounding and design (the `FsNode` location and the two-codec question are both
decisions with a wrong cheap answer), ~50m edits and the type-error cascade from two record widenings,
~15m mutants, ~10m lost to an environment problem reported in §9.

---

## 2. WHAT A v1 ARTIFACT DOES UNDER THE NEW BUILD — DEMONSTRATED, NOT DESCRIBED

The migration answers **two different questions with two different answers**, and the pair is the
substance of the item. Both are executed rows.

### 2.1 A v1 PROGRAM decodes. Unchanged.

`decodable_schema_versions()` is `["execution-program/1", program_schema_version()]` — written out
oldest-first rather than derived, so a future bump has to make the decision explicitly instead of
inheriting it. The trap the handoff named was real and is now pinned in two places:

```
mutant M2  decodable_schema_versions() -> [program_schema_version()]      (the pre-D22 form)
           dst_program                 1 of 3 rows red
           program_persistence         ✗ THE FROZEN v1 SPECIMEN NO LONGER DECODES:
                                         [artifact-unknown-schema-version] this build writes
                                         'execution-program/2' and can decode 1 schema version(s);
                                         it cannot decode 'execution-program/1'
```

`test_current_schema_is_decodable_and_an_unknown_one_is_not` now asserts four clauses, not two: the
current version is decodable, `execution-program/0` is not, **`execution-program/1` is**, and the list
is exactly two long. The length is pinned as well as the membership — a third version added without a
decode path in `dst_persistence` satisfies both membership clauses and only the count says so.

### 2.2 A v1 TOOL OUTCOME refuses. This is what the bump was cut for.

```
mutant M1  decode_tool_outcome reads exit_code WITH a default:
             match opt_int_field(root, "exit_code")   ->   match Some(int_field(root, "exit_code", 0))
           ports.ail   ✗ test_a_v1_tool_payload_refuses_rather_than_decoding_to_a_default_exit_code
                       4 passed, 1 failed — and it is the only row that moves
```

The fixture is the byte-exact payload `encode_tool_outcome` emitted at HEAD~1:
`{"result":"completed","content":"OUT"}`. Under the mutant it decodes clean, `tools_of` reconstitutes a
queue from it, and **a recorded run in which a subprocess exited non-zero replays as one in which it
exited 0, with every count balancing.** That is S30's failure in the exact place S30 was written about.

The row carries two negative controls, because either half alone is passed by a broken decoder:

* an explicit `"exit_code":0` must decode **to 0** — so the refusal cannot be satisfied by a decoder
  that treats every zero as absent;
* the current encoder's own output must contain the key — so nothing this build writes can trip it.

### 2.3 THE RULE THE PAIR ESTABLISHES, because "old fields default" and "old fields refuse" are both wrong

> **A default is admissible exactly when the OLD VERSION'S OWN SEMANTICS FIXED THE VALUE. Refusal is
> required when they did not.**

`world.file` absent → `files: []` is a **default and correct**: at v1 the field existed nowhere and
`world_state_of` unconditionally reconstituted an empty table, so an empty table is what a v1 program
*meant*. The decoder reproduces v1's semantics rather than guessing at them.

`exit_code` absent → **refusal**, because v1 runs really did execute subprocesses that exited with
something, and every default that is a valid exit status claims to know what.

Both statements are at their sites (`dst_program.program_schema_version`, `dst_persistence.project`,
`ports.decode_tool_outcome`), stated as the failure they prevent.

---

## 3. THE `FsNode` LOCATION DECISION

**Taken: a NEW std-only module, `src/core/fs_node.ail`.** The handoff's three options were measured and
two were declined:

| Option | Verdict |
|---|---|
| `dst_program` imports `ports` | **Declined on direction.** `dst_persistence` imports `dst_program`, so the whole effectful port layer would enter the import graph of the pure program schema. That is precisely the "move what you need down, do not import up" rule the Makefile's own `dst_secrets` tier guard states, applied one module over |
| Move it into `dst_interaction` | **Declined on honesty.** Cheapest (both importers already have it, no new file) and it makes that module's header — "the interaction vocabulary" — false. An `FsNode` is not an interaction |
| An anonymous `[{path, kind, content}]` on `InitialWorld` | **Declined as the handoff predicted.** It reintroduces `{path, kind: "dir", content: "hello"}` at the persistence boundary, which is the one place hand-written and corrupted inputs enter |

**No cycle exists and none was created**: `fs_node` imports `std/option` and `std/list` and nothing
else. Cost of the move, measured: **5 import sites** — `ports`, `dst_program`, `ext_world`,
`scripts/dst/world_state_probe`, `scripts/smoke_v2_compaction_full_loop`. `ports` keeps the full
representation argument in place and points at the new module.

---

## 4. THE TWO CODECS — SEPARATE, AND NOW PINNED AGAINST EACH OTHER

**Answer: deliberately separate, and they share the VOCABULARY rather than the codec.**

They differ in three ways, all legitimate:

| | `ext_world` | `dst_persistence` |
|---|---|---|
| format | JSON | tab-separated lines (chosen for diffability, its choice 1) |
| lifetime | one hook call | outlives the build that wrote it |
| unreadable entry | **falls back to `FsFile`** — an old token has no `kind` key and every entry it could have written was a file | **REFUSES** — no artifact predates `world.file`, so an unknown kind is a newer schema or a corrupted file |

Merging them would have forced one of those three answers onto the other side. So what moved into
`fs_node` is `fs_kind_id` / `fs_content_of` / `fs_node_of_kind` / `all_fs_kinds`, and **neither codec
writes the literal `"file"` or `"dir"` any more.** `ext_world`'s encoder lost its two hand-written
tokens to `fs_kind_id`; `dst_persistence`'s `file_lines` never had any. Renaming `"dir"` now moves both
at once, and renaming it in one of them is no longer expressible.

`program_persistence`'s own `files_diff` instrument reads the same two functions, so the measurement
cannot drift from the thing it measures either.

The refusal side is two named rules, not one with a reason string:
`artifact-unknown-file-kind` and `artifact-directory-carries-content`. Both are executed:

```
mutant M3  the structural phase stops calling check_file_entries
           ✗ artifact-unknown-file-kind was NOT reported for: an initial-world file entry whose
             kind this build does not define
           ✗ artifact-directory-carries-content was NOT reported for: a directory entry carrying
             a file body
```

`check_file_entries` runs in `decode_body`'s **structural phase**, beside `check_required`, and not in
`project`. That is forced: `project` returns a program rather than a `Result` and has nowhere to put a
refusal — a check living in the projection is a check that has already decided to build something.

---

## 5. THE v2 SPECIMEN IS FROZEN, AND THE COUNT IS ZERO

```
✓ the frozen v2 specimen decodes to the specimen, field by field (2409 bytes read from the tree)
  ✓ the current encoder still produces those exact bytes
  ✓ 0 identity class(es) round-tripped-but-not-frozen — WI-D17's two-tier compatibility surface is
    CLOSED (all 10 classes are in frozen bytes)
```

**`scripts/dst/fixtures/execution-program-v2.artifact`, 83 lines**, holding `specimen_program()`
entire: all eleven interactions — so `file_write`, `file_remove` and `dir_make` are in frozen bytes for
the first time — plus the new `world.file` section.

**THE v1 BYTES ARE NOT REGENERATED.** `git status scripts/dst/fixtures/` shows one addition and zero
modifications. The v1 row still passes and now reports the ⓘ it was written to report: *"the current
encoder produces different bytes from the frozen artifact, and the frozen artifact still decodes
correctly — that is a backward-compatible encoding change and is permitted."* That ⓘ was dormant for
the artifact's whole life and this is the first item to reach it.

### 5.1 The world had to be split the same way the interactions were

WI-D17 split `frozen_v1_interactions()` from `specimen_interactions()` because a class added after a
freeze cannot be in the frozen bytes. **`InitialWorld.files` needed the identical split one level up**,
and missing it would have been loud rather than silent: `frozen_v1_program()` was
`{ specimen_program() | interactions: … }`, so seeding the shared `specimen_world()` would have changed
the v1 program and the v1 row would have said, correctly, that this build reinterprets an old artifact.
So there is now `frozen_v1_world()` (no files, pinned) and `specimen_world()` =
`{ frozen_v1_world() | files: post_v1_files() }`.

### 5.2 What the four seeded entries are for

They are built to freeze the CODEC, not to look like a filesystem: an ordinary file with a body; a
**present-but-empty file**; an **explicit empty directory** — which serialises to the identical
`content: ""` and differs only in `kind`, so a codec that dropped the kind is visible **in the bytes**
and not only in a round trip; and a path carrying a **tab** with a body carrying a **newline and a
backslash**, because `world.file` is the first three-field tag in this schema and a mid-field tab is
where a record splits into the wrong arity.

The v2 row asserts **byte identity as a failure**, where v1 only informs. The asymmetry is deliberate:
v1's bytes predate this encoder, so a permitted backward-compatible change can legitimately falsify
"the encoder still produces them". v2's were frozen BY this encoder, so a mismatch means either the
encoding changed without a version moving — the thing this module exists to catch — or the file was
regenerated. There is no third reading.

```
mutant M4  encode_body stops writing the file table
           ✗ 1 field(s) did not survive the round trip: world.files length (4 vs 0)
           ✗ the current encoder no longer produces the frozen v2 bytes …
           ✗ both file rules NOT reported   ✗ the store did not round-trip the specimen
```

### 5.3 How the bytes were produced, since there is no regeneration target and must not be

A one-shot `emit_v2_once` writer was added to `program_persistence_dst.ail`, run once, and **removed**;
the file was restored from a byte-copy taken before the edit. The Makefile's writer guard was
**extended to `v2_fixture_path()`** in the same commit, so the guard now forbids re-adding it. That is
the guard working as intended: the fixture is producible by a deliberate manual act and by nothing that
survives in the tree.

---

## 6. THE RELEASE ANSWER ON THE RENAME — A STOP CONDITION FIRED

**IT FORCES THE ABI MAJOR. The rename is NOT applied.** The handoff's third stop condition is explicit
that this decision has consumers outside this project and is to be reported rather than taken.

**WI-D21's ground for coupling the rename to the schema bump does not survive contact.** The two are
not one conversation: `execution-program/N` and `motoko-ext-abi@X.Y` are independent compatibility
surfaces with independent consumers, and `execution-program/2` shipped without touching a single type
in `packages/motoko-ext-abi/types.ail`. Coupling them would have made a release decision a side effect
of a codec change.

**What the rename does to a consumer that has not re-released**, which is the half seven deferrals
never stated:

> `ExtPorts` is a RECORD and every extension constructs one by writing every label. A renamed label is
> therefore not a soft break noticed at a call site — it is a construction that no longer type-checks,
> at the one function every extension package is required to export (`register_with_config`). There is
> no deprecation window, no shim, and no source that satisfies both the old and the new ABI.

That is categorically unlike the deferred **fifteen rows and five added types**, every one of which is
a widening or an addition that an unchanged consumer keeps compiling against — A12's P1 argument,
records take additive fields. **A rename is the first genuinely breaking one, and under this package's
own rule (`types.ail:7`) it is a `6.0`, not a row that rides along with the widenings.**

Recorded at the ABI row itself, in the past-tense form plan rule S15 asks for. `proc_exec` still says
the wrong thing; the parameter names `(tool, args_json)` WI-D21 landed, plus that paragraph, are what
stand between a reader and the misreading until the major is cut.

### 6.1 The anchor cascade did NOT fire, and the reason is worth recording

The handoff budgeted six files for it. **Zero.** The cascade law is about `ext_ports_of`, and the
rename is what would have touched `ext_ports_of`; deferring the rename deferred the cascade with it.
Verified rather than assumed: `predicate_anchors` reports *"no drift: 6 anchors and 7 references all
match their accepted hashes"*, `ext_call_inventory` and its selftest are green, and
`driver_only_version` is still **19** with `no_ops_version` still **6**.

**The comment added to the ABI row moved nothing.** That is a genuine data point against D21's finding
that a comment-only edit fires the cascade: the cascade is anchored on `session.ail`, not on
`types.ail`, and prose in the ABI is not in the normative region the anchor tool scans.

---

## 7. RECORDED BINDINGS: DECIDED VERSUS DISCOVERED

**Decided:**

1. `FsNode` moves to a NEW std-only module `src/core/fs_node.ail`, not into `dst_interaction` and not
   by importing `ports` upward (§3).
2. The two codecs stay separate and share the kind vocabulary; neither writes `"file"`/`"dir"` (§4).
3. An unreadable file entry is a **refusal** in the artifact and a **stated fallback** in the world
   token, and the two answers are both correct for their surface (§4).
4. `exit_code`'s absent value is `-1`, a sentinel and not `Option[int]` — priced at §-2 of the type
   comment: the option buys a compile-time reminder at four sites and costs a representation decision
   at each of two codecs, and the persistence side refuses absence anyway.
5. `ToolCompleted` gets `exit_code` and the other three variants do not. "Completed" is the variant
   that conflates exit 0 with exit 1; the other three are already discriminated.
6. The generating adapter writes `-1` and **draws nothing**. An extra draw remaps `dst_generator`'s
   whole stream and moves stage 4's pinned seeds 9, 13 and 94; a derived `if d.code == "" then 0 else 1`
   draws nothing and is worse, because it manufactures the claim that every generated tool ran a
   process.
7. `dst_replay.ail:999`'s `"execution-program/1"` is **DERIVED**, not pinned. It is the machinery's own
   fixture, exercises no compatibility path, and nothing about it is v1-specific — measured, per the
   handoff, as the only live transcription outside the producer (the two other occurrences are
   comments).
8. The rename is reported and not taken; the ABI major is named as the blocker (§6).

**Discovered:**

9. **`project` rewrote the schema version it read** (§0). Latent at one decodable version, armed by the
   bump, and the row that should have caught it could not fail on that field.
10. **`scan_program` did not scan the seeded file table, and could not have — the field did not exist.**
    Adding `InitialWorld.files` opens the one path into an artifact that D8's redact gate does not
    cover, and `ports.recording_file_write` says why it matters in its own comment: *"a file body is the
    single most likely place in this whole surface for a credential to appear."* That comment's answer
    was "do not put it there"; this item had to put it there, because a redacted seed no longer
    reproduces the run. So the other half applies and `scan_file_table` scans **both the path and the
    body** — a credential in a path (`/w/.config/token-sk-…`) is not hypothetical.
11. **`scenario_decode_mutants` transcribed `"execution-program/1\n"`** to build the unknown-schema
    mutant. It would have gone red loudly rather than silently (a mutation that mutates nothing produces
    no refusal), but it is the same S23 shape as §7.7 and is now derived from
    `program_schema_version()`.
12. **`world.file` is the first three-field repeatable tag in the schema**, so it is the first place a
    mid-field tab could split a record into the wrong arity. Arity 3 with an empty content for
    directories, rather than a tag whose arity depends on its own second field — that would make
    `WrongArity` undecidable from the tag table.
13. `reconstitution_balance` needed a **files** rule, and it is the environment's rule rather than a
    queue rule: the two tables the program carries DIRECTLY are the ones a projection can drop with
    every count still balancing.

---

## 8. THE COUNTERS, KEPT APART

**Silent-wrong: 75, unchanged, across forty-four runs.** No new production site where two answers
type-check and the wrong one ships was found in the tree. §7.9 is *not* one: at HEAD it produced no
wrong answer, because only one schema version existed. §7.10 is not one either — it is a hole this item
would have **authored**, closed in the same commit, and inflating the count with defects the item
created and fixed would destroy what the number answers.

**Instrument-weaker-than-its-claim: 6 → 7.** The new instance is §0/§7.9's other half:
`program_diff` names `schema_version` in a row whose whole claim is "field by field", and both sides of
that comparison were derived from `program_schema_version()`, so the field could not disagree however
wrong the artifact was. Nothing shipped wrong; the evidence was thinner than advertised. **D21's split
was the right call and this item is the first to add to the second counter without adding to the
first** — which is exactly the discrimination the split exists to make.

---

## 9. THE ENVIRONMENT PROBLEM, MEASURED RATHER THAN GUESSED AT

`corpus_pr`, `corpus_rotating` and `discovery` were **`Killed` (OOM), three times between them**, on a
box showing 14.2 GB of 16 GB used by other sessions and ~1.7 GB available. The tempting conclusion —
"the schema bump costs memory" — was measured instead of assumed:

| | peak RSS |
|---|---|
| `corpus_rotating_dst`, HEAD | 1,133,396 kB |
| `corpus_rotating_dst`, with WI-D22 | 1,091,336 kB |

**Lower with the change**, and all three targets pass on retry. It is memory pressure from co-tenants,
not this item. Recorded because "a target that OOMs after your edit" reads exactly like a regression and
the only thing that separates the two is a number.

**One process rule earned this run and it is not in S13/S17/S28**: `make sync_packages` must be re-run
**after any edit to a type that a package's import graph can see**, not only once at the start.
`smoke_v2_compaction_full_loop` failed with `record field 'exit_code' not found in concrete record`
pointing at a source line that plainly had the field — because `ailang.lock` had gone stale and the
resolver was reading an older `motoko_core`. It cost ~10 minutes and the error names the wrong file.

---

## 10. THE YIELDS

**Unchanged, as the handoff said they should be: 4 of 15 installable at zero barriers, 5 of 15 at the
graded profile.** This item routed nothing — it unblocked the routing rather than performing it.

---

## 11. WHAT DID NOT SHIP, AND WHY

* **The `proc_exec` rename** — §6, stop condition fired, release decision reported.
* **Routing the four `exec` sites and widening `ExtProcOutcome`** — out of scope by the handoff, and
  now genuinely unblocked: `ScriptedTool.exit_code` and `ToolCompleted.exit_code` exist and are
  persisted. `world_tool`'s dispatch arm carries `-1` with the reason at the site, and the reason is
  WI-D21's link 4: `dispatch_one`'s `(workdir, ToolCall) -> string` contract, which needs either a
  typed sibling or JSON parsing in `ports` — and parsing there is the same string-parsing defect one
  layer down.
* **The eighth recording adapter and `ExtCtx.ext_id`** — untouched, `absent_classes` untouched.
* Everything else on the handoff's out-of-scope list.

---

## 12. THE SWEEP

`make sync_packages` first (nineteenth consecutive item). `AILANG_RELAX_MODULES=1 make dst`,
cache-cold, **never piped through `tail`** — D21 lost a run to it. `check_core`: **56 passed, 0 failed**
(55 before; `fs_node.ail` is the 56th).

`test_coverage` and `test_coverage_selftest` are the sweep's only two red targets, and **both fail
identically at HEAD — confirmed by stash-and-run, not asserted.** `test_coverage` reports 2 findings:
`[failing] src/core/prompts_test.ail` (0/6) and `[stale_skip_record] Named test blocks not yet
implemented`. `test_coverage_selftest` reports the same `stale_skip_record` leaking into its
`named_only.ail` fixture (`self-test: 2 failure(s)`, byte-identical at HEAD). A third finding — `[untracked] src/core/fs_node.ail`, *"carries 4 test(s) and is not
tracked by git, so it runs on this machine and does not exist in CI"* — **was mine and is fixed by
`git add`.** That rule is worth its keep: a new module with inline tests is exactly the thing that
passes locally and does not exist in CI.

Four scripts fail at HEAD and still fail, untouched and unrelated: `probe_phase_vocab_sealed`
(`MkHistory` not exported) and the three `smoke_v2_{conversation,factual,intercept}` arity failures.

**Mutants: 5 applied, 5 killed their named row, and no other row moved.** Restored by `cp` from a
snapshot taken before the first one, per S17; the restore is verified by re-running all three modules'
inline suites to green (21/21, 5/5, 3/3) rather than by `git diff` alone.
