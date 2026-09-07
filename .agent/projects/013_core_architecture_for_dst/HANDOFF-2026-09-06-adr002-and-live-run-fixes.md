# Handoff: ADR-002 v2.1, the PLAN-001 live-run fixes, and what the container rebuild kills

Date: 2026-09-06, written just before the herdr container is rebuilt.
Branch: `arniwesth/013-dst-architecture-adr`, HEAD `8980ba6`. **Nothing from this session is
pushed. Everything under `.agent/` from this session is UNCOMMITTED** (see §2).
Author: a Claude Code session (Fable 5.1) in herdr pane w3:pR, orchestrating two delegates.
Its transcript is not in `.motoko/logfile/`; this page and the documents it names are the record.

## 1. What this session did, in order

1. **Read the PLAN-001 orchestration log** (`.motoko/logfile/session_2026-09-05T16-06-34-724Z.jsonl`,
   a motoko session on `muse-spark-1.3-contributor` driving `.dagr/run-plan001.json`) and its
   worker logs. Six findings, recorded in
   [`../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`](../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md).
   Two of its numbers were later corrected by the ADR-002 review and the note carries the
   corrections inline (195 provider calls, not 193; the check/read/nudge breakdown).
2. **Wrote four issue files** and extended a fifth:
   `delegate-worker-output-budget-exhausted-and-empty-tool-arguments.md` (open; carries a
   correction that the truncation diagnosis is inferred),
   `hybrid-bash-extracts-prose-examples-in-native-tool-mode.md` (resolved),
   `herdr-extension-run-file-drifts-from-operator-plan-file.md` (open, option B done),
   `session-logger-prints-undefined-version-on-conversational-turns.md` (resolved),
   and a "Second occurrence" section in `progress-guard-prose-heuristics-permit-premature-stop.md`.
   Plus a status paragraph in `DESIGN-delegate-model-selection.md` and a §10 in
   `DESIGN-dagr-as-delegation-view.md` (the two-run-files question, options A/B).
3. **Delegated the fixes to a claude-kind agent on Opus 5** (herdr pane w3:pT, name
   `plan001-fixer`). Six commits, one per fix, `28a7c67`…`8980ba6`, all on top of `a24a78a`.
   Its report is preserved at
   [`../021_herdr_delegation/REPORT-2026-09-06-live-run-fixes-opus.md`](../021_herdr_delegation/REPORT-2026-09-06-live-run-fixes-opus.md)
   and its brief at `TASK-2026-09-06-live-run-fixes-brief.md` beside it. Read the report's
   "Decisions the issue did not settle" and "Things a reviewer should look at" before touching
   any of those six areas.
4. **Wrote ADR-002 v1** ([`ADR-002-park-and-wake.md`](ADR-002-park-and-wake.md)): a parked
   step-machine state served by a `wake_read` port, plus an explicit task-complete signal from
   the motoko runtime. Direction chosen by the owner.
5. **Delegated an adversarial review to codex on `gpt-6-astra`** (pane w3:pV, name
   `adr2-reviewer`): [`REVIEW-adr002-verdicts-codex.md`](REVIEW-adr002-verdicts-codex.md),
   brief at [`BRIEF-adr002-review.md`](BRIEF-adr002-review.md). Verdict: reject as written,
   retain the direction; D2 and D5 rejected; 26 corrections.
6. **Rewrote ADR-002 as v2** folding all 26 corrections (version history and retractions at the
   top), then **v2.1 adding D6** (session snapshot and `--resume`) at the owner's request.
   v2.1 is **unreviewed**.

## 2. The working tree, exactly

Committed by the fixer (`git log a24a78a..8980ba6`): six fix commits. Everything else is dirty.

