# Handoff: close acceptance row 10 — the filesystem world class, and the last red row

Audience: a fresh session grounded against HEAD. Source-heavy driver work; you are that session.

**Third and last item of C4's post-gate work list.** The plan has nothing after Milestone C — C4's
planning defect 1 — so this is scheduled by acceptance row.

**WI-D2 landed 2026-08-05** (~46 min): `d64_gap_register` 13 → 2, row 7 green on all three conjuncts,
`make ledger_parity` comparing 17 variants wire-against-trace. Verified at review: register at 2,
`witnessed=17` with the nine unwitnessed variants printed **by name**, and the M5 mutant reproduced —
with the driver appending nothing, `make event_vocabulary` and `make invariants` are **both exit 0**
while the wire gate catches it. **Confirm tree state with `git status`.**

**Read first:** `NOTE-d2-parity-register-row-7.md`, then **`Makefile:1392-1416`** — the recorded reason
this row was deferred is precise, correct, and is most of your design. Then the plan's
`## Standing rules`; **S7, S15 and S16 all grew at D2.**

## Mission

**Give the world a filesystem class, route `resolve_context_limit` through it, and build the host-env
poison pair.** Row 10 — *"probes show ambient effect, host-env, clock, and RNG bypasses fail or are
detected"* — is **the only red row left**. Ten of C4's eleven hold.

## What is actually wrong, and it is not what the row's name suggests

**The driver's own env reads are all routed already.** `session.ail` has zero `getEnvOr` calls; A12
routed all six through `Ports.env_get`. What kills an `Env`-withheld deterministic run is one module
the driver calls and does not thread:

```ailang
-- src/core/context_usage.ail
import std/fs (fileExists, readFile)
import std/env (getEnvOr)

export func resolve_context_limit(model: string) -> int ! {Env, FS}
```

It takes **only a model** — no world, no ports — and is called at **eight sites** (six in
`session.ail`, two in `rpc.ail`). Its two halves each read env **to compute a file path they then
read**: `config_context_limit_override` builds `"${profile_dir_path()}/config.json"`, and
`catalog_context_limit_for` reads `catalog_path()`. Four variables — `MOTOKO_MODELS_FILE`,
`MOTOKO_REPO`, `MOTOKO_PROFILE_DIR`, `MOTOKO_CONFIG`.

**The world has an `env` table and no file table.** `WorldState` carries
`env: [{ key, value }]`; `Ports` has five classes and none of them is a file read
(`tool_exec` declares `! {IO, Process, FS}` but is a tool invocation, not a read).

## The rule you will break by accident

**Routing the env half alone produces a green check that implies absent coverage**, and the Makefile
already says so at `:1403-1409`:

> Threading the world through the env half would hand back a world-supplied path to an **ambient
> file** — a run that passes an Env poison probe while still depending on ambient state.

That is cluster 4's **C1b defect**, and it is the single most likely way this item ships something
worse than what it replaces: the probe goes green, the row gets marked closed, and the dependency is
still there. **Both halves route or neither does.** The env read becomes `Ports.env_get` (which
already exists) and the file read becomes the new class; only then does the path stop being a handle
to the host.

## Three things the design has to get right

**1. The pair must be TWO-SIDED, like AI and Clock.** Every enforced class in `make world_state` has
both halves — *"deterministic world completes with X withheld"* **and** *"live world dies with X
withheld"*. The second is what makes the first non-vacuous: without it, a class that never performs
the effect at all would pass. D2's M5 is the general form of that mistake, one artifact up.

**2. It works because AILANG gates on PERFORMED, not DECLARED** — the mechanism C5's whole detector
rests on, recorded at `ports.ail:406`. `tool_exec` **declares** `! {IO, Process, FS}`, so a naive
reading says withholding `FS` must kill any run that dispatches a tool. It does not: the scripted
adapter performs no filesystem read, and the interpreter only fails on a capability when a read is
actually performed. **Confirm that empirically before designing around it**, because the whole pair
depends on it and the declared row says the opposite.

**3. The class is a POINT READ, not a filesystem.** What is needed is `fileExists` + `readFile` on a
path — the same narrowness as `env_get`, not the generality of `tool_exec`. A world file table plus a
`(WorldState, string) -> FileRead ! {FS}` returning existence, contents and successor is the whole
surface. **Resist widening it to writes or listings**; nothing in the driver's call graph needs them,
and D1's rule is that the world models what the driver actually observes.

## The narrowing move to refuse

