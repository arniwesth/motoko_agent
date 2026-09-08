# Handoff: WI-D26 — route compose's `exec` sites

Audience: a fresh session grounded against HEAD (`600f0f2` — the D25 implementation is committed;
start from a clean tree). **Item 1 of the goal line's remaining critical path, and the change every
item since D16 has been preparing:** compose's last hook-reachable ambient effects go through the
world. After this item, compose's ambient remainder is entirely disclosed classes — four `println`,
registration's three, one AI — and the demonstration (item 2, C5's profile) has a fully mediated
subject.

**Read first:** the goal-line section; D23 §12.1 and D25 §9 (what routing inherits); S14 (two
subjects), S25 (state conditions), S33 (the operating question).

## The four sites, each measured with its scope

| # | Site | Enclosing scope | What is already in scope |
|---|---|---|---|
| 1 | `compose.ail:277` — `check_snippet`: `exec("ailang", ["check", path])` | helper `(snippet_path) -> {ok, errors, exit_code} ! {Process}` | callers at `:562` and `:984` both sit in functions already using `p.dir_make`/`p.file_write`/`p.clock_now` with a live `ExtWorld` |
| 2 | `compose.ail:292` — `run_snippet`: `exec("ailang", ["run", "--caps", caps, …])` | helper `(snippet_path, caps)` | same two callers |
| 3 | `author_tools.ail:430` — `grep_impl`: `exec("rg", …)` | **already `(p: ExtPorts, w: ExtWorld, …)`** | routing is in-place |
| 4 | `authoring/dispatcher.ail:244` — `check_snippet`: `exec("ailang", ["check", path])` | **already `(p: ExtPorts, w: ExtWorld, snippet)`** — D19/D20 routed its `dir_make`/`file_write`/`clock_now`; only the `exec` line is ambient | routing is in-place |

**The shape:** each `exec(cmd, argv)` becomes
`p.proc_exec(w, "BashExec", encode(jo([kv("cmd", js(<shell string>))])))`, branch on the typed
`outcome.exit_code` (D23), decode `outcome.output` as the `BashExecResult` JSON
(`{tool, cmd, exit_code, stdout, stderr, truncated}` — `tool_dispatch_adapter.ail:107-115`) for the
streams, and **thread `outcome.next_state`**. Sites 1–2's helpers widen to take `(p, w, …)` and
return `next_state`; their callers already thread worlds through every adjacent line, so the
threading is local. Remove the three `import std/process` lines when the last call in each module
routes; `ProcessError` and its `show` helper go with them.

## The five traps, each measured

1. **`rg` exit 1 means NO MATCHES, not failure.** `grep_impl` today branches on `text == ""` and
   never reads the exit code (`author_tools.ail:432-438`). The routed form must keep exactly that
   branch structure — a routed `grep_impl` that adopts `exit_code == 0` gating breaks the
   fallback-scan path on every quiet search, and every fixture with matches stays green (S33's
   divergent input is a search with no hits). The typed code is *available* there, not *load-bearing*.
2. **The argv → shell-string conversion is a quoting boundary, and it is safe here BY MEASUREMENT
   OF THE GENERATORS, not in general.** The seam's only subprocess door is `BashExec` → `bash -lc`
   (`run_process_result` wraps; D21 §8). The paths are machine-generated —
   `tmp/snippet_${step}_${now_ms}_${attempt}.ail` (`compose.ail:556`) and
   `.motoko-store/tmp/compose_structured_${sha256Hex(…)}.ail` (`dispatcher.ail:241`) — digits, hex
   and underscores only; `caps` comes from config as a comma-joined capability list. **State at
   each converted site that the safety is conditional on the generated charset** (S25), and if any
   argument can ever carry user text, stop and report rather than hand-rolling shell quoting.
3. **`exit_code == -1` lands in the failure branch, and that is correct but must be said.** `-1` is
   "no subprocess, or a seam that cannot say" — for `check_snippet`'s `ok: exit_code == 0` that is
   a failure, which is the fail-closed direction. One comment at the helper, not per site.
4. **Double truncation.** `run_snippet` caps stdout/stderr at 8000/2000 itself; the seam's
   `BashExecResult` carries its own `meta.truncated`. Keep compose's caps, OR the two flags, and
   say so — a dropped seam-truncation flag is a silent lie in `truncated: false`.
