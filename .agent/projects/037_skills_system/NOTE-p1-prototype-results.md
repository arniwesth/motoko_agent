# NOTE: P1 prototype results — the numbers, and what each one means for ADR-001

Date: 2026-10-04. For gate **G1** (PLAN-001 §3). This note reports and recommends; it rules on
nothing.

- **Written** on `feat/skills-extension` at `980f1aa3`.
- **Measured** in the scratch worktree `/workspaces/motoko_agent-p1proto` at `e483c2a8`, with the
  prototype uncommitted on top, on AILANG v0.47.2. `src`, `packages`, `scripts`, `tools` and the
  `Makefile` are identical at the two commits.
- **Nothing was re-run for this note.** The tables, scripts and small captures are copied to
  `evidence/p1/` (index: `evidence/p1/README.md`). The headline counts below were recomputed
  from the copied tables and agree with the delegates' reports.
- A figure marked *(report)* comes from a delegate's report and has no file of its own in
  `evidence/p1/`.

## 1. The answers

| # | Question (PLAN-001 §7) | Answer |
| --- | --- | --- |
| Q1 | Do the inventories accept an extension that imports `std/yaml`? | **Yes.** |
| Q2 | Does OpenAI accept a 16,000-char tool description? | **Not measured; closed by ruling.** No OpenAI request was sent. All seven other families accept it. |
| Q3 | Does the bare relative root index the workdir's skills in a real session, in both layouts? | **Split.** Yes when the workdir is outside the launch directory. When it is under it, a session launched as the TUI would launch it loads no extension at all. |
| Q4 | Do models load a matching skill, follow it, and reload it after compaction, at a cost worth paying? | **Split.** Load: yes. Follow: yes. Reload: not once under the structural compactor, once per run under `compaction_ai`. A reload costs about 6,075 tokens. What it costs to work without the text was not measured. |

**Recommendation for G1: revise the ADR first, then go.** The revision is narrow: D8, and the
text that records two rulings already made. Reasons are in §8.

**Decisions that return to the operator** (§6):

1. **D8, the size check.** Its claim that a skill the handler returns is never cut is
   contradicted.
2. **D8, reloading.** Under the structural compactor it did not happen, which is the condition
   D8 and PLAN-001 Q4 name for opening the pinning decision.
3. **D4, the OpenAI leg.** Closed by the ruling of 2026-10-04; the ADR's text still says
   otherwise.
4. **D7, the subdirectory layout.** Ruled its own issue for the TUI and core owner on
   2026-10-04; pending there. The ADR's text does not yet carry that scope.

## 2. Q1 — `std/yaml` in an extension's closure: yes

P1.1 wired a registration-shaped probe that imports `std/yaml (decode)`. P1.2 then wired the
prototype itself beside it.

| Gate | P0 baseline, no skills code | With the probe and the prototype wired |
| --- | --- | --- |
| `ext_ambient_inventory` | green | PASS, 21/21 extensions, 19/19 std modules, 0 unresolved |
| `ext_hook_scope` | red, on `test_dummy` only | red, on `test_dummy` only; `skills` and `yaml_probe` are `config-caps pass` (20 of 21) |
| `profile_definition` | green | exit 0 |
| `registry_gen_check` | green | green, 21 packages |

- `std/yaml` resolves, and `decode` is classified proven pure: its cached interface has a closed
  empty effect row *(report)*.
- A negative control hid the cached `std/yaml` interface; the inventory then failed closed on
  `std/yaml.decode` *(report)*. The pass depends on the interface being read.
- **Only these gates were run with the prototype wired.** The DST lanes,
  `declared_vs_performed` and the rest of ADR A7's list were not.

**For the ADR:** D9 stands. The subset parser is not needed.

Evidence: `evidence/p1/p1.2/gate_*.out`; `evidence/baseline/BASELINE.tsv`.

## 3. Q2 — a 16,000-char index: yes on seven families; OpenAI not sent

Row e sent one session per family through OpenRouter. The index was exactly 16,000 chars (35
skills); the whole `Skill` description was 16,517 chars.

