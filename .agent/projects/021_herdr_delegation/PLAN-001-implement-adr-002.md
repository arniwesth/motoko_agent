# PLAN-001: implement ADR-002 — the fork with `dagr apply`, and the `RunRecord` tool

Date: 2026-10-04. Status: **Ready to start — no part has begun.** It implements
[`ADR-002`](ADR-002-verified-writes-to-dagr-files.md), Accepted 2026-10-04. The operator ruled the
four questions of ADR-002 §7 as proposed that day, which was this plan's condition for starting.
Grounded at `b863ee20` on branch `feat/dagr-verified-writes`, in the worktree
`/workspaces/motoko_agent-dagr-writes`. `dagr 0.3.1`; fork `motoko-agent/herdr-dagr`, branch
`apply-command` at `ca248980`. AILANG v0.47.2, extension ABI 8.0.

This plan follows the repository's standing disciplines.
**Sequence by source surface** (`.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md`):
each part owns one surface and ends in one green state.
**Re-ground inherited anchors** (`re-ground-inherited-anchors-before-building.md`): each part
starts by checking the coordinates below against its own HEAD.
**Detector placement**: each check is a test or a `make` target the author runs before handing
in, not something a review is expected to catch.

## 0. Standing rules

1. **The ADR is the decision record.** A part that finds it wrong stops, keeps the evidence, and
   the ADR is revised with the operator's ruling. It does not build around the disagreement.
2. **Two repositories.** P1 works in `motoko-agent/herdr-dagr`. Everything else works in this
   repository, on `feat/dagr-verified-writes`, in the worktree above. Nothing is committed to
   `main`, and the shared checkout at `/workspaces/motoko_agent` is not switched or edited.
3. **No Rust toolchain in this container.** The fork is built and tested by its own GitHub
   Actions. A part that needs a local build says so and stops.
4. **`.devcontainer` is read-only to an agent.** The change to the container definition is written
   as a patch for the operator to apply, as the five earlier `PATCH-agent-confined-*.md` files in
   this folder were.
5. **Other sessions use the same `dagr` binary.** Replacing it in the running container is done
   once, at a moment the operator picks, not as a side effect of a part.
6. **No upstream pull request** (ADR-002 D1).
7. **Sizes are rough**, in working days for one agent session with review. None is measured.

## 1. Parts, by surface

| Part | Surface | Ends in | Size |
|---|---|---|---|
| P0 | none (read-only) | a baseline table of the gates | ¼ |
| P1 | the fork repository | a release with `apply`, built by the fork's CI | ½ |
| P2 | this repository's pin: `Makefile`, the CI action, `scripts/dagr-pane.sh`, a container patch | every gate green against the fork binary, and `apply` exercised by a target | ½ |
| P3 | `packages/motoko-ext-herdr/dagr.ail` and `orchestrator.ail`, pure code only | the transitions and the quote check, tested | ½ |
| P4 | `packages/motoko-ext-herdr/herdr.ail`, `register.ail`, `orchestrator.ail`: the wiring | `RunRecord` callable, the policy and the prompt changed | 1 |
| P5 | the producer skill and this project's documents | the skill teaches `apply`; ADR-002 says what was built | ¼ |
| G1 | a live session | the operator's disposition of A10 | ¼ |

P1 and P3 share nothing and can run at the same time. P2 needs P1's release. P4 needs P3, and
needs P2 only for the last gate, which checks the published documents against the fork binary.

## 2. P0 — the baseline

Read-only, on a clean checkout of the branch. Run and record, one line per gate with its result
and the first failing line: `make verify_dagr_producer DAGR_REQUIRED=1`, `make verify_herdr_gate`,
`make verify_herdr_check_answer`, `make verify_herdr_delegate_wait`, `make verify_herdr_owner_tag`,
`make verify_herdr_dagr_pane`, `make verify_herdr_orchestrator`, `make driver_plus_herdr`,
`make check_core`, and the registry and inventory gates (`ext_call_inventory`,
`declared_vs_performed`, `ext_hook_scope`, `registry_gen_check`, `registry_multiplicity`).

Four gates were red on `main` at `501cd879` for reasons that are not this project's: see
`../037_skills_system/evidence/baseline/BASELINE.tsv` on branch `feat/skills-extension`. That table
is the starting expectation, not a substitute for running them here: a fresh worktree has no build
output, and a gate that is red for want of a build is not a baseline red.

**Output:** `evidence/adr-002/BASELINE.tsv` in this folder.

## 3. P1 — the fork release

