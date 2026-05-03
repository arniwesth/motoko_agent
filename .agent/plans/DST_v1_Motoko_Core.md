# Deterministic Simulation Testing v1 — Motoko AILANG Core

## Objective

Build a first-pass Deterministic Simulation Testing (DST) harness for the Motoko agent's AILANG core modules. The goal is **CI regression coverage** — catching behavioral drift and robustness bugs on every commit — not full-system production chaos testing.

**Success criterion:** `make test-dst` runs in CI on every PR, executes ≥500 seeded property-test iterations across parser fuzzing and full-loop termination invariants, and fails reproducibly (printing the offending seed) on regression.

GRPO-style trajectory-replay fidelity is explicitly a **later concern**; this plan does not try to serve both goals.

---

## Frozen decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Purpose | CI regression harness. GRPO is v2. |
| 2 | AILANG coupling | Import-shim approach (no AILANG runtime patches). Fork-friendly; survives upstream churn. |
| 3 | Mock LLM fidelity | v1 = scripted state machine with seeded adversarial generators. Not a hash table, not recorded tapes. |
| 4 | Mock environment fidelity | Tier 1 — canned `{stdout, stderr, exit_code}` responses behind a clean seam for a later Tier-2 upgrade. |
| 5 | Priority-0 invariants | (a) parser fuzzing and (b) full-loop termination. |
| 6 | Harness language | AILANG-native. Tests live in `src/core/*_properties.ail` and run via `ailang test`. No external Go/TS driver. |

Reference context: `.agent/research/Misc.md` (DST-related notes), AILANG reference `ailang/docs/docs/reference/effects.md` and `guides/testing.md`.

---

## Scope

### In scope

- `src/core/parse.ail`, `src/core/parse_test.ail` — parser functions
- `src/core/rpc.ail` — main agent loop (refactored for injection)
- `src/core/agents_md.ail` — only its pure helpers (`dirname`, `is_root`); the FS-traversing discover function is stubbed for v1
- `src/core/cache.ail` — trajectory cache, treated as a SharedMem dependency of `rpc.ail`
- `src/core/env_client.ail` — swapped for `env_mock.ail` in tests
- New: `src/core/ai_mock.ail`, `src/core/env_mock.ail`, `src/core/parse_properties.ail`, `src/core/rpc_properties.ail`

### Out of scope for v1

- TUI frontend (`src/tui/`) — not tested here at all
- `Net`-effect fault injection (HTTP chaos) — v2
- Recorded real-LLM tapes — v2
- Tier-2 in-memory fake FS — v2 (likely driven by GRPO needs)
- `AGENTS.md` discovery on real directory trees — deferred pending open question (see below)
- `/abort` mid-loop testing — requires stdin injection, harder than it looks — v2
- TypeScript env-server behavior — pure production concern, not testable from AILANG

---

## Architecture

### The import shim

Production code uses `std/ai` and `env_client`:

```
rpc.ail ──► std/ai (call)           [live LLM, Net effect]
        └─► env_client (exec)       [HTTP to env-server, Net effect]
```

Test code swaps those for mock modules with matching signatures:

```
rpc_properties.ail ──► ai_mock (call)      [scripted, pure/SharedMem]
                   └─► env_mock (exec)     [canned table, pure]
```

To make the swap work without duplicating `rpc.ail`, the main loop is parameterized (see Milestone 0): `run_loop` takes `ai_call` and `env_exec` as arguments.

### File layout after v1

```
src/core/
  parse.ail                  (existing)
  parse_test.ail             (existing)
  parse_properties.ail       NEW — property tests for parse functions
  rpc.ail                    MODIFIED — main extracted as injectable run_loop
  rpc_properties.ail         NEW — property tests for the agent loop
  ai_mock.ail                NEW — scripted state-machine LLM mock
  env_mock.ail               NEW — Tier-1 canned response env mock
  test_helpers.ail           NEW — init_state, default_fixture, count_substring, naive_done_check, adversarial generators
  agents_md.ail              (existing)
  cache.ail                  (existing)
  env_client.ail             (existing, untouched)
  types.ail                  (existing)
  prompts.ail                (existing)
```

---

## Milestones

### M0 — Refactor `rpc.ail` for testability  *(~0.5 day)*

This is the only unavoidable change to production code. Without it, AILANG-native testing of the full loop is impossible.

