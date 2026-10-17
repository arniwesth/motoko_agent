# AILANG mission system: how much is code, how much is prose

Source: sparse, blobless clone of `sunholo-data/ailang` `dev` at `2a1f3f295` (2026-10-03).
All paths are relative to the clone root unless absolute.

Conventions in these notes

- **[O]** observed: read directly in a file at the cited `path:line`.
- **[I]** inferred: my reading of what the code implies. Nothing was built or run.
- "No caller found" claims are limited to what is on disk in the sparse checkout:
  `cmd/ailang`, `internal/{coordinator,messaging,mission,storage}`, `scripts`, `tools/{coordinator,launchd}`,
  top-level `tools/*` files, `missions`, `design_docs`, `docs`, `.claude`. Other `internal/` packages
  and `.github/` were not on disk and were not searched.

---

## 0. Headline: the split

**[O] Size.**

| Layer | Non-test lines | Test lines |
|---|---|---|
| `internal/mission/**` Go (56 files) | 10,530 | 9,993 |
| `cmd/ailang/mission_*.go`, `design_quorum.go`, `chains_stats_mission.go` | 3,395 | 1,821 |
| `internal/coordinator/mission_*.go` (the SQLite state machine) | 877 | 960 |
| `tools/launchd` mission shell (driver, helpers, libs, hook) | 4,299 | 5,919 |
| `scripts/mission_{answer,decisions,directives,pi_run}.sh` | 774 | 225 |
| `.claude/skills/mission-control` (SKILL.md + 12 resources), prose | 5,426 | none |

The driver `tools/launchd/mission-control.sh` is 2,511 lines, of which 1,218 are comment-only
lines: about half of it is incident narrative.

**[O] What the live loop actually runs.** The live path is: launchd plist, then the bash driver,
then one headless controller session whose instructions are the prose skill.
`tools/launchd/mission-control.sh:2208-2222` builds the prompt: "Run one mission-control iteration:
invoke the mission-control skill for ${MISSION_DOC} and follow its gates." Gates 0 to 5 (observe,
pick, route, record, retro) are prose executed by a model.

**[O] The durable Go state machine is opt-in, not the live path.**
`docs/docs/guides/mission-iteration.md:16`: "This opt-in path does not activate or replace a
mission's live schedule by itself." `docs/docs/guides/mission-role-dispatch.md:93-95`: "The live
loops retain their existing drivers unless explicitly opted into `mission iterate`". The driver
takes that path only when `AILANG_MISSION_WORK_ITEM` is set
(`tools/launchd/mission-control.sh:1969-1978`, `exec ailang mission iterate --work-item ...`).
The supervised activation of it is limited to one mission:
`cmd/ailang/mission_activation.go:59` "activation currently supports local Docs only".

**[I] So the answer to "how much is code" has two halves.** Around the iteration, nearly everything
is code: scheduling, overlap, kill switch, billing guard, quota ration, model ladder, watchdogs,
slot verdicts, the human-comment allowlist, ledger validation, quorum, log rotation, registry and
drift doctor. Inside the iteration, what to pick, how to verify, how to record and how to credit a
dead predecessor are prose. A complete code replacement for the inside exists (about 2,600 lines of
`iteration` plus 877 lines of SQL state) but at this commit it is a canary.

---

## 1. `missions/*.toml`

### What an entry contains

**[O]** `internal/mission/registry.go:53-85` (`type Mission`) and `:38-49` (`type Schedule`):

- `name`: 1 to 32 chars of `[a-z0-9-]` (`registry.go:90-100`, `:121-123`). "Mission names become
  filenames, launchd labels and state-file keys" (`:87-89`).
- `repo`: GitHub slug, required (`:124-126`).
- `workdir`: absolute path to the checkout, required; `~` rejected because "the driver runs under
  launchd, where ~ is not expanded" (`:130-147`).
- `doc`: "the mission charter path, repo-relative" (`:127-129`).
- `[schedule]`: `mode` is `keepalive` or `interval`; exactly one of `throttle_seconds` or
  `interval_seconds` matching the mode (`:149-170`); `boot_offset >= 0` (`:172-174`).
- `driver`: optional absolute path. "EMPTY MEANS THE SHARED DRIVER" (`:66-77`). None of the six
  files sets it.
- `[roles]`: a rejection trap. "Roles is a REJECTION TRAP, not a field" (`:60-64`); load fails if
  present (`:114-119`). Model assignment belongs to `models.yml`.
- Cross-entry checks: duplicate names and colliding `boot_offset` values fail the whole load
  (`:209-230`).
- TOML comments carry the ratified rationale. `internal/mission/render.go:226-231`: "That rationale
  moves to missions/<name>.toml, which is the reviewable artifact; the plist becomes a build
  product with a pointer to it."

Actual values **[O]**: v1 keepalive/5400, offset 0 (`missions/v1.toml:43-48`); world
keepalive/14400, offset 420 (`missions/world.toml:27-30`); docs interval/21600, offset 840
(`missions/docs.toml:27-30`); motoko interval/46800, offset 1260 (`missions/motoko.toml:17-20`);
fleet interval/21600, offset 1680 (`missions/fleet.toml:16-19`); stapledon interval/21600, offset
2100 (`missions/stapledon.toml:16-19`).

### What reads it

**[O]** One loader: `mission.Load` (`registry.go:256-277`), reached through `loadMissionRegistry`
(`cmd/ailang/mission_cmd.go:156-188`), which uses `AILANG_MISSION_REGISTRY` if set, else `missions/`
in the working directory or an ancestor. Callers:

- `ailang mission list` (`mission_cmd.go:190-209`) and `doctor` (`:211-235`).
- `install` (`:237-258`): `RenderStagedFrom` writes `<env>.staged` and `<plist>.staged` only
  (`render.go:376-409`).
- `apply` (`:260-309`): promotes staged files and reloads launchd; refuses mid-iteration, and needs
  `--adopt` for a hand-written plist (`internal/mission/apply.go:31-48`).
- `rotate-log` (`:338-345`) and `normalize` (`:425-470`): use `name`, `repo`, `workdir` to find the
  log files.
- `iterate`, first admission only (`cmd/ailang/mission_iteration_cmd.go:199-211`): `workdir`
  becomes the source repository. "Resume reads saved repository and model inputs; changing today's
  registry does not reroute an admitted item" (`mission-iteration.md:44-46`).
- `tools/launchd/test_mission_routing.sh:636-639` iterates `missions/*.toml`.

**[O] The running driver does not read the TOML.** It sources the rendered
`~/.config/ailang/mission-<name>.env` on every fire (`mission-control.sh:71-82`). The registry
authors only four variables in that file, `MISSION_NAME`, `MISSION_REPO`, `MISSION_DOC`,
`MISSION_WORKDIR` (`render.go:31-36`); everything else is passed through byte for byte
(`render.go:24-30`). The plist is fully generated: label, `/bin/bash <driver>`, `HOME`,
`MISSION_PROFILE`, `MISSION_WORKDIR`, `PATH`, `RunAtLoad`, and either `KeepAlive` +
`ThrottleInterval` or `StartInterval` (`render.go:232-300`).

**[O] `boot_offset` is validated but never consumed.** The only readers are the validators
(`registry.go:172`, `:222-227`). The driver uses its own hard-coded table
(`mission-control.sh:690-700`). `registry.go:47` admits it: "Today this lives as a case arm inside
the driver; the registry is its home." The bootstrap guide tells the operator to edit both
(`mission-bootstrap.md:272`).

**[O] Other hard-coded mission lists that the registry does not feed.**

- `internal/mission/comms/comms.go:39-44`: `missionRepos` names v1, world, docs, motoko only.
  **[I]** `ailang mission report --mission fleet` or `stapledon` would fail with "unknown mission"
  (`comms.go:67-76`).
- `tools/mission-weekly-report.py:28-33`: `MISSIONS` names v1, world, motoko only.
- `tools/launchd/githooks/pre-push:53`: special-cases `fleet`.

**[O] Doctor checks** (`internal/mission/doctor.go:162-292`): env vs registry (`env-drift`),
installed env vs the reviewed copy in `tools/launchd/mission-env/` (`env-source-drift`), plist
missing or schedule mismatch, PATH without `/usr/sbin`, file vs loaded launchd job
(`loaded-stale`), pin sentinel present, declared fork. Exit 0 clean, 1 drift, 2 registry error
(`mission_cmd.go:214-218`, `doctor.go:127-133`).

### Six TOML files, four charters