In `motoko-agent/herdr-dagr`.

1. Cut a release branch from the tag `v0.3.1` and cherry-pick `ca248980`. That commit touches only
   `src/apply.rs` and `src/main.rs`, and its parent is seven commits past the tag, so `main.rs` may
   need a small resolution. If it needs more than the usage text, stop and report: D3 assumed the
   commit stands alone.
2. `scripts/install.sh`: the download repository becomes `motoko-agent/herdr-dagr`.
3. The version becomes `0.3.1-motoko.1` (ruled, ADR-002 §7 Q1) in `Cargo.toml`,
   `Cargo.lock` and `herdr-plugin.toml`. The release workflow refuses a tag that does not equal
   `v` plus the Cargo version, and a plugin version that differs from it.
4. `skills/dagr-producer/SKILL.md`: a section on `apply`, per D9. Keep `tests/skill_examples.rs`
   green: it holds the skill's examples strict-clean.
5. Push the branch and let the fork's `ci.yml` run. Then push the tag. **Pushing the tag publishes
   a release on a public repository.** The operator has ruled what it contains. It is pushed only
   after the check below and a green `ci.yml`.

**Check before the tag:** `herdr plugin install` and `cargo` both accept the version string. A
pre-release version is the kind of thing one of them could reject, and finding out after the tag
is public costs a second release. If either rejects it, stop and take the operator's ruling on
another string.

**Ends in (A1):** the release, with both Linux musl archives, their sha256 files and `COMMIT`.

## 4. P2 — the pin

1. **`Makefile`.** `DAGR_VERSION` at `:2746` takes the fork's version. Add `DAGR_REPO`, and use it
   in the two places that name the repository in text (`:2741`, `:2797`). The comment block above
   the pin says the pin *"lives here and nowhere else"*; keep that true for the repository name.
2. **The version pattern.** `.github/actions/dst-setup/action.yml:88`, `scripts/dagr-pane.sh:40`
   and `.devcontainer/agent_sandbox/Dockerfile:565` parse `DAGR_VERSION` with a pattern that accepts
   only `X.Y.Z`. All three must accept the ruled version string and read the repository from the
   same place.
3. **CI.** `action.yml:101` fetches from the fork. The digest check stays as it is.
4. **The container.** `Dockerfile:567` installs from the fork. Written as
   `PATCH-agent-sandbox-dagr-fork.md` and a `.patch` beside it, checked with `git apply --check`.
   The operator applies it and rebuilds.
5. **`make verify_dagr_apply`**, new, for A2. On copies of fixture run files: an appending patch
   applies and the result passes `--strict`; the same patch again is refused, exit 1, file
   unchanged; a stale `test` is refused; and a patch that adds an attempt with cause type
   `operator_ruling` is refused. Skipped loudly without a binary, red with `DAGR_REQUIRED=1`, as
   the contract leg of `verify_dagr_producer` already behaves.
6. **The running container.** Until the image is rebuilt, the fork binary is installed with
   `herdr plugin install` at the pin and `~/.local/bin/dagr` is pointed at it. See §0.5.

**Ends in (A2, A3):** `verify_dagr_apply` and `verify_dagr_producer DAGR_REQUIRED=1` green against
the fork binary, and P0's table unchanged otherwise.

## 5. P3 — the pure parts

In `dagr.ail`, beside `add_note` (`:860`) and `settle` (`:827`):

- `answer_question(doc, task, quote, summary, now_ms)`: refuses an unknown task, a task whose kind
  is not `question`, and a task that is settled or has an attempt. Otherwise it appends the
  operator attempt and the `directive` event of ADR-002 D4 and sets the task `done`. The shape is
  the producer skill's own example, `examples/07-answer-question.json`.
- `add_directive(doc, task, verb, quote, summary, now_ms)`: one event, no state change.
- Each returns the `DagrStep` the other transitions return, so a refusal reaches the caller as a
  note and is not only an event in the file (`herdr.ail`, the comment above `DagrStep`).

In `orchestrator.ail`, beside `is_operator_message` (`:610`):

- `operator_said(history, quote)`: true when the quote, with whitespace collapsed, is inside an
  operator message. It reuses `is_operator_message`, so a guard's injected message does not count.

**Tests.** Inline `tests [...]` on each, and cases in `scripts/verify_mot136_dagr_producer.ail` that
emit the resulting documents as `DAGR_DOC` lines, so `make verify_dagr_producer` checks them
against the pinned binary. Cover every row of A4 and A5.