5. **The spawn-failure arm changes shape.** `exec`'s `Err(ProcessError)` disappears; a routed spawn
   failure arrives as the error-JSON content with `exit_code` 1 (`ToolErrorResult` /
   `dispatch_one_typed`'s defensive arm). `errors: stderr-else-stdout-else-message` preserves the
   current semantics; verify against a real spawn failure (a command that does not exist), not only
   a nonzero exit.

## Recording and replay come for free, and the witness proves it

A routed call in a recorded run now records
`ExtensionEffectIdentity(<holder ext id>, extension_effect_fault, "")` via D24's adapter — the
holder is stamped by the audited folds (D25), and both hooks compose binds at these sites
(`on_tool_handle`, `on_response_intercept`) are confirmed landing sites by compiler verdict
(D25 §9). In a scripted world the call is served from `WorldState.ext_effects`.

**The witness, per S14's two subjects:** extend the discovery scenarios (D24's `effect_scenario`
has the `ext_effects`-seeding pattern; D19/D20's `routing`/`handle` scenarios drive compose's real
hooks) so that **compose's own `check_snippet` path runs deterministically** — a scripted
`ext_effects` entry carrying an `ailang check` failure (nonzero exit, distinct value per S7, with
stderr text) served to the real `handle_compose_tool` chain, asserting compose takes its retry
branch on the typed code and the recorded program validates and replays. **This is the first
deterministic compose authoring loop in the project's history**, and it is the row that makes the
routing real rather than compiling. The live half: one real `bash -lc "ailang check <path>"`
through the routed site (the existing smoke targets exercise this — cite which).

**Mutants:** the routed site reverted to reading `output` text for success (ignoring the typed
code) must redden the scenario's retry-branch row; `grep_impl` switched to exit-code gating must
redden a no-matches row (build it — quiet search, exit 1, fallback scan must still run).

## What moves and what must not

- **`ext_ambient_inventory`: compose 11 → 8 ambient sources** (the three `std/process` import
  sites go), **field calls 32 → 36+** (derive, do not predict). The first yield-adjacent movement
  since D15 — re-derive every consumer of the old numbers (S22): the inventory selftest's
  expectations if pinned, and note the reviewer-side docs carry 11/32 (corrected at apply).
- **Verdicts that must NOT move:** `ext_hook_scope` 5/15 and 4/15 (door 3's `show` still holds
  compose HOOK-UNRESOLVED — this item does not touch classification), PORT-MEDIATED 4/15
  (compose's `println`/registration/AI remain), `declared_vs_performed` (46/0 — the declared rows
  do not change; the same effects are performed through the port).
- **No anchors move** unless a core file is edited — this item's edits are package-side. If
  `session.ail`, `ext/runtime.ail` or `tool_phase.ail` end up touched, the D25-corrected width law
  applies (the files that PIN the moved anchors).
- **No `types.ail` edit, no `sync_packages`-sensitive type change is expected** — but compose's
  `ailang.lock` refresh after signature changes in its own modules follows D22's rule anyway.

## Definition of done

1. Zero `std/process` imports in the compose package; `ext_ambient_inventory` shows compose with
   **no `{Process}` ambient source** and the new numbers recorded.
2. The deterministic compose scenario green (record → validate → replay, retry branch on typed
   code), the live smoke green, both mutants red against their named rows (S17 restore).
3. Gates: `discovery`, `world_state`, `execution_program`, `program_persistence`,
   `declared_vs_performed`, `conformance`, `ext_ambient_inventory` + selftest,
   `ext_call_inventory` + selftest, `ext_hook_scope_selftest`, `anchors`, `predicate_anchors`.
   Full sweep with the three standing reds unchanged (`test_coverage` pair,
   `effect_inventory_selftest`) and nothing new.
4. Re-tense at the sites: compose's D19/D21-era notes about the seam ("the two remaining
   obstacles…") — the typing and identity obstacles are gone; what remains at each site is only
   what that site still owes (S15 two-part).
5. Counters: routing replaces ambient calls with mediated ones — expect no counter movement unless
   an undisclosed defect surfaces; do not count defects authored-and-closed here.

## Out of scope, per the goal-line rule

- **C5's compose-bearing profile** (item 2 — the scenario above is a scenario, not a profile).
- The solver-slot row widening (barrier question), door 3, the `proc_exec` rename.
- The bridge's `workdir: "."`/`timeout_ms: 0` — routed calls run where the process started,
  exactly as ambient `exec` did; the behavior is unchanged and stays on the register.
- The four `println`, registration's three, the ambient AI — disclosed classes, untouched.

## Stop and report rather than deciding inline

- If any routed argument's charset cannot be established from its generator (trap 2).
- If preserving `rg`'s no-match semantics requires reading the exit code at all (trap 1 — it must
  not).
- If the scenario cannot serve compose's routed call from `ext_effects` without touching core
  reconstitution — D24 finished that surface; needing to reopen it is a finding.
- If removing `std/process` from any module changes a classifier or hook-scope verdict anywhere
  but compose — the instruments' units are import-granular and a cross-extension effect would mean
  a shared-closure edge nobody has mapped.

## Report back

`NOTE-d26-…` in the established form: per-site table (what the call became, what threads where);
the inventory's new numbers with their derivation; the scenario's quantities and both mutants; what
the live smoke exercised; anything the first deterministic compose loop revealed that four items of
preparation did not predict — that sentence is the item's headline; and what item 2 (the C5
profile) inherits.