**Dirty tracked files that are this session's or the fixer's:**
`.agent/issues/delegate-worker-output-budget-…`, `.agent/issues/progress-guard-…` (a
cross-reference to ADR-002 added after the fixer's commit), `.agent/issues/step-budget-exhaustion-…`
(a "Design home" pointer to ADR-002 D6), `.agent/projects/021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` (§10).

**Dirty tracked files that are NOT this session's — do not commit them blind:**
`Makefile` (a `motoko:` target), `src/core/tool_catalog.ail` (2 lines), `ailang.lock`,
`tools/ext_ambient_inventory/fixtures/expected.json` (the D6 re-pin from yesterday's run),
`.agent/projects/028_…/PLAN-002-lower-the-complexity.md`. The first three are the P1B motoko
worker's (pane w3:pQ; the owner says it did what it was told and finished).

**Untracked, this session's:** `ADR-002-park-and-wake.md`, `REVIEW-adr002-verdicts-codex.md`,
`BRIEF-adr002-review.md`, this handoff, the four new issue files,
`021/MEASUREMENTS-2026-09-05-plan001-live-run.md`, `021/REPORT-2026-09-06-…`, `021/TASK-2026-09-06-…`.

**Untracked, older, not this session's:** ADR-001, PLAN-001, NOTE-002, both ADR-001 reviews,
`mmd/`, the three `ailang-*` issues, `012/EVAL-…`, `docs/`, `herdr-studio/`, `little-coder/`,
`studio.png`. Whoever commits 013's documents should commit ADR-001 and PLAN-001 with them;
they are the ADR-002 inputs.

## 3. What the container rebuild destroys

- **Every herdr pane and agent**: the orchestrator w3:p5, the P1B worker w3:pQ, the fixer
  w3:pT, the reviewer w3:pV, this session w3:pR. All were idle at handoff. Nothing in flight.
- **The scratchpad** under `/tmp/claude-1001/…`. Its three files are copied into the repo (§1).
- **`.dagr/` markers and the extension's run file** (`run-w3-p5-1788624394725.json`) become
  stale again, as the issue on run-file drift describes. `.dagr/run-plan001.json` is the
  owner's and shows P1B `working`; settling it is the owner's call.
- **The codex `gpt-6-astra` usage window**: nearly exhausted by the review. Do not send that
  account more heavy work today. Model id is `gpt-6-astra`, not `astra` (the bare name starts
  cleanly and fails on the first request). Codex in this container needs
  `-s danger-full-access -a never` because unprivileged user namespaces are off.

## 4. What is open, in the order I would take it

1. **The contract-policy red on the branch.** `make new_contract_policy` reports 8 unjustified
   declarations in `src/core/context_limit.ail`, which came in with yesterday's P1A takeover
   commit `a24a78a`, not with the fixes. Diff-relative, so it is a CI failure waiting. Small,
   mechanical; the fixer's report lists the eight names.
2. **A second review of ADR-002 v2.1**, covering the D2 rewrite and D6. Use a fresh codex window
   or a claude-kind reviewer; the brief in `BRIEF-adr002-review.md` is reusable with its
   "Under review" paragraph updated to v2.1 and the six questions replaced by: D2's precedence
   table against `session.ail:3017–3080`; the host protocol's completeness; D6's snapshot as a
   DST object; whether D6 stage 1 really needs nothing from D2.
3. **PLAN-002 for ADR-002** after that review: D5's steps 1–5 with gates; first item the herdr
   `--message` probe; D6 stage 1 second; O5 (`DelegateAwait`) as the fallback item.
4. **The upstream ask** for an output-token parameter on `std/ai.step` (issue file 1, item 2).
   Route through the `ailang-feedback` skill. Nothing repo-side can raise the 4096 cap.
5. **Commit** 013's and 021's documents and the four issues, in one or two commits, once the
   owner has read the ADR.

## 5. Facts worth not rediscovering

- The runtime already boots from a history + `WorldState` + counts tuple
  (`session.ail:709`, `run_v2_from_messages*` at `:3283`); `WorldState` has a JSON codec
  (`ext_world.ail:515`, `:543`). That is why D6 is small. The JSONL log is **not** a transcript:
  digests only, and compaction rewrites history unlogged.
- Motoko is a herdr lifecycle authority (020 ADR-001): herdr runs no detection on its panes,
  Motoko reports `idle`/`working`/`blocked`. herdr accepts exactly four reportable states;
  `done` is derived, not reportable. A motoko delegate's `idle` covers startup, turn end,
  empty stop and completion — hence answer-file-only checks.
- Production `approval_read` is `readLine()` with the request ignored (`stub_step.ail:205–213`);
  there is no TUI approval handler. ADR-002 v1 assumed one; v2 does not.
- `Delegate` now **refuses** a call without `kind` when more than one kind is allowed, and
  `HERDR_DELEGATE_KIND`'s unset value is `""`, not `claude` (fix 3, `75ab532`). `default_kind()`
  is deleted. With `HERDR_ALLOWED_KINDS=claude,motoko` every Delegate must name its kind.
- Hybrid bash extraction is off for the rest of a session once it has emitted a native tool
  call (fix 2). Prose with fenced shell examples is safe again in v2 sessions.
- Truncated native tool arguments now produce `arguments_undecodable` with the byte count and
  a `ToolArgumentsUndecodable` ledger event (fix 1) instead of `missing path`. The old
  `decode_or_empty` is gone; the native path's decoder was `tool_dispatch_adapter`, not it.
- The progress guard allows a stop while a delegate is open, by reading the extension's own
  tool-result sentences (fix 5). Known limit: last signal wins, so "launch A, launch B,
  collect B" hides A. ADR-002 D3 replaces it with runtime wait state.
- The extension yields its dagr view when `.dagr/.pane` names a pane that `herdr pane get`
  still reports as a `dagr` label (fix 4). The two run files still drift; §10 of the dagr
  design has the A/B decision.
- My own harness waits for a delegate for free (a detached `herdr agent wait`, wake as an
  injected message). Motoko's equivalent is ADR-002 D2; the interim is D3's guard change plus
  `DelegateCheck` when there is something to collect.
