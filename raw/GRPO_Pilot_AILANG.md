# GRPO Pilot: Reinforcement Learning for AILANG Code Generation

## Objective

Prove that GRPO (Group Relative Policy Optimization) with the AILANG compiler as the reward model measurably improves Gemma 4's ability to generate valid AILANG code. This is a proof-of-concept, not a production training run.

**Success criterion:** The GRPO-trained LoRA produces a higher `ailang check` pass rate on a held-out evaluation set than the base Gemma 4 model with the same system prompt.

**Baseline (established):** Gemma 4 26B-A4B-it with the AILANG teacher prompt currently achieves a **62.7% compile rate** and **58.7% final pass rate** (with self-repair) across 42 benchmark tasks. 90.4% of failures are compile errors -- exactly the failure mode `ailang check` as a reward signal targets. See `.agent/research/Gemma4_FSharp_Benchmark_Results.md` for full data.

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  GRPO Training Loop               │
│                                                    │
│  System Prompt ──┐                                 │
│  (AILANG docs)   │                                 │
│                  ▼                                 │
│  User Prompt ──► Gemma 4 ──► Completions (N each) │
│  (coding task)   (QLoRA)     (AILANG code)         │
│                                  │                 │
│                                  ▼                 │
│                         ┌──────────────┐           │
│                         │ Reward Funcs │           │
│                         │              │           │
│                         │ 1. extract   │           │
│                         │ 2. check     │──► scores │
│                         │ 3. run       │           │
│                         │ 4. verify    │           │
│                         └──────────────┘           │
│                                  │                 │
│                                  ▼                 │
│                         Policy update (GRPO)       │
└──────────────────────────────────────────────────┘
```

The reward functions shell out to the real `ailang` binary. No learned reward model, no approximations. The compiler is the oracle.

---

## Components

### 1. System Prompt (Full AILANG Docs)

The full `ailang-v0.9.0-docs.md` (~70KB, ~17K tokens) is used as-is. No condensation needed.

Gemma 4 26B-A4B supports 256K context. 17K tokens is ~7% of the window. On an A100 80GB with QLoRA and gradient checkpointing, `max_seq_length=32768` accommodates the full doc + user prompt + 4K generation with headroom to spare.

Using the full doc eliminates the risk of accidentally cutting a critical syntax rule, stdlib signature, or contract pattern the model needs during training. One fewer component to build and maintain.

**Injection mechanism:** The system prompt is injected as the first message in each prompt's chat message list during dataset preparation in `training_core.py`:

```python
ailang_docs = open("ailang-v0.9.0-docs.md").read()

def format_prompt(task_prompt: str) -> list[dict]:
    return [
        {"role": "system", "content": ailang_docs},
        {"role": "user", "content": task_prompt},
    ]
```

This happens once during dataset construction, not per-step. The tokenizer's `apply_chat_template` handles the rest.

**File:** `ailang-v0.9.0-docs.md` (existing, no new file needed)

### 2. Training Prompts (~30 prompts)

Each prompt is a self-contained coding task that produces a single `.ail` file. Every prompt must result in a program with `export func main()` so we can run it.

**Prompt tiers by difficulty:**

| Tier | Count | Examples | Reward signal |
|------|-------|---------|---------------|
| Easy (basic syntax) | ~10 | Hello world, arithmetic, string concat, if-then-else, simple list ops | `ailang check` + `ailang run` (expected output known) |
| Medium (stdlib + effects) | ~10 | Map/filter/foldl, pattern matching on lists/ADTs, record creation/update, JSON encode | `ailang check` + `ailang run` |
| Hard (contracts + complex) | ~10 | Z3-verified pure functions, recursive ADT traversal, multi-function composition with contracts | `ailang check` + `ailang verify` |

Sources for prompt ideas:
- The 157 existing examples in `ailang/examples/manifest.json` (133 working, 13 with expected output)
- The runnable contract examples in `ailang/examples/runnable/contracts/`
- Common AILANG pitfalls from the docs (these are what the model needs to learn to avoid)

Each prompt entry includes:
```json
{
  "id": "fizzbuzz",
  "prompt": "Write an AILANG program that prints FizzBuzz for 1 to 20...",
  "expected_output": "1\n2\nFizz\n4\nBuzz\n...",
  "caps": "IO",
  "has_contracts": false,
  "difficulty": "medium"
}
```

Prompts where expected output cannot be determined deterministically (e.g., file I/O, network) are excluded — every prompt must be verifiable by the reward functions.

**File:** `training/grpo_pilot/prompts.jsonl`

### 3. Reward Functions

Four reward functions, layered from cheapest to most expensive:

```
R1: code_extractable     — Can we parse an ```ailang block from the response?
R2: ailang_check_passes  — Does `ailang check -json` return passed:true?
R3: ailang_runs_correctly — Does `ailang run` produce the expected stdout?
R4: ailang_verifies       — Does `ailang verify` report VERIFIED (not VIOLATION)?
```

