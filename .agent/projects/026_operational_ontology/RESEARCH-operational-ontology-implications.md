# RESEARCH: Operational Ontology (Data Engineering Weekly / gura105) — what Motoko can take from it

Date: 2026-08-27
Status: Research note (no decision taken; candidate ADR/PLAN listed in §7)
Grounded at: branch `arniwesth/mot-129-extension-abi-phase-a`, HEAD `068c634`
Sources:
- Article: dataengineeringweekly.com/p/building-an-operational-ontology
- Reference impl: github.com/gura105/operational-ontology (~300 LoC TypeScript, MIT, MCP server via `pnpm mcp`)

Relates to:
- `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` — the `ToolPolicy` seam
  where an ontology's "action gate" would sit in Motoko.
- `../017_extension_handling/ADR-001-extension-abi-evolution.md` — `Capability` list (6.0);
  `ToolPolicy` is a one-vote kind, `ToolProvider` is first-match per tool family. Both matter in §4.
- `../016_github_ops/ADR-001-github-pr-ops-pipeline.md` and
  `../022_linear_integration/RESEARCH-linear-integration.md` — Motoko's two real *write-to-systems-
  you-don't-own* surfaces. These are the concrete candidates for the pattern (§4.2).
- `../025_envharness_contracts/RESEARCH-envharness-implications.md` — "Contracts at the tool
  boundary"; the ontology's action preconditions are the same idea with a domain model behind it.
- `design_docs/planned/m-motoko-tool-policy-pending.md` — `Pending(reason, default)`; the
  ontology has no human-in-the-loop notion, Motoko does (§3.3).
- `src/core/dst_fault_catalogue.ail` (`logical_transition`) — Motoko's commit-semantics vocabulary,
  which is stricter than the ontology's write-back-first rule (§3.2).

---

## 0. TL;DR

The article's thesis: a semantic layer (objects + links, read-only) is not enough once agents
act; you need an *operational* ontology that adds **named actions with preconditions**,
**machine-readable refusals as return values**, a **declared authority map** (source-backed /
ontology-owned / derived) per piece of state, **write-back to the system of record before
local commit**, and an **audit log of every attempt, refused or applied**. Agents get one MCP
tool per query shape and one per action; there is no raw UPDATE path.

Motoko already has the *mechanism* half of this (policy gate + typed refusal + ledger) but none
of the *model* half (objects/links/authority). Implications, in order of confidence:

1. **Machine-readable refusal codes at `ToolPolicy`** — `Deny(string)` is free text today.
   The ontology's `{"error":{"code":"SHIPPED_ORDER_CANNOT_BE_CANCELLED"}}` is the same decision
   with a code the model (and DST invariants) can branch on. Small ABI widening, high leverage.
2. **GitHub-ops and Linear are Motoko's first operational ontologies** — both are writes to
   systems Motoko does not own, both already have hand-written preconditions and a local
   processed-state record (`.agent/prs/<remote>-<n>/state.yaml`). Restating them as
   `objects/links/actions` with an authority map is the cheapest real instance of the pattern.
3. **The ontology's MCP server plugs into `motoko-ext-mcp` unchanged** — a zero-code way to
   evaluate the pattern: run `pnpm mcp` from the reference repo, point a profile at it, observe
   how a model handles structured refusals vs. Motoko's string denials.
4. **Authority map as an extension-ABI concept** — Motoko's `ExtWorld` token already declares
   *who owns state* at the harness seam (host-owned, opaque). The ontology generalizes this to
   domain state. Possibly nothing to build; worth naming in the ABI docs.

Not transferable: the ontology's "no generic UPDATE" for a *coding* agent. `WriteFile`/`BashExec`
are generic updates by design and the Phoenix architecture depends on them (§5).

---

## 1. The sources, compressed

### 1.1 Four properties (repo's stated minimum)

1. Semantic objects and links, modeled above physical data you don't own.
2. Action-gated writes: state changes only via named actions; no generic update path.
3. Business rules at actions: preconditions → machine-readable refusals.
4. Write-back to systems of record with declared ownership per field
   (`source-backed` | `ontology-owned` | `derived`).

### 1.2 Execution flow of one action

