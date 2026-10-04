# AILANG messaging as work intake and coordination — survey notes

Source: sparse, blobless clone of `sunholo-data/ailang` `dev` at `2a1f3f295` (2026-10-03).
All paths are relative to the repo root. Nothing was built or run; every statement about
behaviour is from reading source and docs.

Markers: **[O]** observed in the cited file. **[I]** my inference from observed facts.
**[D]** a claim made by a doc or comment that I did not check against code.

## 0. Reading ledger

**Read in full**

- Docs: `docs/internal/message-plane-topology.md`, `docs/internal/github-notification-hygiene.md`,
  `docs/docs/guides/agent-messaging.md`, `collaboration-hub.md`, `notification-channels.md`,
  `notify-daemon.md`
- Skills: `.claude/skills/agent-inbox/SKILL.md`, `resources/message_format.md`,
  `resources/reference.md`, `scripts/check_messages.sh`; `.claude/skills/collaboration-hub/SKILL.md`,
  `resources/id_relationships.md`; `.claude/skills/ailang-core-triage/SKILL.md`;
  `.claude/skills/github-issue-triage/SKILL.md`
- `scripts/check_autoclose.sh`
- `internal/messaging/`: `messages.go`, `schema.go`, `inbox.go`, `inbox_flow.go`, `inbox_routing.go`,
  `store.go`, `message_store.go`, `notfound.go`, `agents.go`, `triage.go`, `simhash.go`,
  `github.go`, `github_pr.go`, `envelope.go`, `envelope_builder.go`, `config.go`,
  `pubsub_notifier.go`, `pkg_schema.go`, `pkg_status.go`, `pkg_routing.go`, `pkg_events.go`
- `cmd/ailang/`: `messages.go`, `messages_crud.go`, `messages_send.go`, `messages_github.go`,
  `messages_health.go`, `messages_health_window.go`, `messages_deadline.go`, `messages_renotify.go`,
  `messages_triage.go`, `messages_send_inbox_guard.go`, `messages_inboxes.go`, `messages_util.go`,
  `mission_ticket.go`
- `internal/storage/backend.go`, `internal/storage/firestore/client.go`,
  `internal/storage/firestore/messaging_inbox.go`
- `internal/config/storage.go`, `internal/config/cloud.go` (lines 1–200) via `git show`
- `internal/coordinator/`: `daemon_github.go`, `message_adapter.go`, `dispatch_read_marking.go`,
  `triage_router.go`, `triage_rubric.go`, `task_dedup.go`

**Skimmed (part read, or grep for comments and signatures)**

- `docs/docs/guides/cloud-messaging-integration.md` — lines 1–650 in full, then the sections at
  846–892, 1067–1135, 1195–1296, 1467–1516, 1665–1750; the client examples and website-builder
  sections were not read
- `internal/messaging/`: `search.go` (1–120, 300–436), `search_neural.go`, `embedder.go` (outline
  plus 165–215), `schema_migrations.go` (74–110, 476–500 and a grep), `threads.go` (1–140),
  `hierarchy.go` (1–80), `client.go`, `approvals.go`, `history.go`, `metrics.go`,
  `image_extractor.go` (headers only)
- `cmd/ailang/`: `messages_search.go`, `messages_activity.go` (1–60), `daemon.go` (90–220),
  `pkg_publish.go` (300–375), `storage.go` (78–112)
- `internal/storage/firestore/`: `messaging.go` (1–120), `messaging_search.go` (comments),
  `messaging_convert.go` (85–133), `finalize_if_absent.go` (96–141)
- `internal/coordinator/`: `github_poster.go` (1–135 and outline), `unrouted_bounce.go` (1–150,
  156–238), `backstop_sweep.go` (1–175), `daemon_tasks_polling.go` (130–150, 440–455, 687–747),
  `approval_processor.go` (340–395), `task_chain.go` (495–545), `feedback_gate_wiring.go` (1–60)
- `scripts/hooks/session_start.sh` (38–60, 140–206, 278–300, 462–520)
- `CLAUDE.md` (8–40), `AGENTS.md` (5–9), `docs/docs/guides/development-workflow.md` (225–275),
  `docs/docs/guides/coordinator.md` (431–476, 510–614),
  `.claude/skills/mission-control/resources/gate-4-record.md` (108–128),
  `gate-0-preflight.md` (52–72), `.github/workflows/ci.yml` (318–359, via `git show`),
  `docs/internal/cloud-coordinator-config.md` (grep only)

**Not opened**

- All `*_test.go` files in `internal/messaging/` (20 files) and `cmd/ailang/messages*_test.go`
- `cmd/ailang/messages_help.go`
- `internal/messaging/embedder_gemini.go`, `embedder_openai.go`, `metrics.go` body, `history.go` body
- `internal/storage/firestore/`: `messaging_approval.go`, `messaging_metrics.go`, `cache.go`, every
  `coordinator_*.go`, `observatory_*.go`, `feedbackgate_stores.go`, `task_directives.go`
- `.claude/skills/agent-inbox/TEST_PROCEDURE.md`; `.claude/skills/collaboration-hub/resources/`
  `database_diagnosis.md`, `hierarchy_algorithm.md`, `rest_api_reference.md`, `scripts/diagnose.sh`
- `scripts/test_check_autoclose.sh`, `make/*.mk` (the `check-autoclose` target itself; not on disk)
- `internal/feedbackgate/`, `internal/pubsub/`, `internal/notify/`, `internal/daemon/`,
  `internal/simhash/`, `internal/server/` (not in the sparse checkout)
- The coordinator daemon and mission loop beyond the files listed above (other agents have them)

**Limits on negative claims.** The clone is blobless, so a tree-wide `git grep` fetches every blob.
I stopped one after it had covered `cmd/`. Every "no caller" or "nothing sets this" statement below
is scoped to the directories on disk: `cmd/`, `internal/{coordinator,messaging,mission,storage}`.

---

## 1. The message schema

### 1.1 Two message models share one database

[O] `collaboration.db` holds two unrelated message tables (`internal/messaging/schema.go:71-85`):

- `messages` + `threads` — the Collaboration Hub conversation model. Fields: `thread_id`,
  `message_seq`, `from_type`/`from_id`, `to_type`/`to_id`, `kind`, `subject`, `content`,
  `metadata_json`, `delivery_state`, `business_state`, `reply_to`, `deleted_at`
  (`schema.go:144-182`). `kind IN ('directive','question','proposal','status','result')`,
  `delivery_state IN ('pending','visible','claimed','acked')`,
  `business_state IN ('open','resolved','archived')` (`schema.go:179-181`).
- `inbox_messages` — "simple async agent-to-agent/user messaging … the unified inbox system for
  CLI (ailang messages) and hooks" (`schema.go:339-340`). **This is the work-intake channel.**

Everything below is about `inbox_messages` unless it says otherwise.

### 1.2 `InboxMessage` fields

[O] `internal/messaging/inbox.go:17-42`:

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Primary key. SQLite: UUID (`inbox.go:160-162`). Firestore: `inbox_<epoch-ms>_<8 hex>` (`internal/storage/firestore/messaging_inbox.go:53-55`) |
| `message_id` | string | SQLite: `msg_<YYYYMMDD_HHMMSS>_<first 8 of id>` (`inbox.go:163-173`). Firestore: equal to `id` (`messaging_inbox.go:29-40`) |
| `correlation_id` | string, optional | Free-form grouping key (see 6.3) |
| `from_agent`, `to_inbox` | string | Routing |
| `message_type` | closed vocabulary | See 1.3 |
| `title`, `payload` | string | Content. Payload is plain text or a JSON string |
| `category` | open string | `bug`, `feature`, `general`, `docs`, `research`, `refactor`, `test` are named (`inbox.go:79-87`); "any string allowed (bug/feature have special behavior)" (`schema.go:386`) |
| `github_issue`, `github_repo` | *int, string | Link to a GitHub issue |
| `simhash`, `dup_of` | *int64, string | Near-duplicate detection |
| `embedding`, `embedding_model`, `embedding_updated_at` | | Single neural embedding |
| `parent_task_id`, `chain_id`, `iteration` | | Links into the coordinator's task hierarchy and execution chain |
| `envelope` | *Envelope | Named embedding vectors (1.5) |
| `status` | 4 values | `unread`, `read`, `archived`, `deleted` (`inbox.go:45-50`) |
| `created_at`, `read_at`, `expires_at` | time | |

