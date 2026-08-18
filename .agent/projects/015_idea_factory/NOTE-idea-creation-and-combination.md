# NOTE: Idea creation and combination

Date: 2026-08-15
Status: Discussion note — analysis of the generation step 015 named but did not specify.
  Schema in §7 is proposed for future admissions, not a retrofit of 001–016.
  Open threads in §9 are not conclusions.
Pinned binary: AILANG **v0.33.0** (`ailang.lock`)
Relates to:
- `RESEARCH-idea-factory-and-idea-evaluation.md` — parent. This note is the missing
  generation/combination half of its §2–§3; it does not reopen evaluation, health
  metrics, or the §5 ledger unification
- `.agent/projects/014_comparative_self_evolution/RESEARCH-godel-machine-lineage-for-motoko.md`
  — Φ_RM / Φ_CH are the source-level rhyme of the operators named here; §3.3's
  "join failure clusters × mutation surface" is the load-bearing precedent
- `.agent/projects/012_continuous_ailang_adoption/RESEARCH-continuous-ailang-feature-adoption.md`
  — pull vs push, `fires_when` / `review_when`; the trust split this note applies
  to combination
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md` and
  `.agent/projects/013_core_architecture_for_dst/RESEARCH-core-architecture-for-dst.md`
  — the inversion pair (same evidence, flipped independent variable)
- `.agent/projects/003_CSP_core_refactor/NOTE-why-not-csp-now.md` — residual after
  a killed blend; the factory's best existing kill record
- `.agent/projects/016_github_ops/RESEARCH-github-pr-ops-pipeline.md` — reviewer
  comment as a new intake channel (internal product: intake)
- `.agent/research/Spatiotemporal_Composability/cordis-paper-vs-motoko.md` —
  dual/complement blend with an `upgrades` row (DST can verify `g∘f = id`)
- `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  — cartesian product of papers × Motoko is the 009 failure mode for generation

---

## 0. The question this note asks

015's generation rule is: *an idea is a join between a recorded weakness and a newly
available capability*. That names one operator and treats combination as a vibe.
The corpus is more specific. Most Motoko research *is* a combination — typically
"can X play a role in the Motoko architecture?" — and the good notes already share
a shape.

Two questions:

1. **What generation operators does the factory already run, measured against
   existing notes?** (§1–§3)
2. **Which of those can be formalized as a schema without automating selection?**
   (§4–§8)

This note does not propose a generator. Automation decisions remain after 014's
WI-1/WI-2, per 015 §7.

---

## 1. 015 under-specified generation

015 §2 places the factory as the general case of a mutation operator and stops.
The join rule is real — 012 (debt × changelog) and 014 Φ_RM (failure clusters ×
mutation surface) are instances — but it is not the only operator the tree runs,
and it does not describe how two *ideas* combine.

The gap matters because a future automated generator inheriting only "join against
recorded evidence" will:

- miss inversion, residual, dual, and unification (the internal products that
  produced 013, 004, Cordis-as-013-D, and 015 §5 itself);
- treat every paper as joinable (the push-driven scan 012 rejected);
- have no typed edge between notes, so rhymes (012 ≅ Φ_RM) stay one-off insights.

---

## 2. Two generators, different trust levels

The same split 012 made for AILANG adoption applies to idea creation.

| | Push / import | Pull / join |
|---|---|---|
| Question | "Here is X; can it play a role?" | "Here is a registered concern; what newly available X addresses it?" |
| Input | paper, architecture, changelog novelty | ledger concern × new capability / comment / sibling idea |
| Corpus | almost all of `.agent/research/` | 012, Φ_RM, 016 comments, 011 from DRAFT §8 |
| False positives | high | near zero |
| Failure mode | 009-shaped volume; findings-per-round rise | misses genuinely new concerns nobody pre-registered |
| Trust | `review_when` — mapping table only, never auto-admit | `fires_when` — may become a project |

The factory currently runs **push by default** and records pull when a human
already knows the weakness. That is why `.agent/research/` is larger and softer
than `.agent/projects/`. Both generators are real; conflating them is what makes
"create ideas" feel unbounded.

The exploration budget (015 §3.2) *is* the push-combination budget. Oracle-creating
ideas are the legitimate push residue: they cannot join against a concern the
current oracles can name.

---

## 3. Combination is not one operator

Measured against notes already on disk. Each row is an operator with typed
operands, not a synonym.

