# Handoff: independently review ADR-001-motoko-dst-definition-and-taxonomy.md

Audience: a fresh agent session with no context from the authoring session. Your distance from the
author is the point — you are the check the author cannot perform on themselves. The authoring
session already ran three self-review passes; assume the easy findings are gone and the surviving
defects are conceptual or empirical, not typographical.

## Mission

Adversarially review
`.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md`.

This is a **definitional/taxonomic** ADR, not an implementation ADR. It decides (a) what the term
"DST" is entitled to mean in this repo, (b) a seven-pillar conformance checklist, (c) a scope
boundary (single-actor, logical-fault; physical-fault and multi-actor explicitly excluded), and
(d) a naming rule (HEAD is PBT, not DST, until a defined bar is met). Your job is to find: stale or
wrong anchors, empirical claims about the code that don't hold, taxonomy that misrepresents DST as
the field practices it, scope choices that are wrong rather than merely opinionated, and any
internal contradiction between D1–D4, the scorecard, and the mot-44 bar.

The failure mode to hunt: a *decision* resting on a *claim* that is false. The naming rule (D3) and
the exclusions (D1.3) are only as good as the empirical and conceptual claims under them.

## Inputs (read in this order)

1. `.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` — under review.
2. `.agent/projects/007_dst_consolidation/NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md` — the
   source analysis (PRs #84 → #99 → #100) the ADR formalizes. Check the ADR did not overstate or
   misattribute the note's conclusions.
3. `.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md`, especially
   its `## Review Comments` section — this is the output quality bar, and it is the ADR whose
   "DST" naming this new ADR re-scopes. Confirm the new ADR does not contradict decisions that
   ADR-001 actually made (vs. the label it merely used).
4. `.agent/projects/007_dst_consolidation/NOTE-dst-consolidation-scope-and-sequence.md` — the
   "why no new ADR" note. The new ADR claims not to reopen the consolidation tracks; verify that.
5. Source, with these anchors **mandatory** (every one is load-bearing for a decision):
   - `src/core/session.ail:684,696` — the `Scripted(script)` routing arm. The whole "substrate
     already in the tree, mot-44 is a small diff" argument (D4, mot-44 bar) rests on this.
   - `src/core/agent_loop_v2.ail:102-104,120-122` — the `[ScriptedStep]` entry points.
   - `src/core/session.ail:826-829` — `emit_run_summary` on every termination path, and the exact
     abnormal codes cited (`cost_exhausted`, `dp7_rejected`, `compaction_exhausted`, `max_steps`).
     D1.3's physical-vs-logical durability boundary depends on this being accurate.
   - `scripts/dst/phase_c_seeded_dst.ail` — the four families, the *scalar* param draws
     (`content_len`/`n_tail`/`n_systems`), and `checkpoint_pressure`'s `decide → apply_checkpoint →
     decide` shape (the ADR calls it a "fixed authored 2-step sequence," not a generated schedule).
   - `scripts/dst/compaction_seeded_dst.ail` — the 1 seeded family. The scorecard's "25 = 5
     families (4 + 1) × 5 seeds" arithmetic depends on this file contributing exactly one.
   - The `ScriptedStep` type definition and its `match` consumers — needed to test two claims:
     that adding fault variants makes existing matches non-exhaustive (Consequences), and that
     mot-44 is genuinely "a small diff."

## Review method (all five passes required)

1. **Citation audit.** Verify every `file:line` and every source-grounded claim against current
   source. In particular re-run the grep the ADR rests a negative claim on — *no* scheduling /
   interleaving / fault-injection / virtual-clock vocabulary anywhere in `.ail` — and confirm the
   hits are production-behavior comments, not test-injected faults. A wrong line, a stale name, or
   a paraphrase the source doesn't support is a finding.

2. **Single-actor attack (highest priority).** The entire "no multi-actor scheduling needed"
   decision (D1.1, and the rejection of canonical pillar 3) rests on the agent loop being *one
   sequential logical actor*. Attack it. Do tool dispatch, MCP servers as separate processes, or
   response streaming introduce real concurrency the ADR ignores? Look at the tool-dispatch and
   tool-runtime paths. If any concurrency exists that could interleave in a way that affects the
   ledger, the single-actor exclusion is too strong and pillar-3-concurrent may not be safely "out
   of scope." Report what you find either way.

3. **Taxonomy fidelity.** Judge whether the seven-pillar decomposition and the trace-replay / PBT /
   DST spectrum faithfully represent DST as FoundationDB / TigerBeetle / Antithesis / Resonate
   practice it. Is the claim that "pillars 3, 4, 5 are what make simulation simulation" defensible,
   or does it undersell pillar 2 (environment model)? Is "the unit a seed controls is an execution,
   not an input value" the right discriminator? You may consult external sources for this pass, but
   the bar is "is this a defensible characterization a practitioner would accept," not "cite a
   paper." Flag any pillar that is misdescribed or any category error in the spectrum.

4. **Empirical claims that gate a decision.** For each, decide TRUE / FALSE / UNSUPPORTED and show
   grounding:
   - HEAD meets pillar 1 (hermetic determinism) — the gate runs under a narrow `--caps` set and
     unmodeled effects fail at perform time. (Note the gate's real caps are `IO,Env,Rand`.)
   - HEAD meets **none** of pillars 2-logical, 3, 4, 5, and half of 7.
   - `checkpoint_pressure` is a *fixed authored* sequence, not a *generated* one (i.e. the seed
     does not choose the ordering, only the params).
   - The `run_summary`-on-every-termination-path guarantee is real and is the *only* durability-ish
     property (i.e. there is no crash-recovery / resume-from-ledger that would pull physical
     durability back into scope).
   - mot-44 ("seed → sequence of scripted steps + faults + stepped clock through
     `Session.run_v2_from_messages(… Scripted(script))`, invariants over `LedgerTrace`") is
     actually reachable from the current seams — or name the specific missing piece.

5. **Internal-consistency and enforceability pass.** Check D1–D4, the D2 checklist, the scorecard,
   the verdict, and Consequences do not contradict each other. Specifically:
   - Is pillar 2 handled consistently (2-logical required per D2/D4; 2-physical out per D1.3;
     scorecard row labelled "logical")?
   - Is pillar 5 described consistently everywhere ("normalized away, not virtualized" — no
     residual "deleted"/"nulled" that the source doesn't support)?
   - Is the D2 gate *enforceable*? "Not DST until pillars 3/4/5 are met" — can a reviewer on a
     future PR actually apply this test, or is it subjective?
   - Does the naming rule (D3: no "simulation" for the seeded axis until D2) collide with any
     existing target/name the ADR grandfathers, and is the grandfathering explicit?

## Output contract

Append a `## Review Comments` section to the ADR itself. Do **not** rewrite the ADR body unless the
user explicitly asks for a revision after review.

Number findings `R1..Rn`, most severe first. Each finding must include:

- The defect in one sentence.
- Grounding: `file:line` reference or reproduced command output.
- A concrete **Action:**.

Close with:

- `What is accurate` — a short paragraph naming the claims that held up (the single-actor verdict,
  the durability boundary, and the taxonomy are the three worth an explicit ruling).
- `Recommended pre-implementation actions` — short list ordered by dependency.

State your model id and the date at the top of the section.

## Constraints

- Findings only. Do not modify source, scripts, the Makefile, other ADRs/notes, or the ADR body
  during review.
- The naming decision (logical-fault DST, reject "Soft DST", HEAD = PBT) is settled *unless* you
  can show it conflicts with source reality, the DST literature, or the ADR's own internal logic.
  Attack the claims under the decision, not the taste.
- Physical-fault and multi-actor exclusions are in scope to attack **only** via pass 2 (find real
  concurrency) or pass 4 (find a real physical-durability contract). Do not re-argue them on
  preference.
- If you run commands, report the exact command for any failing or surprising result.
- If no major findings remain, say so plainly, and still record residual risks — the likeliest one
  is that a future concurrency feature (parallel tools, sub-agents) silently invalidates the
  single-actor exclusion; note where that tripwire should live.
