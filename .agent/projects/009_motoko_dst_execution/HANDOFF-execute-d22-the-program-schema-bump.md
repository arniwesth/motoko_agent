# Handoff: WI-D22 — `execution-program/2`, and the freeze it finally makes possible

Audience: a fresh session grounded against HEAD. **The change three items have owed and one has
scheduled.** WI-D21 ended by naming it: *"the schema bump now has two consumers… per S23 it should be
scheduled. Take the `proc_exec` field rename in the same item."*

**Read first:** `NOTE-d21-…` §3.1 and §6, then `NOTE-d17-…` §7b — the two-tier compatibility surface
D17 created and said only a future schema version could close. **This is that version.**

## What the bump carries — three payloads, not two

| Payload | Owed since | Why it needs the version |
|---|---|---|
| **`InitialWorld.files`** | D17, and **D18 grew it a field** before it was taken | `world_state_of` reconstitutes `files: []`, so a deterministic run's filesystem cannot be seeded at all |
| **`ScriptedTool.exit_code`** | D21 | the deterministic half cannot say whether a subprocess succeeded |
| **A FROZEN v2 SPECIMEN** | D17 §7b | **three classes are round-tripped and NOT frozen** |

**The third is the one nobody has to be told twice, and it is free with the other two.**
`post_v1_interactions()` holds exactly `FileWriteIdentity`, `FileRemoveIdentity`, `DirMakeIdentity` —
verified — and D17 recorded that nothing in the tree can freeze them *"because there are no historical
bytes containing them; the only fix is a future freeze at a future schema version."* **Freeze them
here or the two-tier surface grows a fourth class next time.**

## The trap that is live right now

```ailang
export pure func decodable_schema_versions() -> [string] {
  [program_schema_version()]            -- dst_program.ail:65
}
```

**A one-element list DERIVED from the current version.** Bump `program_schema_version()` alone and the
build instantly cannot decode `scripts/dst/fixtures/execution-program-v1.artifact`, whose first line is
`execution-program/1` — verified.

`program_persistence`'s `scenario_the_frozen_v1_specimen_still_decodes` is the row that catches it, and
**the module's own comment states the rule**: *"A migration extends this list and keeps the old decode
path, or it does not extend it and old programs fail closed. There is no third option in which the
program is read anyway."* **Extend it and keep the path.** `dst_program.ail:575-576` already asserts
the list's shape and that `execution-program/0` is not in it — that pair is the template.

## The transcribed constant, and it is S23's own shape

**`dst_replay.ail:999`'s `fixture_program()` states `"execution-program/1"` as a literal.** Measured: it
is **the only live transcription outside the producer** — the two other occurrences are comments
(`stub_step.ail:498`, `dst_interaction.ail:104`).

**Decide which it is** — a fixture deliberately pinned at v1 (in which case say so at the site, because
it will read as staleness forever) or the current version transcribed (in which case derive it). **S23
was promoted for exactly this shape and D14 paid for it live**, so this is the rule's own test case.

## The design question: where does `FsNode` live?

`InitialWorld.files` must be **kinded**, because D18 made `WorldState.files` kinded and a seed that
cannot express a directory cannot seed the world D18 built.

Measured: **`FsNode` is `ports.ail:517`**, and **`dst_program.ail` does not import `ports`, nor `ports`
`dst_program`** — both import `dst_interaction`. **So there is no cycle**, and three options are open:

1. **`dst_program` imports `ports`** — cheapest, and it makes the persisted program schema depend on
   the runtime's world types. Say whether that layering is intended.
2. **Move `FsNode` down to `dst_interaction`**, which both already import. A type move with pinned
   consumers — `ext_world.ail:41` imports it by name.
3. **Give `InitialWorld` a structurally-identical anonymous shape** — `[{path, kind: string, content}]`.

**Option 3 looks cheapest and is a trap.** It reintroduces precisely what D18's sum was chosen to
prevent — *"`{path, kind: "dir", content: "hello"}` is a directory carrying a file body, and something
would then have to forbid it"* — **at the persistence boundary, which is where hand-written and
corrupted artifacts enter.** If it is taken anyway, the forbidding has to be built and asserted.

## Two codecs for one structure

**The kinded table already has an encoder**, and it already made the decision this item will face
again. `ext_world.ail:245-252` encodes `FsFile`/`FsDir` as `kind: "file"`/`"dir"`, and its comment
records the fallback: **decode absence as `FsFile`, because falling back to `FsDir` "would silently turn
an old world's whole file table" into directories.**

**`dst_persistence` is a different format** — tag/arity lines, not JSON (`world.clock_epoch` at arity 1,
`env_lines` for the environment), verified. So `InitialWorld.files` needs **new tags there**.

**Say whether the two codecs share or are deliberately separate, and if separate, pin them against each
other.** Two encodings of one structure is the two-homes shape D16 and D17 both argued from, one layer
down — and this time both homes are code you wrote.

## Per S30, this item is the rule's positive case

