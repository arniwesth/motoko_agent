# Gemma-4-AILANG: GRPO Reinforcement Learning Approach

## Source

Analysis based on Unsloth's Gemma 4 RL Sudoku notebook:
https://colab.research.google.com/github/unslothai/notebooks/blob/main/nb/Gemma4_(E2B)_Reinforcement_Learning_Sudoku_Game.ipynb

Cross-referenced with the existing Gemma-4-AILANG session transcript (SFT-only plan) in:
`.agent/research/Gemma-4-AILANG_session_transcript.md`

---

## The Sudoku RL Pattern (GRPO)

The Unsloth notebook trains Gemma 4 to solve Sudoku via Group Relative Policy Optimization (GRPO):

- **Prompt:** Fixed natural-language prompt asking the model to write a Python `strategy(board, initial)` function
- **Generation:** Model produces multiple completions per prompt at temperature=1.0
- **Reward:** Three layered functions score each completion against ground truth:
  1. `function_works` (+1 / -2): Does it parse as valid Python?
  2. `no_cheating` (+1 / -20): Does it avoid importing external modules?
  3. `strategy_succeeds` (scored by valid moves / game state): Does the generated strategy actually solve the puzzle when executed?
- **Training:** GRPO updates policy toward higher-reward completions
- **Config:** `GRPOConfig` with `loss_type='bnpo'`, `temperature=1.0`, `num_generations=2`, LoRA rank 32, runs on free T4
- **Key insight:** The reward is *not* a learned preference model -- it is ground-truth verification by executing the code

---

## Why AILANG + RL Is a Natural Fit

AILANG is a *better* fit for this pattern than Sudoku. The Sudoku notebook works because there is a deterministic oracle: run the strategy, check if the board is valid. AILANG has **three** deterministic oracles, each more powerful than the last:

| Oracle | Command | What it proves | Signal quality |
|--------|---------|---------------|----------------|
| Parser + type checker | `ailang check` | Syntactic validity + type correctness | Binary, noise-free |
| Runtime | `ailang run` + compare output | Functional correctness on specific inputs | Deterministic for given inputs |
| Z3 verifier | `ailang verify` | Mathematical correctness for **ALL** inputs | Perfect oracle -- strongest possible signal |

No human annotation. No learned reward model. No teacher errors. The compiler IS the reward model.

---

## Why RL Is Strictly Better Than Pure SFT for This Problem

The existing plan (Gemma-4-AILANG session transcript) is pure SFT distillation from Claude Opus. That has a ceiling:

1. **SFT teaches imitation.** If Opus scores 0-17% on contract benchmarks, the student cannot exceed 17% by imitating Opus. SFT bakes in the teacher's failure modes.

2. **RL teaches from ground truth.** The model does not learn "what Opus would write" -- it learns "what actually compiles and verifies." This is the DeepSeek-R1 / AlphaGo insight: learning from a perfect verifier lets you surpass the teacher.

3. **The contract benchmarks are the prize.** The session transcript explicitly identifies `Contract Matrix Determinant` (17%), `Contract Rle Roundtrip` (0%), `Type Unify` (0%) as the hackathon differentiator. SFT from a teacher that scores 0% on these cannot solve them. RL with `ailang verify` as the reward *can*.

---

## Optimal Pipeline: SFT Then RL

The standard pipeline (and the right one here) is two phases:

### Phase A -- SFT Warmup (existing plan, but smaller role)

Generate ~500-1000 examples from Opus. Fine-tune with QLoRA. This gets Gemma from "writes Python when asked for AILANG" to "writes something AILANG-shaped." The model needs to be in the right neighborhood before RL can refine it -- if it generates pure Python, the reward signal is always -2.0 and GRPO learns nothing.

### Phase B -- GRPO Refinement (new)

Use the SFT checkpoint as the starting point. Run GRPO with AILANG-specific reward functions. This is where the model goes from "imitates Opus at 40% parse rate" to "actually compiles at 90%+ and can write verified contracts."

---

## Concrete Reward Functions for AILANG GRPO

Direct analog to the Sudoku notebook's three-reward structure:

```python
def ailang_parses(completions, **kwargs):
    """Reward 1: Does the generated code parse and type-check?"""
    scores = []
    for completion in completions:
        code = extract_ailang_code(completion[0]["content"])
        if code is None:
            scores.append(-2.0)  # No code block found
            continue
        # Write to temp file, run ailang check
        result = run_ailang_check(code)
        if result.returncode == 0:
            scores.append(2.0)   # Parses + type-checks
        elif "Parse error" in result.stderr:
            scores.append(-1.0)  # Doesn't even parse
        else:
            scores.append(0.0)   # Parses but type error
    return scores

def ailang_correct_output(completions, prompts, expected_outputs, **kwargs):
    """Reward 2: Does it produce the right output when run?"""
    scores = []
    for completion, expected in zip(completions, expected_outputs):
        code = extract_ailang_code(completion[0]["content"])
        if code is None:
            scores.append(0.0)
            continue
        result = run_ailang(code, caps="IO")
        if result.stdout.strip() == expected.strip():
            scores.append(5.0)   # Correct output
        elif result.returncode == 0:
            scores.append(1.0)   # Runs but wrong output
        else:
            scores.append(0.0)   # Doesn't run
    return scores

def ailang_verified(completions, **kwargs):
    """Reward 3: Do the Z3 contracts verify? (The killer signal.)"""
    scores = []
    for completion in completions:
        code = extract_ailang_code(completion[0]["content"])
        if code is None:
            scores.append(0.0)
            continue
        result = run_ailang_verify(code)
        # Count verified vs failed functions
        verified = result.stdout.count("VERIFIED")
        violated = result.stdout.count("VIOLATION")
        if violated > 0:
            scores.append(-3.0)
        elif verified > 0:
            scores.append(10.0)  # Heavy reward -- this is the goal
        else:
            scores.append(0.0)   # No contracts to verify
    return scores
```

