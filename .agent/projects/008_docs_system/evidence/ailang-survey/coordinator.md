# AILANG coordinator: how it holds and moves work

Source: `sunholo-data/ailang`, branch `dev`, commit `2a1f3f295` (2026-10-03).
All paths are relative to the clone root
`/tmp/claude-1001/-workspaces-motoko-agent/5c0ae771-b88d-496a-8866-321245c5b41a/scratchpad/ailang-dev`.
`IC/` abbreviates `internal/coordinator/`, `CA/` abbreviates `cmd/ailang/`.

Each claim is marked **Observed** (read in the source at the cited line) or
**Inferred** (my reading of what the observed code implies; not run, not built).

## 0. Coverage, and what limits these findings

**Search scope.** Every "no caller" or "not wired" statement below was checked by
grep over the directories on disk in the sparse clone only: `cmd/ailang`,
`internal/coordinator`, `internal/messaging`, `internal/mission`, `internal/storage`.
`internal/server` (the dashboard, which also approves) is not checked out and was
not read. A caller there would not have been seen.

**Nothing was built or run.** No test was executed; test claims are from reading
test source.

**One deviation from the brief.** I ran one `git grep` against `HEAD` across the
whole tree. The clone is blobless (`remote.origin.partialclonefilter=blob:none`), so
that fetched missing blobs on demand and triggered git's automatic repack in the
shared object store. I stopped it. The working tree, sparse-checkout list and HEAD
are unchanged (`git status` clean, HEAD still `2a1f3f295`), and no git process was
left running. The object store holds extra blobs it did not hold before.

### Read in full

Guides and rules: `docs/docs/guides/coordinator.md`, `coordinator-setup.md`,
`coordinator-workers.md`, `workspaces.md`, `secret-approvals.md`;
`.claude/rules/coordinator.md`; `.claude/skills/coordinator-helper/SKILL.md`.

`internal/coordinator` (46 of its 118 non-test files): `store.go`, `task_status.go`,
`task_status_cas.go`, `store_sqlite_transitions.go`, `store_sqlite_schema.go`,
`store_sqlite_approvals.go`, `store_sqlite_approvals_if_absent.go`, `task_dedup.go`,
`task_blocked.go`, `finalization_ledger.go`, `task_finalize.go`,
`task_finalize_approval.go`, `task_finalize_cloud_strategy.go`, `approval_handoff.go`,
`approval_recovery.go`, `approval_processor.go`, `approval_checkpoint.go`,
`approval_diff.go`, `approval_rerun.go`, `backstop_sweep.go`, `completion_binding.go`,
`artifact_discovery.go`, `pipeline_config.go`, `evaluation_verdict.go`,
`daemon_evaluator.go`, `cascade_scheduler.go`, `stale_task_detector.go`,
`pubsub_completion_handler.go`, `merge.go`, `pr_reconcile.go`, `pr_landed.go`,
`daemon_landed_cards.go`, `daemon_stranded_approvals.go`, `daemon_tasks_init.go`,
`daemon_tasks_worktrees.go`, `daemon_lifecycle.go`, `retry_chain.go`,
`execution_lane.go`, `work_tier.go`, `autonomy_router.go`, `secret_approval.go`,
`mission_attempt.go`, `mission_work_item.go`, `mission_work_item_child.go`,
`mission_work_item_finish.go`, `mission_work_item_attestation.go`.

`cmd/ailang`: `coordinator_approvals_authority.go`, `coordinator_approvals_engine.go`,
`coordinator_approvals_orphans.go`, `coordinator_cloud_evidence.go`.

Other: `internal/dashboard_transforms/approval_authority.ail` (via `git show`).

Tests: `task_status_test.go`, `task_claim_test.go`, `finalize_parity_test.go`.

### Read in part (line ranges)

`IC/store_sqlite.go` 1-330; `IC/agent_registry.go` 95-354; `IC/daemon.go` 395-671;
`IC/daemon_tasks_polling.go` 60-389; `IC/worktree.go` 1-260; `IC/task_chain.go` 1-330;
`IC/stage_execution.go` 1-260; `IC/store_sqlite_queries.go` 100-190;
`IC/daemon_tasks_exec.go` 98-165; `IC/daemon_tasks_exec_run.go` 400-440 and 500-545;
`IC/secret_approval_bridge.go` 1-60; `IC/completion_matrix_test.go` 1-180 and 280-316;
`IC/pipeline_full_chain_test.go` 1-190; `CA/coordinator_approvals_remote.go` 150-326;
`CA/coordinator_approvals_json.go` 1-90; `CA/coordinator_cloud.go` 225-330;
`CA/coordinator_cloud_github.go` 100-200; `CA/coordinator_prs.go` 1-60;
`internal/storage/firestore/coordinator_transitions.go` 1-47 and 158-225;
`internal/storage/firestore/coordinator_approvals.go` 322-345.

### Skimmed (header comment, or grep hits only)

`IC/`: `instances_sweep.go`, `unrouted_bounce.go`, `triage_router.go`, `watcher.go`,
`analyzer.go`, `dispatch_provider.go`, `cloud_dispatcher.go`, `heartbeat.go`,
`pubsub_adapter.go`, `observatory_sync.go`, `package_agents.go`, `task_chain_agent.go`,
`mission_work_item_expire.go`, `mission_work_item_stage.go`,
`mission_work_item_readonly.go`, `dispatch_read_marking.go`, `task_timeout.go`,
`daemon_tasks_budget.go`, `task_executor.go`, `agent_config.go`,
`agent_config_workspaces.go`, `history_collector.go`, `approval_watcher.go`,
`github_webhook.go`, `human_interaction.go`.
Test function names only (bodies not read) for 15 test files, listed in section 1.

### Not opened

`IC/`: `daemon_http.go`, `daemon_github.go`, `github_poster.go`, `github_comments.go`,
`templates.go`, `provider.go`, `provider_executor.go`, `provider_gemini.go`,
`provider_script.go`, `event_handler.go`, `event_formatter.go`,
`capability_detector.go`, `resource_tracker.go`, `feedback_gate_audit.go`,
`feedback_gate_wiring.go`, `triage_rubric.go`, `kms.go`, `apikey_cache.go`,
`heartbeat_file.go`, `instances_http.go`, `http_broadcaster.go`,
`pubsub_broadcaster.go`, `message_adapter.go`, `meta_prompt.go`,
`model_resolution.go`, `agent_registry_effective.go`, `finalization_ledger_store.go`,
`store_sqlite_events.go`, `secret_notification.go`, `sanitize.go`, `git_args.go`,
`tag_matcher.go`, a few others, `task_chain.go` after line 330, and 120 of the 140
test files.

`cmd/ailang`: 68 of the 77 `coordinator*.go` files (28 of those are tests),
including `coordinator_actions.go` (the local approve and reject commands),
`coordinator_pending.go`, `coordinator_pipeline.go`, `coordinator_lifecycle.go`,
`coordinator_lint.go`, `coordinator_agent_check.go`, and most of
`coordinator_cloud*.go`. For `coordinator_prs_landed.go`, `coordinator_actions.go`
and `coordinator.go` I saw grep hits only.

Also: `.claude/skills/coordinator-helper/resources/reference.md` and its three
scripts; `internal/server`; `internal/mission` and `internal/messaging` (assigned to
other agents); the Firestore store beyond the two ranges above.

---

## 1. What a task is

### Schema

**Observed.** `TaskRecord`, `IC/store.go:9-100`. Field groups:

- Identity and lineage: `ID`, `MessageID`, `ThreadID`, `ParentTaskID`, `ChainID`,
  `StageID` (lines 10-13, 46-47).
- Classification: `Title`, `Content`, `Type`, `Kind`, `Source`, `Priority`,
  `Capabilities`, `ImpactLevel`, `EstimatedCost` (14-16, 26-28, 77-79).
- Execution: `Status`, `Provider`, `AgentID`, `SessionID`, `Iteration`,
  `AttemptCount`, `ChainLinkIndex` (23-24, 29-31, 42-43).
- Isolation: `WorktreeID`, `WorktreePath`, `BaseBranch`, `BaseCommit`, `Workspace`
  (32-35, 44).
