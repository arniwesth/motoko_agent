# M9 — v2 Test Matrix (5 providers × 5 benchmark tasks)

**Status**: Pending user-led validation
**Sprint**: M-MOTOKO-RPC-LOOP-FULL-MIGRATION
**Predecessor**: M8 (multi-turn conversation_loop) — passed
**Successor**: M10 (production cutover) — blocked on M9

---

## What sprint-executor delivered

Test infrastructure ready to run:

- [scripts/smoke_v2_provider_matrix.sh](../../scripts/smoke_v2_provider_matrix.sh) — driver that runs MOTOKO_AGENT_V2=1 against multiple providers × multiple smoke variants, tabulates pass/fail, dumps per-cell logs to `/tmp/motoko-m9/`.
- [scripts/smoke_v2_policy.ail](../../scripts/smoke_v2_policy.ail) — task #1: empty-extension v2 wiring smoke (one tool-using prompt against each provider).
- 4 smoke-variant slots ready to fill (placeholders in TASKS array of the matrix runner).

Currently configured for 5 providers:

| Provider key | Model id                       | Auth                                                                                          |
|--------------|--------------------------------|-----------------------------------------------------------------------------------------------|
| anthropic    | claude-sonnet-4-5              | `ANTHROPIC_API_KEY`                                                                           |
| gemini       | gemini-2-5-flash               | Prefer Vertex AI via ADC (`gcloud auth application-default login` + `GOOGLE_CLOUD_PROJECT`); fallback `GOOGLE_API_KEY` (AI Studio) |
| openai       | gpt-5                          | `OPENAI_API_KEY`                                                                              |
| glm          | openrouter/z-ai/glm-5          | `OPENROUTER_API_KEY`                                                                          |
| minimax      | openrouter/minimax/minimax-m2.7| `OPENROUTER_API_KEY`                                                                          |

---

## Why this is human-in-the-loop

M9 cannot be auto-executed because:

1. **Real API keys**: Each provider requires authentication tokens that the agent doesn't have access to.
2. **Cost**: Running 5×5 = 25 cells consumes real tokens against paid APIs.
3. **Subjective acceptance**: The criteria explicitly allow degraded performance for smaller models ("GLM-5: ≥4/5 pass acceptable", "MiniMax M2.7: ≥4/5 pass acceptable"). Deciding which failures are bugs vs quirks-to-document requires human judgment about model capabilities.
4. **Regression-test authoring**: Per-provider bugs found during the matrix should land as `internal/ai/<provider>/step_test.go` fixtures upstream in AILANG. That's a separate sub-task per finding, with judgment about minimum reproducer shape.

---

## How to run M9

### Quick start (one provider, current task set)

```bash
cd motoko_agent
export ANTHROPIC_API_KEY=...
PROVIDERS=anthropic scripts/smoke_v2_provider_matrix.sh
```

### Full matrix (requires all 5 auths)

```bash
cd motoko_agent
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=...
export OPENROUTER_API_KEY=...
# Gemini: prefer ADC (no key needed once configured)
gcloud auth application-default login
export GOOGLE_CLOUD_PROJECT=your-gcp-project
# Gemini fallback (skip if ADC works):
# export GOOGLE_API_KEY=...
scripts/smoke_v2_provider_matrix.sh
```

### Adding the remaining 4 task variants

The matrix currently has 1 task slot filled (`policy-default`). To reach 5×5, copy `smoke_v2_policy.ail` 4 times with prompt variations:

```bash
cd motoko_agent/scripts
for variant in tool-write tool-read tool-build factual; do
  cp smoke_v2_policy.ail "smoke_v2_${variant}.ail"
  # edit the user prompt in each copy
done
```

Then add to the `TASKS` array in `smoke_v2_provider_matrix.sh`:

```bash
TASKS=(
  "policy-default:scripts/smoke_v2_policy.ail"
  "tool-write:scripts/smoke_v2_tool_write.ail"
  "tool-read:scripts/smoke_v2_tool_read.ail"
  "tool-build:scripts/smoke_v2_tool_build.ail"
  "factual:scripts/smoke_v2_factual.ail"
)
```

Suggested task prompts (representative of motoko's real workload):

| Task id     | Prompt                                                                  | Tool expectations |
|-------------|-------------------------------------------------------------------------|-------------------|
| policy-default | "What does 1+1 equal? One number, no tool calls."                    | No tools (prose only) |
| tool-write  | "Create /tmp/m9-test.txt with the content 'hello m9'."                  | WriteFile         |
| tool-read   | "Read /etc/hostname and tell me what it contains."                      | ReadFile          |
| tool-build  | "Run 'echo build-ok' as a shell command and confirm the output."        | BashExec          |
| factual     | "What is the capital of France? Answer in one word."                    | No tools (prose only) |

---

## Acceptance criteria (for human evaluation)

After running the matrix, evaluate per the M9 sprint criteria:

- [ ] Claude Sonnet 4.5: **5/5** benchmark tasks pass
- [ ] Gemini 3 Pro: **5/5** pass (likely surfaces functionCall ID quirks — fix upstream)
- [ ] GPT-5: **5/5** pass
- [ ] GLM-5: at least **4/5** pass (acceptable for smaller OS model)
- [ ] MiniMax M2.7: at least **4/5** pass
- [ ] Any per-provider bug found gets a regression test in upstream `internal/ai/<provider>/step_test.go`
- [ ] Documented compatibility matrix written (recommend `docs/v2-model-compatibility.md`)

---

## Failure mode handling

If a cell fails:

1. Inspect the per-cell log: `cat /tmp/motoko-m9/<provider>-<task-id>.log`
2. Identify whether it's:
   - A motoko-side bug (wrong dispatch, stale state) → fix in `src/core/agent_loop_v2.ail`
   - An upstream AILANG bug (provider adapter sends wrong protocol) → file issue at sunholo-data/ailang with the smoking gun
   - A model quirk (e.g. Gemini emits functionCall without an id, or OpenAI returns argument-string-not-object) → fix in upstream `internal/ai/<provider>/step.go`, add `step_test.go` regression, file issue
3. After fix, re-run the failing cell only:
   ```bash
   PROVIDERS=<provider> scripts/smoke_v2_provider_matrix.sh
   ```

---

## What unblocks M10

M10 (production cutover) requires:

- M9 acceptance criteria all checked off
- v2 default-on (flip `MOTOKO_AGENT_V2` env-gate to opt-out)
- `rpc_loop` and dependent helpers (parse_tool_calls, indicates_continuation_intent, etc.) deleted from rpc.ail and parse.ail
- SYSTEM.md updated to reflect v2 dispatch semantics
- CHANGELOG entry referencing this sprint

When all M9 cells pass (or fail in the documented "acceptable for smaller OS model" zones), invoke sprint-executor to run M10.

---

## Cross-references

- AILANG sprint plan: `design_docs/planned/v0_17_0/m-agent-loop-architecture.md`
- motoko sprint plan: `design_docs/planned/m-motoko-rpc-loop-full-migration-sprint-plan.md`
- motoko design doc:  `design_docs/planned/m-motoko-rpc-loop-full-migration.md`
- Sprint progress JSON: `.ailang/state/sprints/sprint_M-MOTOKO-RPC-LOOP-FULL-MIGRATION.json`