| Operator | Typed as | Instance |
|---|---|---|
| **Import / blend** | external X ⊗ Motoko substrate | 014, Cordis, PSE, TRM, TM, 003 CSP |
| **Inversion** | same evidence, flipped independent variable | 011 "add axes, freeze architecture" vs 013 "change architecture, freeze axes" |
| **Join** | weakness row × capability | 012, Φ_RM, 016 reviewer comments |
| **Unification** | A, B, C are views of one object | 015 §5 ledger; 008 keying × 015 × 016 |
| **Dual** | each covers the other's admitted gap | Cordis vs Phoenix+DST |
| **Residual** | X killed as architecture; X-as-island survives | 003 CSP → 004 phase machine + stream islands |
| **Generalize** | working instance → system | DST-for-compaction → generalized DST |
| **Layer** | Y repairs X's dominant failure | DGM → HGM → MGM → RQGM |

Those rows describe **how a candidate was discovered**. A second, independent
axis describes **how its mechanisms would compose**. Keeping the axes separate
prevents an overloaded word such as `blend` from meaning both provenance and
architecture:

| Composition topology | Typed as | Question it asks |
|---|---|---|
| **Role binding** | X.mechanism → Motoko.role | Which architectural responsibility could X occupy or augment? |
| **Pipeline** | X.provides → Y.requires | Does one mechanism produce exactly what the next consumes? |
| **Overlay** | X × Y joined on subject/key | Do two mechanisms describe the same entity on complementary axes? |
| **Feedback** | X.output → Y.evaluate → X.control | Can the result close a measured improvement loop? |
| **Shared substrate** | X, Y, Z are views of L | Is an apparent combination really one latent object with several projections? |
| **Governance** | G constrains when/how X changes | Does one mechanism keep optimization pressure off another's oracle? |
| **Comparison** | X ⊗ Y → diagnostic delta | Does controlled contrast create evidence neither operand contains? |
| **Layer composition** | X and Y act at distinct stages | Are their effects complementary rather than competing for one slot? |

Thus `import` may discover a pipeline, overlay, or role binding; `unification`
usually discovers a shared substrate; `layer` may discover a pipeline or a
governance relation. The discovery operator is useful for calibration. The
composition topology is useful for determining whether the proposed system can
actually be built.

"Can X play a role?" is the **import/blend** operator. The others are how Motoko
ideas combine with *each other*. Treating them as one operator is why combination
feels unformalizable.

---

## 4. The blend that already works

Every good import note is the same artifact: a **mapping table**, not a narrative.

- **TRM** (`.agent/research/TRM_Context_Compression_Research.md`): puzzle triple
  `(x, y, z)` → conversation triple, plus a "what breaks" column (asymmetric
  lengths). Stops at a cheap probe. Correctly did not become a project.
- **Cordis**: temporal/spatial bets vs Phoenix+DST, then "each covers the other's
  gap," then explicit *rejects* (hot-plug, metatheory). Crosses into 013-D because
  an `upgrades` row exists: DST can verify `g∘f = id`, which the paper leaves as
  an author obligation.
- **014**: lineage component → Motoko nearest artifact → state. Prize rows are
  **upgrades** (DST as pre-admission; replay-diff as causal Φ_CH), not transfers.
- **TM** (`.agent/research/Tsetlin_Machines_AILANG_Synthesis.md`): clause / ADT /
  Z3 synergy map, plus a tension section (training loop, scale). Stays research.
- **003**: the mapping ran, the substrate failed the distinguishing probe
  ("does AILANG v0.26 give uniform cancellable processes?"), the residual became
  004. Best existing kill record.

That is conceptual blending with the generic space made explicit:

- Input 1: X's machinery
- Input 2: Motoko's substrate
- **Generic space: the shared concern** (recovery, self-evolution, compression,
  verification, …)
- Blend: the mapping table
- **Emergent structure:** something neither input had alone

Emergent structure is the admission test 015 was missing for combinations.

### 4.1 The bridge is the third operand

Most useful combinations are not `X + Y`. They are `X → Z → Y`, where Z is
the smallest adapter, shared key, representation, or protocol that makes the two
mechanisms interact. Z is frequently the novel research contribution.

Project 010 is the cleanest instance:

```text
architecture map
  provides: subject → stable coordinates

DST trace
  provides: time → events

bridge: event attribution
  provides: event → subject set

composition
  trace → attribution → coordinates
```

The map and trace can coexist without producing replay visualization. The
attribution bridge produces the overlay, divergence localization, and blast-radius
views. Likewise:

