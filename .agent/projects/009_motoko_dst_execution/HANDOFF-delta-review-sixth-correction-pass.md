# Handoff: delta review of the sixth correction pass to ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the correcting session. The corrections you are
reviewing were written by the authoring side in response to two delta reviews. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**Narrow delta review.** The ADR carries thirteen `## Review Comments` sections: two full reviews
(2026-07-26), three verifications of the F1–F6 revision, and eight delta reviews of correction passes
two through five (all 2026-08-01). The architecture is settled and has been re-derived by every round.
Your target is one commit plus a one-line follow-up.

## Mission

Verify the **sixth correction pass**, which answers all eight findings from the two delta reviews
recorded as the ADR's twelfth and thirteenth sections.

## Target range

```text
d1b5c14  the two fifth-pass delta reviews (verbatim, committed before any response)  <-- BASELINE
6eca7fe  sixth correction pass
<HEAD>   delta-review-count correction (see A6) + this handoff
```

```text
$ git diff d1b5c14..HEAD -- .agent/projects/009_motoko_dst_execution/
```

Exhaustive, no hand-maintained edit table. The untracked `mmd/` directory is out of scope.

## The one thing that is an authoring choice, not a review recommendation

**A1 is an adjudication where both reviews offered a menu.** For the rejection predicate they each
gave two options — extend D4's site-to-hook attribution table to extension packages, or adopt a
coarser extension-granularity rule. The pass took the coarse rule and made it the interim gate. That
trades precision for decidability, and it is the text you should push hardest on.

## Attack list

### A1. The extension-granularity rejection rule, and whether it collides with the coverage floor added in the same pass

D1 and D5 now say: an installed extension that **textually references** a classifier-2 `ExtPorts`
field must have **every hook it registers** excluded, or the profile definition is rejected.

1. **Is the coarse rule right?** It is decidable today from a grep plus `register.ail` and it fails
   closed. It also excludes seven hooks of `compaction_ai` that never touch the port. Argue whether
   the precision loss is acceptable as an interim gate, or whether the attribution-table refinement
   should have been required up front.
2. **Does it collide with the coverage floor?** The same pass added: a conformant profile must cover
   at least one hook of every extension it installs, or not list it as installed. For an
   `ai_step`-referencing extension the two rules point opposite ways — all hooks excluded (rule) but
   at least one covered (floor). The ADR resolves this by naming the `ai_step` case an exception. **Check
   whether the exception is specified well enough to be one**: it must be recorded in the profile
   definition, but the seven-plus-one bullet list at the versioned-profile-definition record has no
   slot for it. If the exemption is ambient, the floor is weaker than it reads.
3. **Is "every hook it registers" decidable?** It requires reading the extension's registration.
   Confirm the hook set is always statically visible there and cannot be built conditionally.
4. **The second `ai_step` reference is in a fixtures package** —
   `packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90`. Under extension granularity,
   what happens if that package is ever installed? The ADR does not say whether fixture packages are
   in scope for classifier 2.

### A2. Classifier 1's stdlib source scan — is the pattern complete, and is the path gate infrastructure?

The detection set is now the union of the builtin projection and a scan of
`~/.local/share/ailang/std/*.ail` for `export func … ! {…}` with a non-empty row, plus a mandatory
reconciliation against the repo's actual `std/*` imports.

- **Is `export func … ! {…}` a complete pattern for effectful stdlib exports?** Consider effects
  arriving through re-exports from another `std` module, through a function whose row is inferred
  rather than annotated, or through any declaration form that is not `export func`. If a fourth
  mechanism exists, this is the fourth consecutive revision of the obligation to fail open, and the
  ADR now claims in its own voice that the reason is recorded.
- **Is a path under `~/.local/share/ailang/` acceptable as gate infrastructure?** It is a user-home
  location, not a repo path or a pinned artifact. Rule on whether the derivation is reproducible in
  CI or on another machine.
- Verify the reconciliation check actually recovers `std/sem` and `std/extension`, and that it
  handles a module imported transitively rather than directly.

### A3. The coverage floor is adopted from a review recommendation but has never itself been reviewed

- **What does "cover" mean here precisely?** D5 defines covered as effect-free or world-mediated. So
  the floor requires at least one hook per installed extension to be one of those. Check that this is
  satisfiable for the profiles the ADR contemplates — in particular the purpose-built narrow profile
  built from `empty_stop_guard` and `progress_contract_guard`.
- Does the floor interact with D11's coverage counters, or with the `Is the tested boundary honest?`
  acceptance row it was added to?

### A4. The attribution table's correctness condition may not be checkable by the validator that is supposed to check it

The table now has contents, source-revision binding, scope, a load-time fail-closed validator, a
producer, and a scheduling prohibition. Its correctness condition is: *installation of at least one
attributed hook is a **necessary** condition of the site executing.*

- **How does a validator check necessity without the path analysis this decision refuses to build?**
  The pass claims the condition is "stated as a checkable claim rather than left to the author's
  judgement". Test that claim. If necessity is only manually reviewable, the validator catches schema,
  staleness, and unknown hooks but **not** the wrong-positive attribution that is the failure the
  fail-closed default already misses — and the ADR should say so rather than imply otherwise.