- Finalisation: `Finalization FinalizationLedger`, a per-effect ledger stored as
  JSON in one column (36-41).
- Outside links: `GithubIssue`, `GithubRepo`, `Stage` (deprecated), `DesignDocPath`,
  `SprintPlanPath` (49-53).
- Time and result: `CreatedAt`, `StartedAt`, `QueuedAt`, `CompletedAt`, `Duration`,
  `Error`, `Output`, `Cost`, token counts, peak CPU and memory (55-75).
- Package-cascade envelope: `RootPackage`, `RootChangeClass`, version and hash
  pairs, effect ceilings (89-99).

SQLite table: `IC/store_sqlite.go:59-91`, extended by 41 `ALTER TABLE ADD COLUMN`
statements whose errors are ignored (`:152-217`, "Ignore errors - columns may
already exist").

**Observed.** A task is created from exactly one inbox message, and its id is
derived from that message: `taskID := fmt.Sprintf("task-%s", msgIDSuffix(msg.ID, 8))`
(`IC/daemon_tasks_polling.go:140`). The comment at `:137-139` records that using the
prefix once gave every task the id `task-inbox_17`.

**Observed.** `CreatedAt` is inherited from the message, not the task's creation
(`IC/daemon_tasks_polling.go:209`; explained at `IC/store.go:57-62`).

**Observed, a gap.** `AttemptCount` is documented as "Persisted rather than held in
memory: the coordinator scales to zero, and a cap that a restart forgets is not a
cap" (`IC/store.go:19-21`). No `attempt_count` column appears in the SQLite schema
or ALTER list (`IC/store_sqlite.go:59-214`), and the string `attempt_count` appears
in no Go file on disk other than the struct tag at `IC/store.go:23`.
**Inferred:** the field is not persisted by either store at this commit. The same
file warns of exactly this failure for a different field: "a field missing there is
silently dropped on read" (`IC/store.go:38-39`).

### States

**Observed.** Eleven statuses: `pending`, `queued`, `running`, `pending_approval`,
`completed`, `failed`, `rejected`, `cancelled`, `duplicate`, `blocked`
(`IC/store.go:105-120`) and `no_changes` (`IC/task_status.go:28`).
`AllTaskStatuses()` enumerates them (`IC/task_status.go:32-46`).

**Observed.** `duplicate` is declared and classified in five tables, but no
non-test code on disk writes it to a task. A duplicate request is not stored as a
task at all: the poller skips creation and publishes a dedup completion
(`IC/daemon_tasks_polling.go:227-235`).

### Where the state machine is defined

**Observed. There is no transition table.** A grep for `allowedTransition`,
`validTransition`, `canTransition`, `state machine` across `internal/coordinator`
and `cmd/ailang/coordinator*.go` returns nothing. What exists instead:

1. **Per-status meaning tables**, each a `map[TaskStatus]…` with a test that every
   declared status has an entry:
   - `terminalByStatus` (`IC/task_status.go:53-67`). `pending_approval` is
     explicitly non-terminal: "work done, but the task is not over — a human
     still rules" (`:57`).
   - `observatoryByStatus` (`IC/task_status.go:74-91`).
   - `dedupSuppressesByStatus` (`IC/task_dedup.go:43-55`).
   - `completionArrivalByStatus` (`IC/completion_binding.go:45-75`).
   - `prStatusVerdict` (`IC/pr_reconcile.go:39-51`).

   The stated reason for tables over conditions: "A hand-written list goes stale the
   moment someone adds a status; a table the tests iterate cannot"
   (`IC/task_status.go:23-24`).

2. **Transition functions on the store**, some guarded and some not.

| Function | Guard | Cite |
|---|---|---|
| `MarkTaskQueued` | only from `pending`, atomic; also clears the ledger and stamps `queued_at` (SQLite) | `IC/store_sqlite_transitions.go:39-58` |
| `MarkTaskCancelled` | only from `pending` | `:100-116` |
| `ResetTaskToPending` | only from `queued` or `running` | `:152-158` |
| `CompareAndSetTaskStatus` | caller names the expected statuses; empty set is refused | `IC/task_status_cas.go:44-73` |
| `ReopenTask` | only from `rejected` or `cancelled`, to `pending_approval` | `IC/store_sqlite_approvals.go:220-269` |
| `MarkTaskRunning` | none | `IC/store_sqlite_transitions.go:61-67` |
| `MarkTaskCompleted` | none | `:70-83` |
| `MarkTaskFailed` | none | `:86-97` |
| `MarkTaskPendingApproval` | none | `:119-130` |
| `MarkTaskRejected` | none | `:133-140` |
| `RequeueTask` | none (any status to `pending`) | `:143-149` |

   The file header says "these nine functions are the only things that move a task
   between statuses" (`IC/store_sqlite_transitions.go:13-14`). **Observed:** that is
   not so. Status is also written by `UpdateTask` (`IC/store_sqlite.go:296-320`, used
   by `--clear-orphans` at `CA/coordinator_approvals_orphans.go:138-140`),
   `resolveApprovalByTask` (`IC/store_sqlite_approvals.go:212-216`),
   `RecoverStaleTasks` (`IC/store_sqlite_queries.go:129-147`), `RetryAllFailedTasks`
   (`:150-161`), `ReopenTask`, and `CompareAndSetTaskStatus`.

3. **The outcome matrix in finalisation**: `nextTaskStatus()` maps a run's outcome
   to a status (`IC/task_finalize.go:242-257`) and writes it with a compare-and-set
   from `FinalizableFrom()` = `pending`, `queued`, `running`
   (`IC/task_status_cas.go:31-37`, applied at `IC/task_finalize.go:259-268`).

**Inferred lifecycle**, assembled from the callers:

```
pending --claim--> queued --(local only)--> running
   |                  \________________________/
   |                             |
   |          finalise: completed (skip_approval) | pending_approval
   |                    | no_changes | blocked | failed
   +--> cancelled (only from pending)
pending_approval --approve--> completed
pending_approval --reject---> rejected  (a new message, hence a new task, carries the retry)
rejected | cancelled --reopen--> pending_approval
queued | running --dispatch failed--> pending
queued | running --timeout (cloud)--> failed ; --restart (local)--> cancelled
failed --retry--> pending ; any --RequeueTask--> pending
```

**Observed.** A cloud task never passes through `running`: "every cloud task,
since MarkTaskRunning is local-only" (`IC/store.go:59-60`).

**Observed.** The only prose lifecycle is in the skill, and it omits `no_changes`,
`blocked`, `cancelled` and `duplicate`
(`.claude/skills/coordinator-helper/SKILL.md:90-94`). The guide's field table lists
six statuses (`docs/docs/guides/coordinator.md:993`).

### What the tests assert

Bodies read: `task_status_test.go`, `task_claim_test.go`, `finalize_parity_test.go`,
and part of `completion_matrix_test.go`. For the rest I read function names only.

**Observed (bodies read).**
- A run expected to change files that changed none is `no_changes`, not `completed`
  (`IC/task_status_test.go:12-18`); an acknowledge-only run with no diff is
  `completed` (`:23-27`).
- Every status has a terminality entry and an observatory mapping (`:65-78`).
- A claim succeeds once; a second claim returns `ErrTaskNotClaimable`
  (`IC/task_claim_test.go:45-67`). A claim on `running`, `pending_approval`,
  `completed`, `failed` or `cancelled` is refused and leaves the status alone
  (`:72-103`). Eight concurrent claimers yield exactly one winner (`:107-144`).
- **Structural tests that parse Go source.** `completion_matrix_test.go` parses
  `daemon_tasks_exec_run.go` with `go/ast` and asserts which effect calls sit in
  which branch of `if result.Success` (`:46-125`). Its header says it "must pass on
  UNMODIFIED dev. It is not a RED-first arm" (`:21-22`).
  `finalize_parity_test.go` asserts the cloud handler calls
  `FinalizeTaskCompletion` and does not call approval or chain writes directly
  (`:26-46`), that every daemon effect has an orchestrator counterpart (`:58-93`),
  and that finalisation calls no accumulating write (`:101-116`).
- `TestCompletionMatrix_DaemonHasNoNoChangesArm` asserts the local path contains no
  identifier with `NoChanges` in it, with a positive control so the absence means
  something (`IC/completion_matrix_test.go:285-316`).

**Observed (names only; assertions not verified).** By name, tests exist for:
cancel only from pending and no resurrection by reset (`task_cancel_test.go:38,61,81`);
the outcome matrix behaviourally (`task_finalize_matrix_test.go`, 10 tests);
replay safety (`task_finalize_replay_test.go`, 9 tests, including
`TestFinalize_DoesNotRegressAnApprovedTask:100`); approval idempotency and the
ledger (`finalization_idempotency_test.go`, 12 tests); completion binding
(`completion_binding_test.go`, 9 tests); handoff exactly-once
(`approval_handoff_once_test.go`, 14 tests); stage crossing and the full
four-stage chain (`pipeline_stage_crossing_test.go`, `pipeline_full_chain_test.go`);
dedup (`task_dedup_test.go`, 15 tests); PR reconcile (`pr_reconcile_test.go`,
11 tests); reopen (`store_sqlite_reopen_test.go`); startup recovery mode
(`stale_recovery_test.go`); blocked (`task_finalize_blocked_test.go`); and the
mission tables (`mission_work_item_test.go`, `mission_attempt_test.go`,
`mission_work_item_recovery_test.go`).

**Not found.** No test asserts a complete set of legal transitions, because no such
set is declared.

### A second, stricter state machine in the same package

**Observed.** `mission_work_items` and `mission_attempts` live in the same SQLite
file (migrated at `IC/store_sqlite.go:224-229`) but share nothing with `tasks`: the
word "task" does not occur in any non-test `mission_*.go` file. They are driven from
`internal/mission/iteration` (`runtime.go:242`) and `CA/mission_attempt_cmd.go:67`.
Their design differs from the task machine on every point that the task machine
had incidents about:

- Ownership by a random 32-byte token plus a lease (`IC/mission_attempt.go:102-106`,
  `IC/mission_work_item.go:50-54`); every write is fenced on token, unexpired lease
  and non-terminal state (`workFence`, `IC/mission_work_item.go:115-122`).
- A monotonically increasing `version` used as compare-and-set for cancel and
  confirm (`IC/mission_attempt.go:189-198`, `IC/mission_work_item_finish.go:39-48`).
- Request and outcome are stored with their SHA-256 and checked
  (`IC/mission_attempt.go:78-91`, `:180`).
- "Running work never retries" (`IC/mission_attempt.go:93-94`): an expired lease on
  a running attempt becomes `needs_reconciliation`, never `prepared`
  (`:199-205`; `IC/mission_work_item_finish.go:79-92`).
- Releasing a cancelled item whose child was running needs an operator
  attestation, recorded with the exact child attempts and versions
  (`IC/mission_work_item_attestation.go:14-22`, `:29-75`).
- A stage advances only when an acceptance row is written whose request and outcome
  digests match the attempt, and the attempt is `execution_completed`
  (`IC/mission_work_item_child.go:100-138`).
- All of it runs in one SQLite transaction that takes the write lock first
  (`workTx`, `IC/mission_work_item.go:84-98`).

**Inferred.** This is the newer design and the closer model for a redesign. It is
SQLite-only: no `Mission*` symbol occurs in `internal/storage/firestore`.

---

## 2. Storage, durability, recovery

### Stores

**Observed.** Local: three SQLite files, `coordinator.db` (tasks, approvals,
events), `collaboration.db` (messages), `observatory.db` (chains, stages, spans)
(`.claude/rules/coordinator.md:49-52`; `IC/daemon_tasks_init.go:254`, `:335`).
Cloud: Firestore for tasks and messages, Pub/Sub for delivery, Cloud Run Jobs for
execution (`docs/docs/guides/coordinator.md:1212-1223`). The Firestore
implementation is `internal/storage/firestore/coordinator*.go`.

**Observed.** There is no cross-store transaction: "the daemon keeps them in three
separate SQLite files, and no store method accepts a caller-supplied transaction.
Cross-store atomicity is therefore unavailable" (`IC/finalization_ledger.go:12-15`).

**Observed.** Foreign keys are off for `coordinator.db`, because rows violating the
declared references already exist: "Turning enforcement on is a data migration, not
an opener setting" (`IC/store_sqlite.go:35-41`).

**Observed.** Schema changes are additive and unversioned; row-rewriting migrations
are versioned by `PRAGMA user_version`, with the rule "never reorder or edit an
entry that has shipped" (`IC/store_sqlite_schema.go:11-20`).

### Durable across a daemon restart

**Observed.** Task rows with status, `queued_at` and the finalisation ledger;
approval rows with `handoffs_triggered`, `handoffs_suppressed`, `handoffs_expired`
(`IC/store_sqlite.go:189-193`); task events (30-day retention,
`IC/daemon.go:588-596`); inbox rows; worktrees on disk, re-read from
`git worktree list` at start (`IC/worktree.go:81-85`); mission work items and
attempts.

### Not durable

**Observed.** `ApprovalCheckpoint` holds requests and waiters in memory
(`IC/approval_checkpoint.go:71-75`); its store-backed variant has "no production
callers" (`:389`). `PubSubInboxAdapter` buffers messages in memory
(`IC/pubsub_adapter.go`, struct header). `CascadeCircuitBreaker` and `CascadeBudget`
are in-memory counters (`IC/cascade_scheduler.go:116-122`, `:162-169`). The secret
notification dedup map is in memory (`IC/secret_approval_bridge.go:31-34`). The
default heartbeat store is in memory (`docs/docs/guides/coordinator-workers.md:262`).

### Recovery mechanisms

| Mechanism | Trigger | What it recovers | Cite |
|---|---|---|---|
| Startup stale recovery | daemon start, local mode only | `running`/`queued` older than 5 min become `cancelled` | `IC/daemon_tasks_init.go:370-378`; `IC/store_sqlite_queries.go:129-147` |
| Stale task detector | every 2 min, cloud mode only | `queued`/`running` past 1.5 × agent timeout become `failed`; chain closed; notice posted | `IC/stale_task_detector.go:90-158`, `:212-220` |
| Backstop sweep | once at start, then every 10 min, cloud | unread inbox rows with a registered agent whose push never arrived | `IC/backstop_sweep.go:24-40`, `:92-106` |
| Approval recovery (missed handoffs) | daemon start | approved `merge_handoff` rows with no recorded handoff decision | `IC/daemon.go:602-671`; `IC/approval_recovery.go:24-127` |
| Stranded-approval sweep | every poll tick | task `pending_approval`, approval already `approved`, worktree on this machine | `IC/daemon_stranded_approvals.go:24-103` |
| Landed-card sweep | every 10 min, cloud | pending card whose PR merged (approve) or closed (reject) | `IC/daemon_landed_cards.go:57-173` |
| Finalisation ledger | each completion delivery | replay of an at-least-once completion | `IC/task_finalize.go:141-239` |
| Orphan clearing | manual CLI | `pending_approval` tasks with no pending approval row | `CA/coordinator_approvals_orphans.go:60-147` |
| Terminal worktree cleanup | daemon start, local | worktrees of terminal or unknown tasks | `IC/daemon_tasks_worktrees.go:32-119` |

Details worth keeping:

- **Startup recovery is local only**, by ruling, because in cloud "a daemon restart
  says nothing about whether the task is alive" (`IC/daemon_tasks_init.go:20-22`).
  The incident is in section 8, item 4.
- **Backstop sweep defaults to report mode**: "The sweep's own risk is
  double-dispatching work that push already did, so the first thing it has to earn
  is a measurement of how often it would fire at all" (`IC/backstop_sweep.go:37-40`).
  An unrecognised mode value becomes `report`, not `dispatch` (`:67-82`).
- **Approval recovery is bounded**: a 7-day window, after which the approval is
  marked expired rather than fired, and 100 rows per boot
  (`IC/approval_handoff.go:69-77`). A partial pass is not recorded, so the next
  boot writes only the missing targets (`IC/approval_recovery.go:115-124`).
- **Orphans** means tasks stuck in `pending_approval` with no approval record to
  act on. The clearing command refuses to cancel one whose worktree still exists
  unless `--force` (`CA/coordinator_approvals_orphans.go:122-136`).
- **Ledger**: each effect is claimed, applied, resolved; at most 3 attempts, then a
  visible terminal `failed` (`IC/finalization_ledger.go:46-48`;
  `IC/task_finalize.go:218-229`). A ledger write failure is logged, not fatal,
  because effects are idempotent (`IC/task_finalize.go:172-177`).

### Designed but not wired at this commit (observed in the checked-out directories)

1. **Infra-class re-dispatch.** `StaleTaskDetector.WithReDispatcher` is called only
   in `stale_task_detector_redispatch_test.go`. The daemon builds the detector with
   `.WithObservatory(...)` only (`IC/daemon.go:456-457`). "Nil means 'report only'"
   (`IC/stale_task_detector.go:32-36`). **Inferred:** a stale cloud task is failed,
   never re-dispatched, and `MaxTaskExecutions = 2` (`IC/retry_chain.go:82`) has no
   effect.
2. **Ledger takeover sweep.** `FinalizationLedger.IsStale` and
   `StaleFinalizationClaim` (`IC/finalization_ledger.go:50-58`, `:145-151`) have no
   non-test caller. Comments refer to "the reconciliation sweep"
   (`IC/task_status_cas.go:18`, `IC/task_finalize.go:106-108`). **Inferred:** a
   finalisation that dies part-way is finished only if Pub/Sub redelivers.
3. **Evaluator gate on automation.** `ApprovalRequestRecord.AllowsAutomation`
   (`IC/evaluation_verdict.go:188-193`) has no non-test caller. See section 3.
4. **Ledger clear on re-dispatch, Firestore.** SQLite's `MarkTaskQueued` sets
   `finalization = NULL` (`IC/store_sqlite_transitions.go:41`), with a 14-line
   comment explaining that not doing so stranded eleven tasks (`:17-35`). The
   Firestore `MarkTaskQueued` updates only `status` and `queued_at`
   (`internal/storage/firestore/coordinator_transitions.go:25-47`), and no other
   Firestore code clears the field. **Inferred, not tested:** on the cloud store a
   re-dispatched task still carries its previous ledger. Production runs on
   Firestore.

---

## 3. Approvals

### How one is requested

**Observed.** On a normal successful completion (not failed, not `no_changes`, not
`blocked`, agent not `skip_approval`), finalisation creates an approval row
(`wantsApproval`, `IC/task_finalize.go:374-376`; `applyApproval`,
`IC/task_finalize_approval.go:43-184`) and posts an `approval_request` inbox message
(`notifyApproval`, `:191-222`). "The ping IS the product: an approval nobody hears
about gets approved blind from a context-free queue" (`:188-190`).

**Observed.** The approval id is derived from the task id, `apr-<task hash>`
(`IC/task_finalize_approval.go:27-29`), and created first-write-wins
(`IC/store_sqlite_approvals_if_absent.go:19-39`), so a redelivered completion
cannot create a second card.

**Observed.** If the agent's inbox has no reader and is not a declared human-triage
inbox, the notice is redirected to the `approvals` inbox and says so on the card
(`IC/task_finalize_approval.go:227`, `:246-267`, `:199-206`).

### What is recorded

**Observed.** `ApprovalRequestRecord`: `ID`, `TaskID`, `Type` (`merge` or
`merge_handoff`), `Description`, `ContextJSON`, `Status`, `ResolvedBy`, `CreatedAt`,
`ResolvedAt`, `TimeoutAt`, `AutoReject`, `Evaluation`
(`IC/store_sqlite_approvals.go:11-31`).

`ContextJSON` carries the evidence the decision is made on:
`handoff_targets`, `source_agent`, `session_id` (`IC/task_finalize_approval.go:56-62`);
`diff_stat`, `changed_files`, `diff`, or an explicit `diff_unavailable` reason
(`:67-81`); and `work_id`, a hash of the sorted changed files plus the diffstat
(`:83-92`; `IC/approval_rerun.go:40-48`).

**Observed.** A missing diff is never rendered as zero files: "a card that renders a
confident 'Files (0)' gets approved blind — measured, twice"
(`IC/task_finalize_approval.go:64-66`).

**Observed.** A decision writes an audit event, an OpenTelemetry span with
`approval.action`, `approval.channel`, `approval.by`, and `resolved_by` on the row
(`IC/approval_processor.go:112-121`, `:135`, `:197-202`). Rejection stores the
feedback as an event and posts it to the GitHub issue (`:458-483`).

**Observed.** A card resolved because its PR merged records
`pr-merge #<n> (<user>)` as approver, "so the audit trail names the merge — not an
operator who never clicked" (`IC/pr_landed.go:77-81`).

### Card kept in step with the work

**Observed.** When the approval row already exists, finalisation classifies the
collision by `work_id` (`IC/approval_rerun.go:74-109`):
same work, do nothing; pending card describing different work, refresh the card
(`RefreshPendingApproval`); resolved card and different work, reopen for a fresh
decision (`ReopenApprovalForNewWork`), which also resets the three handoff flags
(`IC/store_sqlite_approvals_if_absent.go:49-70`). With no evidence either side, the
standing decision is left alone: "reopening a decision on a guess is the worse
error" (`IC/approval_rerun.go:60-62`).

### Channels

**Observed.** One function handles every channel: "This is the SINGLE source of
truth for approval logic" (`IC/approval_processor.go:65-67`). Callers on disk: CLI
(`CA/coordinator_actions.go:96`, `:240`; `CA/coordinator_approvals_remote.go:272`),
the landed-card sweep (`IC/daemon_landed_cards.go:128`, `:156`), the manual
`prs --landed` command (`CA/coordinator_prs_landed.go:137`). The dashboard is
documented as a channel (`docs/docs/guides/coordinator.md:763-767`) but its handler
is in `internal/server`, not read.

GitHub labels are a further channel (`IC/approval_watcher.go:38-43`). Webhook
requests need a valid HMAC signature and fail closed if the secret is unset
(`IC/github_webhook.go:24-26`, `:45-60`); events sent by a bot are skipped (`:114`).

Dashboard roles are `Approver` and `Viewer` per workspace
(`docs/docs/guides/workspaces.md:32-37`).

### Who has authority

**Observed.** `CA/coordinator_approvals_authority.go:10-48`, with the decision in an
AILANG module, `internal/dashboard_transforms/approval_authority.ail`.

- Default: nobody but the operator. "the default is none, it always needs approval,
  but controller sessions and high-end models in mission loops like fable/astra
  have the authority to do approvals unattended" (`:13-15`, attributed to the
  operator, 2026-09-08).
