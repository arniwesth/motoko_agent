# Handoff: re-run the CRC scout experiment with a STRONGER model

You are continuing the autoresearch "does the literature scout add value?" thread.
The `autoresearch_crc` fixture is built and the deepseek-v4-pro experiment is done
(see `session-summary-2026-06-03-scout-value.md` + `crc-fixture-operator-notes.md`).
This session: **re-run it with a stronger model** to test whether the result is
model-specific.

## The question under test

deepseek-v4-pro gave a THIRD null, via a new mechanism: the scout SUCCEEDED at
retrieval (found `corsix/fast-crc32`, verified the fold invariant) but the model
**could not implement the reflected custom-poly PMULL fold** — specifically the
**Barrett reduction from 64→32 bits** — across 0/6 conditions (cold 0/3, arm A,
arm C @50 steps, arm C @100 steps; it stopped voluntarily at step 82/100). Verdict:
**capability ceiling, not budget or reasoning-effort** (it was already reasoning
heavily; effort knob is weak/adaptive).

So the open question: **is that ceiling model-specific?** With a stronger model:
- (a) It implements folding **cold** (arm A reaches it) → still a scout null, but
  the ceiling is now *reachable* → confirms the barrier was capability and this
  model clears it. Fixture becomes "in-weights-implementable" like simdjson.
