# Review: ADR-001 Extension-owned structured decisions (v0.7)

Reviewer: Claude Fable 5.1 (`claude-fable-5-1`), seventh review, full and independent, 2026-09-20. **Same model as
the drafter of v0.3–v0.7, different session:** this session has none of the drafter's context, asked for none, and
its evidence is its own — every probe re-run from the sixth review's printed sources, eleven new probes built, the
tool's `Scope` class driven on fixtures and on the real tree rather than read. Independence here is of session and
of evidence, not of model, as the brief requires me to say. Neither the sixth reviewer (Codex `gpt-6-astra`) nor
the fourth (Claude Opus 5). This reviews the **working-tree v0.7**, not the v0.2 at HEAD. Branch
`arniwesth/031-abi-8-0`; HEAD `2f3ee4d1`; ABI `7.4`; AILANG `v0.33.0`, commit `ae36986`. The reviewed file has
1107 lines and SHA-256 `45378ccd835f1aedaed38f4ba56aa62b02a691af0763b8da79ccc821378abd06`, matching the handoff.
`git diff --stat 2062605 HEAD` over `src/core`, `packages`, `tools`, `scripts` and the `Makefile` is empty. Final
provenance and the post-write SHA check are below the appendix.

## 1. Architectural verdict and freeze readiness

**Retain the architecture; do not freeze v0.7.** Everything the six earlier reviews accepted stands, and v0.7 is
the first revision whose boundary text I could not break as a *rule*. The sixth review's 45 compiler cases reproduce
(**0 mismatches**, Appendix A.2). I then attacked the v0.7 shape rule with eleven further constructions (A.3): a
payload bound to a **parameter** that shadows a top-level function, a **delegated callee that is a parameter**
shadowing a top-level function, a local `let make_hooks` over an **imported** `make_hooks`, a local `func ToolPolicy`
over the constructor, an import that shadows a same-module declaration, a module-level `let` lambda, a `match` that
selects between lists, a delegated shadow behind the `{ config, caps }` record, a destructuring `let`, and the
`(Json) -> [ToolSchema]` shape itself. Four of these escape the bare compiler; every one of the four is rejected by
the rule *as v0.7 writes it*. Two constructions I expected to escape do not: the compiler resolves `ToolPolicy(…)` to
the constructor even when a same-named local function exists, and it resolves an **imported** name over a local
`let` and over a same-module declaration (`result=2` in both probes). The last fact matters: it is not the scoping
order v0.7 asserts, and the rule over-rejects there — the safe direction, but a direction the suite must score.

The eight v0.7 decisions resolve as follows: **N49, N55, N56 resolved; N52 and N54 resolved as criteria; N51
resolved as a rule and not yet as an implementation; N50 and N53 partial.** The reason v0.7 is not freeze-ready is
smaller than the last three rounds' but still a decision, not a wording:

1. **The narrowed channel claim leans on a detector that does not detect (N57).** D2 now says a `question_config`
   violation — a question dependency placed in general configuration — "is a conformance failure that strict query
   replay detects". It is not. D6 and ADR-004 D1 record the configuration bytes per epoch and serve them at replay,
   so a re-executed `prepare` reproduces the recorded request under the changed general configuration; nothing
   compares a prepared request across the epoch boundary, and the live `Descriptor` row is designed not to fire.
   The classification the sixth review asked for therefore rests on a mechanism that is not in the ADR.
2. **The waiver transition is two sentences short (N59, N60).** An orphan acknowledgment is never retired, so an
   identity that is acknowledged, reappears, accrues new liabilities and is removed again is silently accepted, and
   a fresh identity then mints at its configured allowance — the exact path the row exists to stop. And the
   migration entry moves "retained state", which D6 defines as used interventions, spend and reservations, into a
   destination that "must be inactive-registered"; nothing says the allowance or the effective limit moves or that
   migration activates, so as written a migrated atom stays inactive and the pinned case "or a migration entry" does
   not restore operation.

Beyond those: constructor **data positions** (`ToolProvider`'s names, `ExitIntent`'s label and captured `enabled`,
`WorkInFlight`'s label) are registration-time state outside the config digest and the kind-only `ext_set_digest`
alike (N58); at a forced resume the "register each new identity inactive" rule and the "first registration at
configured allowance" rule both claim an unrelated new identity, and "records nothing else" contradicts the
descriptor the snapshot must carry (N61); the rule's stated resolution order is measured wrong for imports (N62);
the four tool edits D2 and D7 list cannot reach parameters, module scope or a result field of the shape result's
own (N63); D4's dispatch diagram still puts admission and reservation in the calling core module (N64); and the
inline-lambda row's breakdown sums to 17 against its own count of 19 (N65).

**Nine new findings, N57–N65.** Missing implementation evidence (freeze items 1–3) is identified separately and is
not counted, as in every review since the third. Findings per round: 13, 9, 8, 10, 8, 8, 9. Four of the nine
(N61, N62, N64, N65) are one-sentence corrections; N63 is an implementation-completeness note the plan would have
hit; the decisions are N57, N59 and N60, with N58 a digest-composition rule.

## 2. Remaining blockers

| Blocker | Decision or evidence needed | References |
|---|---|---|
| **The channel's violation classification names a non-detector: N57** | Either give the violation a detector — on a config-epoch change at resume, the host re-runs `prepare` on the last recorded invocation's evidence snapshot with the new `ext_config` and refuses (or forces) when the canonical request differs while the question digest is unchanged — or take the restricted question-only view v0.7 declined, or state that the obligation is a reviewed discipline with no mechanical check and withdraw "strict query replay detects". | D2:345-361; D6:724-737; ADR-004 D1 |
| **Acknowledgment is never retired: N60** | An acknowledgment is retired when the acknowledged identity reappears (its ledger resumes and it is once again subject to the orphan predicate), or it records the liability totals it acknowledged and the predicate fires again when they differ. Add the case to the pinned list. | D6:788-818 |
| **Migration does not activate and carries no allowance: N59** | State that the migration entry carries the source identity's allowance and effective limit and activates the destination, or that it requires a subsequent grant; state what a grant to an active identity does to D5's "fixed for that session identity", and whether a grant may name an absent identity. | D5:637-648; D6:799-803, 811-813; D7 "Other records" |
| **Constructor data positions are outside every digest: N58** | Hash the data positions of `caps` (names, labels, `enabled`) into the per-epoch config digest, or require them to be derived from `config`; say which resume row sees a change to them. | D2:335-343, 363-369; `runtime.ail:1113-1151`; `types.ail:1263,1273` |
| **Evidence 1–3 still not supplied** | Unchanged from the third through sixth reviews: accepted signatures; compiled ABI-8 examples of both consumers registered as named functions reading `ext_config`, plus the configured-versus-empty `DescribeTools` consumer; the executable shape gate red on the fixtures and green on a migrated tree; strict-mismatch and offline-experiment evidence. | Freeze 1–3 |

N61–N65 are corrections to text and to the D7 tooling row; they do not block on their own but N62 and N63 change
what freeze item 8's gate must be built from.

## 3. New findings (N57 onward)

### N57. "Strict query replay detects a violation" is false: nothing in v0.7 detects a question dependency placed in general configuration

**Evidence.** D2:352-358: "every configuration value that influences evidence selection or question construction
must be represented in `question_config` … Strict query replay detects a violation — the prepared request differs
from the record — and the live `Descriptor` row does not; a general-config change that alters a question is
classified as a conformance violation surfaced by replay, not as a refused resume." Three facts from the ADR's own
text make the detection sentence untrue:

1. Strict replay re-executes the program against the **record** and serves recorded configuration inputs; D6:731-737
   makes the binding table, limits and effective configuration "recorded configuration inputs of the program in
   ADR-004 D1's sense … read from the record, never from ambient configuration", and D2:341-343 records the
   configuration "as bytes or a resolvable reference (ADR-004 D1), not only as a digest". D2:363-369 records the
   config digest **per policy epoch**. So when a general-config change is accepted on resume (an epoch is appended),
   the new bytes are what the record holds from that epoch on. A strict replay of that run re-executes `prepare`
   with those bytes and reproduces the recorded request. There is no mismatch to detect.
2. The only cross-epoch comparison the ADR defines is the `Descriptor` row, which compares the question version and
   config digest (D6:753-769); v0.7's whole point is that a general-config change does not touch that digest. The
   row is designed not to fire.
3. The dependency is expressible: the sixth review's `config_projection` re-runs here (A.2) and prints
   `question A` then `question B` for identical descriptor projections and a changed `ext_config`.

**Consequence.** The sixth review's N50 asked for one of three things: narrow the claim, retain the obligation with
a detector, or restrict `prepare`'s view. v0.7 narrowed the claim (correctly), retained the obligation (correctly),
declined the restricted view because "replay already detects" the gap — and replay does not. The classification
"conformance violation surfaced by replay" therefore names an event that never occurs. In practice a live operator
who edits a general-config value that the guard's `prepare` reads will change the questions asked, the resume will
append an epoch and continue, every subsequent query will be recorded and replayed faithfully, and no artifact in
the ADR's evidence set will ever say the questions changed under an unchanged `question_config` digest. Freeze
item 3 ("strict query and policy mismatches fail") cannot be demonstrated for this case because no mismatch arises.

**Decision needed.** One of: (i) a **dry prepare at the epoch boundary** — when a resume accepts a config-digest
change for an extension with decision atoms, the host re-runs `prepare` on the last recorded invocation's evidence
snapshot (recorded under D3/D6) with the new `ext_config` and the unchanged descriptor projections, and refuses
the resume (`--resume-force` overrides, epoch appended with the violation recorded) when the canonical request
differs; this is small, needs no new context type, and turns the obligation into something a fixture can show;
(ii) the restricted question-only view for `prepare`, which makes the violation unwritable at the cost of a seventh
context type; or (iii) keep the obligation as a reviewed discipline and say plainly that no mechanism in this ADR
detects it. Whichever is chosen, delete "strict query replay detects a violation" and add the chosen case to freeze
item 3.

### N58. Registration-time state in constructor data positions is outside both digests

**Evidence.** Three constructors carry data beside their callback: `ToolProvider([string], handle)`,
`ExitIntent(string, bool, render)` and `WorkInFlight(string, render)` (`types.ail:1244-1273`). The data is computed
at registration from the environment: herdr's `tools` is `if gate_open then tool_names() else []` and its
`ExitIntent` flag is `cfg.reap_on_exit || cfg.settle_on_exit`, both from `getEnvOr` (`herdr/register.ail`,
`herdr.ail:2032-2058`); ailang-docs' and omnigraph's tool lists are gated on a registration-time workdir check. The
ABI header itself says the `enabled` flag is "the operator opt-in RESOLVED AND CAPTURED AT REGISTRATION"
(`types.ail:1256-1262`). The host acts on these values without invoking any callback: the catalog advertises the
names (`tool_catalog.ail:113-118`), the exit machinery publishes an empty action list when `enabled` is false.

None of this is hashed. `ext_set_digest` covers `id` and capability **kinds** only (`runtime.ail:1113-1151`); the
config digest covers `ExtRegistration.config` (D2:335-343); the `Prompt` row covers the system prefix; the
`Descriptor` row covers decision atoms. The sixth review's Q-1 said so in terms — "constructor data such as provider
tool names, exit-intent IDs/enabled flags and work labels remain data arguments and must also participate in the
relevant registration/policy records" — and v0.7 contains no sentence on constructor data (I searched D2, D6 and D7
for "data argument", "names", "enabled", "label").