**Score design (per-function, independent):**

GRPOTrainer sums scores from each reward function independently. Each function runs independently on the raw completion — there is no cross-function communication. Each function calls `extract_ailang_code()` from `ailang_helpers.py` itself, and returns 0.0 ("neutral, no opinion") when it cannot or should not act:

| Function | Condition | Score |
|----------|-----------|-------|
| R1 `code_extractable` | Code block found | +1.0 |
| | No code block | -1.0 |
| R2 `ailang_check_passes` | `ailang check` passes | +2.0 |
| | Parse error | -1.5 |
| | Type/effect error | -0.5 |
| | No code extracted (R1 failed) | 0.0 |
| R3 `ailang_runs_correctly` | Correct output | +3.0 |
| | Runs, wrong output | +0.5 |
| | Crashes / timeout | 0.0 |
| | No `expected_output` for this prompt | 0.0 |
| R4 `ailang_verifies` | All contracts VERIFIED | +3.0 |
| | Any VIOLATION | -2.0 |
| | No contracts in code | 0.0 |
| | `has_contracts` is false for this prompt | 0.0 |

Best possible total: +9.0 (code found + check passes + correct output + verified).
Worst possible total: -4.5 (no code + check parse error + violation).

Note: R1 and R2 both independently call `extract_ailang_code()`. If R1 finds no code, R2 also finds no code and returns 0.0. There is no coupling — each function extracts and evaluates independently.

**Per-prompt metadata flow:**

TRL's GRPOTrainer passes all extra dataset columns as `**kwargs` to reward functions. The dataset must include `expected_output`, `caps`, and `has_contracts` columns alongside `prompt`. Each reward function accepts these via kwargs and returns 0.0 when the relevant metadata is absent:

```python
def ailang_runs_correctly(completions, **kwargs):
    expected_output = kwargs.get("expected_output")  # absent or None -> skip
    if expected_output is None:
        return [0.0] * len(completions)  # No expected output for this prompt
    caps = kwargs.get("caps", "IO")
    ...
```

The dataset format (as constructed by `training_core.py`):

```python
{
    "prompt": [{"role": "system", "content": docs}, {"role": "user", "content": task}],
    "expected_output": "42\n",      # omit field entirely for prompts without expected output
    "caps": "IO",                   # for ailang run --caps
    "has_contracts": true            # controls R4; omit or false to skip verification
}
```

**Subprocess safety:**

Every `ailang` subprocess invocation is wrapped in try/except with a timeout. If the process hangs, times out, segfaults, or throws any exception, the reward function returns 0.0 (neutral) rather than crashing the training loop:

```python
def run_ailang_check(code: str) -> dict | None:
    try:
        result = subprocess.run(
            ["ailang", "check", "-json", tmpfile],
            capture_output=True, text=True, timeout=10
        )
        return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception):
        return None  # Caller treats None as "skip, return 0.0"
```

Timeouts: `ailang check` 10s, `ailang run` 5s, `ailang verify` 15s.

**Implementation details:**
- Each reward function writes the extracted code to a temp file, runs the ailang binary, parses the result
- `ailang check -json` gives structured JSON — parse `passed` field
- Module line `module benchmark/solution` is injected if missing
- Temp files go in `/tmp/ailang_grpo/` with unique names per completion

**File:** `training/grpo_pilot/reward_functions.py`

### 4. Training Harness (Dual-Platform)

The training logic is split into a platform-independent core and two thin wrappers:

**Shared core** (`training_core.py`):
- Model loading (Unsloth FastLanguageModel / FastVisionModel)
- LoRA configuration
- GRPO configuration
- Dataset preparation (load prompts, format chat messages with system prompt)
- Reward function wiring

**Modal wrapper** (`modal_train.py`) — for PoC and iteration:
- `modal.Image` definition: deps, ailang binary (cross-compiled x86_64), Z3, AILANG docs
- `@app.function(gpu="A100-80GB")` decorator
- `modal.Volume` for checkpoint persistence
- Launch: `modal run modal_train.py::train`
- **Reference implementation:** `tools/md2audio/src/md2audio/modal_app.py` in this repo is a working Modal deployment with image definition, `@app.cls(gpu="A100")`, `modal.enter()` for model loading, and `add_local_dir` for source packaging. Use this as the template for the Modal wrapper — it demonstrates the exact patterns needed (image building, GPU selection, local file inclusion, endpoint structure).

