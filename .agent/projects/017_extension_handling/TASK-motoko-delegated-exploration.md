# TASK: Close project 017 (extension ABI evolution) by delegating the hard parts

You are the ORCHESTRATOR for this task. Your job is to produce one decision document
that answers the four open questions in `.agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md` §5.
You will NOT do the deep analysis yourself. You will hand each hard part to a stronger
coding agent with the `Delegate` tool, collect their answers with `DelegateCheck`,
and then synthesise.

Repository root: `/workspaces/motoko_agent` (this is your working directory).

---

## Orchestration rules — read these before your first tool call

1. **A delegate shares NOTHING with you.** It cannot see this task, your history, or any
   file you have read. Every `Delegate` prompt must stand completely alone: it must state
   the absolute repo path, the exact files to read, the question, and the answer format.
   The four prompts below are already written that way. Send them as-is.
2. **Fan out FIRST, collect SECOND.** Issue all four `Delegate` calls before you call
   `DelegateCheck` even once. A delegate takes 25–90 seconds; starting them in parallel is
   the entire point. Do not start one, wait for it, then start the next.
3. **`Delegate` returns immediately and does not wait.** The answer is NOT in the
   `Delegate` result. Only `DelegateCheck` returns work.
4. **`DelegateCheck` polling discipline.** Each call already waits ~20 s server-side.
   If it says "still working" or "has not written its answer yet", that is NORMAL —
   call it again with the same name. Keep cycling through the four handles until each has
   returned an answer or hard-failed. Do not conclude a delegate is stuck, do not give up,
   and do not start doing its work yourself.
5. **Known codex failure mode:** an unattended `codex` delegate sometimes replies with the
   answer file path without actually writing the file. If `DelegateCheck` reports
   "finished but never wrote its answer file", re-issue that same delegation once with
   `kind: "claude"` instead. Do this at most once per delegate.
6. **Budget.** Exactly four delegations, plus at most two retries under rule 5. Do not
   invent extra delegates. Do not delegate the synthesis — that part is yours.
7. **Do the reading you need and no more.** You have 100 steps and four delegates to
   babysit. Do not read the ABI source yourself; the delegates are doing that.

---

## Phase 0 — orient (max 2 tool calls)

Read `.agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md`.
That is the input document. Its §2 states the problem, §3 gives three options,
§4 gives the current recommendation, and §5 lists the four open questions that this
task exists to close. You do not need to read anything else before delegating.

---

## Phase 1 — fan out four delegations, back to back

Call `Delegate` four times in a row. Use the exact `prompt` text and the exact `kind`
given below for each one. Record the handle name each call returns — you need it for
`DelegateCheck`.

### Delegation 1 — kind: `claude`

prompt:

```
You are working in the repository at /workspaces/motoko_agent. Answer one empirical question
by MEASURING it against the AILANG compiler, not by reasoning about it.

BACKGROUND. The extensions ABI is the pure package sunholo/motoko_ext_abi, defined in
packages/motoko-ext-abi/types.ail. It exports a record type `ExtensionHooks` with eight hook
slots. Each slot's type carries a CLOSED effect row (e.g. `on_pre_step` is declared
`! {AI, IO, Trace}`), and the ABI's design history treats those rows as compiler-enforced:
an extension that performs an effect its slot does not declare should fail to type-check.
There is a known hole, recorded in-tree as WI-B4: declared effect rows do NOT bound lambdas
in RECORD-FIELD position. The proposed 6.0 re-shape of this ABI (see
.agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md §3.3) moves those
same lambdas from record fields into SUM-CONSTRUCTOR-ARGUMENT position, i.e.
`type Capability = Compactor((ExtCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace}) | ...`.

THE QUESTION: does the AILANG effect checker enforce a closed effect row on a lambda passed as
a SUM CONSTRUCTOR ARGUMENT, or does the WI-B4 record-field hole recur there?

METHOD (required — the answer must be measured):
1. Locate the WI-B4 note in packages/motoko-ext-abi/types.ail and any related test or check
   target, so you reproduce the original measurement method rather than inventing one.
2. Write a minimal AILANG file under /workspaces/motoko_agent/tmp/017-effectrow/ that declares
   a sum type whose variant payload is a function type with a narrow closed effect row, and
   construct it with a lambda that performs an effect NOT in that row.
3. Type-check it with the repo's AILANG (`ailang check <file>`; the local binary is
   ailang/bin/ailang, and `make check_core` shows how the repo invokes it).
4. Run the mirror-image control: the same violation in record-field position, to confirm you
   have reproduced the known WI-B4 hole and that your method can detect the difference.
5. Report the ACTUAL compiler output for each case, verbatim.

Do not modify any file outside /workspaces/motoko_agent/tmp/017-effectrow/.

ANSWER FORMAT — Markdown, under 400 lines:
- VERDICT: one sentence — enforced, not enforced, or partially enforced.
- The exact commands you ran and their verbatim output.
- The minimal reproduction files, inline.
- CONSEQUENCE FOR THE 6.0 RE-SHAPE: if the rows are not enforced in constructor-argument
  position, say plainly what guarantee the capability-registration design would be claiming
  without holding, and what out-of-band check would have to cover it.
- CONFIDENCE, and anything you could not measure.
```

### Delegation 2 — kind: `codex`

prompt:

```
You are working in the repository at /workspaces/motoko_agent. Implement and verify a small,
non-breaking addition to an AILANG package, then report on it.

BACKGROUND. packages/motoko-ext-abi/types.ail defines the record type `ExtensionHooks` with an
`id` field, a `provided_tools` field, and eight hook slots. Today all 16 motoko-ext-* packages
construct that record label-by-label in their `register_with_config`, so ADDING a slot means
editing 16 packages plus an ABI major version bump. The accepted fix (see
.agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md §3.2) is for the ABI
itself to export `default_hooks(id: string) -> ExtensionHooks` returning all-no-op slots, so an
extension can construct by RECORD UPDATE:
  { default_hooks("agentcli") | provided_tools: [...], on_tool_handle: handle }
Record-update syntax is already used in-tree — see src/core/ext/registry_generated.ail.

YOUR TASK:
1. Read packages/motoko-ext-abi/types.ail carefully, including its comments — they carry the
   ABI's design history and its versioning rule. NOTE: a stale AILANG compile cache under
   .ailang/cache/ mentions a `default_hooks` export from an earlier prototype. It does not
   exist in any .ail source. Ignore the cache; implement it fresh.
2. Implement `default_hooks` in that file, with a correct no-op for every slot. A no-op must
   respect each slot's declared effect row and its host dispatch semantics (concatenation,
   patch fold, chaining, first-match, opinion merge) so that folding it changes nothing.
   Read src/core/ext/runtime.ail to see how the host dispatches each slot before you decide
   what "no-op" means for it — a wrong no-op is worse than no default at all.
3. Migrate exactly ONE extension package to construct via record update, as a demonstration.
   Pick the smallest one that has a real binding.
4. VERIFY: run `make check_core`, and type-check every file you touched. Do not report success
   on code that does not compile. If it does not compile, fix it.
5. Determine EMPIRICALLY whether closed-row enforcement survives an overridden field: take the
   package you migrated, make its overriding lambda perform an effect its slot does not
   declare, and check whether the compiler rejects it. Then undo that mutation.
6. Leave the working tree in a compiling state. Do not touch anything unrelated to this task.

ANSWER FORMAT — Markdown, under 400 lines:
- WHAT YOU CHANGED: the file list, and the full `default_hooks` implementation inline.
- VERIFICATION: the exact commands run and their verbatim output, including `make check_core`.
- THE MUTATION TEST from step 5: what you mutated, and what the compiler said.
- IS THIS TRULY NON-BREAKING? State whether existing full-literal constructions still compile
  and whether this can ship as a minor version, with your evidence.
- THE COST NAMED IN §3.2: with defaults available, "not implemented" and "implemented as a
  no-op" look identical at the type level. Say what you observed that bears on whether the
  conformance tooling can still tell them apart.
```

