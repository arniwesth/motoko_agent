# RESEARCH: Proving harness properties in Lean, after Kiro — what transfers to Motoko

> **Revisited, 2026-11-05: PLAN-001's trial gave outcome D.** The results are in
> `FINDINGS-001-trial-lean-against-differential-checks.md`. As PLAN-001 §10 committed before
> the trial, the verdict in §2 becomes: **adopt cross-language differential and property checks
> as standing tests; use Lean only where a person names a property that must hold for every
> length.** §10 item 7 (`make verify_lean`) is dropped. Nothing below this marker is edited:
> the update of 2026-11-03 and the text after it are as they were.

> **Update, 2026-11-03, after this note was written.** §10 items 1 and 2 are done. The record
> is `evidence/diff/README.md`.
>
> - **Lean** (item 1): every theorem in `evidence/PairingModel.lean` checks under 4.28.0, and
>   none uses an axiom beyond `propext` and `Quot.sound`.
> - **Three-way differential**, over all 16,105 histories: the model matches the real
>   `updatePending` and the real `fold_journal` with 0 mismatches, and the two real functions
>   agree on every history the fold accepts within (H1) and (H2). Mutants planted in either
>   real function are caught.
> - **Reproduction** (item 2): the two admitted shapes (§6.1) and the trailing empty id (§6.2)
>   reproduce on the real fold. None is shown reachable (§6.3), so each is still an
>   observation, and "no finding" below still stands. Item 2 is a program beside the evidence,
>   not an in-module test, so that no test pins the admitted shapes as correct before item 3
>   decides whether they are.
>
> - **§11**, an addendum of the same date, on how the method combines with DST. By reading;
>   nothing run.
>
> The text below is as first written, through §10; §11 is the addendum.

Date: 2026-11-03.
Status: Research, with one worked example in `evidence/`. Proposes an order of work and names
what it would need. **No finding**: the worked example's Lean half could not run in the session
that wrote it (§6.4), so every statement about the model is unchecked by the kernel, and no
counterexample has been run against the real code.
Grounded at: Motoko `origin/main` `43530c0a`; AILANG at the pin, `v0.54.14` (`e1ef33fa`).
External source:
- Kharkov, Erata, Omidvar-Tehrani and Mukherjee, *Kiro proves properties of its own harness in
  Lean*, Kiro blog, 2026-11-02, [post][kiro]. "The post" below. Read through a fetch tool. Its
  code listings did not render in the fetched text ("Loading code example..."), so the post's
  Lean models and theorems themselves were **not** read; what follows rests on its prose,
  Figure 1's caption and Table 1.

Companion to: `029_cslib_proof_tier/` (§8, the transcription gap; §9, MOT-137 and MOT-138),
`027_z3_contracts/ADR-001-contract-classification-register.md`, `013_core_architecture_for_dst/`
`ADR-003-session-journal-and-resume.md` (D1, D4), `039_systematic_mutation_testing/`.

_Written because 029 §8 left one obligation open and said how it would be met. The Lean tier
can only ever judge a hand-transcribed model of an AILANG function, "the transcription is
unverified", and the gap is "discharged by inspection rather than by proof". The post is a
worked answer to a narrower question: how to discharge it mechanically, if not completely.
Compile the model, run it beside the real code on generated inputs, and fix the model until
the two agree. That is a method Motoko can run with parts it already has, and it reaches the
code `ailang verify` cannot._

---

## 1. What the post is

A results post from the team that works on Kiro's context management. Kiro's own agent (the
Kiro CLI on Claude Opus 5.5) scanned three Kiro codebases (the TypeScript agent server, the
Rust and TypeScript CLI, and the Python Kiro Crew) for small functions with a precise intent,
modelled 26 of them in Lean 4, checked each model against the real code, and then proved the
intended property or found the input that breaks it.

