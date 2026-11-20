# astra — round 2

## A. Fable and Neon

**Fable.** A split by patch hash can put two versions of the same fault mechanism on opposite sides. Of eight independently written “blind” mutations in the recovery experiment, three exactly duplicated prescribed edits. Removing them changes the result from six kills in eight to three in five. Two extra kills would establish that the new rule detects those two edits. I would require a new causal mechanism before calling that transfer. I take Fable’s distinction between reaching the faulty path and observing a wrong result there. I confirmed that `candidate.py` enforces `resource-only` and refuses edits to the DST modules. An oracle-editing experiment needs a different admission policy. (`.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/README.md:90–104`, `scripts/eval/candidate.py:165,185–205,436–444`)

**Neon.** Two accepted descendants show progress on the bank that selected them. An inherited timeout fix could also give the second author more opportunities, while the original author, given that same starting point, might propose an equally good successor. Compare authors editing the same parent. I take Neon’s referee-owned model and cost meter. The proposed test-writing arm still executes each submitted test during scoring, so the expected answers belong outside that process. Neon is right about journal admission. At this HEAD, `mode_admit` sends every real entry to `exit(1)`. My two admitted prefixes came from a separate evaluator revision. Motoko reads the system prompt as text, so a comment changes what the model sees. Use identical prompt bytes to measure noise. (`.agent/projects/044_rsi_fresh_look/discussion/round-1/neon.md:18–38`, `scripts/eval/journal_replay.ail:209–215,234–239`, `.agent/projects/013_core_architecture_for_dst/HANDOFF-2026-09-20-plan004-p24-parked.md:16–20`, `src/core/rpc.ail:295–305,390–393`)

## B. The case for DST

The strongest case is cumulative experimental evidence. A controlled world runs production transitions, makes a failure reproducible for diagnosis and lets investigators keep the counterexample as a regression check for every descendant. Generation also lets a changed driver take a different action within the modelled world. That case survives for driver investigations. A revised repair procedure changes what the live model asks and tries, so its improvement needs fresh outcomes. The original direction explicitly requires that distinction and a repair-only control. (`design_docs/planned/m-motoko-dst-recursive-self-improvement.md:15–25,43–53,67–78`, `.agent/projects/032_dream_rsi/RESEARCH-dream-rsi-implications.md:72–85`)

I missed the value of an *inconclusive* diagnosis. In the 30-site pilot, a mutant and its control emitted identical wire output, yet only the mutant wrote a file. Generating more wire comparisons would have rewarded persistence with no new evidence. I would adopt 042’s diagnosis categories and charge the improvement for human adjudication and rejected attempts. Its lighter protocol freezes predictions, separates the answer key and scores by reproduction. (`023b0f02`, `.agent/projects/014_comparative_self_evolution/NOTE-001-re-read-2026-11-02.md:215–238`, `.agent/projects/042_improving_experimentation/RESEARCH-improving-experimentation.md:53–67,112–133`, `.agent/projects/042_improving_experimentation/NOTE-001-preregistered-method-comparison.md:130–147`)

## C. The four disagreements

For both participants’ history queries I also checked whole patches at `2eae0666`. Counting one hash per entry gave 25 and 123 commits. Running `git diff --binary C^ C | git apply --reverse --check` for each gave **2/25** and **25/123** clean reversals respectively. This checks textual applicability alone. (`.agent/projects/044_rsi_fresh_look/discussion/round-1/fable.md:164–171`, `.agent/projects/044_rsi_fresh_look/discussion/round-1/neon.md:23`)