**[O]** The four charters under `design_docs/` are `v1-mission.md`, `docs-mission.md`,
`motoko-mission.md`, `fleet-mission.md`. Those are exactly the four entries with
`repo = "sunholo-data/ailang"` (`v1.toml:13`, `docs.toml:11`, `motoko.toml:5`, `fleet.toml:8`).
The other two work in other repositories, and `doc` is relative to the mission's own repo:

- world: `repo = "sunholo-data/ailang-world"`, `workdir = ".../ailang-world"`
  (`missions/world.toml:10-12`).
- stapledon: `repo = "sunholo-data/stapledons-godot"`; "Charter: design_docs/stapledon-mission.md
  in the game repo" (`missions/stapledon.toml:3-4`, `:8-10`).

The code encodes the same distinction: for non-shared repos, `normalize` looks in `m.Workdir`
(`mission_cmd.go:438-441`), and `rotate-log` uses the registry checkout only when
`m.Repo == sharedRepoSlug` (`mission_cmd.go:355-360`, `:381`).

**[O] One stale comment worth knowing.** `missions/world.toml:3-8` still says "WORLD IS A FORK.
Its driver lives in a SEPARATE GitHub repo ... De-forking is Phase 3 ... gated on HD-2, which is
deliberately unratified." The same commit says the opposite in three places: the file sets no
`driver`; `mission-bootstrap.md:256-259` says "Superseded 2026-09-06 (the de-fork)"; and
`mission-control.sh:1143-1146` says "after world was de-forked it runs this shared driver".
The file whose job is to hold rationale is itself out of date.

---

## 2. The iteration lifecycle as code

There are two lifecycles. Keep them apart.

### 2a. Live path: bash driver plus heartbeat file

**[O] State and where it lives** (all under `~/.ailang/state/`, namespaced
`mission-<name>-*`, with legacy un-namespaced names for v1; `mission-control.sh:83-116`):

- `mission-<name>.pid`: overlap guard. Written per attempt after the controller starts (`:2302`),
  removed at the end (`:2452`).
- `mission-<name>.disabled`: kill switch (`:88`, `:106`).
- `mission-<name>-heartbeat`: TSV, `epoch, iso, label, attempt, note`. The driver truncates it with
  a `fired` row at each attempt (`:2249`); the agent appends one row per gate through
  `tools/launchd/mission-heartbeat.sh:28`. Legal labels are a closed set:
  `fired|gate-0|gate-1|gate-2|gate-3|gate-3b|gate-4|gate-5|complete|abort`
  (`mission-heartbeat.sh:11-14`); any other label exits 2.
- `mission-<name>-slot-verdicts.log`: one line per slot, capped at 200 lines (`:2446-2449`).
- Episode markers that de-duplicate notices: `.blocked` (`:1989-1992`), `-rcfail.episode`
  (`:2494-2498`), `-reaped.episode` (`:2457-2459`), `-lane-degraded.episode` (`:2073-2081`),
  `-driver-pin.episode` (`:2106-2111`).
- `mission-<name>-gh-issue`: the current bookkeeping issue number (`:1122`).
- `mission-lane-dead/<MISSION_FIRE_ID>.tsv`: per-fire dead-lane ledger
  (`tools/launchd/mission-lane-dead.sh:13`, `:33-37`).
- `mission-<name>-base`: recorded base SHA rows (`tools/launchd/mission-base.sh:9`, `:32`).

**[O] Slot verdicts** are computed from exit code and the last heartbeat label
(`mission-control.sh:2429-2441`): `COMPLETED` (rc 0, last `complete`), `ABORTED` (rc 0, `abort`),
`DIED-PRE-GATE-0` (rc 0, `fired` or empty), `REAPED at=gate-N` (rc 0, a gate label),
`KILLED at=` (rc 143/137), `CRASHED at=` (any other), `PAUSED-NO-CAPACITY` (`:2439`),
`HEARTBEAT-MISSING` (`:2441`).

**[O] Attempts.** Up to 3 attempts per fire on a transient-error signature, with 45s x attempt
backoff (`:1084-1086`, `:2395-2412`). Watchdog kills are never retried (`:2371`). A runtime quota
signature demotes the rung and re-walks the ladder, at most 4 times (`:1078-1082`, `:2374-2384`),
then pauses (`:2385-2393`).

**[I] What survives a crash on the live path.** The heartbeat rows, the slot-verdict line (only if
the driver itself survives to write it), the pidfile (stale, removed by the next fire at `:1897`),
git state (branches, worktrees, PRs, uncommitted files), and whatever the agent already wrote to
the charter and log. There is no record of which queue item was picked. Reconstruction is the next
agent's job, by prose (section 7).

### 2b. Durable path: `ailang mission iterate` over SQLite

**[O] Input.** A strict v1 JSON work item (`internal/mission/iteration/spec.go:62-77`): mission
and work item ids, repository origin, full base commit, brief, `allowed_paths`, workflow `full-v1`,
1 to 4 stages in the fixed order designer, planner, executor, evaluator (`:118-121`, `:157-158`),
up to 3 prerequisites standing in for earlier roles (`:112`, `:122-150`), up to 32 verification
commands as argv (`:181-201`), limits, acceptance criteria (`:202-211`). Decoding rejects duplicate
keys, unknown fields and missing required fields (`iteration/spec_decode.go:13-35`, `:72-96`).
Iteration timeout at most 7200s, stage at most 1800s (`spec.go:109`, `:163`).

**[O] Placement.** `~/.config/ailang/mission-runtime.toml` with exactly `version = 1`, `state_db`,
`workspace_root`; unknown keys are an error (`iteration/binding.go:14-49`).

**[O] Tables** (`internal/coordinator/mission_work_item.go:69-80`,
`mission_attempt.go:49-55`, `mission_work_item_attestation.go:38`):

- `mission_work_items`: key (mission, work item); `spec_json`, `spec_digest`, `stage_ids`, `state`,
  `reason_code`, `next_action`, `owner_token`, `lease_until`, `version`, `deadline`, `next_stage`.
- `mission_admissions`: primary key `mission_id`. One admitted work item per mission.
- `mission_stage_deadlines`, `mission_work_children`, `mission_stage_acceptances`.
- `mission_attempts`: key (mission, work item, stage); `attempt_id`, `request_digest`,
  `request_json`, `state`, `owner_token`, `lease_until`, `version`, `outcome`, `outcome_digest`.
- `mission_stop_attestations`: created lazily.

**[O] Work item states.**

| State | Set by |
|---|---|
| `ready` | default (`mission_work_item.go:71`); after a stage is accepted (`mission_work_item_child.go:136`) |
| `running` | `StartMissionChild` (`mission_work_item_child.go:73`) |
| `validating` | `MarkMissionWorkItemValidating` (`mission_work_item.go:194`) |
| `waiting` | `workWait` (`mission_work_item.go:187`); reasons `quota`, `availability`, `decision` |
| `completed`, `failed` | `FinishMissionWorkItem` (`mission_work_item_finish.go:9-35`); `failed` with `deadline_exceeded` (`mission_work_item_expire.go:47`) |
| `cancelled` | `CancelMissionWorkItem`, reason `operator_cancelled` (`mission_work_item_finish.go:48`) |
| `needs_reconciliation` | reason `outcome_unknown`, next `reconcile_child` (`mission_work_item_finish.go:89`); or next `confirm_process_stopped` after cancel or expiry with a live child (`:59`, `mission_work_item_expire.go:58`) |

**[O] Attempt (stage child) states.** `prepared` (`mission_attempt.go:109`), `running` (`:159`),
`execution_completed` / `execution_failed` (`:177`), `cancelled` (`:197`),
`needs_reconciliation` (`:200`).

**[O] Fencing.** Every transition checks an owner token and an unexpired lease (`workFence`,
`mission_work_item.go:115-122`). The parent lease is 30s renewed every 5s
(`iteration/runtime.go:142`, `:156`, `:166`); the child the same
(`iteration/runtime_stage.go:313`, `:322`, `:331`). Losing the lease cancels the run context
(`runtime.go:168-171`). Time comes from the database (`mission_attempt.go:46`).

**[O] One stage, step by step** (`runtime.go:203-315`, `runtime_stage.go:274-414`): begin stage
deadline, build or reload the request, ensure a detached git worktree at the frozen base, preflight
(model resolve plus quota admission), `ClaimMissionChild` (`prepared`), journal `dispatching` and
`StartMissionChild` (`running`), execute, `CompleteMissionAttempt`, `validating`,
`ValidateArtifacts` plus frozen verification commands in a separate worktree
(`iteration/verify.go:33-125`), usage caps (`runtime.go:356-379`), `AcceptMissionStage`
(`next_stage+1`, back to `ready`), and finally `completed`.