Table 1's totals: 96 properties; **70 proved**, 2 given bounded checks, **18 falsified in the
model and reproduced on the real code**, 6 partial or observations; 235 Lean theorems
including lemmas; 97,938 differential test cases with no mismatch in the final runs. Lean
4.28.0, core only, no Mathlib and no Lake.

The method (Figure 1) has eight steps:

1. **Find targets.** The agent ranks functions whose doc comments, invariants and call sites
   state something a theorem can say: a size cap, an approval rule, a reload that must match
   the live session, a state machine that must not go backwards.
2. **Model.** A Lean function that keeps the source's structure, with a header naming the
   source file and lines.
3. **Differential test.** The model is compiled and run beside the real code on random
   inputs aimed at boundaries (multi-byte text, lengths either side of a cap, shuffled event
   orders). A mismatch sends the model back to step 2. As a check on the test itself, they
   changed one behaviour on the real-code side of two trackers and got hundreds of
   mismatches.
4. **Prove.** A stuck proof is either a false theorem, a wrong model or an unfinished proof.
   A false one becomes a theorem `bug_...` that states the counterexample, so Lean checks it.
5. **Reproduce** the counterexample with a script against the real, unmodified code. Only
   then is it a finding.
6. and 7. **Reachability.** Can a real caller produce that input, and what would a user see?
8. **Fix.** State the fix in Lean and prove it closes the gap while keeping the intended
   behaviour.

Three things are trusted, and the post keeps them apart: Lean's kernel checks each proof, the
real code checks each finding, and people review each theorem statement, because the kernel
will accept a proof of a statement that misses the code's intent. Against the agent's own
failure modes they listed every theorem's axioms, and for every theorem they quote they gave a
concrete input satisfying all its hypotheses, so none is vacuous.

Where the findings were: fifteen of eighteen in context management, permissions and their
state machines, and most **at a boundary between two representations** (UTF-16 against UTF-8,
a file path against a glob) or in a rare order of concurrent events. Seven of the agent
server's nine were in the functions that cut text to fit a cap, several of them a cap counted
in one unit and enforced in another. None was a security finding.

Its limits section is the honest part, and it is the same list 029 §8 arrives at from the other
direction: a proof is about the model; the differential test is evidence and not proof that
the model matches; a theorem can leave out part of the intent; unbounded integers miss
overflow; `native_decide` widens the trusted base; results are tied to the analysed commit.

## 2. Verdict

**Adopt the method; there is no tooling to adopt.** Motoko is a better host for it than Kiro's
codebases were, for three reasons, and one reason it is no easier.

- **The core is pure, so a model can follow it line by line.** AILANG's `pure func`s over
  records, lists and sums transcribe into Lean almost mechanically; Kiro had to model Python
  over SQLite and TypeScript over Node.
- **Determinism makes the differential test clean.** A pure AILANG function on a fixed input
  has one answer, and the DST corpus and recorded journals are ready-made input sets.
- **It fills the hole Z3 leaves (§3).** The functions where `ailang verify` reports `blocked`
  or cannot reach at all, list folds and event sequences, are exactly where Kiro's proofs and
  findings cluster.
- **No easier:** AILANG has no Lean semantics (029 §8 stands), and there is no AILANG-to-Lean
  translator, so every model is hand-written, as Kiro's were. The differential test narrows
  the transcription gap; nothing closes it.

## 3. What Z3 covers, and what it leaves

Measured at the pin, `v0.54.14`:

- **Recursion** is encoded only by bounded unrolling, and only when asked:
  `RecursiveDepth`, "1-10", "0 means no unrolling (default behavior)"
  (`internal/smt/codegen.go:100-103`).
- **Higher-order calls** are specialised and unrolled to a default depth of 3
  (`codegen.go:366`).
- **Unencodable builtins** block the contract outright: `compress_output` is `blocked` on
  `std/string.split`, as 029 §4 recorded live.