1. **Target.** Improve the repair procedure first because its output can be tested on both the faulty input and a nearby valid case. Broaden to whole-harness competence after demonstrating that the promoted procedure produces better successors.
2. **Prerequisite.** A mechanical, two-sided verdict on each pilot case is necessary before promotion. Making the whole DST sweep cheap can proceed in parallel because small checker functions already accept constructed records and return findings. (`tools/test_coverage/derive.py:347–395,737–767`)
3. **Supply.** Among the clean broad reversals, I count at least six distinct mechanisms involving truncated status, numeric decoding, argument schemas, retry ownership, summary-cache invalidation and socket contention. That supports a feasibility pilot on historical parents, but the total of independent, runnable families and the supply for multiple promotions remain [unverified]. (`fc546d68`, `23a99bc0`, `05aa3c83`, `851e27be`, `006cda86`, `6580adfc`)
4. **Noise.** Under a null of independent, equally likely win directions across families, Fable’s two extra kills, Neon’s minimum three distinct wins, and my five wins give one-sided sign-test probabilities of ¼, ⅛ and 1/32 respectively if there are zero losses. Neon’s confidence interval needs to cluster the 40 runs by family and account for successive selections, and my own single-run arms need replication given the seven task flips across profiles in an earlier 26-task comparison. (`.agent/projects/044_rsi_fresh_look/discussion/round-1/neon.md:33–39`, `/workspaces/motoko_agent/ailang/design_docs/planned/m-motoko-self-improvement-loop.md:109–130`)

## D. Revised first experiment

Qualify four historical checker defects on their original parents, eight planted defects from other families and four correct controls. Historical leads include skipped verification, an incorrectly constructed module path, omitted files and a classifier that mishandled conflicting evidence. (`4bad256e`, `3fe71b06`, `0cabdf41`, `a8b3ab03`)

Freeze the referee, witnesses and family split. Remove history and answer-bearing fixtures from worker snapshots. Run the incumbent three times on each of eight separate development tasks. Require at least one majority repair and one majority miss on development defects. Motoko uses those histories to write one replacement paragraph. Reset source between jobs so both arms inherit identical code.

Randomize three runs per arm per blind task. The external referee must reproduce the wrong verdict on the original, the intended correction on the patch and passing results on all hidden checks. A family succeeds on at least two of three runs. Promote on at least five challenger-only family wins including a historical and a planted case, zero incumbent-only wins and all twelve challenger control runs correctly leaving the source alone. Run the promoted paragraph to author a successor. Record every attempt, metered tokens and human review time. A missed threshold retains the incumbent and leaves small benefits unresolved. A shortage of qualified families stops the trial before grading.

```yaml
participant: astra
round: 2
position_changed: yes
top_proposals:
  - id: P1
    title: "Replicated trial of a self-written checker-repair procedure"
    one_line: "Promote one frozen paragraph on repairs that transfer across independent fault families."
  - id: P2
    title: "Compare successor authors on the same starting artifact"
    one_line: "Give the original and promoted procedures the same parent, development evidence and budget, then judge their offspring on fresh cases."
first_experiment:
  what: "Qualify twelve fault families and four clean controls, collect three incumbent runs on eight development tasks, then compare one self-revision with its parent on three runs per arm per blind task."
  pass_if: "At least five challenger-only majority wins, including historical and planted faults, zero incumbent-only majority wins, twelve clean challenger control runs, and a successor proposal produced under the promoted paragraph."
  fail_if: "Retain the incumbent on any missed criterion. Stop before blind scoring if qualification fails or either required development outcome is absent."
  cost: "Estimated 3–5 engineer-days, at most 122 live sessions, 3.05M tokens and 20h20m serial worker time at 25k tokens and ten minutes per session."
disagreements:
  - with: fable
    about: "Start with the repair procedure and a local referee. Driver-oracle expansion and sweep cost reduction can proceed independently."
    material: yes
  - with: neon
    about: "Defer whole-harness optimization and give each promotion an untouched family-level test."
    material: yes
  - with: prior-docs
    about: "014 ranks completing journal admission ahead of automation. This data-driven checker trial can proceed with its own qualified referee."
    material: yes
would_change_my_mind_if: "A family audit cannot support the narrow trial, or a fixed procedure produces equally good offspring from the same starting artifact on prospective failures."
embargo_notes: ""
```
