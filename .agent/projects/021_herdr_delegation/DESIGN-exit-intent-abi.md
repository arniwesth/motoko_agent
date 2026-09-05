# DESIGN: extension-declared exit intent — removing the herdr hardcoded TUI surface

Date: 2026-09-04
Status: Proposed v2 (2026-09-04) — revised after NEEDS-FIX review by `mot-dlg-1788529974769` (claude). v1 proposed closure-valued `ExitIntent` + `ExtCtx` identity; the review blocked all three shapes (B1–B3) with fresh v0.33.0 measurements. This revision adopts the review's fixes: data-not-closure exit actions, positional payload, registration-time identity. Review: `.motoko/herdr-delegates/answer-mot-dlg-1788529974769.md`.
Scope: `motoko-ext-herdr` MOT-133/134/136/137 + `src/tui/src/herdr-{owner-token,reap}.ts` + `herdr-agent-state.ts` exit seam.
Does NOT propose: changing what the integration does (token format, opt-in reaping, report-by-default sweep). Only WHO declares it and WHERE it executes.

## 1. The problem

A pluggable extension requires hardcoded TUI changes. Concretely, `motoko-ext-herdr`
needs three host-side pieces that no other extension needs and the ABI cannot express:

1. **Session clock minting.** The `mot-owner` ownership token is `<own-pane>:<session-ms>`
   (`types.owner_token_value`). The TUI mints the clock once (`herdr-owner-token.ts:
   sessionStartMs`), forwards it as `MOTOKO_SESSION_MS` via `buildChildEnv`
   (`runtime-process.ts`), and the exit-time reaper rebuilds the same string on the
   far side of a language boundary. The extension explicitly refuses to mint its own
   (`register.ail`): a local clock would look right and match nothing.
2. **Exit-time reap.** `herdr-reap.ts:reapOwnedPanes`, called from `releaseHerdrReporter`
   (`herdr-agent-state.ts`) inside `process.on('exit')` — synchronously, because an async
   spawn there never runs, 1s timeout per call, best-effort, never blocking exit.
3. **Env forwarding.** `buildChildEnv`'s `HERDR_*` prefix rule exists so the extension's
   `register_with_config` can read `HERDR_ENV/BIN_PATH/PANE_ID` (+ the operator knobs
   `HERDR_ALLOWED_KINDS`, `HERDR_DELEGATE_KIND`, …) through `std/env`. Already generic,
   but it is herdr-shaped load-bearing config the ABI does not model.

Everything else the integration does — tagging at spawn, orphan sweep, dagr producer,
auto view pane, readiness gates, elapsed wording — is pure AILANG + routed `herdr`
calls and needs no host help.

The same missing slot bites one more place: the dagr run file freezes tasks `working`
when the model delegates and moves on (DESIGN-dagr-as-delegation-view.md §6: "there is
no ABI slot for 'session ended'"). Session-end settlement for the run file (dagr §8
item 4, via F-5 §7 "Explicitly out of scope") is the same seam, a different question.

## 2. What the ABI has today, and why it cannot host this

`packages/motoko-ext-abi/types.ail` `Capability` (post-6.0): `DescribeTools`,
`PromptShaper`, `BudgetShaper`, `Compactor`, `ToolPolicy`, `ToolProvider`,
`ResponseInterceptor`, `SolverJudge`. Registration returns `[Capability]`; the vote
kinds reject N>1 (017 ADR-001).

- `SolverJudge((ExtCtx, string) -> FinalizeOutcome ! {Process})` is model-answer
  finalization, not process exit. Wrong trigger, wrong lifetime.
- No capability carries an exit trigger at all. The TUI exit seam (`initHerdrReporter`
  registers `exit`/`SIGINT`/`SIGTERM`; DESIGN-f5 §2.3) is host-side TypeScript "where
  the ABI's missing session-end slot does not matter" — a direct quote of the gap.