**Ends in (A4, A5):** `make verify_dagr_producer` and `make verify_herdr_orchestrator` green.

## 6. P4 — the wiring

Re-ground first. These files name the extension's tools, and each needs a look to see whether a
third tool belongs in it:

| File | Mentions | What to check |
|---|---|---|
| `packages/motoko-ext-herdr/herdr.ail:139` | `tool_names()` | add `RunRecord` |
| `packages/motoko-ext-herdr/herdr.ail:254`, `:1954` | `describe_tools`, the dispatch | add the schema and the branch |
| `scripts/verify_herdr_orchestrator.ail:180` | the tool list given to the hooks | add it |
| `src/core/dst_driver_plus_herdr.ail:176` | the profile's description of the provider | does the profile pin the catalogue? |
| `packages/motoko-ext-progress-contract-guard/`, `packages/motoko-ext-repetition-guard/` | `DelegateCheck` by name, for polling | `RunRecord` is not a poll; confirm no rule needs it |
| `src/core/session.ail`, `src/core/phase_vocab.ail` | `DelegateCheck` as the settlement path of a wait | `RunRecord` opens no wait; confirm nothing here changes |

Then:

1. **The schema and the handler.** `do_record`, beside `do_delegate` (`herdr.ail:1268`) and
   `do_check` (`:1674`). It checks the quote against `ctx.history_slice`, then calls `dagr_record`
   (`:685`) with the transition. A refused publish is an error result for this tool (D4, A6):
   `publish` (`:544`) returns a note today, and the handler has to tell "published" from "not".
2. **Measure before relying on it:** what `history_slice` holds at a tool call, before and after a
   compaction. If the operator's message is not there in the ordinary case, D5 does not work as
   written and goes back to the operator.
3. **The policy.** `.dagr/` joins the guarded prefixes (`orchestrator.ail:86`) with its own refusal
   text. The present one (`deny_reason`, `:632`) says the edit is implementation work for a
   delegate. The orchestrator must still be able to read under `.dagr/` and run `dagr check`.
4. **The prompt note** (`orchestrator.ail:300`), per D7. `scripts/verify_herdr_orchestrator.ail`
   pins its text.
5. **The plan check** (D8), in `dagr_record` where the missing-plan and unparseable-plan notes are
   composed.

A tool description is part of the catalogue, so the configuration digest moves and the generated
registry or a profile expectation may need regenerating. That is expected. Record which.

**Ends in (A6 to A9):** the gates of §2 green, or red for their baseline reason.

## 7. P5 — the skill and the record

- `.claude/skills/dagr-producer/SKILL.md` is replaced by what the fork binary prints with
  `dagr --skill`, so the two stay identical (D9).
- ADR-002 gets its implementation status and anything the parts found that it had wrong.
- A handoff template line for orchestrators: answers and rulings go through `RunRecord`.

## 8. G1 — the live check

A real orchestrator session on a small plan with one `question` task, for A10: the answer in chat,
the call, the view; then a call with words the operator did not write. Observed and reported. The
operator records a disposition.

## 9. What is not in this plan

Everything ADR-002 §5 lists: carrying answers across a restart, the extension publishing through
`apply`, the ADR-001 D4 findings, the `reject` and `unblock` verbs, and a mechanical check that a
claimed write happened.

## 10. Open questions, each with what settles it

| # | Question | Settled by | If it goes the other way |
|---|---|---|---|
| Q1 | Does the `apply` commit cherry-pick onto `v0.3.1` cleanly? | P1 step 1 | D3 returns to the operator: release the branch tip instead, with the seven view commits |
| Q2 | Do `cargo` and `herdr plugin install` accept the version string? | P1, before the tag | The operator rules another string |
| Q3 | Is the operator's message in `history_slice` at a tool call, after compaction too? | P4 step 2 | D5 returns to the operator |
| Q4 | Does adding a tool move a pinned catalogue or digest in a profile? | P4 re-grounding | The part regenerates it and records which |
| Q5 | Which lands first on the extension: this plan's P3 and P4, or 008 ADR-001's WI-2? | **Ruled 2026-10-04: this plan's.** | 008's WI-2 re-grounds against it |

## Related records

- [`ADR-002-verified-writes-to-dagr-files.md`](ADR-002-verified-writes-to-dagr-files.md)
- [`ADR-001-run-file-authorship-and-correspondence.md`](ADR-001-run-file-authorship-and-correspondence.md)
- [`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) §10
- `../008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md` (branch
  `arniwesth/008-plan-structure-in-dagr`, draft PR #215)