**Standalone wrapper** (`standalone_train.py`) — for full-scale training on RunPod/Lambda:
- `argparse` for paths (model dir, output dir)
- Same core logic, no Modal dependency
- Launch: `python standalone_train.py` over SSH
- Assumes deps pre-installed via `setup.sh`, ailang binary on PATH

The wrappers are ~30 lines each. All training logic lives in the shared core.

Uses Unsloth (free/OSS) + TRL's GRPOTrainer. Closely follows Modal's first-party GRPO example.

**Model strategy:**
- **PoC / pipeline validation:** `unsloth/gemma-4-E4B-it` (dense 4B, fits on T4/A100). Use this first to debug prompts, reward functions, Modal plumbing, and GRPOTrainer integration without burning GPU-hours on the big model.
- **PoC / quality measurement:** `unsloth/gemma-4-26B-A4B-it` (MoE, 3.8B active params, 4-bit on A100). Switch to this once the pipeline works end-to-end. This is the model with the 62.7% baseline.
- **Full-scale training:** Same 26B model, longer runs on RunPod/Lambda.

**LoRA config:**
- `r=32` (matching Sudoku notebook — sufficient for PoC)
- All linear layers: `q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj`
- `lora_alpha = r * 2` (Unsloth recommendation)
- `use_gradient_checkpointing = "unsloth"`

**GRPO config:**
```python
GRPOConfig(
    temperature=1.0,           # High diversity for exploration
    learning_rate=5e-5,
    weight_decay=0.001,
    warmup_ratio=0.1,
    lr_scheduler_type="linear",
    optim="adamw_8bit",
    per_device_train_batch_size=1,
    gradient_accumulation_steps=2,
    num_generations=4,          # 4 completions per prompt, score all, learn from best
    max_completion_length=4096, # Room for substantial AILANG programs
    max_steps=60,              # PoC — short run to prove the concept
    # NOTE: 4 generations × 21K prompt = ~84K tokens input per step.
    # If too slow on A100, reduce num_generations to 2.
    loss_type='bnpo',
    mask_truncated_completions=True,
    report_to="none",          # Or "wandb" if available
)
```

**Sequence length budget:**
- System prompt: ~17K tokens (full AILANG docs)
- User prompt: ~200 tokens
- Generation: ~4K tokens
- Total: ~21K -> `max_seq_length=32768`

**Dataset:** The 30 prompts are repeated to fill the training set. Each "step" sees a different prompt. With 30 prompts and 60 steps, each prompt is seen ~2 times on average.

**Platform strategy:**
- **PoC / iteration:** Modal (A100 80GB, ~$2.50/hr, serverless, no idle billing, ~$5-10 per run)
- **Full-scale training:** RunPod (A100 80GB, ~$1.39/hr) or Lambda (A100 80GB, ~$1.79/hr) for longer runs where per-hour cost matters

**Files:** `training/grpo_pilot/training_core.py`, `training/grpo_pilot/modal_train.py`, `training/grpo_pilot/standalone_train.py`

### 5. Evaluation Script

A separate script (not part of training) that:
1. Loads the base model and the GRPO-trained LoRA
2. Runs both on a held-out evaluation set (5-10 prompts NOT in training)
3. For each, generates 5 completions and runs `ailang check -json`
4. Reports pass rate comparison: base vs GRPO

This is how we prove the PoC worked.

**Where it runs:** On Modal as a separate `@app.function(gpu="A100-80GB")`, or on the same RunPod instance after training completes. Needs a GPU (for inference) and the `ailang` binary (same image/environment as training).

**File:** `training/grpo_pilot/evaluate.py`

### 6. Setup + README

**For Modal (PoC):**
- No setup script needed. Image definition in `modal_train.py` is declarative and reproducible.
- Cross-compiled ailang binary (`GOOS=linux GOARCH=amd64 go build ./cmd/ailang/`) included in image.
- Z3 installed via `apt_install("z3")` in image definition.
- HF token injected via `secrets=[modal.Secret.from_name("huggingface-secret")]` (see Prerequisites).

**For RunPod/Lambda (full-scale):**
- `setup.sh`: install Python deps, Go toolchain, build ailang from source, `apt install z3`, verify GPU.
- Or: upload pre-compiled x86_64 ailang binary to skip Go requirement.

**README.md:**
- Architecture: shared core + two platform wrappers
- PoC quickstart: `modal run modal_train.py::train`
- Full-scale quickstart: provision A100, `bash setup.sh`, `python standalone_train.py`
- Hardware requirements (A100 80GB recommended)
- Expected runtime (~2-4 hours on A100 for 60 steps)
- How to interpret results

**Files:** `training/grpo_pilot/setup.sh`, `training/grpo_pilot/README.md`

---

---

## Prerequisites

Before the first `modal run`:

1. **HuggingFace: accept Gemma 4 license + create token**
   - Go to the Gemma 4 model page on HuggingFace (e.g., `https://huggingface.co/google/gemma-4-26b-a4b-it`)
   - Click "Agree and access" to accept Google's license (one-time)
   - Go to `https://huggingface.co/settings/tokens` -> create a Read token -> copy it

2. **Modal: store HF token as a secret**
   ```bash
   modal secret create huggingface-secret HF_TOKEN=hf_xxxYourTokenxxx
   ```

3. **Modal: verify account has GPU access**
   ```bash
   modal run --gpu A100 -c 'import torch; print(torch.cuda.get_device_name(0))'
   ```

The Modal training script injects the secret via `secrets=[modal.Secret.from_name("huggingface-secret")]` on the `@app.function` decorator. The `HF_TOKEN` env var is read automatically by transformers/unsloth when downloading gated models. No code changes needed beyond the decorator parameter.

## File Tree

```
training/grpo_pilot/
├── README.md                # Architecture, quickstart for both platforms
├── setup.sh                 # RunPod/Lambda: install deps, build ailang, verify GPU
├── prompts.jsonl            # 30 training prompts + 10 eval prompts
├── ailang_helpers.py        # Shared: code extraction, temp file mgmt, ailang invocation
├── reward_functions.py      # Platform-independent: code_extractable, ailang_check, ailang_run, ailang_verify
├── training_core.py         # Shared: model loading, LoRA config, GRPO config, dataset prep
├── modal_train.py           # Modal wrapper: image def, @app.function(gpu=), Volume
├── standalone_train.py      # RunPod/Lambda wrapper: argparse, no Modal deps
└── evaluate.py              # Before/after comparison (platform-independent)
```

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Full doc system prompt too large for VRAM | Training OOM | Gemma 4 26B-A4B supports 256K context. 17K system prompt + 4K generation = 21K tokens. `max_seq_length=32768` fits comfortably on A100 80GB with QLoRA. If tight, reduce `max_completion_length` first. |
| Generation throughput too slow with 4 completions × 21K prompt | Steps take >5 min, training takes 5+ hours | Reduce `num_generations` from 4 to 2. Halves generation cost per step. Still provides reward signal contrast for GRPO. |
| Reward latency from ailang subprocess too high | Training extremely slow | Batch ailang calls. Use `-quiet` flag. Measure and optimize if >2s per call |
| Model generates Python despite system prompt | All scores are -2.0, no gradient for GRPO | This would mean the model ISN'T in the basin. Would need SFT warmup first. User reports this isn't the case. |
| 30 prompts insufficient diversity | Model memorizes prompt-specific patterns | Prompts cover 3 difficulty tiers and 8+ distinct AILANG features. Sufficient for PoC. |
| ailang binary architecture mismatch | Reward functions fail on x86_64 training machine | Cross-compile here: `GOOS=linux GOARCH=amd64 go build ./cmd/ailang/` produces 75MB static binary. Stdlib embedded via go:embed. Already verified working. |
| Gemma-4-26B too large for single GPU with QLoRA | OOM | Fall back to `gemma-4-E4B-it` (4B dense). Still proves the concept. |

---

## Execution Order

0. **Cross-compile ailang binary** — `cd ailang && GOOS=linux GOARCH=amd64 go build -o ../training/grpo_pilot/ailang-amd64 ./cmd/ailang/` (already verified, takes ~30s)
1. **Training prompts** — write 30+10 prompts with expected outputs
2. **Reward functions + ailang helpers** — implement and unit-test locally against known-good/bad AILANG
3. **Training core + Modal wrapper** — wire up Unsloth + GRPOTrainer + reward functions (Modal for PoC)
4. **Evaluation script** — before/after comparison (runs on same platform as training)
5. **Standalone wrapper + setup.sh** — RunPod/Lambda support for full-scale training
6. **README** — document both platforms

Steps 1 and 2 are independent. Step 3 depends on 1-2. Steps 4-5 can follow 3. Step 6 depends on all.

**Parallelizable:** Steps 1 and 2 can be built simultaneously. Steps 4 and 5 are independent of each other.

---

## What This Does NOT Cover (Deferred)

- SFT warmup (user confirms it's unnecessary — Gemma 4 already writes decent AILANG)
- Tsetlin Machine integration (separate research line, see `TM_FineTuning_DualPath.md`)
- Full 15K dataset generation from Claude Opus (that's the scale-up phase after PoC succeeds)
- 8xH100 multi-GPU training (PoC is single-GPU)
- Kaggle submission packaging (depends on PoC results)
- Contract-specific GRPO (Phase 2 — focus on `ailang verify` reward after basic compilation reward works)