**[O] What survives a crash, and what resume does.**

- The frozen input: `Snapshot` holds spec, the full model registry, repository path and workspace
  root (`runtime.go:21-28`). Resume refuses a changed spec ("work item input changed; use reviewed
  successor", `runtime.go:105-107`) or changed placement (`:120-122`).
- The exact request per stage. "Existing attempt requests are immutable; do not rebuild packets on
  recovery" (`runtime_stage.go:31-43`).
- Stage deadlines. "Resume returns the first deadline, even after quota waiting"
  (`mission_work_item_stage.go:9-10`, `:25`).
- Accepted stages with digests; budget is recomputed from them (`runtime_stage.go:56-81`).
- The receipt journal, `receipts/<stage>-<32 hex>.jsonl`, created `O_EXCL` mode 0600 and fsynced
  per event (`dispatch/receipt.go:24-63`).
- Evidence files named by content digest, `O_EXCL` (`runtime.go:322-348`).
- Stage worktrees. A dirty unstarted workspace is refused: "preserve and inspect"
  (`runtime_stage.go:133-135`).
- A new owner may claim only when the old lease has expired, the state is not terminal, and the
  snapshot is byte-identical (`mission_work_item.go:156-159`).
- On resume the child's state decides (`runtime.go:236-258`): `prepared` re-executes;
  `execution_completed` goes to validation without re-dispatch; `execution_failed` fails the item;
  `running`, `needs_reconciliation` or `cancelled` calls `ReconcileMissionWorkItem`. "Running work
  never retries" (`mission_attempt.go:93-94`).
- Crash fixtures hook five checkpoints: `prepared`, `dispatching`, `receipt_finished`,
  `execution_completed`, `accepted` (`runtime_stage.go:317`, `:352`, `:367`, `:371`;
  `runtime.go:312`).
- Stated limit: "Tests cover abrupt process exit and database reopening; they do not establish
  power-loss durability, exactly-once external effects" (`mission-role-dispatch.md:143-145`).
  "Receipt and SQLite writes are separate; a crash or disk error can leave one ahead of the other"
  (`:142-143`).

**[I] Design and plan stages always stop for a human.** For designer and planner the produced
artifact's SHA-256 must already appear in the stage's frozen `authority_refs`; otherwise the item
goes to `waiting/decision` with "review produced artifact and supply approved prerequisite in a
successor work item" (`runtime.go:284-300`). The digest of a not-yet-written artifact cannot be
known when the spec is frozen, so a fresh design or plan cannot auto-advance. Evaluator-only and
executor-onward items can.

**[O] `status`** (`cmd/ailang/mission_iteration_cmd_status.go:18-34`, `:60-150`): read-only open,
no migration (`internal/coordinator/mission_work_item_readonly.go:10-22`). Returns phase, reason,
next action, a typed diagnostic (`completed`, `ambiguous_execution`, `in_progress`, `ready`,
`decision`, `admission`, `cancelled`, `deadline`, `verification`, `budget`, `provider_failure`,
`unknown`; `:160-211`), stage, version, lease, deadline, accepted evidence, routes. The diagnostic
"deliberately excludes provider text ... unknown causes are never guessed from stderr substrings"
(`:152-153`).

**[O] Status progress** (`cmd/ailang/mission_iteration_status_progress.go:17-129`): scans the
receipts directory, at most 128 entries, 4 MiB per file, 16 MiB total; accepts only `progress`
events bound to the frozen request digest; a last line without a newline is "incomplete"
(`:83-86`); two journals with progress for one request is "unavailable" (`:116-118`). Progress is
tool-call counts and exact repeats only (`dispatch/progress.go:15-25`).

**[O] `cancel`** needs the version from a fresh status (`mission_iteration_cmd.go:172-189`). If a
child was running, the item becomes `needs_reconciliation` and keeps mission admission
(`mission_work_item_finish.go:51-63`).

**[O] `confirm-stopped`** (`cmd/ailang/mission_confirm_stopped.go:21-91`): only for
`needs_reconciliation` with reason `operator_cancelled` or `deadline_exceeded` (`:74`); requires
`--version` and a 1 to 2048 byte `--attestation`; stores the attestation with the exact child
attempt ids and versions in the same transaction
(`mission_work_item_attestation.go:29-75`); final state is `failed` (deadline) or `cancelled`
(`mission_work_item_finish.go:94-104`). "The command does not stop a process itself"
(`mission-iteration.md:163`). Generic `outcome_unknown` is rejected: "generic ambiguity cannot be
cleared by confirm-stopped" (`mission_iteration_cmd_status.go:168`).
**[I]** The only code path out of `outcome_unknown` that I can see is `cancel` (which rewrites the
reason to `operator_cancelled`, `mission_work_item_finish.go:48-60`) followed by `confirm-stopped`.

**[O] `retry-review`** (`iteration/retry_review.go:42-150`): prepare-only. Requires a terminal
`failed` or `cancelled` parent (`:55`), a fresh successor id (`:58-60`), and no `prepared`,
`running` or `needs_reconciliation` child (`:69-71`). It turns accepted author stages into
prerequisites and emits a spec, `.manifest.json` and `.models.yml`; without authority the draft is
non-executable (`:18-19`, `:34-40`). "It never claims an item or contacts a provider" (`:42`).

**[O] Role state (legacy single stage).** `ailang mission role-run --state-db` goes through
`iteration.RunRoleWithHeartbeat` (`iteration/role.go:17-100`; `cmd/ailang/mission_role_state.go:11-16`),
a 30s lease renewed every 10s. `ClaimMissionAttempt` refuses when the mission has any admitted
work item (`mission_attempt.go:107-109`), so the two modes cannot share a mission.
`ailang mission attempt status|reconcile|cancel` (`cmd/ailang/mission_attempt_cmd.go:21-83`);
`reconcile` sweeps expired `running` attempts to `needs_reconciliation`
(`mission_attempt.go:199-205`).

**[O] Ticket.** A harness defect report, not an iteration state
(`internal/mission/ticket.go:47-57`): mission, iteration, fire time, signature, slot verdict,
blocking (`none|item|all`), evidence capped at 2,048 bytes (`:34`, `:70-72`), workaround. Stored as
a message in the `mission-fleet` inbox (`:21`, `cmd/ailang/mission_ticket.go:116-124`). "Open"
means unread (`mission_ticket.go:9-11`). Filing is idempotent by title (`:125-135`). The fleet
mission may not file (`ticket.go:80-81`). Grouping ranks by `slots_lost`, then oldest first
(`ticket.go:138-181`). `resolve` replies to each filing mission before marking read, so "a crash
between the two leaves the ticket open" (`mission_ticket.go:229-230`).

**[O] Exit codes** (`mission_iteration_cmd.go:249-273`): 0 completed, 2 invalid, 3 waiting or
conflict, 4 reconciliation, 5 failure, 130 cancelled.

---

## 3. Which markdown is parsed by code

**[O] The charter (`<name>-mission.md`) is not parsed by any Go code.** In the on-disk Go, shell
and Python, the only consumers of charter content are two awk scripts (decision ledger) and one
Python report (heuristics). The queue tags `[NEXT] [IN-SPRINT] [PARKED] [LANDED] [RULED OUT]`
(`design_docs/mission-charter-TEMPLATE.md:107`), the Repo Profile, the bar and the STATUS stamps
that live in the charter are read only by the model. The log is parsed by Go (rotation,
normalisation), by the driver (one grep), and by the Python report.

### Format contracts

| # | Contract | Depends on it | When the markdown does not match |
|---|---|---|---|
| 1 | Markers `<!-- decision-ledger:start -->` and `<!-- decision-ledger:end -->`, exactly one pair | `scripts/mission_decisions.sh:16-17`, `:32-34`; `scripts/mission_answer.sh:124-125` | `--check` prints "expected exactly one decision-ledger block (start=%d end=%d)", exit 1. `mission_answer.sh` finds no row, exit 1, file untouched. |
| 2 | Ledger row: line starting `| D-`, cells ID, Status, Decision, Evidence; status `OPEN` or `RESOLVED`; both text cells non-empty; unique IDs; at least one row | `mission_decisions.sh:18-27`, `:35` | "duplicate decision ID", "invalid status", "empty decision/evidence field", "decision ledger has no rows"; exit 1. |
| 3 | The same row must split into exactly 6 pipe fields after `\|` is protected, and must be `OPEN` | `mission_answer.sh:127-139` | "row %s has %d fields, expected 6 — refusing to edit a row I cannot parse" or "is %s, not OPEN — refusing"; the edit is built in a temp file and never copied (`:157-159`). After a successful edit the whole ledger is re-validated and a failure tells the user to `git checkout` (`:172-174`). |
| 4 | Log entry heading `## [Iteration ]N[ & M] — YYYY-MM-DD[Thh:mmZ][/dd][ — title]` | `entryHeadingRe`, `internal/mission/rotate.go:44-45`; `parseLog` `:78-136` | see below |
| 5 | STATUS stamp `## STATUS YYYY-MM-DD[ (qualifier)] — ITERATION N[ WORD][:] headline` | `statusHeadingRe`, `rotate.go:57-58` | see below |
| 6 | STATUS note with no iteration number `## STATUS YYYY-MM-DD — text` | `statusNoteRe`, `rotate.go:63` | indexed with `—` as the number (`rotate.go:160-163`) |
| 7 | Upper-case note heading `## WORDS — YYYY-MM-DD ...` | `noteHeadingRe`, `rotate.go:67`; honoured only after the first entry (`:121`) | before the first entry it is preamble |
| 8 | Any other `## ` heading at or after the first entry | `strayHeadings`, `rotate.go:318-339` | whole rotation refused (`:197-202`) |
| 9 | Canonical shapes `## N — YYYY-MM-DD[ — title]` and `## STATUS YYYY-MM-DD — ITERATION N: headline` | `canonicalEntryRe`, `canonicalStatusRe`, `internal/mission/normalize.go:34`, `:37`; variants `wordyEntryRe` `:45-46`, `statusVariantRe` `:50-51`, `statusParenIterRe` `:61-62`; `normalizeHeading` `:84-130` | a record-looking heading that cannot be converted is reported as `UNCONVERTIBLE line N (reported, never guessed at)` (`normalize.go:161-163`, `cmd/ailang/mission_cmd.go:464-466`) and left alone |
| 10 | File names `design_docs/<name>-mission-log.md`, `-log-archive.md`, `-status-archive.md`, `-status-archive-old.md`, `-index.md`, `-status-index.md` | `mission_cmd.go:361-366`, `:402-409`; `rotate.go:204-215` | missing log: read error; `normalize` skips missing files (`mission_cmd.go:443-445`) |
| 11 | The last `## ` heading of `${MISSION_DOC%.md}-log.md` changes when an iteration records itself | `tools/launchd/mission-control.sh:2359-2360`, `:2472-2473` | unchanged heading plus rc != 0 is reported as "FAILED to complete ... The queue is untouched" (`:2503`); changed heading is reported as "late kill, work landed" (`:2476-2482`) |
| 12 | Log body fields `**Ruled out**`, `**Next**`, `**Progress**`; headline tags `[PRODUCT]`, `[HARNESS]`, `[ADMIN]`, `[REFUTATION]` | `tools/mission-weekly-report.py:36`, `:41-42`, `:121-123`; `parse_log` `:60-74`, `goal_distance` `:126-140`, `class_mix` `:143-156` | fail-soft: `None`, 0, `untagged`, `n/a`. "untagged counts stay visible rather than being folded away" (`:146-148`) |
| 13 | Charter `## Queue` heading, list rows carrying `[PARKED`, strike-through `~~` | `roadmap`, `mission-weekly-report.py:218-227` | count is 0 |
| 14 | Charter rows carrying `needs-human-review`, `DECISION D-n`, `awaiting Mark`, `PARKED ... human` and not `RESOLVED`, `LANDED`, `~~` etc. | `open_decisions`, `mission-weekly-report.py:77-118` | "Under-reporting is the intended failure mode" (`:85-86`) |
| 15 | Doc text containing "conflict surface", "high-stakes", "shared infra", "touches shared" | `DocSelfDeclaresHighStakes`, `internal/mission/quorum/escalate.go:139-155` | no Tier-2 trigger; but see section 5, this function has no production caller on disk |
| 16 | Env file assignment lines `K=v`, `export K=v`, `K="${K:-v}"` | `assignmentKey`, `internal/mission/render.go:49-66`; `changedKeys`, `doctor.go:328-358` | a non-matching line is passthrough |
| 17 | Issue comments: author login in the allowlist, `createdAt > since` | `scripts/mission_directives.sh:84-93` | filtered out as "public feedback, never directives" (`:103`) |

**[O] Contract 4 to 8 in detail: what `parseLog` does with a heading it does not recognise.**

- Zero recognised entries: "no iteration entries found (expected headings like '## 337 — 2026-09-06 — ...')" (`rotate.go:183-185`).
- An unrecognised `## ` heading before the first entry: silently part of the preamble, kept
  verbatim (`rotate.go:128-131`, `:315-317`).
- An unrecognised `## ` heading after the first entry: rotation refuses, naming the first one.
  "the tool cannot tell a record from structure, and guessing wrong silently relocates live
  reference material" (`rotate.go:195-196`).
- The parser does not know about code fences. **[I]** A fenced `## ` line after the first entry
  would count as stray.
- Why the pattern is loose: "under-matching here does not fail loudly — it produces a short index,
  and an index that quietly omits iterations is exactly what lets the loop repeat work"
  (`rotate.go:41-43`).

**[O] Evidence that the mismatch path is live at this commit.**

- `design_docs/docs-mission-log.md:288` is
  `## ITERATION 3 — died mid-flight, credited retroactively by iteration 4 (2026-09-02)`.
  `normalize.go:19` names that exact shape as the one outlier ("date not even in position").
- `design_docs/docs-mission-index.md` is not generator output. Its header reads "refreshed as
  explicit Gate4 bookkeeping because rotate-log refuses the existing STATUS archive structural
  header", and its rows carry the whole raw heading (`| 17 | 2026-10-01 | ## 17 — 2026-10-01 — ...`),
  a shape `indexLine` never emits (`rotate.go:149-165`).
- `design_docs/motoko-mission-index.md:13-17` carries a hand-written note that ends: "`rotate-log`
  cannot regenerate this index for motoko today (queue row 19), so the next regeneration may drop
  it."
- **[I]** I replayed the four regexes in Python over the files on disk (an approximation of Go's
  engine, not a run of the binary). Result: `docs-mission-log.md` has 1 stray heading (line 288);
  `docs-mission-status-archive.md` has 1 (`## (Charter sections — moved back 2026-10-01)`, line
  463); `motoko-mission-status-archive.md` has 11; `motoko-mission-log.md` has 0 entries (it was
  reset on 2026-09-30). So at this commit `rotate-log` would refuse or error for docs and motoko
  and work for v1 and fleet. Two of four in-repo missions have fallen back to hand-maintained
  indexes.

**[I] A weaker spot in contract 2.** `mission_decisions.sh:14` splits on raw `|` and does not
protect `\|`, while `mission_answer.sh:117-119`, `:129` does. A decision cell containing `\|`
shifts the fields, so `--open` prints a truncated answer and the empty-evidence check looks at the
wrong cell.

**[O] Nothing automated runs `--check`.** The only non-prose callers are `mission_answer.sh:172-173`
and a test (`tools/launchd/test_mission_routing.sh:319-321`, against the v1 charter; whether CI runs that
test was not checked, `.github` is not on disk). The driver never calls it. The skill tells the agent to (`.claude/skills/mission-control/resources/gate-0-preflight.md:146-149`).

---

## 4. `rotate-log`

**[O] Command.** `ailang mission rotate-log <name> [--keep N] [--status]`, default keep 20
(`cmd/ailang/mission_cmd.go:311-337`). `--status` rotates `<name>-mission-status-archive.md`
instead of the log (`:362-367`).

**[O] Where.** For a mission on `sunholo-data/ailang` it rotates the file in the checkout that
holds the registry, not in the mission's clone. "Writing a rotated log there would be thrown away by
the next fetch, silently. Caught by doing exactly that to motoko's clone"
(`mission_cmd.go:346-360`).

**[O] What it does** (`internal/mission/rotate.go:174-313`), in this order:

1. Parse the file into preamble plus entries. Refuse on zero entries or stray headings.
2. Derive paths (`:204-215`): archive `<stem>-archive.md`; for a status archive, `<stem>-old.md`.
   Index `<stem minus "-log">-index.md`; for status, `<name>-mission-status-index.md`.
3. Read entries already in the archive (`:219-222`).
4. Sort live entries by number ascending, keep the last `keep`, archive the rest (`:224-229`).
5. Archive: append the full bodies to the existing archive, or create it with a three-line header
   (`:237-255`).
6. Live log: rewrite as preamble, a four-line "Older entries are ARCHIVED" notice, then the kept
   entries (`:257-270`).
7. Index: regenerate from scratch from archive plus live entries, newest first, de-duplicated by
   number (notes by date and title), one row `| # | date | title |` (`:273-311`). Titles are cut to
   150 runes and `|` is escaped (`:149-165`).

Each file is written by temp file, fsync, rename (`render.go:307-339`).

**[O] Rules stated in the code.**

- Three tiers: "live log — last N full entries ... archive — every older full entry ... INDEX —
  one line per iteration, ALL" (`rotate.go:20-29`).
- The index is never appended to: "an append-only index drifts the moment an entry is edited or a
  rotation is re-run, and a drifted 'what have we already done' index is worse than none"
  (`rotate.go:170-173`).
- A combined entry keeps both numbers in the title (`:95-103`).
- Truncate by runes: "the first real run produced an index that was not valid UTF-8 because a dash
  was cut in half" (`:153-156`).

**[O] When it runs is prose.** "ROTATE THE LOG WHEN IT PASSES ~40 ENTRIES ... `ailang mission
rotate-log ${MISSION_NAME} --keep 20`" (`.claude/skills/mission-control/resources/gate-4-record.md:30-33`).
No script, plist or hook on disk calls `rotate-log` or `mission normalize`.

**[O] It is not idempotent on the live log.** The notice in step 6 is appended after a preamble
that already contains the previous notice. `design_docs/v1-mission-log.md` carries 8 copies of the
"Older entries are ARCHIVED" block (lines 24 onward) and `fleet-mission-log.md` carries 7.

**[I] Other edges.**

- The three writes are individually atomic but not as a group. A crash after the archive write and
  before the log write leaves the rotated entries in both files; a re-run would append them to the
  archive again. The index de-duplicates by number, the archive does not.
- Notes have number -1 and sort to the front in step 4 (`:224`), so a dated note is archived
  before any numbered entry regardless of its date.
- Regeneration discards anything hand-added to an index file, which is what the motoko note warns
  about.
- The index header text hard-codes "the log (2.8 MB, ~715k tokens)" for every mission
  (`rotate.go:300`), including a 31-line fleet index.

---

## 5. The design quorum

**[O] How many.** Three seats per doc by default (`internal/mission/quorum/seating.go:26`), drawn
from a pool of five, one per vendor: `gpt6-1-sol,gemini-3-1-pro,oc-glm-5-3,oc-kimi-k3,claude-sonnet-5@claude-p`
(`cmd/ailang/design_quorum.go:183`). Plus the controller's own in-session verdict, passed as flags:
"NOT an API call" (`quorum/quorum.go:20-27`, `design_quorum.go:55-67`).

**[O] Seating** (`seating.go:67-106`): the author's vendor is benched; the rest of the pool is
rotated by an FNV hash of the doc path, so "a revised doc's second round is judged by the same seats
that blocked the first" (`seating.go:13-17`); distinct vendors are preferred; an absent seat is
replaced from the reserve; the benched vendor is recalled only if nobody answered, labelled
`author-vendor-fallback` (`seating.go:108-130`). With no `--author`, a Claude author is assumed
(`design_quorum.go:75-80`).

**[O] A verdict.** JSON with four required string fields (`quorum/reviewer.go:85-94`): `verdict`
(`pass` or `reject`), `strongest_objection`, `catch`, `proposed_fix`. `strongest_objection` and
`catch` must be non-empty even on a pass (`reviewer.go:151-164`). The system prompt opens "Your job
is to REJECT by default" and scores premise verification, conflict surface and axiom compliance
(`reviewer.go:101-114`). A malformed reply makes the reviewer absent with reason `invalid`, never a
pass (`quorum/run.go:159-175`).

**[O] Synthesis** (`quorum.go:141-183`): any present reject, or a controller reject, gives
`blocked`; all present pass gives `proceed`; nobody present gives `blocked` with "refusing to
proceed on zero signal". Absent reviewers are listed with a reason out of `unreachable`, `budget`,
`auth`, `unknown-model`, `invalid` (`run.go:93-99`), `quota` (`quorum/claude_reviewer.go:34`). The
process exits 0 for proceed and 3 for blocked (`design_quorum.go:130-134`).

**[O] Outputs.** A JSON artifact at `.ailang/state/mission-quorum/<slug>-<iso>.json`, created
`O_EXCL` with a numeric suffix on collision (`quorum/artifact.go:14`, `:40-77`); optionally a
markdown block appended to the mission log, headed `#### Design-quorum review`
(`artifact.go:82-143`). **[I]** Four hashes, so it never trips the `## ` stray-heading rule.

**[O] When it is required: prose.** "QUORUM-AT-PICK ... if the picked doc has NO quorum artifact
(`ls .ailang/state/mission-quorum/<doc-id>-*.json`), run the text quorum BEFORE routing"; skip only
for "bookkeeping-only picks, ghost-closes, and mission-infra docs the quorum already reviewed"
(`.claude/skills/mission-control/resources/gate-2-pick.md:135-144`). Also charter ratification at
iteration 0 (`docs/docs/guides/mission-bootstrap.md:324-326`). Neither the driver nor the durable
runtime calls it; `iteration` gates design and plan on human authority refs instead
(`iteration/runtime.go:284-300`).

**[O] Disagreement.** There is no vote. One reject blocks. What follows is prose: "Any-reject → the
objections go to the designer role for a revision pass first ..., then re-quorum ONCE;
still-rejected → `needs-human-review`, park, next item" (`gate-2-pick.md:140-142`). A carve-out
allows a bounded second revision that applies the reviewers' verbatim `proposed_fix` when no
objection disputes the design direction (`gate-2-pick.md:145-158`).

**[O] Tier 2 exists but is not wired.** `ShouldEscalate` fires on a premise-class objection, a
self-declared high-stakes doc, or a split (`quorum/escalate.go:76-106`), and `RunTier2` runs agentic
reviewers on read-only worktrees (`quorum/tier2.go:43-62`). The CLI calls `RunSeatedQuorum`
(`design_quorum.go:89`); `RunQuorumWithEscalation` (`quorum.go:109-130`) has no non-test caller in
the on-disk Go.

**[O] Cost.** Per-reviewer cap `DefaultMaxCostUSD = 0.30` (`run.go:20`). A pre-flight estimate
(prompt chars / 4, plus 1,024 output tokens) refuses before spending (`run.go:27-43`, `:136-144`);
actual cost is tokens times registry pricing (`run.go:156-157`). The Anthropic seat runs
`claude -p` on the subscription with a 5 minute timeout (`claude_reviewer.go:3-6`, `:36-38`) and is
absent when the Anthropic bucket is over its ration (`design_quorum.go:192-198`). The skill
describes the quorum as "cents, budget-capped" (`gate-2-pick.md:140`) and records a single
re-run at "$0.08" (`gate-2-pick.md:178`). **[I]** Three metered seats give a default ceiling of
$0.90 per round before reserve replacements.

**[O] Two known holes, both documented in the skill rather than fixed in code.**

- A `proceed` at N-1 looks like a `proceed`. "A reviewer drops out on `budget` when the DOC GREW —
  i.e. immediately after a substantial revision, which is exactly when its opinion is most
  load-bearing" (`gate-2-pick.md:173-175`). The rule: read `.synthesis.absent_reviewers` before
  acting (`:184-189`).
- The controller satisfies the zero-signal guard. `presentCount++` for the controller is still at
  `quorum.go:164-165` and the guard tests the same counter (`:176`). The skill:
  "V1's artifacts carry three syntheses reading `proceed` with **zero of two** model reviewers
  present ... Filed as `#651` for the code fix; until it lands, the count that matters is
  **present EXTERNAL reviewers**" (`gate-2-pick.md:228-238`).

---

## 6. Scheduling and guards

Order inside one fire, from the driver:

1. **[O] Billing guard.** `unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN OPENAI_API_KEY`
   (`mission-control.sh:158`). "Subscription-or-nothing by construction" (`:150-153`).
2. **[O] Driver pin.** Re-exec from a worktree pinned to committed `origin/dev`
   (`:1126-1160`). A failed pin is loud, not fatal (`:1164-1169`).
3. **[O] Kill switch.** `[ -f "$KILL_SWITCH" ]` then exit 0 (`:1609-1611`). It must sit above the
   probes (`:1603-1608`). Arming is `tools/launchd/mission-arm.sh`: it runs the lane check and
   removes the switch only on READY, keeping the pause note as `.released-<stamp>`; `--force`
   needs `--reason` (`mission-arm.sh:2-10`, `:30-43`). Bootstrap sets the switch before loading a
   plist because `RunAtLoad` fires immediately (`mission-bootstrap.md:281-286`).
4. **[O] Fleet idle pre-check.** The fleet mission exits before any probe when no ticket is open;
   an unreadable count yields: "a failed read is neither zero nor work" (`:1619-1631`).
5. **[O] Role lane probes and the ration gate.** `ailang mission quota --over` once per fire,
   bounded at 60s (`tools/launchd/lib/lane-probe.sh:156-200`). A failed quota command blocks Codex
   and Ollama Cloud (fail closed). Pace rules: Codex and Anthropic at 20% of the weekly bucket per
   weekday, "nothing on Saturday or Sunday" (`internal/mission/quota_ledger.go:47-61`); other
   buckets 10% per day (`:39-45`); the ration paces the long window only (`:100-110`). Accounting
   is fleet-wide because the bucket is ("four missions drawing on one subscription", `:19-22`).
6. **[O] Overlap guard.** Pidfile plus `kill -0`; a live pid means "yield (next interval
   retries)"; a stale pidfile is deleted (`:1892-1898`). It replaced a `pgrep` that matched a
   human's monitoring shell (`:1887-1891`). The pidfile is written only after the probes, so a
   probing fire is invisible to it (`tools/launchd/mission-recovery.sh:50-54`).