- Identity comes from variables the driver sets, not from the session:
  `MISSION_CONTROL_ACTIVE`, `CONTROLLER_ID` (`:17-28`). A controller demoted to a
  fallback model loses the grant.
- Trusted models are matched as substrings: `fable`, `astra`, `opus` (`:57`).
- A row with no visible diff is not covered even under a grant (`:37-42`;
  `approval_authority.ail:158-172`).
- `AILANG_APPROVAL_POLICY` is `never` (default), `evaluated` (needs a visible diff
  and an evaluator PASS) or `always` (`CA/coordinator_approvals_json.go:40-67`;
  `CA/coordinator_approvals_authority.go:106-124`).
- If the AILANG module cannot be evaluated, the answer is refusal; there is
  deliberately no Go fallback (`CA/coordinator_approvals_engine.go:27-35`).

### How self-approval is prevented

**Observed. It is prevented by rule, not by enforcement, and the code says so.**

- The rule: a spawned role (designer, planner, executor, evaluator) is refused
  before any model is consulted, "because the agent that produced a change must
  never be the one that approves it" (`CA/coordinator_approvals_authority.go:32-36`;
  `approval_authority.ail:89-103`, `:116-120`).
- The disclaimer: "WHAT THIS IS NOT: enforcement. Every caller drives the same CLI
  against the same store, and any session can export any variable, so this decides
  what a session is TOLD it may do" (`CA/coordinator_approvals_authority.go:44-48`).
  And: "`agent_actionable` is ADVICE, not a control"
  (`CA/coordinator_approvals_json.go:31-35`).