**Consequence.** The narrowed claim at D2:345-347 — "a named callback can read no registration-time state that was
not returned through [the channel]" — is literally true, since a callback does not read its own constructor's data
arguments. But "disclosure becomes a fact" (the N41 row) is not: an operator can flip `HERDR_REAP_ON_EXIT`, or a
workdir check can change which tools an extension advertises, between two runs of one session, and no resume row
and no recorded digest shows it. For a `ToolProvider` the change alters the tool catalog the model sees, which
ADR-004 D1 treats as a configuration input of the program.

**Decision needed.** Fold the data positions of every atom into the per-epoch config digest — they are all
`Json`-representable (strings, a bool, string lists), the host already has the list, and the kind enumeration
`capability_kind` (`runtime.ail:1139-1151`) is where the data would be projected — and record them beside `config`
in the epoch snapshot. State that a change to them on resume is the same event as a config-digest change (append
and continue, D2:363-369). Alternatively require each data argument to be derivable from `config` and say the host
checks it; that is a conformance rule a fixture cannot enforce, so the digest is the better answer.

### N59. The migration entry's effect on allowance, limit and activation is unspecified; as written a migrated identity stays inactive

**Evidence.** D6:799-803 defines the migration entry as "old identity → new identity; the retained state,
interventions included, moves once; the old identity is closed; the destination must be inactive-registered; a
second move is refused". "Retained state" is defined three times in D6 (`:777-779`, `:790-791`, `:784-786`) as
**used interventions, known spend, and outstanding reservations**. Inactive registration is "zero allowance *and*
interventions disabled" (`:794-797`). Nothing in D6 or the D7 "Other records" row says that a migration carries the
source identity's allowance or its effective intervention limit, or that it activates the destination; only the
grant "activates the identity" (`:801-803`). Yet the pinned case at `:811-813` reads "then by a grant (activated at
the granted money and interventions) or a migration entry (retained state moves once)" — the "or" presents
migration as an alternative that restores the atom.

Separately, D5:640-642: "the effective intervention limit is the lower of operator and descriptor limits, fixed for
that session identity", and `:646-647`: "An extension cannot raise or reset its counter". A grant "sets money and the
intervention limit separately" (`:801-803`). Applied to an **active** identity that is a change to a limit the ADR
calls fixed; applied to an **absent** (acknowledged) identity it activates nothing. Neither case is addressed.

**Consequence.** Under the literal text, the ordinary rename-and-migrate path leaves the extension unable to query
or intervene until an operator grant follows, which makes the migration entry redundant with the grant and the
pinned case wrong. Under the charitable reading (migration carries everything and activates), the text is missing
the sentence that says so. The Q-2 question — "are the three entries sufficient and non-duplicating" — is answered
"not as written" by this alone.

**Decision needed.** State that the migration entry moves the source identity's **allowance and effective limit
together with its retained state**, closes the source, and activates the destination, so that after migration the
atom continues exactly where it was; that a grant to an active identity is an operator-recorded change of the
operator limit (permitted, recorded as an epoch entry) or is refused — pick one and reconcile D5's "fixed"; and
that a grant naming an identity the registry does not contain is refused. Add "grant to an active identity" and
"grant to an absent identity" to the pinned list.

### N60. An orphan acknowledgment is never retired, so a second orphaning of the same identity is silently accepted

**Evidence.** D6:789-793: the forced snapshot "records an orphan acknowledgment for each orphaned identity: its
liabilities … stay retained under the old identity, but an acknowledged orphan no longer satisfies the `Identity`
predicate, so the next ordinary resume does not refuse again". D6:803-804: "A later reappearance or rollback of an
acknowledged identity resumes its retained ledger and mints nothing." Nothing says the acknowledgment ends when the
identity reappears, and D6's comparison is against the effective epoch, into which the acknowledgment is folded.

Walk it. `guard#0/finalize/g` has one used intervention. It is removed; the ordinary resume refuses (`Identity`);
the operator forces; the snapshot acknowledges `guard#0`. Later the operator rolls back: `guard#0` reappears,
"resumes its retained ledger and mints nothing" — correct. It runs, spends money, uses its second intervention. It is
removed again, and this time a new `guard#1` (or a reordered `guard#2`) appears. At the **ordinary** resume the
predicate asks: does the ledger hold retained state for an identity the registry lacks that is *not acknowledged*?
`guard#0` is absent, holds state, and is acknowledged — from the earlier epoch. No refusal. The new identity
"orphans nothing" and is a first registration at its configured allowance (D6:771-776).

**Consequence.** After one forced waiver an identity can be orphaned again without refusal, and its replacement
mints. That is the path N36 and N46 closed and N53 was meant to finish. The window is narrow — it needs a rollback
between two removals — but the rollback case is one D6 pins as ordinary, and a positional identity makes "removal"
as cheap as inserting an extension earlier in the list.

**Decision needed.** Either retire the acknowledgment when the acknowledged identity is registered again (the
reappearance entry clears it, so the identity is once more subject to the predicate), or make the acknowledgment
record the liability totals it acknowledged and have the predicate fire when the retained totals differ from the
acknowledged ones. The first is simpler and matches "resumes its retained ledger". Pin "acknowledged → reappears →
accrues → removed again" as a refusing case.

### N61. At a forced resume two rules claim an unrelated new identity, and "records nothing else" contradicts the descriptor the snapshot must carry

**Evidence.** D6:794-797: the waiver "registers each new identity **inactive**". D6:771-776 and D5:644-647: an
identity "that orphans nothing is a first registration: the resume records it in a policy snapshot at its
configured allowance". A forced `Identity` resume that also, in the same profile change, adds a decision extension
unrelated to the orphan introduces an identity that satisfies both descriptions. D6 does not say which wins. And
D6:797-798, "(3) It records nothing else: no allowance is recomputed, nothing is manufactured", is stricter than the
snapshot can be: the new identity's descriptor (question and interpretation digests, declared limit) must enter the
epoch or the next `Descriptor` comparison has nothing to compare against (D6:753-769).

**Consequence.** An implementer reading (2) literally makes every identity introduced at a forced resume inactive,
including one that would have been a first registration on an ordinary resume — safe, but a surprise the operator
must then repair with a grant; one reading (2) narrowly must decide which new identities "replace" the orphan,
which is exactly what the ADR says the host cannot know (that is why migration is explicit). "Records nothing else"
read literally forbids recording the descriptor.

**Decision needed.** Say that at a waived `Identity` resume **every** identity the effective epoch does not hold is
registered inactive — the host cannot tell a replacement from a coincidence, and the grant is the recorded way to
say so — and that the first-registration rule applies to ordinary resumes and to forced resumes that waive only
`ExtSet` or `Prompt`. Reword (3) to "records the new identities' descriptors and nothing else".

