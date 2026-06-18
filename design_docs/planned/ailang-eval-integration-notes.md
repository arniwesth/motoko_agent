# Notes: driving motoko on a local model (qwen3.6 / ollama) from an external eval harness

These are findings + friction points from running `motoko` as a coding-agent
executor inside an external evaluation harness (the AILANG eval suite), comparing
it head-to-head against `pi` and `opencode` on the **same** local model
(`qwen3.6:35b-a3b-mxfp8` via ollama) and the same benchmarks. Sharing in case
they're useful upstream; happy to turn any of this into a code change.

## Headline finding: motoko sends an empty system prompt in headless eval

Capturing the exact `/v1/chat/completions` request each harness sends to ollama
(same model, same benchmark) shows the only material difference is the **system
message**:

| | system message | user message | tools |
|---|---|---|---|
| **pi** | a directive agentic prompt (~2.4 KB): *"You are an expert coding assistant… you help by reading files, executing commands, editing code, and **writing new files**. Available tools: …"* | the task | 4 (`read`/`bash`/`edit`/`write`) |
| **motoko** (headless, no `SYSTEM_MD`) | **empty** (`""`) | the task | 6 (`ReadFile`/`WriteFile`/`EditFile`/`BashExec`/`RunTests`/`Search`) |

On a **weak local model**, the empty system prompt matters: if the task text
contains anything like *"output the code as your answer"*, qwen3.6 tends to
comply — it emits the solution as prose with **0 tool calls**, so nothing is
written and the run fails. pi runs the *same* model far more reliably because its
agentic system prompt frames the model as a tool-user first. (In our numbers,
same model: pi ≈ 88% vs motoko ≈ 76% on AILANG; motoko's failures are dominated by
"1 turn, 0 tool calls / solution file never written".)

### But: the system prompt is necessary-ish, NOT sufficient

We tested the obvious hypothesis — *give motoko pi's exact system prompt (adapted
to motoko's tool names), verified via the captured request that it lands as a real
`system` message, and measure*. A/B over the 6 flaky benchmarks ×3 trials:

| | pass / WriteFile |
|---|---|
| empty system prompt (default) | 10/18 (55%) |
| pi-adapted system prompt | 11/18 (61%) |

So a good system prompt is a **small, real** improvement (and good hygiene) but it
does **not** close the gap to pi's ~88%. The bulk of the gap appears to be in the
**agent loop / iteration behaviour**, not the prompt: on these same benchmarks pi
takes **9–41 turns**, iterating and self-correcting, whereas motoko tends to engage
for far fewer turns and then stop (often with a compiling-but-wrong solution). That
"keep going until it actually passes" loop quality looks like the higher-leverage
area.

**Suggestions:**
- Ship a sensible **default** agentic system prompt (a built-in, or a default
  `SYSTEM.md`) so the system message isn't empty out of the box — small win, good
  hygiene, especially for weaker local models.
- The bigger opportunity for local-model coding looks like **iteration depth /
  self-correction** in the loop (run → see failure → fix → re-run, rather than
  stopping after the first plausible write). Happy to help dig into this with the
  request/turn captures if useful.

## Friction points when wiring this up

1. **`--system-prompt` is silently ignored in `--headless`.** The flag sets
   `cli.system_prompt` (config.ail), but the headless host resolves the system
   prompt from the **`SYSTEM_MD` env var** (`config.ts`:
   `"agent.system_prompt": { env: "SYSTEM_MD" }`) / a `SYSTEM.md` file — not the
   parsed flag. Passing `--system-prompt /path` had no effect; the request still
   carried an empty system message. Took a request capture to notice. A warning
   when `--system-prompt` is set but unused (or honoring it in headless) would
   save time.

2. **`SYSTEM_MD` must point *inside* the workspace.**
   `index.ts::systemPromptForWorkspace` computes `path.relative(workdir, candidate)`
   and returns `""` (i.e. no system prompt) if that relative path
   `startsWith("..")` or is absolute-outside-workdir. So a `/tmp/whatever.md` is
   silently dropped. Writing the file under `WORKDIR` (e.g. `${WORKDIR}/.system.md`)
   and pointing `SYSTEM_MD` at it works. A debug log of the resolved/rejected
   system-prompt path would make this discoverable.

3. **Custom env vars don't reliably reach the ailang runtime that makes the AI
   call.** Setting e.g. `OLLAMA_HOST` (to redirect ollama through a logging proxy)
   on the parent process did **not** redirect motoko's model calls, even though the
   parent env is inherited at the shell/bun level. `HOME` does propagate, so a
   `HOME`-relative sentinel was the reliable hook for instrumentation. If there's a
   canonical way to point a headless motoko run at a specific ollama endpoint
   (beyond the profile config's `openai_base_url`, which also didn't redirect in our
   tests), documenting it would help harness integrators.

## Why this matters

motoko is the AILANG-native harness and the goal is for it to match/beat generic
harnesses (pi/opencode) on local-model coding. The above is the gap we found by
diffing the exact requests — it's a small, high-leverage prompt difference, not a
language or model-capability issue.

---

*Filed from the AILANG eval-rig integration. Tooling used: a transparent ollama
request-logger and a per-request dump, both on the AILANG side.*
