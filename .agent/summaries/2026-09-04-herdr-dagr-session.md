# 2026-09-04 herdr+dagr live exercise, nitfixes, model selection, exit-intent design

Branch: `arniwesth/mot-133-f-5-extension-side-tag-delegates-at-spawn-report-stale`
(HEAD `440580c` at session start; all work below is uncommitted on top, except the
design note which is a new untracked file.)

## 1. Live delegation → dagr measurement (the planned exercise)

Ran the operator's 11-step probe prompt (report-only) against the live session.
`HERDR_ALLOWED_KINDS=claude,motoko`, `HERDR_REAP_ON_EXIT=1`, pinned `dagr v0.3.1`.

- **Orphan sweep** fired on first call, read-only, 8 stale tasks in other sessions'
  files — correct (not our file, never write it).
- **alpha/beta/gamma** (`motoko` kind) all settled `done·reported`, receipt = answer
  path. Mid-flight `working` polls never false-fired `lost`.
- **delta** (pane killed before first poll) settled `lost·heuristic`, task `failed`,
  no probe file — the `agent_not_found` gate fires when the pane is really gone.
- **Idempotent re-check**: unchanged result, but `elapsed` grew 52.4s→56.5s
  (wall-clock `now-start` recomputed; later fixed, §2).
- **Bogus `retry_of`**: delegation succeeded as new work, linkage refused with
  reason in both tool result and run file.
- **Run file** (`.dagr/run-w1-pT-1788502472210.json`): no `verified`/`asserted`/
  `model`/`last_output_at`, no `unblock` on settled tasks, `retry_of` → attempt a2
  of same task with `owner` = new handle (by design, §3.6). `dagr check --strict`
  clean (`[]`). First document this code produced ever rendered by `dagr view`.
- **Panes**: only `w1:pY` (dagr viewer) carries `mot-owner`; delegate panes reaped
  on settle as designed.

## 2. Nitfixes from the measurement (all in `packages/motoko-ext-herdr/`)

1. **Re-check elapsed**: `do_check_motoko` early-answer passed `waited=999999`
   (forced "took Xs"); now `waited=0` → honest "at most Xs / upper bound", matching
   the claude/codex early path. (Measured 52.4s→56.5s misreport gone.)
2. **pX-vs-pY double opener**: `ensure_dagr_pane` note now names the marker file
   and states hand-opened views win (`dagr-pane.sh` takeover, measured 2026-09-04).
3. **`owner` confusion**: comments on `open_task`/`open_retry` state `id` = first
   handle, `owner` = current handle.
4. **Review nits** (motoko review SHIP-WITH-NITS, `mot-dlg-1788520987788`, 218s):
   `dagr-pane.sh` pin derived from `Makefile DAGR_VERSION`; post-wait status
   reports `target` instead of stale pre-wait status; quoting-refusal lands at
   `reported` while herdr-observed spawns keep `verified` (new `tier` param on
   `open_failed_task`/`dagr_failed`).

Gates: `ailang check` clean ×4 files; `verify_dagr_producer` (incl. `--strict`),
`verify_herdr_{dagr_pane,owner_tag,check_answer,gate}`, `verify_repetition_guard`
— 55 OK, 0 FAIL.

## 3. Split herdr/dagr? — No.

One extension, two layers (pure `dagr.ail`/`types.ail` vs effectful `herdr.ail`)
is the right seam. A runtime split costs ordering/atomicity, doubles `pane list`,
forks `HerdrConfig` identity, and serves no second consumer. Revisit only if a
non-herdr producer appears.

## 4. Codex allowlist + PR — blocked on host (still open)

- `HERDR_ALLOWED_KINDS=claude,motoko` lives at
  `.devcontainer/agent_confined/docker-compose.yml:246` (ro mount in here).
  Change to `"claude,motoko,codex"` + recreate on the host. Tried `EditFile`
  (temp-file fail), `touch` (EROFS), `docker` (exit 127, no CLI in container).
- `make pr` blocked on same recreate: `MOTOKO_BOT_GH_TOKEN` is in host `.env`
  but in-container `.env` is masked to 0 bytes by design, so `tools/pr` finds
  nothing. Draft is staged + filled
  (`.agent/github/staging/arniwesth-mot-133-…/body.md`, base `main_dst`);
  publish from fresh container or host.
- One recreate fixes both. Resume triggers: `codex permitted` → fire codex
  review; token-fixed → `make pr BASE=main_dst`.
- Reviews so far: claude spawn failed `agent_not_ready` (unauthenticated CLI);
  codex refused by policy; motoko review SHIP-WITH-NITS (above).

## 5. `model` selection (free-string) — implemented, gated, live-pending

Both CLIs take it (`claude --model`, `codex -m`); herdr forwards trailing
`[AGENT_ARG]...` after `--` (same slot as codex relaxation flags).

- `types.ail`: `kind_model_args` (claude/codex only, shell-token refusal →
  degrade to CLI default), `argv_start_model` (old `argv_start` delegates with
  `""`, byte-identical default).
- `herdr.ail`: schema `model` param, threaded through both `agent start` sites,
  `model_note` transcript line.
- `dagr.ail`: request recorded verbatim as attempt `model` chip (per
  `dagr --skill`); empty omits. Narrows the old "`model`: nothing selects or
  records one" refusal with reason.
- 4 new `verify_mot136` asserts green; `--strict` clean.
- Live: direct `model: claude-fable-5` delegation settled `done` but via OLD
  loaded code (no "with model" text, no chip) — this runtime predates the change.
  Nested motoko probe confirmed new code on disk (`grep` = 3) but hit the depth-1
  recursion gate before spawning. **Live proof of the new path needs the
  post-recreate runtime** — one pane: `kind: claude, model: claude-fable-5`,
  check attempt row + success text.

## 6. Exit-intent ABI design note (+ review)

- Wrote `.agent/projects/021_herdr_delegation/DESIGN-exit-intent-abi.md` (v1:
  closure `ExitIntent` + `ExtCtx` identity) for the parallel ABI stabilisation.
- Claude review (`mot-dlg-1788529974769`, 603s): **NEEDS-FIX** — B1 (exit runs
  where no extension code exists; per-task runtime is gone), B2 (record payload
  chooses the `smuggle` hole; positional is row-checked), B3 (`register` takes
  no `ExtCtx`; `ExtCtx` is per-task, no stable clock). Majors M4–M10 (pricing
  inverted, coverage already atom-based, `ExtWorld` opacity, `PublishFile` not
  `WriteFile`, per-task death of incremental state + host-reads-run-file
  alternative). Review: `.motoko/herdr-delegates/answer-mot-dlg-1788529974769.md`.
- Rewrote doc to **v2**: data-not-closure actions cached per turn, positional
  payload, registration-time bool, mint stays host-side (format unifies),
  corrected migration pricing + acceptance. **Needs a second review round
  before building** (§5 Q1/Q4, M10-b).
- Side finding: "Claude Fable 5.1" was never pinned — `kind` selects the CLI,
  not its model (observed: Claude Code v2.1.260 / Opus 5); the run file
  deliberately records no `model`. The §5 feature closes exactly this gap.

## 7. Open items for next session

1. Host recreate (token + codex allowlist) → `make pr BASE=main_dst`.
2. Live `model` probe on fresh runtime (one claude pane).
3. Second review of exit-intent v2, then ABI pass.
4. Cleanup: `rm -f .dagr/probe-*.txt`; PR includes untracked
   `DESIGN-exit-intent-abi.md` (add it); `little-coder/` untracked, unrelated.
