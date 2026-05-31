# Autoresearch Method Ledger

## 2026-05-31 - Polyglot 0.5a - ReAct-style action loop

- Paper: ReAct: Synergizing Reasoning and Acting in Language Models, Yao et al., arXiv:2210.03629, https://arxiv.org/abs/2210.03629
- Claim used: interleave brief reasoning with task-specific actions so the agent can update plans from observations and recover from tool/environment issues.
- Candidate change: `benchmarks/prompts/polyglot_system.md` added an explicit inspect -> edit -> test loop and told the model to continue with direct file reads if `Search`/`rg` is unavailable.
- TRAIN measurement: baseline segment 2 run #1 median `pass_rate=0.5833335`, candidate run #2 median `pass_rate=0.75`; within-run MAD for candidate `pass_rate=0.083333`, so `ar_log keep` committed the prompt change.
- Held-out TEST measurement: `grade_test.sh` on the disjoint TEST split scored `pass_rate=0.000000`; all six exercises timed out or errored under `openrouter/deepseek/deepseek-v4-flash`.
- Follow-up: next segment should retry the same held-out transfer check with `openrouter/deepseek/deepseek-v4-pro`.
- Verdict: positive TRAIN result, no held-out transfer under the current DeepSeek-only route; count this as a non-reproduction for exit-gate purposes.
- Pro route follow-up: with `openrouter/deepseek/deepseek-v4-pro`, the default prompt scored `pass_rate=1.000000` on both TRAIN and held-out TEST. This isolates the Flash result as route/capability limited, but it does not validate the ReAct candidate as the causal improvement.