- **Observed.** `ProcessApprovalRequest` takes `ApprovedBy` as a caller-supplied
  string and never compares it with `task.AgentID`
  (`IC/approval_processor.go:25-48`, `:67-128`). `resolveApprovalAuthority()` is
  used to label who decided (`CA/coordinator_approvals_remote.go:231-234`) and to
  annotate queue rows (`CA/coordinator_approvals_json.go:160`, `:177`). The one
  place on disk where a missing grant refuses an action is
  `prs --landed --fire-handoffs`: "--fire-handoffs dispatches agents, and that is
  an approval decision" (`CA/coordinator_prs_landed.go:39-43`). The remote approve
  command has no such check (`CA/coordinator_approvals_remote.go:184-306`, read),
  and `.Granted` is referenced nowhere else in `cmd/ailang`.
  **Inferred:** nothing in the approve path refuses an approval for lack of
  authority; a role that ignored its instructions could approve its own task.
  The dashboard's own check (`internal/server`) was not read.

What does bind an executing agent mechanically, as distinct from an approver:

- **Completion binding.** A completion must name the agent the task was dispatched
  to, and the task must be in a state a dispatched run can report from
  (`IC/completion_binding.go:87-108`). Its stated limit: "It does not stop an
  executor that knows another task's agent ID" (`:21-23`).