[O] The SQLite insert column list has no `iteration` (`inbox.go:242-244`); the Firestore map writes
it (`internal/storage/firestore/messaging_convert.go:103`). [I] `Iteration` does not survive a
SQLite round trip.

### 1.3 Types and categories

[O] `message_type` is a closed vocabulary of nine, "the single source of truth for the database
CHECK constraint": `notification`, `request`, `response`, `completion`, `handoff`, `info`, `audit`,
`approval_request`, `feedback` (`inbox.go:262-278`, `schema.go:384`).

[O] The comment on it records why it is closed: "a type present here but absent there is rejected
at write time on SQLite and silently accepted on Firestore, which is how the two backends came to
disagree" (`inbox.go:265-267`). The migration derives the CHECK from the Go slice so it "cannot
drift from the code that writes to it" (`internal/messaging/schema_migrations.go:96-107`).

[O] `category` is a separate, open axis. The CLI's `--type` flag sets `category`; if the value
also names a message type, it sets `message_type` too (`cmd/ailang/messages_send.go:136-149`,
`772-789`). `bug` and `feature` imply `--github` (`messages_send.go:110-115`).

[O] A tenth type is in use and is not in the vocabulary: the coordinator's bounce is written with
`MessageType: bounceMessageType` = `"inbox_unrouted_notice"`
(`internal/coordinator/unrouted_bounce.go:48`, `:228`), and `messages health` treats it as a result
type (`cmd/ailang/messages_health.go:45-53`). It is absent from `InboxMessageTypes`
(`inbox.go:268-278`). [I] By the code's own rule above, a SQLite-backed coordinator rejects every
bounce at the CHECK and a Firestore one accepts it. Not run.

[O] The skill doc `agent-inbox/resources/message_format.md:50-62` lists a different `type` enum
(`plan_ready`, `milestone_complete`, `sprint_complete`, `error`, `approval_request`, `paused`,
`resumed`, `handoff`, `notification`) and fields `from`/`to`/`reply_to`/`timestamp` that do not
exist on `InboxMessage`. [I] That file describes an older file-based format; only `handoff`,
`notification` and `approval_request` would pass the current CHECK.

### 1.4 Inboxes

[O] An inbox is just the string in `to_inbox`. There is no inbox table; a send to a new name
creates the inbox. `FormatPackageInbox` "applies no normalization and no existence check"
(`docs/internal/message-plane-topology.md:183-185`; code at
`internal/messaging/pkg_routing.go:53-56`).

[O] Address prefixes: `pkg:<vendor>/<name>`, `workspace:<name>`, `team:<name>`, otherwise plain
(`pkg_routing.go:11-51`). Named plain inboxes in the docs: `user`, `coordinator`,
`design-doc-creator`, `sprint-planner`, `sprint-executor`, `website-builder`, `eval-runner`
(`docs/docs/guides/cloud-messaging-integration.md:1071-1079`), plus `public-feedback`,
`ailang-core`, `eval-rig`, `mission-fleet`, `mission-<name>` and `unrouted`.

[O] What a name *does* is decided by the coordinator's agent registry, not the store. Every inbox
is one of three things (`cmd/ailang/messages_inboxes.go:28-36`):

```
DISPATCHES  an agent is registered; a send creates a task and work starts
TRIAGE      declared human-triage; a send is filed for a person, on purpose
NOTHING     neither; a send is accepted and silently goes nowhere
```

"The third row is the whole point. It is the state that looks identical to the first from where a
sender stands." (`messages_inboxes.go:35-36`)

[O] Registry lookup: exact match, then longest matching `*` prefix pattern, then no dispatch
(`message-plane-topology.md:210-212`). The plane's registry is "a 700-line YAML in a GCS bucket"
(`messages_inboxes.go:21`), not a file in this repo.

[O] An empty `to_inbox` is rewritten to `unrouted` on insert, because "every read path filters by
inbox, so the row is retained and billed but can never be listed, acked, or triaged"
(`internal/messaging/inbox_routing.go:9-11`, applied at `inbox.go:174` and
`messaging_inbox.go:41-43`).

### 1.5 Threads, hierarchy, and the two things called "envelope"

[O] `inbox_messages` has no thread column and no `reply_to`. Grouping is by `correlation_id`
(indexed, `schema.go:404`), `parent_task_id` and `chain_id`. Threads exist only in the Hub's
`messages` model (`internal/messaging/threads.go:10-23`), and the dashboard hierarchy is
root → agent → thread with unread/pending/running badges (`internal/messaging/hierarchy.go:18-32`).

[O] `messages reply` does not create a message. It posts a comment on the linked GitHub issue and
refuses if there is none (`cmd/ailang/messages_send.go:402-408`, `447`).

[O] "Envelope" names two different things:

1. **Semantic envelope** — `Envelope{Slots map[string]*EnvelopeVector}`, five named embedding
   vectors: `intent`, `code`, `context`, `skill`, `resolution`
   (`internal/messaging/envelope.go:8-34`). Stored as JSON in the `envelope` column.
2. **Package message envelope** — `PackageMessageEnvelope`, schema `ailang.package-message/v1`,
   a typed JSON document "stored as JSON in InboxMessage.Payload"
   (`internal/messaging/pkg_schema.go:12-13`, `47-68`). Eleven kinds (`pkg_schema.go:18-30`), each
   with required fields (`pkg_schema.go:111-164`), its own `status` and a `supersedes` field.

---

## 2. Lifecycle

### 2.1 The states that exist and the ones that are used

[O] Four statuses are declared: `unread`, `read`, `archived`, `deleted` (`inbox.go:45-50`).

[O] In the directories on disk, only two are ever written to an inbox message: `read`
(`inbox.go:536-538`, `598-603`; `messaging_inbox.go:203-210`, `241-244`; and by dedupe at
`internal/messaging/search.go:406`, `414`) and `unread` (`inbox.go:569-571`;
`messaging_inbox.go:212-218`). `archived` and `deleted` appear only in read filters
(`inbox.go:311`, `651`; `search.go:105`). `cleanup` hard-deletes rows (`inbox.go:704-711`).
[I] The inbox is a two-state queue in practice.

[O] The docs say so directly: "There is no CLI verb to set `status="resolved"` or attach a
resolution note, so the authoritative resolution record is the CHANGELOG (which cites ticket IDs
like `fb_cef305`) plus the git commits — not the inbox"
(`docs/docs/guides/agent-messaging.md:110-113`).

### 2.2 Transitions

