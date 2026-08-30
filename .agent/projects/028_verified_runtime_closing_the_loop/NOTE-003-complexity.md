# NOTE-003 — Complexity: measured, and the levers to lower it (2026-08-30)

Companion to NOTE-002 (same second session, ~130 live steps). QUESTION: the
first session's verdict called the taxonomy "real weight" — how heavy is it,
exactly, and what would lower it? Method: measurement first, levers second.
Cross-references: ADR-002 (the decision this implies), PLAN-002 (the work
items), NOTE-001 (the 9/10-7/10-6/10 frame this does not change).

## Measurements (all reproducible one-liners)

| Dimension | Number | Reproduce |
|---|---|---|
| Distinct `WI-` sprint ids cited in core | **48 distinct / 861 mentions / 33 of 56 files** | `grep -rhoE "WI-[A-Z0-9]+" src/core/*.ail \| sort -u \| wc -l` etc. |
| Parallel numbering systems | 12 `M-MOTOKO-*` + 9 `D#` + 2 ADR refs | same pattern |
| `phase_vocab.ail` (the hub) | **52 exported types, 42 funcs, 33-variant LedgerEvent**, fan-in 13 modules | `grep -c "^export type" ...` |
| `session.ail` | 3,706 lines, 9 exported entry points, 1,116 comment lines | `grep -c "" ...` |
| Makefile | **2,760 lines, 103 targets** | `wc -l` / `grep -cE "^[a-zA-Z_-]*:"` |
| Top-level docs vs code-carried rationale | 974 doc lines vs 1,116 comment lines in `session.ail` ALONE (47% of `dst_generator.ail`) | `wc -l` |
| `run_v2_with_scripted_ports` | **12 positional parameters**, adjacent same-typed ints (`step_budget`, then `max_cost_millicents`) | session.ail signature |
| Production-imports-test-fixture | `rpc.ail` (the runtime entry) imports `src/core/test/stub_step` — test code in the production import graph | `head -30 src/core/rpc.ail` |

Reading: a majority of core files are unreadable without sprint archaeology;
four parallel numbering systems; one hub with fan-in 13; several self-described
"compatibility adapter[s] ... kept until they are audited" entry points
(~L3394).

## The structural finding

The complexity is not in the algorithms — `decide`, `affine_calibrate`,
`bounded_draw` are each a screen long and clean. It is that the **rationale
layer is hand-woven into artifacts no gate protects**: 861 WI mentions, 60%
comment ratios, Makefile pins — all editable prose, all drifting (doc drift is
the ONE finding class both independent sessions share: missing FORK.md, rotted
`discount_calculator.ail`, stale "SKIPPED — Z3 fragment" annotations | NOTE-002
defect 2; NOTE-002 fold wall).

Meanwhile the repo already trusts the cure — ONE pattern, used three times:
generate the artifact, gate the generator (`registry_gen_check`; the event
vocabulary's own validator; `make dst`). Complexity work = applying that
pattern to the rationale layer itself. Details in ADR-002; work items in
PLAN-002.

## The five levers (summary; PLAN-002 has items)

1. **Glossary, generated + gated** — WI/M/D/ADR ids become lookup, not
   archaeology; the only lever that stops new ids accreting.
2. **Retire the compatibility surface behind a surface-check gate** — 9
   `run_v2*` entry points → 1 + options record (closed records make the
   options record MORE type-safe than 12 positionals; kills the transposition
   footgun).
3. **Split the hubs along seams the code already names** — `dst_program`→
   `dst_interaction` is the in-repo precedent; apply to `phase_vocab`
   (events / state / policy) and to `session.ail` (loop vs DP7 vs fixtures;
   moves `stub_step` out of the production import graph).
4. **Promote a runnable tour** — five `tmp/demo/*.ail` files from this session
   (decide, loop, checkpoint/calibration, PRNG, events) are the doc set that
   CANNOT rot once CI-run — the direct fix for the example-rot defect class.
5. **Failure-mode triage rule for the toolchain** — every failure is a
   diagnostic+fix-hint or a skip+reason, never a hang, never a silent success
   (the two classes both sessions hit: `PAR_INFINITE_LOOP`; batch-skip exit 0).

## What NOT to do

- Don't chase file-count minimization (splitting raises `ls` noise but lowers
  coupling — coupling is the real cost; module headers are the antidote).
- Don't erase the WI history (load-bearing traceability; glossary makes it
  cheap, deletion makes it gone).
- Don't big-bang the Makefile into "a real test framework" (generate the check
  matrix from a manifest instead; the pins are the immune system).
- Don't gate on prose quality (no "doc coverage" CI — it breeds box-ticking;
  gate on existence, drift, and rot only).
