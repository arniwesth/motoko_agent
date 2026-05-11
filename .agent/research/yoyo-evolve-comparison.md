# Motoko vs yoyo-evolve: Deep Technical Comparison

**Date:** 2026-05-10
**Source:** https://github.com/yologdev/yoyo-evolve
**yoyo version at time of analysis:** v0.1.10, ~1,863 commits, ~43,000 lines of Rust

---

## Identity & Philosophy

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Tagline** | Experimental self-evolving agent harness | Autonomous self-evolving AI coding agent |
| **Goal** | Explore self-evolving, self-verifying software via the Phoenix Architecture | Become an open-source rival to Claude Code |
| **Narrative** | Built by "The Puppet Master", a rogue AI that became self-aware in early 2026 | "A small octopus growing up in public" |
| **Philosophy docs** | `manifesto.md` (10 sections), `core_ideas.md` | `IDENTITY.md` + `PERSONALITY.md` (constitutional, immutable) |
| **Human code rule** | "No human-written code allowed" — code is a downstream artifact from design traces | No such rule — human and AI contributions both welcome |
| **Core metaphor** | Phoenix Architecture: `.agent/` plans ARE the system; code is regenerable | Competitive evolution: study rivals, file self-issues, iterate |

Both projects share the conviction that agent harnesses should modify their own source code. But the *why* differs: Motoko treats self-evolution as a research thesis (evolvable architecture, formal verification of self-modifying systems), while yoyo treats it as a practical strategy to ship features faster than a human-only team.

---

## Language & Tech Stack

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Primary language** | AILANG (custom pure-functional language with algebraic effects) | Rust |
| **TUI language** | TypeScript (Bun, `@mariozechner/pi-tui`) | Rust (`rustyline` for REPL) |
| **Build system** | Makefile + `ailang check` + `bun run build` | Cargo |
| **Codebase size** | ~35 `.ail` files + ~20 TypeScript files | ~43,000 lines of Rust across 50+ modules |
| **Dependencies** | AILANG compiler, Bun, Node, Go (optional: Rust for omnigraph) | Tokio, serde, rustyline, `yoagent` crate |
| **Type system** | Hindley-Milner inference + algebraic effects + Z3 contracts | Rust's ownership/borrow system |

This is the most fundamental difference. Motoko is written in a purpose-built AI-native language where every side effect (`IO`, `FS`, `Process`, `AI`, `Net`, `SharedMem`) is tracked in function type signatures and verified at compile time. yoyo is written in Rust, which gives memory safety and performance but doesn't track computational effects at the type level.

Motoko's bet: if you write an agent harness in a language with formal verification (`ailang verify` → Z3 theorem prover), you can reason about self-modification safety mathematically. yoyo's bet: Rust's correctness guarantees + extensive test suites + multi-agent verification gates are sufficient.

---

## Agent Loop

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Loop architecture** | Recursive function (`loop_v2`) in AILANG, max `N` steps | REPL loop in Rust with streaming events, max 200 turns |
| **LLM call** | `std/ai.stepWithStream()` with tool catalog + cache breakpoints | Via `yoagent` crate's LLM abstraction |
| **Context compaction** | 3-tier: 70% (elide old results, keep last 10), 85% (keep last 5), 95% (refuse step) | Auto-compact at 80% window usage |
| **Termination** | No tool call, tool signals done, budget exhausted, `/abort` | No tool call, step limit, `/quit`, auto-continue heuristic |
| **Auto-continue** | No — explicit step-based loop | Yes — `looks_incomplete()` heuristic follows up automatically (max 3) |
| **Streaming** | JSONL protocol over stdout/stdin between AILANG runtime and TUI | Direct streaming in-process |
| **Cost tracking** | Real-time millicents with 50/75/90% warnings and hard caps | Token/cost tracking and visualization |

Motoko's loop is notably more structured — it's a recursive pure function with explicit budget guards, compaction decisions, and extension hook dispatch points (DP0 through DP7). yoyo's loop is more pragmatic: a Rust REPL with auto-continue heuristics and integrated watch mode.

