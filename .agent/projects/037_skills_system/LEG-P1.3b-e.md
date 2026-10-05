# LEG-P1.3b/c/d/e — model measurements: estimate first, then measure (dagr tasks `P1.3b`–`P1.3e`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this assignment. You do not implement any other part, you do not edit the ADR or
the plan, you do not write any dagr run file, and you do not touch other panes, tabs or
worktrees.

## What this is

PLAN-001 §3 rows b–e, run through the real prototype the P1.2 delegate built. **This
assignment has two phases with a hard stop between them.** Phase 1 states a cost
estimate; the operator approves it (Q-SPEND, and Q-OPENAI for row e) before phase 2 runs
anything that spends.

## Where you work

Worktree `/workspaces/motoko_agent-p1proto`, scratch branch `scratch/p1-prototype`
(verify with `git rev-parse HEAD` and `git branch --show-current` before you start). Your
`cwd` is that worktree root. Do not touch the shared checkout at
`/workspaces/motoko_agent`, the worktrees `/workspaces/motoko_agent-skills` and
`/workspaces/motoko_agent-fix3`, or any other session's panes, tabs or paths. Push
nothing. Commit nothing — neither on the scratch branch nor on `feat/skills-extension`.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0.5 (spend), §3 P1.3 rows b–e.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **A5** (what is
   measured), **D4** (16,000-char budget; OpenAI's reported 1,024-char cap), **D8**
   (compactors, 70%/75% thresholds, 25% size check).
3. `.agent/projects/037_skills_system/evidence/m2_trigger_probe.py` — the M2 task set
   (15 tasks) and the three models (`meta/muse-spark-1.3-contributor`,
   `deepseek/deepseek-v4-pro`, `deepseek/deepseek-v4-flash`). Reuse the tasks; do not rewrite.
4. `.agent/projects/037_skills_system/evidence/m8_description_limit_probe.py` — the
   provider-family probe shape for row e. Note it predates the prototype.
5. `.motoko/herdr-delegates/p1.2/` in this worktree — the prototype, `skills_proto`
   profile, fixture workdir builder, and recorder harness. The P1.2/P1.3a reports (your
   orchestrator holds them) add: layout 1 (sibling) is the working layout — run every
   session that way; layout 2's relative-`--workdir` profile miss is with the operator
   and is NOT yours to work around.

## Phase 1 — estimate (do this now; then STOP and send back)

State, per row b–e: requests per model × models × expected steps/tokens, at current
OpenRouter prices, with the total. Calibration: the research proxy cost ~$0.50 for 450
single-step requests; harness runs are multi-step. Row e is one request per provider
family at budget size, OpenAI included — flag it separately, because this account's
OpenAI key was rejected on 2026-10-03 (Q-OPENAI: the operator supplies a route or rules
OpenAI out of scope). Send the estimate back and STOP. Do not run any spending call
until the orchestrator relays the operator's go-ahead.

## Phase 2 — measure (only on the orchestrator's go-ahead, relayed in a follow-up)

- **Row b (dagr `P1.3b`):** M2 task set through the real runtime under `skills_proto`
  on the fixture workdir, on the three profile models. Per model: Skill-as-first-call
  rate, Skill-called-at-all in the first response, and whether the checkable action
  (`workdir-stamp`: `STAMP.txt` containing the bundled token) was done. Fixture skills
  are already in the workdir; rebuild with `p1.2/build_fixture.sh` if needed.
- **Row c (dagr `P1.3c`):** a run driven past 70% usage under the structural compactor,
  then under `compaction_ai` at 75%. Per compactor: reloads per run, tokens they cost,
  whether the model calls Skill again once the result is elided/summarised.
- **Row d (dagr `P1.3d`):** a model whose context is small enough that D8's size check
  must answer with its error instead of loading. Live check, not the stub-port table
  P1.2 already produced.
- **Row e (dagr `P1.3e`):** one request with the index at the 16,000-char budget to
  each provider family the profiles use, OpenAI included. If OpenAI rejects it, STOP
  that row and report verbatim — D4 returns to the operator.

Output (phase 2): scripts and result tables under `.motoko/herdr-delegates/p1.3/`
(gitignored, kept for P1.N), committed later to `evidence/p1/` on `feat/skills-extension`
by a later task — NOT by you. Reported, not gated.

## Rules that bind you

- No spending call in phase 1. In phase 2, only what the relayed approval covers; if the
  approval sets a cap, stay under it and say so. No credentials in any file or output —
  keys arrive via the environment, never written down.
- Heavy runs one at a time. Sessions run in layout 1 only.

## What to send back

Phase 1 (now): the per-row estimate table plus total, the row-e OpenAI flag, HEAD plus
`git status --short`. Phase 2 (later): per-row result tables with the raw captures kept
under `.motoko/herdr-delegates/p1.3/`, HEAD/state, anything that could not run and why.
In both phases, write the answer file with WriteFile before replying.
