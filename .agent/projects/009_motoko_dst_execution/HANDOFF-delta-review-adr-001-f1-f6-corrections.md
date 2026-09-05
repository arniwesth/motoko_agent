# Handoff: delta review of the F1–F6 correction pass in ADR-001-deterministic-test-world-architecture.md

> **EXECUTED AND SPENT — 2026-08-01.** Run twice, independently: Claude Code `opus-5` (R1–R7) and
> Codex `GPT-5` (R1–R8), both *Revise*, both recorded in the ADR as its sixth and seventh
> `## Review Comments` sections. Do not execute this handoff again.
>
> **Both reviews overturned A1 below.** A1 asserts that D5 obligation 2 fails open because
> `_resolve_call` discards `ports.model_step(...)`. That is wrong: the discarded call is a *routed*
> seam call, which is what should be absent from an ambient-effect inventory, and the parser resolves
> direct ambient calls through its bare-import path. The real disqualifiers are profile scope
> (`PROFILES["core"]` is `("src/core",)` and never contained `packages/`) and row granularity (the
> emitted rows are not sites). A1 is left as written because it is the record of a wrong diagnosis
> that a review caught — deleting it would hide the most useful thing this round produced.
>
> Two further findings neither this handoff nor its A-list anticipated: D4's "default profile"
> reachability claim is false against the checked-in configuration (Codex R3), and the Status block
> contradicted itself on blocker count (Codex R4). A third correction pass answering all of it is
> committed and **needs its own delta review**; this document does not cover it.

Audience: a fresh agent session with no context from the correcting session. Your distance from the
author is the point, and it is the whole point this round: the corrections you are reviewing were
written by the same side that decided what the three verifications meant. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**This is a delta review, not a full round.** The ADR has now had an author self-review, two
independent reviews (2026-07-26), and three independent verifications of the F1–F6 revision
(2026-08-01, all recorded at the end of the document). Six full passes have run over this text.
Re-reviewing D2, D3, D7–D11, or the architecture is not your job and will not find anything the
prior rounds missed.

## Mission

Verify the **correction pass** applied to
`.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` on
2026-08-01, committed as `d3bd9cd`.

All three 2026-08-01 verifications returned *Revise* and converged on the same defect set. The
corrections answer every convergent finding. Your target is whether they actually resolve them, and
whether the new text introduces defects of its own.

## Read this first: you cannot get the corrections by diff

`d3bd9cd` is not a correction commit. It is the **whole acceptance record** committed at once — the
F1–F6 revision body, all three verification sections, and the corrections, none of which had ever
been committed. `git show d3bd9cd` will show you the revision and the corrections tangled together
against a two-review-old baseline.

The pre-correction state was never written to the object store. The blob Codex cited in its own
review header (`374d46fbe...`) is a working-tree blob and is **not retrievable**:

```text
$ git cat-file -e 374d46fbe39ccb77b2fd4a5e71b3dabc0c70f741
NO: never written to object store
```

This is a direct, mechanical consequence of the defect Kimi filed as R8 — an acceptance record kept
in an uncommitted working tree cannot produce a clean delta afterwards. It is worth noting in your
review as a process finding if you think it is one; it is not a defect in the ADR's content.

**Because there is no diff, the corrections are enumerated exhaustively below with line numbers.**
If you find corrected text that is not on this list, that is itself a finding — it means the
enumeration is incomplete and the author's account of their own edits is unreliable.

## The corrections, exhaustively, at commit `d3bd9cd`

Line numbers are current as of the commit. All are in the ADR unless stated.

