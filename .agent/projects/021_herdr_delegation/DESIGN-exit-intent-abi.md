# DESIGN: extension-declared exit intent — removing the herdr hardcoded TUI surface

Date: 2026-09-04, revised 2026-09-05
Status: **Accepted and implemented v3 (2026-09-05)** on branch `arniwesth/exit-intent-abi`, as
`motoko-ext-abi 7.0`. v1 proposed closure-valued `ExitIntent` + `ExtCtx` identity and was blocked on
all three shapes by the NEEDS-FIX review from `mot-dlg-1788529974769` (claude); v2 adopted the
review's fixes (data-not-closure exit actions, positional payload, registration-time identity) and
left §5's four questions open. v3 answers all four, and two of the answers are corrections to v2
rather than choices between the options it listed — see §5. Review:
`.motoko/herdr-delegates/answer-mot-dlg-1788529974769.md`.
Scope: `motoko-ext-herdr` MOT-133/134/136/137 + `src/tui/src/exit-actions.ts` (new) +
`src/core/ext/exit_manifest.ail` (new) + the `herdr-agent-state.ts` exit seam.
Does NOT change what the integration does (token format, opt-in reaping, report-by-default sweep).
Only WHO declares it and WHERE it executes.

## 1. The problem

A pluggable extension required hardcoded TUI changes. Concretely, `motoko-ext-herdr`
needed three host-side pieces that no other extension needs and the ABI could not express:

1. **Session clock minting.** The `mot-owner` ownership token is `<own-pane>:<session-ms>`
   (`types.owner_token_value`). The TUI mints the clock once, forwards it as
   `MOTOKO_SESSION_MS` via `buildChildEnv`, and the exit-time reaper rebuilt the same
   string on the far side of a language boundary. The extension explicitly refuses to
   mint its own (`register.ail`): a local clock would look right and match nothing.
2. **Exit-time reap.** `herdr-reap.ts:reapOwnedPanes`, called from `releaseHerdrReporter`
   inside `process.on('exit')` — synchronously, because an async spawn there never runs,
   1s timeout per call, best-effort, never blocking exit.
3. **Env forwarding.** `buildChildEnv`'s `HERDR_*` prefix rule, so `register_with_config`
   can read `HERDR_ENV/BIN_PATH/PANE_ID` and the operator knobs through `std/env`.
   Already generic, but herdr-shaped load-bearing config the ABI does not model.

Everything else the integration does — tagging at spawn, orphan sweep, dagr producer,
auto view pane, readiness gates, elapsed wording — is pure AILANG + routed `herdr`
calls and needs no host help.