### Reward Shaping Rationale

Graduated scores, not just pass/fail. The model needs a gradient to climb:

```
"doesn't parse" (-2.0)
  -> "parses but wrong types" (-1.0)
    -> "type-checks but wrong output" (0.0)
      -> "runs but wrong output" (+1.0)
        -> "correct output" (+5.0)
          -> "verified contracts" (+10.0)
```

---

## Practical Concerns

### 1. Reward Latency

The Sudoku notebook runs the game in-process (pure Python, microseconds). AILANG requires shelling out to the `ailang` binary for each completion. This adds ~100ms-1s per check. With `num_generations=2` and batch size 1, this is tractable. With larger generation counts it becomes the bottleneck.

**Mitigation:** Batch the checks, or run the ailang binary as a persistent process.

### 2. Prompt Diversity

The Sudoku notebook uses a single fixed prompt repeated 1000 times -- diversity comes entirely from the model's temperature. For AILANG, we need a diverse prompt set: "Write fizzbuzz," "Write a verified tax calculator," "Parse JSON and filter by age," etc.

**Source:** The existing AILANG benchmarks at `ailang.sunholo.com/docs/benchmarks/performance` provide exactly this.

### 3. SFT Warmup Is Mandatory

If you skip SFT and go straight to RL, Gemma writes Python. Every completion scores -2.0. GRPO has no signal to learn from. The SFT phase gets the model into the basin of attraction where RL can find the gradient.

### 4. Hardware

The Sudoku notebook runs on a free T4. AILANG RL would need more because (a) we need the `ailang` binary available in the training environment, and (b) reward computation is slower. A single A100 with QLoRA is realistic for a pilot.

### 5. ailang Binary in Training Environment

The `ailang` binary must be available on the training machine. This means either:
- Pre-installing it in the Docker/VM image
- Bundling the vendored `ailang/` fork from this repo
- Using a sidecar process or API endpoint for compilation checks

---

## Revised Full Pipeline

| Phase | Method | What it does | Hardware | Cost estimate |
|-------|--------|-------------|----------|---------------|
| Phase 0 | SFT (QLoRA) | Teach basic AILANG syntax via Opus distillation. ~500 examples. Gets parse rate from ~0% to ~40%. | 1x A100 | ~$25 |
| Phase 1 | GRPO (QLoRA) | Refine with compiler-as-reward-model. Model learns what actually compiles and verifies, not what Opus thinks should compile. | 1x A100 | ~$50-100 |
| Phase 2 | GRPO (high-rank LoRA or FFT) | Scale up: larger prompt set, longer training, bfloat16 precision. Target contract benchmarks. | 8x H100 | ~$400 |

### Success Criteria by Phase

- **After Phase 0 (SFT):** >40% `ailang check` pass rate. Baseline for RL.
- **After Phase 1 (GRPO pilot):** >70% `ailang check` pass rate. At least one compiling Z3 contract. Proves RL works for AILANG.
- **After Phase 2 (GRPO full):** >90% `ailang check` pass rate. >50% on contract benchmarks (currently 0-17% for frontier models). This is the hackathon-winning result.

---

## Reference: Sudoku Notebook Training Config

```python
from trl import GRPOConfig, GRPOTrainer
training_args = GRPOConfig(
    temperature = 1.0,
    learning_rate = 5e-5,
    weight_decay = 0.001,
    warmup_ratio = 0.1,
    lr_scheduler_type = "linear",
    optim = "adamw_8bit",
    logging_steps = 1,
    per_device_train_batch_size = 1,
    gradient_accumulation_steps = 2,
    num_generations = 2,
    max_completion_length = max_completion_length,
    max_steps = 60,
    save_steps = 100,
    epsilon = 0.2,
    epsilon_high = 0.28,
    delta = 1.5,
    loss_type = 'bnpo',
    mask_truncated_completions = True,
)

trainer = GRPOTrainer(
    model = model,
    processing_class = tokenizer,
    reward_funcs = [
        function_works,
        no_cheating,
        strategy_succeeds,
    ],
    args = training_args,
    train_dataset = dataset,
)
```

For AILANG, the analog would replace the three reward functions with `ailang_parses`, `ailang_correct_output`, and `ailang_verified`.

---

## Key Takeaway

The existing plan (SFT distillation from Opus) has a hard ceiling at the teacher's performance. RL with the AILANG compiler/verifier as the reward model has no such ceiling. The compiler is a perfect oracle. Z3 verification is an even more powerful signal. The combination of SFT warmup + GRPO refinement is the optimal approach, and the Unsloth Sudoku notebook provides a direct, working template for the RL phase.