So a contract over a fold can at best be checked for histories of up to ten elements, and
`verify_core` correctly reports the rest as `blocked`, not as proved. The core's own idiom is
the fold: `fold_journal`, `pair_step`, `chain_digests_over`, `strip_dangling` and `path_up` are
all list recursion or `List.foldl`. In Lean these are proofs by induction, for every length.

The division of labour that follows: **Z3 keeps the scalar, non-recursive contracts**, where
it is already fast (about 10 ms each) and its classification register is computed. **Lean
takes what Z3 reports as `blocked` or cannot state**: properties over sequences, folds, event
orders, and statements about two implementations at once.

## 4. Kiro's method, mapped onto Motoko

| Kiro's step | Motoko's piece | Exists? |
|---|---|---|
| 1. Targets | Contracts the register marks `blocked` or `unclassified`; the cross-language twins (§5.A); ADR-003 D4's fold rules | Lists exist; ranking does not |
| 2. Model | Hand-written Lean, `file:line` header, same structure. `evidence/PairingModel.lean` is the first | One model |
| 3. Differential test | Compiled Lean model beside `ailang run` and `bun`, over bounded enumerations, DST seeds and recorded journals | bun half only (§6.4) |
| 3. Its negative control | 039's mutation practice: plant one mutant on the real side and require mismatches | Practice exists; not wired to this |
| 4. Prove, audit axioms | Lean 4.28.0 core; the scratchpad's axiom audit (`classifyTheoremAxioms`, 029 §3) already refuses `sorry`, `native_decide` and fresh axioms | Audit exists; toolchain dark (MOT-137) |
| 4. Vacuity | Kiro: a satisfying witness per theorem. Motoko can go one further, after 027 ADR-001: also require the theorem to **fail on a mutant model**, so a statement that holds of everything is caught by computation, not by review | Neither yet |
| 5. Reproduce | An AILANG test in the module, built through the public API. `journal.ail`'s `test_refusal_pairing_is_the_folds_own_rule` (`:2963`) is already the shape | Shape exists |
| 6-7. Reachability | Callers, the driver, the host | By reading |
| 8. Prove the fix | Same model, patched | — |
| Re-run on change | Pin each model by the source body's hash, as `contracts.register` pins contract and body text, so an edit invalidates a proof instead of inheriting it | Mechanism exists for Z3 |

**Who reviews the theorem statement.** Kiro's answer is its team. Motoko's Phoenix rule puts
people on ideas, decisions and evidence rather than code, and a theorem statement is a
decision about intent, not code. So the statement is the one artefact in this loop that a
person should read; the model, the proof and the harness are agent work checked by kernel,
differential test and register. §6.2 is an example of why the statement and its stated
hypotheses need that reading.

## 5. Where the targets are

**A. The cross-language twins.** Kiro's "cross-repo contracts" are, in Motoko, rules
implemented twice across the AILANG/TypeScript boundary, the shape the codebase calls MOT-118
and has "already paid for twice" (`exit-actions.ts:148`). The declared ones:

| Rule | TypeScript | AILANG |
|---|---|---|
| Pending tool calls at exit | `session-journal.ts:865` `updatePending` | `journal.ail:1634` `pair_step`, via `finish_fold` |
| The journal writer | `session-journal.ts` (`:21`, "THE TWIN") | `journal.ail:2137` `journal_lines_of_records` |
| Running inside herdr | `herdr-agent-state.ts:145` | `motoko-ext-herdr/types.ail:1425` `herdr_env_ready` |
| herdr failure vocabulary | `wake-waiter.ts:125` | `types.ail:1160` `failure_code`, `:1198` `means_agent_gone` |

Each comment says the two must move together; nothing checks it. A Lean model of both sides
plus one theorem, "equal on every input satisfying H", is the check, and §6 does it for the
first row.

**B. The journal fold (ADR-003 D4).** The persistence property Kiro states as "reloading
gives the model exactly the messages it saw live" is, here, folding what the twin wrote:
`fold_journal(journal_lines_of_records(h, rs), leaf)` returns the history `rs` recorded.
Smaller pieces of it, each a fold:

