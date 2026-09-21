# NOTE-001 — The effect-inference gap: an inline atom can call `ctx.ports.*` past any `Capability` payload row (2026-09-18)

Status: Measured. Filed upstream as AILANG public-feedback ticket **`fb_30e82f6bdc5fc8c3`**
(queued 2026-09-18T13:47:55Z, category bug, via `mcp.ailang.sunholo.com` `submit_feedback`; no
GitHub mirror yet — `GH_TOKEN` was invalid in the devcontainer and `~/.ailang/config.yaml` unset).
Grounded at: HEAD `2062605`, ABI `7.4`, AILANG `v0.33.0` (commit `ae36986`, built 2026-09-17),
equal to the `ailang.lock` pin.
Found by: the v0.2 review of ADR-001 (`REVIEW-adr001-v0.2-verdicts-claude.md`, finding N14 /
freeze blocker F1). This note carries the evidence so the review, the ADR's F1 remedy, and the
017 tooling changes can cite one place, and so the repro survives the session scratchpad.

Cross-references: `../017_extension_handling/ADR-001-extension-abi-evolution.md` §3.3 and the B8
correction (the claim this note narrows); `scripts/dst/run_declared_vs_performed.sh` IMPORTED-SUM
rows (the gate that reads green); `tools/ext_ambient_inventory/hook_scope.py` (the instrument that
cannot see it); `packages/motoko-ext-abi/types.ail` `Capability` (the slots affected);
`ADR-001-extension-owned-structured-decisions.md` D2 (the claim that motivated the probe).

## 0. TL;DR

In AILANG v0.33.0 the inferred effect row of an **unannotated anonymous function** omits the effects
of a call when **both** hold: the callee is a **record-field projection** (`e.f(args)`) and at least
one argument is **derived from the lambda's own parameter**. The lambda then unifies against a
rowless or narrower closed payload row and is accepted; with the capability granted, the effect
performs at runtime. Break either condition — literal argument, callee bound to a local first,
annotated lambda, or a named top-level function — and the checker rejects correctly.

`ctx.ports.ai_step(ctx.world, …)` is the trigger shape by construction: the callee is a projection
of the parameter and the world token is a field of the same parameter. So every `ExtCtx`-taking
slot can be given an inline atom that performs `{AI, IO, Trace}` — in `ToolPolicy` (`{}`), in
`PromptShaper` (`{}`), and past `SolverJudge`'s `! {Process}` — with `✓ No errors found!`. Nothing
in-tree does this today; the two inline registrations in the tree are safe by accident (one is
annotated, one calls a named function). Nothing in-tree would catch it either.

## 1. Minimal reproduction (two modules, no dependencies)

`ailang.toml`

```toml
[package]
name = "local/repro"
version = "0.1.0"
edition = "1"
module_prefix = "repro"
ailang = ">=0.33.0"

[dependencies]
```

`repro/types.ail`

```ailang
module repro/types

export type Ctx  = { name: string, emit: (string) -> () ! {IO} }
export type Slot = Pure((Ctx) -> int)
```

`repro/main.ail`

```ailang
module repro/main

import std/io (println)
import repro/types (Ctx, Slot, Pure)

func smuggler() -> Slot {
  Pure(func(ctx: Ctx) -> int {
    let _ = ctx.emit(ctx.name);   -- accepted; `ctx.emit("x")` is rejected
    1
  })
}

func run_slot(s: Slot, ctx: Ctx) -> int {
  match s { Pure(f) => f(ctx) }
}

export func main() -> () ! {IO} {
  let ctx: Ctx = { name: "SMUGGLED: IO performed through a {} slot", emit: func(s: string) -> () ! {IO} { println(s) } };
  println("slot returned ${show(run_slot(smuggler(), ctx))}")
}
```

Verbatim output, run from the repro root:

```
$ ailang check repro/main.ail
✓ No errors found!

$ ailang run --caps IO --entry main repro/main.ail
✓ Running repro/main.ail
SMUGGLED: IO performed through a {} slot
slot returned 1

$ ailang run --entry main repro/main.ail          # capability withheld
Error: execution failed: effect 'IO' requires capability, but none provided
Hint: Run with --caps IO
```

Expected for `check`: rejection at the `Pure(...)` application, the message every control below
produces:

```
Error: type error in repro/<file> (decl 0): type unification failed at [function application at
repro/<file>.ail:7:7]: failed to unify parameter 0: failed to unify effect rows: incompatible
closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

### Controls (each is the repro with one change; each is REJECTED with the message above)

| File | Change |
|---|---|
| `control_literal.ail` | `ctx.emit("x")` — literal argument |
| `control_local_callee.ail` | `let e = ctx.emit; e(ctx.name)` — callee bound to a local first |
| `control_named.ail` | same body as `func named(ctx: Ctx) -> int`, then `Pure(named)` |

## 2. The boundary (standalone bisect)

Types for this table: `Ctx = { name: string, n: int, world: World, ports: Ports, emit_direct: (string) -> () ! {IO} }`,
`Ports` with `emit: (string) -> () ! {IO}`, `stepw: (World) -> Out ! {IO}`, `stepi: (int) -> Out ! {IO}`,
`step3: (string, string, string) -> Out ! {IO}`, `stepl: ([string]) -> Out ! {IO}`; slot `Pure((Ctx) -> int)`.
Each row is one inline unannotated lambda in the slot.

| Call in the lambda | Callee | Argument | Verdict |
|---|---|---|---|
| `ctx.ports.emit("x")` | projection | literal | rejected ✔ |
| `ctx.ports.step3("a","b","c")` | projection | literals | rejected ✔ |
| `ctx.ports.stepl([])` / `stepl(["a"])` | projection | literals | rejected ✔ |
| `let s = "x"; ctx.ports.emit(s)` | projection | local from literal | rejected ✔ |
| `ctx.ports.emit(outer)` | projection | captured variable of the enclosing function | rejected ✔ |
| `ctx.ports.emit(show(1))` | projection | call result not involving the parameter | rejected ✔ |
| `ctx.emit_direct(ctx.name)` | projection, one level | parameter field | **ACCEPTED ✘** |
| `ctx.ports.emit(ctx.name)` | projection, two levels | parameter field | **ACCEPTED ✘** |
| `ctx.ports.stepw(ctx.world)` | projection | parameter field (a record) | **ACCEPTED ✘** |
| `let w = ctx.world; ctx.ports.stepw(w)` | projection | local from the parameter | **ACCEPTED ✘** |
| `ctx.ports.emit("${ctx.name}")` | projection | parameter inside interpolation | **ACCEPTED ✘** |
| `ctx.ports.stepi(length(ctx.name))` | projection | parameter through a `std` call | **ACCEPTED ✘** |
| `ctx.ports.step(ctx.world, "m", ["a"])` | projection | mixed, one from the parameter | **ACCEPTED ✘** |
| `let e = ctx.ports.emit; e(ctx.name)` | **local variable** | parameter field | rejected ✔ |
| same body in a named `func` | projection | parameter field | rejected ✔ |
| nested lambda inside a named `func`, capturing its `ctx` | projection | parameter field | rejected ✔ (the named function's pass walks the whole body) |
| lambda annotated `! {IO}` | projection | parameter field | rejected at the annotation ✔ |

Two conditions, jointly necessary: **projection callee** and **parameter-derived argument**.

## 3. On the real ABI (`pkg/sunholo/motoko_ext_abi/types`, imported sum)

Eighteen probes were run from the repository root so the package path resolved. The ones that
decide the matter:

| Probe | Slot (payload row) | Atom | Body | Measured |
|---|---|---|---|---|
| p1 | `ToolPolicy` (`{}`) | inline, unannotated | `ctx.ports.ai_step(ctx.world, "m", [])` | **ACCEPTED** |
| p6 | `ToolPolicy` (`{}`) | `let`-bound inline, unannotated | same | **ACCEPTED** |
| p16 | `PromptShaper` (`{}`) | inline, unannotated | same | **ACCEPTED** |
| p17 | `ToolPolicy` (`{}`) | inline, unannotated | `ctx.ports.clock_now(ctx.world)` | **ACCEPTED** |
| p18 | `SolverJudge` (`! {Process}`), enclosing `caps() ! {Process}` | inline, unannotated | `ctx.ports.ai_step(…)` | **ACCEPTED** — `{AI, IO, Trace}` past a `{Process}` row |
| p2 | `ToolPolicy` (`{}`) | inline, unannotated | pure | accepted (control) |
| p8 | `ToolPolicy` (`{}`) | inline, unannotated | `std/io.println("smuggled")` | rejected `[IO]` — direct `std` callee is inferred |
| p13 | `ToolPolicy` (`{}`) | inline, unannotated | `let step = ctx.ports.ai_step; step(ctx.world, …)` | rejected `[AI IO Trace]` |
| p5 | `ToolPolicy` (`{}`) | named, unannotated | `ctx.ports.ai_step(…)` | rejected `[AI IO Trace]` |
| p9 | `ToolPolicy` (`{}`) | inline, annotated `! {AI,IO,Trace}` | same | rejected at the annotation |
| p12 / p15 | `ToolPolicy` (`{}`) | inline calling a named helper that applies the port | via helper | rejected — the helper's row is inferred |
| p14 | `ToolPolicy` (`{}`) | named, with an inner lambda applying the captured `ctx.ports.ai_step` | nested | rejected |

p18 shows the defect is under-inference of the lambda's row, not a special case of empty rows.
Runtime execution was proven standalone (§1), not on the ABI (constructing an `ExtCtx` by hand
was not attempted).

## 4. Why the tree's gates read green

- **017 ADR-001 B8** and the IMPORTED-SUM rows of `scripts/dst/run_declared_vs_performed.sh`
  measure an inline atom performing **`std/env`** with **literal** arguments. That is a named
  `std` callee, so its row is inferred and the row correctly REJECTS. The conclusion recorded there
  — "an unannotated inline atom is rejected at the payload row" — is true for what was measured
  and false for the port-call shape, which is the only effectful thing an `ExtCtx` offers.
- **`hook_scope.py`** enumerates doors 1–6: `std/*` symbols, `_` builtins, other builtins,
  interpolations, unresolvable bindings, registration-time effects. A port call is classified
  `HOOK-PORT-MEDIATED` — the *good* verdict. For a slot that must be port-free there is no rule.
- **`make profile_coverage`** (`dst_profile_coverage.ail`) treats pure slots as needing no port
  coverage because they can do nothing. That now depends on binding shape, which the classifier
  does not read.
- **The runtime capability check** works (§1, no-caps run) but Motoko launches the runtime with
  every capability granted (`Makefile:312`, `--caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand`).

In-tree registrations at HEAD: `context-mode`, `omnigraph`, `microrag`, `repetition-guard`,
`empty-stop-guard` bind **named** functions (checked). `progress-contract-guard/register.ail:20`
is inline but **annotated** `! {Process}` (checked against the annotation). `compose.ail:1110` is
an inline lambda whose callee is a **named** function (inferred). None exploits the gap.

## 5. Consequences if unfixed upstream

1. **Dropped successor world.** Nine of the ten `ExtPorts` fields take and return the world token
   (`types.ail:294-497`). A pure slot's decision type has no `next_state`, so a smuggled
   world-threading call advances the ordinal inside the port and the driver continues from the
   stale world — the F6 defect class (`types.ail:698-701`) reached from the other side. The DST
   may surface it as a strict-replay identity mismatch at the *next* driver call; that is a
   runtime symptom with a misleading location, not a compile error or a normalization refusal.
2. **Unrecorded effect.** `env_get: (string, string) -> string ! {Env}` (`types.ail:524`) is the
   one un-widened, non-world-threaded field. A pure slot can read the environment at hook time
   with nothing recorded — undisclosed nondeterminism in a slot classified pure.
3. **Misattributed spend** under ADR-001 (031): a smuggled `ai_step` in `prepare` is a model call
   the decision ledger, the reservation logic and shadow mode never see.
4. **Documentation debt.** `types.ail:1263-1266` ("`! {FS}` is the whole enforcement: a render that
   wanted to spawn a subprocess could not") and 017 §3.3 become review-enforced claims. For
   published third-party extensions (README, registry) that is a claim without backing.

## 6. Mitigations, cheapest to most complete

| Mitigation | Closes | Cost | Residual |
|---|---|---|---|
| **Annotation-or-named rule** in `hook_scope.py`: every inline `func` in a capability list must carry a `!` row, or be a named binding. Annotated lambdas are checked against the annotation (p9); named functions go through the body-walk pass (p5, p14). | the registration surface, completely | a check on the literal list the tool already parses; fail closed on unresolvable | none for registration |
| **Trigger-shape row** in `run_declared_vs_performed.sh`: `Pure(func(ctx) { ctx.ports.<port>(ctx.world) })` must be REJECTED. **Red today.** | nothing by itself; makes the gap visible and detects the upstream fix landing | one row | documents rather than closes |
| **Ports-free context** (no `ports`, no `world`) for rowless slots and for ADR-001's `prepare`/`interpret` | 1, 2, 3 for pure slots, structurally | ABI 8.0 change; the `ExtCtx` literals are being rebuilt anyway | narrow slots still exposed |
| **Per-slot ports views** for narrow slots: a record holding only the fields the slot's row admits (`{FS}` slots get the six FS ports and `clock_now`) | everything, structurally; rows become documentation of a fact the record type enforces | more context types at 8.0 | none — least authority in data, immune to inference |
| Re-run §1 at every toolchain bump | drift | already the practice (017 §5 item 5) | — |

Recommended: the annotation-or-named rule and the red row regardless of anything else; the
context-type changes into 8.0 while it is open (ADR-001 F1 for the new capabilities; the
per-slot views for the existing narrow slots).

## 7. Re-test procedure

At each AILANG bump: recreate §1 (three files), run `ailang check repro/main.ail`. **Fixed** when
it rejects with `r2 has extra labels [IO]` at `repro/main.ail:7:7` while `ailang check
repro/control_named.ail` still rejects (so the fix did not simply stop checking). Then flip the
red row in `run_declared_vs_performed.sh` to expect REJECTED and re-run the p1/p6/p16/p17/p18 set
against the real ABI.

## 8. Mechanism (hypothesis, for upstream; not a finding)

Named top-level functions go through the separate "Effect checking…" pass, which walks the body
and collects every call's row (hence p5, p14). Anonymous functions get their row from unification
alone. The pattern — known-typed arguments fine, parameter-derived arguments lost, callee-as-local
fine — suggests that when the callee is a projection and an argument's type is still being
resolved against the parameter, the application unifies the callee's *type* without adding its
effect labels to the enclosing lambda's row.

## Provenance

Probes and the standalone repro were written to the session scratchpad
(`…/scratchpad/probe/p1…p18.ail`, `…/scratchpad/repro/`, `…/scratchpad/repro_min/`) and run with
the PATH `ailang` (`/home/motoko/.local/bin/ailang`, v0.33.0). Every verdict in §1–§3 is a direct
`ailang check` / `ailang run` result; none is inferred. The upstream report body is the §1–§3
content plus §8, 6,046 bytes, snippet = the two §1 files.
