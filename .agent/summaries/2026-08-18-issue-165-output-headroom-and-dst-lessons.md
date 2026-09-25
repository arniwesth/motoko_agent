# 2026-08-18 Issue #165: output headroom, a provider-realistic DST, and three semantic CI migrations

## Context

Branch: `arniwesth/mot-100-fix-output-headroom`, targeting `main_dst`. Entry point was
[`#165`](https://github.com/arniwesth/motoko_agent/issues/165): determine whether Motoko's DST
could reproduce a real shared-context provider rejection, implement the recommended coverage, fix
the production defect, relate it to [`#31`](https://github.com/arniwesth/motoko_agent/issues/31),
and publish the work as `motoko-agent`.

Shipped on the branch as PR [`#166`](https://github.com/arniwesth/motoko_agent/pull/166). The final
six commits are:

```text
da999ac  fix(compaction): reserve provider output headroom
0b99152  record PR #166
13093b4  fix(ci): preserve attribution anchor locations
51e1afe  test(compaction): express tiny windows after output reserve
f64b5cf  test(compaction): generate raw seal windows with reserve
2e0a7df  docs(compaction): state output-budget invariant
```

The operator reported all PR checks green at the end of the session.

## The defect

Motoko resolved a model's raw shared context window and used it as though the entire window were
available for input. For the reported case:

```text
raw context window       262,144
requested output budget   65,536
safe whole-input budget  196,608
```

After structural compaction, the exact issue fixture reconstructed a 207,239-token provider
payload. The old input-only check saw 79% of the raw 262,144-token window and allowed the call. It
left only 54,905 tokens for a response whose configured allowance was 65,536, so a shared-window
provider could reject before generation.

The policy error was not in structural compaction itself. It was the coordinate used by both the
extension-facing compaction budget and the post-extension payload seal: each treated a raw provider
capability as a usable input budget.

## DST reproduced it without a live provider

The useful test substrate was not another scripted response. It was an opt-in provider constraint:

```ailang
bounded_scripted_ports({
  context_window,
  max_output_tokens
})
```

The wrapper independently computes a deterministic char/4 provider input estimate and rejects when:

```text
estimated input + max output tokens > context window
```

It returns non-retryable `E_PROVIDER_CONTEXT_LENGTH`, emits nothing, and does not consume the
scripted response cursor. Accepted requests delegate to `scripted_ports()` unchanged. A zero window
or malformed negative allowance deliberately leaves the base provider unbounded so policy-only
fail-open scenarios remain expressible.

The wrapper does not call the production `effective_input_limit` helper. This is load-bearing:
using the production decision as the provider oracle would allow both layers to agree on the same
mistake. Its independence is specifically arithmetic, not tokenizer fidelity; real-provider
telemetry and the existing calibration path remain responsible for correspondence to provider token
counts.

Unit coverage pins the external contract exactly:

```text
input + allowance == window      accepted, scripted step consumed
input + allowance == window + 1  rejected, scripted step preserved
zero/malformed capacity          delegates unchanged
```

## The regression coverage shape

The issue coverage has two layers.

**Layer 1 — exact boundary and direct seal.** It reconstructs the measured 262,144/65,536 case,
proves that the independent provider accepts equality and rejects one token over, runs the real
structural compactor, and proves the final seal rejects the 207,239-token payload that the raw 79%
check previously admitted.

The near-megabyte string fixture is built by repeated doubling rather than `std/string.repeat`:
AILANG v0.33.0's repeat implementation is recursive and reaches the interpreter depth ceiling at
this scale. Fixture construction therefore does not become the resource failure under test.

**Layer 2 — the real driver, with three arms.** The three arms prevent a negative assertion from
passing vacuously:

| Arm | Input class | Required observation |
|---|---|---|
| A | #165 unsafe after structural floor | `ContextExhausted`; no `ProviderCallPrepared` or `ProviderResult`; extension observes the derived segment budget |
| B | safe neighboring payload | provider path is live: one preparation, one result, successful run |
| C | beyond the raw window | existing raw-exhaustion terminal remains live; provider still not called |

Arm B proves that Arm A's zero provider calls are caused by admission policy rather than a
disconnected port. Arm C proves the new output-headroom path did not collapse every large input into
one indistinguishable terminal.

Two more driver controls pin the deliberate fail-open policy:

- raw limit `0` (unknown model/catalog miss); and
- raw window at or below the output allowance.

Both resolve to effective limit `0`. `usage_percent_with_limit(..., 0)` returns `0`, so the seal
returns `Ok` and the unbounded scripted provider is reached. This is explicit policy, not an
accidental division-by-zero behavior.

## The production fix

`src/core/compaction.ail` now owns the shared derivation:

```ailang
output_token_allowance() = 65536

effective_input_limit(raw) =
  if raw <= output_token_allowance() then 0
  else raw - output_token_allowance()
```

The same effective whole-input budget is consumed at both production seams:

1. The driver subtracts pinned-message tokens from it before constructing the extension's
   compactable-segment context.
2. `seal_compacted_payload` reconstructs the final payload after the pre-step extension chain and
   evaluates it against the effective budget immediately before provider preparation.

The derivation sequence is therefore observable as:

```text
raw provider context window
  - output allowance
  = effective whole-input budget
  - pinned-message tokens
  = extension compactable-segment budget
```

The raw catalog window remains raw in policy records and telemetry. The implementation derives a
policy view rather than relabeling the provider capability, which keeps diagnostics truthful and
makes it possible to see where each subtraction occurred.

The final seal is intentionally after the last payload mutator. Pre-step extensions can transform
the compactable segment; an initial compaction decision cannot guarantee that the reconstructed
post-extension payload is still admissible.

## The 65,536 constant: correct current invariant, visible external coupling

A later branch review correctly observed that Motoko hardcodes one 65,536-token reservation and
does not read a per-model output limit. The first conclusion drawn from that observation was too
broad: a model's theoretical ability to emit 128k does not imply that AILANG requests 128k. The
relevant quantity is the maximum configured on the actual provider request.

Inspection of the pinned AILANG v0.33.0 source established:

- every active model-registry `max_output_tokens` value is at or below 65,536;
- the cloud registry has an executable invariant requiring 65,536 or an enumerated lower provider
  ceiling;
- known lower entries range through 4,096, 8,192, 16,384, 32,768, and 64,000;
- direct/unknown handlers normally default to 4,096; and
- the Ollama agent path floors small requests to 16,384, while an explicit environment override
  could exceed the Motoko assumption.

AILANG's CLI passes the registry value into the handler used by `std/ai.stepWithStreamRecorded`.
Under the pinned policy, 65,536 is therefore safe but may over-reserve models configured lower,
causing premature compaction. It becomes unsafe if AILANG later permits a configured request above
65,536 or an override raises one without Motoko learning the resolved value.

The source and PR description now state this accurately: `std/ai` does not expose the resolved
per-call output budget, so Motoko mirrors an external invariant. The clean long-term design is not
a second independently maintained Motoko catalog field; it is one resolved request budget consumed
by both the provider request and `CompactionPolicy`.

## Three CI failures, none fixed by weakening the new contract

The first implementation and focused tests were green. The PR workflow then found three different
migration costs in sequence.

### 1. Attribution anchors moved

Adding lines in `session.ail` and `stub_step.ail` moved pinned source-coordinate attribution
anchors. The anchored behavior had not changed, but `make anchors` and the attribution artifacts
correctly detected coordinate drift. Imports were widened in place, additions were placed around
the anchored sites, and the original line locations were preserved in commit `13093b4`.

This was a non-behavioral failure, but not noise: project 009 deliberately makes those coordinates
auditable identities. The session is further evidence of their migration cost and of the need to
run anchor gates early.

### 2. Existing tiny-window fixtures changed semantic class

`phase_c_l1_scenarios.ail` and `world_state_probe.ail` used raw values `10` and `1` while intending
tiny **input budgets**. After output reservation, both were raw windows below 65,536 and therefore
became deliberate fail-open cases.

The fixtures were corrected to construct raw windows as:

```text
output_token_allowance() + intended input budget
```

This retained their original behavioral intent under the new field semantics. The actual merged
tree with current `main_dst` passed both scenarios.

### 3. The seeded generator used the same ambiguous coordinate

`phase_c_seeded_dst.ail` generated a value such as `464` under the name `limit` and passed it
directly as a raw context window. It too collapsed into the fail-open class. The generator now names
the draw `input_limit`, derives `raw_limit = output_token_allowance() + input_limit`, and passes the
appropriate quantity to each layer.

`DST_SEEDS=5 DST_BASE_SEED=1 make dst_seeded` passed against the actual merged tree after the fix.

The sequence matters: focused DST proved the new contract; seeded and full-corpus DST then served as
a semantic migration detector for old fixtures whose values remained syntactically valid but no
longer represented the asserted scenario.

## Relationship to #31

Issue #31 reports oversized tool results entering history and overflowing the context. Issue #165
is a downstream containment layer: it prevents an impossible provider call after compaction and all
payload mutations. It does not truncate or split the tool result, prevent oversized ingestion, or
recover an already overfull conversation.

The accurate failure chain is:

```text
tool-result/input shaping
  -> history storage
  -> compaction
  -> final provider admission        #165 / PR #166
  -> provider rejection mapping
  -> recovery                         #31 still open
```

The initial #31 wording said #165 “closes the provider-overflow hole,” which was broader than the
evidence. A bot-authored qualification now says that #165 closes the downstream admission hole for
AILANG's current configured output budgets at or below 65,536, while #31's upstream shaping and
recovery remain open.

## GitHub actions and identity

The repository's `tools/pr/lib.ts` identity mechanism was used for every write. It resolved and
printed `motoko-agent` before acting:

- opened PR #166 as `motoko-agent`;
- answered #165 with the implementation and PR link;
- linked #31 back to #165;
- updated the PR description with the external AILANG invariant; and
- posted the qualification on
  [#31](https://github.com/arniwesth/motoko_agent/issues/31#issuecomment-5333345310).

`gh pr edit` attempted an unrelated GraphQL project-metadata query and failed because the bot's
classic PAT has `public_repo` but not `read:org`. No write occurred through that path. The same
bot-authenticated update was sent through GitHub's REST issue endpoint, which needs only the
existing scope. This is another reason to use the repository identity wrapper rather than ambient
`gh`: the mechanism both guarantees authorship and makes a transport fallback possible without
changing identity.

The PR's source-of-truth body remains at `.agent/github/prs/origin-166/body.md` and was committed
with the clarified description.

## DST architecture lessons retained

The session's reusable findings are recorded in:

`.agent/projects/013_core_architecture_for_dst/NOTE-issue-165-dst-architecture-findings.md`

The note distinguishes observations from undecided follow-ups and records fifteen lessons:

1. Primitive integers hide semantic units such as raw window versus usable input budget.
2. Numeric `0` collapses unknown, disabled, malformed, and undersized states into one sentinel.
3. A useful oracle derives from the external contract rather than the production decision helper.
4. Constant-difference metamorphic tests can reveal hidden constants and coordinate confusion.
5. Configuration coherence across Motoko and AILANG is an integration boundary of its own.
6. Shared fixture constructors are semantic migration infrastructure, not merely deduplication.
7. The full corpus detects stale scenario meaning after focused tests prove the new contract.
8. Negative-effect evidence needs a neighboring liveness control to avoid vacuity.
9. Invariants belong after the last mutator and before the first irreversible effect.
10. Raw and derived budgets should remain separately observable through every derivation stage.
11. Provider realism should be an opt-in composable capability, not a global strengthening of fakes.
12. Numeric admission rules need below/equality/one-over boundary coverage.
13. Oracle independence must name its dimension: arithmetic, measurement, configuration, or substrate.
14. Downstream failure containment must not be credited as upstream root-cause remediation.
15. Absolute source-coordinate anchors impose migration costs unrelated to behavior and should be
    distinguished from semantic reclassification when the artifact permits.

The note's lowest-cost candidate group is semantic fixture constructors, explicit generator
domains, a written independent-oracle rule, live controls for absence assertions, boundary triples,
and named budget-stage diagnostics. None has been promoted to a WI or architecture decision.

## Verification

Evidence accumulated during implementation and CI repair:

```text
make compaction_dst                             8/8 scenarios
make smoke_driver                              PASS
make check_core                                57/57
ailang test src/core/phase_vocab.ail            28/28
ailang test src/core/session.ail                23/23
ailang test src/core/test/scripted_ports.ail    10/10
ailang test src/core/compaction.ail              8/8
make anchors                                   PASS, 10 anchors
make attribution_table                         PASS
DST_SEEDS=5 DST_BASE_SEED=1 make dst_seeded    PASS
git diff --check                               PASS
```

The GitHub Actions corpus and verification checks were reported green after commit `2e0a7df`.

## State at handoff

- PR #166 is open, green, and ready for review/merge.
- The production branch is pushed through `2e0a7df`.
- Per-call output-budget plumbing remains a moderate AILANG/Motoko substrate follow-up; the current
  implementation intentionally mirrors AILANG's pinned at-most-65,536 policy.
- #31 remains open for tool-result truncation/splitting and recovery.
- The DST architecture note from this session is written but uncommitted.
- This session summary is also uncommitted.
- Pre-existing user changes in `.motoko/config/default/config.json` and `ailang.lock` remain
  untouched.
