# Review: ADR-001 Extension-owned structured decisions (v0.4)

Reviewer: Claude Opus 5 (`claude-opus-5`), independent full review, 2026-09-20. Neither the drafter
(Claude Fable 5.1) nor the third reviewer (Codex `gpt-6-astra`). This reviews the **working-tree
v0.4**, not the v0.2 committed at HEAD. Branch `arniwesth/031-abi-8-0`; HEAD
`2f3ee4d1e83feb677583924131ce08f7cb91b47a`; ABI `7.4`; AILANG `v0.33.0`, commit
`ae36986c5c0a1e8ad4f0fc1e607efddefbbae46a`. The reviewed file has 772 lines and SHA-256
`0e8b0c05aaac4e1a7c2c4ffe4e1c60ce772d2b9afabee1c1f99868d19d490758`, matching the handoff. Final
provenance and the post-write SHA check are below the appendix.

## 1. Architectural verdict and freeze readiness

**Retain the architecture; do not freeze v0.4.** Everything the first three reviews accepted stands:
extension-owned preparation and interpretation, two invocation sites, two pure callbacks, the
provider-independent integer vocabulary with explicit absence, nullary `Accept`, all-atoms ordered
execution with paid losing votes, host-mediated decision transport, and the split between query
identity, policy manifest and response metadata. v0.4 is a substantial improvement over v0.3 and
closes five of the third review's eight items cleanly (N24, N25, N27 in part, N29, N30). Its
corrections are honest: D2 now says what the context types actually buy, and says it in the right
words.

**But v0.4's central new claim is false on the pin, and it is false in the slot that matters most.**
D2 replaces v0.3's disproved compile-time gate with a **registration discipline** — "a named
top-level function, or an inline lambda whose body is exactly one call to a named top-level function
passing the lambda's parameters through" — and rests freeze item 2(b) on it. I re-ran the third
review's 21 probes (**0 mismatches**, confirming the drafter's re-run) and then built the two
constructions the handoff's Q-1 asked for. The second one escapes:

```ailang
type W = { f: (PureCtx) -> int }
func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }          -- named top-level
func build() -> Slot ! {IO} {
  let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } };
  Pure(func(ctx: PureCtx) -> int { apply(ctx, w) })          -- the PERMITTED shape
}
```

`ailang check` exit 0. `ailang run` exit 0, printing `EFFECT WITH NO PORTS OR WORLD` from inside the
callback. The registered value is an inline lambda whose body is exactly one call to a named
top-level function, passing its parameter through plus a captured value — **precisely the
`compose.ail:1110` shape v0.4 names as the permitted form**, and precisely the "captured value
alongside the parameters" case the handoff asked me to try. The same escape works in the realistic
D2 shape `prepare: (PureCtx, candidate) -> JudgePreparation` (probe `n_dec_prepare_escape`: it
prints the candidate text) and in the `{FS}` view (probe `n_fs_passthru_captured2`).

This is not the 017 record-field hole restated. The third review demonstrated that hole only from the
`{FS}` view and recorded, correctly for what it measured, that "**no successful ambient-effect escape
from the rowless slot was demonstrated**" — its `direct`, `captured`, `localrecord`, `localannot` and
`localunannot` pure-slot attempts were all rejected, and I reproduced all five rejections. The
escape needs one intervening named function between the extraction and the constructor, and once it
is there the rowless slot falls too. So v0.4's discipline is not a sound fail-closed rule; it is a
rule with a hole in the exact construction it was written to bless.

Three further problems are load-bearing rather than editorial. The discipline's **in-tree exception
list is wrong by an order of magnitude** — v0.4 names one exception where the tree holds at least
twelve `let`-bound callback bindings across ten packages plus several other-body inline bindings
(N32). The **enforcement point is not a gate**: `ext_hook_scope` is absent from `DST_TARGETS`, G5e
names only `ext_hook_scope_selftest`, and the tool resolves extensions only through path
dependencies in the repo's own `ailang.toml` (N33). And D7's **schema-1 refusal claim is wrong on
the fold as it stands**, in both directions — the behaviour v0.4 asks ADR-003 to be amended to
provide already exists and is pinned by a test, while the refusal message v0.4 promises is not the
one the fold produces, and the header version of a schema-2 session is left unspecified (N34).

The two allowance rules (N26/N28) are the right shape and are much clearer than v0.3, but they are
not yet complete: the admission equation omits the disabled-cap case the step machine actually
implements, and its inputs exist in no type the ADR defines (N35); and "a newly introduced identity
requires explicit registry migration" is an obligation with no check behind it — a profile switch is
accepted by `resume_refusal` without any extension-set comparison at all (N36).

Ten new findings follow, **N31–N40**. Missing implementation evidence (freeze items 1–3) is
identified separately and is not counted as a finding, as in the third review.

## 2. Remaining blockers

| Blocker | Decision or evidence needed | References |
|---|---|---|
| **F1 still unresolved: N31** | The named-or-pass-through rule does not close the rowless slot. Either narrow the permitted pass-through form so that no captured value may be a record or function (and prove it), or drop the pass-through arm entirely and require named top-level functions only, or make the enforcement a reachability walk rather than a shape check and say so. The ADR must stop claiming a boundary the probe set falsifies, and freeze item 2(b) must name the construction that escaped. | D2; freeze 2; Appendix A |
| **The exception list is false: N32** | v0.4 says the in-tree exception is `progress-contract-guard`'s inline judge. It is at least twelve `let`-bound bindings (compose ×2, context-mode ×2, repetition-guard ×2, a2a, agentcli, ailang-docs, exa-search, mcp, scratchpad) plus test-dummy's four other-body inline atoms and several `\_ .`/projection forms. Re-measure the 46 constructor call sites, price the migration, and decide whether the rule changes or the tree does. | D2; D7 tooling row; freeze 2(c) |
| **The gate does not run: N33** | `ext_hook_scope` is not in `DST_TARGETS`; G5e names `ext_hook_scope_selftest`, the fixture suite. Name the target that runs the rule over the tree, put it in the lane, and state that extensions without in-tree sources are outside its reach. | D7; freeze 8; release G5e |
| **Schema transition underspecified: N34** | State what `schema_version` a *new* schema-2 session's header carries, and widen `header_of_entry`'s `v != 1` accordingly. Correct the claim that a schema-1 reader refuses "with the `Schema` message" — it refuses with `Entry(seq, "type=schema_promotion")`. Withdraw the unknown-entry ADR-003 amendment: the fold already refuses, and `journal.ail:3282-3288` pins it. | D7; `journal.ail:634,813-818,3282-3288`; `session-journal.ts:34` |
| **Admission equation incomplete: N35** | Add the `max_cost_millicents > 0` guard the step machine implements, and give the child a typed carrier for `decision_allowance`, `known_spend` and `outstanding` — `DecisionInvocationState` carries intervention counts only, so the deterministic preflight the ADR requires cannot be evaluated from anything D3 defines. | D5; D3; `step_machine.ail:112-114` |
| **Fresh allowance still reachable: N36** | Define the refusal that detects a newly introduced identity. `resume_refusal` compares nothing across a profile switch (ADR-003 D5, `journal.ail:1796`), and the `Descriptor` row is keyed by identity, so a new identity has nothing to compare against and admits itself. | D5, D6; ADR-003 D5 |
| **Evidence 1–3 still not supplied** | Unchanged from the third review: accepted signatures, compiled ABI-8 examples for both consumers under the discipline, view/construction probes, updated inventories, strict mismatch and offline-experiment evidence. | Freeze 1–3 |

F2 remains resolved as architecture, and N25's contract is the right one. N29's validation split is
correct and I found nothing to add to it. N30 is resolved in substance, with a documentation
correction (N39).

## 3. New findings (N31 onward)

### N31. The registration discipline does not close the rowless slot