**Deliverable:** extract the main loop into a function parameterized over its effect dependencies. The exact signature depends on OQ2's resolution; the shape below is a placeholder:

```ailang
-- Placeholder — final effect rows settled during OQ2 investigation.
-- Likely needs two distinct row variables or a row-union return type
-- because std/ai::call and env_client::exec carry different effects.
func run_loop[e_ai, e_env](
  ai_call: (string) -> string ! e_ai,
  env_exec: (string) -> ExecResult ! e_env,
  state: AgentState
) -> TrajectoryResult ! {e_ai | e_env | SharedMem | IO}
```

`rpc.ail::main` becomes a thin wrapper that wires in `std/ai::call` and `env_client::exec`. All runtime behavior must be identical — verified by running `make run TASK="hello world"` before and after and diffing `trace.jsonl` **modulo timestamps and step durations**. Use `jq` to project only the stable fields (event type, step index, prompt/output content) before comparing:

```bash
jq -c '{type,step,cmd,stdout,stderr,exit_code,done}' trace.jsonl > trace.canonical.jsonl
```

**Acceptance:**
- Existing smoke test (whatever currently exercises `rpc.ail`) passes
- `make run` unchanged from a user's perspective
- `ailang check src/core/rpc.ail` passes
- The two callback-parameter effect rows (`e_ai`, `e_env`) are distinct and polymorphic, so mocks with fewer effects than their production counterparts (e.g., no `Net`) typecheck at the wiring sites in both `rpc.ail::main` and `rpc_properties.ail`

### M1 — Parser property tests  *(~1 day, highest ROI)*

Create `src/core/parse_properties.ail`. Port the 85 existing inline tests as the golden floor, then add adversarial property tests.

**Properties to land in v1:**

```ailang
property "extract_bash is total" (s: string) =
  let _ = extract_bash(s) in true   -- must not panic

property "is_done is deterministic" (s: string) =
  is_done(s) == is_done(s)

property "parse_cwd returns valid shape" (s: string) =
  match parse_cwd(s) {
    Some(p) => length(p) > 0,
    None => true
  }

property "extract_fence requires two fence occurrences" (s: string, f: string) =
  match extract_fence(s, f) {
    Some(_) => count_substring(s, f) >= 2,
    None => true
  }

property "done marker survives adversarial placement" (seed: int) =
  let s = adversarial_string_with_done_marker(seed) in
  is_done(s) == naive_done_check(s)
```

**Helper dependencies.** `count_substring` and `naive_done_check` are not in AILANG stdlib; they live in `src/core/test_helpers.ail` alongside `init_state` and `default_fixture` (see File Layout). Budget ~30 min for these plus the adversarial generators listed below.

**Adversarial generators** (written as pure AILANG helpers, seeded by `int`):
- `adversarial_fence(seed)` — arbitrary numbers of backticks, unclosed fences, nested fences
- `unicode_soup(seed)` — RTL marks, zero-width chars, combining marks, BOM
- `huge_input(seed)` — inputs approaching input-size limits
- `embedded_done_marker(seed)` — `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT` inside strings, comments, code blocks

**Acceptance:**
- `ailang test src/core/parse_properties.ail` passes with `AILANG_TEST_RUNS=500`
- Each property runs 500 seeded iterations with zero failures
- Every adversarial generator (`adversarial_fence`, `unicode_soup`, `huge_input`, `embedded_done_marker`) is used by at least one property and demonstrably produces structurally distinct outputs across seeds (spot-checked by dumping 10 samples per generator and eyeballing them)
- Failing seed is reproducible locally via `AILANG_TEST_SEED=<seed> make test-dst`

### M2 — Mock LLM module `ai_mock.ail`  *(~1–2 days)*

Module exposing `call(prompt: string) -> string` matching `std/ai::call` signature, minus the `Net` effect (pure + `SharedMem` for step counters if needed).

**Two modes:**

1. **Scripted mode** — constructor takes a `Turn[]` fixture. Returns `turns[step_index].response`. Used for golden-path trajectory tests.
2. **Adversarial mode** — constructor takes a seed. Emits structurally-varied bash-in-markdown using the generators from M1, plus:
   - `truncated_response(seed)` — cuts off mid-fence
   - `no_fence_response(seed)` — LLM "decides to quit" (agent should treat as done)
   - `multi_fence_response(seed)` — multiple bash blocks, only first should be taken
   - `huge_response(seed)` — 1MB+ response

