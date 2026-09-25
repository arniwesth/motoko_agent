# NOTE-007: the loop that would not stop, and the guard that now breaks it

Date: 2026-09-02. Source: `.motoko/logfile/session_2026-09-01T19-12-41-501Z.jsonl`, the fourth
session in that file (`session_1788294098723`, the `continue` turn). Implements track A of the
2026-09-02 triage; B, E and D are in
[`021/MEASUREMENTS-2026-09-02-run-file-truthfulness.md`](../021_herdr_delegation/MEASUREMENTS-2026-09-02-run-file-truthfulness.md).

## What happened

After answering the operator's question, the model ran **197 steps of one cycle** — open a herdr
pane, `sleep 2`, read it, close it — for twenty minutes, and was still going when the log ended.
No `run_summary`, no `done`. Measured from the transcript:

- **188 tool calls**, of which **84 were byte-identical** `herdr plugin pane open …`
- **~90 panes** spawned and closed
- **95 non-empty assistant messages**, comprising **11 distinct texts** — one of which appears
  **85 times**, byte for byte, at 1969 characters

Nothing caught it. `empty_stop_guard` and `progress_contract_guard` were both loaded and both only
ever push the model to *continue*; there was no guard anywhere that could argue for stopping.
`agent.max_steps` was 300 and was never reached. NOTE-006 §2 predicts this shape from compaction
eliding older tool outputs — the model loses the record of what it already verified and re-verifies
it.

## The correction that shaped the fix

The first version of this guard counted **identical (call, result) pairs**. That is the
discriminator that keeps legitimate polling safe: `DelegateCheck` on one handle is *supposed* to be
called repeatedly, and the herdr integration prompt asks for eight in a row, but a poll whose state
is moving never returns the same bytes twice.

Replayed over the real transcript, **that rule fires never.** `plugin pane open` returns a **fresh
pane id on every call**, so the 84 identical calls produced 84 distinct results and no two pairs
ever matched. The design was reasonable and the measurement refuted it.

What *was* byte-identical was the prose. So `decide_call` carries two rules:

| rule | fires on | budget |
|---|---|---|
| A | the same (call, result) pair seen N times — same question, same answer | 5 |
| B | the message **carrying** the call restates prose the assistant has already emitted verbatim, ≥200 chars | 2 prior |

Replayed over the real transcript with rule B, the deny lands at **step 31 of 197**: 166 steps and
82 of the 84 pane opens that never happen.

## Two hooks, because one of them cannot see the bug

`SolverJudge` fires **only** on a step with no tool calls (`session.ail`'s `hybrid_attempt = None`
arm). Every step of the observed loop carried a `BashExec` call, so a finalize-side guard alone
would have watched the whole thing go past. It is still right for the other shape — a model that
has stopped calling tools and is only restating — and there it returns `Accept(candidate)`, ending
the run with the text the model kept repeating. That text *is* the answer; the model just could not
tell it was done. Asking it to continue is what the other two guards do and is exactly wrong here.

`ToolPolicy` fires on every tool call, which is where the loop lives, and returns `Deny`.

The threshold and length floor are captured at registration (`MOTOKO_REPEAT_CALL_BUDGET`,
`MOTOKO_REPEAT_ANSWER_BUDGET`) because `ToolPolicy` is a pure row with no `Env`. Zero disables a
half — inert, not absent, which is what an operator reproducing a loop needs.

## What this does not do

**No extension seam can halt a tool-calling loop.** `ToolPolicyDecision` has no terminal variant; a
denied call returns a denial and the loop goes round again. What denial buys is that the call
**never executes** — no pane, no `sleep`, no subprocess — so a runaway costs a model round-trip
instead of two panes and two seconds of wall clock, and the model is told, in the one place it is
guaranteed to read, that it is repeating itself. **The hard ceiling is still `agent.max_steps`.**

`Pending(reason, DenyAfterTimeout)` *would* halt: it suspends the run for an operator decision.
Deliberately unused. Nothing in this tree returns `Pending` yet, `approval_read` blocks on the
operator, and turning a runaway loop into a hung session is a worse failure than the one being
fixed. That trade is an operator's to make.

Also unfixed, and visible in the same file: the turn immediately before the loop finished with
`output_tokens: 4096` and `output: ""` — a max-tokens truncation surfaced to the user as an empty
answer (`empty_stop_finalize` at step 0, then `done` with no output). Separate bug, not touched
here.

## Gates

`make check_core` goes from 28 assertions to 46; `verify_repetition_guard` contributes 18 and
`verify_extensions` now boots 9 extensions. The negative cases carry the weight:

| must not fire | why it would be fatal |
|---|---|
| a poll whose output moves, at any depth | `DelegateCheck` polling is the documented way to use delegation |
| identical commands with moving output, 12 deep | test-edit-test iteration is a working session |
| short repeated narration ("Now let me run the tests.") | a model says that more than twice and is fine |
| a first or second emission of an answer | `history_slice` is `msgs ++ [candidate]`; counting the candidate would end every run on step one |
| a blank repeated candidate | that message is `empty_stop_guard`'s, and it asks for a real answer |

`repetition_guard` is enabled in the `default` profile, after the two guards it argues against.
