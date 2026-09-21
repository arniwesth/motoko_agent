# Brief: adversarial review of ADR-004 v4 (same session as the v3 review)

Same repo, branch and HEAD (`d5edebf`) and the same rules as `BRIEF-adr004-v3-review.md`:
read-only; edit nothing under the repo except the one review document you write; no commit; no
`make dst`, replay, prototype run or other heavy execution (memory is contended); `ailang check`
and targeted Python reads of existing files are fine; do not open, close or prompt any pane or
agent. Temporary evidence goes under `/tmp/claude-1001/-workspaces-motoko-agent/0dc4f7fe-4912-46cb-8ed0-5a4e6fc6a2b5/scratchpad/codex-review-v4/` (create it); you may reuse the
scripts and outputs in `/tmp/claude-1001/-workspaces-motoko-agent/0dc4f7fe-4912-46cb-8ed0-5a4e6fc6a2b5/scratchpad/codex-review/`.

## Under review

`.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md` —
Proposed, **v4**, unreviewed. It claims to fold all ten required changes of your v3 review
(`REVIEW-adr004-v3-verdicts-codex.md`, "Required changes for v4"). The v1→v3 history is carried
verbatim; the new material is the "v3 → v4" retraction block (sixteen items) and the rewritten
TL;DR, Context, D1–D8, Consequences, Not decided and Cross-references.

## What the review must do

1. **Disposition of your ten required changes**, one row each: ADDRESSED / PARTIAL / NOT
   ADDRESSED, with the evidence, in the shape of your v3 review's §1.2.
2. **Disposition of the sixteen v3→v4 retractions**, one row each, as your §1.1 did for v3.
3. **Per-decision verdicts** D1–D8, ACCEPT / ACCEPT WITH CORRECTIONS / RETURN, with reasons.
4. **Check the new mechanisms against HEAD**, each with file:line:
   - D1's **stopping contract** and the T0 settings table: is the set of reachable ends under
     those settings exactly what D1 says (continuation → `tool_calls` → tools → budget test;
     stop → `classify_candidate` → `CandidateApproved` → `dp7_approved` → `Finalize`)? Is any
     arm still reachable that D1 does not name (blank stop, `dp7_rejection_errors` with
     verification disabled, solver with an empty registry, hybrid extraction with a seed that
     has native calls, `open_waits`)? Is the `StopBeforeEnd` cutoff coherent?
   - D1's **runtime-status cutoff** and the claim that no other tool bypasses the queued seam at
     T0 (`dispatch_tool_entries_with_builtin`, the policy/handle seams with an empty registry,
     `backend_for_v2` with `ohmy_pi = false`).
   - D2's **guarded-delegation seams**: can `eval_model_step`/`eval_tool_exec` be written as
     specified with only exported names (`record_interaction`, `encode_exhausted_provider_outcome`,
     `encode_tool_outcome`, `recording_ports`, `recording_tool`, `world_tool`)? Does replacing
     the last interaction's `request_projection` preserve everything `world_state_of`,
     `reconstitution_balance`, `check_discovery` and `strict_replay_findings` read? Is "assert
     exactly one interaction appended" always true of `recording_model_step` and
     `recording_tool` (including fault and mismatch paths)?
   - D2's **exhausted marker** handling: recorded as `{served:false}`, returned as a
     non-retryable `Err`; confirm `script_of` skips it, that `ProgramExhausted`/counts see it,
     and that a run containing one can never satisfy A6/K6.
   - D2's **program sketch** and manifest: does `validate_manifest(m, driver_only())` accept what
     D2 fills, and is every required field sourced?
   - D3's **witness** construction: are the per-key env-read counts right for the T0 settings
     (policy init, the profile-config branch of `resolve_context_limit_sum`, `MOTOKO_SESSION_ID`,
     `MOTOKO_TOOL_TIMEOUT_MS` per native dispatch, `MOTOKO_EXIT_MANIFEST` on each end shape,
     `MOTOKO_CAPTURE_FAILED_PAYLOAD`), and do `env_balance`, `absent_classes` and the clock
     delta behave as D3 assumes for a run with zero approvals/effects/file mutations? Does the
     synthetic profile config in `files` actually get read by the recording adapters' file port?
   - D3's **A8/K4**: can `execution_of` be called with the inputs D3 lists for a journal replay
     (`ReplayObligation`, `ReplayMetadata`, decision/retry budgets), and which families are in
     fact vacuous at T0?
   - D5's **protected regions** by function-text hash: is the listed set the right set (does the
     seam path depend on anything else in candidate files), and is a hash of function text
     implementable from the tooling that exists (`tools/predicate-anchors`,
     `tools/driver_leaf_inventory`) or does it need new tooling?
   - D5's **line-neutral variant commit**: is it actually achievable at `d5edebf` for all three
     sites (the sum at `stub_step.ail:69`, the arm in `ported_provider`, `frame_ordinal0`) and
     the constructor imports, without moving `anchors.sh`'s pinned lines or `derive.py`'s
     bridge span? Say which lines would be joined.
   - D6's **contextual scan policy**: re-run the scan with the 16-character-body sharpening over
     r2.1's seed, script and tool outputs and report counts per reason and per component (no
     content); say whether r2.1 is admitted under it, and whether the sharpening is sound
     against the credential prefixes in `credential_value_prefixes()`.
   - D4's **measured process**: is "the seed fold runs inside the measured process" consistent
     with what the profile actually captures, and does it change the control comparison?
5. **Everything factually wrong** in v4 — code, numbers, or what the reviews said — as a list
   with corrections, including any coordinate in the Cross-references that does not resolve.
6. **Anything a v5 must still change**, as a numbered list, or state that v4 can be the version
   PLAN-004 is written against.

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-adr004-v4-verdicts-codex.md` in
the shape of your v3 review: header (date, HEAD, branch, subject, prior, method, what you did not
do); overall verdict; §1 the two disposition tables; §2 per-decision verdicts; §3 the mechanism
checks; §4 claim audit; "Required changes for v5" (or "None: PLAN-004 may be written against
v4"). Every claim carries a file:line at `d5edebf` or a command and its output. When finished,
reply with only the review file's path.