| Transition | Caused by | Cite |
|---|---|---|
| → `unread` | Any insert | `inbox.go:177-179` |
| `unread` → `read` | `messages ack <id>` | `cmd/ailang/messages_crud.go:222` |
| `unread` → `read` | `messages ack --all`, across **every** inbox unless `--inbox` is given | `messages_crud.go:160-207` |
| `unread` → `read` | `messages read <id>`, `--latest`, `--all-unread` unless `--peek` | `messages_crud.go:307-313`, `332-334`, `367-370` |
| `unread` → `read` | The coordinator, when the message becomes a task | `internal/coordinator/dispatch_read_marking.go:27-46` |
| `unread` → `read` | `messages dedupe --apply` on every non-representative duplicate | `internal/messaging/search.go:398-422` |
| `unread` → `read` | Interactive browser `r`, `a`, `A` | `cmd/ailang/messages_util.go:122-175` |
| `read` → `unread` | `messages unack <id>` | `messages_crud.go:256` |
| any → gone | `messages cleanup --older-than` (default 7d) deletes by age, whatever the status | `inbox.go:707-711`, `messages_util.go:351` |
| `to_inbox` rewritten | `messages forward`, the triage router, label resync | `inbox.go:614-627` |

### 2.3 What each transition means for whoever is responsible

- **Unread on a DISPATCHES inbox** means "not yet picked up by an agent". [O] `messages health`
  calls this "routable but undelivered" and says "In a healthy plane this is 0 — push delivers
  everything" (`messages_health.go:213-219`).
- **Unread on a TRIAGE inbox** means "waiting for a person, on purpose"
  (`messages_health.go:28`).
- **Read** means one of four different things, and the row does not say which: a human
  acknowledged it; someone merely looked at it; an agent took it as a task; or dedupe folded it
  into another message. [I] "Read" carries no claim that the work was done.
- [O] The attended rule is "Summarize to the user and ask **before** acking" (`CLAUDE.md:32`).
  An unattended agent (`AILANG_TASK_ID` or `AILANG_MISSION_STAGE` set) must "skip the inbox and do
  the task" (`CLAUDE.md:32-34`); the hook exits early for it (`scripts/hooks/session_start.sh:50-51`).

[O] Three documented traps follow from read being a side effect:

1. "`messages read <id>` marks the message read as a side effect. Triaging by reading silently
   drains the unread queue — the next session sees an empty inbox and concludes nothing arrived."
   (`message-plane-topology.md:298-300`)
2. "`ack --all` sweeps outbound cross-mission messages too." (`message-plane-topology.md:301-302`)
3. The list view truncates ids to 8 characters, so every cloud message renders as `(inbox_17)`
   (`message-plane-topology.md:295-297`; the truncation is at `messages_util.go:397-400`).

[O] Backend difference: SQLite `MarkInboxMessageRead` only matches `status = 'unread'` and errors
"message not found or already read" otherwise (`inbox.go:536-550`). Firestore updates
unconditionally (`messaging_inbox.go:203-210`).

### 2.4 Two layered lifecycles built on top

**Package messages.** [O] Seven states with an enforced transition table: `open → acknowledged →
in_progress → completed`, with `blocked`, `rejected`, `superseded`
(`internal/messaging/pkg_status.go:11-31`). The state lives in the JSON payload, not the `status`
column (`pkg_status.go:33-71`).
[O] `UpdatePackageMessageStatus` is a method on the concrete SQLite `*Store` and is not in the
`MessageStore` interface (`internal/messaging/message_store.go:13-122`). Its only non-test caller
on disk is `SupersedeOlderMessages` (`pkg_status.go:107`), called from `ailang pkg publish`
(`cmd/ailang/pkg_publish.go:363`), which opens the local SQLite file directly
(`cmd/ailang/pkg_msg.go:266-269`). `TriagePackageMessage` has no non-test caller on disk.
[I] Only `open → superseded` is reachable from the CLI I read, and only on the local store.
The guide's "Messages follow enforced state transitions" (`agent-messaging.md:887-898`) describes
a validator, not a workflow in use.

**Harness tickets.** [O] `ailang mission ticket` builds an open/resolved tracker out of the
unread flag: "'Open' means UNREAD in the mission-fleet inbox. That only holds if nothing marks a
ticket read except `resolve`" (`cmd/ailang/mission_ticket.go:9-11`).
- `file` writes one message per occurrence, deduplicated by title (`mission_ticket.go:125-136`),
  with correlation `harness:<signature>`.
- `open` lists without marking read and ranks signatures by slots lost (`mission_ticket.go:166-195`).
- `resolve` requires `--resolution`, replies to each filing mission's inbox, then marks every
  occurrence read. "Reply BEFORE marking read: a crash between the two leaves the ticket open
  (re-resolvable), never closed with nobody told." (`mission_ticket.go:229-250`)
- The invariant is held by convention: "Do not `messages read` or `ack --all` it"
  (`message-plane-topology.md:205-207`).

---

## 3. The stores

### 3.1 What exists

[O] Two backends implement one 74-method interface (`internal/messaging/message_store.go:13-125`):

- **Local SQLite**, `~/.ailang/state/collaboration.db`, per machine (`store.go:80-90`).
- **Firestore**, collection `inbox_messages` (`internal/storage/firestore/messaging.go:21`), in a
  GCP project. Canonical is prod, project `ailang-multivac` (`message-plane-topology.md:9-13`).

[O] Notification is a third, separate layer: Pub/Sub carries "a bare `{"message_id": "..."}`
telling a device to go read it" (`message-plane-topology.md:315-318`).

### 3.2 Selection

[O] One function resolves it: `config.StoragePlane()` is "the ONLY reader of AILANG_STORAGE and
the three overrides" (`internal/config/storage.go:156-203`).

- `AILANG_STORAGE=local|gcp|hybrid`, default `local`. Moves all three stores.
- `AILANG_STORAGE_MESSAGING=local|gcp` moves messaging alone. Siblings exist for coordinator and
  observatory (`storage.go:13-24`).
- Project for the messaging store: `AILANG_MESSAGES_PROJECT`, else `config.CloudProject`
  (`cmd/ailang/messages.go:149-156`, `182-187`).
- `hybrid` keeps messaging in SQLite (`messages.go:154-156`, `220-222`).
- Retired selectors (`AILANG_MESSAGES_STORE` and three others) are a hard error naming the
  replacement, because "a value that is now ignored must not LOOK honoured" (`storage.go:114-124`,
  `137-154`).
- An unknown value is a hard error: `invalid storage selection` (`storage.go:110-112`, `198-200`).

[O] **The default is the private local store.** Reading the shared inbox needs two exported
variables (`agent-messaging.md:44-63`, `CLAUDE.md:13-20`).

[O] Per-node wiring (`message-plane-topology.md:216-222`): the attended laptop reads prod messages
but keeps coordinator and observatory local; the rig and the Cloud Run coordinator have all three
in prod.

[O] Three commands bypass the switch and pin a store:
- `mission ticket` always opens Firestore in `config.MissionMessagePlaneProject`
  (`mission_ticket.go:62-72`).
- `pkg publish` message emission always opens local SQLite (`pkg_msg.go:266-269`).
- The coordinator's GitHub label resync always opens local SQLite
  (`internal/coordinator/daemon_github.go:181-182`).

### 3.3 Recorded failure modes of reading the wrong store

1. **Bare listing reads local.** [O] "measured 2026-08-26, the banner said '16 unread' while the
   canonical store held 74, including four months of public feedback nobody had seen"
   (`scripts/hooks/session_start.sh:157-160`). The topology doc exists because of it
   (`message-plane-topology.md:4-5`).
2. **Hooks do not inherit the login shell.** [O] "exports in ~/.zshenv are NOT in scope here"
   (`session_start.sh:156`), so the hook exports the pair itself (`session_start.sh:166-167`).
   launchd jobs have the same property (`message-plane-topology.md:100-101`).