- **Topology from config only.** Handoff targets come "from the agent registry —
  never from model output and never from the sending message"
  (`IC/task_finalize.go:397-399`).
- **Permission tier from config only.** `ResolveWorkTier` reads the agent registry,
  defaults to the strict tier, and ignores task type because type is "a substring
  match over message text" that the sender controls (`IC/work_tier.go:9-22`,
  `:53-64`).
- **Auto-merge floor.** Section 5.

### Evaluator verdict

**Observed.** A closed three-value type, `PASS`, `FAIL`, `UNAVAILABLE`; anything
unparsable or absent becomes `UNAVAILABLE` (`IC/evaluation_verdict.go:23-30`,
`:81-116`, `:148-162`). It is written onto the parent task's approval
(`IC/daemon_evaluator.go:25-53`). A verdict arriving after a human already decided
is still attached, marked late (`IC/store_sqlite_approvals.go:416-436`). The verdict
is meant to block automation and never the human
(`IC/evaluation_verdict.go:12-16`).

**Observed.** The verdict is attached only from the local daemon path
(`IC/daemon_tasks_exec_run.go:522`, `:658`). The shared finaliser has no evaluator
effect (`IC/task_finalize.go:160-169`). The one consumer of the verdict on disk is
the CLI's `coversRow` under policy `evaluated`
(`CA/coordinator_approvals_authority.go:192-215`).
**Inferred:** on the cloud plane the verdict is not attached by the code I read.

### Secret approvals (a separate, blocking gate)

**Observed.** An agent's `secret(ref)` call blocks; the request carries only the
reference, a purpose and the agent; timeout denies (`IC/secret_approval.go:21-22`,
`:38-63`). Approve/Deny buttons carry HMAC single-use tokens
(`docs/docs/guides/secret-approvals.md:166-176`). The guide's own status box says
the path is "Code-complete — deploy-gated" (`:30-37`).

---

## 4. Pipelines and handoffs

### Is there a fixed chain?

**Observed. No, in code; yes, by configuration and legacy defaults.**

- The mechanism is one field per agent: `trigger_on_complete`, a list of agent ids
  (`IC/agent_registry.go:119`). Any graph can be declared.
- `PipelineConfig` declares stages once and binds them to projects; expansion sets
  stage *i*'s trigger to stage *i+1* (`IC/pipeline_config.go:42-46`, `:86-89`). A
  collision with a hand-written agent is an error (`:74-76`). The reason given: six
  cloned entries had "zero messages ever received, drifting from the primary chain"
  (`IC/pipeline_config.go:8-13`).
- The chain actually configured is design-doc-creator, sprint-planner,
  sprint-executor, sprint-evaluator (`IC/task_finalize.go:18-20`;
  `IC/pipeline_full_chain_test.go:55-70`). In that fixture the first two edges are
  gated, executor to evaluator is automatic, and the evaluator skips approval.
- A legacy fixed chain still exists: `TaskChain` "manages the pipeline: design-doc →
  sprint-planner → sprint-executor" (`IC/task_chain.go:15-16`), and `TaskStage`
  (design, sprint, implementation, merge) is marked deprecated in favour of agent
  ids (`IC/store.go:122-146`).
- "Cascade" in this package means package dependency updates in topological order,
  with a failure breaker and a cost cap (`IC/cascade_scheduler.go:10-13`,
  `:114-117`, `:152-161`). It is not the agent chain.

### Two dispatch moments

**Observed.** Edges are partitioned (`IC/approval_handoff.go:18-40`):

- **Auto edges** (`auto_approve_handoffs`, or a per-edge `auto_approve_handoff_to`)
  dispatch at completion (`autoHandoffTargets`, `IC/task_finalize.go:400-415`).
- **Gated edges** are embedded in the approval's `handoff_targets` and dispatch when
  it is approved (`approvalHandoffTargets`, `IC/approval_handoff.go:87-99`;
  `dispatchApprovalHandoffs`, `:481-531`).

"The two functions partition TriggerOnComplete, so a target dispatches once and at
one moment" (`IC/approval_handoff.go:38-40`). No handoff follows a failure,
`no_changes` or `blocked` (`IC/task_finalize.go:388-393`).

### How one stage's output is bound to the next

**Observed. "Approval handoff"** is one inbox row. Its fields
(`IC/approval_handoff.go:141-153`): `FromAgent: "coordinator"`, `ToInbox`,
`MessageType: handoff`, `Title`, `Payload`, `CorrelationID` = parent task id,
`ParentTaskID`, `ChainID`.

- **Identity.** The row id is `"<task>:handoff:<target>"`
  (`IC/task_finalize_approval.go:34-36`), suffixed with the first 16 characters of
  the approval's work id when there is one (`IC/approval_handoff.go:58-67`). It is
  written first-write-wins, and only the call that created the row notifies
  (`:201-228`). "ONE HANDOFF, ONE ROW" (`:168`).
- **Suppression.** An approval can be resolved with its handoffs withheld, in the
  same write (`IC/store_sqlite_approvals.go:178-192`). The check lives in the one
  sender all approval-path producers share (`IC/approval_handoff.go:234-256`).
- **Body.** `handoffContent` (`IC/approval_handoff.go:284-327`) gives the next agent:
  the parent task id; the GitHub issue if there is one; `Design doc:` and
  `Sprint plan:` paths; other artifacts; `Work branch:` and `Base branch:`; and the
  original request unwrapped from nested envelopes (`rootRequestOf`, `:409-420`).

**Observed. Two sources name the artifact**, in priority order
(`IC/approval_handoff.go:329-374`):

1. An **output marker** the agent prints, `DESIGN_DOC_PATH:` or
   `SPRINT_PLAN_PATH:`, parsed from the transcript
   (`IC/stage_execution.go:363-374`) and stored on the task
   (`IC/task_chain.go:117`, `:256`). This is "model-dependent: a run that does the
   work and forgets the marker records nothing" (`IC/approval_handoff.go:331-336`).
2. The approval's `changed_files`, computed from the diff, filtered through the
   agent's **declared** `artifact_patterns`. "It is computed from the diff, not
   printed by a model" (`:338-342`).

**Observed. "Artifact discovery"** is `git diff` against the base commit recorded
at worktree creation, plus uncommitted, staged and untracked files, filtered by
glob (`IC/artifact_discovery.go:45-83`, `:116-163`). The file's own header:
"preferred over parsing output markers, as git accurately tracks all file changes"
(`:11-12`). The scratch directory `.ailang-scratch` is excluded so probe files
never reach the card (`:56-68`, `:88`).

**Observed. "Completion binding"** is not a stage-to-stage link. It binds a
completion message to the dispatch it claims to finish: agent id must match, and
the task's status must admit a completion (`IC/completion_binding.go:9-32`,
`:87-108`). A rejected completion is acknowledged and dropped with the log prefix
`COMPLETION_REJECTED` (`IC/pubsub_completion_handler.go:107-115`).