- **Chain prefix:** `chain_digests_over(b, xs ++ ys)` begins with `chain_digests_over(b, xs)`,
  with `sha256Hex` uninterpreted. The analogue of Kiro's prompt-cache prefix theorem.
- **`path_up`** (`journal.ail:1403`) terminates and returns a repeat-free root-to-leaf path even
  when `parent_id`s form a cycle. The `seen` list is the termination argument; Lean will want
  it written down.
- **Pairing,** §6.

**C. Unit boundaries,** Kiro's largest class. §7 records what reading the source turned up.

**D. The step machine.** Single-step properties of `step_machine.decide` are cheap, and most
would classify as spec-equals-body in 027's sense ("Park only when waits are open" is the
guard on `:124`). The valuable statement is about runs, such as termination within the step
budget, and needs the driver loop in `session.ail` modelled. Later, not first.

**E. Capabilities.** Kiro's sub-agent theorem says a combined permission is never wider than
the parent's. Motoko's analogue would be per-hook capability narrowing, and that does not
exist yet: `.agent/issues/ailang-per-hook-capability-narrowing.md` records `scope=` as parsing
with no semantics, pending AILANG's effect scope parameters. That was measured at AILANG v0.33.0
and not re-measured at the pin for this note. There is nothing to model until narrowing lands;
when it does, monotonicity is the theorem to state first.

## 6. Worked example: the pairing rule and its TypeScript twin

`evidence/PairingModel.lean` (about 300 lines, Lean 4 core) models two functions:

- `pair_step` and its fold in `finish_fold` (`journal.ail:1634-1651`, `:1715-1724`), the fold's
  pairing check, D4 rules 3 and 4; and
- `updatePending` (`session-journal.ts:865-875`), the host's "three-line TypeScript twin" of the
  trailing-pair rule, which becomes `exit.pending_tool_calls`.

A message is modelled as its role, its call ids and its `tool_call_id`, because neither function
reads anything else.

### 6.1 What the model states

| Theorem | Statement |
|---|---|
| `admits_duplicate_result` | The pairing check accepts `[asst(a), tool(a), tool(a)]` |
| `admits_result_after_user` | It accepts `[asst(a), tool(a), user, tool(a)]` |
| `refuses_unanswered_call_before_user`, `refuses_result_for_unmade_call` | Controls: the shapes D4 names are refused |
| `host_twin_agrees` | For every history the check accepts, under (H1) no call id is empty and (H2) no tool message carries calls, the host's pending set equals the fold's open set |
| `trailing_call_is_dangling` | A satisfying witness for `host_twin_agrees`'s hypotheses |
| `twin_disagrees_without_h2` | Without (H2) the two sides disagree on an accepted history |
| `h1_not_free_in_trailing_batch` | Without (H1), in the trailing batch, they disagree too |

The two admitted shapes come from one detail: `pair_step` tests a result against `cur_ids`, not
`open_ids`, and `cur_ids` is replaced only by the next assistant that makes calls. D4 states the
rule as every tool result answering "a call in the assistant message before it", and read
literally both shapes satisfy it. So they are a question about D4's intent, which is a person's
decision (§10 item 3), not a bug in the code.

### 6.2 The fold refuses less than the comment claimed

The model's first draft justified (H1) by saying the full fold refuses any history with an
empty call id, so the hypothesis "costs nothing". Reading `finish_fold` against that claim shows
it is wrong in one position. An empty-id call in the **trailing** batch stays in `open_ids`, so
it is in `dangling`; `strip_dangling` then removes it from the assistant (`keep_calls` drops the
dangling ids, `:1664-1671`) **before** `history_valid_transcript` reads the message (`:1730`).
So `[asst([a, ""]), tool(a)]` folds with `dangling = [""]`, while the host, which filters empty
ids, records no pending call.

