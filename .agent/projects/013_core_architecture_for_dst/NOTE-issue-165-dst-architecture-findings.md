# NOTE: DST architecture findings from issue #165

Date: 2026-08-18
Status: Observation and follow-up candidates — no architecture decision
Source session: [`motoko_agent#165`](https://github.com/arniwesth/motoko_agent/issues/165)
Implementation: [`motoko_agent#166`](https://github.com/arniwesth/motoko_agent/pull/166)
Relates to:
- `RESEARCH-core-architecture-for-dst.md` in this directory
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md`
- `.agent/projects/011_improve_test_axises/NOTE-dst-substrate-versus-oracle.md`

---

## 0. Scope

Issue #165 reported a provider admission failure at a shared context-window boundary: a
262,144-token context window, a 65,536-token output allowance, and an input payload that was
legal when checked against the raw window but impossible when input and output were considered
together. PR #166 introduced an effective input budget, a final payload seal, boundary coverage,
and an opt-in bounded scripted provider.

The implementation work also exposed test failures outside the new scenarios. Existing fixtures
had supplied small integers such as `1`, `10`, and generated values such as `464` as
`context_limit`. Before #166 those values behaved as tiny input limits. After #166 the field was
interpreted as a raw shared window, so any value at or below the 65,536-token output reservation
resolved to `0` and deliberately failed open. The fixtures still type-checked, but their values no
longer represented the state their assertions claimed to exercise.

This note records the general DST lessons from that migration. It does not reopen #165's scoped
policy or decide that each proposed follow-up should be implemented.

---

## 1. Plain integers hide distinct semantic units

### Observation

`context_limit: int` has been used in tests to mean at least two different quantities:

1. the provider's **raw shared context window**; and
2. the **usable input budget** against which compaction and sealing operate.

They were numerically interchangeable before output headroom was reserved. They are no longer
interchangeable:

```text
effective input budget = raw context window - requested output allowance
```

Consequently, a syntactically valid fixture can silently move into another semantic class when a
policy begins distinguishing the two quantities. This is not specific to token accounting. The
same risk applies wherever DST uses one primitive type for request budgets, cumulative budgets,
timeouts, ordinals, byte counts, percentages, or provider capabilities.

### Generalisation

DST inputs should name the semantic coordinate in which a value is expressed. At minimum, shared
fixture constructors should make conversion explicit:

```ailang
raw_window_for_input_budget(input_budget, output_allowance)
```

A stronger future representation would use records or distinct constructors such as
`RawContextWindow`, `InputBudget`, and `OutputAllowance`, with conversion at one policy boundary.
This would make the wrong coordinate harder to pass accidentally and make generated domains easier
to audit.

---

## 2. `0` is an overloaded sentinel and therefore a coverage blind spot

### Observation

The resolved limit `0` currently covers several different states:

- an unknown model;
- a catalog miss;
- explicitly disabled enforcement;
- a malformed or undersized raw window; and
- a window no larger than the output reservation.

The fail-open behavior is intentional and covered. The architectural problem is that resolution
erases the reason before downstream policy and DST observe it. In #165, this allowed old tiny-limit
fixtures to become indistinguishable from unknown or disabled limits and return `Ok` at `0%` usage.

### Generalisation

Sentinel values compress distinct scenario classes into the same observable state. That weakens
both scenario generation and diagnostics. A future resolved shape could preserve the distinction:

```text
Unknown
Disabled
Bounded(input_budget)
InvalidWindow(raw_window, output_allowance)
```

The production policy may still choose to fail open for several arms, but DST could then prove
that each arm reached the intended reason rather than merely observing the same numeric result.

Until such a representation exists, generators and hand-written fixtures should label these
classes explicitly and avoid treating arbitrary small positive integers as valid bounded windows.

---

## 3. A useful DST oracle must be independent of the production decision

### Observation

PR #166's bounded scripted provider checks the external capacity contract directly:

```text
estimated input + configured max output <= configured context window
```

It does not call `effective_input_limit`, the helper exercised by production compaction and the
seal. This separation is load-bearing. Had the provider wrapper reused the production helper, the
implementation and oracle could have agreed on the same incorrect arithmetic and kept every test
green.

### Generalisation

Provider, capacity, accounting, permission, and lifecycle oracles should be derived from the
external contract, not from the function under test. Reuse is appropriate for neutral test-data
construction, but not for the predicate that decides whether the system is correct.

For every reusable DST oracle, its documentation should answer:

1. Which external rule does it implement?
2. Which production helpers does it deliberately not reuse?
3. Which observable failure proves the boundary rejected the request?

This gives the substrate a defence against correlated implementation mistakes rather than only a
second execution of production policy.

---

## 4. Metamorphic relations can expose hidden constants and coordinate confusion

### Observation

The #165 coverage proves one concrete pair: a 262,144-token raw window and a 65,536-token output
allowance produce a 196,608-token input budget. That is necessary regression coverage, but a single
pair cannot distinguish a genuinely parameterised policy from one that happens to contain the
expected constant.

### Generalisation

A reusable metamorphic property is:

> Holding `context_window - output_allowance` constant must hold compaction and seal behavior
> constant for the same input history.

For example:

```text
{ context_window: 262144, output_allowance: 65536 } -> input budget 196608
{ context_window: 204800, output_allowance:  8192 } -> input budget 196608
```

The same message history should cross compaction and seal boundaries identically in both cases,
while the independent provider oracle should accept or reject according to the sum in each
configuration. Varying both operands while preserving their difference detects:

- a hardcoded allowance;
- use of the raw window in one driver arm;
- subtraction performed twice;
- test data expressed in the wrong coordinate; and
- divergence between extension-facing and final-seal limits.

This relation belongs naturally with project 011's metamorphic axis, but #165 supplies a concrete
cross-layer instance rather than a generic recommendation.

---

## 5. Configuration coherence is a first-class integration boundary

### Observation

Motoko currently resolves the raw context window from its catalog/configuration. AILANG resolves
the output request budget when it constructs the provider handler. `std/ai` does not expose the
resolved per-call output budget to the Motoko program.

At the pinned AILANG version, active model-registry entries configure at most 65,536 output tokens,
so #166's reservation is safe under that policy and conservatively over-reserves models configured
lower. The correctness invariant nevertheless spans two independently resolved values:

```text
Motoko reserved output >= AILANG requested output
```

A source comment can document this coupling, but Motoko's current DST cannot prove it against the
actual live handler configuration. A future AILANG registry change or provider-specific override
could violate the relationship without changing Motoko code.

### Generalisation

Configuration resolution should be treated as an observable integration phase, not merely setup.
A coherence probe should eventually resolve, record, and compare the properties that jointly
govern a provider call:

- model identity and route;
- raw context window;
- requested maximum output tokens;
- reasoning budget or mode;
- provider-specific overrides; and
- any fallback used for a catalog miss.

The strongest design is one source of truth for the requested output budget, consumed by both the
provider request and `CompactionPolicy`. Duplicating `max_output_tokens` into a second Motoko-only
catalog would improve precision but would not remove drift. Exposing the resolved request budget
through the AILANG substrate, or making it an explicit call parameter, would.

---

## 6. Shared fixture constructors are semantic migration infrastructure

### Observation

The later CI failures were not new defects in the seal. They were distant fixtures constructing
policies with the old meaning of `context_limit`. Because record literals and arbitrary integers
were repeated across the suite, the semantic migration had to be discovered by the full corpus and
repaired site by site.

### Generalisation

Central fixture constructors should encode ordinary, valid production relationships. Tests should
need deliberately named escape hatches for abnormal states:

```text
policy_for_input_budget(...)
policy_for_raw_window(...)
policy_with_unknown_limit(...)
policy_with_undersized_window(...)
```

This is not primarily deduplication. It creates a change-impact boundary: when the meaning of a
shared field changes, the normal fixture population migrates through one constructor, while tests
of malformed and fail-open behavior remain visibly exceptional.

Seeded generators need the same treatment. Their generated variable should be named for the
semantic domain (`input_budget`, not an ambiguous `limit`), and conversion to the production field
should occur once after generation. Otherwise a broad numeric generator can spend most of its
draws in an unintended sentinel class while still reporting healthy seed coverage.

---

## 7. Full-corpus DST detects semantic migrations, not only runtime regressions

### Observation

The focused #165 tests established the new contract and passed. Subsequent full checks found old
fixtures whose inputs no longer represented their asserted scenario. The failures therefore
provided information that the focused suite could not: they mapped the blast radius of a changed
semantic interpretation across the existing test corpus.

### Generalisation

The DST layers have complementary jobs:

| Layer | Primary job in a semantic change |
|---|---|
| Focused example/boundary DST | Prove the reported contract and exact boundary |
| Seeded/property DST | Explore nearby values and generated scenario classes |
| Independent substrate oracle | Reject behavior that violates the external system contract |
| Full corpus | Detect fixtures and consumers carrying stale semantic assumptions |

A green focused suite is therefore not evidence that a shared policy-field migration is complete.
When a primitive field changes meaning, the full corpus should be interpreted as a semantic
migration gate. Failures should be classified as either production regressions or stale scenario
encodings; silently weakening the assertion to restore green would destroy that signal.

This also suggests a useful reporting improvement: corpus failures should include the resolved
scenario class and both raw and derived quantities. For #165 that would mean logging at least the
raw window, output allowance, effective input budget, estimated input, and resolution reason.

---

## 8. Negative evidence needs a reachability control

### Observation

The real-driver regression used three arms rather than asserting only that the unsafe request made
zero provider calls:

- **Arm A:** the #165 payload must terminate with `ContextExhausted` before
  `ProviderCallPrepared` or `ProviderResult`;
- **Arm B:** a safe neighboring request must reach the scripted provider and succeed; and
- **Arm C:** an input beyond the raw window must still reach the existing raw-exhaustion terminal,
  without being confused with Arm A's output-headroom failure.

Arm B is a liveness witness for Arm A. Without it, zero provider calls could mean the provider port
was disconnected, the model phase was unreachable, or the scenario stopped for an unrelated
reason. Arm C establishes discrimination: the new rejection path did not merely turn every large
request into one undifferentiated failure.

### Generalisation

Assertions about the **absence** of an effect need a neighboring scenario proving that the effect
was reachable through the same wiring. Assertions about one terminal reason also need a control
showing that adjacent terminal reasons remain reachable and distinguishable.

A reusable DST scenario family should therefore pair:

```text
forbidden effect under unsafe input
live effect under safe input
distinct existing terminal under its own input class
```

This turns “nothing happened” from a potentially vacuous observation into evidence about the
production decision boundary.

---

## 9. Enforce invariants after the last payload mutator

### Observation

Sizing the history before pre-step compaction is insufficient. Extension hooks can transform the
compactable segment, after which the driver reconstructs the provider payload from pinned messages
and the transformed segment. A correct initial decision does not prove that this final payload is
safe.

PR #166 therefore applies the payload seal after the pre-step chain and reconstruction, immediately
before `ProviderCallPrepared`. The unsafe arm also asserts that neither preparation nor a provider
result was emitted.

### Generalisation

An invariant should be re-established after the last component allowed to invalidate it and before
the first irreversible external action. For provider admission the relevant sequence is:

```text
initial sizing
  -> extension transformations
  -> payload reconstruction
  -> final seal
  -> ProviderCallPrepared
  -> provider effect
```

DST should exercise both the mutator and the final guard. Testing the guard only against an
unmodified payload leaves the transformation seam unproved. The same principle applies to tool
arguments after policy hooks, filesystem paths after resolution, and commands after extension
composition.

---

## 10. Budget derivation should remain observable stage by stage

### Observation

The driver does not pass one undifferentiated limit through every layer. It derives a sequence:

```text
raw provider context window
  - requested output allowance
  = effective whole-input budget
  - pinned-message tokens
  = extension compactable-segment budget
```

For #165's 262,144-token raw window, the whole-input budget is 196,608. The extension-facing value
is smaller again because the pinned prefix is outside the segment the extension may compact. At the
same time, telemetry and catalog reporting retain the raw 262,144-token fact rather than relabeling
the derived input budget as the model's context window.

### Generalisation

Preserve source facts and derive policy views. Replacing a raw fact in place makes telemetry
misleading and hides where a subtraction occurred; passing only a raw value everywhere invites
each consumer to derive a different policy view.

DST diagnostics and assertions should expose every budget transition with named quantities. This
detects subtraction at the wrong layer, subtraction twice, omission of pinned costs, and accidental
use of a segment budget as a provider capability. The principle generalises to cumulative versus
per-step cost budgets, wall-clock versus remaining time, and raw versus normalized resource sizes.

---

## 11. Realistic constraints should be opt-in capabilities

### Observation

`bounded_scripted_ports({ context_window, max_output_tokens })` was added as an opt-in wrapper rather
than changing `scripted_ports()` globally. This was required because unknown-window and
reserve-exceeds-window scenarios intentionally exercise Motoko's fail-open policy. Those scenarios
are not physically meaningful provider configurations and deliberately use an unbounded provider.

Making every scripted provider enforce a shared window would have made these policy tests fail at
the provider layer, preventing them from observing the Motoko behavior they exist to specify.

### Generalisation

Provider realism is a capability that should compose with a base test substrate, not an implicit
global strengthening of every fake. A wrapper makes the chosen external constraints visible at the
scenario construction site and preserves existing uses whose purpose is to isolate another layer.

This pattern should be preferred for latency bounds, rate limits, provider grammar enforcement,
filesystem permissions, and fault injection:

```text
bounded(rate_limited(grammar_checked(scripted_ports())))
```

The default substrate remains minimal; scenarios opt into exactly the external laws needed for
their claim.

---

## 12. Numeric boundaries need equality and one-over coverage

### Observation

The bounded provider coverage checks both sides of the exact shared-window boundary:

```text
input + output allowance == context window      -> accept
input + output allowance == context window + 1  -> reject
```

This pair specifies that overflow is `>` rather than `>=`. A single large failing example would
show that some rejection exists but would not define the maximum accepted point or catch an
off-by-one implementation.

### Generalisation

Every numeric admission rule should include, where representable:

- one value immediately below the boundary;
- equality at the boundary; and
- one value immediately above the boundary.

If discretization, rounding, or calibration changes the reachable values, the test should record
that mapping explicitly. Boundary triples are particularly important for percentages, token
rounding, retry counts, timeouts, and maximum interaction budgets, where integer division can move
the effective threshold.

---

## 13. Oracle independence has multiple dimensions

### Observation

Section 3 records that the bounded provider independently implements the capacity equation instead
of calling `effective_input_limit`. That establishes **decision-arithmetic independence**. The
wrapper still uses a deterministic token estimator rather than a live provider tokenizer, however,
so it does not independently validate tokenizer fidelity.

This distinction matters to the strength of the claim. A test can be independent in how it decides
overflow while sharing the production approximation of how many tokens the input contains.

### Generalisation

DST documentation should identify the dimensions in which an oracle is independent:

| Dimension | Question |
|---|---|
| Decision arithmetic | Is acceptance computed without the production policy helper? |
| Measurement | Is size/time/cost measured by an independent mechanism? |
| Configuration | Does the oracle obtain limits independently of production resolution? |
| Execution substrate | Does it cross the same adapter/provider boundary as production? |

No single test needs independence in every dimension. The claim must be bounded accordingly. For
#165, the scripted provider proves admission arithmetic and call ordering under deterministic token
measurement; provider telemetry and calibration evidence remain responsible for correspondence to
real tokenization.

---

## 14. Failure containment is not root-cause remediation

### Observation

Issue #165 and issue #31 occupy different layers of the same failure chain. #165 prevents the
driver from preparing an input/output combination that cannot fit the provider window. It does not
prevent a tool from returning an oversized result, truncate or split that result, or recover a
conversation after oversized data has entered history.

The relationship was initially easy to describe too broadly as “closing the provider-overflow
hole.” The accurate claim is narrower: #165 supplies downstream admission safety under the current
output-budget invariant; #31 still requires upstream input shaping and recovery.

### Generalisation

DST should model defensive layers separately:

```text
tool-result/input shaping
  -> history storage
  -> compaction
  -> final provider admission
  -> provider rejection mapping
  -> recovery
```

A scenario proving one layer should not be used as evidence that the entire failure chain is
solved. Separate layers allow tests to distinguish prevention, containment, error translation, and
recovery, and they keep issue and PR claims aligned with the behavior actually exercised.

---

## 15. Source-coordinate anchors impose non-behavioral migration cost

### Observation

The first PR check failed because additions moved line-number-based attribution anchors in
`session.ail` and `stub_step.ail`. The behavior under test had not changed at those anchored sites.
The branch had to preserve line counts and relocate additions around the anchors before the
behavioral suite could proceed.

This is not a new discovery: project 009 records the attribution-anchor cascade, its multi-file
blast radius, and cases where `make anchors` was necessary but not sufficient. The #165 session is
additional evidence from an otherwise unrelated policy change.

### Generalisation

Source coordinates are useful evidence locators but expensive identities. When a test means “this
semantic site still has this classification,” stable structural tags, content identities, or an
extracted declaration are preferable to an absolute line number. If coordinates must remain part
of an auditable artifact, CI should distinguish:

- mechanical coordinate drift with unchanged anchored content; and
- semantic drift requiring reclassification or profile re-issuance.

This note does not propose redesigning the attribution system; the governing analysis remains in
project 009. The local lesson is to include anchor checks early in the change-impact gate and not
mistake their failure for a production or DST-behavior regression.

---

## 16. Consolidated follow-up candidates

These are ordered by leverage and scope, not committed work items.

| Priority | Candidate | Layer | Expected benefit |
|---|---|---|---|
| 1 | Introduce semantic fixture constructors for raw windows and input budgets | Test architecture | Prevent recurrence in hand-written and seeded fixtures |
| 1 | Label generator domains and preserve fail-open scenario classes | DST generators | Stop valid draws from collapsing unintentionally into the `0` sentinel |
| 1 | State the independent-oracle rule in DST guidance | Test architecture | Avoid correlated production/oracle bugs |
| 1 | Require a live neighboring control for negative-effect assertions | Scenario design | Prevent disconnected or unreachable paths from satisfying absence claims |
| 1 | Require equality and one-over cases for numeric admission boundaries | Scenario design | Specify inclusivity and kill off-by-one variants |
| 1 | Preserve and report each named budget-derivation stage | Observability | Detect wrong-layer and double-subtraction defects |
| 2 | Add the constant-difference metamorphic relation | DST property axis | Detect hidden constants and raw/effective divergence |
| 2 | Emit raw, derived, and resolution-reason diagnostics | Observability | Make corpus failures self-classifying |
| 2 | Document which independence dimensions each oracle provides | Test architecture | Keep evidence claims no broader than the measurement actually supports |
| 2 | Prefer opt-in realism decorators over globally stronger fakes | DST substrate | Let scenarios select external laws without obscuring policy-only tests |
| 2 | Catalogue last-mutator/final-guard pairs at external boundaries | Core and DST | Ensure invariants are re-established immediately before effects |
| 2 | Represent prevention, containment, rejection, and recovery as separate scenario layers | DST taxonomy | Prevent a downstream guard from being credited with upstream remediation |
| 3 | Replace numeric `0` with a reason-preserving resolved-limit shape | Core policy | Improve correctness arguments and scenario coverage |
| 3 | Expose the resolved provider output budget to Motoko | AILANG integration | Make provider admission derive from one source of truth |
| 3 | Add a configuration-coherence probe | Integration DST | Detect catalog, route, and provider-handler drift |
| 3 | Reduce absolute source-coordinate identity where the artifact permits | Attribution architecture | Separate mechanical movement from semantic reclassification |

The smallest coherent next step is the first-priority group: semantic constructors, explicit
generator domains, a written independent-oracle rule, live controls for absence assertions,
boundary triples, and named budget-stage diagnostics. They require no provider API change and make
the existing suite more resistant to the exact classes of semantic drift and vacuous evidence
exposed by #165.