**Observed. Deduplication had to learn about stages.** Handoffs embed the parent's
request, so each simhashed to its own parent and was suppressed. `DedupScope` now
excludes a different agent and the parent task (`IC/task_dedup.go:65-92`,
`:99-120`).

**Observed. Rejection.** A rejected task is marked `rejected`; a feedback message
goes to the same agent's inbox with `ParentTaskID` and `Iteration + 1`
(`IC/approval_processor.go:486-549`). Agent-to-agent retries stop at 3 iterations;
human rejections from CLI or dashboard have no limit
(`IC/human_interaction.go:141-164`).

### Two completion paths still exist

**Observed.** The cloud path goes through `FinalizeTaskCompletion`
(`IC/pubsub_completion_handler.go:175-181`). The local daemon path is still inline
in `executeTask` with unconditional `MarkTask*` writes and a plain
`CreateApprovalRequest` (`IC/daemon_tasks_exec_run.go:504-545`, `:609`). Moving the
daemon onto the orchestrator is recorded as "deliberately outstanding"
(`CA/coordinator_cloud_evidence.go:101-106`). The local path has no `no_changes`
arm, and a test pins that (`IC/completion_matrix_test.go:285-316`).

---

## 5. Isolation and merge-back

### Local lane

**Observed.** One git worktree per task. Branch `coordinator/<task-id>`, path
`<state>/worktrees/<agent-id>/<task-id>` (`IC/worktree.go:121-123`;
`IC/daemon_tasks_init.go:236`). The base branch's commit hash is captured before
creation, because "the branch ref may move later, but this commit is fixed"
(`IC/worktree.go:112-119`). Default cap is 3 worktrees per manager (`:65-67`);
hitting it leaves the task queued rather than failing it (`:15-17`).

**Observed.** After the run, uncommitted changes are committed by the coordinator:
"Agents may forget to commit, so we do it automatically before approval"
(`IC/daemon_tasks_exec_run.go:419-424`; `IC/daemon_tasks_worktrees.go:121-161`).
The worktree is preserved until a decision.

**Observed.** Merge on approval (`IC/approval_processor.go:302-400`): auto-commit,
then `MergeWorktree`, which checks out the target branch in the main repository and
runs `git merge --no-edit <branch>` (`IC/merge.go:59-66`, `:206-211`). On conflict
the merge is aborted, the conflicting files are returned, and the approval reports
failure (`IC/merge.go:68-75`; `IC/approval_processor.go:318-325`). On success: task
`completed`, chain and stage closed, GitHub issue closed, worktree and branch
removed (`:336-394`). Target branch priority: explicit parameter, agent's
`merge_branch`, then `dev` (`:93-104`).

**Observed.** On permanent rejection the worktree is deleted
(`IC/approval_processor.go:585-588`). The guide says rejection preserves it
(`docs/docs/guides/coordinator.md:750`); the code path that preserves it is the
re-trigger branch, which does not clean up (`:488-552`).

**Inferred.** `MergeWorktree` changes the checked-out branch of the operator's main
repository (`IC/merge.go:60`). I did not find a guard for a dirty main working
tree; I did not look for one beyond this file.

### Cloud lane

**Observed.** No worktree; the coordinator image has no git
(`IC/daemon_tasks_init.go:228-247`). Each job does a shallow clone into
`/workspace/<task-id>`, records the clone point, and creates
`coordinator/<task-id>` (`CA/coordinator_cloud.go:421`, `:439-441`, `:461`). With
`AILANG_PUSH_BRANCH` set it commits straight to that branch with no PR
(`:319-322`, `:457-459`); such a dispatch never gets the permissive tier
(`IC/work_tier.go:48-59`).

**Observed.** The wrapper commits whatever the agent left uncommitted, pushes if
commits are still local, and opens the PR (`CA/coordinator_cloud.go:566-606`,
`:651-666`; `CA/coordinator_cloud_github.go:36`). An agent may also commit or push
itself; the wrapper still opens the PR in that case (`CA/coordinator_cloud.go:644-648`).
With no commits since the clone point, no branch or PR is created (`:656-657`).

**Observed. Auto-merge** is GitHub's native auto-merge, enabled only when the agent
is configured for it and every changed file both matches a declared artifact
pattern and ends in `.md` (`CA/coordinator_cloud_github.go:114-139`, `:161-184`).
"Patterns declare SCOPE, not safety … The floor means auto-merge can only ever land
documents" (`:155-160`). If the diff cannot be classified, it is not enabled
(`:119-124`).

**Observed. Merge after approval** is a separate reconcile step. `DecidePR`
(`IC/pr_reconcile.go:69-127`) maps task status to merge, close or leave, and
refuses a merge when: there is no agent config; the agent declares no
`artifact_patterns`; the PR reports no files; any file is outside the declared
patterns; or the approval card's file list and the branch's file list differ as
sets. `coordinator prs` is "DRY RUN BY DEFAULT. Merging is the one irreversible
action in this path" (`CA/coordinator_prs.go:12-14`).

**Observed.** The reverse direction also exists: a PR merged by any route approves
the card and fires its handoffs; a PR closed unmerged rejects it
(`IC/daemon_landed_cards.go:3-10`; `IC/pr_landed.go:23-65`). The branch name is the
only link, matched exactly (`IC/pr_landed.go:20-22`).

**Observed. Cross-lane.** A task's lane is declared (`execution_lane`) or inferred
from the shape of `workspace` (`IC/execution_lane.go:74-86`). An approval given on
one machine for a worktree on another is finished by the owning machine's sweep
(`IC/daemon_stranded_approvals.go:7-20`).

---

## 6. Completion verified, as opposed to claimed

**Observed.** The status of a cloud run is computed by coordinator-owned wrapper
code from git evidence, not reported by the model.

1. **Diff decides.** `ClassifyCompletionStatus(changedFiles, branchPushed,
   expectChanges)` (`IC/task_status.go:126-134`), called at
   `CA/coordinator_cloud.go:285-286` with files discovered from the clone point.
   No changed files where changes were expected gives `no_changes`, a distinct
   terminal status. It is a status and not a flag on `completed` so that an old
   consumer "reads it as NOT completed, i.e. as not-success"
   (`IC/task_status.go:15-19`).
2. **Whether changes were expected comes from config**, the agent's
   `acknowledge_only` (`IC/agent_registry.go:143-148`), not from message content.
   Unset or malformed means changes were expected (`CA/coordinator_cloud.go:282-285`).
3. **The agent's one voice is `BLOCKED:`**, and it is honoured only when the run
   changed no files: "the files are the stronger evidence"
   (`CA/coordinator_cloud.go:295-309`; `IC/task_blocked.go:57-78`). "nothing DEPENDS
   on the marker being present. An agent that forgets it gets today's behaviour"
   (`IC/task_blocked.go:26-30`).
4. **Evidence is two immutable commit SHAs**, the diffstat, the file list and a
   capped patch (`CA/coordinator_cloud_evidence.go:31-37`, `:49-86`). Without both
   SHAs the card says the diff is unavailable
   (`IC/task_finalize_cloud_strategy.go:25-37`). SHAs rather than a branch name
   because "a branch can move or be deleted between attempts" 
   (`CA/coordinator_cloud_evidence.go:21-24`).
5. **Producer and consumer share a contract list** of the four statuses an executor
   may publish, with a test that the consumer accepts every one
   (`IC/task_finalize_cloud_strategy.go:39-60`). An unknown status is not defaulted
   to success (`:62-79`).
6. **The completion is bound to its dispatch** (section 4).
7. **Second check before merge**: declared scope, and card equal to branch
   (section 5).
8. **Independent evaluation**: a separate evaluator agent judging the pushed branch,
   with a closed verdict type (section 3).
9. **`pending_approval` is not done.** The observatory maps it to completed
   (`IC/task_status.go:78`), but terminality does not (`:57`).

**Observed limits.**
- The local path trusts `result.Success` from the executor
  (`IC/daemon_tasks_exec_run.go:403`) and has no `no_changes` outcome.
- Auto-commit captures whatever is in the worktree; nothing in the coordinator
  runs the project's tests. "Tests pass" is a line in the guide's approval advice
  (`docs/docs/guides/coordinator.md:1418-1422`), not a gate I found in code. On the
  cloud lane, required checks are GitHub's, applied through native auto-merge
  (`CA/coordinator_cloud_github.go:110-113`).