The theorem `host_twin_agrees` is untouched, since it assumes (H1). What changed is the argument
for why (H1) is cheap, and that argument lived in a comment, which is where nobody looks. This
is the post's point about reviewing statements, in miniature: the error was not in a proof or
in the model, but in the stated reason a hypothesis was safe.

### 6.3 Reachability, if the theorems check

None of the three shapes is shown reachable. The two admitted shapes need a journal holding a
second result for an answered call; whether any writer produces one is step 7's question, and
D4 itself names the likeliest route: its rule 4 widens "when branching lands", because a branch
point can strand results. The (H1) and (H2) shapes need a provider adapter that emits an empty
call id or a tool message with calls. Until one of these is shown, each would be an
observation in Kiro's terms, not a finding.

### 6.4 What ran, and what did not

- **The bun half ran.** `evidence/diff/enumerate.ts` drives the real `updatePending` over every
  history of length 0 to 4 in an eleven-message alphabet: 16,105 histories, output sha256
  `6de0b5877d1ace2f…`. The alphabet includes one message violating (H1) and one violating (H2).
- **The Lean half did not.** `elan` could not install 4.28.0: `release.lean-lang.org` answered
  403 from this session's sandbox. So no theorem in §6.1 has been checked by the kernel, the
  axiom report has not been read, and the comparison has not happened. The model's header
  says so.
- **The AILANG half does not exist yet,** and AILANG `v0.54.14` could not be built here
  (`proxy.golang.org` was unreachable). The reproduction of the two admitted shapes on the real
  fold is a two-line variant of `test_refusal_pairing_is_the_folds_own_rule`.

`evidence/diff/run_diff.sh --ts-only` exits **2**, not 0: one half running is not a pass. That
follows 029 §9 item 1 (MOT-137): a Lean tier that is unavailable has to be a counted state, and
this session is a fourth instance of the tier being dark.

## 7. Unit boundaries, found by reading (nothing here has been run)

**Where solver and runtime agree.** `_str_len` is `utf8.RuneCountInString`
(`internal/eval/builtins_string.go:77-86`) and maps to Z3's `str.len`, so the verified contracts
that bound `length(result)` count what the runtime counts, on valid UTF-8.

**Where they need not.** Z3's strings are sequences of characters; a Go string is bytes, and may
not be valid UTF-8, in which case `RuneCountInString` counts each invalid byte as one rune. The
contracts quantify over a smaller domain than the runtime's. That matters only because the
runtime does make such strings:

- `std/bytes.toString` is `string(b)`, with no repair (`internal/builtins/bytes.go:130-137`), while
  its own documentation says invalid sequences become U+FFFD (`:102`). A model written from the
  documentation would be wrong, which is the post's case for the differential test, met here
  before any Lean was written. At the pin there is one implementation, so this is a
  documentation error, not a split between execution modes.
- The search, bash and test-runner tools decode process output that way (`tool_runtime.ail:639`,
  `:985`, `:999`), so binary output, or text cut mid-character by the process, enters as invalid
  UTF-8.
- `truncate_utf8_by_bytes` in compose (`packages/motoko-ext-compose/store.ail:19-29`) slices at a
  byte offset and so can split a character, despite its name.

**Where the repair does happen, and the question it leaves.** AILANG's JSON encoder ranges over
runes, so it writes U+FFFD for each invalid byte (`internal/eval/builtins_json.go:151-189`).
Core tool results are encoded to JSON text before they become message content
(`tool_dispatch_adapter.ail:284-293`), so the history holds valid UTF-8 on that path. For an
extension result whose `stdout` reaches message content without passing through `encode`, the
in-memory string and its journaled form would differ, and `canonical_message_frame` hashes the
raw content (`phase_vocab.ail:271-273`, `:357-359`). A digest the child computed would then not
match the one the fold recomputes on resume. **Not traced to the end**: whether compose's
envelope reaches content raw was not followed through the extension boundary. Target B's
round-trip theorem, with a differential test over non-UTF-8 tool output, is what would settle
it.

