# Mocked seams and overclaiming prose (2026-09-05)

From building ABI 7.0 (`ExitIntent`) on `arniwesth/exit-intent-abi` and having it reviewed.
Ten findings came back; four were defects in code, four were claims the PROSE made that the
code did not earn, and two were both. The code lessons are cheap to state. The prose one is
the expensive one.

## 1. A seam mocked from both sides is invisible to both suites

THE BUG. `session.publish_turn_exit_manifest` built its `ExtCtx` with `noop_ext_ports()`.
That port's `file_read` answers `present: false` to every path, so every render read an
absent run file and published `"actions": []`. Both suites stayed green:
`verify_exit_intent` injects a scripted `file_read`, and `exit-actions.test.ts` is handed
manifests written by hand. Neither could see the wire between them, and the wire was cut.

WHY IT SURVIVED REVIEW-BY-READING. The failure output is indistinguishable from success:
an empty action list is exactly what a clean session with no delegates produces.

HOW IT WAS FOUND. Running it. A real delegate on a real pane, a correct run file on disk,
`"actions": []` in the manifest, and the pane still alive with `HERDR_REAP_ON_EXIT=1`.

THE SAME SHAPE, TWICE MORE, IN ONE BRANCH:

- Reported "P0, Ctrl+C is broken for every user" from a repro that armed `initExitActions()`
  in isolation. In the real TUI `env-server.ts` registers its handlers first
  (`index.ts:779`) and calls `process.exit(0)`, which fires exit listeners anyway. The hang
  was latent, not live. Testing the fragment, reporting on the composition.
- Argued two successful live headless runs were evidence against a publication/exit race.
  They were a race won, not a race avoided — see §2.

THE CHECK THAT WOULD HAVE CAUGHT IT. For any cross-process or cross-language seam, one test
where BOTH sides are real. If that is impossible, one test where the mock is *distinguishable*
from the real thing — see the decoy in §5.

## 2. A test that passes twice is not an ordering guarantee

`strace` was unavailable, so the latency went where its injection would have: a 2s delay
inside `publish_exit_manifest`, then the same headless delegation that had passed twice.

```
TUI exited                  .motoko/exit/ EMPTY
(one second later)          manifest appears, actions=1, correct pane, correct proof
herdr pane list             the delegate pane SURVIVING
```

The TUI treats `done` as "turn over", drains its logger and exits without waiting for the
runtime, which published only after the traced run returned. Two few-millisecond paths, no
ordering. Fix: publish before `ledger_emit(session_id, done_event)`, so the consumer cannot
observe the trigger before the artifact exists.

GENERAL FORM: when two processes race and you cannot remove the race, **inject latency on
the side you control and re-run the passing test.** A test that only passes when it wins is
worth knowing about before production finds out.

## 3. Two Node facts worth not rediscovering

- `spawnSync`'s `timeout` sends its kill signal and then WAITS. The default `SIGTERM` is
  catchable, so a child that handles it without exiting blocks past the nominal bound —
  measured **2200ms against a nominal 1000ms**. `killSignal: "SIGKILL"` makes it real: 1007ms.
- Installing a `SIGINT`/`SIGTERM` listener REMOVES Node's default termination. A handler that
  does cleanup and returns makes the process unkillable by that signal. Signal termination
  needs ONE owner per process; everything else should use an `'exit'` listener, which
  `process.exit()` fires anyway.

Also: a per-call timeout is not a deadline. 32 actions x 1s was described in the prose as
"bounded" and permitted a 64-second exit. Aggregate budgets need to exist separately.

## 4. Pins: an anchor that still matches can still be wrong

`tools/predicate-anchors/anchors.sh` pins five `session.ail` clock sites by line number.
Two import lines shifted all five by +2. FOUR failed the check. The fifth PASSED and was
wrong: at +2 it landed on `let clock_now = func(...)` instead of `let reading =
p.clock_now(w0)` — a different expression containing the same substring, so the grep matched
and the anchor silently re-pointed.

**Re-baseline every anchor in a file that moved, not only the ones that shouted.** A partial
re-baseline freezes a green anchor onto the wrong line, which is worse than the red one.

I also mis-priced that cascade in both directions in one session: first claiming three files
because no fixture-carried anchor moved (the three profiles pin the TABLE, not the anchors —
`make driver_only` said so), then expecting a profile re-issue for the dispatch-kind change
that did not need one (`table_content_hash` covers the attribution rows, not the dispatch
table). Derive the width from the gates, do not argue it.

## 5. Make the fixture distinguishable from the real thing

First version of `verify_exit_intent` case 8 asserted "no-op ports render nothing, reading
ports render one". Both halves passed and the first was near-vacuous: with nothing at the
configured path, a render that bypasses the port and reads `std/fs` behind its back looks
identical to one that goes through it.

It now plants a **decoy** — a real run file at the configured path naming a DIFFERENT pane
(`w1:pDECOY`) than the scripted content (`w1:pA`) — and asserts the routed render names
`w1:pA`, the no-op render names nothing, and the two DISAGREE. Verified by reintroducing the
ambient read: the case goes red and names `w1:pDECOY`, so the diagnostic says which read
happened rather than that a count was wrong.

## 6. The expensive one: prose that claims more than the code earns

Four of the ten findings were sentences, not defects:

| Claimed | True |
|---|---|
| `Unconditional` dispatch is "the truth, not the convenient answer" | the render is gated by `enabled` AND by whether a manifest was named — neither "every atom" nor "every turn end" held |
| the token check "restores the freshness a cached action loses" | it NARROWS a TOCTOU window the pre-7.0 reaper also had; closing it needs a server operation herdr does not offer |
| execution is "bounded" | 32 actions x 1s, with a catchable kill signal |
| "mechanism moves; policy stays" | the RUNGS were unchanged; the SET of panes reaped narrowed in two ways |

Every one was argued at length and sounded measured. The dispatch one was argued from a
property of code the same change had just made conditional.

WHY THIS MATTERS MORE HERE THAN ELSEWHERE. In this repo the comments ARE the specification —
gates read them, profiles cite them, and the next person budgets from them. A wrong comment
is a wrong spec that no gate will ever fail on. `make check_core` cannot read English.

THE HABIT: when writing "this is the truth rather than the convenient answer", stop and go
find the code that makes it false. If the sentence is worth that much emphasis it is worth
one grep. Three of the four above would have died to a single search of the function being
described.

## 7. The gates were right every time

`driver_plus_no_ops` rejected a rowed unconditional slot returning no world state.
`world_state` rejected an ambient env read that moved onto the deterministic driver path.
`attribution_table` caught the anchors twice. `driver_plus_compose` caught a stale
`rowed_slot_ids()` with "both readings type-check and the stale one is silent".
`ext_hook_scope_selftest` refused a registration it could not enumerate — which turned out to
be a real bug in `keep_interpolations`, blanking a string literal's quotes along with its
text so `ExitIntent("label", …)` read as `Kind(, f)`.

Every one of those was a design correction delivered as a test failure. None of them could
have caught a paragraph.