**API sketch:**

```ailang
-- Effect row on the returned function is OQ2-dependent.
-- Minimum: {SharedMem} (for step counters). May need phantom Net
-- if row unification at the run_loop wiring site requires it.
type MockMode = Scripted([Turn]) | Adversarial(int)

func make_mock_ai(mode: MockMode) -> ((string) -> string ! e_ai)
```

**Acceptance:**
- `ailang check src/core/ai_mock.ail` passes
- Unit-tested: same input + same seed → byte-identical output, always (explicit regression property in `ai_mock.ail` inline tests)
- Adversarial generators spot-checked: 10 samples per generator printed and eyeballed for structural variety
- Used in M4 without type-row conflicts with `run_loop` (if conflicts appear, apply the OQ2 fallback and document the row change here)

### M3 — Mock env module `env_mock.ail`  *(~0.5–1 day)*

Tier-1 canned responses. Signature matches `env_client::exec`.

**API:**

```ailang
-- Effect row is OQ2-dependent (same story as ai_mock).
-- Minimum: pure. May need phantom Net for row unification.
type EnvFixture = {
  responses: [{pattern: string, stdout: string, stderr: string, exit_code: int}],
  miss_policy: MissPolicy
}

type MissPolicy =
  | HardFail           -- return exit 127 "command not found" (default — hostile)
  | SoftEmpty          -- return {"", "", 0}

func make_mock_env(fixture: EnvFixture) -> ((string) -> ExecResult ! e_env)
```

**Default miss policy is `HardFail`** — the hostile choice forces the agent loop to handle command failures, which is exactly what we want tested.

**Acceptance:**
- Pattern matching is substring-based and case-sensitive
- When multiple fixtures match a single command, the first entry in the list wins (order-dependent by design; predictable for tests)
- Deterministic: same fixture + same command sequence → same outputs
- `ailang check src/core/env_mock.ail` passes

### M4 — Full-loop property tests  *(~1–2 days, marquee)*

Create `src/core/rpc_properties.ail`. The two priority-0b invariants:

```ailang
property "loop terminates in ≤50 steps for any adversarial LLM" (seed: int) =
  let ai = make_mock_ai(Adversarial(seed)) in
  let env = make_mock_env(default_fixture()) in
  let result = run_loop(ai, env, init_state()) in
  result.step_count <= 50

property "loop never panics on adversarial LLM output" (seed: int) =
  let ai = make_mock_ai(Adversarial(seed)) in
  let env = make_mock_env(default_fixture()) in
  let result = run_loop(ai, env, init_state()) in
  match result.status {
    Done(_) => true,
    BudgetExhausted => true,
    Aborted => true,
    Panic(_) => false     -- any panic is a test failure
  }
```

**Placeholder types.** `TrajectoryResult`, its status variants (`Done`, `BudgetExhausted`, `Aborted`, `Panic`), and the helpers `init_state()` and `default_fixture()` are defined during M0 (for the result type) and in `src/core/test_helpers.ail` (for the helpers). Variant names shown here are placeholders and may be renamed during M0.