### N62. The rule's stated resolution order is not the pinned compiler's for imported names, and the fixture list lacks the cases that show it

**Evidence.** D2:193-197: "Resolution is lexical at **every hop**: a delegated callee is looked up in the calling
body's locals and parameters *before* the module's declarations, so a local `let make_hooks` over a top-level
`make_hooks` is a rejection (fact 6), exactly as a local `let body` over a top-level `body` is (fact 5)." Measured on
v0.33.0 (Appendix A.3):

| Probe | Construction | Check | Run | Which function ran |
|---|---|---|---|---|
| `v7_import_shadow` | `import repro/v7_other (body)` **and** a same-module `func body`; `[ToolPolicy(body)]` | 0 | 0 | the **import** (`result=2`) |
| `v7_delegate_import_shadow` | `import repro/v7_mkmod (make_hooks)` **and** a local `let make_hooks = <escaping list>`; tail `make_hooks(0)` | 0 | 0 | the **import** (`result=2`, no effect printed) |
| `delegate_shadow` (sixth review) | local `let make_hooks` over a same-module `func make_hooks` | 0 | 0 | the **local** (effect printed) |
| `q_named_shadow` (fifth review) | local `let body` over a same-module `func body` | 0 | 0 | the **local** (effect printed) |

So the pinned compiler's order is **import, then local `let`, then module declaration** — an imported name outranks
a local of the same name in the calling body. The rule as v0.7 writes it would reject `v7_delegate_import_shadow`
as a shadowed delegation; the compiler runs the clean imported function. That is an over-rejection, the safe
direction, and the tool's `_resolve_func` (imports first, `:763-773`) happens to agree with the compiler. But freeze
item 2(b) scores the suite in three groups, and this construction belongs to none of them: it is accepted by the
compiler, performs nothing, and is rejected by the boundary. A suite that lists it among the escapes would be wrong
about the compiler; one that lists it among the controls would be wrong about the boundary.

Two escapes the rule text does cover but the fixture list at D2:243-246 names only half of:

| Probe | Construction | Check | Run | Tool today (A.4) |
|---|---|---|---|---|
| `v7_param_shadow` | `func make_hooks(body: (Ctx) -> int) -> [Capability] { [ToolPolicy(body)] }` with a top-level `func body`; the registration passes the escaping lambda | 0 | 0, **effect performed** | `HOOK-PORT-MEDIATED`, binding classified named |
| `v7_delegate_param` | `func build_with(mk: (int) -> [Capability]) { mk(0) }` with a top-level `func mk`; the registration passes a lambda returning the escaping list | 0 | 0, **effect performed** | `HOOK-PORT-MEDIATED`, two hops followed, binding classified named |

The fixture list has "a parameter binding" (the first). It does not have the delegated-parameter case, which is the
one where the tool follows the *wrong list* two hops deep.

**Consequence.** "In AILANG's scoping order" (D2:187) is asserted, not measured, and for imports it is wrong. The
rule stays sound because every measured divergence is in the over-rejecting direction; but the suite's expected
results are part of freeze item 2(b), and an import-shadow row must be scored as "compiler accepts, boundary
rejects, no effect performed" — a fourth class or an explicit note — rather than forced into the three groups.

**Decision needed.** Replace "in AILANG's scoping order" with the measured order, or with "lexical at every hop,
which is stricter than the compiler's import precedence and over-rejects the import-shadow case by design". Add
`v7_import_shadow` and `v7_delegate_import_shadow` to the suite as boundary-rejected compiler-clean controls, and
`v7_delegate_param` to the escape group and to the gate's fixture list.

### N63. The four tool edits v0.7 lists cannot implement the parameter half, the module-scope half, or a shape result distinct from the walk

**Evidence.** D2:199-203 and the D7 tooling row (`:852`) name the edits: `Scope.locate` keeps scope provenance per
hop, `_binding_text` consults `let`s first, `verdict`/`emit_hook_scope` gain the total shape result and a nonzero
exit. Three things the rule needs are not reachable from those functions as the file stands:

1. **Parameters are never read.** `func_body` (`:371`) and `_body_at` (`:415`) return the brace body *after* the
   signature; `_resolve_func` (`:763`) returns `(module, body)` with the parameter list already discarded;
   `producing_locals` is `let_bindings(self.producing_body)` alone (`:666`); `_param_names` (`:955-975`) is
   documented "best effort" and reads only lambda parameter lists inside body text. `v7_param_shadow` and
   `v7_delegate_param` are certified named for exactly this reason (A.4). The rule's "parameter-bound in the
   producing body or in any delegated body" needs the signature retained per hop, which is a change to `func_body`
   or a sibling, not to `locate`.
2. **Declarations are closure-wide, keyed by bare name.** `self.declared` is built over every module in the closure
   (`:557-558`) and `_resolve_func` returns the first module whose text holds a `func <name>` (`:773-777`). A
   fixture with a clean `body` in `register.ail` and an effectful `body` in another closure module resolves the
   binding to the **other** module (`fx_xmod_collision`, A.4: `HOOK-AMBIENT`). That is an over-rejection today, but
   "resolves to a top-level `func` declaration *of the module*" (D2:191-192) is not what the table implements, and
   after the import-precedence fact (N62) the correct order is imports of the home module, then declarations of the
   home module, never another module's.
3. **`hook-binding-unresolvable` is also a walk shape.** The walk emits it for an imported callee that resolves to
   no declaration in the closure (`:882-886`); on the real tree under a package-local closure it fires for
   ailang-docs, exa-search, scratchpad, compaction-ai and compose (A.5). So a shape result computed as "rejections
   of shape `hook-binding-unresolvable` or `capability-list-unresolvable`" would be contaminated by walk residue in
   one direction and by `unknown-callee` in the other. v0.7 says the result must be "distinct from — and never hidden
   by — the walk's `HOOK-UNRESOLVED` residue" (`:239-241`); the D7 row does not say it is its own field with its own
   shape names, and `derive_hook_scope`'s per-extension dict (`:1049-1065`) has no such field.

**Consequence.** The implementation plan will discover all three; but freeze item 8's pass criterion is stated in
terms the listed edits cannot produce, and the gate's "green on the migrated tree" depends on (3) being a separate
field rather than a filter.

