# Handoff: WI-D8 — measure `ExtPorts.ai_step`'s row, and revisit `on_pre_step`'s barrier

Audience: a fresh session grounded against HEAD. Source-heavy ABI measurement, small in edits.

**WI-D7 landed 2026-08-06** (`eed91bd`, ~45 min): all three remaining barriers measured, Route A
refused for each by exactly one binding of fifteen, two rows narrowed anyway to buy the compiler as
enforcer, and **the barrier count made a derived, checked artifact**. Verified at review:
`make profile_definition` prints `3 barrier(s) stand, so NO extension is installable in a conformant
profile`, `make dst` exit 2 with only the two pre-existing red targets, **870 ✓ rows**,
`declared_vs_performed` 26/0.

**Read first:** `NOTE-d7-the-three-remaining-barriers.md` — its measurement method is yours, and its
`on_pre_step` conclusion is what this item tests. Then the plan's `## Standing rules`; **S21 and S22
both grew at D7 and both grew against the item that earned them.**

## Mission

**Measure `ExtPorts.ai_step`'s declared row, which nothing has ever measured, and re-decide whether
`on_pre_step` is a barrier.**

D7 concluded that `on_pre_step`'s barrier is **the row's vocabulary — "not the behaviour, and not the
row's width"** — because its one performing binding reaches all ten effects through
`ctx.ports.ai_step`, "whose own port row is exactly those ten." **That last clause was taken as given.
It is not.**

## The measurement, taken at review and reproducible in four minutes

`ExtPorts.ai_step` declares **ten** effects. The bridge closure declares ten. `ext_ai_step` declares
ten. **And `ext_ai_step`'s entire effect demand comes from `p.model_step`, which is
`! {AI, IO, Trace}` — three.**

I narrowed `ExtPorts.ai_step` to `{AI, IO, Trace}` along with the eleven annotation sites carrying the
same ten-effect row, and `ext_ai_step` itself. **Result:**

| Module | With `ai_step` at 3 |
|---|---|
| `packages/motoko-ext-abi/types.ail` | **GREEN** |
| `packages/motoko-ext-compaction-ai/compaction_ai.ail` | **GREEN** |
| `src/core/ext/ctx_defaults.ail` | **GREEN** |
| `src/core/ext/runtime.ail` | **GREEN** |
| `src/core/session.ail` | **GREEN** |

**No body failed. `ExtPorts.ai_step`'s row appears over-declared by seven effects** — `Process`, `FS`,
`Env`, `Net`, `SharedMem`, `Clock`, `Stream` — none of which `Ports.model_step` can produce.

Narrowing `on_pre_step` to match then leaves `types.ail` and `compaction_ai.ail` green, with
`runtime.ail` and `session.ail` reporting `extra labels [Clock Env FS Net Process SharedMem Stream]`
— **an annotation mismatch on the dispatch folds' own rows, not a body failure.** That is D7's own
silently-wrong site 1, and resolving it is this item's work: narrow the folds and read the effect
checker again.

**Probe reverted; the tree is byte-identical to `eed91bd`.**

## Why this changes D7's conclusion, and how much

**It does not refute the vocabulary point; it removes the strongest objection to mediation.**

D5 criterion 2 admits a hook that is effectful only through world-mediated ports and returns explicit
world state. `PreStepOutcome.next_state` is returned. `Ports.model_step` is a D1 world-mediated port.
D7's finding was that the criterion is evaluated against the *declared* row, and a declared row cannot
say "this effect arrives through a port."

**But at ten effects, seven of them are effects `model_step` cannot produce — so the row was positive
evidence AGAINST mediation.** At three, every declared effect is exactly what the mediated port
produces. **The row stops contradicting the claim.** Whether that is sufficient for D5 is a judgement
this item must make and record, not assume in either direction:

- **If sufficient**, `on_pre_step` stops being a barrier and the count goes 3 → 2, **with no ADR
  amendment and no port-surface change** — which is a materially different position from the one D7
  left.
- **If not sufficient**, D7's vocabulary conclusion stands, and the narrowing is still worth taking
  for the reason D7 took its two: it buys the compiler as enforcer.

**Do not let the narrowing alone decide it.** A narrowed row that still fails criterion 2 is a real
outcome and the honest report says so.