7. **[O] Dry run.** `MISSION_DRY_RUN=1` logs the resolved wiring and exits (`:1908-1915`).
8. **[O] Boot stagger.** Only inside the first 900s after boot, sleep the mission's offset
   (`:1924-1932`); offsets are 420s apart (`:690-700`). Steady-state separation comes from
   non-harmonic intervals (`:644-646`, `missions/motoko.toml:10-13`).
9. **[O] Memory gate.** Needs at least 16 GB available and at most 48 GB compressed; polls every
   60s for up to 600s, then yields; fails open, loudly, if `vm_stat` is absent (`:1939-1964`).
   "Thresholds are STARTING VALUES, not measured ones" (`:735-738`).
10. **[O] Binary iteration hand-off**, if `AILANG_MISSION_WORK_ITEM` is set (`:1969-1978`).
11. **[O] Controller selection.** Env pin, override file with expiry, then the ordered ladder
    `claude-opus-5-5,codex:gpt-6.1-sol` and the fallback chain
    `pi:ollama/glm-5.3:cloud,pi:openrouter/z-ai/glm-5.3`, each rung probe-gated and ration-gated
    (`:846`, `:869`, `:926-1040`). No usable rung: refuse, announce once per episode via the
    `.blocked` marker, exit 1 (`:1982-2005`).