3. **Wrong project, confident answer.** [O] `AILANG_CLOUD_PROJECT` "is pinned per-machine (the
   attended laptop's `~/.zshenv` points it at the stale `-dev` graveyard)"; "the wrong project
   gives a confident, wrong answer with no error — dev and prod queries returned byte-identical
   output" (`message-plane-topology.md:285-291`).
4. **A stale binary ignores the selector silently.** [O] "it reads local SQLite and exits 0,
   making the whole protocol vacuous" (`message-plane-topology.md:303-311`). The control is to
   pass a deliberately invalid value and require a refusal. The hook runs this probe
   (`session_start.sh:192-201`).
5. **A missing composite index looks like an empty or broken store.** [O] "The rig polled
   correctly every 30s and every poll failed `FailedPrecondition` while a message sat unread in
   its inbox: registered, tagged, alive, and silently claiming nothing"
   (`message-plane-topology.md:275-281`). "declared" is not "live"
   (`agent-messaging.md:147-163`).
6. **Split between store and notification project.** [O] "a probe written to ailang-multivac-dev
   published its notification to ailang-multivac … The dev coordinator was never told and the
   task never ran" (`cmd/ailang/messages_send.go:726-728`). Fixed by making the notification
   follow the store (`messages_send.go:732-755`); `messages health` reports it as `SPLIT`
   (`messages_health.go:328-342`).
7. **Status command contradicting the tool it explains.** [O] `ailang storage status` named the
   `-dev` project for a store that was reading prod, 2026-09-30 (`cmd/ailang/storage.go:84-91`).
8. **The CLI hangs when the cloud store is unreachable.** [O] "inside the pi mission sandbox …
   `ailang messages list --unread` hung until the runner killed it at 600s … and the runner banked
   each one as the MODEL's `stream_dead`" (`cmd/ailang/messages_deadline.go:11-18`). Now a 90s
   bound with exit 124 (`messages_deadline.go:22`, `36-51`).
9. **Wrong registry, wrong verdict.** [O] The same failure one level up: "the local config
   carried 41 agents while prod carried 34" (`messages_health.go:99-101`); "a 177-message 'config
   gap' against a plane whose real gap was 54" (`messages_health.go:108-111`).

[O] The mitigation they settled on is a header that names the store on every non-local listing:
`store: gcp (Firestore, project …, via …)` (`messages.go:226-239`, printed at
`messages_crud.go:126-128`). "No header, no cloud." (`agent-messaging.md:144-145`)

[O] That header is printed only on the human-readable path. `--json` and `--compact` return
before it (`messages_crud.go:96-118`). The session hook and `check_messages.sh` both use `--json`.

### 3.4 Residual hazards I found by reading

- [O] The hook's inbox query is
  `ailang messages list --unread --json 2>/dev/null || echo "[]"` (`session_start.sh:188`). Any
  failure becomes an empty list and the banner prints "No unread messages"
  (`session_start.sh:436-457`). The same file calls that shape "the exact failure this hook
  exists to prevent" (`session_start.sh:171`) and its approvals block prints `UNREADABLE` instead
  of 0 (`session_start.sh:291`, `310`). [I] The inbox count still fails silent.
- [O] The count is `jq length` of that listing (`session_start.sh:189`), and `messages list`
  defaults to `--limit 20` (`messages_crud.go:21`, applied at `:84`). [I] The banner cannot
  report more than 20 unread. The hook's own comment quotes a banner that "said '20 unread'"
  (`session_start.sh:285`). Not run.
- [O] `.claude/skills/agent-inbox/scripts/check_messages.sh:27` has the same `|| echo "[]"` and
  pins no store.
- [O] `storage.NewBackendsForSelection` resolves the project through `config.CloudProject` only
  (`internal/storage/backend.go:133-141`). `config.MessagesProject()` is called from three CLI
  files (`cmd/ailang/messages.go:182`, `storage.go:94`, `coordinator_cloud_project.go:42`).
  [I] A daemon opened through `storage.NewBackends` does not honour `AILANG_MESSAGES_PROJECT`.
  The notify daemon takes its project from `--env` instead (`cmd/ailang/daemon.go:107`, `140`).

---

## 4. GitHub sync

### 4.1 Directions

| Direction | Mechanism | Cite |
|---|---|---|
| GitHub issue → message | `ailang messages import-github`: lists **open** issues carrying the watch labels, inserts each as an unread `notification` with `github_issue` and `github_repo` set | `cmd/ailang/messages_github.go:95-96`, `229-241`; `internal/messaging/github.go:395-404` |
| Scheduled import | Coordinator `github_sync` shells out to the same CLI every ≥5 min per repo | `internal/coordinator/daemon_github.go:39-51`, `87-125` |
| Message → GitHub issue | `messages send --github` (implied by `--type bug|feature`) creates an issue titled `[<from>] <title>`, labelled `from:<agent>`, the category, and `create_labels` | `messages_send.go:110-115`, `253-274`; `github.go:292-364` |
| Message → issue comment | `messages reply <id> "text"` | `messages_send.go:441-452` |
| Retry | `messages github-sync <id>` | `messages_github.go:301-367` |
| Task → issue | Coordinator posts status comments, adds/removes labels, closes | `internal/coordinator/github_poster.go:47-118` |
| Issue labels → task state | GitHub-driven approvals: human adds `design-approved`, `sprint-approved`, `merge-approved` | `docs/docs/guides/coordinator.md:547-614` |
| PR state → approval | `ListMergedPRsWithPrefix` reconciles merged `coordinator/*` PRs back to pending approvals | `internal/messaging/github_pr.go:92-122` |

[O] The session hook used to import; it no longer does: "The hook no longer imports directly to
avoid routing to wrong inbox" (`session_start.sh:147-151`).