## The rule you will break by accident

**A green check after narrowing an annotation is not evidence that a body performs less.** D7 counted
this as a silently-wrong site and it is the exact hazard here: narrowing a record field's row and
seeing `incompatible closed rows … extra labels [...]` compares **two annotations**. An over-wide
annotation on an effect-free body produces a byte-identical message.

**The distinguishing move, which D7 established: narrow the refusing helper's OWN row and read again.**
A body that genuinely performs the effect gives `Effect checking failed for function '<name>'`. My
probe above narrowed annotations tree-wide and got green, which is suggestive — **it is not the same
as having driven each refusal down to a body.** Do that.

**And per S22 as D7 extended it**, do not take the annotation-site count from this handoff. I found
eleven by grep; **derive the set and assert it**, because a scope claim taken from prose is the defect
that has now bitten D6 and D7 in succession.

## What the other two barriers need, unchanged

`on_response_intercept` (`! {IO, Process, FS, Clock}`) and `on_solver_candidate` (`! {Process}`) are
**genuine behaviour**, measured by D7 and not in doubt: compose's inline path calls
`mkdirAll`/`writeFile`/`removeFile` and spawns the compiler; `context_mode.finalize_with_index`
spawns a `node` bridge (`context_mode.ail:185`). **No narrowing reaches those.** They need
world-mediated process and file seams on `ExtPorts` — which is **Route B**, and which connects
directly to the long-owed `ExtPorts.proc_exec`/`env_get` widening that has been WI-C5's since B2b left
them as classifier-2 members.

**That is not this item.** This item is the one barrier where the work may already be done.

## Definition of done

**`ExtPorts.ai_step`'s row measured**, with every refusal driven down to a body or to an annotation,
and the two distinguished — per D7's method, not by reading `extra labels`.

**A decision on `on_pre_step`, recorded either way**, against D5's criterion 2 read directly. **If it
stops being a barrier, the derived count in `make profile_definition` moves 3 → 2 on its own** — that
gate already exists and will say so without being told.

**Whatever narrows, narrows.** Even if the barrier stands, a row seven effects wider than any body
needs is a row that lets a binding start performing `Process` silently.

**Per S22 — derive every list this item quantifies over** and assert it in the gate: the annotation
sites, and the bindings.

**Per S13/S9/S17/S19** — sweep cache-cold with `AILANG_RELAX_MODULES=1`, failing set member-for-member;
run `make dst` in full; clear every live `.ailang/cache`, leave `~/.ailang/cache/registry` alone,
check no other session is running a gate; restore mutants by `cp` or `tar`, never `git checkout`; read
artifacts not transcripts, and never `$?` after a pipe.

## Out of scope

- **Route B for the other two slots** — world-mediated process/file seams on `ExtPorts`. Larger than
  everything D6 and D7 did together, and it is WI-C5's.
- **Installing anything.** If this item takes the count to zero, **stop and report** — reaching zero is
  WI-C5's trigger and the derived gate is written to go red on it precisely so that it is decided.
- **The `motoko-ext-abi` major** — seven changed rows now, and this item may add an eighth. State the
  count; do not cut it.
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds;
  `test_coverage` and `test_coverage_selftest`.

## Stop and report rather than deciding inline

- **If narrowing `ai_step` changes what any extension can do**, that is a capability change on the
  extension surface and is larger than a row edit.
- **If the barrier count reaches zero**, stop — see out of scope.
- **If `on_pre_step` turns out to need an ADR amendment to D5's criterion 2**, report the amendment
  rather than writing it. D5 is Accepted and amendments go through a normal round.

## Report back

Thirty-second calibration run.

- **The git wall-clock window.**
- **`ai_step`'s measured row**, with each refusal classified as annotation or body. The item's durable
  output.
- **The `on_pre_step` decision** and the barrier count the gate derives afterwards.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **59 across
  thirty-one runs; determinism has caught none.** Both of D7's were in reading a declared row as
  evidence of behaviour — **this item is made entirely of that reading**, so look there first and
  hardest.
- **Whether D7's vocabulary conclusion survives.** Say so plainly either way; it is the sentence WI-C5
  inherits.