12. **[O] Scope guard.** A per-fire `core.hooksPath` installs a pre-push hook
    (`:2186-2194`): product loops may not push harness paths, the fleet loop may not push
    language-core paths (`tools/launchd/githooks/pre-push:14-63`).
13. **[O] Watchdogs.** Hard timeout 6h (`:1043`, `:2305-2313`). Stall watchdog: 40 min grace, then
    5 consecutive 2-minute samples with no transcript or file growth, no heartbeat change, less
    than 10 CPU-seconds of descendant rusage growth ("below 10 CPU-s", `:555`; `-ge 1000` cs, `:628`) and under 2% CPU, with a descendant alive at
    least 40 min (`:1050-1057`, `:562-638`, `:2321-2334`). It fails open without a progress
    instrument (`:560-561`, `:572-579`).

**[O] launchd side.** `RunAtLoad` on every mission plist so a reboot restores the cadence
(`render.go:273-275`). `StartInterval` re-arms from exit, `KeepAlive` + `ThrottleInterval` from
start (`registry.go:25-35`). `tools/launchd/cron-kicker.sh:1-20` exists because launchd's GUI
domain stopped spawning interval jobs for about 31 hours.

**[O] Activation binding** (durable path only).
`ailang mission activation run docs --operation OP --work-item FILE --binding FILE`
(`cmd/ailang/mission_activation.go:54-61`). The manager records ownership first, then installs the
docs kill-switch marker, re-verifies the legacy driver is idle, and only then installs the
temporary `mission-runtime.toml` (`internal/mission/activation/activation.go:68-156`). It refuses
if a foreign disable marker already exists (`:92-94`). Phases: `prepared`, `active`, `restoring`,
`restored`, plus a `cleanup_pending` reason. One host-wide owner pointer file, `active` (`:125`).
The retained record is how `status --activation OP` reads the canary's database after the binding
is restored (`cmd/ailang/mission_activation_binding.go:25-51`).