- Check the post-boundary scope restriction against the simulation-boundary text it references.

### A5. Anchors introduced or changed in this pass

All unverified by any reviewer:

`~/.local/share/ailang/std/sem.ail:374,385`; `~/.local/share/ailang/std/extension.ail:27`;
`src/core/cache.ail:29,60,75`; `src/core/rpc.ail:200`;
`packages/motoko-ext-omnigraph/register.ail:4`;
`packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90`;
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`; the eight-hook claim at
`packages/motoko-ext-compaction-ai/register.ail:99-110`;
`packages/motoko-ext-compose/compose.ail:761-790` and `:767`; and the separated guard lines
(`206, 222, 239, 280, 368`) versus call lines (`206, 222, 245, 287, 374`) in
`src/core/ext/runtime.ail`.

**Five consecutive passes have shipped anchor errors**, including one in an edit whose only purpose
was fixing an anchor. The ADR now says so in its own Status block. Assume a sixth.

### A6. The Status block — including a count the authoring side got wrong again and caught itself

Both fifth-pass reviews found the delta-review count stale because the previous pass applied a
correction relative to the *baseline* rather than the commit being written. **The sixth pass repeated
the identical mistake**: it wrote "six independent delta reviews" while producing a commit containing
eight. The follow-up commit in your target range corrects it to eight.

- Recount at the commit you are reviewing. Two full reviews, three F1–F6 verifications, and eight
  delta reviews should total thirteen sections at `6eca7fe`.
- Check the rest of the Status block for the same class of staleness, and for self-contradiction.
- The fifth-pass round's R6 action said explicitly: "Recount the review sections at the commit being
  written, not at the commit being answered." That instruction was in front of the authoring side and
  was still missed. If there is a structural fix — a check rather than a resolution — it is worth
  naming.

### A7. Collateral

- Does the extension-granularity predicate now read identically at D1, D5's exclusion paragraph,
  D5's validation bullet, classifier 2, and the acceptance row? The fifth pass had four different
  phrasings; this pass claims to have collapsed them to one.
- Does the declared-versus-performed ruling for per-hook classification contradict anything in D5's
  hermeticity probe?
- Does D4's 4 / 12 / 13 arithmetic survive, given the attribution table's scheduling prohibition now
  says "four driver clock reads" is not derivable until the table validates?

## Settled — do not reopen

- **F1, F2, F3, F5, F6**; the **narrowed D1 blocking clause**; the **upstream return-shape ruling**;
  **M2** — all three F1–F6 verifications. **D6.1** — two of the three.
- **D4's count of 13** and **"nothing is routed at HEAD"** — re-derived by every delta round.
- **The extension-model-path exclusion is the right disposition**, and **the coverage/rejection
  split's timing argument is sound** — both ruled explicitly by both fifth-pass reviews.
- **`ProviderState`'s home in `src/core/ports.ail` is buildable** — two independent three-module
  probes typechecked clean on pinned v0.26.0.
- **Clause 3's necessity-not-sufficiency attribution semantics** — endorsed by both fifth-pass
  reviews as the correct answer to mixed guards. A4 above is about its *validator*, not its semantics.
- **Classifier 1's label and module arithmetic** — 17 effect labels plus `Pure`, 21 projected modules,
  12 in `[effects] max`, no non-`std/*` impure rows. Confirmed twice. A2 is about completeness, which
  is a different question and the one that failed.
- Second-pass corrections **C3, C4, C5, C9, C14**; all configuration facts (fourteen configs, all
  installing `compaction_ai`; `compose` in one; `test_dummy` in none).

## Leads already checked — do not re-derive

- `ExtPorts.clock_now` has **zero call sites repo-wide**.
- `ailang builtins list -json` is byte-deterministic across runs; its `name` is the internal builtin
  (`_clock_now`), never the exported wrapper.
- All three import forms typecheck on the pin: bare, `as`-aliased, and `as`-qualified-selective.
- `std/sem`'s only builtin rows are the pure `_embedding_decode`/`_embedding_encode`.
- `agents_md.walk_agents` performs `FS` undeclared and v0.26.0 accepts it.
- Neither classifier, nor the attribution table, is wired into CI, the Makefile, or `scripts/`.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors.** Every prior round built probes in
  scratch directories outside the repository; do the same.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`.

## Output contract

Append a **fourteenth** `## Review Comments` section to the ADR. There are thirteen. **Count them
yourself at the commit you are reviewing** — a previous handoff said "third" and was executed three
times, and the authoring side has now twice written a stale review count into the Status block for
exactly this reason.

Do not rewrite the body, and do not edit any existing review section. All thirteen are historical
records.

State your model id, the date, and the commit you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name what you re-ran and confirmed. Three deserve an explicit ruling:
   whether the extension-granularity rule and the coverage floor are compatible (A1), whether
   classifier 1's source scan is complete and reproducible (A2), and whether the attribution table's
   correctness condition is checkable by its validator (A4).
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
  candidates, in order: A1's floor/rule collision and its unslotted exception, A2's source-scan
  pattern being incomplete or its path being unreproducible, and A4's correctness condition being
  manually-reviewable-only.
