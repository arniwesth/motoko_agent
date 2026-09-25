# Cluster 12 execution report — WI-A13 stage 6, and the close of WI-A13

Twelfth calibration run, and the last of WI-A13. **Both pieces of the mission landed, green and
committed. WI-A13 is complete; A14 and A15 are unblocked.**

Commits:

- `6c4894e` feat(A13): stage 6 — D8's secret handling, and the axis that reaches this driver
- `e01a978` feat(A13): stage 6 — the program encoding, and a compatibility policy that is a file

**`make dst`: exit 0** — read as an exit status. **466 green checks, 63 of them new** (403 at stage
5; 427 after the first commit, so 24 and 39). **`make check_core`: exit 0**, 48 modules. The single
`✗` in the `dst` log is the `✗ Failed: 0` summary label of a passing `ailang test` run, checked
rather than assumed.

No source drift at session start (`git diff --stat ad03ab5..HEAD -- src packages scripts Makefile`
was empty).

**A5 anchors undisturbed.** `src/core/test/stub_step.ail:161` and `session.ail`'s
948/1053/2290/2400 verified intact at start and end; `driver_only` stays at **v3**. This stage added
no `StepProvider` variant and touched neither file, so the handoff's rule held trivially — but the
`sed -n '161p'` check was still run, because the cost of not running it is a profile re-issue.

---

## What landed

### D8's persistence safety (`6c4894e`)

**`src/core/dst_secrets.ail`**, new, 768 lines — std-only tier (std plus `dst_interaction`, and
nothing else, guarded in the Makefile). `SecretSite` (6 variants), `SecretReason` (6),
`SecretFinding`, the two detection axes, `ReplayImpact`, `Redaction`, the redactors, and **8 inline
rows**. **`scripts/dst/program_persistence_dst.ail`**, new — 8 scenarios, 24 checks.

### The encoding, the compatibility policy and the store (`e01a978`)

**`src/core/dst_persistence.ail`**, new, 1261 lines — the escape, `encode_body`/`encode_artifact`,
`DecodeRefusal` (12 variants), the two-phase decode, `program_digest`, `artifact_path`,
`artifact_identity`, `persist_program`/`load_program`, and **4 inline rows**.
**`scripts/dst/fixtures/execution-program-v1.artifact`** and **`…-v0.artifact`**, frozen, 67 lines
each. The acceptance script grows to 17 scenarios, 63 checks.

No regeneration target, no `--update`, no `ACCEPT=1`. The entry point that wrote the specimens was
deleted after use, and a Makefile guard fails if anything in the tree writes to that directory —
stage 5's discipline for its canary pins, applied to an artifact instead of a table.

---

## The decision the stage owned: site 22

**Recorded, keyed around, and `seed_state` left alone. The pinned characterization test stays.**

The handoff offered two legitimate outcomes and warned against a silent third. The reasoning for
taking the second is in `dst_persistence`'s choice 3 and it is **not the cost argument**:

> **Fixing `seed_state` would not make `(generator_id, generator_version, seed)` a key.** D8's own
> reproducibility promise is conditioned on the recorded execution manifest and profile — *"Repeating
> discovery under the recorded execution manifest/profile and seed must reproduce the same resolved
> program"*. The program is a function of (manifest/profile, id, version, seed), and the triple omits
> the manifest. Two runs at one triple under two manifests are two different programs **today**, with
> or without site 22. A store that filed under the triple and believed it unique would be wrong for a
> second, independent reason that repairing the PRNG does not touch.

Two independent facts pointing the same way, so:

- **the PATH is derived from the triple**, because a stable path is the whole reason a diffable
  encoding is worth having — the same logical program lands at the same name across regenerations,
  so `git diff` shows what moved. A content-addressed path puts every revision at a new name and
  there is nothing to diff;
- **the IDENTITY is `sha256Hex` of the exact bytes**, and it is the only thing in the module
  described as unique. A corpus deduplicates on it;
- **`persist_program` refuses to overwrite** a path whose existing artifact has a different digest,
  by name, with the reasoning in the message. Writing the same program twice is idempotent.

The 260-seed re-sweep was therefore **not** performed and stage 4's seeds 9, 13 and 94 are
untouched. `test_a_version_bump_is_currently_only_a_seed_offset` is **not** deleted: the store is now
safe, and the version axis still means nothing, which is what that row is about and what repairing
`seed_state` would fix. A pointer to this decision was added above it so the two ends connect.