**[O] Durable-path guards.** One admitted item per mission (`mission_admissions`,
`mission_work_item.go:75`, `:153`). Quota admission is mandatory at preflight and at dispatch
(`internal/mission/dispatch/admission.go:10-59`; `internal/mission/admission.go:38-98`). Ambient
API keys refuse the subscription routes (`mission-role-dispatch.md:72-73`). Stage limits cannot
exceed iteration limits (`spec.go:166-168`); the remaining budget carries across stages
(`runtime_stage.go:72-81`, `:100-106`).

---

## 7. Recovery of a dead or orphaned iteration

**[O] Detection, in code (live path).**

- Slot verdict from rc and last heartbeat label (`mission-control.sh:2416-2450`). `REAPED`,
  `DIED-PRE-GATE-0` and `HEARTBEAT-MISSING` notify once per episode on the message bus and the
  bookkeeping issue (`:2454-2469`).
- rc != 0: compare the log's last `## ` heading before and after. Changed: "late kill, work landed"
  (`:2471-2482`). Unchanged: "FAILED to complete ... The queue is untouched; the next interval will
  retry", posted once per rc value (`:2487-2504`).
- A background-task ceiling used to end slots with rc=0 and no work; the driver now sets
  `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` (`:2041-2055`).
- `tools/launchd/mission-recovery.sh` polls every 240s
  (`tools/launchd/dev.ailang.mission-recovery.plist:41-42`) and kickstarts the mission only when
  its `.blocked` marker exists, the kill switch is absent, no pid is alive and 20 min have passed
  since the last kick (`mission-recovery.sh:59-98`). It handles "no usable model", not crashes.
  Only v1 and motoko have a recovery plist on disk.

**[O] The driver neither credits nor discards work.** It labels the slot. Everything after that is
prose, in `.claude/skills/mission-control/resources/gate-2-pick.md:303-360`:

- Why: iteration 148 "had completed the ENTIRE inner loop ... opened PR **#600**, watched it go
  green and MERGEABLE, then died before Gate 3b. It left **zero** charter rows, **zero** log
  entries and **zero** STATUS stamps" (`:311-315`).
- What to look for at pick time: (a) open PRs authored by the bot account, (b) stale sprint
  worktrees, (c) uncommitted state in the stale worktree and in the main checkout (`:318-345`).
- What to do: "the iteration's deliverable is to VERIFY AND LAND it, not to redo it" (`:326-327`);
  one inherited milestone "had **2 of its 9 tests RED as delivered**" (`:349-350`).
- Crediting: "**record the orphaned iteration inside your own log entry and credit it** —
  otherwise the log silently skips a number" (`:354-356`).

Examples in the data: `design_docs/docs-mission-log.md:183`
(`## 2 — 2026-08-31 — recovering a died-mid-flight prior fire`) and `:288`
(`## ITERATION 3 — died mid-flight, credited retroactively by iteration 4 (2026-09-02)`). The index
parser has a case for a combined dead entry, `## 321 & 322 — ... — NO ENTRY: both slots died
mid-flight` (`rotate.go:95-103`).

**[O] Tickets.** A product loop that loses a slot to a harness defect files a ticket with the slot
verdict line (`cmd/ailang/mission_ticket.go:93`) instead of fixing the harness; the fleet loop
ranks by slots lost.

