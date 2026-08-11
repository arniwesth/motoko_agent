# Handoff: delta review of the seventh correction pass to ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the correcting session. The corrections you are
reviewing were written by the authoring side in response to two delta reviews. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**Narrow delta review.** The ADR carries fifteen `## Review Comments` sections: two full reviews
(2026-07-26), three verifications of the F1–F6 revision, and ten delta reviews of correction passes
two through six. The architecture is settled and has been re-derived by every round. Your target is
one commit plus a one-paragraph follow-up.

## Mission

Verify the **seventh correction pass**, which answers all seventeen findings from the two delta
reviews recorded as the ADR's fourteenth and fifteenth sections.

## Target range

```text
d6904c4  the two sixth-pass delta reviews (verbatim, committed before any response)  <-- BASELINE
a3519d6  seventh correction pass
<HEAD>   correction to the extension-coverage claim (see A2) + this handoff
```

```text
$ git diff d6904c4..HEAD -- .agent/projects/009_motoko_dst_execution/
```

Exhaustive, no hand-maintained edit table. The untracked `mmd/` directory is out of scope.

## The two things that are authoring choices, not review recommendations

**A1 and A2 below.** Both reviews said "restate or delete" the coverage floor; the pass **deleted** it
and substituted a different mechanism. And the pass derived a general claim about extension coverage
that neither review asked for — which the follow-up commit has already had to correct once. Start
there.

## Attack list

### A1. Deleting the coverage floor may have replaced an unsatisfiable rule with an unfailable one

The floor is gone. In its place: the profile definition, the acceptance row, and the run result must
report **per-extension covered/excluded hook counts**.

- **Can the new acceptance clause ever fail?** The floor was a predicate over configurations; the
  replacement is a reporting obligation. "The result reports per-extension counts" is satisfied by
  reporting, whatever the counts say. A profile that installs fourteen extensions and covers nothing
  now *passes* the row it used to fail, having disclosed that it covers nothing. Rule on whether
  disclosure belongs in an acceptance table at all, or whether it is a manifest/result obligation
  with no gate semantics — Claude R10's original framing offered exactly that alternative and the
  pass did not take it.
- **Is the anti-laundering goal actually met?** The stated purpose was to stop "conformant" being
  claimed by a profile that excludes everything. Disclosure makes that visible to a reader. Decide
  whether visible-but-permitted is the right disposition, or whether something must still reject it.
- The pass's argument for deletion — a structural rule over a field set the extension does not
  control cannot work — is sound as far as it goes. Check it does not also argue against the
  replacement.

### A2. The extension-coverage claim was overstated once already; check the corrected version

`a3519d6` asserted that "under the declared-row rule, no behaviour-carrying extension hook is
coverable today". **That is false**, and the follow-up commit corrects it: `ExtensionHooks` leaves
three slots rowless — `on_describe_tools`, `on_build_system_prompt`, `on_tool_policy` — and
`on_tool_policy` carries real policy logic in at least four extensions (`compose.ail:838`,
`motoko-ext-microrag/register.ail:189`, `motoko-ext-context-mode`, `motoko-ext-omnigraph`).

- **Verify the corrected claim**: five slots excludable-only (four at nine effects, `on_budget_plan`
  at `{Env, FS}`), three coverable. Check the enumeration against the ABI type, not against this
  handoff.
- **Check the surviving narrow claim** — that the two named guards cover none of their own logic,
  because `decide` is reached through `on_solver_candidate`. That is the part the correction keeps,
  and it is what makes the interim profile's value questionable.
- The original error came from generalising over "behaviour-carrying" without checking which slots
  the ABI leaves rowless. Look for the same generalisation elsewhere in the pass.

### A3. The classifier-2 matcher is now precise — is it precise about the right thing?

The predicate is "calls a classifier-2 field on an `ExtPorts`-typed value", at extension granularity,
with declarations, record construction, strings/comments, and the ABI package named out of scope.

- **Is the typed qualifier decidable by the textual scan that implements it?** "On an
  `ExtPorts`-typed value" is a type-level condition; a grep for `\.ai_step\(` approximates it. Where
  do they diverge, and does the divergence fail open or closed?
- **`motoko_ext_conformance` is called non-registrable, with the rule applying "unchanged" if a
  profile installs a fixture package deliberately.** D5 elsewhere contemplates "deterministic fixture
  hooks" in an initial profile. Check those two statements are compatible.
- Re-derive the two call sites and the five textual matches; confirm the guards match textually and
  not by call.

### A4. Making the attribution table source-global may have orphaned it from the profile record

The table is now "source-global over **known** hook identities", with profiles intersecting against
it — the fix for a validator that could not express `test_dummy`'s absence.

- The profile-definition record still lists "the site-to-hook attribution table … bound to the source
  revision it was derived from" as a profile field. **If the table is source-global, what does a
  profile record — the table, or a reference to its version?** Those are different artifacts with
  different staleness rules, and the ADR now implies both.
- Check the intersection semantics are stated well enough to implement: a row lists hooks, a profile
  installs some subset, and the site is reachable iff the intersection is non-empty. Confirm the ADR
  says that and that the fail-closed default still applies to un-attributed sites.

### A5. Necessity is now explicitly manual — check what that costs the gate

The pass concedes that no listed validator check tests the correctness condition, records a named
reviewer per row, and adopts **syntactic dominance** as a conservative mechanical check.