parameter validation → precondition evaluation → dry-run (edit plan) → authority check →
write-back to source → atomic local commit → audit record (applied *or* refused).
Source refusal ⇒ nothing changes locally. Re-index replays ontology-owned overlays on top of the
refreshed source-derived base; an orphaned overlay *blocks* the re-index rather than partially
applying.

### 1.3 Agent surface

MCP tools generated from the schema: one per query shape (`search`, `get`, `traverse`,
`aggregate`) and one per action. Preconditions are enforced identically for humans and agents —
"governance is enforced regardless of prompt variation."

### 1.4 Stated non-goals

Authorization, concurrency, federation, schema evolution, link properties, OWL/RDF. The author
frames it as DDD + CQRS + audit log, relocated from *inside* an application to *across* systems.

---

## 2. Mapping onto Motoko

| Ontology concept | Motoko today | Location |
|---|---|---|
| Action gate (precondition → allow/refuse) | `ToolPolicy((ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision)` | `packages/motoko-ext-abi/types.ail:1010` |
| Machine-readable refusal | `Deny(string)` — **free text**, no code | `types.ail:592` |
| Refusal as return value, not exception | Yes: decision-as-data, `NativeToolDenied` event, denial appended to tool batch, loop continues | `dst_fault_catalogue.ail:406` |
| Audit of every attempt | Session JSONL ledger + DST `Interaction` log with `CausalIdentity`, commit facts | `src/core/dst_interaction.ail` |
| Human approval | `Pending(reason, PolicyDefault)` — **absent in the ontology** | `types.ail:594` |
| Write-back before commit | `logical_transition` per fault row (did the all-or-nothing update commit?) — stricter | `dst_fault_catalogue.ail` |
| Authority map (who owns state) | Only at the harness seam: `ExtWorld.token` is host-owned/opaque | `types.ail` (WI-B2b) |
| Semantic objects/links | **Absent** for external systems; Omnigraph is a code graph, not a business model | `packages/motoko-ext-omnigraph` |
| Tools generated from schema | `ToolProvider` + `DescribeTools`; MCP bridge consumes any MCP server | `packages/motoko-ext-mcp` |
| Re-index / overlay | n/a (no materialized model) | — |

Reading: Motoko is the *runtime* an operational ontology assumes exists, minus a domain model.
The ontology is the *policy content* Motoko's ADR-001 (005) says should live in extensions.

---

## 3. Where the ideas land

### 3.1 Refusal codes (highest confidence)

`Deny(string)` forces the model to parse prose to learn *why* it was refused, and forces DST
invariants to match on substrings. The ontology's insight is that a refusal is domain data.
Candidate ABI change (major, since `ToolPolicyDecision` is matched everywhere):

```ailang
export type Refusal = { code: string, reason: string, retry_hint: Option[string] }
type ToolPolicyDecision = Allow | Deny(Refusal) | NoOpinion | Pending(Refusal, PolicyDefault)
```

Benefits: `ToolDeniedInfo` (`phase_vocab.ail:569`) carries a code → invariant families can
assert "denied-for-X never followed by retry-of-X"; the model gets a stable token to condition
on; the 016 processed-state record can cite a code instead of quoting a string.

### 3.2 Write-back-first vs. Motoko's commit vocabulary

The ontology commits locally only after the source accepted. Motoko's DST already forces every
fault row to state its `logical_transition`. The ontology adds one thing Motoko lacks: the
**dry-run edit plan** as a first-class value produced *before* the effect. `ToolHandleDecision`
has no "here is what I would do" variant. For GitHub/Linear writes this is exactly what the
016 pipeline wants (rank → test claim → respond → record) — a plan that can be shown, logged,
and refused before `gh`/Linear MCP is called.

### 3.3 Human-in-the-loop is Motoko's addition, not the ontology's

The ontology has three outcomes per action: applied, refused-by-rule, refused-by-source.
Motoko has a fourth: `Pending`. If Motoko adopts ontology-style actions, `Pending` maps to an
action whose precondition is "an operator has approved", with the approval itself an
ontology-owned, audited write. That is a cleaner story than today's stdin approve/deny, and it
reconciles with 022's open question "whose Linear account is this?" — the authority map answers
it per field.

### 3.4 Authority map at the harness seam