**[O] Durable path.** An expired lease on a `running` child becomes `needs_reconciliation`, never a
retry (`mission_work_item_finish.go:79-92`). "There is no automatic rerun or automatic acceptance
for an ambiguous outcome" (`mission-iteration.md:104`). Accepted stages are kept and reused:
`resume` continues from `next_stage`; `retry-review` reuses accepted author work for a new
evaluator. Discarding is never automatic: failed checks keep their workspace
(`iteration/verify.go:64-70`) and terminal items are immutable ("the original failed record stays
immutable", `mission-iteration.md:149`). Activation recovery "restores only unchanged owned files,
after explicit verified stop" (`activation/activation.go:158-159`).

---

## 8. How human decisions enter

**[O] Two channels of equal rank** (`mission-bootstrap.md:330-349`).

**Issue comments.** `scripts/mission_directives.sh --issue N [--repo] [--since ISO]`:

- Allowlist from `MISSION_DIRECTIVE_AUTHORS`, default `MarkEdmondson1234` (`:49`). Set but empty is
  refused (`:46-48`).
- Self-direction guard: if the allowlist contains the login `gh api user` returns, it dies with
  "that lets the loop direct itself. Refusing." (`:58-70`).
- Filter: login in allowlist, case-insensitive, and `createdAt > since` (`:84-93`). The authors are
  passed to jq as data, not interpolated program text (`:74-77`).
- It does not move the watermark; the agent does that after triage
  (`:14-15`; `gate-0-preflight.md:118-120`, `:141`). The watermark file is
  `~/.ailang/state/mission-<issue>-last-seen`.
- Why it is a script: the allowlist used to be a `jq` filter in the skill, "enforced only by the
  controller choosing to run that exact command" (`:8-12`).

**Attended ledger edits.** `scripts/mission_answer.sh --id D-n --answer TEXT [--file] [--commit]`:

- Rewrites exactly one `OPEN` row inside the ledger block to `RESOLVED`, appending
  "**ANSWERED — ...** (name, attended date, recorded directly in this ledger.)" and an evidence
  stamp (`:140-143`). Never re-answers a resolved row: "supersede it with a new ID instead" (`:137`).
- Re-validates the ledger (`:172-174`); with `--commit`, commits as the attended identity
  (`:176-184`). It does not push (`:23-26`).
- Identity guard: refuses if the attended email contains the fleet account name or the name
  contains "bot" (`:107-111`).

**Validation.** `scripts/mission_decisions.sh --check|--open|--all` (section 3). The report's
"DECISIONS FOR MARK" section is generated from OPEN rows
(`gate-0-preflight.md:155-156`; `mission-charter-TEMPLATE.md:94-95`).

**What stops the unattended loop from answering its own question.**

- **[O] Issue channel: code.** The bot's comments are not on the allowlist, and the script refuses
  to run if the bot is on it.
  **[I]** The guard fails open if `gh api user` fails: `SELF` becomes empty and the check is
  skipped (`mission_directives.sh:58-59`).
- **[O] Ledger channel: convention.** The script says so itself: "ATT_NAME/ATT_EMAIL below are
  DEFAULTS, not derived from whoever invokes the script, so it stamps the attended identity for any
  caller ... The real control is the charter rule, not this code" (`mission_answer.sh:44-48`). The
  skill says the same: "The guard is a convention; treat it as one and say so, rather than
  simulating an enforcement that is not there" (`gate-0-preflight.md:192-193`). The rule itself is
  prose: "YOU MAY NOT USE THIS CHANNEL. The loop never runs `mission_answer.sh`" (`:183-184`).
- **[O] After-the-fact audit: prose.** The skill asks the agent to check
  `git log -1 --format='%an <%ae>' -S'| D-nn |' -- <charter>` and to treat a flip authored by the
  bot as self-resolution, to be re-opened and flagged (`gate-0-preflight.md:171-182`).
  `mission_answer.sh:58-62` records that no code reads the commit author.
  **[I]** That check separates "went through the script with `--commit`" from "edited by hand"; it
  cannot separate a human from an agent that ran the script.
- **[O] Durable path: structural.** Approval is an `authority_refs` entry that must exist in git
  history at the frozen base, with matching hashes and a locator string present in the file
  (`iteration/authority.go:42-70`). The stage instructions add "Do not publish, merge, change
  policy or spawn additional author/reviewer roles" (`runtime_stage.go:119`). The code is candid
  about the limit: "These references bind approved content; they are not human signatures"
  (`authority.go:9-10`).

**[O] An incident this design already produced.** A rebase "silently eat this charter's
`decision-ledger:end` marker and its entire Goal block ... It exited 0.
`scripts/mission_decisions.sh --check` caught it; nothing else would have"
(`gate-0-preflight.md:203-209`).

---

## 9. Ten incident comments

1. **A log with no rotation rule.** `internal/mission/rotate.go:15-18`: "The v1 log reached 2.86 MB
   / ~715k tokens / 335 entries with NO rotation rule anywhere in Gate 4 — iteration 1 was still in
   the file iteration 335 appended to. Bounded greps keep it out of context today, but one careless
   Read costs ~715k tokens on every remaining turn of that iteration".

2. **A rotation that archived live reference material.** `rotate.go:193-196`: "Measured on motoko's
   status archive, which carries eight such sections. Rotating it moved '## Backlog (prioritized —
   top = next)' and '## How the mission runs' into an archive nothing loads. Reverted, and refused
   here instead".

3. **A security rule that lived only in prose.** `scripts/mission_directives.sh:8-12`: "Until now
   the allowlist was a `jq ... select(.author.login == "...")` written into the mission-control
   skill's prose — correct, but enforced only by the controller choosing to run that exact command.
   A model that paraphrases the pipeline, or that is talked into widening it by something it read,
   has nothing behind it. This script is that something."

4. **A prose rule that an agent ignored anyway.** `tools/launchd/mission-worktree.sh:10-13`: "Docs
   iteration 17 (2026-10-01) then read a tree with 25,786 staged deletions; V1 iteration 234
   (2026-08-20) removed the live index.lock and killed a checkout. The skill had prose rules for
   this since 2026-08-20 and a controller still ran the add in the foreground — so the guard is
   this script".

5. **Reviewed is not deployed.** `missions/docs.toml:3-9`: "THIS MISSION IS THE STANDING PROOF THAT
   A REVIEWED FILE IS NOT A DEPLOYED FILE ... It was never copied to ~/.config. Docs work has routed
   to opus instead of codex ever since, with a green CI arm — the test asserts the repo copy while
   the driver reads the installed one." Same event at `internal/mission/doctor.go:186-191`.

6. **The token cost of a long prose skill.** `tools/launchd/mission-control.sh:761-766`: "Four astra
   CONTROLLER fires overnight cost 2,121,499 tokens ... a controller drives the WHOLE iteration, so
   the fixed context prefix is re-sent on every turn — ~63k tokens of this skill x ~50 turns is
   ~3.1M input tokens before it reads anything."

7. **A false sentence that agents then defended.** `scripts/mission_answer.sh:52-56`, `:64-67`:
   "That sentence was FALSE BY CONSTRUCTION for every caller on this machine ... twice (D-53 on
   2026-09-02, and again on 2026-09-03) an agent read that sentence as a control it had to protect,
   and handed a ruling Mark had already given back to Mark to re-enter by hand."

8. **A pause that still spent.** `mission-control.sh:1605-1608`: "Measured 2026-09-08: the docs fire
   began at 04:41 and reached this line at 04:49:36 — nineteen minutes and four inference probes on
   a mission that was already disabled ... A pause that still spends is not a pause."
   (The two timestamps are 8.5 minutes apart, so the comment's own arithmetic does not hold.)

9. **Measure the scheduler before tuning it.** `missions/v1.toml:20-27`: "StartInterval re-arms
   from the job's EXIT, not its start: three consecutive v1 gaps ... came in at 5403s, 5372s and
   5379s against a 5400s interval ... HALF of v1's day was idle — 11.9 hours — none of it chosen."
   And `:38-40`: "On 2026-09-02 three loops were tightened in the same hour: fleet stall rate 6% ->
   33%, and total starts did NOT rise (19 -> 18)." (`missions/docs.toml:20` gives the same event as
   "5% -> 33%".)

10. **A budget cap that silently removed the best reviewer.** `internal/mission/quorum/run.go:14-19`:
    "It was $0.10 until 2026-09-25, sized when docs were a few thousand tokens. World's docs grew to
    ~9-13k tokens ... so the pre-flight refused it on EVERY quorum from 2026-09-24 21:46Z on — the
    reviewer that finds real objections, silently reduced to N-1".

Runners-up, all **[O]**:

- `mission-control.sh:51-57`: a missing `START_EPOCH` under `set -u`; "every v1/docs/motoko
  iteration died here after its work had landed, so no slot verdict was ever recorded".
- `mission-control.sh:2041-2049`: `claude -p` ends background tasks after 600s and exits rc=0;
  "the slot dies with a plausible transcript, zero commits, zero charter rows — and NEITHER
  watchdog fires".