- **Is syntactic dominance actually conservative?** It is presented as an over-approximation of
  necessity that catches a fabricated attribution. Test that. Consider a site dominated by a guard
  naming the hook where the hook is not in fact necessary.
- Does requiring a named reviewer per row belong in an ADR, or is it plan-level? It is the first
  human-process obligation this document imposes.

### A6. Classifier 1's four scan repairs

Signature-scoped rather than line-scoped; `export pure func` included; effect variables excluded;
recursive `std/**/*.ail`; scan root bound to a resolved commit.

- Re-derive all four defects rather than inheriting them: `std/process` scoring zero under a
  line-anchored pattern, `std/list`'s five `! {e}` exports, `std/ai/streaming.ail`'s effectful
  exports being in neither half of the union, and `export pure func … ! {Declassify}` being accepted
  on the pin.
- **Is "exported declarations carrying a non-empty effect row" now complete?** Three revisions have
  each found a fifth form. Look for a sixth before accepting the claim that the reason is recorded.
- Check the resolved-commit binding is stated as a fail-closed check and not merely as a record.

### A7. Anchors introduced or changed in this pass

`packages/motoko-ext-abi/types.ail:151-165` and the individual hook rows;
`packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:52,53,70`;
`packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:136,137,154`;
`packages/motoko-ext-compose/compose.ail:838`; `packages/motoko-ext-microrag/register.ail:189`;
`~/.local/share/ailang/std/process.ail`, `std/list.ail`, `std/ai/streaming.ail`, and
`examples/runnable/contracts/inbox_injection_v2.ail:39`; and the `install-prerequisites.sh` early
return.

The sixth pass was the first to ship **no** anchor error, after five that did. Do not assume that
holds.

### A8. The Status block, and a count that has now been stale twice

The review count is now stated as derived — `(sections − 5)`, evaluated at the commit carrying the
edit — with the derivation written into the block rather than resolved in prose again.

- **Recount at the commit you are reviewing.** Fifteen sections at `a3519d6` should give ten delta
  reviews.
- Check the rest of the block for content staleness, which is the class that survived last time, not
  count staleness.

## Settled — do not reopen

- **F1, F2, F3, F5, F6**; the **narrowed D1 blocking clause**; the **upstream return-shape ruling**;
  **M2** — all three F1–F6 verifications. **D6.1** — two of the three.
- **D4's repo-wide count of 13** and **"nothing is routed at HEAD"** — re-derived by every delta round.
  A9-class questions about the 4/12/13 *split* are answered by this pass's pre/post-table framing;
  the count of 13 is not in question.
- **The extension-model-path exclusion is the right disposition**; **the coverage/rejection split's
  timing argument is sound**; **classifier 2's cursor-loss membership criterion is correct** — all
  ruled explicitly by prior rounds.
- **`ProviderState`'s home in `src/core/ports.ail` is buildable** — two independent probes.
- **Clause 3's necessity-not-sufficiency semantics** — endorsed twice. A5 is about its *check*.
- **The closed-ABI facts** — `ExtensionHooks` is a closed record, the hook set is always eight, and
  `register.ail` can never narrow it. Established by both sixth-pass reviews.
- Configuration facts: fourteen configs, all installing `compaction_ai`; `compose` in one;
  `test_dummy` in none.

## Leads already checked — do not re-derive

- `ExtPorts.clock_now` has **zero call sites repo-wide**; `.ai_step(` has exactly two.
- `ailang builtins list -json` is byte-deterministic; its `name` is the internal builtin.
- The builtin projection yields 21 modules; the repo imports 21 distinct `std/*` modules; ten of
  those have no effect-bearing row; the source half recovers `std/sem` and `std/extension`.
- `agents_md.walk_agents` performs `FS` undeclared and v0.26.0 accepts it.
- Neither classifier, nor the attribution table, is wired into CI, the Makefile, or `scripts/`.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors.** Build probes in scratch
  directories outside the repository, as every prior round has.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`.

## Output contract

Append a **sixteenth** `## Review Comments` section to the ADR. There are fifteen. **Count them
yourself at the commit you are reviewing** — a previous handoff said "third" and was executed three
times, and the Status block has twice carried a stale count for exactly this reason.

Do not rewrite the body, and do not edit any existing review section. All fifteen are historical
records.

State your model id, the date, and the commit you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name what you re-ran and confirmed. Three deserve an explicit ruling:
   whether replacing the floor with disclosure leaves an acceptance clause that can fail (A1),
   whether the corrected extension-coverage claim is right this time (A2), and whether classifier 1's
   declaration pattern is finally complete (A6).
2. **Recommended pre-acceptance actions** — ordered by dependency, separating what this ADR must fix
   from what belongs to the implementation plan.
3. **Accept / revise recommendation** — one line, and say explicitly what happens to the upstream API
   blocker.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, the spike, other ADRs, or this
  ADR's body during review.
- **Do not re-litigate accepted 007**, and do not re-argue the decision to request an upstream API.
- **Verify by execution.** A claim you did not re-run is a claim you cannot certify.
- **Do not treat the fork prototype as the gate cleared.** D1 requires the recorded-stream API in a
  *release* with the toolchain repinned; `arniwesth/ailang`'s `stepWithStreamRecorded` on the
  `v0.31.0` tag is a prototype.
- **Do not treat the throwaway spike branch as HEAD state.**
- If the corrections hold, say so plainly and record residual risk. The likeliest surviving
  candidates, in order: A1's replacement clause being unfailable, A2's corrected claim still being
  wrong at the edges, and A6's declaration pattern missing a sixth form.