| # | Location | What changed | Answers |
|---|---|---|---|
| C1 | `4-10` Status line | Records three verifications complete, all *Revise*, converged | Kimi R8 |
| C2 | `12-16` | "Fresh delta review, not a fourth full round"; names what is not reopened | Kimi R8 |
| C3 | `18-28` | States no `## Spike-findings disposition` section exists or was meant to; the body is the record | Codex R6, Kimi R7 |
| C4 | `30-41` | Retracts the header's "the rest verified unchanged" claim | Kimi R3, Codex R4 |
| C5 | `173` Context row | "Five call sites", call-sites ≠ terminal-paths, cites the two direct returns | Claude R3, Codex R5, Kimi R4 |
| C6 | `175` Context row | Re-grounds chunk ordering off the stale `stub_step.ail:175-204` | Codex R4, Kimi R3 |
| C7 | `185-193` | New *Known stale source comment* note; defers the source fix | Kimi R3 (source half) |
| C8 | `229-239` D1 | Names one explicit `C2LoopState` field as the interim cursor home | Claude R5, Kimi R6 |
| C9 | `305-319` D1 | Scopes the port-widening rule to demonstrated loss channels | Claude R4, Codex R3, Kimi R5 |
| C10 | `596` D4 | Softens "locates such reads precisely" to conservative/over-approximate | consequential to C12 |
| C11 | `615-642` D4 | Clock table: 13 sites, routing column, nothing routed at HEAD | Claude R2, Codex R2, Kimi R1 |
| C12 | `744`, `753-784` D5 | Replaces "reachability-aware, not textual" with three ordered obligations | Claude R1, Codex R1, Kimi R2 |
| C13 | `1205-1207` Handoff item 2 | Points the F6 fix at the interim `C2LoopState` field | Claude R5, Kimi R6 |
| C14 | `HANDOFF-review-adr-001-f1-f6-revision.md:21-26,55-57,198-220` | Corrects the disposition references; closes the spent output contract; fixes the superseded "F4 measures 14" note | Codex R6, Kimi R7/R8 |

One further edit post-dates `d3bd9cd` and is uncommitted or in a later commit — check `git log` and
`git status`: the Status line at `13-15` was narrowed from "D6.1 ... confirmed by all three" to "by
two of the three", because Claude's verification records no explicit D6.1 ruling. **Verify that
narrowing is itself correct**, and that no *other* claim in C1–C2 overstates what the three sections
actually ruled on. The author caught this one after committing; assume there may be more.

## Attack list

Ordered by where I expect defects, not by severity.

### A1. C12's over-approximation argument is inverted for this substrate — confirmed, not suspected

**This is the highest-value item and it is a known-open defect in the correction, flagged by the
author rather than repaired.** It is recorded in D5 itself as an open defect (see the marker at the
end of that section). Your job is to adjudicate the repair, not to rediscover the problem.

D5 now argues that a conservatively over-approximate function-level inventory is the right tool
because "an inventory that reports more possible ambient calls than exist forces routing work, which
fails closed." **That argument requires the analysis to over-approximate, and this repo's does the
opposite.** `_resolve_call` in `tools/code-graph/extractor/source_parser.py:176-199` resolves a
dotted call only when its prefix is an *import alias*:

```python
CALL_RE = re.compile(r"(?<![.\w])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*\(")
...
    if "." in call:
        prefix, member = call.split(".", 1)
        imp = qualified.get(prefix)
        if not imp or member in ctor_names:
            return None          # <-- call is DROPPED, not over-approximated
```

For `ports.model_step(...)`, `prefix` is `ports` — a local binding, not an import alias — so
`qualified.get("ports")` is `None` and the call is discarded. **Motoko's entire effect architecture
is function-valued**: `Ports` holds six function fields (`src/core/ports.ail:17-24`), and
`ExtPorts`/`ExtensionHooks` likewise (`packages/motoko-ext-abi/types.ail:62-66,151-164`). Every
effect crossing the port seam is invisible to this graph. That is *under*-approximation, and for a
hermeticity inventory under-approximation fails **open**: a real ambient call reached through a port
closure is silently absent.

