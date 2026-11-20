# neon — round 2

## (A) Cross-examination of `fable` and `astra`

**`fable`.**
- *Factual checks:* **Two claims fail at HEAD `2eae0666`.** First, `fable` claims `session.ail` still exceeds AILANG's compile-cache limit (`fable.md:23,121,183`), grounding its `P2` "~9× sweep speedup." Actually, AILANG `v0.52.2` raised that cap (`.github/workflows/verify-extensions.yml:133-135`), and `v0.60.4` sets `maxArtifactBlobBytes = 64 << 20` (`/home/motoko/.local/share/ailang/internal/pipeline/cache_artifacts.go:38`, 4× `v0.47`). Second, `make dst` has `55` targets (`Makefile:507-519`), not `53` (`README.md:101` is stale). Also, the `ce9cb247` blind survivors marked `[unverified]` (`fable.md:20`) already gained branch controls (`scripts/dst/corpus_judge_dst.ail:80-86`).
- *Strongest weakness:* `P1` tunes `driver_only` checks and never improves how Motoko writes or repairs code. Its fault supply is also tiny: `fable`'s 25 driver commits (`:167-170`) contain 3 non-`fix` subjects matched in bodies (`2c0fa52d`, `1b641931`, `052d4c2f`), 6 obsolete May-2026 commits, and CI/upgrade chores, leaving `<10` post-August behavioral driver bugs — while `039`'s pilot saw `16/30` seeded mutants leave no wire difference and missed an off-world FS write (`.agent/projects/014_comparative_self_evolution/NOTE-001-re-read-2026-11-02.md:215-238`).
- *What I take:* **Part A first** (zero-model mechanical classification on a green, wall-clock-free baseline before any LLM loop), false-alarm checks on `K` merged good commits (`fable.md:62-63,83-88`), and measuring RSI by widening mechanically accepted change classes (`:124-126`).

**`astra`.**
- *Factual checks:* `astra.md:7` **holds verbatim** — `m06` scored `KILLED` on an `exit 2` crash without a summary (`.agent/projects/037_skills_system/evidence/p3/mutants.tsv:6`; `mutate.py:100`), and `4bad256e` moved `survey.py` from `0/2197` to `488` on `v0.60.4`. `astra.md:13` **holds with a catch:** `--system-prompt` exists (`src/tui/src/index.ts:695-703`), but `SYSTEM_MD` *replaces* the entire built-in prompt (`:19`), requiring concatenation.
- *Strongest weakness:* Three flaws. (1) One 300-word prompt paragraph cannot fix real harness/tool bugs (`30 s` `BashExec`, `Search`, search/filtering) and hits a checklist ceiling quickly. (2) **Single-trial evaluation** (`1` run/arm on `12` defects) collides with Motoko's `27%` single-trial flip rate (`7/26` benchmarks, `014/NOTE-001:136,376`), making zero-loss acceptance (`astra.md:27`) noise-fragile. (3) The `25,000` cumulative token cap (`:23,29`) starves Motoko: `system_prefix` is `12,307` chars (`NOTE-010:10-11`), turn 1 starts near `3,942` tokens (`037/evidence/m2_results.tsv:2`), and real sessions average `~117k` input tokens/step (`NOTE-008:16,45`); reading 900–1,700-line checkers (`derive.py`, `candidate.py`) exhausts `25k` in 3–5 turns.
- *What I take:* **Clean-snapshot controls**, **root-cause family separation**, and `astra`'s **author-vs-author compounding test** (`astra.md:33`): pitting incumbent vs promoted authors editing the *same* starting artifact on fresh families.

## (B) Earlier plans: strongest case for DST, and what Round 1 missed