- Effect-row reality: an exit intent needs `{Process, FS}` at minimum (enumerate panes,
  close by id) plus `Clock` for timestamps, executed **synchronously inside the exit
  handler** with a bounded timeout. An async `Process` effect dispatched through the
  runtime would never execute there — the event loop is already closed. Any ABI shape
  that ignores this constraint produces a hook that fires everywhere except exit.

## 3. Proposal (v2): data-not-closure `ExitIntent` + registration-time identity

v1 proposed a closure-valued `ExitIntent` (`plan: (ExtWorld) -> [ExitAction]`) with
session identity on `ExtCtx`. The review blocked all three shapes — B1 (the exit
dispatcher runs in the TUI process where no extension code exists; the per-task AILANG
runtime is normally already gone, and reaching it needs the async IPC an `exit` handler
cannot do), B2 (record payload puts both closures in the `smuggle` position B8 measured
as unchecked — re-measured in-review on v0.33.0), B3 (`register_with_config` takes no
`ExtCtx`; `ExtCtx` is built inside the per-task runtime, so it cannot carry a stable
session clock anyway). This revision adopts the review's fixes throughout.

Two additions, sized to the stabilisation pass:

### 3a. Registration-time session identity (narrows hardcoded piece 1, does not kill it)

B3 correction: `register_with_config(cfg: RuntimeConfig) -> [Capability]`
(`packages/motoko-ext-abi/types.ail:4`) receives no ctx, and the herdr config is
assembled once at registration and captured (`register.ail` → `make_hooks`). So
identity cannot arrive per-hook via `ExtCtx` without restructuring the package — and
`ExtCtx` is built inside the per-task child (`mk_v2_ext_ctx`, `src/core/session.ail`),
which has no stable session clock of its own. The host must still mint the clock
(`sessionStartMs`) and forward `MOTOKO_SESSION_MS` via `buildChildEnv`.