- `mission-control.sh:882-886`: a rung "probed rc=0, then died on its FIRST real call ... the fleet
  crash-looped for hours while ... the very next rung, healthy, with $93.33 of credit — was never
  tried."
- `mission-control.sh:647-656`: "all four fired together again, 33 `claude` processes inside ten
  minutes"; three out-of-memory events in two days.
- `mission-control.sh:178-183`: a generic notice title collided with the dedupe forever; "six world
  rows ... had been retried on every fire for fifteen days".
- `internal/mission/comms/comms.go:3-7`: the bookkeeping thread "held 27 comments and 52,677
  characters, of which the human wrote exactly one comment, six characters long".
- `internal/mission/quorum/reviewer.go:68-73`: a schema `required` omission "silently knocked every
  OpenAI reviewer ... out of the quorum, degrading it to solo-gemini on every run".
- `internal/mission/render.go:263-266`: world "came up with workdir=~/.ailang-driver-pin/world, a
  worktree of ailang, for a mission whose entire job is the ailang-world repo".
- `tools/launchd/lib/lane-probe.sh:169-173`: a 15s bound on a 31 to 39s quota read; "All 7 fires
  after 2026-09-30 21:40 timed out and blocked Codex, with Codex at 51% used of 68% allowed."
- `rotate.go:153-156`: byte truncation cut an em dash; "the first real run produced an index that
  was not valid UTF-8".

---

## 10. Observations for the Motoko redesign

All **[I]**, drawn from the above.

- The pattern in this codebase is consistent: a rule starts as prose, an agent breaks it or
  paraphrases it, and it moves into a script. Incidents 3 and 4 say so in their own words. The
  rules that have not moved (when to rotate, when to run the quorum, how to credit a dead
  iteration, who may resolve a ledger row) are the ones still producing incident notes in the
  skill.
- Markdown that code must parse needs a refuse-loudly path and a named contract. Where AILANG has
  one (the ledger markers, the entry heading), failures were caught. Where the format drifted
  (five status heading variants, `normalize.go:10-23`), the tool needed a normaliser and two
  missions still ended up with hand-maintained indexes.
- A generated file needs to be regenerable or it will be hand-edited. Both hand-edited indexes say
  in their own headers why the generator could not be used.
- Code comments and TOML comments are being used as the incident log. They go stale like any other
  prose: the `world.toml` header, the nineteen-minute arithmetic and the 5% vs 6% figure above are
  three examples from one commit.
- Several lists of "which missions exist" survive beside the registry (`_mc_boot_offset`,
  `comms.missionRepos`, the weekly report). A registry only helps if the other lists are deleted.

---

## Files read

**Read in full**

- `docs/docs/guides/mission-bootstrap.md`, `mission-iteration.md`, `mission-model-fleet.md`,
  `mission-role-dispatch.md`
- `missions/docs.toml`, `fleet.toml`, `motoko.toml`, `stapledon.toml`, `v1.toml`, `world.toml`
- `internal/mission/registry.go`, `rotate.go`, `normalize.go`, `ticket.go`, `admission.go`,
  `render.go`, `doctor.go`
- `internal/mission/iteration/spec.go`, `runtime.go`, `runtime_stage.go`, `role.go`, `binding.go`,
  `authority.go`, `spec_result.go`, `spec_decode.go`, `verify.go`
- `internal/mission/quorum/quorum.go`, `run.go`, `seating.go`, `reviewer.go`, `escalate.go`,
  `tier2.go`, `artifact.go`, `tokens.go`
- `internal/mission/dispatch/request.go`, `receipt.go`, `admission.go`, `progress.go`
- `internal/mission/activation/activation.go`
- `internal/mission/comms/comms.go`
- `internal/coordinator/mission_attempt.go`, `mission_work_item.go`, `mission_work_item_child.go`,
  `mission_work_item_expire.go`, `mission_work_item_finish.go`, `mission_work_item_attestation.go`,
  `mission_work_item_stage.go`, `mission_work_item_readonly.go` (outside the listed sources, but
  this is where the durable state lives)
- `cmd/ailang/mission_cmd.go`, `mission_iteration_cmd.go`, `mission_iteration_cmd_status.go`,
  `mission_iteration_status_progress.go`, `mission_confirm_stopped.go`, `mission_role_state.go`,
  `mission_attempt_cmd.go`, `mission_ticket.go`, `mission_comms.go`,
  `mission_activation_binding.go`, `mission_activation.go` (one long line truncated),
  `design_quorum.go`
- `scripts/mission_answer.sh`, `mission_decisions.sh`, `mission_directives.sh`
- `tools/launchd/mission-heartbeat.sh`, `mission-recovery.sh`, `mission-base.sh`, `mission-arm.sh`,
  `mission-lane-dead.sh`, `mission-worktree.sh`, `mission-template.plist`, `githooks/pre-push`
- `tools/launchd/mission-env/mission-v1.env`, `mission-fleet.env`

**Read in part**

- `tools/launchd/mission-control.sh`: lines 1-190, 560-1285, 1596-1655, 1870-2511 (about 1,700 of
  2,511). Not read: 190-560 (notify, process-tree and progress instruments), 1285-1596 (role
  defaults), 1655-1870 (role fallback probe loops).
- `internal/mission/iteration/retry_review.go` 1-150 of 364
- `internal/mission/quota_ledger.go` 1-120 of 713, plus its function outline
- `internal/mission/apply.go` 1-75 of 284
- `internal/mission/quorum/claude_reviewer.go` 1-60 of 130
- `tools/mission-weekly-report.py` 1-232 of 361
- `scripts/mission_pi_run.sh` 1-70 of 447
- `tools/launchd/lib/lane-probe.sh`: the `_mc_load_ration` function only
- `tools/launchd/mission-lane-check.sh` 1-25; `cron-kicker.sh` 1-25;
  `mission-env/README.md` first 28 lines
- Skill prose, for cross-checks only: `gate-2-pick.md` 128-240 and 303-360,
  `gate-0-preflight.md` 100-216, `gate-4-record.md` 24-58
- `design_docs`: the template's headings and ledger block, the v1 ledger head, the four index
  heads, the `## ` headings of the four logs, `motoko-mission-log.md` 1-38

**Outline or grep only**

- `internal/mission/iteration/artifacts.go`, `internal/mission/dispatch/run.go` (declarations and
  comments)
- `cmd/ailang/mission_quota_cmd.go` (the `--over` lines)
- `tools/launchd/dev.ailang.mission-recovery*.plist` (keys); the three mission plists (grep for the
  generated marker: none carries it)
- Test names in `internal/coordinator/mission_work_item_recovery_test.go` and
  `internal/mission/iteration/*_test.go`

**Not opened**

- `internal/mission`: `anthropic_quota.go`, `anthropic_usage_cli.go`, `codex_quota.go`,
  `codex_app_server_quota.go`, `ollama_quota.go`, `ollama_rate_ration.go`, `openrouter_quota.go`,
  `quota_margin.go`, `kill_unix.go`, `kill_windows.go`
- `internal/mission/activation/files.go`, `lock_*.go`, `privatedir_*.go`
- `internal/mission/dispatch/resolve.go`; `internal/mission/iteration/review_packet.go`
- `internal/mission/quorum/agentic_caller.go`, `agentic_provider.go`, `call.go`
- every `*_test.go` body
- `cmd/ailang/mission_activation_process.go`, `mission_activation_unix.go`,
  `mission_activation_other.go`, `mission_quota_codex_reset.go`, `mission_retry_review.go`,
  `mission_role_cmd.go`, `chains_stats_mission.go`
- `tools/launchd`: `lib/pin-root.sh`, `lib/pi-ext-args.sh`, `lib/proc_rusage.py`,
  `lib/suite-env.sh`, `resolve-role-spawn.sh`, `spawn-pin-hook.sh`, `derive-planner-lane.sh`, every
  `test_*.sh`, and the docs, motoko, stapledon and world env files
- `scripts/test_mission_*.sh`
- The body of `.claude/skills/mission-control/SKILL.md` and the other resources (grep hits only)

## Method notes and one side effect

- Nothing was built or executed from the clone. The regex replay in section 3 used Python's `re`,
  which is close to but not the same engine as Go's.
- I started one whole-tree `git grep ... HEAD -- '*.go'`. The clone is blobless
  (`remote.origin.partialclonefilter = blob:none`), so that command began fetching blobs on demand
  and git printed "Auto packing the repository in background" repeatedly. I stopped it. The working
  tree and the sparse-checkout patterns were not changed, but the shared clone's object store
  gained some fetched blobs and may have been repacked. All later searches used plain `grep` on the
  files on disk.