The strongest case (`design_docs/planned/m-motoko-dst-recursive-self-improvement.md:15-39`; `014/NOTE-001:288-293`; `032/RESEARCH:48-52,95-100`) is that DST gives reproducible counterexamples for causal localization (`Diverged { location }`), a `46 s` deterministic pre-filter (`corpus_judge`), zero-cost exact replay for in-support policy edits, and a ratcheting safety barrier. That survives **as a lower tier, not the centre**. The earlier plans themselves admit replay cannot grade prompt/tool/request edits (`m-motoko-dst-recursive-self-improvement.md:53`; `014/NOTE-001:303-309`), ADR-004 measures allocation only (`014/NOTE-001:142-144`), and the newest plan (`042/RESEARCH`, `042/NOTE-001`) already pivoted to live pre-registered method comparisons on sealed defects.

Four things earlier plans caught that my Round 1 missed:
1. **Author-vs-author compounding control** (`042/RESEARCH:170-180`; `m-motoko-dst-recursive-self-improvement.md:76`): sequential `M_0 → M_3` conflates inheriting a better harness with improving the improvement procedure.
2. **`N ≥ 3` replicates/cell** (`014/NOTE-001:136,374-379`): my `k = 2` repeats were underpowered against `7/26` single-trial flips.
3. **Blinding & zram operational limits** (`042/NOTE-001:112-129`): 8 sessions froze container zram in 7 min (needs 6 GiB / `<3 GiB` watchdog, 2–3 workers not 4); side channels (`herdr`, `gh`, `/tmp` caches) need auditing, hash-pinned `sequence.log`, and a dry run.
4. **Multi-gate safety floor** (`014/NOTE-001:228-238,437`): `corpus_judge` alone missed mutants caught by `ledger_parity`, `corpus_pr`, `journal_resume`, plus off-world FS writes.

## (C) Four axes of disagreement

1. **First thing to improve:** Improve the **editable harness + repair/investigation procedure together**, scored on competence over bugfix and oracle-authoring tasks — wider than `astra`'s 300-word paragraph (so tool/timeout bugs get fixed), and higher-leverage than `fable`'s `driver_only` checks.
2. **Mechanical verdict — prerequisite or parallel?** **Prerequisite for the loop's own gate** (Fable Part A + `042` dry run: green, wall-clock-free safety floor and 100% mechanical task scoring before any LLM run), **parallel** for all 55 `make dst` targets or splitting `session.ail`.
3. **Fault supply and root-cause families:** Both Round-1 counts were inflated (`--grep='^fix'` matches commit bodies and includes upgrade/CI/pin chores). Post-August behavioral fixes yield **~7–9 families** in `fable`'s 25 driver commits (too thin) and **43 commits across ~16–18 independent families** in my 123 `src/`/`packages/` commits (TUI exit codes, path guard, duration parsing, extension tool offers, herdr waits/policy, guards, compaction, skills, microrag, `ailang_tools`, catalog, `Search`, profile-dir, context-limit) — enough for **one** family-separated pilot, after which compounding requires sealed planted defects (`042`) and prospective live bugs.
4. **Pass criteria vs noise:** No Round-1 threshold was well-powered. My `+3` net tasks had one-sided sign-test `p = 0.125` (`k=2` ties); `astra`'s 1-trial `5/12` with `0` losses (`p = 0.031` one-sided) is fragile to `27%` flips; `fable`'s `+2` kills risks single-family overfit. Fix: `k = 3` replicates/task, 1 task per independent family, clean controls, and family-level paired permutation `p < 0.05`.

## (D) Revised proposals and first experiment