**Units named one way and counted another.** `stdout_bytes` and `stdout_total_bytes` are rune
counts in core (`tool_runtime.ail:275-278`) and in compose (`compose.ail:167-168`), while compose
enforces its own cap, `max_stdout_bytes`, in bytes (`store.ail:36`). Within one package the cap
and the metadata reporting against it use different units; CJK text is three bytes per rune.
Separately, the elided output is the clipped prefix plus a notice, so it exceeds
`max_stdout_bytes` by the notice's length. The post's equivalent theorem includes the notice in
the cap; whether Motoko means to is a question about intent.

## 8. What Lean adds to what Motoko already runs

DST and mutation testing sample executions; Z3 proves scalar contracts for every input but
stops at the fold; Lean proves statements over every sequence, for a model. None replaces
another. What the post adds is the joint: the differential test is what makes a Lean verdict
about a model worth citing about the code, and Motoko already has the input generators for it
(the DST corpus, recorded journals) and the negative-control habit (039).

It also bears on the project's stated destination. A self-rewrite that keeps every pinned
theorem proved and every differential test clean is evidence that the change kept those
properties, without a person reading the code. That is only as good as the theorem statements,
which is why §4 puts the person there.

## 9. Limits, and what does not transfer

- **The transcription gap stays open.** The differential test is evidence on the inputs tried,
  not proof. 029 §8's requirement stands: wherever a Lean verdict is cited, the gap is named
  with it.
- **Kiro's scale is not the point.** 26 functions and a team reviewing statements. The useful
  unit here is one model per rule that a person already cares about, starting with the twins.
- **Hashes and the outside world.** `sha256Hex` is uninterpreted in any model; properties that
  depend on its value are out of scope. Ports must be modelled as pure state transitions, which
  the DST world already is.
- **`native_decide`** stays excluded from anything counted as proved, as the scratchpad's audit
  already enforces. Kiro used it only for bounded checks, counterexamples and one control case.
- **A mechanical AILANG-to-Lean translator** for the pure subset is conceivable and would remove
  step 2's hand-writing. It is upstream work and is not proposed here.

## 10. Ranked follow-ups

1. **Run the worked example where Lean installs.** `evidence/diff/run_diff.sh`, and record the
   result in `evidence/diff/README.md`'s table with its mismatch count and axiom report. If no
   machine can install 4.28.0, that is MOT-137's state and should be reported as such.
2. **Add the AILANG half.** An in-module test that folds the two admitted shapes and the (H1)
   shape through `journal_lines_of_records` and `fold_journal`, as
   `test_refusal_pairing_is_the_folds_own_rule` does. This is step 5 for §6.
3. **Decide D4's intent** for duplicate and late results. A person's decision. If they are meant
   to be refused, the fix is to test `open_ids` and clear `cur_ids` when a batch closes, and
   the model can prove that fix before the code changes.
4. **Model the other twins** in §5.A. They are small, pure and string-valued, and each has a
   comment saying they must agree.
5. **The persistence round trip** (§5.B), with a differential test that includes non-UTF-8 tool
   output, to settle §7's open question.
6. **Report `_bytes_to_string`'s documentation upstream** through the `ailang-feedback` skill.
   Not done here: filing is outward-facing.
7. **Only then, a gate.** `make verify_lean`, each model pinned by its source body's hash, with
   the three-valued verdict 029 §9 item 3 asks for (`verified`, `refused`, `unavailable`).

## 11. Addendum, 2026-11-03: the method combined with DST

Added after §1-§10, after the dry run (PLAN-001 W0.9), at the operator's request. **By reading
only: nothing in this section was run.** Anchors are at `43530c0a` for `src/core` and at this
branch's `4ecaa292` for the project's files. It edits no hashed file, and the trial tree is
built from PLAN-001's own commit (PLAN §7), so no arm session sees it.