### Delegation 3 — kind: `claude`

prompt:

```
You are working in the repository at /workspaces/motoko_agent. This is a design-analysis task
about tooling, not an implementation task. Read the code before you answer.

BACKGROUND. The extensions ABI (packages/motoko-ext-abi/types.ail) is proposed to change in its
6.0 version from a wide record of eight hook slots to a LIST OF CAPABILITIES — extensions would
return `[Capability]`, where `Capability` is an ABI-owned sum type with one variant per hook
kind. The full proposal is .agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md
§3.3; read it first. The stated precondition for that change is that the DERIVATION TOOLING must
be re-designed first, because that tooling — not the type system — is where the ABI's guarantees
are actually measured. The relevant tooling is:
  - tools/ext_call_inventory/  (including its derive.py and the SUCCESSOR_FIELD classifier)
  - tools/ext_ambient_inventory/
  - the `declared_vs_performed` make target
  - the per-(extension, slot) coverage/barrier derivation
All of it currently reads RECORD FIELDS to identify which extension binds which slot.

ANSWER THESE THREE QUESTIONS, grounded in what the tooling actually does today:
1. How does each of those tools identify a binding today — concretely, which field names or
   AST shapes does it key on? Cite file and line.
2. How does each one restate over a capability LIST? For each tool, say whether it is a
   mechanical re-target, a real redesign, or something that cannot be recovered at all.
3. Does "slot" survive as the unit of coverage, or must the unit become
   (extension, capability-instance)? A capability list allows an extension to return two
   Compactors, which the record model made impossible — say what that does to the coverage
   criteria and to the barrier counts.

Then answer the residual question: does `default_hooks` (the non-breaking interim fix, §3.2)
need a per-slot "was overridden" witness so the tooling can distinguish implemented-as-no-op
from not-implemented — or is the ambient inventory's transitive-closure measurement sufficient
because it reads BODIES rather than BINDINGS? Decide from the code, and say which.

Do not modify any file in the repository. This is a read-and-analyse task.

ANSWER FORMAT — Markdown, under 400 lines:
- A table: tool | what it keys on today (file:line) | verdict under capability lists | work required.
- Your answer to question 3, with the coverage-unit decision stated plainly.
- Your answer to the override-witness question: YES it is needed, or NO it is not, plus the
  evidence from the code that decides it.
- THE BIGGEST RISK you found in re-shaping this tooling, and what it would cost to get wrong.
```

### Delegation 4 — kind: `codex`

prompt:

```
You are working in the repository at /workspaces/motoko_agent. Produce a concrete, TYPE-CHECKED
sketch of a proposed API change, and a policy recommendation.

BACKGROUND. Read .agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md §3.3
and packages/motoko-ext-abi/types.ail. The 6.0 version of this ABI is proposed to replace the
eight-slot `ExtensionHooks` record with a list of capabilities: `register_with_config` would
return `[Capability]`, where `Capability` is an ABI-owned sum with one variant per hook kind.
The motivation is an asymmetry in AILANG: adding a FIELD to a record breaks every constructor,
while adding a VARIANT to a sum breaks only exhaustive matchers — and extensions only construct,
while the only exhaustive matcher is the in-tree dispatcher (src/core/ext/runtime.ail).

YOUR TASK:
1. Write the full `Capability` sum type covering ALL EIGHT existing hook slots, preserving each
   slot's exact closed effect row and its payload types as they are declared today. Note that
   §3.3 proposes collapsing `provided_tools` + `on_tool_handle` into a single `ToolProvider`
   variant — carry that through, and bundle in the `proc_exec` rename that types.ail lines
   324–406 already price for 6.0.
2. TYPE-CHECK IT. Put it in a scratch file under /workspaces/motoko_agent/tmp/017-capability/
   and run the repo's AILANG on it (`ailang check`; the local binary is ailang/bin/ailang).
   A sketch that does not type-check is not an answer. Iterate until it checks or until you can
   state exactly which AILANG limitation blocks it.
3. Sketch how src/core/ext/runtime.ail's dispatcher would iterate a capability list instead of
   record fields, preserving the existing per-slot merge semantics (concatenation, registry-order
   patch folds, chaining, first-match, and the Deny > Pending > Allow > NoOpinion and
   ContinueWithFeedback > Accept > NoDecision priority merges). Read runtime.ail first.
4. DECIDE THE MULTIPLICITY POLICY. The record model guaranteed at most one binding per slot per
   extension; a list does not. For EACH capability variant, state whether N>1 from one extension
   is an error to reject at registration or a feature to support, and give the reason from the
   merge semantics of that slot. Say where the validation would live.

Do not modify any file outside /workspaces/motoko_agent/tmp/017-capability/.

ANSWER FORMAT — Markdown, under 400 lines:
- The `Capability` type, inline, exactly as it type-checked.
- The verbatim `ailang check` output proving it checks — or the precise limitation that blocks it.
- The dispatcher sketch, with the merge semantics preserved and named per variant.
- A multiplicity table: variant | N>1 allowed? | why | where enforced.
- ANYTHING THAT DOES NOT SURVIVE THE TRANSLATION: name every part of today's ABI you could not
  express as a capability, and say what it would cost to lose it.
```

---

## Phase 2 — collect

Cycle `DelegateCheck` over the four handles until every one has produced an answer or
hard-failed. Re-read rules 4 and 5 above before you decide any delegate is finished.
A "still working" result is not a failure and is not a reason to stop.

Once you have all four answers, read the full answer files if the tool output was
truncated — they are at `.motoko/herdr-delegates/answer-<handle>.md`.

---

## Phase 3 — synthesise (this part is yours, not a delegate's)

Write `.agent/projects/017_extension_handling/ADR-001-extension-abi-evolution.md` with
exactly these sections:

1. **Decision** — what to do now, what to do at 6.0, and what to reject. State it in the
   imperative, in under 10 lines. The research doc's §4 is the incoming recommendation;
   say whether the measurements confirmed it, changed it, or overturned it.
2. **The four questions, answered** — one subsection per §5 open question, each stating the
   answer, the evidence, and which delegate produced it (by handle and kind).
3. **What the measurements changed** — anything a delegate found that contradicts the
   research doc. If nothing did, say so explicitly; do not manufacture a disagreement.
4. **Disagreements between delegates** — if two answers conflict, state both and say which
   you believe and why. Do not average them and do not hide one.
5. **What is still unknown** — anything no delegate could measure, and what it would take
   to measure it.
6. **Provenance** — a table of the four delegations: handle, kind, what it was asked,
   whether it succeeded, and the path to its answer file.

Rules for the synthesis:
- Every claim must trace to a delegate's measured output or to the research doc. If you
  cannot source a claim, cut it.
- If a delegate reported a command's verbatim output, quote the output rather than
  paraphrasing its conclusion.
- Do not restate the research doc at length. The ADR is a decision, not a summary.

---

## Definition of done

You are done when ALL of the following are true:

- Four delegations were issued, and each either produced an answer file or is reported as
  hard-failed in the ADR's provenance table.
- `ADR-001-extension-abi-evolution.md` exists with all six sections above.
- If Delegation 2 left changes in the working tree, you have run `make check_core` yourself
  and the ADR states its result. If it fails, say so in the ADR — do not claim success on
  code that does not compile.
- Your final message names the decision in one sentence and lists the four answers in one
  line each.

Do not stop before then. A prose-only reply is your stop signal, so do not emit one while a
delegate is still outstanding.