So C12 replaced an unbuildable requirement with a differently-wrong one. The sentence distinguishing
hermeticity inventory from architecture discovery reads well and its *distinction* is sound, but it
rests the recommended tool on a property that tool does not have.

- Confirm the above independently, then rule on what D5 must require instead. A conservative
  *textual* inventory of ambient-effect imports and call names per in-profile module may genuinely
  over-approximate where this call-graph does not — in which case the correction has the tool
  preference exactly inverted and the original "grep-based audit" it disparages was closer to right
  for *this* use than for the F2 use.
- Assess whether the AILANG effect-row system is the better primary detector, since a function
  performing `Clock` must declare `{Clock}` in its row. Note the known hole: latent
  under-declarations exist at HEAD (`agents_md.walk_agents` performs `FS` undeclared, per the
  Consequences section), so rows are not currently trustworthy on their own either.
- Judge whether D5 can name *any* buildable primary detector today, or whether the honest disposition
  is that the hermeticity gate's routing audit is an unsolved problem the implementation plan must
  solve before the name-adoption gate can cite it.

### A2. C11's "13" is a count over a named set of five files, not over the repo

The table counts `session.ail` (4), `ext/runtime.ail` (1), and `motoko-ext-compose` (8). Those five
files came from the spike. **Nothing in the correction establishes that the profile-reachable set is
confined to them.**

- Re-run the count yourself on pinned v0.26.0; do not inherit it. Two prior "re-grounding" passes
  each introduced fresh numeric errors, which is why this attack exists.
- Then sweep wider: `now()`, `std/clock`, and any aliased import across all of `src` and `packages`.
  If another in-profile package reads the clock, 13 is wrong in the same way 14 was, and it is wrong
  in a decision that has now carried a bad number through three revisions.
- Verify "nothing is routed at HEAD" independently, and verify the `derive_session_id`/`:791`
  attribution that replaced the phantom `conversation_loop_v2` row.

### A3. C9 may have over-corrected

The rule is now scoped to ports with a "demonstrated loss channel", which today means `model_step`
alone.

- Is that too narrow? `env_get` returning a bare value arguably loses the missing-versus-empty
  distinction; `tool_exec`'s stringly seam loses structure, though D1 widens it for a separately
  named reason. If a second field genuinely has a loss channel, the correction has swapped an
  over-general rule for an under-general one.
- Check the new text does not contradict D1's own later bullets, which it now cross-references.

### A4. C8's interim cursor home must actually be expressible

D1 now names "one explicit field on `C2LoopState`, threaded by the driver" as the interim home.

- `C2LoopState` is an immutable record threaded through recursion (`src/core/session.ail:344`
  region). Confirm the F6 fix is expressible that way — that the scripted provider can return a
  successor cursor the driver stores in that field without a second home appearing anywhere.
- Confirm C8 and C13 agree with each other and with the "sole owner" absolute they qualify.

### A5. C5, C6, C7 — the re-grounded anchors, again

Two consecutive re-grounding passes each shipped new errors in freshly re-verified numbers. Treat
this pass identically.

- Re-verify every line number in C5 and C6 at HEAD on pinned v0.26.0.
- Verify C7's claim that `stub_step.ail:170-171` is stale and `:189-190` contradicts it.
- The source fix C7 describes was **deliberately deferred**, not forgotten. Judge whether deferring
  it is right, given the ADR now anchors into a file containing a self-contradictory comment.

### A6. C3's disposition ruling

The author ruled that the missing section was a bad reference, not a missing document, and that the
normative body is the disposition record.

- Verify the body actually contains a per-finding response where C3 says it does — F1/F2 in D1,
  F3/F4 in D4, F5 in D6, F6 in D1 and Handoff item 2.
- If any finding has no locatable response, C3 is a rationalization and the section should exist.

### A7. C14's handoff edits

`HANDOFF-review-adr-001-f1-f6-revision.md` is the instruction document three reviewers executed.
Editing it after the fact alters the record of what they were asked to do.