- DST + fuzzing needs a seeded scenario generator and persisted reproduction key;
- changelog + debt registry needs a shared capability identifier;
- variant archive + comparative mutation needs `(variant, task) → outcome`;
- benchmark divergence + deterministic replay needs a reproducer that translates
  the real failure into a scripted world.

A proposed combination that cannot name Z has not described an interaction. It
has described adjacent features. Conversely, proving Z expensive, lossy, or
impossible is an excellent cheap kill.

014's causal Φ_CH is not "adopt MGM." It is MGM's comparison *plus* Motoko's
identical-world replay — neither paper nor Motoko had that. Cordis+DST verifying
inverses is the same shape. TM+Z3 is "first verified TM," not "TM in AILANG."

**A combination with no `upgrades` or `gap-covered` row is a rename or a mashup.**
Queue it behind blends that produce emergent structure. Same spirit as 015 §3.1
(unjoined ideas queue behind joined ones), applied to combination rather than
provenance.

---

## 5. Well-typed vs ill-typed

`A ⊗ B` is well-typed when it has port compatibility (item 1) **and** at
least one reason to compose (items 2–5):

1. **Port compatibility.** A provides something B requires, or the proposal names
   a bridge that translates between them. No compatible ports and no bridge →
   adjacent features, not a combination.
2. **Shared concern.** Both address a named Motoko weakness. This is the highest-
   trust case and prunes the paper × module cartesian product.
3. **New-role exception.** A push/import mapping may reveal a useful architectural
   role or concern that Motoko did not previously name. It must state the new role,
   connect it to existing flows, and remain `review_when`; otherwise "no shared
   concern" is just a mashup.
4. **Dual flanks.** A's unguarded failure is B's strength (Cordis live-revert vs
   Motoko pre-verify).
5. **Orthogonal layers.** Different slot, different oracle, different mutation
   surface. Context-mode × headroom combined *because they do not compete*.
   012 ≅ Φ_RM is the same operator at different grain — a rhyme, not a merge.

Ill-typed when:

- **Substitutes, no distinguishing probe.** CSP vs phase machine wanted the same
  slot (the core). 003's cheap probe killed the blend and kept the residual. A
  combination that cannot name the 1-bit test that would pick a winner is 015
  §3.3's "commitment wearing an experiment's costume."
- **Coupled payoff.** Value only if both operands fully land. 014 already refused
  this: G1+G2 pay even if no loop is built. A blend of "handlers +
  commands+interpreter + hot-plug" that only pays if all three ship is a bad idea
  regardless of how pretty the architecture is.
- **No residual.** If the combination dies, nothing remains. Good blends leave the
  mapping table and the rejected rows.

Do not merge rhymes. 012 and Φ_RM are the same *operator*, different *layer*.
Merging them is the three-ledgers-built-thrice failure 015 §5 warned about.
Record the rhyme; keep the views.

---

## 6. How to create combinations

Not a search over papers. A procedure with two predicates, stolen from 012 §5.

### 6.1 Pull (`fires_when`) — may become a project

```
concern C is on the ledger
X newly available (changelog, paper, comment, capability, sibling idea)
X addresses C
Motoko's current answer A to C is named
emit mapping table: X.components → A
classify each row: transfers | upgrades | adapts | rejects | gap-covered
if ≥1 upgrades/gap-covered AND a 1-bit probe exists:
  admit as candidate
```

This needs a **concern vocabulary** — the missing formal object. 015's ledger is
"where we are weak"; it is not yet a closed list of *named concerns* an external
X can join against. Without it, every import is push.

Do not invent a taxonomy first. Harvest the Relates-to / "why this paper matters"
sections. They already name the concern. Candidates already in prose:

- admission-without-benchmark
- oracle-strength (reachability ≠ kill-rate)
- world-boundary totality
- mutation-surface allowlist
- stale-blocked debt
- kill-trace
- prediction-calibration
- registration-outside-ledger
- context-compression
- factory-throughput (this project's own concern)

Freeze the harvested list per epoch (015 §6 Q4 / RQGM). A future generator
optimizing against the concern list will invent fake weaknesses to join against.
The concern vocabulary *is* an oracle.

### 6.2 Push (`review_when`) — mapping table only, never auto-admit

"Here's a paper" is allowed; its output is a mapping table plus a kill-or-queue
decision. TM, TRM, Phoenix mostly stopped here, correctly. 014 and Cordis crossed
into projects because the mapping produced upgrades against *already recorded*
concerns (archive gap, registration gap, 013-D).

The 009 failure mode for idea generation is cartesian product: papers × modules ×
Motoko slogans. Findings-per-round will rise. The health metric is **kill rate of
blends**, not number of "X × Motoko" notes.

### 6.3 Internal products (idea ⊗ idea)

Different grammar from import. Detectable once ideas carry keys.

| Product | Detectable? | Example |
|---|---|---|
| Inversion pair | semi — shared evidence, flipped IV, often written in §0 | 011 ⊗ 013 |
| Rhyme | yes, if generation rule is keyed | 012 ⊗ Φ_RM |
| Prerequisite | yes — already in Depends-on | 005 ⊗ 014; 013-A ⊗ 011 shrinking |
| Unification | yes — same evidence keys, two schemas | 012 registry ⊗ 014 matrix ⊗ 015 queue |
| New intake | yes — A emits the evidence B joins | 016 ⊗ 015 |
| Residual successor | only if kills are recorded | 003 ⊗ 004 |

Rhyme, prerequisite, unification, and intake are mechanical **once ideas carry
keys** (concern, generation rule, evidence rows, predicted outcome). Inversion
still needs a human to notice the flipped question — but 013 §0 shows the tell:
"how this differs from N." Make that section mandatory when two notes share
evidence.

Relates-to today is untyped prose. That is why 015 could see the 012/Φ_RM rhyme
only by rereading.

---

## 7. Schema to formalize now

015 §7 still holds: no generator, no dashboard. The cheap formalization is a
**combination schema on the research note**, same cost as 014 G1 (a field + a
derived index). Proposed for *future* admissions; not a retrofit (015 §6 Q5 /
§7).

### 7.1 Minimal mechanism and role interfaces

The mapping table needs typed endpoints. The minimum useful interface is not an
ontology; it is a small record that exposes what can compose:

```yaml
mechanism:
  consumes: []       # information or state needed
  provides: []       # capability or information produced
  acts_on: []        # architectural objects changed
  observes: []       # architectural objects measured
  requires: []       # preconditions and host capabilities
  preserves: []      # invariants claimed unchanged
  optimizes: []      # objective placed under pressure
  failure_modes: []

role:
  responsibility: ""
  inputs: []
  outputs: []
  invariants: []
  current_answer: ""
  recorded_weaknesses: []
  available_measurements: []
```

This record is filled only for operands and roles used by the proposed mapping;
it is not a demand to model all of Motoko. An unmatched `provides` may become a
new-role hypothesis rather than being discarded merely because today's
architecture has no corresponding name.

A combination record then names both axes and the interaction:

```yaml
discovered_by: import       # import | inversion | join | unification | ...
topology: overlay           # role-binding | pipeline | overlay | feedback | ...
operands: []
bindings: []                # mechanism port → Motoko role or other port
bridge: ""                  # adapter/key/protocol; may be `none` with a reason
emergent_capability: ""     # caused by interaction, not a union of features
interference_risks: []
```

`discovered_by` answers where ideas come from. `topology`, `bindings`, and
`bridge` answer whether they form a system.

### 7.2 Import / blend

```yaml
discovered_by: import
topology: role-binding
concern: [registration-outside-ledger]   # join keys into the §5 ledger
operands: [cordis-paper, 013-D, phoenix]
mapping:
  - from: inverse-carrying commands
    to: 013-D Command
    class: upgrades          # emergent: DST can verify g∘f=id
  - from: hot-plug extensions
    to: compile-time registry
    class: rejects
    reason: type-error overreach is the differentiator
bridge: "inverse metadata carried by Command and interpreted by the DST driver"
emergent_capability: "DST can verify that revert composes with apply to identity"
probe: "can a Command carry an inverse without changing ExecutionProgram wire schema?"
prediction: "revert-then-replay is a new invariant family or it isn't"
residual: "mapping table + rejected hot-plug remain even if 013-D never happens"
```

`class` is one of: `transfers` | `upgrades` | `adapts` | `rejects` | `gap-covered`.

Admission gate, lexicographic (015 §3.4):

1. well-typed (§5) — else not a proposal;
2. ≥1 `upgrades` or `gap-covered` row — else queue behind those that have one;
3. probe named and cheap — else not yet a proposal;
4. residual named — else the kill is expensive;
5. only then score (leverage-per-effort, exploration-budget slot, …).

### 7.3 Internal products

Less schema. Required fields: `discovered_by`, `concern`, and a **typed**
Relates-to edge:

```text
inverts | rhymes | prereq | unifies | intakes | residual-of
```

Untyped Relates-to remains legal for navigation; typed edges are what make
§6.3 products queryable.

### 7.4 What this makes combination

- **generable** as a join (concern × new X)
- **killable** (no upgrades row, or probe fails)
- **composable** (two ideas share a concern key → inversion / unification / rhyme
  candidates fall out)
- **calibratable** (which operators' predictions settle true — 015 §3.5 applied
  per operator, not just per idea)

A later 014-style loop can treat combination as Φ_CH over *ideas*: two ideas,
shared concern, first-divergent claim. Same operator, one grain up. Which is
itself a rhyme — and the reason this is a 015 note, not a 017.

---

## 8. The creation loop (manual, stated so it can later be an operator)

```
signal (paper | changelog | comment | inversion | residual)
  → normalize each operand into a mechanism interface
  → name the concern, or explicitly propose a new role under review_when
  → name Motoko's current answer and role interface
  → enumerate plausible role/port bindings
  → classify discovery operator and composition topology separately
  → name the bridge between operands
  → mapping table: transfers | upgrades | adapts | rejects | gap-covered
  → state the emergent capability (not the union of features)
  → if substitute: run the distinguishing probe or kill
  → if blend/dual: require an upgrades row and a viable bridge
  → write prediction + residual
  → queue behind evidence-joined ideas unless it is oracle-creating
```

That is the factory's generation step, written as a procedure rather than a
slogan. Degree-0 still; the schema is the keying discipline, not the loop.

---

## 9. Open questions

1. **How strict is the mapping table on day one?** Required for new imports, or
   harvested retrospectively from the notes that already have one (014, Cordis,
   TRM, TM, 003)? Recommendation: require going forward; harvest only Relates-to
   edges. Retrospective scoring of 001–016 is 015 §6 Q5.
2. **Where do typed Relates-to edges live?** Frontmatter on the note, a section,
   or rows in the §5 ledger? Same question as 015 §6 Q1 (kill records) and 016
   §4 (008 fork 2). Do not invent a fourth carrier.
3. **Who harvests the concern vocabulary, and when is it frozen?** A one-pass
   extract from Relates-to / "why this paper matters" is cheap; keeping it open
   forever makes it an unmeasured oracle.
4. **Is "no shared concern" a hard refuse or a `review_when`?** Hard refuse kills
   mashups; `review_when` is how 014 and Cordis entered (the concern was named
   *by* the mapping). Recommendation: refuse auto-admit, allow the mapping table.
5. **Does combination-as-Φ_CH fall under the RQGM epoch rule?** Yes, the moment
   a generator optimizes against the concern list or the `upgrades` classifier.
   At degree 0–1 this is theoretical; the line is the same as 015 §6 Q4.

---

## 10. Explicitly out of scope

- **Automating idea generation or selection.** Same ordering as 015 §7: after
  014 WI-1/WI-2 produce data.
- **A paper-ingestion agent that emits "X × Motoko" notes.** That is 012's
  push-driven scan. Output volume will look like factory health and will not be.
- **A closed concern ontology designed up front.** Harvest, then freeze per
  epoch.
- **Scoring combinations by how clever the blend sounds.** Gate-then-score still
  applies.
- **Re-ranking or retrofitting 001–016.** §7 schema is for future admissions.
- **A new numbered project.** This is factory machinery, not a sibling of 015.

---

## 11. Relation to 015's criteria

015 §3's five criteria survive. Combination adds the missing *generation*
discipline those criteria assume:

| 015 criterion | What combination adds |
|---|---|
| §3.1 Provenance | concern key is the join; untyped Relates-to is not provenance |
| §3.2 Oracle-creating exception | push / `review_when` budget; mapping table still required |
| §3.3 Cheap falsification | probe + residual on the blend; coupled-payoff blends fail this |
| §3.4 Gate-then-score | well-typed → upgrades row → probe → residual, then score |
| §3.5 Settled prediction | `prediction` field per combination; calibration *per operator* |

Factory health (§4) gains one metric that is currently unmeasurable: **kill rate
of blends**. It becomes computable the moment a killed import leaves a mapping
table with a `rejects`-only (or probe-failed) outcome — which is 015 §6 Q1
applied to this operator family.