- The structured markers `IMPLEMENTATION_COMPLETE: true` and friends are agent
  claims parsed by substring (`IC/stage_execution.go:376-379`).

---

## 7. Links to the outside

| Link | Identifier on the task | Cite |
|---|---|---|
| Message that created it | `MessageID`; task id is derived from it | `IC/daemon_tasks_polling.go:140`, `:195` |
| Reply to the sender | completion notice with `CorrelationID = task.MessageID` | `IC/pubsub_completion_handler.go:233-240` |
| Parent stage | `ParentTaskID`, set from the handoff message | `IC/daemon_tasks_polling.go:197` |
| Chain and stage (observatory) | `ChainID`, `StageID`; chain created from the message or inherited from the parent | `IC/daemon_tasks_polling.go:288-345` |
| Dashboard thread | `ThreadID` | `:244-255` |
| GitHub issue | `GithubIssue`, `GithubRepo`; issue is claimed with a label, watched for approval labels, closed on merge | `IC/task_chain.go:56-105`; `IC/approval_processor.go:374-389` |
| GitHub PR | none stored; found by exact branch name `coordinator/<task-id>` | `IC/pr_reconcile.go:178`; `IC/pr_landed.go:20-22` |
| Approval | `apr-<task hash>`, derived | `IC/task_finalize_approval.go:27-29` |
| Design doc | `DesignDocPath`, a file path string | `IC/store.go:52` |
| Sprint plan | `SprintPlanPath`, a file path string | `IC/store.go:53` |
| Trace | `task_id` / `parent_task_id` attributes, because trace context is not propagated | `.claude/rules/coordinator.md:54-59` |

**Observed. There is no design-doc id and no sprint id on a task.** A grep for
`sprint_id`, `SprintID`, `design_doc_id`, `DesignDocID` over `internal/coordinator`
and `cmd/ailang/coordinator*.go` returns nothing. The tie between a task and a
design doc or sprint is:

- two path strings, filled from a marker the agent prints or left empty
  (`IC/approval_handoff.go:331-336`: nineteen design-doc tasks had none);
- the handoff body, which quotes those paths as text
  (`IC/approval_handoff.go:293-298`);
- glob patterns naming where such files live. The legacy defaults are
  `design_docs/**/*.md` and `.ailang/state/sprints/*.json` for the planner
  (`IC/agent_registry.go:629`), with markers `SPRINT_PLAN_PATH:` and
  `SPRINT_JSON_PATH:` (`:606`).

**Observed.** `SPRINT_JSON_PATH:` is declared as a marker, and the agent is told to
print it, but no non-test code path on disk reads its value. The fixed extraction
covers `DESIGN_DOC_PATH`, `SPRINT_PLAN_PATH`, `BRANCH_NAME` and
`IMPLEMENTATION_COMPLETE` (`IC/stage_execution.go:363-380`); a generic
`ParseOutputMarkers` exists (`:290-303`) whose only non-test caller is
`HasMarkerValue` (`:352-359`), itself uncalled. The sprint JSON file appears otherwise
only as an incident example: the executor found
`.ailang/state/sprints/sprint_M-OPENROUTER-EU-ROUTING.json` missing
(`IC/task_blocked.go:12-16`).

**Inferred.** The design-doc milestone name (for example `M-OPENROUTER-EU-ROUTING`)
is the de facto key between a design doc, its sprint JSON and the work, but it
lives in file names and prose. The coordinator does not hold it. A task cannot be
queried by design doc or sprint.

**Observed. Missions.** No task field references a mission, and no mission table
references a task (section 1). They share a database file only.

**Observed. Messages.** Inbox routing decides the agent: the sender picks an inbox,
the registry picks the agent (`IC/work_tier.go:18-22`). An inbox with no agent is
either declared human-triage or logged as `CONFIG GAP`
(`IC/daemon_tasks_polling.go:101-110`). Completion notices and approval requests in
an agent's inbox are never turned into tasks (`:67-77`).

---

## 8. Ten incident comments

Each records a date and a measured cost, next to the code that fixes it.

1. **Exit code is not work landed.** `IC/task_status.go:11-13`: "`completed` used to
   mean 'the executor exited 0', which is not the same as 'work landed' and could
   not be told apart from it. Measured store-wide: 1,249 completion records, 16
   marked completed, 6 that ever changed a file."

2. **Two implementations of one thing.** `IC/task_finalize.go:15-20`: "The daemon
   path performed ten side effects; the cloud path — the only one production runs —
   performed two … The configured pipeline … has therefore never once advanced past
   its first stage." With `IC/finalize_parity_test.go:15-17`: "This defect existed
   for four months because nothing could see the two completion paths side by side."

3. **A claim that could not refuse.** `IC/store.go:226-228`: "Measured on the prod
   plane 2026-09-17 20:06: one task, one creation, and THREE `Cloud dispatch` lines
   inside 500ms, each producing its own Cloud Run execution, its own commit and its
   own completion."

4. **Restart recovery that killed live work.** `IC/daemon_tasks_init.go:358-364`:
   "Measured in prod 2026-09-02: task-c8126248 dispatched at 12:33:57, the
   coordinator scaled to zero at 12:49:05, the job finished and opened PR #56 at
   12:50:40, a new instance cold-started and cancelled the task at 12:50:45 … The
   work succeeded and nobody was told."

5. **Dedup against its own parent.** `IC/task_dedup.go:76-81`: "every handoff
   simhashes to its own parent, and a parent at handoff time is always `completed`,
   which suppresses. A handoff could therefore NEVER dispatch. That is a second,
   independent bug behind the approval-path fix of 2026-09-07 — which is why fixing
   that one did not make the pipeline run."

6. **Printed, not stored.** `IC/approval_processor.go:192-196`: "'handoffs NOT fired'
   used to be printed and not stored, so the next coordinator boot found the
   approval 'without triggered handoffs' and fired them — 22 on 2026-09-23 15:17,
   17 of which ran sprint-planner on stale work."

7. **The card and the branch came apart.**
   `IC/store_sqlite_approvals_if_absent.go:75-83`: "Measured 2026-09-15 on
   task-c0ca6301 … The operator approved a card describing a file that no longer
   existed and merged a file the card never named."

8. **A zero timestamp read as 292 years.** `IC/backstop_sweep.go:186-193`:
   "Measured in prod 2026-08-31: one real message at 06:28 became 13 notices and 5
   Cloud Run executions in 28 minutes … Zero here means time.Since(zero) ≈ 292
   years, so the task is marked timed-out on the first tick after dispatch."
   The fix refuses to act on an unknown age (`IC/stale_task_detector.go:225-231`).

9. **The next stage was handed the wrong branch.** `IC/approval_handoff.go:311-317`:
   "Measured 2026-09-14: sprint-evaluator … was told 'Branch: dev', found nothing to
   evaluate, ran `git diff origin/dev...HEAD` on its OWN empty branch and returned
   FAIL 0/100 against a sprint it had never been handed. A wrong verdict on
   unexamined work is worse than no verdict."

10. **A notice sent to nobody.** `IC/task_finalize_approval.go:238-241`: "Measured
    2026-09-17 on task-c063b6d2: its agent `daneel-design-ailang` was deleted in the
    12 Sept revert, so the notice went to that dead inbox and the approval waited
    SEVEN DAYS for a design doc that had already been merged by PR #1138."

Others of the same kind, for reference:

- A sweep that swallowed its own error: "A sweep that cannot look is not a sweep
  that found nothing" (`IC/daemon_stranded_approvals.go:65-70`).
- A guard that refused every honest approval for sixteen days: "83 pending on prod
  by 2026-09-23" (`CA/coordinator_approvals_remote.go:255-263`).
- A queue that was mostly ledger: "57 of 77 pending cards on the prod plane had a
  merged coordinator PR" (`IC/pr_landed.go:8-10`).
- Sixteen tasks awaiting an approval that did not exist
  (`CA/coordinator_approvals_orphans.go:13-15`).