My core thesis (`P1` harness competence over DST-only tuning) stands, with five material revisions: promote a **mechanical, wall-clock-free multi-gate safety floor + zero-model Part-A dry run** to `P2` (Gate 0, dropping ADR-004 replay from top 3); move oracle-strengthening (`fable`'s `P1`) to `P3` as Stage 2; deduplicate strictly to **1 task per root-cause family** (`6` dev; `18` sealed holdout: `10` historical reverts, `4` planted/oracle tasks, `4` clean no-change controls); upgrade to **`k = 3` replicates** (`54` holdout runs/arm), family-level `p < 0.05`, hash-pinned `sequence.log`, and 2–3 watchdog-guarded containers; and test compounding via **incumbent (`M_0`) vs promoted (`M_1`) authors editing the same `M_1` baseline** on fresh families.

```yaml
participant: neon
round: 2
position_changed: yes
top_proposals:
  - id: P1
    title: "Closed-loop harness and repair-procedure self-improvement on family-separated sealed tasks"
    one_line: "Headless Motoko edits its config/skills/prompts/tools/guards from dev journals; an isolated evaluator scores diffs across k=3 replicates on root-cause-separated historical reverts, planted/oracle tasks, and clean controls, then tests compounding via an M_0-vs-M_1 author comparison on a shared baseline."
  - id: P2
    title: "Gate 0: mechanical, wall-clock-free multi-gate safety floor and Part-A dry run"
    one_line: "Before spending model tokens, pin a green, non-wall-clock safety floor (check_core, corpus_judge, ledger_parity, journal_resume, verify_core, native-FS fixture) and prove 100% mechanical task scoring with zero human rulings."
  - id: P3
    title: "Stage-2 mutation-guided oracle strengthening on held-out faults"
    one_line: "Once P1 lifts Motoko's coding reliability, run fable's oracle-only loop against held-out mechanical mutants and prospective live defects with known-good commit survival controls."
first_experiment:
  what: "Gate 0 dry run + 24 root-cause-separated tasks on 2eae0666 (6 dev; 18 sealed holdout: 10 historical reverts, 4 planted/oracle tasks, 4 clean no-change controls), hash-pinned in sequence.log. Score M_0 and comment-only K_0 (k=3, 54 holdout runs each), run up to 2 self-improvement rounds to produce M_1, then run an author-vs-author compounding check (M_0 vs M_1 both editing M_1 on fresh dev failures)."
  pass_if: "Gate 0 achieves 100% mechanical scoring on a green baseline; K_0 delta <= 3/54 and rejected; M_1 beats M_0 on sealed holdout with paired family-level permutation p < 0.05 (>= +15 pp across 54 runs), 4/4 clean controls untouched, safety floor 100% green, proxy USD/task <= 1.25x M_0; and M_1's offspring beats M_0's offspring on fresh families (or establishes a clean null)."
  fail_if: "Gate 0 needs human adjudication; K_0 false-accepts or exceeds noise bound; M_1 fails p < 0.05 or triggers any false alarm on clean controls or safety-floor regression; or M_0 fails to emit compiling diffs across both rounds."
  cost: "5-6 engineering days (Gate 0 safety floor + container/proxy/watchdog harness + 24 family-separated calibrated tasks); ~$200-$350 API spend ($400 proxy cap, realistic ~150k-token/task budget) and 10-14 hours wall-clock at 2-3 parallel containers."
disagreements:
  - with: fable
    about: "Improving driver_only checks first vs improving Motoko's coding/repair harness first; also fable's P2 rests on the obsolete v0.47 16 MiB compile-cache cap raised to 64 MiB in v0.52.2+."
    material: yes
  - with: astra
    about: "Restricting self-edits to a 300-word prompt paragraph (too narrow to fix harness/tool traps), using 1 trial per task (fails against Motoko's 27% flip rate), and a 25k cumulative token cap (too small for Motoko's prompt + multi-step file reads)."
    material: yes
  - with: prior-docs
    about: "Keeping DST at the centre (m-motoko-dst-recursive-self-improvement.md) or prioritizing ADR-004 P2-P3 allocation gating (014/NOTE-001 item 2) ahead of a sealed competence benchmark."
    material: yes
would_change_my_mind_if: "Gate 0 dry run shows M_0 cannot produce compiling AILANG patches even on dev tasks without manual bootstrapping, OR a small calibration probe shows a single 300-word prompt paragraph already solves >= 80% of repo/checker failures without touching tools, timeouts, or extensions."
embargo_notes: "Round-1 embargo lifted; read all required earlier plans (m-motoko-dst-recursive-self-improvement.md, 014/NOTE-001-re-read-2026-11-02.md, 042/README.md, 042/RESEARCH-improving-experimentation.md, 042/NOTE-001-preregistered-method-comparison.md, 032/RESEARCH-dream-rsi-implications.md TL;DR)."
```
