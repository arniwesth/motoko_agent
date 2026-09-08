# Handoff: WI-D15 — does criterion 2 quantify over hooks, or over registration too?

Audience: a fresh session grounded against HEAD. **A reading question with a build behind it.** The
reading decides whether the build is worth doing, so settle it first.

**WI-D14 landed the second profile** — `driver_plus_no_ops/1`, four extensions, 32 hooks, all no-ops
— and **all four of row 3's installed-extension clauses bound and held**. Verified at review. It also
produced the first live instance of this project's counted failure mode in thirty-eight runs: the ABI
version pinned at `4.0` while the package declares `5.0`, silent for eleven items. **Counter at 70.**

**Read first:** `NOTE-d14-the-second-profile.md`, then classifier 3's recorded coarsening
(`NOTE-d12-build-classifier-3.md` §9 item 2), then **`ADR:1481-1486`** — the amendment's properties 1
and 2, which this item tests against each other.

## The finding

**Classifier 3 can never clear an extension that mediates, and the reason is registration rather than
behaviour.**

Measured at review, on `compaction_ai` — the one extension whose hooks the tree already argues are
clean:

| File | Imports |
|---|---|
| `compaction_ai.ail` — where the hooks' logic lives | `std/ai` (a **type**), `std/crypto`, `std/json`, `std/list`, `std/option`, `std/result`, `std/string` — **every one proven effect-free** |
| `register.ail` — registration | **`std/env (getEnvOr)`**, **`std/fs (readFileResult)`** |

**Classifier 3 reports `compaction_ai` AMBIENT.** Its closure is six modules and includes
`register.ail`, so the verdict comes from what registration imports, not from what any hook does.

**And `driver_only.ail:597` already contains the counter-argument**, recorded as a live conformance
claim: *"compaction_ai in FACT reaches effects only through `ExtPorts.ai_step` — `compaction_ai.ail`
imports [seven effect-free modules] and calls no ambient builtin."*

**So the tree holds both the verdict and its refutation, and nothing compares them.**

## Why this is the blocker rather than Route B

WI-D9 established that Route B alone clears zero barriers. **WI-D13 changed that** — the barrier
derivation is now per `(extension, slot)` with classifier 3 as a third producer, so a mediating
extension *could* clear. **But it cannot, because classifier 3's unit is the closure and every
extension's closure contains its registration.**

WI-D6 measured this exact confound from the other side: **nine of fifteen `register_with_config`
implementations read `Env` before any hook is dispatched**, and it solved it for the runtime trap with
paired arms — `reg_<ext>` and `budget_<ext>`, read as a differential. **The static closure analysis
never got that treatment.**

**So Route B's cost estimate is wrong in the direction nobody has priced.** D9's condition A-2 said
Route B would need to strip every effect-bearing import from a 17-module closure. **If registration is
out of criterion 2's scope, most of that requirement evaporates** — and if it is in scope, Route B is
larger than anyone has said.

## The reading question, and the two properties pull opposite ways

**Property 1 is call-granular:** *"decide, for each effect a hook can perform, whether **the call**
that performs it is a field call on an `ExtPorts`-typed value."*

**Property 2 is closure-granular:** *"the unit is the extension's transitive module **closure** — not
the module that happens to hold the hook's chain."*

**Classifier 3 implements property 2 and coarsens property 1 away**, deliberately and on the record:
*"An import alone is a rejection; a call site is not required."*

**And D5's own text quantifies over hooks:** *"every hook reachable within that profile is either…"*
**Registration is not a hook.** But property 2 was written to stop a *file*-scoped argument — the
`dst_driver_only.ail:597` defect D9 named — and it may have overshot from "not one file" to "including
registration".

**Decide which, against D5 and the amendment read together.** The answers differ:

- **Hooks only** — `compaction_ai` may be clearable, Route B becomes tractable, and the fourteen
  `register_with_config` rows stop being a conformance question and become a hygiene one.
- **Closure including registration** — classifier 3 is correct as built, no mediating extension can
  ever be cleared without stripping registration imports, and **that should be stated in the ADR**
  because it bounds what the extension model can ever achieve.

## The rule you will break by accident

**Registration effects are real and they happen at install time. Ruling them out of criterion 2 does
not make them harmless.**

If the answer is "hooks only", something must still account for what registration does — a profile
installs an extension and its registration runs. **D5's disclosure obligation is the natural home**,
and the fourteen `register_with_config` rows become the artifact that carries it. **Do not simply
narrow the scope and leave the effects unaccounted**; that is the shape of every vacuity this project
has spent fourteen items marking.

**And per S16 as D12 extended it:** if you sharpen the unit, enumerate the ways an effect can reach a
hook before choosing the new one. D12 found the **builtin door** exactly this way — effects that need
no import at all — and a registration/hook split that forgets builtins reopens it.

## Definition of done

**The reading decided, against D5 and the amendment, with the reasoning recorded.** This is the item's
durable output whether or not any code changes.

**If hooks-only: classifier 3 sharpened**, with registration separated from hook-reachable modules,
the fail-closed discipline preserved, and the yield re-derived. **Report the delta** — if it moves
from 4 of 15, say which extensions and on what evidence.

**If closure-including-registration: the ADR says so**, as a drafted amendment rather than an edit —
D5 is Accepted and this project's mandate routes corrections through a normal round. **And Route B's
cost estimate is revised upward**, with WI-C5's owner told.

**Either way, what accounts for registration effects**, named.

**Per S13/S9/S17** — targets in `make dst`; sweep cache-cold with `AILANG_RELAX_MODULES=1` including
the stdlib-adjacent cache; `make sync_packages` first (twelfth consecutive item); restore mutants by
`cp` or `tar`.

## Out of scope

- **Route B itself**, and WI-C5's compose-bearing profile. This item prices them; it does not build
  them.
- **Installing anything into either profile.** `driver_plus_no_ops` is `driver_plus_no_ops`; if the
  reading clears `compaction_ai`, that is a third profile's question.
- **The full eleven-row table** for `driver_plus_no_ops` — seven rows are unclaimed and running them
  is WI-C4's shape.
- **Repairing classifier 1**, and its zero-check. **The stdlib-adjacent cache's producer, which is
  STILL UNIDENTIFIED** — WI-D14 identified `~/.ailang`'s 4 files, a different directory from
  `~/.local/share/ailang/std/.ailang`'s 52. Corrected at review; the open question is untouched.
- The gate-table State column; the ADR's "1 of 15"; F3; the `extension_effect_fault` wording; the
  `motoko-ext-abi` major at eight rows.

## Stop and report rather than deciding inline

- **If the reading requires amending D5's criterion 2 text**, draft and stop. D5 is Accepted and the
  amendment round is a known process — WI-D9 drafted, a reviewer dispositioned, WI-D10 applied.
- **If sharpening classifier 3 clears an extension that mediates**, stop and report before any profile
  acts. That is the first non-vacuous coverage this project could claim and it deserves its own item.
- **If the registration/hook split cannot be made fail-closed**, say so and keep the coarse rule. A
  coarse rule that refuses honestly beats a sharp one that admits by accident.

## Report back

Thirty-ninth calibration run.

- **The git wall-clock window.**
- **The reading, with its reasoning.** The durable output.
- **The yield delta**, if classifier 3 moved, with the extensions named.
- **What accounts for registration effects** under the reading taken.
- **Route B's revised cost**, up or down, for WI-C5's owner.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **70 across
  thirty-eight runs, and the thirty-eighth was the first LIVE one** — a transcribed constant nothing
  compared. Per S23, look for constants this item states that only one artifact states.
- **Whether the slot-level barrier count is still three.**