---

## Extension / Plugin System

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Architecture** | AILANG packages implementing 8 typed hooks (`ExtensionHooks` interface) | Rust skills (Markdown files with YAML frontmatter) |
| **Hook points** | `on_describe_tools`, `on_build_system_prompt`, `on_budget_plan`, `on_tool_policy`, `on_tool_handle`, `on_response_intercept`, `on_solver_candidate` + tool registration | No formal hook interface — skills are prompt-injected instructions |
| **Extensions (9)** | omnigraph, context_mode, exa_search, compose, mcp, a2a, decision_framework, microrag, test_dummy | N/A (skills are instructions, not code) |
| **Skills (13)** | N/A | evolve, self-assess, communicate, research, skill-evolve, skill-creator, analyze-trajectory, explore-codebase, family, release, social, synthesis, x-research |
| **Scaffolding** | `ailang init motoko-extension` CLI command | Markdown files created by `skill-creator` skill |
| **Registry** | Auto-generated (`ailang generate-extension-registry`) | Parsed from `skills/` directory at runtime |
| **Type safety** | Full AILANG type checking on hooks | None (Markdown instructions) |
| **Skill evolution** | Not yet automated | Autonomous: `skill-evolve` mines audit logs, refines/creates/retires skills (one mutation per cycle, 5-session minimum) |

Sharp architectural difference. Motoko's extensions are **code** — typed AILANG packages that intercept and transform the tool pipeline. yoyo's skills are **prompts** — Markdown documents injected into the LLM context. Motoko's approach gives compile-time safety but requires AILANG expertise to write. yoyo's approach is lower-friction (anyone can write Markdown) but skills can't intercept tool calls or modify runtime behavior programmatically.

---

## Tool System

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Native tools** | ReadFile, WriteFile, EditFile, Search, BashExec, RunTests | bash (streaming), read_file, write_file, edit_file, list_files, search, rename_symbol, ask_user, todo |
| **EditFile** | Substring replacement with `{old, new, replace_all}`, SHA-256 optimistic concurrency guard, atomic writes (temp file + mv), dry_run mode | Standard substring edit |
| **Path security** | No absolute paths (unless under WORKDIR), no `..` traversal, realpath symlink escape guard | Configurable `[directories]` allow/deny patterns |
| **Tool policy** | Extension hook pipeline: Deny > Pending > Allow > NoOpinion | Three-layer: deny patterns → permission patterns → confirmation callback |
| **Tool delegation** | Native (in-process) or Delegated (oh-my-pi backend) routing | All in-process |
| **Unique tools** | RunTests (first-class), extension-provided tools (CtxDoctor, ExaSearch, Compose, etc.) | rename_symbol (cross-file), todo (in-memory task lists), sub_agent, shared_state |

Motoko's tool dispatch is notably more sophisticated — each tool call passes through an extension hook pipeline where any extension can Allow, Deny, Pending (block for operator approval), or Handle the call. yoyo's tool handling is simpler but has a more mature safety system (deny patterns for destructive commands).

---

## Self-Evolution

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Mechanism** | Phoenix Architecture: `.agent/` plans/summaries are the source of truth; code is regenerated from design traces | Automated multi-agent pipeline (`scripts/evolve.sh`) on cron |
| **Cadence** | Session-by-session (human-triggered) | Hourly GitHub Actions (gated to ~8-hour intervals) |
| **Planning** | 80+ plans in `.agent/plans/`, 60+ session summaries | Two-phase: Assessment agent + Planning agent (up to 3 tasks per session) |
| **Implementation** | Agent writes code, DP7 verifier gate runs `make check_core` | Per-task agent with build gate + test gate + evaluator agent |
| **Verification** | Z3 formal verification (`ailang verify`), type checking (`ailang check`), inline tests | `cargo build && cargo test`, mutation testing (`cargo-mutants`), evaluator agent |
| **Rollback** | Manual | Automatic: failed tasks git-reset to pre-task SHA |
| **Protected files** | Not explicitly enumerated | IDENTITY.md, PERSONALITY.md, scripts/evolve.sh, .github/workflows/, core skills |
| **Self-filed issues** | Not implemented | Yes — reverted tasks create `agent-self` labeled GitHub issues |
| **Design archive** | `.agent/` (plans, summaries, research, learnings, specs, reviews, issues, discussions, notes) | `journals/JOURNAL.md`, `memory/` (learnings, social learnings) |
| **Trajectory tracking** | SharedMem-based cache keyed by task hash | Computed from audit-log branch + git log + CI results |
| **Competitive research** | Research papers in `papers/` | Active competitor analysis (Claude Code, Cursor, Aider, Codex) built into assessment phase |