**This is a deferral with a named owner, not a resolution.** A15's corpora are where the harm lands:
a corpus holding (v1, seed 4) and (v2, seed 3) has one program's worth of coverage while reporting
two. It can now dedupe on `artifact_identity`, which makes the aliasing visible rather than counted —
but it will still be *aliasing*, and the version axis will still be decorative until `seed_state`
changes.

---

## The rule the handoff said would be broken by accident, and it was not

> *A compatibility policy needs a frozen artifact from the past, or it tests nothing — and this
> project has no past, so you must manufacture one deliberately.*

`scripts/dst/fixtures/execution-program-v1.artifact` is that artifact. What the handoff did **not**
say, and what turned out to matter, is that the frozen row must assert only **decodability** and not
**encoder stability**. Asserting `encode(specimen) == frozen_bytes` is one character cheaper to write
and it acquires exactly the regeneration target cluster 11's correction 1 warned about: any
backward-compatible encoding change reddens it, and the natural response destroys the specimen. The
row therefore asserts the frozen bytes still **decode to the specimen field by field**, and reports
an encoder difference as an informational line rather than a failure.

Per S8's complement, the specimen carries every shape the schema admits — all seven identity classes,
all three outcome statuses, chunks present and absent, deadline present and absent, fault id present
and blank, D2's one legitimate blank call id, and a tab, a newline and a backslash inside frozen
values. Coverage is **asserted against `all_interaction_kinds()`**, not described.