**Stretch properties if time allows** (move to v2 otherwise):
- `done implies final response contains no bash block`
- `cache state is a pure function of the completed trajectory` — **only valid if OQ3 resolves to "SharedMem isolated per property run."** If SharedMem leaks across runs (the likely default), this property is trivially false. Either drop it, or prepend `cache_reset()` to every property body (OQ3's fallback) and reword as "cache state after `cache_reset + trajectory` is a pure function of that trajectory."

**Acceptance:**
- `ailang test src/core/rpc_properties.ail` passes with `AILANG_TEST_RUNS=500`
- Failing seed reproducibility verified: reset seed, rerun, same failure
- CI run completes in <5 minutes at 500 runs per property

### M5 — CI wiring  *(~0.5 day)*

**Makefile targets:**

```makefile
test-dst:
	ailang test src/core/parse_properties.ail src/core/rpc_properties.ail

test-dst-ci:
	ailang test --format json --no-color \
	  src/core/parse_properties.ail \
	  src/core/rpc_properties.ail > test-results.json
```

### Seed policy — regression vs fuzz

The stated goal (Frozen Decision #1) is CI **regression**, not fuzz testing. These have incompatible seed requirements:

| Need | Seed behavior | Consequence |
|---|---|---|
| Regression (per PR) | Fixed, or derived deterministically from commit SHA | Same code → same result. Red stays red across reruns. |
| Fuzz (nightly) | Rotating (`github.run_id` or `$(date)`) | Broader coverage of the input space over time, at the cost of intermittent reds. |

**v1 runs both, as separate CI jobs** — regression gates PR merges; fuzz surfaces bugs asynchronously.

**GitHub Actions — regression job (blocking, per PR):**

```yaml
- name: DST regression
  env:
    AILANG_TEST_RUNS: 500
    AILANG_TEST_SEED: 42     # fixed. Bump only when broadening the fuzz corpus.
  run: |
    echo "Using AILANG_TEST_SEED=$AILANG_TEST_SEED (fixed regression seed)"
    make test-dst-ci

- name: Upload failing seeds
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: dst-failures
    path: test-results.json
```

**GitHub Actions — nightly fuzz job (non-blocking, scheduled):**

```yaml
on:
  schedule:
    - cron: '0 3 * * *'   # 03:00 UTC daily

jobs:
  fuzz:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: DST fuzz
        env:
          AILANG_TEST_RUNS: 5000
          AILANG_TEST_SEED: ${{ github.run_id }}   # rotates each run
        run: |
          echo "Using AILANG_TEST_SEED=$AILANG_TEST_SEED (rotating fuzz seed)"
          make test-dst-ci
      - name: Open issue on failure
        if: failure()
        run: gh issue create --title "DST fuzz failure (seed=$AILANG_TEST_SEED)" --body "See artifact."
```

A fuzz failure creates a GitHub issue with the seed rather than blocking PRs — new edge cases become work items, not blockers.

**Acceptance:**
- CI runs `make test-dst-ci` on every PR with fixed seed `42`
- Nightly fuzz job runs with rotating seed at `AILANG_TEST_RUNS=5000`
- Red CI prints the active seed in the logs (fixed seed for PRs; rotating seed for fuzz)
- Any seed is reproducible locally: `AILANG_TEST_SEED=<n> make test-dst` fails the same way

---

## Open questions to answer before kickoff

These are real unknowns that could bend the shape of M0–M4. Budget one morning to answer them; each has a known fallback.

### OQ1 — Can `property` bodies carry effects?

The M4 property bodies call `run_loop`, which has `! {IO, SharedMem}` at minimum. If `ailang test` doesn't grant capabilities to property bodies, M4 needs a different shape (e.g., a pure wrapper that swallows the effect, or a drop to an external driver for M4 only).

**How to check:** write a throwaway `property "io works" (x: int) = { println(show(x)); true }` and run `ailang test`.

**Also verify during OQ1:** does `ailang test` print the active `AILANG_TEST_SEED` at startup or on failure? CI-to-local reproducibility hinges on the seed being visible in logs. If it isn't printed by default, M5 must echo `$AILANG_TEST_SEED` before invoking the target.

**Fallback:** If effectful properties aren't supported, run `rpc_properties.ail` as an `ailang run` script with a manual seeded loop — gives up shrinking but keeps reproducibility.

### OQ2 — Effect-row compatibility between `std/ai::call` and `ai_mock::call`

`std/ai::call` is exported with a specific effect signature (likely `! {Net, SharedMem}` or similar). The mock has `! {SharedMem}` only. Can both be passed into a `run_loop` parameterized over `! e`? If row polymorphism requires both arguments share the same row variable, there's a type error at the wiring site.

**How to check:** attempt the refactor on a trivial version of M0 — two small functions with different effect rows, passed into a polymorphic consumer.

**Fallback:** bloat the mock's signature to include `Net` as a phantom (allowed but unused) so rows match. Slightly ugly, works.

### OQ3 — SharedMem isolation between property runs

`cache.ail` uses SharedMem for the trajectory cache. If `ailang test` reuses one process across 500 property iterations, cache pollution will make run N+1 see run N's cache. This masks real bugs (a "terminates in 1 step" result because the cache hit the previous trajectory).

**How to check:** write a property that writes to SharedMem and another that reads; see whether the second sees the first.

**Fallback:** add `cache_reset()` as the first line of each property body. Cheap and explicit.

### OQ4 — `AGENTS.md` discovery

`agents_md::discover` uses `FS`. Either (a) use `AILANG_FS_SANDBOX` pointing at a fixture tree baked into the test repo, or (b) stub the discover function. Affects M0's function signature (does `run_loop` take a `discover_agents_md` callable too?).

**Choice:** for v1, **stub at the `run_loop` call site** — pass pre-computed AGENTS.md content into `init_state`. Defers real discovery testing to v2 but keeps the v1 blast radius small. If v1 finds no bugs from this path, revisit only when GRPO needs richer FS state.

---

## Effort estimate

| Milestone | Estimate |
|---|---|
| M0 — rpc.ail refactor | 0.5 day |
| M1 — parser properties | 1 day |
| M2 — mock LLM | 1–2 days |
| M3 — mock env | 0.5–1 day |
| M4 — full-loop properties | 1–2 days |
| M5 — CI wiring | 0.5 day |
| Open-question investigation | 0.5 day (up front) |
| **Total** | **5–8 days** |

Fits inside "weekend spike to small sprint" — aligned with the Option-2 effort envelope.

**Add ~1 day buffer** if the implementer hasn't written AILANG `property` tests before. First-time friction is almost entirely the type checker and figuring out how `property` interacts with effect capabilities (OQ1/OQ2).

---

## Definition of done

1. `make test-dst` exists and runs
2. CI runs it on every PR
3. At least 500 seeded iterations per property, reproducible via `AILANG_TEST_SEED`
4. Failing seeds print on CI red and replay deterministically locally
5. Zero new AILANG runtime patches required — all work lives in `src/core/`
6. For each adversarial generator in M1, at least one property run exercises it and produces structurally distinct outputs across seeds (verified during M1 spot-checks, not requiring a bug to be found)
7. Documentation: one-page follow-up note in `.agent/learnings/` capturing what broke, what the open questions resolved to, and what should change for v2

---

## Explicit non-goals

- **Not production chaos testing.** We do not simulate env-server flakes, network partitions, or LLM provider outages in v1. See *Beyond v1* below for the staged roadmap.
- **Not trajectory replay for RL.** The fixture-driven mock LLM is too thin to serve policy gradients. GRPO needs Tier-2 env + recorded tapes, separate plan.
- **Not coverage completeness.** We pick two high-value invariants (parser totality, loop termination) and ignore the long tail. Adding invariants is cheap once the harness exists.
- **Not a DST framework for general AILANG code.** Everything here is specific to Motoko's core. Generalization is an AILANG-upstream concern (aligned with their "(Planned)" mock-effect roadmap).

---

## Beyond v1: path to full-system chaos testing

v1's non-goal is "not production chaos testing." This section makes the deferred work concrete so the gap is a known roadmap, not a handwave.

"Full-system production chaos testing" covers a ~50× cost range depending on what it means. Three tiers, each with a different ceiling:

| Tier | What it is | Cost from v1 | Reproducibility | Recommendation |
|---|---|---|---|---|
| **A — Chaos monkey** | Fault injection at real boundaries (HTTP, network, process) | 2–4 weeks | None — surfaces bugs, can't replay | **v2 target** |
| **B — Record + replay** | Capture real runs; replay with perturbations | 1–2 months | Yes for recorded traces, no for novel faults | v3, co-scheduled with GRPO |
| **C — True DST (Antithesis-grade)** | Bit-deterministic whole-system replay | 6+ months; possibly impractical | Yes, everywhere | Skip unless Motoko becomes critical infrastructure |

### Tier A — chaos monkey (2–4 weeks from v1, recommended as v2)

Toxiproxy between the AILANG runtime and the env-server. An LLM proxy that intercepts Anthropic/OpenAI/Google HTTP and injects: 5xx responses, slow replies, token-stream drops, truncations, rate-limit bursts. A "survived" oracle: no panics, `trace.jsonl` still parseable, session ends in `done` or `error` (never wedged).

**Catches:** network and timing bugs v1 structurally cannot surface — v1 has no network layer at all (it's all mocks and pure functions).

**Limits:** faults are wall-clock-driven. No reproducibility for novel fault combinations — a red CI run re-run won't hit the same fault. Good for "did we survive?", bad for "why did we fail?".

**Architectural cost:** zero. Adds proxy services at HTTP boundaries that already exist in the production path. No code changes to the AILANG core or TUI.

**How it composes with v1:** run alongside the v1 nightly fuzz harness as a separate non-blocking job. v1 fuzz catches deterministic parser and loop bugs; Tier A catches network and timing bugs. The combined signal covers ~80% of what production throws at you at ~10% of Tier C's cost.

### Tier B — record + replay (1–2 months, co-scheduled with GRPO)

Record every LLM call, env-server exchange, and stdin/stdout event to a `.tape` file. Replay the tape against the runtime while applying perturbations: shifted timings, mutated content, dropped events, injected failures.

Reuses v1's `ai_mock`/`env_mock` plumbing — the import shims become replay drivers instead of canned responders. Adds:
- Recording mode on production import sites (~1 week)
- Tape format + loader (days)
- Perturbation library (2–3 weeks)
- Divergence detection: "when does runtime behavior depart from the tape?" (2–3 weeks — the conceptually hardest piece)

**Reproducibility:** yes for recorded trajectories and their perturbations. Still no for novel fault combinations outside the recorded distribution.

**Natural trigger: GRPO.** Reinforcement learning on agent trajectories requires reproducible rollouts to compute counterfactual rewards. That requirement justifies the record+replay cost without forcing it. Building Tier B *before* GRPO lands is premature — the reproducibility value is small without a training loop consuming it.

### Tier C — true DST (skip unless criticality changes)

Antithesis-grade bit-deterministic replay of the whole system. FoundationDB / TigerBeetle-level engineering.

Motoko's architecture fights this on every axis:

1. **Three processes** (pi-tui Node + AILANG Go runtime + env-server Node) communicating via OS-mediated pipes. Bit-deterministic coordination requires folding them into one process with a cooperative scheduler. That's a rewrite, not a refactor.
2. **Go scheduler** is non-deterministic. Needs either Antithesis's hypervisor (proprietary, they sell it as a service) or rebuilding AILANG's runtime on a deterministic goroutine scheduler like `testing/synctest` (new and limited).
3. **Node event loop** is non-deterministic. Would require eliminating the TUI or simulating `libuv` — part of why v1 put TUI out of scope in the first place.
4. **Real FS, PIDs, sockets, `/dev/urandom`** leak entropy. Needs `libfaketime` + namespaced FS + seeded entropy for every source. Containers don't get you there; you need a VM or hypervisor.

**Cost reality:** FoundationDB took years and invented a C++ extension language (Flow) to make concurrent code look cooperatively-scheduled. TigerBeetle was designed around DST from day one. Retrofitting an existing multi-process system is meaningfully more expensive than building greenfield.

**Skip this tier** unless Motoko runs autonomous agents in production with real financial or safety consequences. At today's scale (research harness + GRPO pilot) the ROI is negative by ~10×.

### The unavoidable wall: live LLMs are structurally non-deterministic

No tier can make a remote LLM API deterministic:
- `temperature=0` drifts across provider versions
- Prompt caching changes outputs
- Infrastructure upgrades shift tokenizers and sampling internals

The only paths to determinism through the LLM layer:

- **Mock it** (v1's `ai_mock`) → deterministic but not "production"
- **Record it** (Tier B) → deterministic but not "live"

"Full-system production chaos testing with live LLMs and full determinism" is not a reachable combination. Pick any two of three.

### Roadmap summary

```
v1 (this plan)       → CI regression: parser fuzz + loop termination
                       [5–8 days, import-shim mocks]

v2 (Tier A)          → Nightly chaos monkey: HTTP/network/LLM-proxy fault injection
                       [2–4 weeks, separate plan]

v3 (Tier B, w/ GRPO) → Record + replay: reproducible perturbations of recorded sessions
                       [1–2 months, co-scheduled with GRPO kickoff]

v4+ (Tier C)         → Deferred indefinitely unless system criticality changes
```

Each tier is independently valuable and cumulative. v2 does not block v3; v3 does not require v2. The natural order is v1 → v2 (nightly bug surfacing) → v3 (when GRPO needs reproducible rollouts).

---

## Next action

Answer OQ1–OQ3 in a ~2-hour investigation session (one throwaway `.ail` file per question). Then start M0.