[O] Message-local first, always: "ALWAYS save to SQLite first" then sync
(`messages_send.go:176-180`); a failed sync leaves the message stored and prints the retry
command (`messages_send.go:262-266`). That retry command did not exist when the hint was written
(#754, `messages_github.go:301-306`).

### 4.2 Trust at the import boundary

[O] "SECURITY (2026-08-10): the repo is PUBLIC and the issue templates auto-apply
`bug`/`enhancement` with no write access needed, so the label filter above says nothing about WHO
is speaking." Issues from non-trusted authors "still import, because dropping public feedback
would be a worse failure; they import INERT" — no category, default inbox, sender
`github-untrusted:<login>`, title prefixed `[untrusted]` (`messages_github.go:176-187`, `202-218`;
config at `internal/messaging/config.go:43-75`).

[O] Account safety: every `gh` call first checks the active account against
`github.expected_user` and hard-fails on mismatch (`github.go:183-256`). Each `gh` call has a 30s
deadline with a distinct `ErrExecTimeout` (`github.go:71-113`).

### 4.3 Duplicate prevention, by layer

| Layer | Key | Cite |
|---|---|---|
| Import | `(github_repo, github_issue)` already present in **this** store | `messages_github.go:129-139`; `inbox.go:629-640` |
| Send | Same title in same inbox, unless `--force` | `messages_send.go:163-174`; `inbox.go:642-659` |
| GitHub retry | Message already has an issue number | `messages_github.go:345-351` |
| Issue claim | Label `coordinator:in-progress` | `internal/coordinator/github_poster.go:9-11`, `351-399` |
| Finalisation replay | Deterministic id + `PutMessageIfAbsent`, first write wins | `inbox.go:116-142`; `internal/storage/firestore/finalize_if_absent.go:108-128` |
| Task creation | Exact simhash, 24h window, same agent, not the parent task | `internal/coordinator/task_dedup.go:23-26`, `82-120` |
| Semantic | `dedupe --apply` sets `dup_of`; intake lists with `Collapsed: true` | `search.go:314-422`; `internal/coordinator/message_adapter.go:27-32` |
| Notification | Daemon suppresses repeats: 60s per `(task_id, status)`, 5 min per `message_id` | `docs/docs/guides/notify-daemon.md:72-77` |

[I] The import key lives in the store, so the same issue imports once per store. Two machines on
local SQLite each get their own copy.

[O] The SQLite title check ignores `deleted`/`archived` rows (`inbox.go:648`); the Firestore one
does not filter on status (`internal/storage/firestore/messaging_inbox.go:278-295`).

[O] A relabelling hazard is written into the triage skill: "Don't add `bug`, `feature` or
`from:*` to existing issues. They are the coordinator's default `watch_labels` … so adding one can
import an old issue as a new task" (`.claude/skills/github-issue-triage/SKILL.md:84`).

### 4.4 What closes what

- [O] **The coordinator closes the GitHub issue when a merge is approved**, with a comment
  "Merged to <branch> / Commit / Approved by" (`internal/coordinator/approval_processor.go:374-388`;
  also `internal/coordinator/task_chain.go:501-543`).
- [O] **GitHub closes issues itself** on a closing keyword in a commit message or squash-merge PR
  text. This is the documented sprint convention: `refs #17` during work, `Fixes #17` on the final
  commit (`docs/docs/guides/development-workflow.md:236-248`).
- [O] **Humans or agents close by hand** through the `github-issue-triage` skill, one verified
  verdict per issue and "get approval before closing" (`github-issue-triage/SKILL.md:51-67`).
- [O] **PRs**: approval squash-merges with `--auto` and never `--admin`; rejection closes the PR
  with a reason (`github_pr.go:192-263`).
- [O] **Nothing I read closes or acks a message because its issue closed.** Import lists only
  open issues (`github.go:397`) and there is no reverse sweep in `github.go`,
  `messages_github.go` or `daemon_github.go`. The message is marked read when it is dispatched
  (`dispatch_read_marking.go:27-46`), not when the work lands. [I] Message state and issue state
  are joined only by `github_issue` on the row and are never reconciled.

### 4.5 What `check_autoclose.sh` guards against

[O] "Refuse GitHub auto-close phrases in records that ship documentation only"
(`scripts/check_autoclose.sh:2`).

- Pattern: `(close[sd]?|fix(es|ed)?|resolve[sd]?)[[:space:]]*:?[[:space:]]*#[0-9]+`, matched
  case-insensitively (`check_autoclose.sh:7`, `80`).
- Scans commit messages in a range, or a PR title+body with its changed-file list
  (`check_autoclose.sh:135-161`). PR text matters because the repo squash-merges
  (`development-workflow.md:252-255`).
- A record that touches any non-docs path is exempt (`check_autoclose.sh:83-85`). Docs paths:
  `docs/`, `design_docs/`, `changelogs/`, `CHANGELOG*`, `README*`, `.claude/`, `.agents/`, and
  root-level `*.md` (`check_autoclose.sh:36-49`).
- Escape hatch: a per-issue trailer `Autoclose-OK: #N`. A bare `Autoclose-OK:` is an instrument
  error, and a trailer for one issue never covers another (`check_autoclose.sh:62-77`, `92-94`).
- Exit 1 for a violation, exit 2 for an instrument failure. "an empty commit range must never
  certify itself green" (`check_autoclose.sh:169-173`).
- Wired into CI for PRs and pushes, with its own self-test step (`.github/workflows/ci.yml:319-337`).

[O] The incident behind it (`.claude/skills/mission-control/resources/gate-4-record.md:113-122`):
`#676`, "a live user-reported OOM this mission had itself triaged **REAL at HEAD**, was closed
`COMPLETED` by `dedf3b91f` — a **docs-only** record, 7 files, **zero code** — 1h46m after our own
comment said it was real and unfixed. The repo is public; an external reporter saw their live bug
marked done." `#612` was closed by a commit that shipped "one 636-line sprint plan". The stated
lesson: "The hazard was known and the guard was applied to the DOCUMENT, never to the COMMIT
MESSAGE".

[O] Why agents are prone to it: "the more carefully you reason in prose about a fix you have
**not** shipped, the likelier you are to close the issue tracking it" (`gate-4-record.md:110-112`).

[O] A related silent failure on the closing channel: `gh issue close --comment` on an
already-closed issue "exits 0, and posts nothing", and a merged PR with `Fixes #N` has already
closed it, so that is "the **normal path**"
(`.claude/skills/mission-control/resources/gate-0-preflight.md:59-64`).

---

## 5. Deadlines, renotification, health

### 5.1 There is no per-message deadline

[O] `expires_at` exists (`inbox.go:41`) and `cleanup --expired` deletes on it (`inbox.go:702-706`).
No code on disk sets it on send. `cmd/ailang/messages_deadline.go` is a wall-clock bound on the
CLI process, not a response deadline (`messages_deadline.go:9-22`).

[O] The only response timeout in the docs is on Hub capability approvals: "Default approval
timeout is 60 seconds. If no human approves in time, the directive is cancelled"
(`docs/docs/guides/collaboration-hub.md:598-600`).

[I] An unanswered message has no SLA. It is surfaced only by the mechanisms below.

### 5.2 How unanswered messages are surfaced

1. **Session-start banner.** [O] Count of unread plus sender summary, labelled with the store.
   Deliberately demoted: "The banner is AMBIENT CONTEXT, not a work queue … sessions arrived, saw
   a backlog addressed to nobody in particular, and triaged it instead of the work they were
   started for" (`session_start.sh:507-514`). Pending approvals lead instead, because "what stalls
   the loop is no longer a lost message — it is a decision nobody was told was waiting"
   (`session_start.sh:279-290`).
2. **Notify daemon.** [O] Pulls Pub/Sub and raises macOS and Discord notifications. External
   feedback (`public-feedback` and any `pkg:*`) passes the Discord allow-list; routine inbox
   traffic stays on the desktop (`notify-daemon.md:46-61`;
   `docs/docs/guides/notification-channels.md:171-187`).
3. **`messages health`.** [O] "make one number visible that should always be zero — messages that
   are filed, routable, and undelivered" (`messages_health.go:5-8`).
   - Classifies each unread message as routable, agent output, human-triage, or unroutable, using
     inbox **and** message type (`messages_health.go:285-306`).
   - Verdict is over a window (default 24h); older items are `BACKLOG`, reported by age and
     excluded from the verdict (`messages_health_window.go:129-134`; `messages_health.go:224-233`).
   - Also checks the send path: `BROKEN` if Pub/Sub is disabled, `SPLIT` if it publishes to
     another project (`messages_health.go:311-344`).
   - `--strict` exits non-zero; `--json` for hooks (`messages_health.go:60-62`, `152-167`).
   - Refuses when the registry cannot be loaded: "Refusing to guess" (`messages_health.go:114-119`).
   - States its blind spot: "This command sees the message plane and NOTHING downstream of it"
     and names three coordinator commands to run next (`messages_health.go:235-242`).
4. **`messages inboxes`.** [O] Lists what each inbox does, with unread and recent counts, problems
   first. Includes inboxes that exist only in the store (`messages_inboxes.go:121-126`). Counts
   recent traffic of any status because "a mistyped inbox disappears from this listing the moment
   someone reads its messages" (`messages_inboxes.go:56-61`).
5. **Bounce.** [O] The coordinator files an `UNDELIVERED:` notice to the sender when an inbox has
   no agent and is not declared triage (`internal/coordinator/unrouted_bounce.go:190-238`). Loop
   guards: never bounce a bounce, never bounce a triage inbox, never fall back to a default inbox
   (`unrouted_bounce.go:35-43`).
6. **Send-time refusal.** [O] `messages send` and `forward` refuse an inbox nothing serves, with
   a "did you mean" suggestion, but only when judging against the plane's own registry; against a
   local registry they warn and send (`cmd/ailang/messages_send_inbox_guard.go:17-23`, `40-72`).
7. **`FILED, NOT DISPATCHED` warning.** [O] Printed when a cloud-store send published no
   notification (`messages_send.go:700-714`).
8. **Backstop sweep.** [O] Coordinator scan for unread, routable, non-outcome messages that push
   never delivered. Default mode is `report`, not `dispatch`, because "the sweep's own risk is
   double-dispatching work that push already did" (`internal/coordinator/backstop_sweep.go:24-40`).
   Sweeps once at startup because Cloud Run instances lived "34s and 12s"
   (`backstop_sweep.go:92-105`).

### 5.3 Renotification

[O] `ailang messages renotify <id>` publishes the Pub/Sub notification for a message already in
the store (`cmd/ailang/messages_renotify.go:12-24`). It refuses a message that is not unread
unless `--force`: "a read message was dispatched or acked, and a second notification would run it
twice" (`messages_renotify.go:77-84`). Re-sending is rejected as a fix because "the sender's own
records (and every completion title) key on the original message id"
(`messages_renotify.go:20-21`).

[O] `messages forward` now also publishes, because a forward was "only a database edit"
(`messages_crud.go:458-471`).

[O] Delivery-layer properties recorded in the topology doc
(`message-plane-topology.md:313-386`): each device needs its own subscription; ordering is keyed
on the inbox, so one stuck notification blocks that inbox; an absent message is retried for
5 minutes then dropped; a hand-made subscription deletes itself after 31 days without a pull.

---

## 6. Triage: how a message becomes work

### 6.1 Paths

**A. Direct dispatch.** [O] A message on a DISPATCHES inbox becomes a task. Local coordinators
poll the store; the cloud coordinator takes work "from Pub/Sub only" (`messages_send.go:687-690`).
The message is then marked read (`dispatch_read_marking.go:27-46`).

**B. The agent chain.** [O] `design-doc-creator → [Human Approval] → sprint-planner → [Human
Approval] → sprint-executor → [Human Approval] → Merged`
(`cloud-messaging-integration.md:1199-1201`). Each stage is a new inbox message to the next
agent's inbox, of type `handoff`, written under a deterministic id.

**C. GitHub issue.** [O] Imported issue → message on the sync target inbox (the guide's example
is `design-doc-creator`, `coordinator.md:514-523`) → the chain → issue closed on merge.
`coordinator:*` labels reroute on import (`messages_github.go:153-173`) and on a periodic label
resync (`daemon_github.go:291-319`).

**D. Auto-triage router.** [O] Opt-in (`coordinator.triage.enabled`). Every 120s it lists unread
messages on the intake inboxes (default `user`, `claude-code`) and forwards any non-duplicate
whose category is `bug` or `feature` to `design-doc-creator`. Everything else is held; "Held/
dropped messages are left in place" (`internal/coordinator/triage_router.go:16-73`, `96-113`,
`202-239`). The decision is category only; the cluster slot and similarity threshold in its
config are not used by `classify`.