`ExtWorld` is already an authority declaration: the world token is host-owned, extensions carry
it, and the codec's one silent-failure mode is documented. The ontology's three-way split
(source-backed / ontology-owned / derived) is a vocabulary Motoko could adopt in the ABI docs to
describe *every* field crossing the seam (`Msg.tool_call_id` is source-backed by the provider;
compaction `artifacts` are ontology-owned by the extension; `BudgetPlan` is derived). Cost: a
docs pass. Benefit: the `declared_vs_performed` tooling gets a third axis to check.

---

## 4. Concrete candidates

### 4.1 Zero-code experiment: run the reference ontology through `motoko-ext-mcp`

`pnpm mcp` serves the orders demo over stdio. Add it to an `mcp.json` profile; give a coding
model the task "cancel order X, then assign it to Y". Observe: does the model recover from a
`SHIPPED_ORDER_CANNOT_BE_CANCELLED` refusal better than from a Motoko `Deny("...")`? This is a
single benchmark run and would settle whether §3.1 is worth an ABI major.

### 4.2 GitHub-ops as the first Motoko-native ontology

Objects: `PR`, `ReviewComment`, `Disposition`. Links: `PR ─has─▶ ReviewComment`,
`ReviewComment ─dispositioned_by─▶ Disposition`. Authority: PR/comment are source-backed
(GitHub); `Disposition{status, evidence}` is ontology-owned (`.agent/prs/.../state.yaml`);
"outstanding count" is derived. Actions: `respond(comment, text)` with precondition
`disposition == pending`; `dismiss(comment, reason)` with precondition `reason != ""` (016 D6:
a dismissal must carry a reason). Write-back: `gh api` before `state.yaml` update. This is
mostly a *restatement* of what 016 already decided, which is the point: it shows the pattern
fits without inventing new work, and it produces the `objects/links/actions` schema an MCP
`ToolProvider` could be generated from.

### 4.3 Linear as the second

022 §4's attribution problem ("accept attribution collapse deliberately, and write it down") is
literally an authority-map entry: `Issue.assignee` is source-backed, `Issue.motoko_note` is
ontology-owned. Making the map explicit is the write-down.

### 4.4 DST: refusal codes as invariant vocabulary

If `Deny` carries a code, the 12 invariant families gain a cheap 13th: *refusal monotonicity* —
a call refused with code C under world W is refused with C on replay. Today that can only be
asserted on the reason string.

---

## 5. What does not transfer

- **"No generic update path."** For a coding agent the filesystem *is* the domain and
  `WriteFile`/`EditFile`/`BashExec` are the actions. Wrapping every edit in a named business
  action is the wrong altitude; Phoenix's "no human-written code" depends on the generic path.
  The pattern applies to Motoko's *external* writes (GitHub, Linear, herdr delegation), not to
  its core tool set.
- **Materialized model + re-index.** Motoko has no datastore to overlay; sessions are ephemeral
  and the ledger is append-only. The overlay/re-index machinery solves a problem Motoko does
  not have.
- **Fail-open visibility default.** The repo's "no policy = visible to all" is the opposite of
  Motoko's fail-closed posture (019 confined agent, `Net` allowlist). Do not import.
- **Scale of the claim.** The reference is ~300 LoC and one demo; there are no measurements of
  agent behaviour under structured refusals. §4.1 would be the first.

---

## 6. Risks

- ABI churn: `ToolPolicyDecision` just went through 6.0. A `Refusal` record is a second major
  within weeks; batch it with the next planned break rather than shipping alone.
- Ontology drift: a hand-maintained `objects/links/actions` schema for GitHub will lag the
  `gh` surface. Mitigation: generate tool schemas from it (the repo's approach) so drift is a
  compile error, not a silent gap.
- Over-modelling: the article's own advice — one object, one action, one rule first.

---

## 7. Candidate follow-ons (none decided)

1. **EXPERIMENT** — §4.1, one profile + one benchmark task. ~half a day. Decides §3.1.
2. **ADR** — `Deny(Refusal)` with code; bundle with the next ABI major. Depends on 1.
3. **PLAN** — restate 016 github-ops as objects/links/actions + authority map; generate the
   `ToolProvider` schema from it. Depends on 2 only for the code field.
4. **DOCS** — adopt source-backed/ontology-owned/derived as the field-ownership vocabulary in
   `packages/motoko-ext-abi/types.ail` headers. Independent.