**Evidence.** Appendix A.2, probes 22–24. `n_pure_passthru_captured` checks with exit 0 and runs with
exit 0, performing `println` from inside a `PureCtx` callback. The registered payload is
`Pure(func(ctx: PureCtx) -> int { apply(ctx, w) })` — an inline lambda whose body is exactly one call
to the named top-level `apply`, passing the lambda's parameter through plus the captured `w`. That
is the form D2 permits, named in D2 by reference to `compose.ail:1110`. `n_dec_prepare_escape` is
the same escape at D2's real `prepare` arity `(PureCtx, candidate) -> JudgePreparation`, and prints
the candidate string. `n_fs_passthru_captured2` is the same escape from `FsCtx`.

The escape has three preconditions, each satisfied by ordinary in-tree code:

1. the smuggled body is stored in a **locally declared** record type's field. Importing the record
   type kills it (`n_pure_passthru_xmod`, rejected at the `let` annotation) — so the confound the
   third review avoided by importing its *sum* does not extend to the *record*, and the local `type
   W = { f: … }` form is what `compose.ail`, `herdr.ail` and the script's own limitation probes use;
2. the stored lambda carries `! {}` (or the slot's row). Unannotated rejects (`n_pure_passthru_unannot`);
3. the enclosing registration function declares the smuggled effect. Removing it rejects
   (`n_pure_passthru_norow`). Every `register_with_config` in the tree that matters declares one:
   compose's is `! {Env, FS, AI, Clock, IO, Process, Rand}`.

The **named-function arm holds**. I could not escape through it: `n_pure_named_localsmuggle`,
`n_fs_named_localsmuggle`, `n_fs_named_indirect` and `n_pure_named_applier` are all rejected, and the
rejection is the effect pass charging the smuggled row to the named function. Capturing a bare
function value instead of a record also rejects (`n_pure_passthru_capturedfn`,
`n_fs_passthru_capturedfn`). It is specifically the **pass-through-with-captured-record** form that
fails, and that form exists only because v0.4 added it to bless `compose.ail:1110`.

**Consequence.** D2's "**Registration discipline (the enforced boundary)**" paragraph is false as
written, and freeze item 2(b) — "the registration discipline rejects every construction the 21-case
suite shows escaping" — is satisfiable only because the 21-case suite does not contain this
construction. The 21 probes are not the regression the ADR says they are: they are a suite that
predates the rule they are asked to validate. Worse, the escape is available from `PureCtx`, so the
three consequences NOTE-001 §5 lists for the pure slot (dropped successor world, unrecorded `Env`
read, misattributed `ai_step` spend) are reachable by a callback the discipline certifies — the
supplied-authority argument protects the *ports*, but ambient `std/*` imports are not supplied
authority and the discipline was the only thing standing between them and a pure slot.

**Decision needed.** Pick one and prove it. (a) Drop the pass-through arm; require named top-level
functions for every `Capability` payload, and migrate `compose.ail:1110` and its siblings. This is
the only arm I could not break, and its cost is bounded (N32 has the count). (b) Keep the arm but
forbid any captured value that is not of a primitive or imported type, and add the three
preconditions above as positive regressions. (c) Make the boundary a reachability walk rather than a
shape rule — which is what `hook_scope.py` already does and what would in fact reject this escape
(N33) — and rewrite D2 to describe that instead of a shape. In every case: add these three probes to
the suite, state that the suite is a regression *for the rule* and not merely for the compiler, and
stop calling the shape rule "the enforced boundary" until something enforces it.

### N32. The discipline's in-tree exception list is wrong by an order of magnitude

**Evidence.** D2 states: "Everything else — `let`-bound lambdas, lambdas with any other body,
callbacks constructed through local records or helpers — **fails closed** … The in-tree exception is
`progress-contract-guard`'s annotated inline judge, which becomes a named function." I read every
`register_with_config` and every delegated `make_hooks` in the eighteen installable packages. The
`let`-bound payload bindings alone are twelve:

| Package | Binding | Slot |
|---|---|---|
| compose | `handle`, `intercept` | `ToolProvider`, `ResponseInterceptor` |
| context-mode | `handle`, `finalize` | `ToolProvider`, `SolverJudge` |
| repetition-guard | `policy`, `finalize` | `ToolPolicy`, `SolverJudge` |
| a2a | `handle` | `ToolProvider` |
| agentcli | `handle` | `ToolProvider` |
| ailang-docs | `handle` | `ToolProvider` |
| exa-search | `handle` | `ToolProvider` |
| mcp | `handle` | `ToolProvider` |
| scratchpad | `handle` (type-annotated `let`) | `ToolProvider` |

Four of these (`compose.intercept`, `context-mode.finalize`, `repetition-guard.finalize`,
`a2a.handle`, `mcp.handle`) have record-literal or `match` bodies, so they fail the second arm too
even if `let` binding were permitted. Beyond them, test-dummy binds four atoms whose bodies are
conditionals or record literals; herdr binds `\ctx call. decide(orch, ctx.workdir,
ctx.history_slice, call)` and `\_ctx. prompt_patch(orch)`; ailang-docs binds `\ctx.
build_prompt_patch(ctx.task)`; a2a, agentcli, ailang-docs and scratchpad bind `DescribeTools` to
`\_ . <expr>`. The last group raises a question D2 does not answer: does "passing the lambda's
parameters through" admit a **projection** of a parameter (`ctx.task`, `ctx.workdir`) or a call that
passes none of them? Under the literal wording, no. There are 46 capability-constructor call sites
in `packages/`.

**Consequence.** Three things follow. The migration price in N24 is understated again, in the same
direction the third review corrected once: it is not only helper signatures, it is the binding form
of roughly half the registrations in the tree. Freeze item 2(c) — "compiled ABI-8 examples of both
consumers registered under the discipline" — cannot be read as cheap when the discipline invalidates
most existing registrations. And the sentence "the in-tree exception is progress-contract-guard's"
is the kind of specific, checkable claim that a reader will rely on when scoping the plan.

**Decision needed.** Re-measure and publish the count in D2 (or defer it to the plan explicitly, as
N24's per-package pricing was deferred, rather than asserting a wrong number). State whether a
parameter projection and a zero-parameter call satisfy the pass-through arm. If the answer to N31 is
"named functions only", say that the tree's registrations migrate with it and that `DescribeTools`'s
`\_ .` forms need a disposition of their own.

### N33. The named enforcement point is not a gate, and cannot see an installed extension

**Evidence.** Three separate facts. (i) `ext_hook_scope` — the derivation over the tree — is **not**
in `DST_TARGETS` (`Makefile:507-519`); only `ext_hook_scope_selftest`, the fixture suite, is. G5e
likewise names `ext_hook_scope_selftest including the named-or-pass-through registration rule`, so
the reworded release gate proves the rule works on fixtures, not that the eighteen in-tree
extensions satisfy it. (ii) `derive.installable_extensions` resolves each installable package
through a **path dependency in the repo's own `ailang.toml`** and raises `SystemExit` if one is
missing; an extension installed from the registry has no source directory for the tool to read.
(iii) `hook_scope.py`'s own header states it "REPORTS a second answer. It does not change
`ext_ambient_inventory`'s shipped verdict", and its scope note rules registration-time effects whose
result a hook closes over *out* of criterion 2, reporting them as `registration_only` — which is the
category N31's escape is constructed in.

There is an upside worth recording. Because `hook_scope.py` **walks transitively** into named
callees rather than only checking the binding's shape, it would very likely reject N31's escape
today: walking into `apply` reaches `w.f(ctx)`, a dotted call whose receiver is not an `ExtPorts`
field, which is the `applied-local` rejection at `hook_scope.py:844`. That is the right answer for
the wrong stated reason — it is the reachability walk doing the work, not the named-or-pass-through
rule, and D2 describes only the rule.

**Consequence.** As written, "fails closed in `hook_scope.py`" names a build-time inventory that is
not in the gate lane, is scoped to in-tree sources, and whose documented reading excludes the
construction class at issue. An operator who installs a third-party extension at runtime passes
through none of it, and the ADR's own sentence — "this discipline is freeze evidence (item 2), not a
later live-enforcement task" — is honest about that but leaves the residual unstated.

**Decision needed.** Name the target that must run the rule over the tree and add it to the lane and
to G5e. State explicitly that registry-installed extensions without in-tree sources are outside the
gate's reach and that for them the guarantee is restricted supplied authority alone. If the
reachability walk is what actually closes N31's class, say so in D2 and make the walk — not the
shape — the specified boundary.

### N34. D7's schema-1 refusal is wrong in both directions, and the schema-2 header is unspecified

**Evidence.** D7 says: "A schema-1 reader refuses at that entry with the `Schema` message
(`journal.ail:634`) … the schema-1 fold must refuse at the first entry kind it does not know rather
than skip it, an ADR-003 amendment (below)."

1. **The amendment is unnecessary.** The fold already refuses an unknown entry type, and it is pinned
   by a test whose comment says so in terms: "AN UNKNOWN TYPE IS REFUSED, not skipped"
   (`journal.ail:3282-3288`), asserting `Entry(seq, "type=not_an_entry")`. Nothing needs amending.
2. **The message is the wrong one.** `Schema` is produced only by `header_of_entry` when
   `schema_version != 1` (`journal.ail:813-818`); its own diagnostic text is header-scoped ("the
   header's `schema_version` is not 1"). A schema-1 runner meeting an appended `schema_promotion`
   entry gets `Entry(seq, "type=schema_promotion")` — which reads to an operator as a corrupt
   journal, not as "your runner is too old". The one operator-facing benefit of the refusal is the
   diagnosis, and this design does not deliver it.
3. **The header version is undefined.** `JOURNAL_SCHEMA_VERSION = 1` (`session-journal.ts:34`) is
   written only by `writeHeader`, which is a no-op on an adopted file. v0.4 never says what a *new*
   schema-2 session's header carries. Both answers have consequences the ADR does not address. If it
   stays `1`, then `schema_version` no longer names the schema, the `Schema` refusal becomes dead for
   this transition, and no schema-1 runner ever gets a header-level refusal. If it becomes `2`, then
   `header_of_entry`'s `v != 1` must widen, and there are now **two shapes of schema-2 journal** —
   promoted (header 1, `schema_promotion` entry present) and native (header 2, no such entry) — for
   which "above it schema-1 semantics, below it schema-2" has no anchor in the native case.

Separately: the appended-entry choice is justified against ADR-003's one-rewrite rule, but that rule
is a rule, not a cost, and v0.4 is simultaneously proposing two other ADR-003 amendments. The
existing `completeHeader` is an atomic in-place rename, so a second permitted rewrite was mechanically
available and would have avoided (3) entirely. The appended entry is still defensible on crash-safety
grounds; what is missing is that the trade was made and what it costs.

**Decision needed.** State the new-session header version and the widened header check together.
Replace the `Schema`-message claim with what the fold does, or add an entry-level refusal that
carries a schema diagnosis. Withdraw the unknown-entry amendment and cite `journal.ail:3282-3288`
instead — it is stronger evidence than an amendment, because it is already tested. Keep the
upgraded-session-resumed-twice fixture; add a native schema-2 session read by a schema-1 runner.

### N35. The admission equation is incomplete and its inputs are not typed anywhere

**Evidence.** D5 states admission as: `r ≤ decision_allowance − (known_spend + outstanding)` and,
when `cost_metered`, `r + totals.cost_millicents ≤ max_cost_millicents`. The step machine's actual
gate is `pol.max_cost_millicents > 0 && pol.cost_metered && s.totals.cost_millicents >=
pol.max_cost_millicents` (`step_machine.ail:112-114`). Two gaps:

1. **The disabled cap inverts.** `max_cost_millicents <= 0` means "no cap" in the code. v0.4 handles
   only `cost_metered = false`; a metered profile with the cap disabled — which is what the third
   review reported for ADR-004's admitted T0 profile — satisfies `cost_metered` and fails
   `r + totals ≤ 0` for every positive reservation. Applied literally, the equation turns "no cap"
   into "refuse everything".
2. **The child cannot evaluate it.** D5 says the reserved charge comes from "the child's
   deterministic preflight", and D6 requires strict replay to "re-execute deterministic preflight"
   with no provider contact and reading recorded configuration rather than ambient config — so
   preflight is child-side and must be a function of the record plus the context. But the only
   decision state D3 puts in any context is `DecisionInvocationState = { invocation_id, mode,
   interventions_used, intervention_limit }`. There is **no** `decision_allowance`, no
   `known_spend`, no `outstanding`, and no `totals.cost_millicents` on `PureCtx`. The equation's
   three left-hand terms have no carrier.

**Consequence.** Either the preflight is host-side, in which case D6's "strict replay re-executes
deterministic preflight" and "records the refusal event and invokes the interpreter with the
corresponding `Unavailable`" need to say that the host re-executes it from the record and how the
replaying host obtains the ledger; or it is child-side, in which case D3 is missing fields on a type
the ADR is about to freeze. This is an ABI-surface question, not a plan question, which is why it
belongs before the freeze rather than in the implementation plan.

**Decision needed.** Add the `max_cost_millicents > 0` guard to the stated equation. Decide which
side evaluates admission and, if it is the child, extend `DecisionInvocationState` (or add a sibling)
with the allowance, the known spend and the outstanding total, in the same units. Say what a
metered-but-uncapped profile does.

### N36. A newly introduced identity still obtains a fresh allowance, because nothing refuses it

**Evidence.** D5: "a newly introduced identity requires explicit registry migration rather than
silently obtaining a fresh allowance on resume." D6: identity is `"${name}#${idx}"` × site × local
ID, "so a reorder or reinstall is a new identity and needs the explicit registry migration D5
requires; `--resume-force` does not authorize it." I confirmed the identity claim — `ext_set_digest`
covers the full instance id and the capability kinds in registry order (`runtime.ail:1113-1122`,
`types.ail:1275`) — but not the refusal.

There is no check that fires on a new identity:

- `resume_refusal` compares `ext_set_digest` **only under the same profile**
  (`journal.ail:1796-1806`), and ADR-003 D5 states "**profile switch accepted**" with `ext_artifacts`
  reset. So a profile switch that installs a different set, or the same set in a different order,
  is accepted with no digest comparison at all.
- The new `Descriptor` row is keyed *by* identity: it compares a registered atom's descriptor against
  the effective epoch's entry for that atom. A **new** identity has no prior entry, so there is
  nothing to mismatch and the row passes by construction.
- Under the same profile, a reorder does change `ext_set_digest` and is refused as `ExtSet`. But the
  stated remedy is `--resume-force`, and v0.4 says force "does not authorize" the migration without
  saying what then happens. The resume proceeds; the identity is new; the ledger is orphaned; the
  new identity's allowance is its full configured maximum.

**Consequence.** The one path v0.4 explicitly set out to close — "silently obtaining a fresh
allowance on resume" — is still open, and the profile-switch arm is open without even a forced
override. The refund rule (never refund an outstanding reservation, never re-charge it to a fresh
run) is sound and I found no path that violates it; the leak is on the other side, in minting.

**Decision needed.** Define a refusal that fires when the invoked registry introduces an identity the
effective epoch's ledger does not hold, and make it compare **across** profile switches as the
`Descriptor` row already does. Say whether `--resume-force` waives it (and, if so, that the waived
identity starts at zero used and zero allowance until migrated, rather than at a fresh full
allowance). Add "profile switch that reorders or replaces the registry" to D6's pinned case list —
today the list has "reorder" and "profile switch" as separate rows and this is their product.

### N37. The `Descriptor` row's granularity makes routine threshold tuning a forced resume

**Evidence.** D6 makes the `Descriptor` resume row compare "question or interpretation version/config
digest, or the declared limit". The interpretation config is where thresholds, abstention and
feedback policy live (D2). D6's remedy for a mismatch is refusal plus `--resume-force`, and a forced
override appends a new policy epoch.

**Consequence.** During the shadow-mode period the ADR prescribes for the first guard — the period
whose whole purpose is tuning thresholds against recorded behaviour — every threshold edit refuses
the resume of every live session and requires `--resume-force`. That is the same flag that waives
extension-digest and prompt mismatches, so the operator habituates to forcing, and the flag stops
carrying signal exactly when the new refusal most needs it to. It also appends an epoch per tuning
step, which is correct but makes the epoch chain long and the rollback rule ("a rollback to P0 is
refused unless forced") bite frequently.

This is a consequence of a decision, not an error in it: comparing the interpretation digest is the
right call for strict replay fidelity. But the first review's N5 asked precisely for the question
version and the interpretation version to be treated differently, and v0.4 separates them in the
identity layers while merging them again in the resume row.

**Decision needed.** Either split the row — refuse on a question/evidence or limit change, record a
settings entry for an interpretation-only change — or state the cost and say that live sessions are
expected to be forced through threshold tuning. Do not leave it implicit.

### N38. Release scope G5a still states the F1 resolution v0.4 falsifies

**Evidence.** The working-tree diff of `033_release/ADR-001-release-scope.md` changes exactly two
things in the G5 row: G5e's wording and the status cell. **G5a is untouched** and still reads: "v0.3
resolves blockers F1 (compiler does not enforce purity of an anonymous callback against `ctx.ports`;
fix is a ports-free `DecisionCtx`) and F2 …; the handoff
`HANDOFF-2026-09-18-adr001-v0.2-review-to-v0.3.md` is the edit list."

**Consequence.** D2's whole N23 correction is that a ports-free context is *not* the fix for the
compile-time claim — it gives restricted supplied authority and nothing more. G5a now asserts, as
the release's acceptance criterion for this ADR, the proposition the ADR itself withdraws. It also
still names the v0.2→v0.3 handoff as the edit list, two revisions on. The brief asks whether G5e
matches freeze item 8; it does (see Q-4), but the row it sits in does not match the ADR.

**Decision needed.** Reword G5a to the current acceptance criterion: ADR-001 reaches accepted status
at the revision that resolves F1's *actual* boundary and F2, with the v0.4 review as the gate. Name
the current handoff.

### N39. Freeze item 8's `XFAIL` class duplicates an idiom the script already has

**Evidence.** `run_declared_vs_performed.sh:751-771` scores the two known compiler limitations
two-sided and in the expected-limitation direction already: `ok "LIMITATION 1 still holds: a
RECORD-FIELD lambda's declared row is NOT checked against its body"` when the check **succeeds**, and
`bad "LIMITATION 1 IS FIXED UPSTREAM … it invalidates this file's controls"` when it fails. Same for
limitation 2. The target is green on v0.33.0 *with* the limitations, and goes red when they are
fixed — which is exactly the `XFAIL` semantics v0.4 proposes, including v0.4's "flip the row to a
hard `REJECT` expectation" instruction. Separately, NOTE-001 §6 lists the trigger-shape row as a
**proposed** mitigation ("**Red today**"), and it is not in the script: I found no such row.

**Consequence.** N30's premise — that the documents describe incompatible acceptance criteria —
describes a row that does not exist yet, so there is no contradiction in the tree today. v0.4's
resolution is nevertheless the right one for when the row is added; it is the framing that is off.
Adding a distinct `XFAIL` class beside an existing idiom that already does the job risks two ways of
saying the same thing in one script, which is the failure mode this file's own comments argue
against at length.

**Decision needed.** Either write the trigger-shape row in the established idiom (an `ok` when the
limitation holds, naming the upstream ticket, with the two-sided control beside it) and drop the
`XFAIL` class, or introduce `XFAIL` and convert the two existing limitation rows to it so the script
has one vocabulary. Say in freeze item 8 that the row is new rather than red.

### N40. A finalize-site reservation may never be tested against the run cap

**Evidence.** The run cost cap is read only in `call_model_or_fail`, i.e. immediately before a model
call (`step_machine.ail:102-114`). D5 says the reservation enters `totals.cost_millicents` "so
`BudgetExceeded` sees this run's decision spend on the next step."

**Consequence.** A decision query at the **finalize** site runs after the last model call of a run.
If the guard's vote ends the run — which is the ordinary case for a completion guard returning
`NoDecision` or an accepted candidate — there is no next step, and the reservation is recorded but
never tested. The run cap is therefore an upper bound on decision spend only for tool-policy queries
and for finalize queries that lead to another turn. The decision allowance still bounds it, so this
is a disclosure gap rather than an unbounded spend.

**Decision needed.** One sentence in D5 saying that the run cap observes decision spend at the next
model call and that a terminal finalize query is bounded by the decision allowance alone.

## 4. Resolution of N23–N30

"Resolved" means a coherent decision whose stated facts hold against the tree, not that an
unimplemented feature has passed a gate.

| Item | Verdict | What I verified against |
|---|---|---|
| **N23** enforcement boundary | **Not resolved** | The restatement ("restricted supplied authority, not compile-time purity") is correct and the three measured facts are accurate — I reproduced all 21 probes with 0 mismatches. But the discipline that is supposed to close the rest is falsified by a construction inside its own permitted form (N31), its in-tree exception list is wrong (N32), and its enforcement point is not a gate (N33). Appendix A.2 probes 22–24. |
| **N24** migration beyond parameter types | **Resolved** | `ToolProvider`'s row (`types.ail:1244-1248`) does not admit `ai_step`'s `{AI, IO, Trace}` without adding `Trace`; the addition is correctly derived. `ExitIntent`/`WorkInFlight` at `! {FS}` (`:1263,:1273`) and herdr's two renderers using `file_read` only. The helper rule (data projection or smallest ports record, no dummy ports) is the right one and the closed-record constraint is real (`helper` probe). The one gap is the binding-form half of the migration, which is N32, filed separately. |
| **N25** journal write barrier | **Resolved** | `append` catches and returns `null` (`session-journal.ts:367-386`); `SessionLogger.log` discards the result (`session-logger.ts:404-410`); `sendWakeReply` writes stdin with no prior journal write (`runtime-process.ts:1282-1298`). Also confirmed that a failed `append` leaves `seq` and `leaf` unadvanced, so the proposed success-returning barrier is implementable without reworking the chain. The three failure arms, the process-crash-only durability statement, the duplicate/late-reply rule and the stdin-ownership rule are all sound; `outstandingWake`'s single-slot late-reply drop is the right precedent and v0.4 correctly declines to copy the ordering. |
| **N26** policy epoch | **Partial** | The epoch fold is the right answer and the P0 → forced P1 → ordinary P1 analysis is correct. `resume_refusal` does compare only under the same profile (`journal.ail:1796-1806`) and ADR-003 D5 does accept a profile switch, so comparing the `Descriptor` row across switches is a real strengthening. What is unresolved: a *new* identity has nothing to compare against and mints a fresh allowance (N36), and the row's granularity makes interpretation tuning a forced resume (N37). |
| **N27** schema transition | **Partial** | The appended-`schema_promotion` boundary is crash-safe and the strict-superset reading is right. `adopt`/`writeHeader` behave as described (`session-journal.ts:288,403-417`). But the refusal claim is wrong in both directions and the schema-2 header version is unspecified (N34). |
| **N28** two cost lifetimes | **Partial** | The two scopes are correctly named and correctly grounded: `c2_state_from_continuation` resets `totals` by design and says why (`session.ail:2607-2652`); `cost_metered` gates the cap (`step_machine.ail:113`). The no-refund/no-re-charge rule is sound and I found no path that violates it. The admission equation is incomplete and uncarried (N35), and the finalize-site case is undisclosed (N40). |
| **N29** adapter validation | **Resolved** | Sole-host-normalizer, integer-only child validation, one versioned fixture-vector set, explicit retry disablement, end-to-end deadline, contract version tied to normalization, and the wire-request-as-projection rule. Nothing to add; this is the cleanest of the eight. |
| **N30** gate semantics | **Resolved, mis-framed** | G5e and freeze item 8 now agree in substance (Q-4). The framing is wrong: the script already implements expected-limitation scoring and the "red row" is a proposal, not a present state (N39). G5a was not updated (N38). |

## 5. The four questions

### Q-1. Is named-or-pass-through the right discipline, and is it sufficient on v0.33.0?

**Right in direction, wrong in detail, and not sufficient. No.**

The **named-function arm is sufficient and I could not break it.** Four separate attempts —
smuggling inside the named function's own body (`n_pure_named_localsmuggle`,
`n_fs_named_localsmuggle`), building the record through a named maker (`n_fs_named_indirect`,
`n_pure_named_applier`) — all reject, and they reject in the effect pass with the smuggled label
named. This is the arm the tree's evidence already supported (NOTE-001 §4: `context-mode`,
`omnigraph`, `microrag`, `repetition-guard`, `empty-stop-guard` bind named functions and none
exploits the gap), and it is the arm worth keeping.

The **pass-through arm is not sufficient**, and the handoff pointed at exactly the right stone. A
pass-through lambda whose single call passes a captured value alongside its parameters escapes when
the captured value is a **locally-typed record holding an annotated lambda** — check exit 0, run
exit 0, ambient `println` performed from `PureCtx`, and from `FsCtx`, and at D2's real `prepare`
arity. Capturing a bare function value does not escape; capturing across an imported record type
does not escape; dropping the enclosing registration row does not escape. So the escape is narrow,
but it is precisely the shape the arm exists to permit, and `compose.ail:1110`'s captured
`composition_mode` is a string only by luck of what compose happens to capture — the rule as written
does not restrict what a captured value may be.

A named function that itself builds a callback through a local record — the handoff's other
construction — **does not** escape: `n_fs_named_indirect` and `n_pure_named_applier` both reject,
because the enclosing named function's declared row is charged for the record's construction.

**Is `hook_scope.py` the right place, and can it fail closed?** Partly, and yes but not for the
stated reason. The tool's existing discipline is stronger than D2's rule: it resolves the binding to
text and then **walks transitively** through named callees, rejecting `applied-local`,
`unknown-callee` and unresolvable field calls (`hook_scope.py:143-150, 820-905`). That walk would
almost certainly reject N31's escape — `w.f(ctx)` inside `apply` is a dotted call on a
non-`ExtPorts` receiver — which is the correct verdict reached by machinery D2 does not mention. But
`_binding_text` today does the **opposite** of what D2 requires at the binding: it accepts an inline
lambda with any body and follows a `let`-bound local lambda into its body
(`hook_scope.py:913-932`). Making those fail closed is real work, and it is work that will reject
~12 in-tree bindings on day one (N32). Three structural caveats: `ext_hook_scope` is not in the gate
lane, G5e names only the selftest, and the tool sees only path-dependency sources, so a
registry-installed extension never meets it (N33). And the tool's own scope note rules
registration-time effects closed over by a hook *out* of criterion 2 — the category N31's escape
lives in — so the rule must be added as an explicit new verdict rather than assumed to follow from
the existing reading.

**Recommendation.** Drop the pass-through arm, or restrict its captured values to primitives and
imported types. Specify the boundary as the reachability walk the tool performs, not as a shape.
Add the three new probes as regressions, and state that the suite regresses *the rule*, not only the
compiler.

### Q-2. Are the policy-epoch and two-allowance rules consistent, and is the equation complete?

**Consistent with each other and with ADR-003 D5. The equation is not complete. Refunds are
closed; fresh allowances are not.**

**Consistency.** The two rules compose correctly. The epoch rule governs *which policy* is in force;
the allowance rule governs *what it may spend*, and D6's "what an override does **not** do:
recompute the effective allowance" is the join, correctly placed. Both are consistent with ADR-003
D5's accepted profile switch and with its reset totals: the run cap resets because ADR-003 says a
resumed run is its own run (`session.ail:2607-2652`, which states the reason), and the decision
allowance does not reset because it is keyed to session identity rather than to a run. Holding
`ext_artifacts` reset on a profile switch while host decision state persists is exactly right, and
is the one place the ADR improves on ADR-003 rather than merely obeying it.

**Completeness: no.** Two gaps (N35). The equation omits `max_cost_millicents > 0`, which the step
machine requires and which converts a disabled cap into a total refusal if the equation is
implemented as stated. And its three decision-side terms — allowance, known spend, outstanding —
appear in no type D3 defines; `DecisionInvocationState` carries intervention counts only. Since D6
requires strict replay to re-execute a deterministic preflight from the record, the side that
evaluates admission and the carrier for its inputs are ABI questions, not plan questions.

**Refunds: closed.** "A reservation left outstanding by an earlier run stays in the decision ledger:
it is **never refunded** because that run ended, and it is **not re-charged** to a fresh run's cap.
Each charge is counted once." I traced every path I could find and none of them refunds: the ledger
is keyed to session identity and survives the `totals` reset; the unknown-charge rule retains the
reservation; process death retains it; a forced descriptor override explicitly does not recompute
the allowance.

**Fresh allowances: still open.** The minting side leaks (N36). A profile switch is accepted with no
extension-set comparison, the `Descriptor` row cannot fire on an identity it has never seen, and
after a forced `ExtSet` override v0.4 says migration is required but defines no refusal that
enforces it. The rule is stated as an obligation on the operator with nothing behind it.

### Q-3. Is the appended `schema_promotion` entry sound, and does the refusal claim hold?

**The entry is sound. The refusal claim does not hold, in both directions, and the header version is
unspecified.**

**Sound against the one-rewrite rule and against `adopt`.** Yes. ADR-003 D3 admits exactly one
in-place write — completing the header on the first `session_start`, done atomically with a rename —
and `writeHeader` returns early once `seq !== 0`, which an adopted file guarantees
(`session-journal.ts:288-302, 403-417`). An appended entry needs neither, is crash-safe under
`appendFileSync`, and gives the fold a position to switch semantics at. The "boundary is where
zero-initialization stops — a second resume folds every decision record after it and resets nothing"
sentence is the right rule and answers N27's sharpest worry directly.

**Does "the schema-1 fold refuses at the first unknown entry" hold for the current fold?** **It
already holds**, and v0.4 has this backwards: it proposes the behaviour as an ADR-003 amendment when
the fold implements it and a test pins it (`journal.ail:3282-3288`, asserting `Entry(seq,
"type=not_an_entry")` and commented "AN UNKNOWN TYPE IS REFUSED, not skipped"). The amendment should
be withdrawn and replaced by a citation — which is a stronger position, since it rests on a test
rather than on a promise.

**But the message is wrong.** The refusal is `Entry(seq, "type=schema_promotion")`, not `Schema`.
`Schema` is reachable only from `header_of_entry` on `schema_version != 1` (`journal.ail:813-818`),
and its text is header-scoped. Under this design a schema-1 runner meeting an upgraded journal never
reaches a header-level check — the header still says `1` — so it reports what reads as a malformed
entry. The diagnosis is the only operator-facing value the refusal has.

**And the header version of a schema-2 session is undefined.** `JOURNAL_SCHEMA_VERSION = 1` is the
sole writer. v0.4 does not say whether a new schema-2 session writes `1` or `2`, and the two answers
give different old-reader behaviour, require different changes to `header_of_entry`'s `v != 1`
check, and produce two shapes of schema-2 journal for which the fold-boundary sentence has only one
anchor (N34).

### Q-4. Does `XFAIL` resolve the contradiction, and does G5e match freeze item 8?

**Yes to both, with one correction of premise and one stale neighbour.**

**Semantics.** `XFAIL` resolves it without weakening the gate. The class is defined two-sided — the
target is red if an `XFAIL` row unexpectedly *rejects* (the upstream fix landed) or if a `REJECT`
row accepts — so nothing is silently waived, a successful exploit is never scored as a successful
safety test, and the upstream fix is detected rather than missed. Crucially, the *passing* gate is
separated from the *expected-limitation* row: freeze item 8 says "the passing enforcement gate is the
`hook_scope.py` named-or-pass-through rule", so the green target does not stand in for enforcement.
That is the right structure. It is undermined only by N31 (the rule does not hold) and N33 (the
enforcement target is not in the lane and G5e names only the selftest).

**Do they match?** Substantively yes, and I compared them clause by clause. Freeze item 8: "the
target is green with `XFAIL` rows listed, red if an `XFAIL` row unexpectedly rejects … or a `REJECT`
row accepts … a fixed compiler is not a release prerequisite." G5e: "green means every `REJECT` row
rejects and every `XFAIL` row, a known compiler limitation listed in the output, still accepts; a
fixed compiler is not a prerequisite." Same three conditions, same listing requirement, same
disclaimer. Freeze item 8 additionally carries the flip instruction and the NOTE-001 §7 pointer,
which is appropriate detail for the ADR and not a divergence. G5e also adds "`ext_hook_scope_selftest`
including the named-or-pass-through registration rule", which matches item 8's sentence that the
rule is the passing gate — except that the *selftest* is the fixture suite, not the run over the
tree (N33).

**Two corrections.** The premise is off: the script already scores known limitations in the
expected-limitation direction (`ok` when they hold, `bad` when fixed upstream,
`run_declared_vs_performed.sh:751-771`), and NOTE-001 §6 lists the trigger-shape row as a proposal —
"**Red today**" — that is not yet in the file. So there is no contradiction in the tree at present,
and `XFAIL` should be reconciled with the existing idiom rather than added beside it (N39). And the
row G5e sits in was not otherwise updated: **G5a still asserts v0.3's ports-free-`DecisionCtx`
resolution of F1**, which D2 withdraws (N38).

## 6. D1–D7 assessment

| Decision | Assessment |
|---|---|
| **D1 ownership** | **Accept, unchanged.** The four-row split is correct and nothing in v0.4 erodes it. The host-mediated transport (D5) does not move policy ownership to the host: the host normalizes numbers and owns transport, the extension still owns questions, thresholds and interpretation. The "host may lower an extension's declared limits but cannot silently change its questions or interpretation thresholds" line remains the right invariant and is consistent with D5's effective-limit rule. |
| **D2 callbacks and contexts** | **Accept the shape; reject the enforcement paragraph.** Two positional pure callbacks, one request per invocation, vote-family multiplicity, the six views and the per-row derivation are all right, and the row derivation is correct against `types.ail` (`ai_step` `{AI, IO, Trace}` at `:294` is not a subset of `ToolProvider`'s row, which is why `Trace` must be added; the six FS fields at `:428-`; `clock_now` `{Clock}` at `:497`; `env_get` `{Env}` at `:524` surviving only in `ProviderCtx`). The three measured facts are accurately stated. The registration-discipline paragraph is falsified (N31), its exception list is wrong (N32) and its enforcement point is not a gate (N33). The closure-disclosure limitation is correctly and explicitly stated and should not be softened. |
| **D3 observations and evidence** | **Accept.** Integer basis points, the tolerance/apportionment/rounding rules, whole-response invalidation, explicit absence, and "no probability is a claim of calibration" are all sound. The evidence provenance rules check out: the `-1` sentinel really is "no subprocess, or a seam that cannot say" and explicitly not success (`ports.ail:645-646`), and `is_missing_infrastructure` really is a substring match over seven phrases (`session.ail:2231-2239`), so treating `VerificationUnavailable` as uncertain is right. The new-accumulation window and its honest `complete_from_session_start = false` on resume are correct. One gap, filed as N35: the state type carries intervention counts but not the spend terms D5's admission equation needs. |
| **D4 execution and merges** | **Accept, unchanged from the third review.** Per-atom two-phase dispatch, the cursor, every-atom execution with paid losing votes and retained successor worlds, the preserved precedences, the optional witness extraction, and nullary `Accept`. The `/5` attribution is correct: `dst_interaction.ail:96-110` records that WI-D17 added two constructors and moved no version, and `dst_program.ail:119-131` records that `/4` was moved by the wake class's payload. Nothing new to raise. |
| **D5 bounds and durability** | **Accept the transport and the barrier; complete the accounting.** The journal-write barrier (N25) is correct in all three arms and its evidence is accurate. The process-crash-only durability statement is honest and matches `appendFileSync`. The charged-and-unapplied recovery rule and the named emission-to-write window are right. The two allowances are the right decomposition. Outstanding: the admission equation (N35), the minting leak (N36), and the finalize-site disclosure (N40). |
| **D6 recording and identity** | **Accept the three layers and the epoch; close the identity hole.** The layer split is sound and strict-versus-offline semantics are right. The epoch fold is correct and the P0/P1 analysis is correct. `ext_set_digest`'s kind-only weakness is real (`runtime.ail:1107-1122` states it itself), so the `Descriptor` row is necessary. Comparing across profile switches is a genuine strengthening over `resume_refusal`'s same-profile rule. Outstanding: N36 (new identities) and N37 (row granularity). "Preflight reads them from the record, never from ambient configuration" is correct and important — see N35 for the missing carrier. |
| **D7 migrations** | **Accept the separation; correct the journal row.** The ABI/program/journal/event separation, historical-fixture preservation, unknown-tag rejection, the `/5` rationale and the `fmt`/`typefix-agent` dispositions are right. The ADR-004 amendment is correctly scoped: adding `Ports.decision_query` and its codecs touches `ports.ail` declarations that ADR-004 D5 pins by hash as protected regions, so a basis refresh genuinely is required, and "never by editing its evaluator worktree" is the right boundary. The "Other records" row's two ADR-003 amendments are half right: the `Descriptor` epoch amendment is necessary; the unknown-entry amendment is not, because the fold already does it (N34). The `ext_call_inventory` note is accurate — it does match `ExtPorts` by name. |

**Freeze-evidence audit.**

| Item | Result |
|---|---|
| **1** accepted contract review | Not met; blockers above. |
| **2** three enforcement classes | **Not met, and (b) is now falsified.** Class (a) is correctly specified and correctly labels the missing-field fault a host control failure. Class (b) requires "the registration discipline rejects every construction the 21-case suite shows escaping" — but the suite does not contain the construction that escapes the discipline, and adding it makes (b) fail (N31). Class (c) is the right requirement and is now much more expensive than the ADR implies (N32). The inventory clause must also say which target runs the rule (N33). |
| **3** extension-only change, strict mismatch, offline separation | Correct requirement, no artifacts. Unchanged. |
| **4** parity, propagation, occurrences, strict replay | Good obligations, unchanged. |
| **5** evidence and crash matrix | Well expanded by v0.4 — the three journal-append failure points, the schema promotion interrupted and repeated, the policy-epoch cases, cross-run outstanding reservations. Add: a new identity introduced by a profile switch (N36), and a native schema-2 journal read by a schema-1 runner (N34). |
| **6** composition and non-resetting limits | Correct. In-process suspension is named, which is right and is the case most likely to be missed, since `c2_state_from_continuation` is child-side and the ledger is host-side. |
| **7** format migrations | Correct apart from the journal row's refusal claim and the unspecified header version (N34). |
| **8** gate semantics | **Met in substance** (Q-4), with the premise correction in N39 and the lane/selftest gap in N33. |

**The three response tables** are faithful. I checked the first-review table against
`REVIEW-adr001-v0.1-verdicts-fable.md` (N1–N13) and the second against
`REVIEW-adr001-v0.2-verdicts-claude.md` (F1/F2, N14–N22): each row summarizes its finding without
overstating the resolution, and the two "partial" admissions (N13's model route, N7's accounting
note) are properly retained. The third-review table is accurate except that the N23 row asserts the
discipline closes what the views do not, which N31 falsifies, and the N27 row asserts an ADR-003
amendment that is not needed (N34). The `Q-A/Q-B/Q-C` row correctly records what the third review
concluded. One presentational point: the N23 row says "Drafter re-ran all 21 probes: 0 mismatches" —
I independently confirm that, probe by probe (Appendix A.1).

## 7. Before freeze, before the plan, and afterwards

**Before freeze.** Close N31 by choosing an enforcement that actually holds, and prove it with the
escape probes added to the suite. Re-measure and state the in-tree binding-form migration (N32).
Name a target that runs the rule over the tree and put it in the lane and in G5e (N33). Settle the
schema-2 header version and correct the refusal claim (N34) — this is a persisted-format decision
that the ABI's `ExtCtx` additions are entangled with, so it belongs before, not in the plan. Add the
`max_cost_millicents > 0` guard and give the admission equation's terms a carrier on a type being
frozen (N35). Define the refusal that fires on a new identity (N36). Fix G5a (N38). Then satisfy
freeze evidence 1–3 with real artifacts: this review, like the third, substitutes minimal language
probes for none of them.

**Before the affected implementation plan is approved.** The success-returning journal operations and
the host/child failure protocol (N25, resolved as a decision, still to be specified as an
interface). The `schema_promotion` write protocol including both journal shapes. The validation,
wire, retry and deadline contract (N29). The per-package helper and binding-form migration across
the eighteen in-tree packages plus the two registry-only dispositions. The `Descriptor` row's
granularity decision (N37). Schedule the ADR-003 amendment (one, not two) and the ADR-004 basis
refresh.

**During implementation, before live enforcement.** Freeze evidence 4–8, with the two additions in
the audit above. Exercise the finalize-site reservation case (N40) explicitly, since it is the one
place the run cap does not observe.

**Afterwards.** Provider limits, guard wording and thresholds, and live quality measurement evolve
under recorded policy versions — subject to N37's cost, which should be resolved before shadow mode
begins rather than discovered during it. Calibration and false-objection rates remain measurements
separate from replay fidelity. The existing `ext_ai_step` usage loss remains separately disclosed
debt and v0.4 is right not to claim it.

## 8. Method and limitations

I read the handoff first and completed both grounding checks before reading the ADR: HEAD is
`2f3ee4d1`, the ADR is 772 lines with the stated SHA-256, and `git diff --stat 2062605 HEAD` over
`src/core`, `packages`, `tools`, `scripts` and the `Makefile` is empty with no tracked working-tree
diff in those paths. Two untracked additions exist under `scripts/dst/` (`mem_canonical_bench.ail`,
`mem_growth_probe.ail`) which are additions, not modifications, and are unrelated; I did not create
or read them. AILANG on PATH is `v0.33.0`, commit `ae36986`, matching the pin.

Read in full: the ADR v0.4; the third review including all of Appendix A; the second and first
reviews; NOTE-001; the v0.4 and v0.2→v0.3 handoffs; the release scope's G5 row and its working-tree
diff. Read in the sections the handoff named plus their dependencies: `types.ail` (the `Capability`
sum, `ExtPorts` rows, `ExtEntry`), `ext/runtime.ail`'s digest, `journal.ail` (refusal catalogue,
`header_of_entry`, `resume_refusal`, the unknown-type fold test), `session.ail` (`c2_state_from_continuation`,
`is_missing_infrastructure`), `step_machine.ail`'s cost gate, `ports.ail`'s `ToolOutcome`,
`dst_interaction.ail` and `dst_program.ail`'s version rules, ADR-003 D3/D4/D5/D6, ADR-004 D5. Host
side: `session-journal.ts` (`append`, `adopt`, `writeHeader`, the schema constant),
`session-logger.ts:396-412`, `runtime-process.ts`'s wake reply path. Tooling:
`tools/ext_ambient_inventory/hook_scope.py` in the sections that decide binding resolution and the
walk, `derive.py`'s `installable_extensions`, `run_declared_vs_performed.sh`'s limitation rows and
exit logic, and the `Makefile`'s target lists. I read every `register_with_config` in
`packages/*/register.ail` and every delegated `make_hooks` body.

Thirty-six compiler probes were run entirely in a scratch directory outside the repository
(`…/scratchpad/adr001-v04-probes`): the third review's 21, reproduced byte-for-byte from its
appendix, and 15 new ones. All 21 reproduced with identical check and run exit codes and identical
diagnostics — **0 mismatches** — independently confirming the drafter's re-run. Sources and captured
output for the new probes are in Appendix A.2. Successful probes were run with explicit capabilities;
the only effect any exploit performs is harmless stdout output. The `PureCtx`/`FsCtx` types are
reduced structural analogues, as in the third review; they are not ABI 8.0.

**Not done.** I did not run `make declared_vs_performed`, `make ext_hook_scope`, or any other project
target: `run_declared_vs_performed.sh` writes and deletes mutant probes inside `scripts/dst/`, which
the read-only rule forbids, and several targets generate files. My claims about that script are from
reading it, not from running it. I did not build any package against a hypothetical ABI 8.0, so N32's
count is a source-level classification of binding *forms* against the rule as worded, not a
compilation result. I did not re-verify the first review's source-inventory counts, attempt any
provider call, or check the external SDK and registry sources again — the third review's checks there
stand and I had nothing to add. I did not read `session.ail`, `ports.ail` or `journal.ail`
line-for-line; I read the named sections and the paths they depend on. Whether `hook_scope.py` would
in fact reject N31's escape is a reading of its walk, not a measurement: I did not run the tool.

No subagents were used. No commits were made. No Herdr command was invoked; pane `w3:p1` and
`/workspaces/motoko_agent-eval` were not touched. The sole repository file written by this review is
this one; probe sources and captured output live outside the repository.

## Appendix A. Compiler probes and exact results

Scratch root outside the repository. `ailang.toml` and `repro/types.ail` are byte-identical to the
third review's Appendix A, so the two suites are directly comparable. Commands:

```sh
ailang check repro/<case>.ail
# only after a successful check:
ailang run --caps IO      --entry main repro/<pure-case>.ail
ailang run --caps IO,FS   --entry main repro/<fs-case>.ail
```

### A.1 Reproduction of the third review's 21 probes

| Case | Expected (3rd review) | Observed check | Observed run | Match |
|---|---|---:|---:|:--:|
| `clean` | 0 / 0 | 0 | 0 | ✓ |
| `direct` | 1 / — | 1 | — | ✓ |
| `named` | 1 / — | 1 | — | ✓ |
| `captured` | 1 / — | 1 | — | ✓ |
| `localrecord` | 1 / — | 1 | — | ✓ |
| `missingport` | 0 / 1 | 0 | 1 | ✓ |
| `helper` | 1 / — | 1 | — | ✓ |
| `capturednamed` | 1 / — | 1 | — | ✓ |
| `capturedannot` | 1 / — | 1 | — | ✓ |
| `missingnamed` | 1 / — | 1 | — | ✓ |
| `missingannot` | 0 / 1 | 0 | 1 | ✓ |
| `missingworld` | 1 / — | 1 | — | ✓ |
| `localunannot` | 1 / — | 1 | — | ✓ |
| `localannot` | 1 / — | 1 | — | ✓ |
| `fs_missing` | 0 / 1 | 0 | 1 | ✓ |
| `fs_smuggle` | 0 / 0 (IO performed) | 0 | 0 (IO performed) | ✓ |
| `fs_direct` | 1 / — | 1 | — | ✓ |
| `fs_named` | 1 / — | 1 | — | ✓ |
| `fs_direct_io` | 1 / — | 1 | — | ✓ |
| `fs_named_io` | 1 / — | 1 | — | ✓ |
| `fs_smuggle_norow` | 1 / — | 1 | — | ✓ |

**21 of 21 match; 0 mismatches.** Diagnostics were compared too and are identical, including the
column offsets. The drafter's re-run claim is confirmed.

### A.2 New probes (Q-1)

`—` means not run, because the check failed.

| Case | Shape | Check | Run | Result |
|---|---|---:|---:|---|
| `n_pure_passthru_captured` | pass-through lambda → named fn, **captured local-typed record** | 0 | 0 | **ESCAPE: ambient IO from `PureCtx`** |
| `n_dec_prepare_escape` | same, at D2's `(PureCtx, candidate) -> Prep` arity | 0 | 0 | **ESCAPE: candidate text exfiltrated** |
| `n_fs_passthru_captured2` | same, `FsCtx`, enclosing `! {IO, FS}` | 0 | 0 | **ESCAPE: out-of-row IO from `FsCtx`** |
| `n_pure_passthru_norow` | as above, enclosing row dropped | 1 | — | rejected (enclosing row is the precondition) |
| `n_pure_passthru_unannot` | as above, stored lambda unannotated | 1 | — | rejected (the `! {}` annotation is the precondition) |
| `n_pure_passthru_xmod` | as above, record type **imported** | 1 | — | rejected (local record type is the precondition) |
| `n_pure_named_localsmuggle` | **named** fn builds the record in its own body | 1 | — | rejected |
| `n_fs_named_localsmuggle` | same, `FsCtx` | 1 | — | rejected |
| `n_fs_named_indirect` | named fn calls a named `! {IO}` maker | 1 | — | rejected |
| `n_pure_named_applier` | named fn applies a named maker's record | 1 | — | rejected |
| `n_pure_passthru_capturedfn` | pass-through, captured **bare function value** | 1 | — | rejected |
| `n_fs_passthru_capturedfn` | same, `FsCtx` | 1 | — | rejected |
| `n_fs_passthru_captured` | `FsCtx` escape, enclosing row `! {IO}` only | 1 | — | rejected (needs `FS` in the enclosing row) |
| `n_fs_passthru_mkcaptured` | record from a named `! {IO}` maker, enclosing `! {IO}` | 1 | — | rejected (same reason) |
| `n_fs_passthru_clean` | control: pass-through + captured **string** | 1 | — | rejected (enclosing row needs `FS`; no smuggle) |

The three escapes and the six most informative rejections follow in full.

#### Probe 22: `n_pure_passthru_captured` — the escape

```ailang
module repro/n_pure_passthru_captured
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }
func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 0:

```text
→ Type checking repro/n_pure_passthru_captured.ail...
→ Effect checking...

✓ No errors found!
```

`ailang run --caps IO` exit 0:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/n_pure_passthru_captured.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

The line `EFFECT WITH NO PORTS OR WORLD` is printed from inside the registered `PureCtx` callback.
Compare probe 14 `localannot`, which is the same record literal in the same enclosing `! {IO}`
function and is **rejected** — the only difference is that `localannot` passes `w.f` straight to the
constructor while this passes `w` through a named function first.

#### Probe 23: `n_dec_prepare_escape` — the escape at D2's real arity

```ailang
module repro/n_dec_prepare_escape
import std/io (println)
import repro/types (PureCtx)
type Prep = Immediate(int) | Query(int)
type Judge = DJ((PureCtx, string) -> Prep)
type W = { f: (PureCtx, string) -> Prep }
func run_prepare(ctx: PureCtx, cand: string, w: W) -> Prep { w.f(ctx, cand) }
func build() -> Judge ! {IO} {
  let w: W = { f: func(c: PureCtx, cand: string) -> Prep ! {} { let _ = println("EXFIL candidate=${cand} name=${c.name}"); Immediate(1) } };
  DJ(func(ctx: PureCtx, cand: string) -> Prep { run_prepare(ctx, cand, w) })
}
func invoke(j: Judge, ctx: PureCtx, cand: string) -> Prep { match j { DJ(f) => f(ctx, cand) } }
export func main() -> () ! {IO} {
  let r = invoke(build(), {name: "pure-ctx"}, "secret candidate text");
  match r { Immediate(n) => println("result=${show(n)}"), Query(n) => println("q=${show(n)}") }
}
```

`ailang check` exit 0: `✓ No errors found!`

`ailang run --caps IO` exit 0:

```text
✓ Running repro/n_dec_prepare_escape.ail
EXFIL candidate=secret candidate text name=pure-ctx
result=1
```

#### Probe 24: `n_fs_passthru_captured2` — the escape from a narrow view

```ailang
module repro/n_fs_passthru_captured2
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func apply(ctx: FsCtx, w: W) -> int ! {FS} { w.f(ctx) }
func build() -> FsSlot ! {IO, FS} { let w: W = { f: func(c: FsCtx) -> int ! {FS} { let _ = println(c.name); 1 } }; Fs(func(ctx: FsCtx) -> int ! {FS} { apply(ctx, w) }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 0: `✓ No errors found!`

`ailang run --caps IO,FS` exit 0:

```text
✓ Running repro/n_fs_passthru_captured2.ail
IO OUTSIDE FS VIEW
result=1
```

#### Probe 25: `n_pure_passthru_norow` — the enclosing row is a precondition

Identical to probe 22 with `func build() -> Slot` in place of `func build() -> Slot ! {IO}`.
`ailang check` exit 1:

```text
Error: effect checking failed in repro/n_pure_passthru_norow: Effect checking failed for function 'build'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func build(...) -> T
  Suggested fix:     func build(...) -> T ! {IO}
```

#### Probe 26: `n_pure_passthru_unannot` — the `! {}` annotation is a precondition

Identical to probe 22 with the stored lambda written `func(c: PureCtx) -> int { … }`.
`ailang check` exit 1, same diagnostic shape as probe 25 (`build` missing `IO`).

#### Probe 27: `n_pure_passthru_xmod` — an imported record type closes it

```ailang
module repro/helpers
import repro/types (PureCtx)
export type W = { f: (PureCtx) -> int }
export func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }
```

```ailang
module repro/n_pure_passthru_xmod
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
import repro/helpers (W, apply)
func build() -> Slot { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1 — and note it is caught at the `let`, not at the application:

```text
Error: type error in repro/n_pure_passthru_xmod (decl 0): type unification failed at [let annotation w at repro/n_pure_passthru_xmod.ail:5:24]: failed to unify record field 'f': failed to unify effect rows: incompatible closed rows: r1 has extra labels [IO], r2 has extra labels []
```

#### Probe 28: `n_pure_named_localsmuggle` — the named arm holds

```ailang
module repro/n_pure_named_localsmuggle
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func body(ctx: PureCtx) -> int { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; w.f(ctx) }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
Error: type error in repro/n_pure_named_localsmuggle (decl 1): type unification failed at [function application at repro/n_pure_named_localsmuggle.ail:6:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 29: `n_fs_named_localsmuggle` — the named arm holds in a narrow view

```ailang
module repro/n_fs_named_localsmuggle
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func body(ctx: FsCtx) -> int ! {FS} { let w: W = { f: func(c: FsCtx) -> int ! {FS} { let _ = println(c.name); 1 } }; w.f(ctx) }
func build() -> FsSlot { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 1:

```text
Error: effect checking failed in repro/n_fs_named_localsmuggle: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T ! {FS}
  Suggested fix:     func body(...) -> T ! {FS, IO}
```

#### Probe 30: `n_fs_named_indirect` — a named maker does not help either

```ailang
module repro/n_fs_named_indirect
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func mk() -> W ! {IO} { { f: func(c: FsCtx) -> int ! {FS} { let _ = println(c.name); 1 } } }
func body(ctx: FsCtx) -> int ! {FS} { let w = mk(); w.f(ctx) }
func build() -> FsSlot { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 1, `body` missing `IO`, same diagnostic shape as probe 29.

#### Probe 31: `n_pure_passthru_capturedfn` — a captured bare function does not escape

```ailang
module repro/n_pure_passthru_capturedfn
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func apply(ctx: PureCtx, g: (PureCtx) -> int) -> int { g(ctx) }
func build() -> Slot ! {IO} { let g = func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 }; Pure(func(ctx: PureCtx) -> int { apply(ctx, g) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
Error: type error in repro/n_pure_passthru_capturedfn (decl 1): type unification failed at [function application at repro/n_pure_passthru_capturedfn.ail:5:104]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

So the escape is specific to a **record field** as the carrier, which is the 017 hole — but reached
from the rowless slot, through the one intervening named call the discipline permits.

## Provenance and final integrity check

- **Model:** `claude-opus-5`, as this session reports it. Self-report, not a backend attestation. No
  model override, no delegated reviewer, no subagents.
- **Reasoning effort:** not exposed in this session's reportable metadata; I do not infer one.
- **Branch / HEAD:** `arniwesth/031-abi-8-0` / `2f3ee4d1e83feb677583924131ce08f7cb91b47a`.
- **ADR SHA-256 before reading:** `0e8b0c05aaac4e1a7c2c4ffe4e1c60ce772d2b9afabee1c1f99868d19d490758`.
- **ADR SHA-256 after writing this review:** `0e8b0c05aaac4e1a7c2c4ffe4e1c60ce772d2b9afabee1c1f99868d19d490758` — **unchanged**; the reviewed working-tree v0.4 was stable throughout.
- **Repository write:** `.agent/projects/031_system_one_decisions/REVIEW-adr001-v0.4-verdicts-claude-opus-5.md`
  only. No commit. Probe sources and captured output are outside the repository.