- (b) It implements folding **only with the scout** (arm C lands it, arm A doesn't)
  → **the first genuine positive** for scout value: retrieval converts a technique
  from un-implementable to implementable.
- (c) It **also fails** → the reflected-fold barrier generalizes across frontier
  models in this harness; strong evidence the binding constraint for this
  autonomous loop is implementation capability, not retrieval.

Any of the three is a publishable result; (b) is the one we've been hunting.

## Suggested model

`openrouter/xiaomi/mimo-v2.5-pro` (confirmed on OpenRouter 2026-06-03: supports
`tools`, `tool_choice`, `reasoning`, 1M context). Alternatives if it's flaky in the
harness: `xiaomi/mimo-v2.5`, or another frontier reasoner (qwen3-max, glm-5, kimi).

## PRE-FLIGHT (do these BEFORE any full run — they're cheap and save hours)

1. **Smoke-test multi-turn tool use in the harness.** Prior sessions found models
   that break here: deepseek-v4-flash was provider-degraded (empty completion after
   a tool result), MiniMax-M3 had reasoning truncation + malformed/duplicated tool
   args. A new model MUST be verified to drive a 2–3 step tool loop cleanly before a
   40–90 min run. Quick check: run it on a trivial 1-tool task via run-agent.sh and
   confirm it emits well-formed tool calls and survives a tool result.

2. **Cold-screen the new model on the CRC task FIRST** (the cheap novelty gate —
   this directly predicts arm A and answers sub-question (a) vs (c)). Reuse
   `.motoko/ar_bench_scratch/crc_coldcheck.py` — just change the model string to
   `xiaomi/mimo-v2.5-pro` — and compile-verify its output with `crc_verify.c`
   (point it at the model's code). $0.01–0.1.
   - If it produces a CORRECT fast fold cold → arm A will likely reach the ceiling;
     the scout is theater (regime a). Decide whether the experiment is still worth
     running (probably re-frame as "ceiling now reachable").
   - If it fails cold like deepseek did (reaches for folding, wrong Barrett
     reduction) → proceed to the full A/B; regime (b) or (c) is in play.
   - Note: cold-screen at the model's DEFAULT reasoning (no effort param), matching
     how the harness runs it (see below). Optionally also probe effort=high.

3. **Check the model's reasoning behavior** (per the thinking-level investigation):
   nothing in the stack sets reasoning effort, so the harness uses the provider
   default. If mimo's effort knob is strong (unlike deepseek's weak/adaptive one),
   consider whether to set `think` — but default-parity with the deepseek runs is
   the cleaner comparison, so prefer leaving it unset unless you have a reason.

## Verified run recipe (carried from this session — these mechanics work)

Worktree `/workspaces/motoko_agent_crc_wt` already exists (branch
`autoresearch/crc-noscout`, baseline `dcaf70d` = fixture with operator notes
stripped). Reuse it; reset between runs.

```bash
cd /workspaces/motoko_agent
WT=/workspaces/motoko_agent_crc_wt
MODEL=openrouter/xiaomi/mimo-v2.5-pro

# --- per run: reset to clean baseline + clear scratch ---
git -C "$WT" reset --hard dcaf70d
git -C "$WT" clean -fdq
rm -rf "$WT/.motoko/autoresearch_crc_"* "$WT"/*.html "$WT/.motoko"/*.c "$WT"/test_* 2>/dev/null

# --- IMPORTANT KNOBS ---
# max_steps is governed by the WORKTREE config (NOT env, NOT AI_MAX_STEPS).
# deepseek needed 100 and still stopped at 82; use >=100 for a fair capability test:
python3 - "$WT/.motoko/config/default/config.json" <<'PY'
import json,sys; p=sys.argv[1]; c=json.load(open(p))
def s(d):
    [ (d.__setitem__(k,100) if k=="max_steps" else s(v)) for k,v in (d.items() if isinstance(d,dict) else []) for _ in [0] ]
s(c); json.dump(c,open(p,"w"),indent=2)
PY

set -a; . .env; set +a

# ===== ARM A (no scout): strip exa_search from the WORKTREE profile =====
python3 - "$WT/.motoko/config/default/config.json" <<'PY'
import json,sys; p=sys.argv[1]; c=json.load(open(p))
c["extensions"]["order"]=[e for e in c["extensions"]["order"] if e!="exa_search"]
json.dump(c,open(p,"w"),indent=2)
PY
PROMPT=$(awk 'f{print} /^-->/{f=1}' benchmarks/prompts/crc_autonomy_noscout_task.md)
MODEL=$MODEL WORKDIR="$WT" CORE_EXT_ORDER=autoresearch MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8190 \
  timeout 6000 ./scripts/run-agent.sh "$PROMPT" > .motoko/ar_bench_scratch/crc_mimo_noscout_seed1.jsonl 2>&1

# ===== ARM C (scout): exa_search ENABLED via CORE_EXT_ORDER (re-run the reset first) =====
PROMPT=$(awk 'f{print} /^-->/{f=1}' benchmarks/prompts/crc_autonomy_scout_task.md)
MODEL=$MODEL WORKDIR="$WT" CORE_EXT_ORDER=autoresearch,exa_search MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8191 \
  timeout 6000 ./scripts/run-agent.sh "$PROMPT" > .motoko/ar_bench_scratch/crc_mimo_scout_seed1.jsonl 2>&1
```

Verify exa_search presence/absence per arm via the `session_start` `loaded_extensions`
event in the log. Grade each kept candidate on held-out TEST:
```bash
LASTKEEP=$(git -C "$WT" log --grep="autoresearch: keep" -n1 --format=%H)
git -C "$WT" checkout "$LASTKEEP" -- benchmarks/fixtures/autoresearch_crc/candidate/crc.c
CRC_CANDIDATE="$WT/benchmarks/fixtures/autoresearch_crc/candidate/crc.c" \
  bash benchmarks/fixtures/autoresearch_crc/bench/grade_test.sh
grep -ciE 'vmull|pmull|fold|clmul' "$WT/.../candidate/crc.c"   # did it land folding?
```

## How to read the result

- The tell for "landed folding" is a kept candidate that (a) **uses vmull/pmull**
  AND (b) grades **>> the slicing plateau** (deepseek topped out ~5.5 GB/s on
  slice-32; real PMULL folding should be ~10–30 GB/s). A kept slicing candidate at
  ~5 GB/s = folding NOT reached, same as deepseek.
- Same-budget fairness: run BOTH arms at the same `max_steps` (100) for the
  comparison. For a statistical claim, N≥4–6 seeds/arm; but the mechanism (did
  folding land, in which arm) is readable at N=1 like it was this session.
- Parse logs as JSONL with Python (grep gives false positives from the prompt echoed
  in `session_start`). The agent's `done` event has its own final summary; the
  `reasoning_delta`/`thinking` events show its trajectory; check `test_*.c` BashExec
  outputs for `MISMATCH` vs `correct!` on its folding attempts.

## Guardrails (unchanged, important)

- **Non-leak discipline.** Keep answer-bearing files OUT of the run worktree: the
  prompts' design comments and the `crc-fixture-operator-notes.md` name the
  technique. The worktree at `dcaf70d` already has the operator notes stripped;
  if you recreate the worktree, re-strip them (an auto-commit had tracked them into
  the base commit — verify with `ls "$WT/.agent/plans/.../crc-fixture-operator-notes.md"`).
  Prompts are read from the MAIN repo (`awk` strips the `<!-- -->` design comment)
  and are NOT in the worktree — keep it that way.
- Build is `gcc -O2 -march=armv8-a+crypto` (so `vmull_p64` compiles); the custom
  polynomial 0xB2A8D703 is non-hardware so no `crc32` intrinsic shortcut. duckdb is
  required by `ar_init` (`which duckdb`).
- Commit only the fixture if needed; leave `.motoko/config/default/config.json` and
  `ailang.lock` (v0.19.1 vs v0.22.0 — still an open pre-existing decision) dirty
  unless the user decides.

## State of the tree (start of this handoff)

- Committed (branch `autoresearch-loop`, `2a75e85`): `benchmarks/fixtures/autoresearch_crc/`.
- Uncommitted: `benchmarks/fixtures/autoresearch_intcodec/` (Stream VByte, parked —
  contaminated), `benchmarks/prompts/{intcodec,crc}_autonomy_{scout,noscout}_task.md`,
  the two `*-operator-notes.md`, `session-summary-2026-06-03-scout-value.md`, this handoff.
- Worktree `/workspaces/motoko_agent_crc_wt` @ `autoresearch/crc-noscout` (baseline
  `dcaf70d`) holds the deepseek experiment keep-commits — reset it before reuse.
- Logs from this session: `.motoko/ar_bench_scratch/crc_{noscout_seed1,scout_seed1,
  scout_seed1_t5400,scout_seed1_steps100}.jsonl`; screens `crc_coldcheck*`,
  `intcodec_coldcheck*`; `crc_verify*.c`, `fold_dev.c`.
- Memory: `autoresearch-novelty-cold-check.md`, `autoresearch-fixture-leak-discipline.md`.