S30 was promoted from D21's measurement: *a field added to a persisted payload without moving the
version makes a recorded failure replay as a success, because absence decodes to the default and the
loud guard only fires on a version it does not know.* **Every field here is added WITH the version,
which is the whole difference between a migration and a silent reinterpretation.** Say at each new
field what an artifact that predates it decodes to, and why that is refusal rather than a default.

## The `proc_exec` rename, and the question it forces

D21 left it here deliberately: **`ExtPorts.proc_exec` says "execute a process" and the seam dispatches a
Motoko tool name.** That misreading sent two items looking for a subprocess seam and put three no-op
packages on a `(_cmd, _cwd)` reading. Four in-tree implementation sites, zero external consumers — and
a **breaking** change to a published ABI at 5.0.

**So state the release question rather than inheriting the deferral.** The ABI stands at **fifteen rows
plus five added types**, deferred by seven consecutive items on the correct ground that **cutting it is
a release act**. Those fifteen are widenings and additions; **a rename is the first genuinely breaking
one.** Either cut the major here and say so as a release decision, or **say what the rename does to a
consumer that has not re-released** — the two are not the same answer and "defer again" is only one of
them.

## Definition of done

**`program_schema_version()` at `execution-program/2`, `decodable_schema_versions()` extended, and the
v1 decode path kept.** The frozen v1 specimen still decodes.

**A frozen v2 specimen containing the three post-v1 classes**, closing D17's two-tier surface. **The v1
bytes are NOT regenerated** — D17's row says regenerating *"destroys the evidence"*.

**`InitialWorld.files`, kinded, with the type-location decision recorded**, and `world_state_of` reading
it instead of reconstituting `[]`.

**`ScriptedTool.exit_code`**, with `encode_tool_outcome`/`decode_tool_outcome` and
`dst_replay.tools_of` following.

**The `dst_replay.ail:999` literal resolved**, derived or pinned-with-a-reason.

**The rename, and the release question answered.**

**Mutants, and per S24 reachability separate from verdict.** The one that matters: **a v1 artifact must
REFUSE rather than decode with defaults** — mutate the decode path to accept it and the row must go red
by name, because that is S30's failure in the exact place S30 was written about.

**Per S13/S9/S17/S26/S28** — `make sync_packages` first (eighteenth consecutive item); sweep cache-cold
with `AILANG_RELAX_MODULES=1` including dependents; restore mutants by `cp`; **append to shared
fixtures**; **do not edit any tracked file while a long instrument runs**; and **never pipe a sweep
through `tail`** — D21 lost a run to it because `tail` buffers and discarded the failing sub-target's
output.

**BUDGET THE ANCHOR CASCADE — it will fire.** The rename touches `ext_ports_of`, and D21 established the
law's final form on the cheapest possible demonstration: **any edit to `ext_ports_of`, prose included,
moves all five `session.ail` anchors and re-issues both profiles.** A `session.ail`-only move costs
**six files, not nine** — the three `*_dst.ail` discovered-site fixtures carry `tool_phase.ail:318` and
are untouched by it. `driver_only_version` is at **19**, `no_ops_version` at **6**.

## Out of scope

- **Routing the four `exec` sites**, and widening `ExtProcOutcome` to carry the typed outcome. This
  item unblocks them; it does not owe them.
- **The eighth recording adapter** and `ExtCtx`'s `ext_id` — what D21 measured `ExtensionEffectIdentity`
  actually needs. Its own item, and `absent_classes` stays untouched until it lands.
- **`on_pre_step` / `on_solver_candidate` successor audits.** Base rate 2 of 2, still owed.
- **The scratchpad loopback successor** (`tool_envelope_dispatch.ail:44`).
- **Door 3's producer**, the hook-scope promotion, C5's compose-bearing profile.
- **The eight stale classifier-2 literals**, now ten items stale.
- Classifier 1's repair; the stdlib cache's producer; the gate-table State column; F3.

## Stop and report rather than deciding inline

- **If freezing a v2 specimen requires regenerating v1's bytes**, stop. D17's row forbids it and the
  split it built (`frozen_v1_interactions()` ++ `post_v1_interactions()`) exists so it is never needed.
- **If `InitialWorld.files` cannot be typed without a cycle, or without moving a type that other
  modules pin by name**, stop and report the layering rather than working around it with option 3.
- **If the rename forces the ABI major**, stop and say so. Seven items have deferred that on a stated
  ground and the decision has consumers outside this project.

## Report back

Forty-sixth calibration run.

- **The git wall-clock window.** D21 ~1h05m, D20 ~1h13m, D19 ~52m.
- **What a v1 artifact does under the new build**, demonstrated by the mutant rather than described.
- **The `FsNode` location decision**, and whether the two codecs share.
- **Whether the v2 specimen is frozen**, and how many classes remain round-tripped-not-frozen. It
  should be zero.
- **The release answer** on the rename.
- **Recorded bindings, decided versus discovered.**
- **Both counters.** Silent-wrong at **75 across forty-three runs**; instrument-weaker-than-its-claim at
  **six**. D21 opened the second and the split was the right call — keep them apart.
- **The yields**, which should still be 4 of 15 and 5 of 15. This item routes nothing.