The same missing slot bites one more place: the dagr run file freezes tasks `working`
when the model delegates and moves on (DESIGN-dagr-as-delegation-view.md §6: "there is
no ABI slot for 'session ended'"). Session-end settlement for the run file is the same
seam, a different question — and `ExitAction.PublishFile` now exists to serve it (§3b),
though nothing uses it yet.

## 2. What the ABI had, and why it could not host this

`packages/motoko-ext-abi/types.ail` `Capability` (6.0): `DescribeTools`, `PromptShaper`,
`BudgetShaper`, `Compactor`, `ToolPolicy`, `ToolProvider`, `ResponseInterceptor`,
`SolverJudge`. Registration returns `[Capability]`; the vote kinds reject N>1 (017 ADR-001).

- `SolverJudge((ExtCtx, string) -> FinalizeOutcome ! {Process})` is model-answer
  finalization, not process exit. Wrong trigger, wrong lifetime.
- No capability carried an exit trigger at all. The TUI exit seam is host-side TypeScript
  "where the ABI's missing session-end slot does not matter" — a direct quote of the gap.
- Effect-row reality: an exit intent needs `{Process, FS}` at minimum, executed
  **synchronously inside the exit handler** with a bounded timeout. An async `Process`
  effect dispatched through the runtime would never execute there — the event loop is
  already closed. Any ABI shape that ignores this constraint produces a hook that fires
  everywhere except exit.

## 3. What landed: data-not-closure `ExitIntent` + a published manifest

### 3a. Registration-time session identity — and the duplication is GONE, not narrowed

v2 predicted that the token FORMAT would collapse to one definition while the mint stayed
host-side, and that §6's v1 criterion ("mint logic deleted") was unachievable. Half right.
The mint does stay: `register_with_config(cfg)` receives no ctx (`types.ail:4`), the herdr
config is assembled once at registration and captured, and `ExtCtx` is built inside the
per-task child which has no stable session clock of its own. `sessionStartMs` and the
`MOTOKO_SESSION_MS` forwarding are unchanged, and `herdr-owner-token.ts` survives as
`src/tui/src/session-identity.ts` holding exactly that and nothing else.

What v2 did not foresee is that the FORMAT duplication disappears entirely rather than
collapsing to "one definition plus a twin test". The exit action carries the token KEY and
VALUE as data (§3b), so the host compares two strings it was handed and never builds one.
`owner_token_value` in `packages/motoko-ext-herdr/types.ail` is now the only definition of
the format in either language, and `herdr-owner-token.test.ts`'s twin assertions were
deleted rather than moved — there is nothing left for them to pin.

The cost inversion the review caught (M4) held: adding fields to `ExtCtx` IS the
record-literal totality price, while adding a `Capability` variant is zero-cost for
non-using extensions. No `ExtCtx` field was added.

### 3b. `ExitIntent`, and the manifest that carries it across the process boundary

The intent yields **data computed while the runtime is alive**, not a closure executed
after it dies. What v2 left as "the host collects and caches the latest" is, concretely, a
FILE: at every turn end the AILANG side renders each intent and publishes a session-keyed
manifest (write-tmp + `mv`); at process exit the TUI reads that one file and executes what
it finds, synchronously, bounded, best-effort — no AILANG execution and no IPC in the exit
path. "Computed from already-known data" is a consequence of where the code runs rather
than a rule anyone has to remember.

```ailang
| ExitIntent(string, bool, (ExtCtx) -> ExitIntentOutcome ! {FS})
--            label  enabled?  render, from FS-backed state, returning a successor

export type ExitIntentOutcome = { actions: [ExitAction], next_state: ExtWorld }

export type ExitAction
  = ClosePane(PaneCloseAction)          -- { bin, pane, token_key, token_value }
  | PublishFile(PublishFileAction)      -- { tmp, dest }: the settled write-tmp+rename
  | RunArgv(RunArgvAction)              -- { bin, args }: argv only, no shell
```

Shape notes:

- **Positional payload** (B2), so the render closure sits in the compiler-enforced
  position. A record payload would choose the `smuggle` hole by construction.
- **Captured `bool`, not a thunk** (M8): reading env is `! {Env}`. `HERDR_REAP_ON_EXIT=1`
  is resolved at registration via `getEnvOr` like every other knob and captured.
- **`ClosePane` carries the PROOF, not just the id.** The extension names the token key and
  value that must still be on the pane; the host verifies before closing, without ever
  learning whose panes are whose. A pane id recycled between the render and the exit fails
  the check and is left alone.

  **What that is worth, corrected.** v2 and the first v3 draft both said this "buys back the
  freshness a cache gives up". It does not, and the review was right to call it. What it buys
  is that a STALE action is no more dangerous than a fresh one — the property the cache
  actually needed. It does not make the close atomic: `pane list` and `pane close` are two
  calls, ownership can change between them, and every action is checked against one
  enumeration taken before any of them ran. Re-listing per close would shrink that window,
  not remove it; removing it needs an operation herdr does not offer — close this pane
  incarnation if its token still matches. **The pre-7.0 reaper had the same race.** This is a
  best-effort snapshot check, and anything stronger has to come from the server.

  All three fields are required and non-empty. An earlier draft read a missing `token_key` as
  `""` and treated `""` as "close any pane that exists", so the escape hatch documented as
  deliberate was also what malformed input decayed to — a default failing in the wrong
  direction. There is no unproven-close mode now.
- **The render returns a SUCCESSOR and reads through `ExtPorts.file_read`.** v2 specified
  `! {FS}` and a bare `[ExitAction]`, which is what was first built. It type-checked,
  passed its own tests, and `make driver_plus_no_ops` rejected it: the barrier derivation
  classifies a slot by (rowed, unconditionally dispatched, returns explicit world state),
  and a rowed unconditional slot returning no world state makes EVERY extension in the
  tree non-zero-barrier at a stroke. The gate was right and the draft was wrong — an
  FS-reading hook that cannot hand on its cursor is exactly WI-D1's shape. `! {FS}` stayed;
  the outcome grew `next_state` and the read became routed.
- **No `ExtWorld` threading of extension state** (M7): `token` is host-opaque. Extension-
  owned cross-task state lives where it already lives — the dagr run file.
- **Persistence across tasks** (M10) is solved by the manifest, which subsumes both options
  v2 priced. See §5 Q4.

Host contract, pinned by `src/tui/src/exit-actions.test.ts`: synchronous, bounded
(`EXIT_ACTION_LIMIT = 32`, announced truncation), best-effort (never blocks exit), closes
by explicit id only after the proof holds, one `pane list` per binary however many closes,
an unknown manifest version or action kind executes nothing rather than guessing, empty
list is a silent no-op. **SIGKILL/power loss runs nothing** — the startup sweep stays the
backstop (DESIGN-f5 §2.3).

### 3c. Explicitly NOT changed

- The token format, the opt-in default (D2), the report-by-default sweep (D3), and the
  tag-at-spawn path are untouched. Mechanism moved; policy stayed.
- No `Pending`-at-exit: suspending the run for an operator decision at exit turns a
  runaway into a hung session.
- No generic async-at-exit: the sync constraint is load-bearing, not an optimization.
- TWO behaviours narrowed, both recorded rather than smoothed over. Both follow from the same
  change of denominator: the old reaper enumerated by TOKEN and ignored task state, while the
  intent renders from the run file's in-flight attempts.
  - The MOT-137 dagr VIEW pane is tagged but is not an attempt, so it is no longer closed at
    exit. See the note above `ensure_dagr_pane`.
  - **A delegate whose pane close FAILED is now excluded too**, which the review found and
    which is the worse of the two. `dagr_settle` marks the attempt terminal whether or not the
    close succeeded — a failure adds a note saying the delegate "may still be running"
    (`herdr.ail:376`) and nothing else — so that pane is terminal, excluded by
    `open_delegate_panes`, and absent from every later exit render. The old reaper would have
    retried it. The fix belongs in the run file rather than the query: a cleanup obligation
    should survive a failed cleanup, which means recording "close attempted and failed" as its
    own fact instead of folding it into a note on a settled attempt. Until then the startup
    orphan sweep is the backstop — the same one that catches everything a SIGKILL skipped.

## 4. What it cost (v2's §4 predictions, against what happened)

v2 corrected v1's "~16 packages + ABI major" to "host-side and enumerable". That held: no
extension that does not use the variant was touched. The actual list:

1. `packages/motoko-ext-abi/types.ail`: `PaneCloseAction`/`PublishFileAction`/
   `RunArgvAction`/`ExitAction`/`ExitIntentOutcome` + the positional variant; version 7.0.
   No `ExtCtx` fields.
2. `src/core/ext/registry_normalize.ail`: `ExitIntent` N>1 admitted (a concatenation kind
   like `DescribeTools`), duplicate LABEL within one extension rejected with position —
   `ToolProvider`'s duplicate-name rule, same reasoning. New rejection
   `DuplicateExitLabel`; fixtures in `scripts/dst/registry_multiplicity_dst.ail`.
3. Coverage enumeration: `CapabilityKind` gains `ExitIntentKind`, `all_capability_kinds()`
   is nine, `capability_dispatch` says `Unconditional` (§5 Q1), the eight-distinct test
   became nine, the seven-unconditional sweep became eight, and the fixtures' `eight()`
   helper was renamed `one_per_kind()` — the name the coverage module's own prose already
   used. `make profile_coverage`'s awk producer counts 9 and agrees with the AIL side.
4. Dispatch classification: answered, see §5 Q1.
5. `src/core/ext/runtime.ail`: `dispatch_exit_intents`, an unconditional fold in registry
   then list order, threading the world atom to atom with the holder stamped and cleared
   exactly as `dispatch_response_intercept` does.
6. `src/core/ext/exit_manifest.ail` (new): renders, encodes, publishes write-tmp + `mv`
   (`std/fs` has no rename at v0.33.0 — ailang#897). Called from the two turn-end seams in
   `session.ail`, on both the success and the error arm.
7. `src/tui/src/exit-actions.ts` (new) + `initExitActions()` registered in `index.ts`
   BEFORE the herdr reporter, so lifecycle authority is handed back last.
   `herdr-reap.ts` and `herdr-reap.test.ts` deleted; `herdr-owner-token.{ts,test.ts}`
   became `session-identity.{ts,test.ts}` with the token half removed.
8. `motoko-ext-herdr`: `HerdrConfig.reap_on_exit` read at registration; `exit_actions`
   renders `ClosePane` per in-flight attempt in the session's own run file;
   `dagr.open_delegate_panes` is the pure query, with its own inline tests.
9. `tools/ext_ambient_inventory/hook_scope.py`: `"ExitIntent": (3, (2,))` — and one real
   tool bug found by the first atom in the tree with a string literal in a DATA position.
   `keep_interpolations` blanked a literal's quotes along with its text, which made
   `ExitIntent("label", …)` indistinguishable from `Kind(, f)` and rejected the whole
   registration as wrong-arity. The delimiters are now preserved, which is what the
   function's name and docstring always claimed. herdr's pinned atom count re-pinned 2 → 3.
10. `tools/profile_definition/check_no_op_profile.py`: `EXPECTED_CAPABILITY_KINDS = 9`.
11. New gate `make verify_exit_intent` (9 cases), wired into `check_core`.

Green after the change: `make check_core` (including the new gate), `make verify_core`,
`make profile_coverage`, `make registry_multiplicity`, `make hook_guard`,
`make profile_definition`, `npx tsc --noEmit` and the TUI jest suites.
Still red, unchanged by this branch and pre-existing on its base commit:
`make declared_vs_performed`, `make driver_plus_no_ops`, `make driver_plus_compose` and
`make ext_hook_scope_selftest` all fail on `repetition_guard` being in `ailang.toml`'s
resolved install set while no profile names it, plus a door-3 residue (`f`) in the
selftest. Those belong to whoever added that extension; this branch re-pinned only what it
moved and left that drift reporting itself.

## 5. The four open questions, answered

1. **(M6, dispatch classification.) ANSWERED WRONG FIRST — `Lifecycle`, a third variant.**
   The original answer was `Unconditional`, argued from "the render runs at every turn end
   for every registered atom" and asserted as "the truth, not the convenient answer". The
   premise was false, and the review caught it. The render is gated twice, by code the same
   change introduced: `ext/runtime.ail` skips the call when the atom's captured `enabled` is
   false, and `ext/exit_manifest.ail` returns before the fold runs at all when the host named
   no manifest — which is `ailang run` without the TUI, and every DST profile. So neither
   "every atom" nor "every turn end" held.

   `Gated` would have been wrong differently: it files the kind beside `ToolProvider`, whose
   exclusion is legitimate because a CALL may never name it — a different reason that would
   read as the same one. `DispatchKind` therefore gains `Lifecycle`: dispatched at a
   lifecycle boundary a profile may or may not exercise. Seven unconditional, one gated, one
   lifecycle, and `profile_definition_dst` sweeps all three by consequence rather than label.

   **What is NOT implemented, said plainly:** a `Lifecycle` exclusion is admitted without the
   harness proving the boundary is unreached. The honest rule is "legal only when the profile
   excludes that boundary and non-dispatch is enforced", and enforcement needs profiles to
   declare boundaries, which they cannot yet. Until then the claim is unchecked — weaker than
   an `Unconditional` rejection, stronger than silence, because it is at least named.

   The cascade was smaller than predicted: `dst_profile_coverage.ail`, a three-valued reader
   in `check_fixtures.py`, barrier selection in `check_no_op_profile.py` (only `Gated` is
   barrier-free — a `Lifecycle` row still runs when its boundary IS exercised, so treating it
   as free would invert the conservative answer), and the DST sweep. The three profiles did
   NOT need re-issuing: `table_content_hash` covers the attribution rows, not the dispatch
   table, and the barrier count held at four.
2. **(M9, can the two-step publish complete inside the exit budget?)** Yes, and the answer
   is cheaper than the question assumed: the extension writes the tmp file while it is
   alive, and the host's half of the transaction is `fs.renameSync` — one syscall, no
   subprocess, no timeout to blow. `PublishFile` therefore ships as an action kind, tested,
   with no consumer yet; dagr's settle-on-exit can take it whenever that item lands.
3. **(M7, the render's row and what enforces it.)** `! {FS}` — stated in the ABI, and the
   row IS the mechanism: a render that wanted to spawn a subprocess would not compile.
   Corrected in one respect the question did not anticipate: `{FS}` alone was not enough,
   because a rowed unconditional slot must also return explicit world state or it breaks
   the barrier derivation. The read goes through `ExtPorts.file_read` and the outcome
   carries `next_state`. See §3b.
4. **(M10, build vs read.)** Neither, and both. The manifest generalises them: the
   extension renders from the session-keyed dagr run file it already writes (option b's
   "no new persistence"), and the persistence that crosses tasks is the manifest itself
   (option a's "file-backed, session-keyed") — but it is generic host machinery rather than
   herdr's own, so the TUI keeps zero herdr knowledge. `.dagr/run-<pane>-<session>.json` is
   read by the extension in-process, never by the host. Neither option was priced further
   because the third one satisfies §6 outright.
5. **(Kept, still out of scope.)** `HERDR_*` env forwarding as-is
   (`herdr-child-env.test.ts`) vs per-extension config files
   (`MOTOKO_PROFILE_DIR/<ext>.json`). The next hardcoded-knob complaint will be one of
   those. Note that `HERDR_REAP_ON_EXIT` moved from "read by the TUI" to "read by the
   extension through the existing prefix forward", so this branch made the forwarding
   MORE load-bearing rather than less.

## 6. Acceptance — met, with one criterion superseded

- ✅ `src/tui/src/herdr-reap.ts` deleted; a generic exit dispatcher in its place. No
  `mot-owner` string remains in `src/tui/` outside `exit-actions.test.ts`, which uses it
  as a fixture token exactly as an extension would supply one.
- ⚠️ "Mechanism moves; policy stays" is TRUE OF THE RUNGS AND NOT OF THE COVERAGE. The opt-in
  default, the token gate and the report-by-default sweep are unchanged, but the set of panes
  reaped at exit is narrower than the pre-7.0 reaper's in the two ways §3c records. This
  branch should not claim cleanup behaviour is unchanged, and no longer does.
- ✅ / superseded. v2 predicted "the format has one definition; the host twin-test stays as
  the pin". The format has one definition and the twin test is GONE, because the host no
  longer builds the token at all — a stronger outcome than the criterion asked for. The
  mint (`sessionStartMs`) and `MOTOKO_SESSION_MS` forwarding stay, as v2 said they must.
- ✅ `make check_core`, `make verify_core`, `make profile_coverage` green; new
  `make verify_exit_intent` gate asserting: the intent is registered whether or not the
  knob is on; with it off nothing renders and the manifest still discloses the intent;
  with it on an in-flight pane becomes exactly one `close_pane` carrying this session's
  token key and value; a settled task and the producer's own pane are never named; an
  absent, unreadable or session-less run file produces nothing; and the published manifest
  is the shape `exit-actions.ts` parses; and (case 8) that a render handed ports which
  cannot read the filesystem yields nothing while the reading-ports case yields one — the
  regression §7 describes. `make declared_vs_performed` is red for a pre-existing reason
  (§4).
- ✅ Live check RUN, 2026-09-05, in herdr workspace `w2` against a real server, and it
  earned its place — see §7. All three legs pass:
  - reap on: a real `claude` delegate on `w2:pD`, tagged `mot-owner=w2:p1:1788596332118`,
    in flight in the run file; Motoko exits; the pane is gone and every other pane in both
    workspaces survives.
  - reap off: a real delegate on `w2:pE`, same tag, same in-flight record; the manifest
    discloses `enabled: false` with an empty action list and the pane SURVIVES the exit.
  - P2-6: a manifest naming four panes with this session's token was executed against real
    panes carrying, respectively, that token, a FOREIGN token (`w9:p9:…`), no token at all,
    and — deliberately — the other operator Motoko's live pane `w1:p1`. Exactly one closed;
    the report said `unproven: 3`. `publish_file` renamed its tmp and `run_argv` ran.

## 7. What the live check found, and why the unit gates could not

The end-to-end run failed on its first attempt, and the way it failed is the point.

Both halves were green. `make verify_exit_intent` passed because it injects a scripted
`file_read` into the ctx it builds. `exit-actions.test.ts` passed because it is handed
manifests written by hand. Neither could see the seam between them, and the seam was dead:
`session.publish_turn_exit_manifest` built its exit ctx with `noop_ext_ports()`.

The reasoning that put it there is in the commit that removed it, and it was not lazy —
it was a defensible-sounding inference from the row. `ExitIntent` carries `! {FS}`, the
render "cannot reach a port it should not need", so handing it live ports looked like
advertising a reach the row denies. Then §5 Q3's correction landed: the render moved from
ambient `std/fs` to routed `ExtPorts.file_read`, and nothing went back to revisit the ctx.
The no-op port answers `present: false` to every path, so every render read an absent run
file and published `"actions": []` — from a run file that was on disk, correct, and
naming an in-flight delegate on `w2:pB`.

Silent in the worst direction: an empty action list is exactly what a clean session with
no delegates looks like. Nothing in either test suite, and nothing in `check_core`, could
tell those apart.

`verify_exit_intent` case 8 now pins what CAN be pinned from inside the extension gate,
and it needed a decoy to be a test at all. Every other case supplies the run file through a
scripted `file_read`, so with nothing at the real path none of them can tell a render that
goes through the port from one that reads `std/fs` behind its back. Case 8 writes a real
run file at the configured path holding a DIFFERENT pane (`w1:pDECOY`) from the scripted
content's (`w1:pA`), and asserts three things at once: the routed render names `w1:pA` (the
bytes came from the port), the no-op render names nothing (the shipped regression), and the
two DISAGREE (without which a fixture that renders nothing twice reads as green).
Verified by reintroducing the ambient read: two cases go red and the argv-level diagnostic
names `w1:pDECOY` explicitly.

What case 8 still cannot see is the wiring — `session.publish_turn_exit_manifest` handing
over no-op ports is a host-side construction the extension gate has no reach into. What
catches that is running it. Recorded here so the next person to build an ABI seam prices
the live check in rather than treating it as confirmation.