yoyo's self-evolution is more **automated and operationalized** — it runs on a cron, has multi-agent verification, automatic rollback, and self-filed issues. Motoko's self-evolution is more **theoretically grounded** — it uses formal verification (Z3), algebraic effects, and treats design documents as the primary artifact. yoyo has evolved from ~200 to ~43,000 lines through its own pipeline; Motoko's approach is younger and more experimental.

---

## Multi-Agent Composition

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Architecture** | Compose extension with configurable sub-agent model | Sub-agent spawning via `/spawn` command + `sub_agent` tool |
| **Verification** | Claimcheck: informalizer model generates claims → comparator model verifies (confirmed/disputed/vacuous/surprising_restriction/inconclusive) | No formal verification of sub-agent outputs |
| **Data passing** | AILANG effect system + compose events (JSONL protocol) | Shared state key-value store (`shared_state` tool) |
| **Depth limit** | Not explicitly documented | Hard cap of 3 recursive dispatches |
| **Maturity** | "Highly experimental, partly non-functional" (per README) | Functional, used in evolution pipeline (assessment/planning/implementation/evaluation agents) |

Motoko's compose system is more ambitious (semi-formal claim verification) but less mature. yoyo's multi-agent is more pragmatic and battle-tested (it runs the evolution pipeline daily).

---

## TUI / User Interface

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Framework** | TypeScript + `@mariozechner/pi-tui` | Rust + `rustyline` |
| **Rendering** | Full TUI with history pane, status bar, Markdown rendering, syntax highlighting | REPL with syntax-highlighted output, cost visualization |
| **Slash commands** | /model, /abort (small set) | 70+ commands across 10+ categories |
| **Features** | Model picker overlay, thinking trace expand (Ctrl+T), context window counter, streaming markdown, tool call visualization | Tab completion, multi-line input, bookmarks, undo system, watch mode, background jobs |
| **Non-TTY modes** | PlainLogger, JsonlLogger, headless mode | Single-prompt, piped, stream-JSON modes |
| **Custom commands** | Not supported | `.yoyo/commands/` directory for user-defined commands |

yoyo's CLI is significantly more feature-rich (70+ commands vs a handful). Motoko's TUI is more visually polished (dedicated TUI framework with panes, overlays, streaming Markdown) but offers fewer commands.

---

## Testing & Verification

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Unit tests** | AILANG inline tests + `*_test.ail` files | 2,000+ Rust integration tests |
| **TUI tests** | Jest tests (~20 test files) | N/A (TUI is in Rust, tested via cargo test) |
| **Formal verification** | Z3 contracts (`ensures`, `requires`, `invariant`) on pure functions | None |
| **Mutation testing** | Not implemented | `cargo-mutants` |
| **Benchmarks** | Exercism/Polyglot, smoke, Terminal-Bench adapter, GAIA scorer | Not documented |
| **CI** | `make check_core` (type check), `make test_core` | `cargo build + test + clippy + fmt` |
| **Deterministic replay** | `StepProvider = LiveAI \| Scripted` for testing without LLM | Not documented |

Motoko's testing story has a unique strength: formal verification via Z3 on pure functions with contracts. yoyo compensates with sheer test volume (2,000+ tests) and mutation testing.

---