- Check the edits are additive corrections that preserve the original contract as history, not
  rewrites that make the executed rounds look like they were asked for something else.

## Settled — do not reopen

Each of these was independently confirmed by all three 2026-08-01 verifications, on executed
evidence, and is out of scope:

- **F1** (cursor ownership), **F2** (port-widening ordering for `model_step`), **F3** (the `Clock`
  backstop is a runtime not build-time check), **F5** (event vocabulary is new construction; 3 of 34
  variants named), **F6** (scripted cursor pins under folding compaction).
- **The narrowed D1 blocking clause** is correct and does not authorize migration before acceptance.
  All three ruled on this explicitly.
- **The upstream return-shape ruling** — none of the parked options (a)/(b)/(c) changes the
  `{chunks, outcome}` type. Codex and Kimi both re-derived it from upstream's own design doc.
- **M2** (the repin forces an extension-ABI major) is correctly framed as a spike measurement.
- **D6.1's zero-`RunSummary` claim** — confirmed path-by-path by Codex and Kimi. Claude did not rule
  on it; see the Status-line narrowing above.
- **Anchors in files untouched since `7b9b4a4c`** — spot-checked by all three, they hold.

Also settled and not yours: **the upstream recorded-stream API blocker**. It is parked, unmerged,
unreleased, and external. Say what happens to it if you recommend acceptance; do not try to clear it.

## Leads already checked — do not re-derive

- `git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` returns `Makefile`
  (2-line CLI-alias change), `scripts/dst/spike_scripted_cursor_probe.ail`, `src/core/session.ail`,
  and `src/core/test/stub_step.ail`. No other anchored file moved.
- `ExtPorts.clock_now` has **zero call sites repo-wide**. Confirmed by all three.
- `ledger_record_name` names 3 of 34 `LedgerEvent` variants. Confirmed by all three.
- `scripts/dst/spike_scripted_cursor_probe.ail` exits 1 by design and is deliberately unwired.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors.** If you hit a type error
  contradicting the source you are reading, clear every `.ailang/cache` before believing it.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`, with a Makefile
  guard against drift.

## Output contract

Append a **sixth** `## Review Comments` section to the ADR. There are five: two from 2026-07-26 and
three from 2026-08-01. Count them yourself before you append — the previous handoff's contract said
"third" and was executed three times, which is the defect Kimi filed as R8.

Do not rewrite the body, and do not edit any existing review section. All five are historical
records.

State your model id, the date, and the commit you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name the corrections you re-ran and confirmed. Three deserve an explicit
   ruling: whether C11's count and routing state are right *this* time, whether C12's replacement is
   buildable and correctly biased (A1), and whether the enumeration above is complete.
2. **Recommended pre-acceptance actions** — ordered by dependency, separating what this ADR must fix
   from what belongs to the implementation plan.
3. **Accept / revise recommendation** — one line, and say explicitly what happens to the upstream
   API blocker.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, the spike, other ADRs, or this
  ADR's body during review.
- **Do not re-litigate accepted 007**, and do not re-argue the decision to request an upstream API.
- **Verify by execution.** A claim you did not re-run is a claim you cannot certify. This applies
  with particular force to C11's numbers, which have been wrong twice.
- **Do not treat the fork prototype as the gate cleared.** `arniwesth/ailang` carries a working
  `stepWithStreamRecorded` on the `v0.31.0` tag. D1 requires the API to have *landed* in a release
  and the toolchain to be *repinned*. A fork is not that.
- **Do not treat the throwaway spike branch as HEAD state.** Importing spike measurements as HEAD
  facts is the exact defect C11 corrects; do not repeat it in your own grounding.
- If the corrections hold, say so plainly and still record residual risk. The likeliest surviving
  candidates: A1 (the over-approximation argument being inverted for a function-valued architecture)
  and A2 (13 being a count over the wrong scope).