**E. Cheap LLM triage in front of design docs.** [O] `ailang-core-triage` skill: one report in,
one file out at `design_docs/planned/ailang-core-triage/<slug>.md`, with `Class`, `Recommend`
(`design-doc | direct-fix | duplicate-of <path> | drop`), `Searched`, and `Estimate`
(`.claude/skills/ailang-core-triage/SKILL.md:21-45`). It exists because "Firing a design doc at
each is real money (~$1–3 and ~20 minutes of a full-size model apiece)" (`SKILL.md:14-19`).
- An ordered seven-row rubric with two numeric thresholds, `DIRECT_FIX_MAX_LINES` = 2 and
  `DIRECT_FIX_MAX_FILES` = 1 (`SKILL.md:60-81`).
- The rubric is enforced in Go, reading the thresholds out of the skill file rather than copying
  them, and runs in `make test` so a violating row fails the PR
  (`internal/coordinator/triage_rubric.go:16-23`, `49-71`, `142-178`).
- "One file per report, NOT a shared table" (`SKILL.md:27-32`).
- "An empty search is a claim" — name the terms searched (`SKILL.md:121-123`).

**F. Feedback gate.** [O] In cloud intake a gate runs before task creation; a filed or rejected
verdict suppresses the task, and "Gate errors fail closed (no dispatch)"
(`internal/coordinator/daemon_tasks_polling.go:440-446`). [D] On the rig it fails closed because
no API key is set there (`message-plane-topology.md:260-261`). I did not open
`internal/feedbackgate/`.

**G. Human at session start.** [O] Summarise, ask, then ack (`CLAUDE.md:32`). The skill's
documented flow is: read, "Create design doc if needed", send an acknowledgment to the sender,
ack the original (`agent-messaging.md:224-234`).

**H. Embedding clusters as an aid.** [O] `messages triage` clusters unread messages by an envelope
slot (`cmd/ailang/messages_triage.go:91-118`). The hook runs it when there are 5 or more unread
(`session_start.sh:487-496`). It produces a report, not a routing decision.

### 6.2 Identifiers that carry through

| Identifier | From → to | Cite |
|---|---|---|
| Message `id` → task id | `task-<last 8 hex>` when the id ends `_<hex>`; otherwise the first 8 hex of SHA-256 of the whole id | `daemon_tasks_polling.go:137-140`, `706-732` |
| Message id → completion | Completion message carries `correlation_id` = the original message id | `internal/coordinator/pubsub_completion_handler.go:239`; `cloud-messaging-integration.md:1245-1251` |
| `github_issue`, `github_repo` | message → task → comments, labels, close | `message_adapter.go:40-54`; `approval_processor.go:374-388` |
| `parent_task_id`, `chain_id`, `iteration` | message → task | `message_adapter.go:55-57` |
| Thread id | `threads.id` → `tasks.thread_id` | `collaboration-hub.md:353-370` |
| Design doc and sprint plan paths | Held on the task, posted in the merge comment | `task_chain.go:517-525` |
| Triage row | `TRIAGE_FILE:` and `RECOMMEND:` output markers | `ailang-core-triage/SKILL.md:148-155` |
| Feedback ticket id | `fb_…` ids cited in the CHANGELOG | `agent-messaging.md:112` |
| Harness signature | `harness:<signature>` on ticket and on the resolution reply | `mission_ticket.go:122`, `240` |
| Milestone id | Design-doc filename matched to issues by M-ID | `github-issue-triage/SKILL.md:109` |

[O] `correlation_id` has at least four conventions: the original message id on completions
(`pubsub_completion_handler.go:239`), the **task** id on handoffs
(`internal/coordinator/approval_handoff.go:148`), `harness:<sig>` on tickets, and workflow names
such as `sprint_M-S1` in the skill doc (`agent-inbox/resources/message_format.md:71-77`).

[O] The task-id rule in three docs is stale. They say `task_id = "task-" + message_id[:8]`
(`cloud-messaging-integration.md:120`, `850-864`; `collaboration-hub.md:365`;
`collaboration-hub/resources/id_relationships.md:56-65`, which cites `message_adapter.go`, a file
that no longer contains it). The code uses the suffix, with the reason in a comment: "the prefix
'inbox_17' is the same for all messages in 2026, which caused every task to get ID
'task-inbox_17'" (`daemon_tasks_polling.go:137-139`).

[O] What does **not** carry: the message row has no field for the design doc, triage file or PR
that answered it. The `resolution` envelope slot is an embedding of the diff and commit message
(`envelope.go:14`; `envelope_builder.go:68-74`, `135-144`), not a link.