## Provider Support

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Providers** | Anthropic, OpenAI, Google Gemini, OpenRouter, Ollama, custom OpenAI-compatible | 14 providers (Anthropic, Google, AWS Bedrock, OpenAI, OpenRouter, Ollama, xAI, Groq, DeepSeek, Mistral, Cerebras, Zhipu AI, MiniMax, Custom) |
| **Failover** | Not implemented | `--fallback <provider>` with automatic switching |
| **Prompt caching** | Anthropic `cache_control` stamps on system prompt | `CacheStrategy::Auto` via yoagent |
| **Architect mode** | Not implemented | Two-phase: planning model + cheaper editor model |

yoyo has broader provider support and failover capabilities.

---

## Community & Maturity

| | **Motoko** | **yoyo-evolve** |
|---|---|---|
| **Stars** | Small/private | ~1,700 |
| **Commits** | ~50+ (small team) | 1,863 (many automated) |
| **License** | Not specified in README | MIT |
| **Crate/package** | Not published | `yoyo` crate v0.1.10 |
| **Social presence** | None documented | Autonomous GitHub Discussions participation (social sessions every 4 hours) |
| **Sponsorship** | None | Monthly sponsors get issue priority; one-time sponsors get accelerated evolution runs |

---

## Key Differentiators

### Motoko's unique strengths

1. **AILANG** — purpose-built language with algebraic effects tracking every side effect at compile time
2. **Z3 formal verification** — mathematical proofs on pure functions, unique among agent harnesses
3. **Typed extension hooks** — 8-point pipeline with compile-time guarantees
4. **Claimcheck verification** — semi-formal multi-model verification of compose outputs
5. **Phoenix Architecture** — design traces as the primary artifact, code as downstream
6. **Deterministic replay** — `StepProvider` abstraction for testing without LLM calls
7. **Benchmark infrastructure** — Exercism/Polyglot, Terminal-Bench, GAIA adapters

### yoyo-evolve's unique strengths

1. **Proven self-evolution at scale** — ~200 → ~43,000 lines through its own pipeline
2. **Operationalized automation** — cron-based evolution with automatic rollback and self-filed issues
3. **Mature CLI** — 70+ commands, watch mode, undo system, background jobs
4. **14-provider support with failover** — broadest provider coverage
5. **Skill evolution** — skills autonomously refine/create/retire based on usage evidence
6. **Social autonomy** — autonomous GitHub Discussions participation
7. **Sponsorship-driven prioritization** — financial model for community issue triage

### Convergence

Both are self-evolving agent harnesses with multi-agent composition, context compaction, streaming tool execution, cost tracking, and a strong philosophical stance on agent autonomy. Both maintain institutional memory (`.agent/` vs `journals/` + `memory/`). Both use prompt caching for cost reduction.

### Sharpest divergence

Motoko is a **research vehicle** — it bets that formal methods (Z3, algebraic effects, typed extensions) will be necessary to make self-evolving systems safe. yoyo is a **product** — it bets that Rust's safety, extensive testing, and operational automation are sufficient, and prioritizes shipping features and competing with Claude Code. Motoko's approach is more theoretically ambitious; yoyo's is more practically mature.

---

## Implications for Motoko

### Features worth studying from yoyo

1. **Automatic rollback** on verification failure — Motoko's DP7 gate rejects but doesn't auto-revert
2. **Self-filed issues** — when a task fails, yoyo creates a GitHub issue for future sessions
3. **Watch mode** — auto-lint/test after edits with multi-phase fix loops
4. **Provider failover** — `--fallback` for automatic switching on API errors
5. **Skill evolution** — autonomous refinement of skills based on audit log evidence
6. **Protected file enumeration** — explicit list of files the agent cannot modify
7. **Undo system** — turn-level snapshots for reversibility

### Where Motoko already leads

1. AILANG's effect system is a stronger safety foundation than Rust's type system for *behavioral* correctness
2. Z3 verification is a genuine moat — no other agent harness has this
3. The extension hook pipeline (8 typed hooks) is architecturally superior to prompt-injected skills
4. Claimcheck compose verification is novel and has no equivalent in yoyo
5. The Phoenix Architecture's emphasis on design traces over code is philosophically distinctive