- A ticker inside a process that lives seconds: "consecutive instance lifetimes of
  34s and 12s" (`IC/backstop_sweep.go:94-101`).
- "92 of 99 chains were `active`, the oldest since 2026-04-27"
  (`IC/stale_task_detector.go:167-170`).
- A sender could pick its own permission tier by writing "please fix this"
  (`IC/work_tier.go:9-16`).
- One config field answering two questions (`IC/execution_lane.go:12-27`).
- The rig offline for 38 hours unnoticed
  (`docs/docs/guides/coordinator-workers.md:179`).
- A model's forgotten marker broke a downstream gate "for nineteen tasks — a
  dependency on a model remembering, which is the shape to avoid"
  (`IC/task_blocked.go:28-30`).

**Inferred, across these.** Four causes recur: two implementations of one concept
drifting apart; a silent default standing in for missing data; a status or flag
that was displayed but not stored; and a recovery routine with wider authority than
the thing it recovers. The code's standing answers are per-status tables with
exhaustiveness tests, deterministic ids with first-write-wins, compare-and-set
writes, and sweeps that start in report mode.

---

## 9. One-line role per file or group

`internal/coordinator/`

| File or group | Role |
|---|---|
| `store.go` | `TaskRecord`, the status constants, and the `Store` interface both backends implement |
| `task_status.go`, `task_status_cas.go` | terminality and observatory tables; completion classification; compare-and-set status write |
| `store_sqlite.go`, `store_sqlite_schema.go`, `store_sqlite_queries.go`, `store_sqlite_events.go` | SQLite backend: schema, additive and versioned migrations, queries, event log |
| `store_sqlite_transitions.go` | the status-moving functions, including the atomic claim |
| `store_sqlite_approvals.go`, `store_sqlite_approvals_if_absent.go` | approval rows: create-if-absent, resolve, reopen, refresh, handoff flags, verdict attach |
| `task_dedup.go` | when an existing task suppresses an identical new request |
| `task_blocked.go` | the `BLOCKED:` marker an agent uses to say it could not start |
| `finalization_ledger.go`, `finalization_ledger_store.go` | per-task record of which completion effects have been applied |
| `task_finalize.go`, `task_finalize_approval.go`, `task_finalize_cloud_strategy.go` | the shared completion orchestrator: outcome matrix, approval creation, auto handoffs, cloud diff source |
| `pubsub_completion_handler.go`, `completion_binding.go` | cloud completion intake; refusal of completions not bound to their dispatch |
| `approval_processor.go` | the one approve/reject path for every channel; local merge and finish |
| `approval_handoff.go`, `approval_recovery.go` | the single handoff envelope and sender; boot replay of owed handoffs |
| `approval_rerun.go`, `approval_diff.go` | work id; telling a replay from a re-run; patch summarising |
| `approval_checkpoint.go`, `secret_approval*.go`, `secret_notification.go` | in-memory blocking approval, used for the secret gate and its phone notification |
| `approval_watcher.go`, `github_webhook.go` | GitHub labels as approvals, by polling or signed webhook |
| `evaluation_verdict.go`, `daemon_evaluator.go` | closed evaluator verdict type and its attachment to the parent's approval |
| `pipeline_config.go` | pipelines declared as data and expanded into chained agents |
| `task_chain.go`, `task_chain_agent.go`, `stage_execution.go`, `templates.go` | legacy and generic stage handling: GitHub comments, directive building, marker parsing |
| `agent_registry.go`, `agent_registry_effective.go`, `agent_config.go`, `package_agents.go` | agent schema, inbox lookup, legacy defaults, per-package agent derivation |
| `work_tier.go`, `execution_lane.go`, `autonomy_router.go`, `dispatch_provider.go`, `model_resolution.go`, `retry_chain.go` | trusted per-agent decisions: permission tier, lane, autonomy by change class, executor, model chain, failure class |
| `daemon.go`, `daemon_lifecycle.go`, `daemon_tasks_init.go` | process lifecycle, wiring, the poll loop, startup recovery |
| `daemon_tasks_polling.go`, `watcher.go`, `message_adapter.go`, `pubsub_adapter.go` | message intake and task creation |
| `daemon_tasks_exec.go`, `daemon_tasks_exec_run.go`, `cloud_dispatcher.go` | claim and dispatch; the local run and its inline completion path |
| `task_executor.go`, `provider*.go` | executor selection and invocation |
| `worktree.go`, `daemon_tasks_worktrees.go`, `merge.go`, `artifact_discovery.go` | per-task worktrees, cleanup, merge with conflict report, changed-file discovery |
| `pr_reconcile.go`, `pr_landed.go`, `daemon_landed_cards.go` | pure decisions for card to PR and PR to card; the standing sweep |
| `stale_task_detector.go`, `backstop_sweep.go`, `daemon_stranded_approvals.go` | the three cloud-era recovery loops |
| `unrouted_bounce.go`, `triage_router.go`, `triage_rubric.go`, `feedback_gate_*.go`, `dispatch_read_marking.go` | intake hygiene: bounce to sender, triage, abuse gate, read marking |
| `cascade_scheduler.go` | package-update ordering, failure breaker, cost cap |
| `mission_attempt.go`, `mission_work_item*.go` | lease-and-fence tables for mission iterations, separate from tasks |
| `heartbeat*.go`, `tag_matcher.go`, `instances_*.go` | worker liveness, tag routing, resident-instance idle sweep |
| `observatory_sync.go`, `event_*.go`, `*_broadcaster.go`, `history_collector.go`, `resource_tracker.go` | reporting: chains, event streams, version history, resource metrics |
| `daemon_http.go`, `daemon_github.go`, `github_poster.go`, `github_comments.go` | HTTP surface and GitHub I/O (not opened) |

`cmd/ailang/`

| File or group | Role |
|---|---|
| `coordinator.go` | subcommand switch: start, stop, status, pending, approvals, approve, reject, reopen, cancel, retry, prs, pipeline, lint, agent-check, execute-job, workers and others (`:27-81`) |
| `coordinator_approvals_authority.go`, `_engine.go`, `_json.go`, `_remote.go`, `_orphans.go` | who may decide unattended; the queue as JSON; approve on a named plane; stuck-row clearing |
| `coordinator_cloud*.go` | `execute-job`, the wrapper that runs inside the Cloud Run Job: clone, run, commit, push, PR, auto-merge, evidence, completion |
| `coordinator_prs.go`, `coordinator_prs_landed.go` | reconcile PRs with task decisions, dry run by default |
| the rest | lifecycle, config, lint, agent listing and checks, browse, inspect (not opened) |

Docs

| File | Role |
|---|---|
| `docs/docs/guides/coordinator.md` | main guide; older sections describe the local, three-stage, GitHub-label flow and lag the code |
| `coordinator-setup.md` | adding agents for another repository |
| `coordinator-workers.md` | tag routing and heartbeats across hosts |
| `workspaces.md` | dashboard tenancy and the Approver/Viewer roles; not git workspaces |
| `secret-approvals.md` | phone approval of secret resolution |
| `.claude/rules/coordinator.md` | path-scoped rule file: executor contract, audit steps, the three databases |
| `.claude/skills/coordinator-helper/SKILL.md` | operator how-to; holds the only lifecycle diagram |

---

## What a redesign could take from this

**Inferred throughout.**

1. The task machine has no declared transition set, and its incident list is
   mostly unguarded writes. The mission tables in the same package show the
   alternative: owner token, lease, version, digests, one transaction.
2. Status meaning as exhaustive tables, each with a test that every status is
   classified, caught drift repeatedly. A dead status (`duplicate`) still costs an
   entry in five tables.
3. Outcome is computed from the diff by trusted code. The agent contributes one
   optional marker that is ignored if files changed.
4. The approval card stores the evidence and a work id, and the merge is refused if
   the branch no longer matches the card.
5. Authority over approval is identity-first and explicitly unenforced. The
   mechanical bindings are on the executor side.
6. Tasks carry no design-doc or sprint identifier. The link is a path string that
   depends on the model printing a marker, with a diff-derived fallback.
7. Several mechanisms are specified, unit-tested and not connected (re-dispatch,
   ledger takeover, the automation gate, `attempt_count`). A reader of comments
   alone would believe they are live.