---

## 7. Semantic search and embeddings

[O] Three mechanisms:

1. **SimHash** — a 64-bit hash of `title + " " + payload`, computed on every insert in both
   backends (`inbox.go:206-214`; `messaging_inbox.go:57-64`; `internal/messaging/simhash.go:5-28`).
2. **Neural embedding** — one vector per message, computed lazily on search, via Ollama, OpenAI
   or Gemini (`agent-messaging.md:675-690`; `internal/messaging/embedder.go:213-215`).
3. **Semantic envelope** — up to five named vectors per message (1.5).

[O] Uses:

- **Duplicate detection.** `messages dedupe` groups by simhash similarity (default 0.95), keeps
  the oldest, sets `dup_of` and marks the rest read (`search.go:313-422`;
  `cmd/ailang/messages_search.go:115`).
- **Hiding duplicates from intake.** The coordinator's inbox adapter, the triage router and the
  backstop sweep all list with `Collapsed: true` (`message_adapter.go:30`; `triage_router.go:218`;
  `backstop_sweep.go:130`).
- **Task dedup.** Exact simhash equality within 24h (`task_dedup.go:18-26`).
- **Search.** `messages search "query"`, `list --similar-to <id>`, and per-slot search with
  `--space` (`agent-messaging.md:494-518`).
- **Triage clustering.** Greedy threshold clustering on one slot (`internal/messaging/triage.go:16-64`).
- **Resolution memory.** [D] On task completion the original message's envelope gets a
  `resolution` slot, so "new problems can be matched against past solutions"
  (`agent-messaging.md:766-773`). I did not read the coordinator code that writes it.

[O] Recorded failures, all silent:

- "semantic search over the canonical prod store matched nothing and reported it as an empty
  result" — the Firestore backend had a private hash that was "not a simhash at all" and a write
  path that never populated the field (`simhash.go:20-25`; `messaging_inbox.go:57-60`).
- Old documents with no simhash were skipped: "a claim of absence produced by an index that was
  never built" (`internal/storage/firestore/messaging_search.go:256-264`).
- The inbox inferred from the repo name used the old spelling, so every bare `search`, `dedupe`
  and `triage` "filtered on an inbox with zero documents and reported 'No messages found'"
  (`cmd/ailang/messages_search.go:222-228`).
- Embedding model drift: "a brain indexed under one model and queried under another compares
  vectors of different geometry and returns confidently wrong neighbours — no error"
  (`embedder.go:179-184`).
- Every handoff simhashed to its own parent, so it was suppressed as a duplicate
  (`task_dedup.go:65-81`).

[O] How much of this is live is limited by the write path. `messages send` computes an envelope
only when git-modified source files are detected or a flag is passed, **and** an embedder is
configured; otherwise it is silent (`messages_send.go:212-221`). `triage` falls back to a flat
list when fewer than two messages have the slot (`messages_triage.go:77-89`). [I] Messages from
the public MCP or the REST API probably carry no envelope, so clustering would rarely apply to
external feedback. I did not measure this.

[O] `search`, `dedupe` and `triage` with no `--inbox` restrict themselves to an inbox inferred
from the git repo folder name (`messages_search.go:52-58`, `217-233`; `messages_triage.go:44-51`).

---

## 8. Is it an issue tracker?

[I] No. It is an intake and dispatch queue with a delivery-health view. Tracking lives in GitHub
issues, the `design_docs/planned` → `implemented` tree, and the CHANGELOG. The project says this
itself: "the authoritative resolution record is the CHANGELOG … plus the git commits — not the
inbox" (`agent-messaging.md:110-113`).

**What it does that GitHub issues do not** [O]:

- A send has an effect: an addressed message becomes a task for a specific agent
  (`messages_inboxes.go:28-33`).
- Intake without a GitHub account: public MCP `submit_feedback` and package-scoped inboxes
  (`message-plane-topology.md:138-164`).
- Private traffic: completions, handoffs, approvals, audit records, cross-mission notes.
- Machine-typed payloads with validation (`pkg_schema.go:111-164`).
- Links into execution: `parent_task_id`, `chain_id`, task id, cost and trace
  (`collaboration-hub.md:341-381`).
- A delivery verdict: "routable but undelivered", bounces, send-path check (5.2).
- Trust tiers on imported content (4.2).
- Tag-routed sends that only a matching worker may claim (`agent-messaging.md:328-342`).
- Near-duplicate detection and per-aspect embedding search (7).

**What GitHub issues do that it does not** [O unless marked]:

- A resolution state. The inbox has unread and read; "read" does not mean done (2.3).
- A discussion on the item. There is no reply message; `reply` is a proxy to the issue
  (`messages_send.go:402-408`).
- Priority, area, owner, milestone. These exist only as GitHub labels (`priority:P0…P3`, `area:*`,
  `needs-decision`) (`github-issue-triage/SKILL.md:73-86`).
- Links from commits and PRs, and closing on merge.
- Durable history. `cleanup` deletes by age (`inbox.go:707-711`).
- Public visibility to the reporter.
- Safe inspection. Reading an issue does not change its state; `messages read` does.
- [I] A stable short id a human can cite. Cloud ids all share an 8-character prefix.

**Where they did build a tracker on it.** [O] The harness-ticket queue (2.4) is a real
open/resolved tracker over the message schema, with dedupe key, ranking and a mandatory resolution
note. It works because one command owns both transitions and a written rule forbids the generic
verbs on that inbox.

**GitHub's own cost for this fleet.** [O] "491 of the last 500 commits (~98%) come from one agent
identity"; the maintainer's inbox "drowns in agent noise"
(`docs/internal/github-notification-hygiene.md:7-11`). GitHub has no per-author mute
(`github-notification-hygiene.md:31-32`). The proposal is layered: watch settings, a custom
filter, email routing, an API auto-triage script that keeps `mention`, `review_requested` and
`security_alert`, and at the source one bot identity, sticky comments and mention discipline
(`github-notification-hygiene.md:85-161`). Status is "draft for approval"
(`github-notification-hygiene.md:3`).

---

## 9. Ten incident records

1. **A quiet banner over a full inbox.** `scripts/hooks/session_start.sh:157-161`: "measured
   2026-08-26, the banner said '16 unread' while the canonical store held 74, including four
   months of public feedback nobody had seen. A quiet banner is the single most effective way to
   make a full inbox look empty."
2. **Messages addressed to nobody.** `internal/messaging/inbox_routing.go:11-15`: "Measured
   2026-08-25: 36 such messages in prod and 787 in dev — all of them task-failure notifications,
   i.e. exactly the traffic whose whole purpose is to be seen."
3. **Absence retried forever.** `internal/messaging/notfound.go:14-18`: "360 notifications
   published 2026-09-24/25 named inbox docs that were never written … 160,947 nacks against 10
   acks in six hours". `docs/internal/message-plane-topology.md:349-350`: "the Mac stopped
   alerting for 6.6 days."
4. **Filed, not dispatched.** `cmd/ailang/messages_send.go:692-696`: "the write genuinely
   succeeded, the caller reasonably believed work had been queued, and nothing ever ran. Measured
   2026-08-31 — three pkg:sunholo/ailang_parse reports sat unread with no task and no job, because
   this machine's config carries no pubsub section at all."
5. **A typo'd inbox accepts mail.** `cmd/ailang/messages_inboxes.go:24-26`: "fifteen messages to
   `ailang-core`, `pkg:sunholo/ailang` and `pkg:sunholo/email_parse` — none of which exist — were
   accepted and never dispatched, and nobody noticed for two days." Then
   `cmd/ailang/messages_send_inbox_guard.go:11-15`: five requests bounced, "and each bounce was
   itself addressed to `ailang`, which is also unregistered — a bounce that bounced."