**Decision needed.** In D2 and the D7 tooling row: `func_body`/`_resolve_func` return the signature's parameter
names beside the body; `locate` records per hop `(module, parameters, lets)` and `_resolve_func` takes that chain,
rejecting a callee found in any hop's locals or parameters, then consulting the home module's imports, then the home
module's own declarations; the shape result is a new per-extension field (say `registration_shape_result: pass |
fail(reason)`) computed from `locate` and the binding pass, with its own rejection shapes, and `emit_hook_scope`
exits nonzero from that field alone. The self-test's `capability_list_atoms` and `registration_shape` pins are
re-pinned by hand for the `{ config, caps }` head, as the file's own comments require.

### N64. D4's dispatch diagram still places admission and reservation in the calling core module

**Evidence.** D4:550: "calling core module: validate/admit → reserve → advance + decision_query + witness". Under
N47 (D5:615-634) admission is evaluated by the host "when the request arrives over the wire", and the reservation
entry is a host journal entry appended before the provider call (D5:664-680). The sixth review's D4 row said this in
so many words ("update it to show local request/leaf work versus host wire admission/reservation after N47"); it
was not numbered, and v0.7's header claims "two contradictions of the drafter's own are removed (D2, D5)" while this
one remains in D4.

**Consequence.** The diagram is the one place a reader sees the whole sequence; it now contradicts D5 on who
admits and who reserves.

**Decision needed.** Redraw the arrow: "calling core module: build request → `decision_query` (wire) → host:
admit, reserve, call, observe, reply → witness successor world".

### N65. The inline-lambda row's breakdown sums to 17 against its own count of 19

**Evidence.** D2:256: "Inline lambda | 19 | test-dummy ×4, herdr ×2, progress-contract-guard, four `DescribeTools`
forms, six `PromptShaper`/`Compactor`/`ToolProvider`/`ToolPolicy` forms" — 4 + 2 + 1 + 4 + 6 = 17. The measured set
(A.5, 19 inline bindings, agreeing with the fifth and sixth reviews) has **eight** in the last group: ailang-docs
`PromptShaper`, compaction-ai `Compactor`, compose `ToolPolicy`, context-mode, exa-search, omnigraph and scratchpad
`PromptShaper`, omnigraph `ToolProvider`. The `let`-bound row (2+2+2+4+6 = 16) and the named row (10) add up.

**Consequence.** Trivial, but this row has been corrected twice (N32, N45) and is the plan's site list.

**Decision needed.** "eight", or list them.

## 4. Resolution of N49–N56

"Resolved" means a coherent decision whose stated facts hold against the tree and the pin, not that an unimplemented
feature has passed a gate.

| Item | Verdict | What I verified against |
|---|---|---|
| **N49** `DescribeTools((Json) -> [ToolSchema])` | **Resolved** | The only invocation in `src/core` is `tool_catalog.ail:110`, `f()` inside `declared_schemas`, called from `hook_schemas(e: ExtEntry)` (`:125-131`), which holds the entry — so `e.config` is one argument away and the catalog stays `pure`. `Json` is already imported by the ABI module (`types.ail:13`). Probe `v7_describe_config` (A.3): a `(Json) -> [string]` payload compiles and yields `configured=1 empty=0`, the freeze 2(c) example. The four sites' captures are data: a2a's `schemas`, agentcli's `cfg.providers`, ailang-docs' `active` bool and `schemas`, herdr's `tools` and `cfg` fields. Plan work the row should not hide: `ExtEntry` gains a field, so the generator template (`generate.py:154-165`), six core literals (`runtime.ail:829,1067-1068`; `registry_normalize.ail:264,389-391`) and `ext_fixture.ail:188` change; the no-op `DescribeTools(\_ . [])` at `runtime.ail:774,802` and `registry_normalize.ail:316` become `\_cfg . []`; `CAPABILITY_KINDS` arity is unchanged. |
| **N50** narrowed channel claim | **Partial** | The narrowed sentence (`:345-347`) is exactly true for what a callback *reads*: `PureCtx` has no `env_get`, module constants are code (`named_static_constant` re-run: `result=7`), transcript and artifacts carry their own provenance. The obligation is retained. But the detector the classification leans on does not exist (N57), and registration-time state in constructor data positions is neither returned through the channel nor hashed (N58). The cost paragraph (`:371-376`) is now an expectation with a measurement plan, which is what was asked. The restricted-view alternative is recorded as not taken — for a reason N57 removes. |
| **N51** delegation resolved at every hop | **Resolved as a rule; partial as an implementation** | The rule text rejects `delegate_shadow`, `computed_list`, `v7_param_shadow`, `v7_delegate_param`, `v7_match_list` and `v7_record_delegated` — every construction I could make the bare compiler accept. Its stated scoping order is wrong for imports (N62), in the over-rejecting direction. The edits named for `Scope.locate` and `_binding_text` cannot reach parameters or module scope (N63). |
| **N52** total registration-shape result | **Resolved as a criterion** | Well-defined against the tree: all 18 installable extensions locate today (A.5: 10 at zero hops, 8 at one), 45 bindings enumerate as 19 inline / 16 `let` / 10 named, so the criterion is red on the unmigrated tree by 35 bindings and can only go green after migration — which is what "green on the migrated tree" should mean. Computed lists fail closed today at `locate` (`fx_computed`, `fx_record`); under the v0.7 grammar `fx_record` locates and `v7_record_delegated`'s hop is a shadow. The result needs its own field (N63 item 3), and the fixture list needs the delegated-parameter case and the import-shadow control (N62). |
| **N53** orphan acknowledgment | **Partial** | P0 → forced P1 → ordinary P1 now resolves: the acknowledged orphan no longer satisfies the predicate, the inactive new identity holds no retained state, the second resume is accepted. Removal with no replacement is acknowledgment alone. But the acknowledgment persists across reappearance and lets a second orphaning through (N60). |
| **N54** inactive for money and interventions | **Resolved for the free `Immediate`** | Inactive = zero allowance and interventions disabled; skipped like an exhausted atom before any callback (D5:641-643; D6:794-797); shadow mode cannot reach it either, since the skip precedes mode. The ambiguity is which identities the rule applies to at a forced resume (N61) and whether migration activates (N59). |
| **N55** run cap at admission for every query | **Resolved** | D5:627-632 now applies `r + run_cost ≤ cap` at host admission with no site exception; the step machine's check (`step_machine.ail:112-114`) is named a second observation point; the N40 response row carries the supersession note; freeze item 5 pins "a terminal finalize-site query refused by the run cap". Consistent with `run_cost` being child-known and sent with the request (D5:617-620): after the last model call the cost is known. |
| **N56** 20 / 1 / 3 | **Resolved** | Counted against the fifth review's A.3 table: twenty rejections (`q_named_mutual` through `q_named_collision`, including the reconstructed `n_pure_named_applier`), one control (`q_dec_prepare_named_ok`), three escapes (`q_named_shadow`, `q_named_paren_apply`, `q_named_partial`). The three escapes and the sixth review's two re-run here (A.2). Freeze 2(b) scores the groups separately and says new cases are new rows. N62 adds a fourth class the text must name. |

## 5. The four questions

### Q-1. Delegation resolution: is the rule sufficient, and is it implementable?

**The rule as written is sufficient against everything I could build; the tool as it stands is not, and the rule's
claim about scoping order is measured wrong for imports.**

Re-runs first: `delegate_shadow`, `computed_list` and `registration_record` reproduce byte-for-byte from the sixth
review's printed sources (SHA-256 `9331f51e…`, `535063b7…`, `49167e7d…`), as do the other 42 (A.2, 0 mismatches).

What I tried against the rule *as written* — a construction the bare compiler accepts that the rule would classify
as a resolved, named, unshadowed payload:

| Route | Probe | Compiler | Rule as written | Tool today |
|---|---|---|---|---|
| Payload bound to a **parameter** shadowing a top-level `func body` | `v7_param_shadow` | accepts; effect performs | rejects ("parameter-bound in the producing body") | **certifies** (A.4) |
| Delegated callee is a **parameter** shadowing a top-level `func mk` | `v7_delegate_param` | accepts; effect performs | rejects ("locals and parameters before declarations", every hop) | **certifies**, two hops (A.4) |
| Local `let make_hooks` over an **imported** `make_hooks` | `v7_delegate_import_shadow` | accepts; **import runs, no effect** | rejects (shadowed local) — over-rejection | follows the import: agrees with the compiler |
| Import that shadows a same-module `func body` | `v7_import_shadow` | accepts; import runs | both are named functions; no effect possible | follows the import |
| Local `func ToolPolicy` over the un-imported constructor, real constructor via a helper module | `v7_ctor_shadow` | accepts; **constructor runs, no effect** — the local function is dead code | not addressed by the rule; not an escape | certifies, correctly by coincidence |
| Same with the constructor also imported | `v7_ctor_shadow_imported` | accepts; constructor runs, no effect | — | — |
| Module-level `let body = <lambda holding a local record>` | `v7_toplevel_let_lambda` | **rejects** (`Effect checking failed for function 'body'`) | rejects (not a `func` declaration) | rejects (`_DECL` matches `func` only) |
| `match cfg { 0 => [clean], _ => [escaping] }` as the tail | `v7_match_list` | accepts; effect performs | rejects (computed list) | rejects (`capability-list-unresolvable`) |
| `{ config, caps: make_hooks(0) }` with a local `let make_hooks` shadow | `v7_record_delegated` | accepts; effect performs | rejects (shadowed hop) | rejects the record wholesale today |
| Destructuring `let { g: body } = p` | `v7_destructure_let` | **parse error** — no such form on v0.33.0 | — | — |

Four bare-compiler escapes, all rejected by the rule text. No construction the rule certifies escapes. The two
avenues I expected to be open are closed by the compiler itself: constructor shadowing (the sixth review left it
"not claimed"; it is now measured closed) and destructuring bindings (the syntax does not exist). The one thing the
rule gets wrong is its description of the compiler: v0.33.0 resolves an imported name over a local `let` and over a
same-module declaration (N62), so "lexical at every hop, locals before declarations" is stricter than the compiler
for imports. Strictness is the right side to be wrong on, and the suite must score it that way.

**Can `Scope.locate` keep scope provenance per hop?** Yes, with more than the listed edits (N63). The loop at
`:626-663` already has `home`, `fbody`, `expr` and the hop count per iteration; it overwrites `producing_body` at
`:659`. Keeping a list of `(home, parameters, let_bindings(fbody))` per hop is a local change. What it cannot get
from the functions v0.7 names is the parameter list — `func_body` discards the signature — and module-scoped
declaration lookup — `self.declared` is closure-wide. Both are small, both are outside the four functions named.

**Is the total shape result implementable without changing the shipped closure verdict?** Yes. `_hook_scope` is a
separate mode of `derive.py` (`:840-888`); the shipped verdict comes from `derive()` in the default mode and is
returned by a different `main` branch (`:920-930`). `emit_hook_scope` can return nonzero from a new per-extension
field without touching `closure["extensions"]`. The self-test pins `closure_port_mediated` separately and asserts it
is unmoved (`:1230-1240`), which is the right guard. What must not be done is to derive the result from
`sc.rejections` shapes, because `hook-binding-unresolvable` is emitted from the walk too (N63 item 3).

### Q-2. The waiver transition

**The acknowledgment retires the predicate on the second ordinary resume; it does not retire itself. Inactive
registration closes the free `Immediate`. The three entries are neither sufficient nor fully non-duplicating.**

Every pinned case, under v0.7's rules:

| Case | Result under v0.7 | Correction |
|---|---|---|
| P0 → forced P1 → ordinary P1 | Forced snapshot: `ack(old)`, `inactive(new)`. Second resume: old is absent-with-state but acknowledged → predicate false; new holds no state → orphans nothing. **Accepted.** | — |
| Rollback to P0 (descriptor) | `Descriptor` refuses unless forced; unchanged from v0.6. | — |
| Limit change after force | `Descriptor` refuses; the effective limit stays fixed (D5:640-642). | — |
| Interpretation-only change | Epoch appended, continues. | — |
| Config-digest change, non-decision extension | Epoch appended, continues; `Prompt` still applies. | N58: data positions are outside this digest. |
| Config-digest change, decision extension | Epoch appended, continues; a question dependency in general config changes the request; nothing detects it. | **N57.** |
| First schema-2 resume of a pre-feature journal | First registrations at configured allowance; no orphan. | — |
| Additive profile switch | First registration; insertion **before** a decision extension is the reorder case (positional identity). | — |
| Reorder / removal / reinstall with retained state | `Identity` fires on the orphan. | — |
| Reorder with no retained state | Orphans nothing; no refusal. | — |
| Forced `Identity`, then a paid query | Inactive → skipped before admission; recorded skip. | — |
| Forced `Identity`, then an `Immediate` vote | Inactive → both callbacks skipped; no vote. **Closed.** | — |
| Forced `Identity`, then a grant | Sets money and limit separately; activates. | Grant to an already-active identity, and to an absent one: unspecified (N59). |
| Forced `Identity`, then a migration entry | Retained state (used, spend, outstanding) moves; source closed. **Allowance and limit do not move; destination stays inactive** as written. | **N59.** |
| Second migration | Refused. | — |
| Removal with no replacement | Acknowledgment alone; second resume accepted. | — |
| Reappearance after acknowledgment | Resumes retained ledger; mints nothing. **Acknowledgment persists.** | **N60:** a second removal is not refused; a replacement mints. |
| Reappearance of a **closed** (migrated-from) identity | Unspecified. It holds no retained state (moved), so it orphans nothing and is a first registration at configured allowance — while its liabilities live on the migrated-to identity. Not a double credit, but a second active allowance under the old name. | Say: a closed identity that reappears is registered inactive. |
| Forced `Identity` with an unrelated new decision extension in the same change | Rule (2) says inactive; the first-registration rule says configured allowance. | **N61.** |
| In-process suspension | Same retained state as a new-process resume. | — |

Duplication: a grant after a migration is redundant only if migration activates (N59 decides). A migration into an
identity that has already been granted is refused by "destination must be inactive-registered" — correct. An
acknowledgment followed by a migration is the intended sequence and is non-duplicating. The gap is not duplication
but the two missing sentences: what migration carries, and when an acknowledgment ends.

### Q-3. The narrowed channel claim and `DescribeTools`

**The sentence is exactly true; the paragraph it lives in is not. `DescribeTools(Json)` is the right shape. The
"replay detects" clause is false for every path from general configuration to a prepared request.**

- *Exactly true?* "The host stamps and hashes the registration data returned through this channel, and a named
  callback can read no registration-time state that was not returned through it" — yes for reading: a named function
  closes over nothing; a module-level `let` is effect-checked (`q_named_toplevel_apply`, `named_module_env`,
  `v7_toplevel_let_lambda` all reject); `PureCtx` has no ports and no `env_get`; module constants are code. The other
  readable inputs (transcript, artifacts, typed evidence, the two descriptor projections) are named with their own
  provenance. What the paragraph then claims about the *consequence* of that fact is where it goes wrong (N57), and
  what the host *acts on* without a callback reading it — constructor data — is outside the fact (N58).
- *The right shape against `tool_catalog.ail` and the four sites?* Yes (N49 row). `declared_schemas(caps)` becomes
  `declared_schemas(cfg, caps)` with `f(cfg)` at `:110`; the caller `hook_schemas(e)` already has the entry. Nothing
  else in `src/core` invokes the payload: the other references are the kind maps in `dst_profile_coverage.ail`, the
  `capability_kind` projection in `runtime.ail:1141`, `kind_name` in `registry_normalize.ail:155`, and five no-op
  constructions. A catalog whose schemas are fixed ignores the argument (`v7_describe_config` shows the configured and
  empty cases differ, which is freeze 2(c)'s example).
- *"A violation is a conformance failure that strict query replay detects" — true for every path?* No path. The
  three routes from general configuration to a prepared request are `ext_config` read directly by `prepare`
  (`config_projection`), a module constant that the extension's version does not bump, and a data position on a
  constructor (N58). For the first, replay serves the recorded bytes of the current epoch and reproduces the request;
  for the second, the record holds the extension's version string, which the author controls; for the third, nothing
  is recorded at all. The only artifact that could show the first is a cross-epoch comparison of requests under an
  unchanged question digest, which the ADR does not define (N57's option (i)).

### Q-4. The gate criterion against the tool's verdicts and the eighteen extensions

**Well-defined, and red on the tree today for the right reason; the fixture list needs two additions and the result
needs its own field.**

Driving `Scope.locate` and the binding pass over the eighteen installable extensions (A.5, read-only, package-local
closures): every registration locates through the list head — ten at zero hops, eight through one delegated call
(a2a, agentcli, ailang-docs, compose via the import rename `register_with_config as register_with_host_cfg`, exa-search,
herdr's `make_hooks_with`, mcp, scratchpad) — and every atom enumerates: 45 bindings, 19 inline lambdas, 16
`let`-bound lambdas, 10 named functions, agreeing with the fifth and sixth reviews and with `expected.json`'s
`capability_list_atoms` (41 real-body atoms plus herdr's and microrag's data-carrying ones). So the total result over
HEAD is: 18 of 18 return-shape supported (list head; the `{ config, caps }` head is not in the tree yet), 18 of 18
enumerated, **0 of 18 pass the named rule** — a2a, agentcli, ailang-docs, compaction-ai, compose, context-mode,
exa-search, herdr, mcp, omnigraph, progress-contract-guard, repetition-guard, scratchpad and test-dummy each hold at
least one non-named binding, and compaction-structural, decision-framework, empty-stop-guard and microrag are named
throughout. Four green, fourteen red, nonzero exit: that is the criterion working as a gate on an unmigrated tree,
and it is independent of the walk residue (`show`, `intToFloat`, `f`) that keeps compaction-structural and microrag
`HOOK-UNRESOLVED` for door-3 reasons.

Against the fixture list at D2:243-246:

- direct named success — `fx_named_ok` locates, named: passes;
- direct shadow — `fx_shadow`: the tool reports `HOOK-PORT-MEDIATED` today; the binding pass sees `body` in
  `producing_locals` **and** as a declaration, so a `let`-first rule rejects it: **red**;
- delegated shadow — `fx_delegate_shadow`: the tool certifies `body` today; with per-hop locals the hop's
  `let make_hooks` is found first: **red**;
- parameter binding — `fx_param_shadow`: certified today; red only once parameters are read (N63): **red after
  N63**;
- partial application — rejected today by `_binding_text` (fifth review's `fx_partial`): red;
- computed and unknown `caps` — `fx_computed` rejected at `locate` today: red; under the new grammar the same;
- valid empty registration — passes where normalization omits it (`registry_normalize.ail:277-289`);
- named callback with unrelated walk residue — compaction-structural and microrag today: **must pass**, which is
  only possible if the shape result is its own field (N63 item 3);
- **missing:** the delegated-parameter case (`fx_delegate_param`, certified two hops deep today) and the
  import-shadow control (`fx_delegate_import_shadow`: the tool follows the import, the compiler runs the import,
  the rule rejects — score it as boundary-rejected, compiler-clean).

`emit_hook_scope` exiting nonzero from the new field changes nothing in the shipped `ext_ambient_inventory`
verdict: the two modes are separate `main` branches (`derive.py:920-930`), and the self-test guards the closure
verdict explicitly (`hook_scope.py:1230-1240`).

## 6. D1–D7 assessment

| Decision | Assessment |
|---|---|
| **D1 ownership** | **Accept, unchanged.** N58's digest extension keeps ownership where D1 puts it: the host hashes what the extension disclosed, now including what it disclosed in constructor data positions. |
| **D2 callbacks, contexts, boundary, channel** | **Accept the views, the rule, the gate criterion and the `DescribeTools` shape; correct the channel paragraph, the scoping claim and the tool edits.** The six views, the row derivation and the helper rule are unchanged and were verified by the third through fifth reviews. Facts 1–6 hold on the pin (A.2). The shape rule is sound against eleven new constructions (Q-1); its "in AILANG's scoping order" is measured wrong for imports (N62); the edits it names cannot implement its parameter and module-scope halves (N63). The channel's narrowed sentence is exact; its "replay detects" consequence is false (N57); constructor data positions are outside it (N58). The count table's inline row mis-sums (N65). The residual for registry-installed extensions, the suite's home, and the cost paragraph are right. |
| **D3 observations and evidence** | **Accept, unchanged.** Nothing in v0.7 touches D3's types. `DecisionInvocationState` carries the two descriptor projections and the five ledger terms; the mirror protocol and its counter-update paths (sixth review Q-3) remain plan obligations. |
| **D4 execution and merges** | **Accept; redraw the diagram (N64).** Precedences match `merge_finalize_decisions` and `merge_tool_decisions`; nullary `Accept`; the leaf placement. The diagram's "validate/admit → reserve" in the calling core module contradicts D5 since v0.6. |
| **D5 bounds and durability** | **Accept.** The terminal-query sentence now agrees with the equation (N55); the two allowances, the no-refund rule, the write barrier and the transport are as verified before (`session-journal.ts:367-386`, `:403-417`, `:430-471`; `session-logger.ts:404-410`; `runtime-process.ts:1282-1298`). The replacement-identity sentence at `:644-647` now defers to D6's first-registration rule; N61 shows one forced-resume case where the two rules still both apply. "Fixed for that session identity" needs the grant reconciled (N59). |
| **D6 recording and identity** | **Accept the layers, the epoch, the split `Descriptor` row, the orphan predicate, the acknowledgment and the inactive registration; complete the waiver (N59, N60, N61) and the detector (N57).** The acknowledgment does what N53 asked for on the second resume. The inactive registration closes N54's free vote. The three entries are one sentence short each: migration's carriage and activation, the acknowledgment's end, and which identities the forced-resume rule covers. |
| **D7 migrations** | **Accept; three rows need words.** The ABI row now names `DescribeTools((Json))`, `ExtRegistration`, `ExtEntry.config` and `ext_config` on every view — right. The tooling row names four edits that are insufficient (N63) and should name the signature retention, the module-scoped table and the separate result field. The "Other records" row names the acknowledgment, migration and grant entries and must gain migration's carriage, acknowledgment retirement, and the data-position digest (N58–N60). The journal row, the `/5` attribution and the `schema_promotion` transition are unchanged and were verified by the fifth review against the fold and the host. |

**Freeze-evidence audit.**

| Item | Result |
|---|---|
| **1** accepted contract review | Not met; blockers above. The surface is now stable enough that the remaining decisions are sentences, not mechanisms — except N57, which is a mechanism or a withdrawn claim. |
| **2** three enforcement classes | **Not met.** (a) unchanged and correct. (b) the rule holds against the combined suite plus eleven new constructions; the group scoring (20/1/3) is right; the suite needs a fourth expected class for boundary-rejected compiler-clean controls (N62) and the delegated-parameter escape. (c) `v7_describe_config` is the shape of the example but is a language probe, not an ABI-8 consumer; nothing compiled against ABI 8 exists. The "one supported registration form" the inventories must recognize now has a measured resolution order to encode. |
| **3** extension-only change, strict mismatch, offline separation | Correct requirement; N57 shows one mismatch class it cannot demonstrate as written. No artifacts. |
| **4** parity, propagation, occurrences, strict replay | Good obligations, unchanged. |
| **5** evidence and crash matrix | Well specified. Add: acknowledged → reappears → removed again (N60); migration then a query without a grant (N59); forced resume with an unrelated first registration (N61); a general-config change that alters a question under an unchanged question digest, and whatever N57 chooses as its detector. |
| **6** composition and non-resetting limits | Correct; "compaction/profile changes/resume cannot silently reset host allowances" now has the reappearance hole (N60) to cover. |
| **7** format migrations | Correct and unchanged. |
| **8** gate semantics | **Criterion right, half implementable as written.** The two-sided idiom and G5e agree with the text (verified: the release scope's G5e cell reproduces D2's four conditions and "zero rejections, nonzero exit otherwise"; its working-tree diff touches only the G5 row). The criterion is well-defined and red on the tree today for the right reason (Q-4). The fixture list lacks two cases (N62) and the result must be a field, not a filter (N63). |

**The six response tables** are faithful to the reviews they summarise. I checked the sixth-review table row by
row against `REVIEW-adr001-v0.6-verdicts-codex.md`: the eight rows state what v0.7 did, and the caveats in §4 are
mine, not misstatements in the table. The fifth-review table's N41 and N46 rows carry their supersession notes; its
**N43 row** ("gate criterion: nonzero exit on any named-only rejection") is superseded by N52's total result and
lacks the note the neighbouring rows have. The fourth-review table's N40 row carries the N55 supersession. The
third, second and first tables are unchanged from v0.6 and were verified by the fourth through sixth reviews; I
re-checked the third table's N26 and N30 rows against the third review and found them accurate as history.

## 7. Before freeze, before the plan, and afterwards

**Before freeze.** Decide N57 — a detector, the restricted view, or an honest "reviewed discipline" — and delete
the replay sentence. Add the two sentences the waiver transition is missing (N59: migration carries allowance and
limit and activates; N60: acknowledgment ends on reappearance) and settle the forced-resume overlap and "records
nothing else" (N61). Fold constructor data positions into the epoch digest (N58). Replace "in AILANG's scoping
order" with the measured order or an explicit over-rejection note, and add the import-shadow controls and the
delegated-parameter escape to the suite and the fixture list (N62). Name the three tool changes the listed four
cannot deliver (N63). Redraw D4's arrow (N64); fix the row sum (N65); add the N43 supersession note. Then satisfy
freeze evidence 1–3 with real artifacts — compiled ABI-8 consumers, the executable shape gate red on the fixtures
and green on the migrated tree, and the mismatch fixtures — which this review, like the last four, substitutes
language probes for none of.

**Before the affected implementation plan is approved.** The `func_body`/`_resolve_func` signature retention and
per-hop scope chain; the module-scoped declaration table; the separate shape-result field and its rejection shapes;
the re-pinned self-test yields for the `{ config, caps }` head. The `ExtEntry.config` migration through the
generator and the seven literal sites (N49 row). The data-position projection into the epoch digest (N58). The
`DescribeTools` migration of the four capturing catalogs, with ailang-docs' `active` bool and herdr's `tools` list
encoded in `config`. The per-package migration of the 35 non-named bindings with A.5 as the site list. The
`schema_promotion` protocol, the success-returning append, the wire contract, the mirror and counter-update paths,
the ADR-003 amendment and the ADR-004 basis refresh, all unchanged from the sixth review's list.

**During implementation, before live enforcement.** Freeze evidence 4–8 with the additions in the audit. Run the
tree-wide gate: red on `fx_shadow`, `fx_delegate_shadow`, `fx_param_shadow`, `fx_delegate_param` and `fx_computed`;
green on `fx_named_ok`, on the empty registration, on a named callback with `show` in its walk residue, and on the
migrated tree. Re-run the suite at every AILANG bump: the import-precedence fact (N62) is as much a property of the
pin as the inference gap is.

**Afterwards.** Provider limits, guard wording and thresholds, and live quality measurement under recorded policy
versions. The `ext_ai_step` usage loss remains separately disclosed debt.

## 8. Method and limitations

I read the brief first and completed both grounding checks before reading the ADR: HEAD `2f3ee4d1` on
`arniwesth/031-abi-8-0`; 1107 lines with the stated SHA-256; `git diff --stat 2062605 HEAD` over the five paths
empty; the three untracked files in those paths (`scripts/dst/mem_canonical_bench.ail`,
`scripts/dst/mem_growth_probe.ail`, `src/eval/journal/testdata/MATRIX.tsv`) neither read nor created. `ailang` on
PATH is v0.33.0, commit `ae36986`.

Read in full: the ADR v0.7; the sixth review including all of Appendix A (its 45 sources were extracted by script
from the appendix, not retyped: 48 fenced `ailang` blocks, 48 unique module names, the four decisive SHAs matching);
the fifth review in full; the fourth review's §1–§5 and its N31–N40; the third review's §1–§5 and its N23–N30 (its
21 sources came through the sixth review's A.4 reproduction); the second and first reviews; NOTE-001; all five
2026-09-20 handoffs and the 2026-09-18 handoff; the release scope's G5 row and its working-tree diff;
**`tools/ext_ambient_inventory/hook_scope.py`, all 1266 lines**; `derive.py`'s `installable_extensions`,
`_hook_scope` and `main`; `run_declared_vs_performed.sh:735-790` and `:935-1005`; `Makefile:500-525` and
`:3205-3232`; every `packages/*/register.ail` (comments stripped) and every delegated `make_hooks` /
`make_hooks_with` body, `compose.ail:1095-1115`, `scratchpad.ail:85-105`, `mcp.ail:148-170`; the four
`DescribeTools` sites. Read in the named sections and their dependencies: `types.ail` (header, `ExtPorts`
`:256-300`, `ExtCtx` `:536-619`, `Capability` and `ExtEntry` `:1238-1277`); `tool_catalog.ail:90-150`;
`runtime.ail:335-350`, `:1098-1151`, the `ExtEntry` literals; `registry_normalize.ail:100-175`, `:270-330`;
`journal.ail` (`:20-40`, `:620-640`, `:805-820`, `:1785-1810`, `:3270-3292`); `session.ail:2600-2655`;
`step_machine.ail:95-120`; `session-journal.ts` (`:25-45`, `:280-300`, `:360-390`, `:400-420`, `:425-475`);
`session-logger.ts:395-415`; `runtime-process.ts:1225-1305`; ADR-003 D3 and D5; ADR-004 D1 and D5; 017 ADR-001's
headings and Q3; the hook-scope `expected.json`; `ailang.toml`'s `[extensions]` block; `std/json.ail`'s `Json`
type; the registry generator's entry template.

**Probes.** Fifty-nine AILANG modules in a scratch directory outside the repository
(`…/scratchpad/adr001-v07-probes/repro/`): `ailang.toml` and the three support modules byte-identical to the sixth
review's A.1; the 45 reproduced cases (0 mismatches on check exit and run exit; escape outputs and first diagnostic
lines spot-checked, Appendix A.2); and eleven new cases plus three new support modules (A.3). Accepted probes were
run with `--caps IO,FS`; the only effect any exploit performs is stdout output. **The walk was driven, not only
read:** a driver imported `hook_scope.py` from the repository by path with `sys.dont_write_bytecode` set (the two
`.pyc` files in `tools/ext_ambient_inventory/__pycache__` predate this session: 2026-08-26 and 2026-09-08; the
directory is gitignored), ran its `Scope` class on eleven fixtures with the fifth review's stub producer, and ran
`locate` plus a binding-form pass over the eighteen installable extensions resolved through `ailang.toml`'s path
table with package-local module sets (A.4, A.5). That measures the tool's registration resolution and binding
enumeration; it is not a run of `make ext_hook_scope`, it does not exercise the closure, the producer cache or the
parent tool, and the **verdicts** it printed for the real tree are not the tool's yield — the stub producer and the
package-local closure make them differ from `expected.json` — so only the shape data (located, hops, home, binding
forms) is reported.

**Not done.** I did not run `make ext_hook_scope`, `make ext_hook_scope_selftest`, `make declared_vs_performed` or
any other project target, for the read-only reason every review since the third has given. I did not build any
package against a hypothetical ABI 8.0. I did not re-verify the first review's inventory counts, attempt a provider
call, or re-check the external SDK and registry sources. I did not read `session.ail`, `ports.ail`, `journal.ail`,
`compose.ail` or the TUI modules line for line beyond the cited regions. I did not re-run the fifth review's twenty
named-arm attacks whose sources it did not print; I counted its table and re-ran the five it printed through the
sixth review's reproduction. The Q-2 walk is reasoning over the text; no resume fixture exists to execute.

No subagents were used. No commits were made. No Herdr command was invoked; pane `w3:p1` and
`/workspaces/motoko_agent-eval` were not touched. The sole repository file written by this review is this one;
probe sources, fixtures, the driver and captured output live outside the repository.

## Appendix A. Compiler probes, walk fixtures, and exact results

### A.1 Environment and commands

Scratch root outside the repository. `ailang.toml` (package `local/repro`, prefix `repro`) and
`repro/types.ail`, `repro/helpers.ail`, `repro/boundary_types.ail` are byte-identical to the sixth review's A.1
(`Ctx = { name: string }`, `Capability = ToolPolicy((Ctx) -> int)` in `boundary_types`). Commands:

```sh
ailang check repro/<case>.ail
# only after a successful check:
ailang run --caps IO,FS --entry main repro/<case>.ail
python3 walk_driver.py fixtures
python3 walk_driver.py tree
```

### A.2 Reproduction of the sixth review's 45 cases

Sources extracted by script from `REVIEW-adr001-v0.6-verdicts-codex.md` (every fenced `ailang` block whose first
line is `module repro/<name>`). Check and run exits compared against that review's A.2 ledger:

```text
cases expected 45 got 45 mismatches 0 []
rejected 28 accepted 17 run0 14 run1 3 ['fs_missing', 'missingannot', 'missingport']
```

Escape outputs, verbatim: `delegate_shadow` and `computed_list` print `NAMED RULE ESCAPE` / `result=1`;
`q_named_shadow` and `n_pure_passthru_unannot` print `EFFECT WITH NO PORTS OR WORLD` / `result=1`;
`registration_record` prints `result=1`; `named_static_constant` prints `result=7`; `config_projection` prints
`question A` / `question B`. First diagnostic lines: `named_match_record` — `Effect checking failed for function
'body'`; `named_module_env` — `… for function 'policy'`; `q_named_toplevel_apply` — `… for function 'w'`.
Source SHA-256 of the four decisive cases match the sixth review's: `delegate_shadow` `9331f51e…516f`,
`computed_list` `535063b7…5864`, `registration_record` `49167e7d…6833`, `named_static_constant` `30552edc…bafe`.

### A.3 New probes against the v0.7 shape rule

`—` means not run because the check failed. Every case imports `Ctx`, `Capability` and (where used) `ToolPolicy`
from `repro/boundary_types`. Support modules: `v7_mk` (exports `mk_policy(f) = ToolPolicy(f)` and `invoke`),
`v7_other` (exports `body` returning `2`), `v7_mkmod` (exports `make_hooks(_n) = [ToolPolicy(body)]` with `body`
returning `2`; first run with `1`).

| Case | Shape | Check | Run | Output | SHA-256 (source) |
|---|---|---:|---:|---|---|
| `v7_ctor_shadow` | local `func ToolPolicy(_f) ! {IO}` building the escaping lambda via `mk_policy`; constructor **not** imported; `[ToolPolicy(body)]` | 0 | 0 | `result=1`, **no effect** — the constructor ran | `5af30c1c…8ecb` |
| `v7_ctor_shadow_imported` | same, constructor also imported | 0 | 0 | `result=1`, no effect | `d9f2c00d…2cb3` |
| **`v7_param_shadow`** | `make_hooks(body: (Ctx) -> int)` returns `[ToolPolicy(body)]`; top-level `func body`; registration passes the escaping lambda | **0** | **0** | `NAMED RULE ESCAPE` / `result=1` | `4af08e9e…f3a6` |
| **`v7_delegate_param`** | `build_with(mk: (int) -> [Capability]) { mk(0) }`; top-level `func mk`; registration passes a lambda returning the escaping list | **0** | **0** | `NAMED RULE ESCAPE` / `result=1` | `5f41bf8f…2699` |
| `v7_import_shadow` | `import repro/v7_other (body)` and a same-module `func body` returning 1 | 0 | 0 | `result=2` — the import ran | `d4ab2590…5862` |
| `v7_delegate_import_shadow` | `import repro/v7_mkmod (make_hooks)` and a local `let make_hooks = <escaping list>`; tail `make_hooks(0)` | 0 | 0 | `result=2`, **no effect** — the import ran (first run, `body` = 1: `result=1`, no effect) | `9411e5c5…a578` |
| `v7_toplevel_let_lambda` | module-level `let body = func(ctx) { let w: W = {…println…}; apply(ctx, w) }` | 1 | — | `Effect checking failed for function 'body' … Missing effects: IO` | `396704ad…2ed3` |
| **`v7_match_list`** | tail `match cfg { 0 => [ToolPolicy(body)], _ => [ToolPolicy(<escaping lambda>)] }` | **0** | **0** | `NAMED RULE ESCAPE` / `result=1` | `36f2e258…852d` |
| **`v7_record_delegated`** | `{ config: JString("data"), caps: make_hooks(0) }` with a local `let make_hooks` over a top-level `make_hooks` | **0** | **0** | `NAMED RULE ESCAPE` / `result=1` | `2a630b17…4d07` |
| `v7_describe_config` | `Describe((Json) -> [string])`; named `describe` matching `JString` | 0 | 0 | `configured=1 empty=0` | `540cd9f3…2438` |
| `v7_destructure_let` | `let { g: body } = p; [ToolPolicy(body)]` | 1 | — | `PAR_UNEXPECTED_TOKEN at …:8:208: expected next token to be IDENT, got { instead` | `03477a4d…4faa` |

#### `v7_param_shadow` — a parameter that shadows a top-level function is certified as that function

```ailang
module repro/v7_param_shadow
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { 1 }
func make_hooks(body: (Ctx) -> int) -> [Capability] { [ToolPolicy(body)] }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { let w: W = { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } }; make_hooks(func(ctx: Ctx) -> int { apply(ctx, w) }) }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

`ailang check` exit 0: `✓ No errors found!`. `ailang run --caps IO,FS` exit 0:

```text
✓ Running repro/v7_param_shadow.ail
NAMED RULE ESCAPE
result=1
```

#### `v7_delegate_param` — the delegated callee is a parameter that shadows a top-level function

```ailang
module repro/v7_delegate_param
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { 1 }
func mk(_n: int) -> [Capability] { [ToolPolicy(body)] }
func build_with(mk: (int) -> [Capability]) -> [Capability] { mk(0) }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { let w: W = { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } }; build_with(func(_n: int) -> [Capability] { [ToolPolicy(func(ctx: Ctx) -> int { apply(ctx, w) })] }) }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

`ailang check` exit 0; `ailang run --caps IO,FS` exit 0, printing `NAMED RULE ESCAPE` then `result=1`.

#### `v7_delegate_import_shadow` — an imported name outranks a local `let` of the same name

```ailang
module repro/v7_mkmod
import repro/boundary_types (Ctx, Capability, ToolPolicy)
func body(_ctx: Ctx) -> int { 2 }
export func make_hooks(_n: int) -> [Capability] { [ToolPolicy(body)] }
```

```ailang
module repro/v7_delegate_import_shadow
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
import repro/v7_mkmod (make_hooks)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { let w: W = { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } }; let make_hooks = func(_n: int) -> [Capability] { [ToolPolicy(func(ctx: Ctx) -> int { apply(ctx, w) })] }; make_hooks(0) }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

`ailang check` exit 0; `ailang run --caps IO,FS` exit 0:

```text
✓ Running repro/v7_delegate_import_shadow.ail
result=2
```

No `NAMED RULE ESCAPE` line: the imported `make_hooks` ran, not the local `let`. `v7_import_shadow` (import
`body` returning 2 beside a same-module `func body` returning 1) likewise prints `result=2`.

#### `v7_ctor_shadow` — a local function named like the constructor is dead code

```ailang
module repro/v7_ctor_shadow
import std/io (println)
import repro/boundary_types (Ctx, Capability)
import repro/v7_mk (mk_policy, invoke)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { 1 }
func ToolPolicy(_f: (Ctx) -> int) -> Capability ! {IO} { let w: W = { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } }; mk_policy(func(ctx: Ctx) -> int { apply(ctx, w) }) }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { [ToolPolicy(body)] }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

`ailang check` exit 0; `ailang run --caps IO,FS` exit 0, printing only `result=1`. The constructor of the imported
sum was applied, not the local function, with or without the constructor's name in the import list.

#### `v7_describe_config` — the N49 shape

```ailang
module repro/v7_describe_config
import std/io (println)
import std/json (Json, JString, JNull)
import std/list (length)
type Cap = Describe((Json) -> [string]) | Other(int)
func describe(cfg: Json) -> [string] { match cfg { JString(s) => [s], _ => [] } }
func caps() -> [Cap] { [Describe(describe)] }
func schemas(cs: [Cap], cfg: Json) -> [string] { match cs { Describe(f) :: rest => f(cfg) ++ schemas(rest, cfg), _ :: rest => schemas(rest, cfg), [] => [] } }
export func main() -> () ! {IO} { println("configured=${show(length(schemas(caps(), JString("tool"))))} empty=${show(length(schemas(caps(), JNull)))}") }
```

`ailang check` exit 0; `ailang run --caps IO,FS` exit 0: `configured=1 empty=0`.

The `v7_match_list` and `v7_record_delegated` sources are the sixth review's `computed_list` and
`registration_record` with, respectively, a `match cfg { 0 => …, _ => … }` tail called with `1`, and a local
`let make_hooks` shadow returning the escaping list inside `caps:`; both check 0, run 0, print `NAMED RULE ESCAPE`.

### A.4 Driving `hook_scope.py`'s `Scope` on scratch fixtures

The driver imports the tool by path, read-only, with `sys.dont_write_bytecode = True`, and runs `Scope` as
`self_test` does: `trivial_resolve`, a stub producer classifying `println`/`print` as `{IO}`, `getEnvOr` as
`{Env}`, `exec`/`writeFile` as `{FS}`, everything else pure; no builtin evidence; the ten `ExtPorts` field names.
A binding is classified by the tool's own helpers: `lambda_body` → inline; a bare name in
`let_bindings(producing_body)` → `let`-bound (and "SHADOWS" when `_resolve_func` also finds it); `_resolve_func`
→ named, with the module it resolved to.

Every fixture begins `module sunholo/motoko_ext_fx/register`, imports `std/io (println)` and the ABI types, and
declares `type W`, `func apply(ctx, call, w) { w.f(ctx, call) }` and a clean `func body`.

| Fixture | Registration tail | Verdict | located / hops | Binding classified | Note |
|---|---|---|---|---|---|
| `fx_named_ok` | `[ToolPolicy(body)]` | `HOOK-PORT-MEDIATED` | true / 0 | named (declaration) | positive control |
| **`fx_shadow`** | `let body = <pass-through>; [ToolPolicy(body)]` | `HOOK-PORT-MEDIATED` | true / 0 | **let-SHADOWS-declaration** (`producing_locals` = `_`, `body`, `w`) | the `let` is visible to a `let`-first rule |
| **`fx_delegate_shadow`** | `let make_hooks = …; make_hooks(0)` over `func make_hooks` | `HOOK-PORT-MEDIATED` | true / 1 | named (declaration) | wrong list followed |
| `fx_computed` | `if true then [ToolPolicy(…)] else []` | `HOOK-UNRESOLVED` | **false** / 0 | — | `capability-list-unresolvable: tail expression … builds the capability list by an expression` |
| **`fx_param_shadow`** | `make_hooks(<lambda>)` with `make_hooks(body: …)` | `HOOK-PORT-MEDIATED` | true / 1 | named (declaration) | parameter never read |
| **`fx_delegate_param`** | `build_with(<lambda>)` with `build_with(mk: …) { mk(0) }` | `HOOK-PORT-MEDIATED` | true / **2** | named (declaration) | parameter `mk` resolved to the top-level `mk` |
| `fx_ctor_shadow` | local `func ToolPolicy`, constructor not imported | `HOOK-PORT-MEDIATED` | true / 0 | named (declaration) | right by coincidence (A.3) |
| `fx_record` | `{ config: "x", caps: [ToolPolicy(body)] }` | `HOOK-UNRESOLVED` | **false** / 0 | — | `… builds the capability list by an expression` — the record head is unknown today |
| `fx_xmod_collision` | `[ToolPolicy(body)]` with an effectful `func body` in a second closure module | `HOOK-AMBIENT` | true / 0 | named (declaration: **other.ail**) | over-rejection: closure-wide `declared` |
| `fx_delegate_import_shadow` | `let make_hooks = …; make_hooks(0)` over an **imported** `make_hooks` | `HOOK-PORT-MEDIATED` | true / 1, home `mkmod.ail` | named (declaration: mkmod.ail) | agrees with the compiler (A.3) |

### A.5 `Scope.locate` and the binding pass over the eighteen installable extensions

Resolved through `ailang.toml`'s `[extensions]` and path table, package-local module sets (every `.ail` under the
package directory), the same stub producer. Only the shape data is reported; the verdicts differ from
`expected.json` because of the stub producer and the package-local closure.

| Extension | hops | hook home | Bindings (form) |
|---|---:|---|---|
| a2a | 1 | `a2a.ail` | DescribeTools inline; ToolProvider let |
| agentcli | 1 | `agentcli.ail` | DescribeTools inline; ToolProvider let |
| ailang_docs | 1 | `ailang_docs.ail` | DescribeTools inline; PromptShaper inline; ToolProvider let |
| compaction_ai | 0 | `register.ail` | Compactor inline |
| compaction_structural | 0 | `register.ail` | Compactor **named** |
| compose | 1 | `compose.ail` | PromptShaper **named**; ToolPolicy inline; ToolProvider let; ResponseInterceptor let |
| context_mode | 0 | `register.ail` | PromptShaper inline; ToolPolicy **named** (import); ToolProvider let; SolverJudge let |
| decision_framework | 0 | `register.ail` | PromptShaper **named** |
| empty_stop_guard | 0 | `register.ail` | SolverJudge **named** |
| exa_search | 1 | `exa_search.ail` | PromptShaper inline; ToolProvider let |
| herdr | 1 | `herdr.ail` | DescribeTools let; PromptShaper inline; ToolPolicy inline; ToolProvider let; ExitIntent let; WorkInFlight let |
| mcp | 1 | `mcp.ail` | ToolProvider let |
| microrag | 0 | `register.ail` | DescribeTools, ToolPolicy, ToolProvider **named** |
| omnigraph | 0 | `register.ail` | PromptShaper inline; ToolPolicy **named** (import); ToolProvider inline |
| progress_contract_guard | 0 | `register.ail` | SolverJudge inline |
| repetition_guard | 0 | `register.ail` | ToolPolicy let; SolverJudge let |
| scratchpad | 1 | `scratchpad.ail` | DescribeTools inline; PromptShaper inline; ToolPolicy **named**; ToolProvider let |
| test_dummy | 0 | `register.ail` | PromptShaper, BudgetShaper, ToolPolicy, SolverJudge inline |

```text
TOTAL over installable extensions: 18 bindings by form: {'inline-lambda': 19, 'let-bound': 16, 'named': 10} sum 45
```

Under the package-local closure the walk emitted `hook-binding-unresolvable` for ailang_docs, exa_search,
scratchpad, compaction_ai and compose — imports the full closure resolves (`pkg/sunholo/motoko_ext_mcp/…`,
`src/core/…`, `motoko_ext_ai_compat`) — which is the shape-name collision N63 item 3 describes.

## Provenance and final integrity check

- **Model:** `claude-fable-5-1`, as this session reports it. Self-report, not a backend attestation. **Same model
  as the drafter of v0.3–v0.7; a fresh session with none of the drafter's context** — independence of session and of
  evidence, not of model. No model override, no delegated reviewer, no subagents.
- **Reasoning effort:** not exposed in this session's reportable metadata; I do not infer one.
- **Branch / HEAD:** `arniwesth/031-abi-8-0` / `2f3ee4d1`.
- **ADR SHA-256 before reading:** `45378ccd835f1aedaed38f4ba56aa62b02a691af0763b8da79ccc821378abd06` (1107 lines).
- **ADR SHA-256 after writing this review:** `45378ccd835f1aedaed38f4ba56aa62b02a691af0763b8da79ccc821378abd06` —
  **unchanged**; the reviewed working-tree v0.7 was stable throughout (re-checked after the probe runs and after
  this file was written).
- **Repository write:** `.agent/projects/031_system_one_decisions/REVIEW-adr001-v0.7-verdicts-claude-fable-5-1.md`
  only. No commit. Probe sources, fixtures, the walk driver and captured output are outside the repository.