What moves: the *format* collapses to one definition (`types.owner_token_value`; the
review's restatement), while mint + forwarding stay host-side. honest acceptance: "the
format has one definition; the mint stays and is the only host-side piece" — NOT
"`herdr-owner-token.ts` mint logic deleted".

Note the cost inversion the review caught (M4): adding fields to `ExtCtx` IS the
record-literal totality price (every `ExtCtx` literal site — six extension packages'
tests plus `session.ail`, `rpc.ail` ×2, `ext/runtime.ail` — must gain the fields),
while adding a `Capability` variant is zero-cost for non-using extensions (the reason
6.0 bought capability registration). So §3a as v1 wrote it was the expensive half
priced as cheap.

### 3b. Data-not-closure `ExitIntent` (kills hardcoded piece 2)

B1 fix: the intent yields **data computed while the runtime is alive**, not a closure
executed after it dies. Per turn/task end the host collects each extension's
`[ExitAction]` and caches the latest; at process exit it executes the cached lists in
registry order — synchronously, bounded, best-effort — with no AILANG execution and no
IPC in the exit path. "Computed from already-known data" becomes an architectural
consequence instead of an asserted constraint.

```ailang
| ExitIntent(string, bool, (ExtCtx) -> [ExitAction] ! {FS})
--              label  reap?  render cached actions from live state (positional
--                           payload: ctor-arg lambdas ARE row-checked, B2/B8)

type ExitAction
  = ClosePane(string)                    -- explicit pane id; never name/kind/argv (P2-6)
  | PublishFile({ tmp: string, dest: string })  -- the settled write-tmp+mv transaction (M9),
                                         -- never a raw WriteFile (torn-read risk, dagr §8.1)
  | RunArgv({ bin: string, args: [string] })    -- herdr-shaped escape hatch, token-free argv only
```

Shape notes (all review-driven):

- **Positional payload** (B2): multi-arg ctor like `ToolProvider`, so the render
  closure sits in the compiler-enforced position. The ABI header claim for the other
  eight kinds then holds for the ninth. Record payload is rejected — it chooses the
  `smuggle` hole by construction.
- **Captured `bool`, not `() -> bool` thunk** (M8): reading env is `! {Env}`; a pure
  thunk with an env job is a compile error positionally or a silent smuggle in a
  record. Resolve `HERDR_REAP_ON_EXIT=1` at registration via `getEnvOr` like every
other knob (`register.ail` already reads all of them) and capture the bool.
- **Effect row `! {FS}` provisional** (review §3 nits): the row is the enforcement
  mechanism, so it is stated, not left implicit. `plan` renders from live FS-backed
  state (dagr run file + markers); the `std/process` risk is a row question, answered
  by the row.
- **No `ExtWorld` threading** (M7): `token` is host-opaque (`types.ail`) — extension
  code must not read it. Extension-owned cross-task state lives where it already
  lives: the filesystem (dagr run file + `.pane-*` markers). The render closure reads
  files, not the token.
- **Persistence across tasks is required** (M10): the rendering runtime dies per task,
  so an in-memory owned-pane set loses panes spawned in earlier tasks. Options: (a)
  file-backed session-keyed set (same keying as the run file), or (b) the review's
  constructive alternative — the host exit dispatcher reads the session-keyed dagr run
  file's per-attempt `locator { pane }` rows directly, no AILANG at exit, no ABI major
  for this half at all. Price (b) before building (a).

Host contract (unchanged from v1, pinned the way `herdr-reap.test.ts` pins it now):
synchronous, bounded (`REAP_LIMIT`, announced truncation), best-effort (never blocks
exit), closes by explicit id, skips another session's / untagged / own pane, empty list
is a silent no-op. **SIGKILL/power loss runs nothing** — startup sweep stays the backstop
(DESIGN-f5 §2.3).

### 3c. Explicitly NOT proposed

- No change to the token format, the opt-in default (D2), the report-by-default sweep
  (D3), or the tag-at-spawn path. Mechanism moves; policy stays.
- No `Pending`-at-exit: suspending the run for an operator decision at exit turns a
  runaway into a hung session (the guard's own measured reasoning).
- No generic async-at-exit: the sync constraint is load-bearing, not an optimization.

## 4. Migration (corrected pricing — review M4/M5)

v1 priced this as "~16 packages + ABI major" for the variant. The review corrects
both halves (M4): the 16-package price was the pre-6.0 *record-slot* price
(RESEARCH-extension-abi-evolution.md: adding a hook slot forced every extension's
record literal to change); capability registration (6.0) was bought precisely to make
slot additions zero-cost. A new `Capability` variant touches no extension that does
not use it. The real cost is host-side and enumerable:

1. `packages/motoko-ext-abi/types.ail`: `ExitIntent` positional variant + `ExitAction`
   type. No `ExtCtx` fields (v1's record extension is dropped — that WAS the 16-package
   shape, and it served nothing after B3).
2. Registration/normalization (`registry_normalize.ail`): admit N>1 `ExitIntent`
   (composable, ordered concatenation; decide duplicate-`label` handling —
   `ToolProvider` rejects duplicate advertised names with position, review §3 nits).
3. Coverage enumeration (M4/M5 — v1's §4.5 was backwards): the denominator is ALREADY
   per-extension registered atoms (B8 deleted the slot half; `dst_profile_coverage.ail`
   rule `atom-not-registered`; 017 ADR-001 Q1: no atom of a kind = zero barriers on
   that kind by construction). What needs doing is the pin list, not a denominator
   redesign: `CapabilityKind`, `all_capability_kinds()`, `capability_dispatch`,
   `test_all_capability_kinds_is_eight_distinct` (becomes nine), `dst_profile.ail`
   `eight()`, `registry_normalize.ail`, `ext/runtime.ail`, `tool_catalog.ail`,
   `test/ext_fixture.ail`, `motoko_ext_conformance/`. `make profile_coverage`
   (`Makefile`) diffs the ABI variant count and fails the moment the variant lands —
   and its `awk '/^export type Capability/,/^[[:space:]]*$/'` producer is line-fragile
   (a blank line inside the variant list truncates the count): keep the payload dense
   or fix the producer first.
4. Dispatch classification (M6 — new §5 question, see below): `capability_dispatch` is
   `Unconditional | Gated`; an exit-only atom fits neither precedent (never under
   SIGKILL, at most once, only on clean exit). Decide before the variant lands.
5. Exit dispatcher in the TUI: per turn/task-end collect + cache each intent's
   `[ExitAction]`; at exit execute cached lists in registry order, synchronously,
   bounded, best-effort. `releaseHerdrReporter` becomes the first caller of generic
   machinery, not herdr-specific logic.
6. `motoko-ext-herdr`: declare the intent with captured bool; render from the
   session-keyed file-backed set (or take review-M10 option (b): host reads the dagr
   run file's `locator.pane` rows directly — no AILANG at exit, no ABI major for this
   half). Collapse the token *format* to `owner_token_value`; mint + forwarding stay.
7. Gates: `verify_herdr_*` + `herdr-reap.test.ts` semantics move to intent tests;
   `check_core` + `verify_core` + `declared_vs_performed` green (positional payload is
   row-checked, so no new `smuggle`-row exposure — the opposite of v1).

## 5. Open questions for the ABI pass (revised — review M6/M7/M9/M10 + §3 corrections)

1. (M6, new — the best question the review produced.) `capability_dispatch` admits
   `Unconditional | Gated`; excluding `Unconditional` rejects ("the run cannot
   complete"). An exit-only atom dispatches at most once, only on clean exit, never
   under SIGKILL. `Unconditional` makes a coverage lie; `Gated` legitimises exclusion
   — which is probably right but undecided. Decide before the variant lands.
2. (M9, narrowed.) The atomicity question is SETTLED (dagr §8.1: write-tmp+`mv` via
   `Process`, `std/fs` cannot rename) — so `ExitAction` carries `PublishFile { tmp,
   dest }`, never raw `WriteFile`. Only open question: can the two-step transaction
   complete inside the exit budget? Settle-on-exit needs this answer first.
3. (M7, re-asked.) Dropped the world-shape question — `ExtWorld` has no ports
   (`ports` lives on `ExtCtx`), so "full world risks a fresh subprocess call" was
   wrong. Real question: what effect row does the render closure carry, and what
   makes it enforceable? Stated provisionally as `! {FS}`; `std/process` use in the
   body is the risk, and the row is the mechanism.
4. (M10, the build-vs-read decision.) File-backed session-keyed owned-pane set (new
   persistence, same keying as the run file) vs host reads the dagr run file's
   `locator.pane` rows directly (no AILANG at exit, no ABI major for this half,
   satisfies every §6 criterion). Price (b) first.
5. (Kept.) `HERDR_*` env forwarding as-is (`herdr-child-env.test.ts`) vs per-extension
   config files (`MOTOKO_PROFILE_DIR/<ext>.json`, already the documented path)?
   Out of scope, but the next hardcoded-knob complaint will be one of those.
   Dropped v1 Q3 (`session_ms` placement): B3 killed the `ExtCtx` move, so there is
   nothing to place.

## 6. Acceptance (corrected — B3)

- `src/tui/src/herdr-reap.ts` herdr-specific logic deleted; generic exit dispatcher
  in its place; no `mot-owner` string remains in `src/tui/` outside dispatcher tests.
- Token *format* has one definition (AILANG `owner_token_value`; host twin-test stays
  as the pin). Mint (`sessionStartMs`) + `MOTOKO_SESSION_MS` forwarding STAY — v1's
  "mint logic deleted" criterion was unachievable (B3) and is withdrawn.
- `make check_core`, `make verify_core`, `make declared_vs_performed`,
  `make profile_coverage` green; new `verify_exit_intent` gate asserting: intent
  fires on clean exit, closes only own tokened panes by id, announces the cap,
  never blocks exit, SIGKILL case stays with the startup sweep.
- Live check: delegate in flight + `HERDR_REAP_ON_EXIT=1` + quit → pane gone;
  without the flag → pane survives; another session's panes never touched (P2-6).