6. **A health number that cannot reach zero.** `cmd/ailang/messages_health.go:37-41`: "this
   command read DEGRADED 87 on a plane whose real undispatched backlog was 4 … A health number
   that is never zero in a healthy plane teaches the reader to ignore it, which is worse than not
   printing it." Same class at `internal/coordinator/dispatch_read_marking.go:15-18` and
   `cmd/ailang/messages_health_window.go:5-11`.
7. **A message that answers messages.** `internal/coordinator/unrouted_bounce.go:30-33`: "One
   legitimate message once produced 591 self-addressed notifications and 59 job executions in 96
   minutes (2026-08-31 backstop sweep incident), so a component that generates messages in
   response to messages carries the burden of proof".
8. **Dedup that made the pipeline impossible.** `internal/coordinator/task_dedup.go:67-80`: "the
   first handoff ever to fire in production … was suppressed ONE SECOND later against
   task-08032ebc itself … every handoff simhashes to its own parent … A handoff could therefore
   NEVER dispatch." And `:8-16`: a retry of a failed task was skipped as a duplicate of the
   failure.
9. **A docs-only commit closed a live bug.**
   `.claude/skills/mission-control/resources/gate-4-record.md:113-116`: `#676` "was closed
   `COMPLETED` by `dedf3b91f` — a **docs-only** record, 7 files, **zero code** — 1h46m after our
   own comment said it was real and unfixed."
10. **Parallel agents sharing one append target.**
    `.claude/skills/ailang-core-triage/SKILL.md:27-32`: "all 13 runs dispatched within 26 seconds
    of each other … Every branch appended to the same line of the same file and all 13 PRs came
    back DIRTY. Agents that may run in parallel cannot share an append target."

**Also worth keeping**

- `internal/messaging/github_pr.go:10-15`: "24 open `coordinator/*` PRs, of which 22 belonged to
  tasks that were already rejected or failed"; `:97-98`: "57 of 77 pending approval cards had a
  merged coordinator PR, because nothing read GitHub in this direction."
- `.claude/skills/github-issue-triage/SKILL.md:10-13`: the keyword "closable" heuristic flagged
  25 issues; "7 were fixed and 18 were live bugs, several of them P0/P1. Its `--close` flag would
  have closed all 25."
- `cmd/ailang/messages_deadline.go:13-16`: a 600s hang "banked … as the MODEL's `stream_dead`".
- `cmd/ailang/messages_send.go:470-478`: an argument parser delivered a message to the wrong
  inbox with the wrong sender and title "and printed '✓ Message sent'".
- `cmd/ailang/messages_send.go:139-145`: `--type feedback` reached a package agent under the
  wrong prompt template; task-30429ccd "went to the consumer package looking for a breakage that
  did not exist."
- `cmd/ailang/messages_inboxes.go:305-312`: a pubsub-only config was read as an agent registry;
  "two of Mark's morning design requests sat deferred for seven hours."
- `scripts/hooks/session_start.sh:46-49`: two unattended jobs "applied CLAUDE.md's attended 'ask
  before acking' rule, and BLOCKED on turn 1 waiting for a user who does not exist".
- `internal/coordinator/triage_rubric.go:9-14`: a triage row "wrote `Estimate: ~15–30 lines` and
  `Recommend: direct-fix` in the same file, with the threshold at 2."
- `cmd/ailang/messages_renotify.go:18-20`: a message "sat four hours on daneel-executor" because
  the sender had no pubsub section.
- `docs/docs/guides/notification-channels.md:82-92`: a Keychain read exited 36 with no output
  because another user held the console; Discord posts had stopped while the item was present.

---

## 10. Doc and code drift found while reading

These are stale statements at this commit. They matter here because the system's main recorded
failure is a reader trusting a confident wrong answer.

| Doc says | Code says |
|---|---|
| `GOOGLE_CLOUD_PROJECT` "is ignored entirely" (`message-plane-topology.md:288-289`; `agent-messaging.md:88`) | It is the second source in `CloudProjectSource` (`internal/config/cloud.go:52-58`). The same topology doc says so at `:84-85` |
| `AILANG_MESSAGES_PROJECT` wins, see `client.go:23` (`message-plane-topology.md:287-288`) | `internal/storage/firestore/client.go:23-29` is `NewClient` → `config.CloudProject`. The pin is read in `cmd/ailang/messages.go:182` |
| `task_id = "task-" + message_id[:8]` (three docs, 6.2) | Suffix or SHA-256 (`daemon_tasks_polling.go:706-732`) |
| Direct Firestore clients write to the `messages` collection (`cloud-messaging-integration.md:283`, `359`) | The inbox collection is `inbox_messages` (`internal/storage/firestore/messaging.go:21`) |
| `messages search --threshold` default 0.70 (`agent-messaging.md:524`) | 0.40 (`cmd/ailang/messages_search.go:20`) |
| `messages triage --threshold` default 0.75 (`agent-messaging.md:820`) | 0.50 (`cmd/ailang/messages_triage.go:22`) |
| `intent` slot is automatic if an embedder is configured (`agent-messaging.md:722`) | Only when code files or context are also present (`messages_send.go:216`) |
| Hub message kinds include `error` (`collaboration-hub.md:318`) | CHECK allows `directive`, `question`, `proposal`, `status`, `result` (`schema.go:179`) |
| Skill: "SQLite backend: All messages in `~/.ailang/state/collaboration.db`" and "SessionStart hook auto-imports GitHub issues" (`agent-inbox/SKILL.md:420-421`) | Contradicted by the same file at `:71-81` and by `session_start.sh:147-151` |
| Skill workflow ends with `ailang messages ack --all` (`agent-inbox/SKILL.md:184`) | The same file warns against it at `:109-110`; `CLAUDE.md:35` says ack per id |
| Skill links `resources/troubleshooting.md` (`agent-inbox/SKILL.md:367`) | The file does not exist; `resources/` holds `message_format.md` and `reference.md` |
| Footer hard-coded "SQLite" called "a lie" and fixed (`messages_search.go:197-202`) | Still hard-coded at `messages_triage.go:87`, `:142` and `messages_crud.go:77` |
| Schema version constant `1.6.0` (`schema.go:14`) | Migrations run to 1.9.0 and past (`schema_migrations.go:76-91`) |

[O] The interactive browser's forward calls `ForwardInboxMessage` directly, with neither the
inbox guard nor the notification the CLI `forward` gained (`messages_util.go:133-150` against
`messages_crud.go:409-414`, `458-490`).

---

## 11. Patterns worth carrying to Motoko (all [I])

1. **Every recorded outage is the same shape**: a write or read that succeeded and meant nothing.
   Their fixes all do one of three things: name the source in the output, refuse instead of
   falling back, or make the healthy value of a counter exactly zero.
2. **A queue with two states cannot say "done".** They compensated with four other records
   (CHANGELOG, design-doc tree, GitHub issue, triage file) and no link back from the message.
3. **One vocabulary, one resolver, one helper.** Each "two implementations disagree" incident was
   fixed by deriving the second from the first (message types, storage plane, registry resolver,
   notification id, dispatch detail).
4. **A side effect on read is a trap for agents.** Three separate docs warn about it.
5. **Guards belong at the call site.** The autoclose guard covered the document and missed the
   commit message; the inbox guard covered `send` and missed `forward`; the footer fix covered
   `search` and missed `triage`.
6. **Parallel agents need one file each.** A shared append-only backlog failed on the first batch.
7. **A machine-enforced rubric beats a stated one.** The triage thresholds are parsed from the
   skill file by a test.
