# Handoff: delta review of the eighth correction pass to ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the correcting session. The corrections you are
reviewing were written by the authoring side in response to two delta reviews. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**Narrow delta review.** The ADR carries seventeen `## Review Comments` sections: two full reviews
(2026-07-26), three verifications of the F1–F6 revision, and twelve delta reviews of correction passes
two through seven. The architecture is settled and has been re-derived by every round. Your target is
one commit.

## Mission

Verify the **eighth correction pass**, which answers all nineteen findings from the two delta reviews
recorded as the ADR's sixteenth and seventeenth sections.

## Target range

```text
1cc1084  the two seventh-pass delta reviews (verbatim, committed before any response)  <-- BASELINE
39e9b8d  eighth correction pass
```

```text
$ git diff 1cc1084..39e9b8d -- .agent/projects/009_motoko_dst_execution/
```

One commit, exhaustive, no hand-maintained edit table. The untracked `mmd/` directory is out of
scope.

## Start here: a finding the authoring side made against its own pass and did not act on

**The extension-granularity rejection rule is provably over-broad, and the correction pass's new
carve-out mechanism may be unnecessary.** This was found while scoping this handoff, verified, and
deliberately left for you to adjudicate rather than fixed — the disposition of this exact question has
now changed three times in three passes (floor → disclosure-only → floor + carve-out), every time
unreviewed, and that is what produced the last three rounds of findings.

The rule requires an `ai_step`-calling extension to exclude **every hook it registers**, justified by
decidability: nothing maps a call site to the hooks that can reach it. But three of the eight ABI hook
slots carry **no effect row** (`on_describe_tools`, `on_build_system_prompt`, `on_tool_policy`), and
AILANG's effect checker makes it impossible for a rowless function to perform an effect:

```text
$ cat mod/m.ail
export func rowless() -> int {
  let _ = println("side effect from a rowless function");
  42
}
$ ailang check mod/m.ail
  Missing effects: IO
  Current signature: func rowless(...) -> T
  Suggested fix:     func rowless(...) -> T ! {IO}
```

`ExtPorts.ai_step` requires `! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream}`. A hook
whose ABI row is empty therefore **cannot** reach it — not "is unlikely to", cannot, by type. So the
rule could exclude only the five hooks carrying a non-empty row and leave the three rowless ones
coverable, at no cost to decidability: the narrowing is read off the ABI type, the same artifact
classifier 2 already reads.

If that holds, the consequences cascade through this pass's other work:

- `compaction_ai` would cover three hooks rather than zero.
- **The classifier-2 carve-out would have no member**, and the "zero covered hooks requires a recorded
  carve-out" machinery — new in this pass, in the profile record and the acceptance row — would be
  dead text.
- The restored coverage floor would bind without an exception, which is a strictly simpler contract.

Rule on it. If you accept the narrowing, say so and say what happens to the carve-out. If you reject
it — perhaps because a rowless hook can still *return a value* that causes the host to do something,
or because ABI rows are declarations the extension could widen in a future ABI — say why, because the
ADR currently justifies the coarse rule solely on decidability and that justification no longer
distinguishes the two options.

## Attack list

### A2. The restored floor and named disclosure, as a pair

The pass restored the floor (deleted in the seventh pass) *and* kept disclosure, on the reasoning that
one rejects and the other informs.

- **Is the floor now stated in a form that is decidable from the profile definition alone?** It is
  "not every hook of an installed extension may be excluded", with the carve-out. Check the
  interaction with the declared-row rule: every extension has three rowless slots, so zero coverage
  arises only when a profile excludes those too — which today only the classifier-2 rule forces. If
  A1's narrowing lands, check whether any path to zero coverage survives at all.
- **Is "disjoint and exhaust all eight ABI slots" right?** `ExtensionHooks` has ten fields; `id` and
  `provided_tools` are not hooks. Confirm eight is the hook count and that the validation is stated
  over the right set.
- The seventh pass claimed disclosure "achieves what the floor was for" and both reviews rejected
  that. Confirm the claim is gone rather than reworded.

### A3. The attribution table's reference form and the empty-intersection rule

A profile now records "table identity, source-revision binding, and content hash", not a copy; and a
valid row whose hooks are all uninstalled means the site is **unreachable**, while only a missing or
invalid row falls back to unconditional core.

- Is "table identity" specified enough to be a reference? Identity, binding, and hash — is that a
  primary key, or does it need a version?
- **The wrong-positive risk is now concentrated.** Syntactic dominance is withdrawn (correctly, per
  A4), so a *valid but false* row is caught by nothing mechanical and now silently removes a site from
  the reachable set. Check the ADR says that plainly. It is the same fail-open clause 3 was rewritten
  to close, re-entering through the artifact — the seventh-pass reviews both said so, and the eighth
  pass removed the check without adding a replacement.
- Confirm the empty-intersection rule no longer contradicts the mechanical rule twelve lines away,
  which is what Codex R2 found.

### A4. Withdrawing syntactic dominance

The pass withdrew it rather than repairing it, on the ground that a check failing its own worked
example invites reliance.

- Verify the withdrawal reasoning is stated correctly: `runtime.ail:190` is inside `emit_dummy_hook`
  (`:187-195`), which has no guard; the five guards are at `:206, 222, 239, 280, 368` and dominate the
  five calls at `:206, 222, 245, 287, 374`; the literal `"test_dummy"` is inside `is_test_dummy` at
  `:197-199`.