**And it is constructed rather than swept, which is a departure from stage 4's technique and the
handoff's suggestion.** Stage 4's move — sweep the generator and filter — cannot supply this
specimen, because the generator provably cannot reach every shape the *schema* admits: the provider
fault class is unreachable by a generated program (cluster 10's correction 2) and
`approval_deadline_exceeded` is unreachable by a discovered, generated or replayed one (stages 2, 3
and 4). A swept specimen would freeze exactly the shapes the generator happens to produce today, and
the codec paths for the rest would not be pinned — they would be **absent**, which reads identically
to unchanged. **Sweep-and-filter selects among things that exist; it cannot cover a space the
producer does not reach.** That is the limit of stage 4's carry-forward and it is worth stating
because A15's corpora will be tempted by the same move for the same reason.

---

## Sites 23 and 24 — two type-checking answers, the wrong one silent

**Twenty-four across twelve clusters. Determinism has caught none of them.** Both of this stage's
were found by mutating the implementation and reading *why* a row went red — never by running a gate.

### Site 23 — the JWT detector's negative controls never entered the branch they tested

`has_jwt` splits on `.` and requires three segments, the first beginning `eyJ` and the other two
long enough to be a payload and a signature. Reducing it to `Str.contains(s, "eyJ")` left **every row
in the module and every row in the acceptance suite green.**

The cause is not subtle once seen: all four negative controls were strings that **do not contain
`eyJ`** — `"ailang 0.26.0 pinned"`, `"one.two.three"`. They test the prefix clause and cannot reach
the segment clause. The row claimed to cover a mechanism whose branches its own trajectory never
entered, which is S8's complement arriving **inside a test rather than inside a digest**. Two
controls that carry the prefix now kill it, and a second mutant that drops only the length clause.

The generalisation is small and worth carrying: **a negative control must fail the rule for the
reason under test, not for an earlier reason.** A control that is rejected by clause 1 certifies
nothing about clause 2, and reads identically to one that exercises both.

### Site 24 — the diff count alone cannot distinguish diffable from single-line

`scenario_deterministic_and_diffable` asserted that a one-field change moves exactly two lines. That
is the right quantity and it is not sufficient: mutating `encode_body` to join the whole program with
a non-newline separator produced a **four-line file** in which a one-field change still moved
**exactly two lines**. The assertion was green on the encoding it exists to forbid.

The fix is structural rather than a better number: the row now also requires the encoding to have at
least `4 × length(interactions)` lines — a floor **derived from the program** rather than picked,
because every interaction costs at least four lines. A magic constant would have worked here and
would have rotted the first time the specimen changed size.

**Both sites are assertion weaknesses rather than implementation defects**, which is now the
majority shape in this project. The implementation was right both times; what was wrong was the
evidence that it was right.

---

## What the mutation testing found that the gates did not

Twenty mutants across the two commits, twenty caught after the two repairs above. Three are worth
naming because each shows a different guard doing work no other guard could:

| Mutant | Caught by | Why nothing else could |
|---|---|---|
| A manifest field the codec silently drops | the field-by-field round trip **and** a Makefile guard counting `ExecutionManifest`'s declared fields against the codec's tags | every count balances and both halves type-check; only a NAMED per-field diff shows `manifest.abi_version ('abi-7' vs '')` |
| `persist_program` writes before the secret scan | reading the **file system** back | redact-after-write and redact-before-write are indistinguishable from the in-memory record, and both type-check |
| the single-line encoding | the derived line floor (site 24) | the diff count is 2 in both arrangements |

**And one guard that worked because of how it was written rather than what it checks.** The thirteen
decode mutation rows each assert a *specific* refusal rule. Corrupting the body without recomputing
the digest would have made eleven of them report `artifact-digest-mismatch` instead — and because
each row asserts its own rule rather than a non-empty refusal list, those eleven would have gone
**red**, loudly, rather than passing on the wrong evidence. The corruption helpers recompute the
digest for exactly this reason. This is cluster 5's C5 discipline paying for the fourth time, and it
is the cheapest rule in the project.

---

## Sizing — S6 per piece, and what the count over-predicted this time

**Recorded bindings: ten — eight decided, two discovered.**

**Piece 1, secret handling (4: 3 decided, 1 discovered).**

1. *Decided.* **Detection has two axes and the value axis is the load-bearing one.** Readable off
   `driver_env_keys()` before a line was written: not one of the seven driver keys contains SECRET,
   TOKEN, PASSWORD, KEY or CREDENTIAL, so a name-only redactor is a no-op that looks like a control.
2. *Decided.* **Identity components are scanned but never redacted.** Replay compares on them, so a
   redacted identity is a causal mismatch at every position — the artifact stops replaying at all,
   and the "fix" is worse than the finding.
3. *Decided.* **"Reject or redact" is not a free choice, and the cost is carried in a type.** The
   environment map is a replay input; `ReplayImpact` distinguishes a redaction D2 demotes from one
   that changes the trajectory, and the persistence path reports the second.
4. *Discovered.* **Site 23.**

**Piece 2, the encoding (6: 5 decided, 1 discovered).**

5. *Decided.* Line-oriented text, not `std/json` — "deterministic" and "diffable" pull apart and
   a single-line encoder satisfies only the first.
6. *Decided.* The digest lives inside the artifact and the bytes are always retained.
7. *Decided.* **Site 22**, above.
8. *Decided.* Validate-then-project, so the decoder has no field defaults.
9. *Decided.* The specimen is constructed, not swept.
10. *Discovered.* **Site 24.**

### Cost, measured against every previous stage from git

The previous five reports gave cost as ratios. Those were effort judgements; this is the first time
the **wall-clock window** (handoff commit → last `feat` commit) has been read off git for all six,
and **the two measures disagree**, which is itself the most useful number in this report.

| Stage | Window | Ratio to previous | Ratio reported at the time |
|---|---|---|---|
| 1 | 34 min | — | — |
| 2 | 43 min | 1.26× | ~3× |
| 3 | 35 min | 0.81× | ~1× |
| 4 | 60 min | 1.71× | ~1.5× |
| 5 | 36 min | 0.60× | ~0.9× |
| 6 | **41 min** | **1.14×** | (this report) |

Stage 4 is the only stage where the two agree closely, and it is the stage whose cost was dominated
by *running things* — sweeps and re-pins — rather than by deciding them. **Where a stage's cost is
deliberation, the contemporaneous ratio over-reports it by two to three times.** Stage 2's "~3×" is
1.26× on the clock. That is not dishonesty; it is that a stage which spends forty minutes on three
hard decisions *feels* three times a stage that spends thirty-four on one, and the clock does not
agree. **Future reports should give the git window, which is checkable, and may give a felt ratio
beside it, which is not.**

### What the binding count predicted, per piece

Piece 1: **4 bindings, 21 minutes.** Piece 2: **6 bindings, 20 minutes.** The count says piece 2
should have cost 1.5× piece 1; it cost 0.95×.

**This is the second consecutive over-prediction and the reason is now legible enough to refine the
rule.** Piece 2's five decided bindings were each decided by *reading D8 and the standing rules with
the artifact already open* — the ADR delegates the encoding and the storage path explicitly, so the
choices were there to be made rather than to be found, and each cost a paragraph of comment. Piece
1's single **discovered** binding cost three mutation loops on its own.

> **S6 refinement: weight the second term by DISCOVERED bindings. A decided binding whose deciding
> artifact is already open is close to free; a discovered one costs a round trip through running the
> thing.** Across pieces 1 and 2 the discovered counts are 1 and 1 and the costs are 21 and 20
> minutes — the discovered count predicts better than the total, on this stage and on stage 5's two
> pieces as well (2 and 0 discovered against ~70% and <30% of the session).

This does not replace S6's first term. Grounding is still paid per input artifact, and this stage
read five (`dst_program`, `dst_interaction`, `dst_replay`, `dst_generator`, `dst_profile`) plus the
plan and cluster 11's note — roughly the five minutes before the first edit.

### Round trips

**4 compiler, 2 gate, 2 silent.**

- **Compiler (4).** `++` is list-only for strings; `[record] :: list` does not parse in expression
  position; an invented `Str.contains_tab`; and **the AILANG defect below**, which was three of the
  four's worth of time on its own.
- **Gate (2).** Sites 23 and 24, both as escaped mutants.
- **Silent (2).** The same two. **Determinism caught neither** — 24 sites, 12 clusters, still
  0-for-24.

### Judgement ratio, split, per piece

(The figure is the *undetermined* fraction.)

- **Machinery, secret handling: ~55%.** D8 says "secret-shaped/live credentials" and defines
  neither. What the shapes are, whether names or values are the surface, whether identities are
  redacted, and what a redaction costs a replay are all unstated.
- **Machinery, the encoding: ~70% — the highest in the project.** The ADR's Non-goals delegates the
  encoding *and* the storage path explicitly. D8 fixes only four properties (deterministic,
  diffable, fail-closed on an unknown schema, retained bytes) and nothing about how.
- **Content, the specimen: ~30%.** Down from stage 4's ~85% and comparable to stage 5's ~25%, and
  the mechanism is stage 5's: the coverage requirement is *read off* `all_interaction_kinds()` and
  the status set, S7 supplies pairwise distinctness, and the escaping surface falls out of the two
  delimiters the format chose. What was left to judgement is which arbitrary strings to use, and
  they are arbitrary on purpose.

**The carry-forward is the same one stage 5 made, with one limit added.** Stage 5 showed the
*filter* can be derived rather than authored. This stage shows the **coverage requirement** can be
too — and that when the producer cannot reach the whole space, the artifact must be **constructed**
against a derived requirement rather than **selected** against a derived filter. A15 will need both
halves.

---

## An AILANG defect, written up

**A call in the field-value position of a record update is not registered as a dependency**, so
`{ p | interactions: f(...) }` reports `undefined variable: f` depending on a declaration ordering
the author cannot see. Moving the callee earlier fixes it in some arrangements and not in others,
which is why it cost about fifteen minutes. `let`-binding the call first is a one-line workaround
and is applied at the two sites in this stage that have the shape.

Reproduced minimally against the pin with five one-line variants isolating the trigger. Written up
in `.agent/issues/ailang-record-update-field-call-is-not-a-dependency.md`, **not yet filed
upstream**. It fails in the good direction — refusing correct code rather than accepting wrong code
— which is the opposite of the unreachable-match-arm defect this project filed in cluster 9.

---

## D2/D8 findings carried forward

1. **`approval_deadline_exceeded` remains unreachable** by a discovered, generated or replayed
   program. Unchanged since stage 2. It is now also **codec-covered**: the specimen carries an
   approval with a deadline and one with a `missing` status, so the encoding of the class is pinned
   even though the fault is not reached.
2. **The provider fault class is still unreachable by a generated program** — cluster 10's
   correction 2, unchanged. Still one `ScriptedStep` field away, still A14's.
3. **`max_resource_size` is bound to the synthetic environment's entry count** and measures nothing
   in a real run. Unchanged. It is now *encoded* and round-tripped, so A14 either gives it a
   resource that can grow or deletes it from `GeneratorBounds` — and deleting it is now a schema
   change, which is the point of having a schema version.
4. **Site 22** — decided as above, not resolved. A15 owns the residue.
5. **Sites 23 and 24** — assertion weaknesses, both repaired.
6. **The triple is not the artifact's key and the manifest is why.** This is new and it is
   independent of site 22: D8 names a preserved failure by (id, version, seed) and conditions
   reproduction on the manifest, and those two statements are inconsistent as a naming scheme. A15's
   corpus should key on `artifact_identity`.

---

## What is unblocked, and what A14 should know

**WI-A13 is complete. A14 and A15 are unblocked.** Six stages, all green, `make dst` exit 0 at 466
checks against 0 at the item's start.

### The staging, in retrospect

**What it got right.** Every stage after the first landed against a seam the previous stage had left,
and the handoffs' *"stage N left the exact seam"* claim held **four clusters running** — stage 3's
walk took a mode parameter for regression replay, stage 5's canary needed nothing from stage 4's
driver, and this stage's encoding needed nothing from the canary, exactly as cluster 11 predicted.
That is not luck; it is the consequence of each stage moving types **down** into the std-only tier
rather than importing up (`dst_interaction` in stage 2, `GeneratorBounds` in stage 4, `dst_secrets`
here). **The tier discipline is what made the staging work, and it is the single most transferable
thing in the item.**

**What it got wrong.** The item was cut as five stages and re-cut to six mid-flight, when the seeded
generator was found to have fallen between stages 3 and 4. That correction was cheap because it was
found before stage 4 started. What was *not* corrected is that **stage 6 was sized as one stage and
is two independent pieces** — the same shape stage 5 had, and the same shape S6's per-piece
refinement now exists for. Neither piece needed the other; either could have been a stage. Sizing an
item by its obligations rather than by its seams produced two stages out of six that are really four.

**And one thing no single stage report says: the ordering of the six was fixed by what each stage
could ASSERT, not by what it could build.** Discovery had to precede replay because replay grades
itself against a recorded log; the generator had to precede the canary because the canary pins the
generator's stream; persistence had to be last because a frozen specimen must contain every shape,
and the shapes were not all defined until stage 5. An item whose stages are ordered by dependency
alone would have put persistence second, where its specimen would have certified a third of the
schema and nobody would have known.

### Five things A14 should carry

1. **Every silent defect in six stages was found by mutating the implementation and reading WHY a
   row went red — never by running the gate.** The gate proves a guard fires; only a mutation proves
   it fires for the right reason, and twice in this stage a row was green against the very thing it
   existed to forbid. Budget mutation loops as the real cost of a detector, not as verification
   after it.
2. **The assertion set is now dense enough that a real defect turns several rows red at once.**
   Dropping one manifest field reddened four rows across three scenarios. Read the *first* red row
   and the reason, not the count — a count invites the conclusion that something large broke.
3. **The three unreached fault classes are unreached in three different ways** and D11's counters
   must not merge them: `approval_deadline_exceeded` is *structurally* unreachable (the driver's
   approval channel carries no duration — a declared gap, not a solved problem); the provider fault
   class is *one field away* (A14's, cluster 10); `ToolCorrelationMismatch` and `ToolDeadlineExceeded`
   are *codec-covered, scenario-unreached*. Three counters, three meanings.
4. **The A5 anchor cost is structural for port-shaped changes and zero otherwise, and this is now
   measured over four stages.** Stages 3, 4, 5 and 6 all paid nothing by writing below anchors,
   widening lines and import lists in place, and running `sed -n '161p'` after each edit. Stage 2 and
   cluster 10 both paid a `driver_only` re-issue, and both because **a new `StepProvider` variant
   forces a match arm that cannot sit below the sites it precedes.** A14 adds a `ScriptedStep` field
   for the provider fault channel — check whether that is a variant before assuming it is free.
5. **The CI replay affordance is A14's and it is now cheap.** D8 requires CI output to carry a
   copy-pasteable local replay command or artifact reference. `artifact_path` gives the reference,
   `load_program` gives the command's other half, and `persist_message` already prints the path and
   the identity. What A14 must not do is emit the digest alone: D8's *"a digest without retained
   bytes is not sufficient for replay"* is enforced in the encoding, and a report that names only a
   hash would reintroduce at the reporting layer exactly what the artifact refuses to represent.