### 11.1 The question, and the answer in one paragraph

Whether the method and Motoko's DST (007 ADR-001: single-actor, logical-fault DST of the real
session driver against a seeded world) combine. They do, at specific joints. DST supplies the
method's steps 3, 5, 6 and 7: inputs at the driver's own lengths and shapes, a reproduction
artefact, and reachability. The method supplies what DST's invariant families only sample: a
statement for every length, about a model. Neither replaces the other, and the trial needs no
amendment for it (§11.5).

### 11.2 Where DST already states §6's rule

| Family | What it reads | What it checks |
|---|---|---|
| `ToolPairing` (`dst_invariants.ail:1767`) | the world's interaction log, `x.world.log` | a dispatch with no answer (`OutcomeMissing`), an answer to an id nobody asked for, a dispatch after a denial, effect disclosure, and a re-dispatch (`redispatched`, `:1749`, marked `contracts: BLOCKED — RECURSIVE`) |
| `JournalFold` (`:2410`) | the trace's records | builds journal lines with `journal_lines_of_records` (`journal.ail:2137`), folds them with the real `fold_journal`, and compares with the driver's `final` field by field, on every traced fixture that calls `evaluate` (`:2429`) |

ADR-003 D4 says (`:421`): "In the harness the `ToolPairing` family is the same rule over the
trace." Read against the code, the two are the same rule over two representations, the log of
dispatches and the journal of messages, as §6's two functions are the same rule in two
languages. Two consequences:

- PLAN-001's T3 (P3.2, the round trip) is the for-every-length form of what `JournalFold`
  samples on every traced fixture. The DST report §5.1 names the sample's limit itself:
  registration in `evaluate` does not show that every scenario invokes it.
- The `ToolPairing`/`pair_step` pair is a model the method has not written (§11.3 item 3).

### 11.3 The joints

| Kiro's step | The worked example has | DST adds |
|---|---|---|
| 3. Differential test | eleven messages, length ≤ 4; the model is tied to the code only up to length 4 (`evidence/diff/README.md`) | every execution's journal lines, at the driver's lengths and shapes |
| 5. Reproduce | a script per counterexample | a constructed execution program in the PR corpus |
| 6-7. Reachability | by reading; none shown | the corpus as a sampler of what the driver writes; a catalogued fault class for what it does not |
| 1. Targets | the twins and the fold | the harness's own pure leaves |

1. **DST executions as the differential test's inputs.** Every DST execution already yields its
   journal lines on the `JournalFold` path. An exporter that projects them to the model's `Msg`
   (role, call ids, `tool_call_id`) and feeds the existing Lean and AILANG halves extends the tie
   past length 4 to what the driver writes: catalogued faults, denials, checkpoints with
   `history_replaced`, resumes. **The dry run is the evidence that these shapes matter.** Arm A's
   three findings (K8-K10, `trial/dryrun/README.md`; recorded, not counted) all sit in the
   replacement path, `replaces_previous` and `history_replaced`, which the alphabet does not
   reach and which arm B's model, like `PairingModel.lean`, leaves out. A compaction or a
   resume in a corpus run is what writes those shapes; whether the PR corpus's runs reach one
   is the first thing the exporter would report.
   **Limit:** the generator cannot violate (H1) or (H2). Its ids are `gcall_<n>_<v>`
   (`dst_generator.ail:711`), and the driver builds every tool message with `tool_calls: []`
   (`tool_phase.ail:122`, `:228`). `invariants_dst.ail:52` already records that the generator
   "provably cannot reach every shape the invariant set protects". The enumeration stays for
   the boundary cases; the two input sets complement each other.