**Do not close this row by calling the existing provenance assertion "detection".** The row says
bypasses *"fail or are detected"*, and the probe today seeds `MOTOKO_HEADLESS` in the world and
asserts the driver acted on the world's value, with a control proving the branches differ. **That is
real and it is not this row.** C4 ruled on it explicitly: *provenance is not hermeticity* — it shows
the driver read the world where it was asked to, and says nothing about other code reading the host.
A one-line reclassification here is the same species as reclassifying a Logical variant `DisplayOnly`,
which D2 declined.

## Definition of done

**The host-env poison pair, both halves**, joining AI, Clock and the typed tool contract — and
`make world_state`'s deferral note removed rather than edited, because the thing it defers will exist.

**`resolve_context_limit` threaded at all eight call sites**, with the world supplying both the path
and the contents.

**Row 10 re-answered against the ADR's text**, with RNG's honest "unused" left as it is — it is
reported rather than claimed and that was already correct.

**Per S16 — say which producer each half of the pair comes from.** A poison pair is an
out-of-process observation (the interpreter kills the run), which is why it is strong; make that
explicit rather than letting it look like another in-process row.

**Per S15 — the reason for anything left open is a MEASUREMENT, not a diagnosis**, and a structural
reason must name the thing that would have to change, not where the code lives. D2 found nine wrong
reasons of thirteen by ignoring this.

**Per S18 — tense every comment BEFORE deriving anchors.** D2 paid the cascade once by doing that and
was the first item to manage it; this item changes `Ports` and `WorldState`, so the cascade is
certain — see the widening trap in the plan.

**Per S13/S9/S17** — sweep cache-cold with `AILANG_RELAX_MODULES=1` and confirm the failing set
member-for-member; clear every live `.ailang/cache` and leave `~/.ailang/cache/registry` alone;
mutation loops restore by `cp`.

## What happens after this item, stated so it is not assumed

**Closing row 10 makes C4's table green. It does not adopt the name, and this item must not.**

D10 has **two** conditions and the second has gone unmentioned for a long time: the label is adopted
*"only after the acceptance test passes for a documented baseline profile **and the project-007
definition/taxonomy ADR is accepted**."* **Checked at review: 007's ADR is `Accepted 2026-07-26`**, so
that condition is already satisfied and the acceptance table is the only thing outstanding.

**Re-running the gate is a separate act** — C4's item exists precisely because running the table is
its own work — and two of the ten current passes are **vacuous in their installed-extension clauses**.
Per D10 those transfer to no second profile. **A green gate for `driver_only` is a green gate for
`driver_only`**, and the report should say so in those words.

## Out of scope

- **Re-running C4's acceptance table and adopting the name.** The next item, and deliberately not
  this one.
- **The `on_budget_plan` ABI change** and everything gated on it: compose's install,
  `ScratchpadResult`'s and `SessionSuspend`'s coverage, `proc_exec`/`env_get` widening.
- **The two sibling `st.world_state` finalize sites** (`SealSystemPromptEmpty`, `SealExhausted`).
- **D4's provider latency pair** — the recorder half. **The adversarial partial stream** — D1's
  residue. The `motoko-ext-abi` major; the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts;
  the two v0.33.0-fixed workarounds.

## Stop and report rather than deciding inline

- **If withholding `FS` kills the deterministic run for a reason other than `resolve_context_limit`**,
  report the site before routing it. The Makefile's note names one cause; a second would mean the
  class is wider than a point read and that changes the design.
- **If threading the world into `context_usage` pulls `Ports` into a module that cannot import it
  without a cycle**, stop — `dst_generator` hit the mirror image of this and the answer was an import
  direction, not a duplicated type.
- **If the pair can only be made green by narrowing what the probe claims**, that is the provenance
  move above. Report it rather than taking it.

## Report back

Twenty-seventh calibration run, and the last row.

- **The git wall-clock window.**
- **Both halves of the pair, and what each producer is.** The item's durable output.
- **Whether row 10 is green and therefore whether C4's table is** — and say plainly that a green table
  is not an adopted name, with D10's two conditions and 007's status named.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **53 across
  twenty-six runs; determinism has caught none.** D2's was in the instrument rather than the tree, and
  this item builds an instrument whose failure mode — a probe green because the effect was never
  performed — is exactly that shape.
- **How many recorded reasons you found stale.** D1 found seven where five were named; D2 found seven
  where none were. The Makefile note this item deletes is itself one of them, and the count is a
  measurement this project now tracks.
