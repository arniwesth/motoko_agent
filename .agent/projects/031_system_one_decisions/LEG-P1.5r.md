# LEG-P1.5r — manifest ABI pins to 8.0, the fixture exemption, and two ABI text probes (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.5r` in `PLAN-001-implement-adr-001-abi-8.md` §3, added by the operator's `Q-SWEEP` ruling and
extended at `P0G`. Tools that read the ABI's **version or text** at a pinned value drifted when P0.4
set 8.0; nothing else on the plan repairs them. Three pieces:

1. **The 31 manifest ABI pins** — `abi_version: "7.4"` / `_manifest(… "7.4")` literals in **25 tracked
   `.ail` files** (re-count at HEAD; it was 31 in 25 at the orchestrator's count) → `8.0`.
2. **The one deliberate exception**: `src/eval/journal/admission.ail:993` builds an entry with
   `abi_version: "7.3"` so `a9b_abi` fires `A9b:AbiVersionDiffers`. Setting it equal to the lock makes
   that fixture assert nothing — a **vacuous test, refused at intake**. It stays a differing literal.
   `tools/profile_definition/check_fixtures.py`'s pin sweep (`:912-943`) gains an **explicit, named
   exemption** for fixture literals built to differ — not a loosening: its `pins == 0` and `< 50 files`
   guards must still fire. Its message (`:936-941`, "the repair is to set each to" the live version) is
   corrected so it stops recommending the vacuous repair.
3. **Two ABI text probes** in `scripts/dst/run_declared_vs_performed.sh` that grep literal 7.4 signatures
   P0.4 correctly changed: `:124` `BudgetShaper((ExtCtx, BudgetPlan)` (8.0: `PureCtx`) and `:707`
   `Compactor((ExtCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace})` (8.0: `AiCtx`). Re-point them at the
   8.0 text **keeping what each asserts** — the effect row, not the context name. Each `bad` branch must
   still fire on a re-widened row.

## Ground truth to read first

1. `PLAN-001-implement-adr-001-abi-8.md` — §3 **P1.5r**; §9's **SWEEP** (the ruling), **P0.2b** (the
   probes' attribution and the lock-trap method note) and **P0G** records.
2. `tools/profile_definition/check_fixtures.py` `:880-943` (the sweep and why it exists);
   `src/eval/journal/admission.ail` around `:515` (`a9b_abi`) and `:993`.
3. `scripts/dst/run_declared_vs_performed.sh` `:110-130` and `:695-712`.
4. `packages/motoko-ext-abi/types.ail` at HEAD for the 8.0 text of both slots.
5. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `b509a191`. ABI 8.0 frozen (ADR accepted at `P0G`).
AILANG `v0.33.0`, the pin. **The tree is red by design** until P1.2 lands the 18 extension packages.

**Your plan exits are not reachable yet — do not chase them.** `make profile_definition` and
`make driver_only` also fail because `tools/ext_call_inventory/derive.py --json` exits 1 on the red tree,
**before** the pin sweep runs (P0.5's evidence); and `make declared_vs_performed` aborts on four
`compose_*` rows (the 7.4 compose package, P1.2d). Both targets are on `R-G`'s list and turn green there.
Your green is **each assertion you own, run on its own**: the pin sweep (invoke `check_fixtures.py`'s
sweep function directly, or add a flag that runs only it — say which), and the two probes (a small
runner that executes those two blocks against the ABI, the way P0.2b's `run_adr001_section.sh` runs
one section). Record why each full target is still red and whose it is.

**`ailang.lock` trap:** path dependencies are pinned to the primary checkout's absolute path; a check
inside a `git clone` resolves the primary's packages. Your assertions are text/Python, so say plainly
whether any of them compiles AILANG — if one does, build a throwaway workspace
(`evidence/P0.4-amendment-1/p04_consumer_check.sh` is the pattern).

**Another delegate works beside you** on P1.2a in `packages/` (six extension packages). Your files do
not overlap. Do not touch `packages/`.

## Exit checks — run them yourself, record the output

1. Pins: every tracked `abi_version`/`_manifest` literal reads `8.0` except the exempted `admission.ail:993`;
   the sweep passes with the exemption named in its output.
2. The two probes: `ok` on the 8.0 ABI; each goes `bad` when its row is re-widened.
3. `src/eval/journal/admission.ail`'s own test still fires `A9b:AbiVersionDiffers` (run it; if it cannot
   run on the red tree, say why and show the fixture's literal differs from the lock).
4. **mutgate** from a fresh clone, spec and helpers **committed** under `evidence/P1.5r/` with
   repo-relative paths. At least: remove the exemption → the `7.3` fixture is swept → red; set
   `admission.ail:993` to the live version → a vacuity guard or the A9b test → red; re-widen each probe's
   row → red; revert one pin to `7.4` → red. Known trap: `cmd | grep -q X` under `set -o pipefail`
   scores baseline red (exit 141) — write a log, then grep the file.

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P1.5r: manifest ABI pins to 8.0, named fixture exemption, two ABI text probes re-pointed
```

```
RESULT P1.5r
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
pins: <n> moved to 8.0 in <m> files; exempted: [admission.ail:993]
probes: :124 <ok|bad>, :707 <ok|bad>
commands:
  - <pin sweep, standalone> -> exit <n>
  - <probe runner> -> exit <n>
  - <A9b test> -> exit <n> | why not
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
full_targets_still_red: [profile_definition: <cause/owner>, driver_only: …, declared_vs_performed: …]
could_not_run: [<what>: <why>, ...]
```

## Rules that bind you

- The 25 pin files, `check_fixtures.py`'s sweep, the two probe blocks in `run_declared_vs_performed.sh`,
  and `evidence/P1.5r/`. Not `packages/`, not other logic in those files.
- One commit, named as above, as your last act. Stage **only your own paths** (`git add <paths>`, never
  `git add -A` or `.`): another delegate is editing `packages/` in this checkout. Leave every unrelated
  path alone, and **never run `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
