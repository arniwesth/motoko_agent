# 2026-08-08 Cluster 48: WI-D22 — `execution-program/2`, and the freeze it finally makes possible

## Context

Branch: `arniwesth/mot-84-wi-d22-execution-program2-and-the-freeze-it-finally-makes-possible`.

Session span: `a816bcd` → **`daef68a`**. Input was
`HANDOFF-execute-d22-the-program-schema-bump.md`, grounded against HEAD `a816bcd`
(`2026-08-08T14:32:09Z`). Pin **v0.33.0**. First command `14:37Z`, closing commit `ba272ab`
at `15:57Z`, **~1h25m** — longer than D21's 1h05m, D20's 1h13m and D19's 52m, and the first of
the four that was an *edit* item rather than a measurement item.

**The change three items owed and one scheduled.** 23 files, **1538 insertions / 80 deletions**
across two commits (two files landed inside a concurrent session's commit — see below).

```text
.agent/.../NOTE-d22-the-program-schema-bump.md   391 +  the record
src/core/ports.ail                               231 +- ScriptedTool.exit_code, ToolCompleted.exit_code,
                                                        the codec that REFUSES a v1 payload
scripts/dst/program_persistence_dst.ail          183 +- the world split, the v2 freeze row, files_diff,
                                                        two new decode-mutant rows
src/core/fs_node.ail                             173 +  NEW std-only module: the type, the shared kind
                                                        vocabulary, 4 inline rows  (in b23a44e)
src/core/dst_persistence.ail                     161 +- world.file lines, two refusal rules, the version
                                                        carried through decode, the secret scan
src/core/dst_program.ail                          95 +- execution-program/2, the decodable list,
                                                        InitialWorld.files
src/core/dst_replay.ail                           90 +- world_state_of reads the seed, FilesNotCarried,
                                                        the derived fixture version
scripts/dst/fixtures/execution-program-v2.artifact 83 + THE FREEZE  (in b23a44e)
src/core/ext_world.ail                            59 +- exit_code across the token; the kind literals
                                                        replaced by the shared vocabulary
packages/motoko-ext-abi/types.ail                 42 +  THE RELEASE ANSWER on the proc_exec rename
scripts/dst/{discovery,world_state_probe,strict_replay,latency_pair,
             invariants,execution_program,seeded_generator,corpus_pr,
             corpus_rotating,long_qwen}_dst.ail   94 +- the two record widenings' construction sites
scripts/smoke_v2_compaction_full_loop.ail          6 +- the FsNode import move
Makefile                                           4 +- the writer guard extended to v2
```

| Definition-of-done item | State |
|---|---|
| `execution-program/2`, `decodable_schema_versions()` extended, v1 decode path kept | **met** — and the list is written out, not derived |
| The frozen v1 specimen still decodes; its bytes NOT regenerated | **met** — `git status` on the fixture dir shows one addition, zero modifications |
| A frozen v2 specimen carrying the three post-v1 classes | **met** — all **ten** classes, and the count is asserted at zero remaining |
| `InitialWorld.files`, kinded, with the type-location decision recorded | **met** — new module, three options priced, two declined |
| `world_state_of` reads it instead of reconstituting `[]` | **met**, plus a two-sided `FilesNotCarried` balance rule |
| `ScriptedTool.exit_code`, codec pair, `tools_of` following | **met** — and `ToolCompleted` too, which the DoD implied and did not name |
| `dst_replay.ail:999`'s literal resolved | **met — DERIVED**, with the reason at the site |
| The rename, and the release question answered | **answered; rename NOT taken — stop condition 3 fired** |
| Mutants, S24 reachability separate from verdict | **5 applied, 5 killed their named row, no other row moved** |
| S13/S9/S17/S26/S28 process rules | **met (19th consecutive `sync_packages`), plus one new rule earned** |
| Anchor cascade budgeted at six files | **ZERO — it did not fire, and the reason is structural** |
| Yields 4 of 15 and 5 of 15 | **met — unmoved** |

---

## The mission result: three payloads shipped, and a fourth was found on the way

**`dst_persistence.project` was rewriting the schema version it had just read.** It stamped
`program_schema_version()` on every decoded program. With ONE decodable version that is
behaviour-preserving and invisible; with two it is a decoder discarding a fact it was handed.

Worse, it made `program_diff`'s `schema_version` row — inside
`scenario_the_frozen_v1_specimen_still_decodes`, whose entire claim is *"field by field"* —
**structurally incapable of failing on that field**, because both sides were derived from the
same function. The bump armed the defect and the bump exposed it. `project` now carries the
version the bytes declared, and `frozen_v1_program()` declares `execution-program/1`, so the
row compares two things that can disagree.

---

## What a v1 artifact does under the new build: two questions, two different answers

This is the item's substance, and both halves are executed rows rather than prose.

**A v1 PROGRAM decodes.**

```
mutant M2  decodable_schema_versions() -> [program_schema_version()]   (the pre-D22 form)
           dst_program            1 of 3 rows red
           program_persistence    ✗ THE FROZEN v1 SPECIMEN NO LONGER DECODES:
                                    [artifact-unknown-schema-version] this build writes
                                    'execution-program/2' and can decode 1 schema version(s)
```

**A v1 TOOL OUTCOME refuses.**

```
mutant M1  decode_tool_outcome reads exit_code WITH a default:
             match opt_int_field(root, "exit_code") -> match Some(int_field(root,"exit_code",0))
           ports.ail  ✗ test_a_v1_tool_payload_refuses_rather_than_decoding_to_a_default_exit_code
                      4 passed, 1 failed — and it is the only row that moves
```

The fixture is the byte-exact payload `encode_tool_outcome` emitted at HEAD~1,
`{"result":"completed","content":"OUT"}`. Under the mutant it decodes clean, `tools_of`
reconstitutes a queue from it, and **a recorded run in which a subprocess exited non-zero
replays as one in which it exited 0, with every count balancing.** S30's failure, in the exact
place S30 was written about.

Two negative controls, because either half alone is passed by a broken decoder: an explicit
`"exit_code":0` must decode **to 0**, and the current encoder's output must always carry the key.

### THE RULE THE PAIR ESTABLISHES

> **A default is admissible exactly when the OLD VERSION'S OWN SEMANTICS FIXED THE VALUE.
> Refusal is required when they did not.**

`world.file` absent → `files: []` is a **correct default**: at v1 the field existed nowhere and
`world_state_of` unconditionally reconstituted an empty table, so the decoder is reproducing v1's
semantics, not guessing at them. `exit_code` absent → **refusal**, because v1 runs really did
execute subprocesses that exited with something, and every default that is a valid status claims
to know what. Neither "old fields default" nor "old fields refuse" is the rule.

---

## The `FsNode` location: a new module, and the cheap answers were both wrong

| Option | Verdict |
|---|---|
| `dst_program` imports `ports` | **Declined on direction.** `dst_persistence` imports `dst_program`, so the effectful port layer would enter the import graph of the pure program schema — the exact "move what you need down, do not import up" rule the Makefile's own `dst_secrets` tier guard states, one module over |
| Move it into `dst_interaction` | **Declined on honesty.** No new file, both importers already have it — and it makes that module's header ("the interaction vocabulary") false. An `FsNode` is not an interaction |
| An anonymous `[{path, kind, content}]` | **Declined as the handoff predicted.** It reintroduces `{path, kind:"dir", content:"hello"}` **at the persistence boundary**, which is the one place hand-written and corrupted inputs enter |

**`src/core/fs_node.ail`** imports `std/option` and `std/list` and nothing else. No cycle
existed and none was created. Cost measured: **5 import sites** — `ports`, `dst_program`,
`ext_world`, `world_state_probe`, `smoke_v2_compaction_full_loop`. `check_core` is **56 passed,
0 failed** (55 before).

---

## The two codecs: deliberately separate, sharing the vocabulary and not the codec

| | `ext_world` | `dst_persistence` |
|---|---|---|
| format | JSON | tab-separated lines (its choice 1, for diffability) |
| lifetime | one hook call | outlives the build that wrote it |
| **an entry it cannot read** | **falls back to `FsFile`** — an old token has no `kind` key, and every entry such a build could have written was a file | **REFUSES** — no artifact predates `world.file`, so an unknown kind is a newer schema or corruption |

Merging them would have forced one of those three answers onto the other side. **What moved
into `fs_node` is the vocabulary** — `fs_kind_id`, `fs_content_of`, `fs_node_of_kind`,
`all_fs_kinds` — and **neither codec writes `"file"` or `"dir"` as a literal any more.**
Renaming `"dir"` now moves both at once and renaming it in one is no longer expressible.
`program_persistence`'s own `files_diff` instrument reads the same functions, so the measurement
cannot drift from what it measures either.

Two named rules rather than one with a reason string, both executed:

```
mutant M3  the structural phase stops calling check_file_entries
           ✗ artifact-unknown-file-kind was NOT reported …
           ✗ artifact-directory-carries-content was NOT reported …
```

`check_file_entries` runs in `decode_body`'s **structural phase**, not in `project` — forced,
because `project` returns a program rather than a `Result`. **A check living in the projection
is a check that has already decided to build something.**

---

## The freeze: WI-D17 §7b closed at zero

```
✓ the frozen v2 specimen decodes to the specimen, field by field (2409 bytes read from the tree)
  ✓ the current encoder still produces those exact bytes
  ✓ 0 identity class(es) round-tripped-but-not-frozen — WI-D17's two-tier compatibility
    surface is CLOSED (all 10 classes are in frozen bytes)
```

**`scripts/dst/fixtures/execution-program-v2.artifact`, 83 lines.** `file_write`, `file_remove`
and `dir_make` are in frozen bytes for the first time.

**The v1 bytes were not regenerated**, and its row reached the ⓘ branch it was written for and
had never used: *"the current encoder produces different bytes from the frozen artifact, and the
frozen artifact still decodes correctly — that is a backward-compatible encoding change and is
permitted."*

**The world needed WI-D17's split one level up.** `frozen_v1_program()` was
`{ specimen_program() | interactions: … }`, so seeding the shared `specimen_world()` would have
changed the v1 program. There is now `frozen_v1_world()` (no files, pinned) and
`specimen_world() = { frozen_v1_world() | files: post_v1_files() }`.

**The four seeded entries freeze the CODEC, not a filesystem**: an ordinary file; a
present-but-empty file; an explicit empty directory — which serialises to the identical
`content: ""` and differs **only** in `kind`, so a codec that dropped the kind is visible in the
bytes and not only in a round trip; and a path with a **tab** whose body has a **newline and a
backslash**, because `world.file` is the schema's first three-field tag and a mid-field tab is
where a record splits into the wrong arity.

**The v2 row asserts byte identity as a FAILURE where v1 only informs**, and the asymmetry is
deliberate: v1's bytes predate this encoder, so a permitted compatible change can legitimately
falsify "the encoder still produces them"; v2's were frozen BY this encoder, so a mismatch means
either an encoding change that did not move the version — the thing this module exists to catch
— or a regeneration. There is no third reading.

```
mutant M4  encode_body stops writing the file table
           ✗ 1 field(s) did not survive the round trip: world.files length (4 vs 0)
           ✗ the current encoder no longer produces the frozen v2 bytes …
           ✗ both file rules NOT reported     ✗ the store did not round-trip the specimen
```

**How the bytes were made, since there must be no regeneration target:** a one-shot
`emit_v2_once` was added, run once, and **removed** (the file restored from a byte-copy taken
before the edit), and **the Makefile's writer guard was extended to `v2_fixture_path()` in the
same commit** — so the guard now forbids re-adding it.

---

## The release answer: it forces the ABI major, so it is reported and not taken

**WI-D21's ground for coupling the rename to the schema bump does not survive contact.**
`execution-program/N` and `motoko-ext-abi@X.Y` are two independent compatibility surfaces with
independent consumers, and `execution-program/2` shipped without touching a single type in
`packages/motoko-ext-abi/types.ail`. Coupling them would make a release decision a side effect
of a codec change.

**What the rename does to a consumer that has not re-released** — the half seven deferrals never
stated:

> `ExtPorts` is a RECORD and every extension constructs one by writing every label. A renamed
> label is not a soft break noticed at a call site — it is a construction that no longer
> type-checks, at the one function every extension package is required to export
> (`register_with_config`). No deprecation window, no shim, and no source that satisfies both
> the old and the new ABI.

Categorically unlike the deferred **fifteen rows and five added types**, every one of which is a
widening or an addition an unchanged consumer keeps compiling against (A12's P1: records take
additive fields). **A rename is the first genuinely breaking one, and under this package's own
rule (`types.ail:7`) it is a `6.0`.** Recorded at the ABI row in S15's past-tense form.
`proc_exec` still says the wrong thing; WI-D21's `(tool, args_json)` parameter names plus that
paragraph are what stand between a reader and the misreading.

---

## THE ANCHOR CASCADE DID NOT FIRE, AND THAT IS A DATA POINT

The handoff budgeted six files. **Zero.** The cascade law is about `ext_ports_of`; the rename is
what would have touched it, so deferring the rename deferred the cascade. Verified, not assumed:
`predicate_anchors` reports *"no drift: 6 anchors and 7 references all match their accepted
hashes"*; `ext_call_inventory` and its selftest green; `driver_only_version` still **19**,
`no_ops_version` still **6**.

**The comment added to the ABI row moved nothing** — a genuine qualification of D21's finding
that a comment-only edit fires the cascade. The anchors are on `session.ail`, and prose in
`packages/motoko-ext-abi/types.ail` is not in the region the anchor tool scans. **D21's law is
about `ext_ports_of` specifically, not about comments.**

---

## The environment problem, measured rather than guessed at

`corpus_pr`, `corpus_rotating` and `discovery` were **`Killed` (OOM) three times between them**,
on a box showing 14.2 GB of 16 GB used by co-tenant sessions. The tempting conclusion — "the
schema bump costs memory" — was measured instead:

| | peak RSS |
|---|---|
| `corpus_rotating_dst`, HEAD | 1,133,396 kB |
| `corpus_rotating_dst`, with WI-D22 | 1,091,336 kB |

**Lower with the change**, and all three pass on retry. Recorded because a target that OOMs
after your edit reads exactly like a regression, and the only thing that separates the two is a
number.

**A new process rule, earned this run and not in S13/S17/S28:**
**`make sync_packages` must be re-run after ANY edit to a type a package's import graph can
see**, not only once at the start. `smoke_v2_compaction_full_loop` failed with
`record field 'exit_code' not found in concrete record` pointing at a source line that plainly
had the field — `ailang.lock` had gone stale and the resolver was reading an older
`motoko_core`. **The error names the wrong file**, and it cost ~10 minutes.

---

## Concurrency: another agent shares this worktree, and it took two of this item's files

Commit **`b23a44e`** ("Addded handoff, plan, note and updated ADR"), from concurrent work on
project 010, **carried `src/core/fs_node.ail` and
`scripts/dst/fixtures/execution-program-v2.artifact`**. They had been `git add`ed before the
mutant runs, which need `git stash push`/`pop` to take a HEAD baseline.

**The content is correct and intact in HEAD; only the attribution is wrong.** Left as-is rather
than repaired, because rewriting another session's commit is the more expensive mistake.
**`git stash` is not safe for HEAD baselines while another agent shares the worktree** — use a
worktree or a byte-copy comparison instead.

---

## The counts

| | |
|---|---|
| Silent-wrong sites | **75, unchanged**, across forty-four runs |
| Rows measuring less than their labels | **6 → 7** |
| Bindings | 8 decided, 5 discovered |
| Mutants | 5 applied, 5 killed their named row, 0 collateral |

**No new silent-wrong site.** The `project` version-stamp is deliberately not counted: at HEAD
it produced no wrong answer, because only one schema version existed. The unscanned file table
is not counted either — it is a hole this item would have **authored** and closed in the same
commit, and inflating the count with defects the item created would destroy what the number
answers.

**The instrument counter moves instead, and this is the first item to move it without moving the
first** — exactly the discrimination D21's split exists to make. The new instance is
`program_diff` naming `schema_version` in a row claiming field-by-field identity, where both
sides were derived from `program_schema_version()` and the field could never disagree.

## The yields

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope_selftest` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| `ext_hook_scope_selftest` — shipped closure verdict | 4 of 15 | **4 of 15** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |

**Unmoved, and they had to be.** This item unblocked routing; it performed none.

## The sweep

`AILANG_RELAX_MODULES=1 make dst`, cache-cold, **never piped through `tail`** (D21 lost a run to
it). The only red targets are **`test_coverage` and `test_coverage_selftest`, both failing
identically at HEAD — confirmed by stash-and-run, not asserted**: `[failing]
src/core/prompts_test.ail` (0/6) and `[stale_skip_record] Named test blocks not yet implemented`.

**A third `test_coverage` finding was mine and is fixed**: `[untracked] src/core/fs_node.ail`,
*"carries 4 test(s) and is not tracked by git, so it runs on this machine and does not exist in
CI"*. That rule earned its keep — a new module with inline tests is precisely the thing that
passes locally and does not exist in CI.

Four scripts fail at HEAD and still fail, untouched and unrelated: `probe_phase_vocab_sealed`
(`MkHistory` not exported) and `smoke_v2_{conversation,factual,intercept}` (arity).

Mutants restored by `cp` from a snapshot taken before the first one (S17), and the restore
**verified by re-running all three modules' inline suites to green** (21/21, 5/5, 3/3) rather
than by `git diff` alone.

---

## What the next item should know

1. **THE SCHEMA IS AT `execution-program/2` AND THE DECODABLE LIST IS WRITTEN OUT, NOT DERIVED.**
   A third version must extend `decodable_schema_versions()`, add a decode path in
   `dst_persistence`, **and** move the length assertion in `dst_program` — which is there
   precisely so a version added without a path cannot pass the membership clauses alone.
2. **THE MIGRATION RULE, NOT THE MIGRATION.** A default for a field absent from an old artifact
   is admissible exactly when the old version's semantics fixed the value. Say which at every
   new field, at the site.
3. **A CLASS ADDED FROM HERE REOPENS THE TWO-TIER SURFACE.** The v2 row asserts **zero**
   round-tripped-but-not-frozen classes, so an eleventh identity class reddens it by name. The
   fix is a further schema version and a further freeze, **never an edit to the v2 bytes** — and
   the Makefile guard now forbids a regeneration target for both fixtures.
4. **`exit_code`'s DOMAIN IS THREE-PART AND `-1` IS NOT SUCCESS.** `>= 0` is a real status;
   `-1` is "no subprocess ran, or the seam producing this cannot say". Nothing routes a real
   code yet — `world_tool`'s dispatch arm and the generating adapter both write `-1`, with the
   reason at each site.
5. **ROUTING THE FOUR `exec` SITES IS NOW GENUINELY UNBLOCKED**, and the remaining obstacle is
   WI-D21's link 4: `dispatch_one`'s `(workdir, ToolCall) -> string` contract. It needs a typed
   sibling; **do not parse its JSON inside `ports`**, which is the same string-parsing defect one
   layer down.
6. **THE `proc_exec` RENAME IS A `6.0`.** It is not deferred for lack of an opinion any more —
   the release question is answered at the ABI row. Cutting the major is a release act with
   consumers outside this project.
7. **THE ANCHOR CASCADE IS ABOUT `ext_ports_of`, NOT ABOUT COMMENTS.** This item wrote 42 lines
   of prose into the ABI row and moved zero anchors. Budget the cascade when you touch
   `session.ail`'s closure, and not otherwise.
8. **RE-RUN `make sync_packages` AFTER EVERY PACKAGE-VISIBLE TYPE EDIT.** A stale `ailang.lock`
   produces a type error naming a file that is already correct.
9. **ANOTHER AGENT MAY BE IN THIS WORKTREE.** Do not use `git stash` for a HEAD baseline; two of
   this item's files landed in someone else's commit that way.
10. **`on_pre_step` and `on_solver_candidate` are still unaudited**, successor-drop base rate
    still **2 of 2**. This item added no evidence either way.