| Family | Model | Outcome | First response |
| --- | --- | --- | --- |
| DeepSeek | `deepseek/deepseek-v4-pro` | accepted | `Skill(workdir-stamp)` |
| Meta | `meta/muse-spark-1.3-contributor` | accepted | text only; `Skill(workdir-stamp)` in the second |
| Tencent | `tencent/hy3` | accepted | `Skill(workdir-stamp)` |
| Qwen | `qwen/qwen3.6-35b-a3b` | accepted | `Skill(workdir-stamp)` |
| Xiaomi | `xiaomi/mimo-v2.6-pro` | accepted | `Skill(workdir-stamp)` |
| Anthropic | `anthropic/claude-haiku-4.5` | accepted | `Skill(workdir-stamp)` |
| Google | `google/gemini-2.5-flash` | accepted | `Skill(workdir-stamp)` |
| OpenAI | none | **out of scope by the operator's ruling of 2026-10-04; no request sent** | |

- No provider rejected the request. All seven picked the one matching skill out of 35.
- The first request was 6,348 to 7,616 input tokens.
- This is one session per family.

**For the ADR:** D4's budget stands for these seven families. The question PLAN-001 asked, about
OpenAI, has no measured answer. D4's "Providers" paragraph and A5's last bullet ("OpenAI
included") still describe an open test and need the ruling written into them.

Evidence: `evidence/p1/row_e.tsv`, `row_e_skill_description.txt`.

## 4. Q3 — a workdir that is not the launch directory: split

Six sessions against a local recorder; no model was called.

| Session | Launch directory | `--workdir` | Skills listed | `Skill` load | `ReadFile` on a bundled file |
| --- | --- | --- | --- | --- | --- |
| `L1-sibling` | worktree root | absolute, outside it | yes | exit 0 | ok |
| `L2B-parent-tmp` | direct parent | relative | **no** | **exit 1** | **fails** |
| `L2A-descendant-worktree` | worktree root, five levels up | relative | **no** | **exit 1** | **fails** |
| `L2B-relative-sandbox` | direct parent | relative, sandbox relative too | **no** | **exit 1** | **fails** |
| `L2B-control-abs-workdir` | direct parent | absolute | yes | exit 0 | ok |
| `L2B-diag-profile-via-repo` | direct parent | relative, profile found through `MOTOKO_REPO` | yes | exit 0 | **fails** |

**Layout 1 passes all three checks.** The `Skill` description is byte-identical to P1.2's, the
load returns `.motoko/skills/workdir-stamp` as its first line, and `ReadFile` under that
directory succeeds.

**Layout 2 fails before the skill root is read.** `session_start` reports
`loaded_extensions: []`, the request carries no `Skill` tool, there is no warning, and the
session exits 0. The cause is the relative `--workdir`, not the root:

- `supervisorWorkdirArg` (`src/tui/src/runtime-process.ts:327`) makes `--workdir` relative when
  the workdir is under the TUI's directory, while the sandbox root stays the workdir (`:475`).
- `profile_dir_for` (`src/core/config.ail:195`) prefixes that value onto the profile path. The
  sandbox does not find it, the profile reads as empty, and no extension loads.
- `resolve_workdir_path` (`src/core/tool_runtime.ail:493`) prefixes the same value onto the
  native file tools' paths, so `ReadFile` fails as well.

These four anchors were re-read at `980f1aa3`.

**The root itself is exonerated.** In the two control sessions the launch directory held a decoy
skill. With the extension loaded, the index was the workdir's four skills and the decoy appeared
in no request.

**Operator ruling, 2026-10-04:** layout 2 is recorded as its own issue for the TUI and core
owner, and 037 proceeds on layout-1 evidence.

**Not run: the TUI.** The scratch worktree has no `src/tui/node_modules`. Every session is the
TUI's command line and environment built by hand, and the relative `--workdir` in layout 2 comes
from reading `supervisorWorkdirArg`, not from executing it.

**For the ADR:**

- **A10** holds in layout 1. It cannot be observed in layout 2 until the issue is fixed.
- **A9's `ReadFile` clause** holds in layout 1 and fails in layout 2, even with the skill loaded
  (`L2B-diag-profile-via-repo`).
- **D7** says that in a session `.motoko/skills` is the workdir's "wherever the TUI was started".
  That is true of how the path resolves and not true of a layout-2 session as launched.
- **D10** calls the directory line "the form the native file tools accept". That holds in
  layout 1 only.

Evidence: `evidence/p1/p1.3a/capture/<session>/layout.txt` and `summary.txt`.

## 5. Q4 — load, follow, reload, cost: split

ADR A5 says these numbers are reported, not gated. No threshold is applied to them here.

### Row b — loading and following, seven models

459 scored sessions through the real runtime under `skills_proto`, in layout 1. The index held
six skills. Three profile models ran five trials; four added models ran three, so one session is
2 points for the first three and 3.3 for the others.

M2 trigger tasks:

| Model | Sessions | `Skill` is the first call | `Skill` called in the first response | Expected skill loaded in the first response | Expected skill loaded within the run |
| --- | --- | --- | --- | --- | --- |
| `meta/muse-spark-1.3-contributor` | 50 | 45 (90%) | 45 (90%) | 44 (88%) | 49 (98%) |
| `deepseek/deepseek-v4-pro` | 50 | 46 (92%) | 49 (98%) | 49 (98%) | 49 (98%) |
| `deepseek/deepseek-v4-flash` | 50 | 47 (94%) | 49 (98%) | 49 (98%) | 49 (98%) |
| `deepseek/deepseek-v4.1-flash` | 30 | 30 (100%) | 30 (100%) | 30 (100%) | 30 (100%) |
| `z-ai/glm-5.3` | 30 | 30 (100%) | 30 (100%) | 30 (100%) | 30 (100%) |
| `xiaomi/mimo-v2.6-pro` | 30 | 30 (100%) | 30 (100%) | 30 (100%) | 30 (100%) |
| `tencent/hy4-preview` | 30 | 28 (93%) | 29 (97%) | 29 (97%) | 29 (97%) |

- **Control tasks: no `Skill` call in any of 135 sessions, in any request.**
- **Stamp tasks: `STAMP.txt` held the bundled token in 53 of 54 sessions.** In all 54 the model
  called `Skill(workdir-stamp)` first and read the bundled file with `ReadFile`. The one miss
  (muse) loaded the skill, read the file, and stopped without writing.
- **The research's proxy** scored 43, 49 and 47 of 50 for the first three models on the same
  tasks *(report)*; the harness gives 44, 49 and 49.
- **The misses.** muse: four empty first responses, each followed by a load at the next request;
  one `Skill({})` with no name; one plan written as text with no call. pro, flash and
  `hy4-preview`: one each, all on the same task (`ailang check … fails`), where the model went
  to the file or the shell and never called `Skill` *(report)*.
- **Step caps:** 3 for M2-task sessions, 8 for stamp sessions.

**For the ADR:** D4's placement of the index works in the harness as it did in the proxy, and on
four models the proxy never saw. A5's first bullet is measured.

### Row c — reloading after compaction

One run per compactor per model, up to 60 requests, on a task that names the `dagr-producer`
skill. Nothing in the task prompts a reload.

| | Structural, pro | Structural, flash | Structural, muse | `compaction_ai`, pro | `compaction_ai`, flash | `compaction_ai`, muse |
| --- | --- | --- | --- | --- | --- | --- |
| Requests | 60 | 60 | 60 | 60 | 60 | 40 |
| First compacted request | 20 | 32 | 24 | 24 | 28 | 21 |
| Requests sent without the skill's text | 40 | 28 | 36 | 30 | 28 | 3 |
| **`Skill` reloads** | **0** | **0** | **0** | **1** | **1** | **1** |
| Tokens of one reload | – | – | – | 6,075 | 6,075 | 6,077 |
| Input spent carrying the reloaded copy | 0% | 0% | 0% | 1.5% | 0.3% | 6.7% |
| Summariser folds | – | – | – | 3 | 1 | 1 |
| Reports reached, of 14 | 13 | 7 | 14 | 14 | 9 | 14 |
| Final run file under `dagr check` | exit 0 | exit 0 | exit 0 | exit 0 | exit 0 | exit 0 |

- **Under the structural compactor the standing instruction had no visible effect.** No model
  called `Skill` again in 104 requests that carried only the elided stub. D8 expected a reload
  about every ten tool calls.
- **In its structural run muse fetched the text another way:** five reads of `SKILL.md` through
  `BashExec` after the first compaction.
- **The pro structural run did not stay at tier 1.** It spent 33 requests at tier 1 (keep 10), 4
  at "hard" (keep 5) and 3 at "emergency" (keep 1 to 3) *(report)*. D8's "about every ten tool
  calls" assumes tier 1.
- **Under `compaction_ai` each model reloaded once.** pro's reloaded copy was folded away again
  and it did not reload in the 19 requests that followed.
- **A reload costs about 6,075 tokens.**
- **What working without the text costs was not measured.** Every run ended with a run file that
  passes `dagr check`. Nobody judged whether each report was recorded correctly beyond that.
- **Each cell is one run.**

Read these with caveats (a) and (c) in §7: the declared limit was 131,472, and the
`compaction_ai` summariser returned a one-line non-summary in four of its five folds.

**For the ADR:** this is the measurement D8 asked for, and its answer under the structural
compactor is that reloading does not happen. D8 says what follows: "If reloading is too costly
or does not happen, pinning becomes a follow-up decision." PLAN-001 Q4 gives the operator the
choice at G1: stop, or open that decision.

### Row d — the size check

Declared `context_limit` 16,000 on `deepseek-v4-pro`, three sessions.

- **The check answered with its error in 3 of 3, and `Skill` was not called again in any.** The
  error, verbatim: `Skill 'dagr-producer' does not fit this model's context: about 6075 tokens
  against a context limit of 16000, and a skill is loaded only when it is under 25% of the limit.
  It was not loaded. Do not call Skill for it again in this session.`
- **In 2 of the 3 the same text reached the context anyway.** The model ran `dagr --skill`
  through `BashExec`, which prints that skill. The third was listing the skill's directory when
  its step cap ended it. The check guards the `Skill` tool, not the text.
- **`rekaai/reka-edge`, a real 16,384-token window, was not viable:** three sessions, one request
  each, no tool call. The check has not been seen on a model whose real window is small.

**For the ADR:** D8's size check does what it says when the declared window is small. A5's
fourth bullet is measured with a declared limit, not with a small model.

Evidence: `evidence/p1/row_b_ext.tsv`, `row_b_ext_sessions.tsv`, `row_c.tsv`, `row_c_runs/`,
`row_d.tsv`.

## 6. What returns to the operator

### 6.1 D8 — the size check and the compactor's cap use different limits

D8 says: "The threshold sits under the compactor's 30% so that a skill the handler does return
is never cut by that rule." **That is contradicted.**

- **The handler is given the declared window.** Its context is built with `raw_window_of`
  (`src/core/session.ail:3601`, `:3645`).
- **The compactor is given a smaller working limit:** the declared window less 65,536 and less
  the pinned prefix, floored at 0 (`working_budget_for_ext`, `src/core/context_limit.ail:91`,
  called at `session.ail:3771`). `cap_oversized_tool_results`
  (`compaction_structural.ail:85`) cuts a tool result at 30% of that.
- **Shown in a recorder session, `dry/cap-80000`.** Declared 80,000, so the compactor's limit is
  12,528. `dagr-producer` loaded with exit 0: it is 7.6% of 80,000. The next request carried it
  as `…[elided 24204 chars]` followed by `[large tool result capped; use grep or offset+limit
  instead of re-reading in full]`: it is 48% of 12,528. A scripted reload was capped the same
  way while it was the newest tool result.
- **Windows affected, by arithmetic from the two rules** with the 1,936-token prefix of these
  sessions: for `dagr-producer`, a declared window of about 67,500 to 87,700; for a skill at V7's
  60,000-char limit, up to about 117,500.
- **Committed profiles.** Two set `context_limit` in `config.json`: `local` at 100,000 and
  `deepseekv4-flash-compaction-live` at 262,144. Under `local`, on the same prefix, a skill over
  about 39,000 encoded chars would load and then be capped. The largest fixture skill is about
  24,300. The other profiles take the model's window, which this note did not resolve.
- **Not measured: how a model reacts to the capped result.** No model was called. The capped
  result reads as elided, which the standing instruction answers with "call `Skill` again", and
  carries advice not to re-read in full. That is the loop D8 set out to prevent.

What the ruling has to settle is which limit the check compares against. Two observations for
it, both mine and neither measured:

- Handing the handler the compactor's limit is a change in core, where the handler's context is
  built.
- That limit is 0 for any declared window of about 67,500 or less, and D8 loads the skill when
  the limit is 0. So that change alone would switch the check off in the range where row d
  showed it working.

**A6b follows D8.** As worded it tests a skill "within D8's bounds" against
`compact_for_pre_step`. Whether it passes depends on which limit the test gives to which side.

### 6.2 D8 — reloading did not happen under the structural compactor

Section 5, row c. The operator's choices, as PLAN-001 Q4 frames them, are to stop or to open the
pinning decision. A third reading is open to the operator and is not in the plan: accept v1
without reloading under that compactor. The evidence for it is that all three structural runs
finished with a valid file; the evidence against is that nothing measured the quality of the
work done without the text.

The standing-instruction sentence in the `Skill` description is the part of D8 with no observed
effect under structural elision.

### 6.3 D4 — the OpenAI leg is closed by ruling

Nothing to decide. The ADR's D4 and A5, and PLAN-001's Q2 row, still read as if OpenAI were to
be tested. The reported 1,024-char cap on OpenAI function descriptions remains untested.

### 6.4 D7 — the subdirectory layout is pending its own issue

Nothing to decide for 037 beyond the ruling already made. D7, D10's directory-line sentence, A9's
`ReadFile` clause and A10 need their scope stated as layout 1 until the TUI and core issue is
resolved. This note did not check whether that issue has been filed.

### 6.5 What stands

| Decision | What P1 showed |
| --- | --- |
| **D2** | Not exercised: the prototype has no refusal path, as PLAN-001 P1.2 specifies. Its literal `{ config, caps }` registration passes the registration-shape check (`skills config-caps pass`). Q5 was ruled on 2026-10-04: Amendment 5 lands before the 033 release tag. |
| **D4** | The index in the `Skill` description triggers loading on seven models with no false positive in 135 control sessions, and a full-budget index is accepted by seven families. |
| **D9** | Q1 is yes. |
| **D10** | Through a stub port: an unknown name, a path-shaped name and a missing name are errors listing the names; a file gone since startup is an error; V4 to V7 at call time are errors naming the rule; the 25% boundary is exact (loads at a limit of 24,309, refuses at 24,308). Not exercised: an edit to a skill's text arriving in the next result, and a file that is present but unreadable. |

The prototype also left these unbuilt, so P1 says nothing about them: D1 and D2's refusal, V8's
budget check, D7's unsandboxed-launch check, and D9's byte-order-mark rule.

**The numbers belong to the wording that was measured.** The description text is in
`evidence/p1/p1.2_skill_description.txt`. Its first three sentences are the research's M2 text.
P1.2 added one sentence explaining the directory line and one carrying the standing instruction,
and ended the size-check error with "Do not call Skill for it again in this session." The ADR
fixes none of that wording. If P4 changes it, rows b and d describe a different text.

## 7. Caveats

**(a) Row c did not run at the approved limit.** The approval reads "context_limit 64000 on all
3 models". The runs declared 131,472. The compactors see the declared window less 65,536 and
less the prefix, so 131,472 gives them 64,000. At a literal 64,000 they see 0 and nothing is
ever compacted: the recorder session `dry/limit-64000` has 18 requests and no compaction event,
where `dry/limit-131472` has five on the same script. Row c's numbers are for a 64,000-token
working limit inside a 131,472-token declared window.

**(b) D8's "never cut" claim is contradicted.** Section 6.1.

**(c) The `compaction_ai` summariser returned a one-line non-summary in 4 of 5 folds.** The four
are 98 to 135 chars and none mentions the skill. One, verbatim *(report)*: `Let me check the
current state of the run file and rounds completed to provide an accurate summary.` Only muse's
run got a real summary, 4,491 chars, naming the skill. The summariser is
`openrouter/deepseek/deepseek-v4-flash`, which `skills_proto` copies from `dogfood`. At
`980f1aa3` eight committed profiles name that id (`ailang`, `decision`,
`deepseekv4-flash-compaction-live`, `dogfood`, `mark`, `microrag`, `omnigraph`, `openrouter`);
`default` and `demo_dst` name its `-latest` alias and `local` names it on another route. So row
c's `compaction_ai` columns describe reloading under a summariser that mostly did not summarise.

**(d) The real charge is not the list price, and cannot be attributed exactly.** At list price
P1.3 cost $4.52 of the $7.00 cap. The key's own counter rose $3.77 between the phase-2 baseline
and the end. The key is shared with other sessions. In the first leg the counter rose more than
list ($2.67 against $1.97); in the extension leg less ($1.06 against $2.55).

## 8. Recommendation for G1: revise first, then go

**Revise first, because:**

1. **PLAN-001 §0 rule 1.** A part that finds the ADR wrong stops, and the ADR is revised with
   the operator's ruling. D8 is wrong on a stated claim (§6.1).
2. **P3 and P4 build D8 as written.** P3 writes the size estimate and A6b's pure tests; P4 writes
   the handler's size check. Built from v0.3 they would encode the wrong limit and a test that
   cannot tell.
3. **Q4's reload leg came back "does not happen"** under the structural compactor, and both D8
   and the plan send that to the operator (§6.2).
4. **Two rulings are not yet in the ADR** (§6.3, §6.4). They cost a few lines in the same
   revision.

**Not stop, because** the idea the plan called "the cheapest test" holds where it was measured:
the right skill loaded in the first response in 88% to 100% of trigger sessions on seven models,
no `Skill` call in 135 control sessions, the checkable action done in 53 of 54, and a
full-budget index accepted by all seven families. Q1 is yes. That is a judgement on reported
numbers, not a gate.

**Not a plain go, because** of reasons 1 and 2.

**What can move while D8 is revised.** P2 touches `registry_normalize.ail`, the
registration-boundary script, the ABI comment and 031's ADR. None of the four returning
decisions reaches that surface, and Q5 is ruled. Releasing P2 at G1 is open to the operator. P3's
size estimate and A6b, and P4's handler, wait for D8.

**Before the worktree is removed.** PLAN-001 G1 removes the scratch worktree and merges nothing.
The prototype's source, the profile, 55 MB of session captures and the delegates' reports exist
only there, in `/tmp`, and in gitignored mailboxes. `evidence/p1/README.md` lists what was and
was not copied.

## 9. Not verified, and why

- **OpenAI.** No request was sent, by ruling.
- **The TUI.** Never launched in P1; the worktree has no `src/tui/node_modules`. A10 and Q3 rest
  on the TUI's command line built by hand.
- **A model facing a capped skill result.** Only the recorder session exists; it was outside the
  approved runs.
- **The size check on a real small-window model.** `reka-edge` made no tool call.
- **The quality of work done without the skill's text.** Only `dagr check` was applied.
- **Reload behaviour beyond one run** per compactor and model.
- **The exact spend.** The key is shared.
- **Gates beyond the five P1.2 ran** with the prototype wired.
- **By this note:** the per-session scoring was not re-run; the reports' statement that the
  row c reconstruction matches `provider_call_prepared` on all 340 requests was not re-checked;
  P1.1's own gate output is quoted from its report, and the copied P1.2 gate logs show the same
  state with the probe still wired.

## 10. Found on the way, not about skills

For routing; none is an ADR-001 decision.

- **Layout 2:** with a relative `--workdir` the profile is not found and no extension loads, for
  any profile, with no warning. Native `ReadFile` fails in the same layout. (§4; ruled its own
  issue.)
- **The `compaction_ai` summariser** (§7 c).
- **A declared window of 65,536 tokens plus the pinned prefix, or less, gives the compactors a
  limit of 0.** That was about 67,500 here. Nothing compacts and nothing is capped (§7 a).
- **P0 baseline:** 12 of the 16 gates green and 4 red, with `new_contract_policy` green as a
  17th row. `ext_hook_scope` is red on `test_dummy`'s registration shape.
  `declared_vs_performed`, `driver_plus_no_ops` and `driver_plus_compose` are red because
  `ailang_tools` is in no profile list. `driver_plus_herdr` is green although `DST_KNOWN_RED`
  (`Makefile:697`) still names it.
- **`native_tool_results` reports `exit_code: 0` for a failed `Skill` call**; the payload, the
  `ext_tool_handled` event and the message sent to the model carry 1 *(report)*.
- **Models read and wrote outside the workdir through `BashExec`** in several row b sessions
  *(report)*.

## Related records

- `PLAN-001-implement-adr-001.md` §3 and §7; `ADR-001-skills-system.md` D2, D4, D7, D8, D9, D10,
  A5, A9, A10
- `evidence/p1/` (this note's evidence) and `evidence/baseline/` (P0)
- The operator's rulings of 2026-10-04 are recorded in the run file
  `.dagr/run-037-plan001.json` in the shared checkout
