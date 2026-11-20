# neon — round 3

## 1. Shared Step 0

Yes — all three turns put zero-model **Step 0** first (2–3 engineer-days):

1. **Mechanical safety floor:** Pin `check_core`, `corpus_judge`, `ledger_parity`, `journal_resume`, `verify_core`, plus an off-world native-FS fixture (omitting `declared_vs_performed` and `corpus_pr`'s wall-clock check). Run twice on clean `2eae0666` to confirm zero standing reds, identical verdicts, and `v0.60.4` latency (`session.ail` caches at `24.8 s` cold / `1.7 s` warm, `moderator-facts.md` §2).
2. **Isolated evaluator & proxy:** Disposable container extracting only `git diff` (plus data-only witnesses), `042/NOTE-001`'s RAM watchdog (`6 GiB` / `<3 GiB`, 2–3 workers), and a loopback LLM proxy metering model ID, tokens, and USD.
3. **Fault qualification:** Two-sided check (`V_i(faulty)=FAIL`, `V_i(clean)=PASS`, zero flake over 2 runs) on `2eae0666`'s `25–34` cleanly reversing commits (`moderator-facts.md` §1) and `60` seeded mutants, grouped by root-cause family, plus `4` clean controls and `5` known-good commits.
4. **Dry run:** Hash splits/rules into `sequence.log`; run `1` unseeded dry run (`042/NOTE-001` §9) to verify blinding and real token cost.

**Plan-changing triggers:** Any non-deterministic gate halts all loops. If historical + planted tasks yield `<12` families or the dry run shows `M_0` cannot compile `.ail` edits reliably, pivot to `fable`'s seeded-mutant oracle loop (`P3`).

## 2. Final ranked proposals and first loop

1. **P1:** Closed-loop harness and repair-procedure self-improvement on family-separated sealed repo tasks (editable config/skills/prompts/tools/guards; isolated container/proxy evaluator).
2. **P2:** Shared Step 0 — mechanical safety floor, isolated evaluator/proxy, and zero-model fault qualification.
3. **P3:** Stage-2 mutation-guided oracle-set strengthening on held-out seeded mutants (`fable`'s `P1`; promoted to first on Step-0 pivot).

**First loop (`P1`):** Freeze `6` dev families and `18` **untouched** holdout families (`6–8` cleanly reversing behavioral fixes, `moderator-facts.md` §1; `6–8` planted defects via `042/NOTE-001`'s planter; `4` clean no-change controls). Run a **byte-identical null control** (`M_0` vs `M_0`, `k=3` = `54` runs/arm, randomized; `moderator-facts.md` §3). From dev journals (`k=3`), `M_0` proposes `1` single-scope candidate `M_1` beating dev and Step 0's safety floor. Score `M_1` vs `M_0` paired on untouched holdout (`k=3`, `≥150k`-token cap). If `M_1` wins, test compounding: `M_0` vs `M_1` editing shared parent `M_1` on `6` fresh dev families, scored on `12` fresh holdout families (`k=3`).

**Noise-proof pass/fail:** Aggregate per **family** (mean of `k=3`; untouched holdout per decision). **PASS:** null `|Δ| ≤ 1` family (`p > 0.20`); `M_1` beats `M_0` across `14` fault families at exact one-sided paired permutation `p < 0.05`, `12/12` clean controls untouched, safety floor green, proxy USD/task `≤ 1.25× M_0`; compounding passes if `M_1`'s offspring beats `M_0`'s (`p < 0.05`). **FAIL:** any criterion missed, null exceeds noise, or no compiling candidate.

## 3. Strongest argument against `P1`

`P1` pays live-LLM variance and curation cost upfront: only `~14` behavioral commits reverse-apply cleanly (`~6–9` families, `moderator-facts.md` §1), requiring a planter, and `k=3` needs `~160–220` live sessions (`$250–$400`). Editing `.ail` tools/guards also stalls if `M_0` sits below the self-editing floor (`0/3` source-writing delegates in PLAN-001). `fable`'s oracle loop gets deterministic verdicts at `~46 s`/mutant; `astra`'s prompt-only loop avoids `.ail` edit risk. If `M_0` cannot patch itself reliably, `P1` spends more to uncover a floor narrower loops expose cheaper.

## 4. Remaining material disagreements and settling observations

- **`fable` (oracle-set vs harness first):** *Settled by Step 0's 60-mutant audit + 6-family dev trace:* count wire-unnoticed driver mutants vs `M_0` dev failures. Plentiful wire gaps + `.ail` edit failures favor `fable`; sparse wire gaps (`039` pilot) + harness failures favor `P1`.
- **`astra` (300-word prompt + `25k` cap vs harness + `≥150k` cap):** *Settled by Step 0's dry run + dev failure audit:* measure tokens on `derive.py`/`candidate.py` and share of tool-trap failures (`30 s` `BashExec`, `Search`, guards). Exceeding `25k` tokens or `>50%` tool traps falsifies prompt-only scope.
- **`prior-docs` (waiting on ADR-004 P2–P3 vs Step 0 evaluator):** *Settled by Step 0:* a mechanical standalone evaluator + safety floor on `2eae0666` avoids reviving 872-commit-stale `manifest-A.json`.

```yaml
participant: neon
round: 3
position_changed: yes
top_proposals:
  - id: P1
    title: "Closed-loop harness and repair-procedure self-improvement on family-separated sealed tasks"
    one_line: "Headless Motoko edits its config/skills/prompts/tools/guards from dev journals; an isolated container/proxy evaluator scores diffs at k=3 replicates across untouched family-separated historical reverts, planted defects, and clean controls, followed by an M_0-vs-M_1 author compounding test on a shared parent."
  - id: P2
    title: "Shared Step 0: mechanical safety floor, isolated evaluator, and zero-model fault audit"
    one_line: "Pin a green, deterministic multi-gate safety floor, container/proxy/watchdog runner, and two-sided qualification of clean historical reverts and 60 seeded mutants before any LLM loop."
  - id: P3
    title: "Stage-2 mutation-guided oracle-set strengthening on held-out seeded mutants"
    one_line: "Run fable's classification-first oracle loop on held-out seeded mutants with known-good commit survival controls once P1 lifts editing reliability, or first if Step 0 triggers a pivot."
first_experiment:
  what: "Step 0 zero-model qualification + dry run, then 1 promotion round of P1 on 6 dev and 18 untouched sealed holdout families (6-8 cleanly reversing historical fixes, 6-8 independently planted defects, 4 clean no-change controls) at k=3 replicates (54 runs/arm) plus byte-identical null control (M_0 vs M_0), followed by an M_0-vs-M_1 author compounding test editing shared parent M_1 on 12 fresh holdout families (k=3)."
  pass_if: "Step 0 runs 100% mechanically on clean HEAD; byte-identical null control |delta| <= 1 family (p > 0.20); M_1 beats M_0 across the 14 fault families with exact one-sided family-level paired permutation p < 0.05, 12/12 clean-control runs untouched, safety floor 100% green, proxy USD/task <= 1.25x M_0; compounding passes if M_1-authored offspring beats M_0-authored offspring from shared parent M_1 on fresh families (p < 0.05)."
  fail_if: "Step 0 needs human rulings or fails determinism; null control exceeds noise bound; M_1 fails family-level p < 0.05, triggers any clean-control false alarm, or reds the safety floor; or M_0 fails to produce a compiling candidate."
  cost: "Step 0: 2-3 engineer-days, zero model spend. First loop + compounding test: +2-3 engineer-days (independent planter + sealing), ~160-220 live sessions, ~$250-$400 API spend (proxy-capped, >=150k-token/session budget), 10-16 h wall-clock across 2-3 watchdog-guarded containers."
disagreements:
  - with: fable
    about: "After Step 0, whether to run whole-harness competence (P1) or driver oracle-set expansion (P3) first; settled by Step 0's count of wire-unnoticed driver mutants vs M_0's dev-task failure modes."
    material: yes
  - with: astra
    about: "Whether the editable surface should be a <=300-word prompt paragraph under a 25k token cap or the harness surface (config/skills/prompts/tools/guards) under >=150k tokens; settled by Step 0's dry-run token trace and dev failure breakdown."
    material: yes
  - with: prior-docs
    about: "Whether to wait for parked ADR-004 P2-P3 journal admission before running an automated loop; settled by Step 0 demonstrating a standalone mechanical evaluator on 2eae0666."
    material: yes
would_change_my_mind_if: "Step 0's dry run and 6-family dev trace show either that M_0 cannot reliably produce compiling AILANG edits (putting fable's P3 or astra's prompt-only loop first) OR that <20% of M_0 failures stem from harness/tool bugs and sessions fit under 25k tokens (making astra's narrow prompt loop strictly better to run first)."
embargo_notes: "Embargo lifted in round 2; all settled counts taken from round-2/moderator-facts.md."
```
