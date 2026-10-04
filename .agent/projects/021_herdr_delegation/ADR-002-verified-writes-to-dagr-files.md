# ADR-002: Verified writes to dagr files — a tool for operator input, and the fork with `dagr apply`

Date: 2026-10-04
Status: **Proposed, v0.1. D1 and D2 are the operator's rulings of 2026-10-04. D3 to D9 are this
document's proposal for carrying them out and have not been ruled on.** Not reviewed.
Grounded at: branch `feat/dagr-verified-writes`, cut from `origin/main` at `b863ee20`;
`dagr 0.3.1 (contract v3; reads v1/v2)`; fork `motoko-agent/herdr-dagr`, branch `apply-command` at
`ca248980`. Every `file:line` below was read at that HEAD.
Implementation status: documentation only. Nothing here is built.

Relates to:

- [`ADR-001`](ADR-001-run-file-authorship-and-correspondence.md) D1 and its corollary: the run file
  has one writer, it is not the model, and *"when the model needs to express something the
  extension cannot, that is an extension gap to be filed and fixed"*. This ADR fixes one such gap.
  ADR-001 is still Proposed v0.1 and is not changed here.
- [`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) §10.5 (the plan is read
  and never written, built 2026-09-08) and §10.6 (`dagr apply` exists on a fork). D1 reverses the
  recommendation §10.6 ends on.
- `../008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md`, accepted 2026-10-04,
  **not on `main`**: it is on branch `arniwesth/008-plan-structure-in-dagr`, draft PR #215. Its
  ruling F2 says the fork is not adopted now. D1 here is a later ruling by the same operator and
  reverses F2. Its WI-2 edits the same extension files as this ADR's tool. §6 says what that needs.

---

## 1. What happened

All of this is from the 037 run on 2026-10-04. Times are UTC. The operator's lines are in the
orchestrator's journal, `.motoko/sessions/session_1791055678628-7135fdf7b5e4b8ce/journal.jsonl`,
which is local and not in the tree.

| Time | What |
|---|---|
| 06:06 to 06:16 | The operator answers the run's four open `question` tasks in chat: `Q-SPEND`, `Q-CGRAPH`, `Q-OPENAI`, `Q5`. |
| 06:31 | The operator: *"Why can't you update the plan file?"* The orchestrator's handoff told it never to write under `.dagr/`. |
| 06:32 | The operator: *"Yes, override the rule and record my rulings"*. |
| 06:33 | The orchestrator rewrites `.dagr/run-037-plan001.json` with `python3` and `json.dump`. It gives the four tasks an operator attempt whose cause type is `operator_ruling`, which the contract does not have, and no `ended_at`. Nothing checks the result. |
| 06:35 | The operator: *"the dagr graph should also be updated right?"* It is not. The view renders the extension's own run file, where the four tasks are still `queued`. |
| 08:56 | A further ruling is relayed. The orchestrator replies *"I've updated the Q-SPEND entry in the run file"*. No file under `.dagr/` changed, and its one tool call in that turn was a read. |
| 08:59 | A supervising session runs `dagr check --strict` on the plan file: four `E133` errors, four `W203` warnings. |
| 09:28 | The supervising session repairs the plan file by hand: a script, `dagr check` on a candidate, then a rename. |

Two different things failed.

1. **An invalid write.** A model wrote a dagr document by hand and nothing validated it. It stood
   for nearly three hours.
2. **A claim nobody could check.** The orchestrator said a ruling was recorded when nothing had
   been written. The only way to find out was to compare file times with the pane.

Both have one cause: **there was no route.** The operator asked for something reasonable, the
extension had no way to do it, and a hand edit was what was left. That is the corollary of
ADR-001 D1, observed a second time. The first was the PLAN-004 run that ADR was drafted from.

The hand edit also did not do what was wanted. It went into the plan file, and a plan task already
seeded into the run file is never touched again (`packages/motoko-ext-herdr/dagr.ail:194`). So the
answers reached a file the view does not draw.

## 2. What exists

- **The extension's own writes are already verified.** `dagr_record`
  (`packages/motoko-ext-herdr/herdr.ail:685`) reads the run file, applies one pure transition and
  calls `publish` (`herdr.ail:544`), which writes a candidate, runs `dagr check --strict` on it and
  renames it only if dagr does not call it invalid. A rejected candidate is removed and the live
  file stands.
- **It has no transition for operator input.** Its tools are `Delegate` and `DelegateCheck`
  (`describe_tools`, `herdr.ail:254`). `dagr.ail` has `add_note` (`:860`) and nothing that settles
  a task on the operator's word.
- **A tool handler can see what the operator said.** `ProviderCtx` carries `history_slice`
  (`packages/motoko-ext-abi/types.ail:1003`), filled from the session's history
  (`src/core/session.ail:1947`). The orchestrator policy already tells an operator message from a
  guard's injected one (`is_operator_message`, `orchestrator.ail:610`).
- **Orchestrator mode does not cover `.dagr/`.** The guarded prefixes are `src/`, `scripts/`,
  `packages/` and `tools/` (`orchestrator.ail:86`). The standing prompt note lists *"settle the run
  file"* among the orchestrator's own work (`orchestrator.ail:300`), which reads as permission to
  write it.
- **`dagr` 0.3.1 only reads.** Its commands are `check`, `view` and `stats`.
- **A write command exists on the fork.** `dagr apply <run.json> --patch <patch.json> [--strict]`
  applies an RFC 6902 patch under dagr's own read-modify-write, validates the result against the
  contract and publishes by atomic rename. Exit 0 is applied, 1 is refused (a failed `test`, a
  patch that does not apply, or a result the contract rejects), 2 is usage or IO. The commit adds
  `src/apply.rs` (399 lines) and 84 lines to `src/main.rs`, and changes nothing else.
- **The fork has never been released.** It has no releases. `apply-command` is eight commits ahead
  of the `v0.3.1` tag: seven upstream commits that came after the release (the view's inspector and the
  README figures), and the `apply` commit. `scripts/install.sh` names `aemrebarut/herdr-dagr` as the place to download
  from. GitHub Actions are enabled on the fork, and its `release.yml` builds five targets with
  sha256 files and a `COMMIT` marker when a `v*` tag is pushed.
- **This container cannot build it.** There is no Rust toolchain here.
- **The pin is in four places.** `Makefile:2746` (`DAGR_VERSION ?= 0.3.1`, with the repository
  named in the text at `:2741` and `:2797`), `.devcontainer/agent_sandbox/Dockerfile:567`,
  `scripts/dagr-pane.sh:40`–`42` and `.github/actions/dst-setup/action.yml:88`–`101`. Three of them
  parse the version with a pattern that accepts only `X.Y.Z`. `.devcontainer` is mounted read-only
  inside the agent container.

## 3. Decision

**D1. The tree runs our fork of dagr, pinned. No upstream pull request for now.** *(Operator,
2026-10-04: "We will not do upstream PRs for now. This is a very good reason to move to our own
fork and pin it.")* The reason is `apply`: a dagr file that anything other than the extension
writes needs a write that is validated and that can be refused. This reverses the recommendation
DESIGN §10.6 ends on, and it reverses F2 of 008 ADR-001. That ADR's D7 named the condition:
*"adopt the fork when something needs it"*, with `dagr apply` in its table of what would.

**D2. The extension gets a tool for operator input.** *(Operator, 2026-10-04: asked for the tool to
be planned.)* An operator's answer or ruling reaches the run file through the extension, by the
path that is already verified, and so reaches the view.

**D3. The first fork release is `v0.3.1` plus `apply`, and nothing else from upstream.** A release
branch on the fork is cut from the `v0.3.1` tag and takes the `apply` commit, without the seven
unreleased view commits. The binary then differs from the one running today by one command. It
also takes three small changes: `scripts/install.sh` downloads from `motoko-agent/herdr-dagr`; the
version in `Cargo.toml` and `herdr-plugin.toml` becomes `0.3.1-motoko.1`, so `dagr --version` says
which binary it is; and the bundled producer skill gains a section on `apply` (D9). The contract
is unchanged, so every document stays readable by an upstream binary.

**D4. The tool is `RunRecord`, and it does three things.**

| `kind` | Needs | Writes | Changes state |
|---|---|---|---|
| `answer` | `task`, `quote` | An attempt by `operator`, state `done`, evidence `reported`, whose receipt holds the quote; and a `directive` event with verb `answer` | The task becomes `done` |
| `rule` | `task`, `quote` | A `directive` event with verb `rule` | No |
| `note` | `detail` | A `note` event | No |

`summary` is optional on `answer` and `rule`: one sentence saying what the orchestrator takes the
operator to have decided. `dagr_plan` is accepted as on `Delegate`. The tool writes only the
extension's run file. It never writes a plan.

`answer` is refused unless the task is in the run file, has kind `question`, is not settled and has
no attempt. A ruling that changes an earlier answer is a `rule`.

The result is the receipt. On success it names the run file, the task and the attempt or event
written. If `dagr check` rejects the candidate, the call fails and says so: for this tool the
write is the whole purpose, so a refused publish cannot come back as a success with a note, which
is what `publish` returns to `Delegate`.

**D5. The operator's words are checked, and kept apart from the orchestrator's reading of them.**
`quote` must appear in an operator message in the session's history, compared after collapsing
whitespace. A message from the assistant, from a tool, or injected by a guard does not count. If
it is not found the call is refused and nothing is written. The record stores the quote and the
`summary` as two things, with the summary labelled as the orchestrator's. On 2026-10-04 the
operator wrote *"I approve everything that needs approval"* and the orchestrator recorded a $4 cap,
five trials and OpenAI out of scope. The record should show which words were whose.

**D6. The evidence tier is `reported`.** The actor is the operator and the envelope is their
message. `verified` stays what it means in DESIGN §4: a mechanical check of the work. Checking
that the operator said something is what makes it `reported` and not `asserted`.

**D7. Orchestrator mode points at the tool and guards `.dagr/`.** The prompt note stops saying
*"settle the run file"* and says that the extension settles it, that the operator's answers go
through `RunRecord`, and that nothing under `.dagr/` is written by hand. `.dagr/` joins the guarded
prefixes with its own refusal text naming `RunRecord`, because the present text says the edit is
implementation work for a delegate, which is wrong for this case. The operator's
`[orchestrator:direct]` still lifts it for one message.

**D8. An invalid plan file is reported, not repaired.** When a plan is in effect, the extension
runs `dagr check --strict` on it at each write point and says so in the tool result while it
fails, as it already does for a plan that is missing or does not parse (`herdr.ail:685`, case 26
of `scripts/verify_mot136_dagr_producer.ail`). It does not change the plan. On 2026-10-04 this
would have reported the hand edit at the next delegation.

**D9. A writer that is not the extension changes a dagr file with `dagr apply`.** That is a plan
owner editing a plan, and a Claude Code or Codex session acting as producer. The producer skill
keeps its loop for creating a file (write a candidate, check it, rename it) and uses `apply` with a
`test` precondition for every change after that. The copy in `.claude/skills/dagr-producer/` is
identical to the one the binary prints with `dagr --skill` today, and the two stay identical.

## 4. Acceptance

- **A1. The fork release exists.** A tag on `motoko-agent/herdr-dagr` whose release holds the two
  Linux musl archives with their sha256 files and the `COMMIT` marker, built by the fork's release
  workflow with `cargo test --release --locked` green. `dagr --version` prints the fork's version.
- **A2. `apply` does what §2 says, at the pin.** A `make` target, run on copies of fixture run
  files: an appending patch applies and the result passes `dagr check --strict`; the same patch
  sent again is refused with exit 1 and the file is unchanged; a patch with a stale `test` is
  refused; and the 2026-10-04 edit, replayed as a patch that adds an attempt with cause type
  `operator_ruling`, is refused.
- **A3. The pin names the fork in all four places**, CI fetches the fork's release by digest, and
  `make verify_dagr_producer` is green against the fork binary with `DAGR_REQUIRED=1`.
- **A4. The transitions are pure and tested.** `answer` on a queued question gives a document that
  passes `dagr check --strict`, with the task `done`, one attempt by `operator` at `reported`, and
  one `directive` event. It is refused for an unknown task, for a task that is not a question, and
  for one already settled. `rule` and `note` add one event and change no state.
- **A5. The quote check is pure and tested.** Accepted: a quote inside an operator message, and the
  same with different whitespace. Refused: an empty quote, and a quote found only in an assistant
  message, a tool result, or a guard's injected message.
- **A6. The result is the receipt.** A success names the file, the task and what was written. A
  candidate that `dagr check` rejects makes the call fail, and the live file is unchanged.
- **A7. Orchestrator mode.** The prompt note names `RunRecord` and no longer says "settle the run
  file". `WriteFile`, `EditFile` and the shell forms the policy already recognises are refused
  under `.dagr/` with text that names `RunRecord`, and `[orchestrator:direct]` lifts it.
- **A8. An invalid plan is said out loud.** With a plan in effect that fails `--strict`, each write
  point's result says so; once it passes, the note stops; the plan file is byte-identical
  throughout.
- **A9. The gates.** `make verify_herdr_orchestrator`, `make verify_dagr_producer` and
  `make driver_plus_herdr` are green. Every gate that was green in a baseline taken before the
  first change is still green, and a gate that was red is red for the same reason.
- **A10. Live, once.** In a real orchestrator session whose plan has a `question` task: the
  operator answers in chat, the model calls `RunRecord`, and the dagr view shows the task done
  with the operator's words. A call with words the operator did not write is refused. These are
  observed and reported, not gated.

## 5. What this does not decide

- **How an answer survives a restart.** A new session has a new run file, seeded from the plan, so
  an answer recorded only in the old run file is not in it. 008 ADR-001 D4 and D5 change how a run
  relates to its plan and are where this belongs. Until then the plan's owner carries it over, with
  `dagr apply`. Writing answers into the plan from the tool is not proposed: 008 D2 says a plan
  holds no state.
- **Whether the extension should publish through `apply`.** With a `test` precondition it would
  notice a second writer instead of reading whatever is on disk. That is the option DESIGN §10.6
  calls A1. Not proposed here; the fork makes it possible.
- **The three `dagr check` findings of ADR-001 D4.** They were written as requests to upstream. On
  our own fork they can be built. Not planned here.
- **The other directive verbs**, `reject` and `unblock`. They change attempts and need their own
  rules.
- **Catching a claim that nothing backs.** D4 makes the claim checkable: "recorded" with no
  `RunRecord` call in the journal is false. Checking it mechanically is the correspondence pass of
  ADR-001 D5, which has no home yet.
- **The name `RunRecord`.**

## 6. Costs, and what to settle before building

- **We own a build.** CI and the container stop fetching a binary upstream published and fetch one
  our fork built. Each upstream release we want is a rebase we do. `apply` is a compare-and-set and
  upstream's contract says dagr carries none, so the fork is probably permanent. That last part is
  an inference: no pull request has been opened to test it, and D1 says none will be for now.
- **The quote check can refuse a true answer.** After compaction the operator's message may no
  longer be in the history. The call is then refused, and the operator has to say it again. That
  is the safe direction, and it is a cost.
- **A model can still write the file.** `python3 - <<EOF` is not a form the policy recognises
  (`orchestrator.ail:44` says so of itself). D7 removes the reason to, and D8 reports the result.
- **The same files are about to be edited twice.** 008 ADR-001's WI-2 changes `orchestrator.ail`,
  `register.ail`, `dagr.ail` and the producer skill. So does this. One has to land first and the
  other re-ground. This ADR's change is the smaller and depends on nothing in 008, so it is
  proposed first. The operator decides.
- **008 ADR-001 now says something its operator has overruled.** Its F2, its D7 and its WI-5 still
  read "not now". That document is on another session's branch and is not edited from here.

## 7. Open questions for the operator

| # | Question | Proposed |
|---|---|---|
| Q1 | What the first fork release contains, and its version string | `v0.3.1` plus `apply` only; `0.3.1-motoko.1` (D3) |
| Q2 | The tool's name | `RunRecord` |
| Q3 | Which lands first on the extension: this, or 008's WI-2 | This |
| Q4 | Who amends 008 ADR-001 to record that F2 was reversed | The session that owns PR #215 |

## Evidence

- Plan file before and after the repair: `.dagr/run-037-plan001.json` (local, gitignored). The
  findings at 08:59 were `E133` on `tasks[1]`, `[2]`, `[3]` and `[7]`, each *"unknown cause type
  \"operator_ruling\""*, and `W203` on the same four.
- The extension's run file for that session: `.dagr/run-w8-p1-1791055678628.json`, last written
  06:07:01, clean under `--strict`, with the four question tasks `queued`.
- The fork: `gh api repos/motoko-agent/herdr-dagr/compare/v0.3.1...apply-command` (eight ahead,
  none behind), and commit `ca248980` (`src/apply.rs` +399, `src/main.rs` +84).
- The other ADR: `git show arniwesth/008-plan-structure-in-dagr:.agent/projects/008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md`.