2. **DST as the reachability instrument** (steps 6 and 7, open in §6.3 and in the dry run's
   reports). DST drives the real driver, so the corpus answers, bounded by the generator's reach,
   whether any run writes a duplicate result, a result after a user message, an empty call id, a
   tool message with calls, or K8-K10's shapes. A negative answer is bounded evidence of
   unreachability, not a proof; a positive one is a finding with its program as the
   reproduction. The stronger form is a catalogued fault class (ADR-001 D3) for a malformed
   provider message, with a `ReachStatus` (`dst_run_report.ail:152`), which turns (H2) from an
   assumption about the driver into a measured class.
3. **One model across the two representations.** A Lean model of `tool_pairing_findings` over
   the log and of `pair_step` over the journal, with the theorem that a clean log implies an
   accepted journal, under stated hypotheses about how a dispatch becomes a message. §1 records
   that most of Kiro's findings were "at a boundary between two representations"; this is that
   class, and every DST execution supplies both sides as inputs for its differential test.
4. **Counterexamples reproduced as corpus programs.** A `bug_` theorem's witness becomes a
   constructed execution program in the PR corpus (ADR-001 D11; the README: "a bank of seeds
   and one constructed scenario"), which is the project's own reproduction artefact and one
   command that fails on the defect. Promotion of a failure into the corpus is "the stated
   policy and is not built yet" (README), so this joint is partly a build.
5. **The harness itself, later.** Kiro's title is "properties of its own harness". Motoko's DST
   substrate has pure leaves with a stated intent that Z3 marks `blocked`: `world_ordinal.advance`
   (`:40`; strict +1, request order), `dst_replay.reconstitution_balance` (`:581`), the seed
   aliasing `dst_corpus.ail:33` measured at 29 of 29 and provable, `check_seed_sensitivity`
   (`dst_generator.ail:251`), and `redispatched`. The driver loop stays out of reach: 013
   RESEARCH §1 measures the DST surface at 20,037 lines with world state threaded by hand. 013
   §2.D's `step : (StepState, WorldResponse) -> (StepState, [Command], [LedgerEvent])` is the
   one change that would make the method and DST check a single object.

### 11.4 What does not combine

- **The transcription gap** (§9) is the same whatever the input source.
- **The projection** from journal lines to `Msg` must be one AILANG function, used by both the
  enumeration and the exporter, or it is a third representation with its own boundary.
- **The name.** 007 ADR-001's naming rule holds: an enumerated alphabet through two real
  functions is exhaustive testing, and the combination is "DST executions as the differential
  test's inputs and as the reproduction vehicle", not "Lean-verified DST".
- **Cost.** The AILANG half took 1 min 45 s for 16,105 small folds (`evidence/diff/README.md`).
  Corpus-sized sets, hundreds of executions of real length, are the scale; not tens of thousands.
- **Reach.** DST's shapes are the generator's shapes (§11.3 item 1's limit), and 011's finding
  stands that the oracle set, not the substrate, is where DST's gaps have been.

### 11.5 The trial

PLAN-001 is approved (W0.5), amended (A1-A3) and not started (`trial/sequence.log`). Nothing
here amends it. Arm A's brief already allows recorded inputs, and arm B may execute the real
code for steps 3 and 5, so neither arm needs a change to use DST executions, and neither is
told to. The combination is compatible with each outcome in §10: D's consequence is "use Lean
only where a person names a property that must hold for every length", which is §11.3 items 3
and 5; L scopes `verify_lean` to what the proofs found, which is where DST inputs would widen
the differential test. Anything in this section that runs goes in a NOTE-002 beside NOTE-001,
after W5 or outside the trial's files.

### 11.6 First step

The exporter of §11.3 item 1, over the PR corpus: each execution's journal lines through the
three halves of `run_diff.sh`, with one report: the number of histories, the longest, the
mismatches per half, and whether any history carries §6.1's shapes, violates (H1) or (H2), or
has K8-K10's shapes. It touches no hashed file. Then §11.3 item 3's model, after §10 item 4's
twins.

[kiro]: https://kiro.dev/blog/harness-properties-in-lean/