- Rule on whether withdrawal was right, or whether the interprocedural version both reviews sketched
  should have been specified instead of dropped.

### A5. Classifier 1's parsed-interface scanner

`ailang iface` is now the normative source-half scanner, with the textual scan a documented fallback.

- **Is `ailang iface` gate infrastructure?** Is it documented, stable, present in CI, and does it
  succeed on all 44 recursive `std` files? Codex reported a parsed-interface walk of all 44 with no
  failure; re-derive rather than inherit.
- Verify the two hard cases it is credited with: `stepWithStream` reporting `effects: ["AI"]` and not
  the callback's `{IO}`, and `std/list`'s five `! {e}` exports reporting no concrete effects.
- The result-row rule, the recursive-walk note (literal `std/**/*.ail` under default Bash matches only
  the nested file), and the corrected "rows containing `Stream`" wording are all new; check each.

### A6. The predicate canonicalisation, third attempt

Two consecutive passes asserted propagation in the same edit that failed to propagate — "stated once"
(false at two sites), "six sites, same words" (false at three, one stating the retired rule
normatively in D5).

- **Grep the body for the canonical phrasing and count.** The pass claims six sites and now frames the
  count as a claim to check rather than a warrant. Check it at the commit you are reviewing.
- Confirm the D1 headline sentence is grammatical and its bold markers are balanced — it was garbled
  by the seventh pass's edit.
- Confirm nothing still says "textual reference", "field-reference sites", or
  "`ai_step`-referencing", outside the paragraphs that retract those phrasings.

### A7. Anchors introduced or changed in this pass

`packages/motoko-ext-context-mode/context_mode.ail:80`;
`packages/motoko-ext-omnigraph/omnigraph.ail:69`;
`packages/motoko-ext-microrag/register.ail:189` and `:153-155`;
`packages/motoko-ext-compose/compose.ail:838` and `:83`;
`~/.local/share/ailang/std/ai.ail:318-324`; `scripts/install-prerequisites.sh:586`;
`packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90`;
`src/core/ext/runtime.ail:187-195, 197-199` and the guard/call line sets.

Two consecutive passes have shipped **no** anchor error, after five that did. Do not assume a third.

### A8. The Status block

The review count is derived — `(sections − 5)` at the commit carrying the edit — and should read
**twelve** at `39e9b8d` with seventeen sections.

- Recount at the commit you are reviewing.
- The class that has survived twice is *content* staleness, not count staleness. Check the block's
  claims against the body, particularly anything describing the floor or the predicate.

## Settled — do not reopen

- **F1, F2, F3, F5, F6**; the **narrowed D1 blocking clause**; the **upstream return-shape ruling**;
  **M2** — all three F1–F6 verifications. **D6.1** — two of the three.
- **D4's repo-wide count of 13**, **"nothing is routed at HEAD"**, and the pre/post-table
  `5 / 13 / 13` → `4 / 12 / 13` framing — re-derived by multiple rounds.
- **The extension-model-path exclusion is the right disposition**; the **coverage/rejection split's
  timing argument**; **classifier 2's cursor-loss membership criterion** — all ruled explicitly.
- **The ABI enumeration**: three rowless slots, `on_budget_plan` at `! {Env, FS}`, four at nine
  effects. Confirmed by both seventh-pass reviews. A1 above builds on it rather than reopening it.
- **Classifier 1's four scan repairs** and **classifier 2's two call sites** — both re-derived twice.
- **`ProviderState`'s home in `src/core/ports.ail` is buildable** — two independent probes.
- Configuration facts: fourteen configs, all installing `compaction_ai`; `compose` in one;
  `test_dummy` in none; `motoko_ext_conformance` non-registrable.

## Leads already checked — do not re-derive

- `ExtPorts.clock_now` has **zero call sites repo-wide**; `.ai_step(` has exactly two.
- The textual `ai_step` grep selects five packages, including both guards, on scaffolding only.
- `ailang builtins list -json` yields 21 modules; the repo imports 21 distinct `std/*` modules; ten
  have no effect-bearing row; the source half recovers `std/sem` and `std/extension`.
- `ailang --version` carries a `Full:` commit equal to the scan root's `rev-parse HEAD` on this
  machine, stamped by `install-prerequisites.sh:586`.
- `microrag_tool_policy` returns a constant `NoOpinion`.
- Neither classifier, nor the attribution table, is wired into CI, the Makefile, or `scripts/`.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors.** Build probes in scratch
  directories outside the repository, as every prior round has.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`.

## Output contract

Append an **eighteenth** `## Review Comments` section to the ADR. There are seventeen. **Count them
yourself at the commit you are reviewing** — a previous handoff said "third" and was executed three
times, and the Status block has twice carried a stale count for exactly this reason.

Do not rewrite the body, and do not edit any existing review section. All seventeen are historical
records.

State your model id, the date, and the commit you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name what you re-ran and confirmed. Three deserve an explicit ruling:
   whether the extension-granularity rule should be narrowed to non-rowless hooks and what that does
   to the carve-out (A1), whether the floor-plus-disclosure pair is coherent and decidable (A2), and
   whether `ailang iface` is usable as normative gate infrastructure (A5).
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
  candidates, in order: A1's narrowing dissolving the carve-out, A3's concentrated wrong-positive risk
  now that dominance is gone, and A5's scanner not being gate infrastructure.
