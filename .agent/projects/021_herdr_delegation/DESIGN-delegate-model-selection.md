# Design: choosing a delegate's model — the transports exist, the policy does not

Date: 2026-08-26
Status: **Design + measurements. Not implemented. No Linear issue yet.**
Provenance: every measurement in §2–§4 was taken this session against the running herdr
(0.8.2) and this repo at HEAD. Findings build on
[`MEASUREMENTS-2026-08-22.md`](MEASUREMENTS-2026-08-22.md) (M1, M2, P2-3, P2-5, P2-7) and
[`DESIGN-motoko-as-delegate.md`](DESIGN-motoko-as-delegate.md) §4. What was not measured is
listed at the end of §7.

---

## TL;DR

`Delegate` exposes `prompt`, `kind`, `cwd`. There is no model parameter and no model concept
anywhere in `motoko-ext-herdr`.

Adding one is possible on **both** spawn paths, and on neither is the transport the problem — both
already exist and are already used for something else. The Motoko path needs **one `--env` pair**.

The actual work is **policy**: nothing anywhere validates a model string. A bogus model is accepted
by every layer and fails only when the delegate tries to do work — which is inside the answer-file
window, and therefore reappears as P2-3's *finished but never wrote*. This is now the **third**
independent route to that same failure shape.

A second finding may matter more than the feature: **model choice can change the delegate's
permission mode**, and a delegate in manual mode cannot run unattended at all (§2.4).

## 1. The two paths

| | claude/codex — `agent start` | motoko — `pane run` |
|---|---|---|
| transport | `herdr agent start … -- [AGENT_ARG]…` passthrough | `MODEL` environment variable |
| already used for | `kind_default_args("codex")` → `-- -s danger-full-access -a never` | nothing; `argv_split` already emits three `--env` pairs |
| change needed | `kind_default_args(kind)` → `kind_model_args(kind, model)`, **plus a per-kind flag map** | add `--env MODEL=<x>` to `argv_split` |
| size | moderate — `--model` is not universal across the 22 kinds | one line |

Note the inversion. [`DESIGN-motoko-as-delegate.md`](DESIGN-motoko-as-delegate.md) §4 calls the
Motoko lifecycle "a branch rather than a table entry" because three of six steps differ. For model
selection it is the *simpler* path, because an env var needs no per-kind knowledge.

## 2. Measured: the `agent start` path

### 2.1 The passthrough reaches the executable

```
$ herdr agent start mot-modeltest-1 --kind claude --pane w4:pX --timeout 30000 \
    -- --model claude-haiku-4-5-20251001
{"…","argv":["claude","--model","claude-haiku-4-5-20251001"],"type":"agent_started"}
real  0m3.696s
```

herdr's own `argv` echo is self-report, so it was checked independently against the process table:

```
pid=575840  claude --model claude-haiku-4-5-20251001      # /proc/<pid>/cmdline
```

### 2.2 A valid model is applied, not merely accepted

The pane banner resolves the id to a display name:

```
 ▐▛███▛█   Claude Code v2.1.246
▝▜██████▀  Haiku 4.5 · Claude Max
```

### 2.3 A bogus model starts successfully — this is the finding that drives §5

```
$ herdr agent start mot-modeltest-2 --kind claude --pane w4:p0 --timeout 30000 \
    -- --model claude-opus-9-turbo-BOGUS
… "agent_status":"idle","interactive_ready":true …
real  0m3.894s   exit=0
```

Inside the pane:

```
"claude-opus-9-turbo-BOGUS" is not a model this version of Claude Code recognizes,
so auto-compact will keep this session within 200k tokens …
▝▜██████▀  claude-opus-9-turbo-BOGUS · Claude Max
❯
```

A **warning, not an error**. herdr reports `exit 0`, `interactive_ready: true`, `idle`, after a full
pane split and 3.9 s. The agent sits at a usable prompt on a model that does not exist. This is M2's
*"herdr's ready is not usable"* reached by a new route, and it is worse than a start failure would
be: a start failure is visible immediately, whereas this surfaces only when the delegate works.

There is a discriminator, if one is wanted post-spawn: a **recognized** model resolves to a display
name (`Haiku 4.5`), an **unrecognized** one is echoed verbatim. That is readable via `pane read`.
But it costs a pane and ~3.9 s to learn what a list lookup answers for free.

### 2.4 Model choice can change the permission mode

Unplanned, and operationally the most important thing here. The two panes differed:

| model | status line |
|---|---|
| `claude-opus-9-turbo-BOGUS` | `⏵⏵ auto mode on (shift+tab to cycle)` |
| `claude-haiku-4-5-20251001` | `⏸ manual mode on` · **`auto mode unavailable for this model`** |

Claude Code says this itself; it is not an inference. A delegate in manual mode blocks on approvals,
never writes the answer file, and `DelegateCheck` watches it sit `working` until the timeout — which
is P2-5 and P2-7's unattended-execution wall arriving through the model parameter instead of through
`kind`.

**Consequence:** an allowlist of models that *exist* is the wrong bar. The bar is models measured to
run **unattended** in this container — exactly the reasoning `HERDR_ALLOWED_KINDS` already encodes
for kinds. Caveat: observed once per model, not a controlled repeat across versions.

## 3. Measured: the Motoko path

Three hops, each checked separately.

**3.1 `--env` survives into the pane shell.** Splitting with
`--env MODEL=anthropic/claude-haiku-4-5`, then reading `/proc/<pid>/environ` of the pane's shell:

```
ANTHROPIC_API_KEY=
HERDR_DELEGATE_DEPTH=1
MODEL=anthropic/claude-haiku-4-5
OPENAI_API_KEY=
```

Consistent with M1, which established that `--env KEY=value` sets a real variable (and `KEY=` sets
it empty rather than unsetting it).

**3.2 A child process inherits it.** `echo CHAIN_MODEL=$MODEL` run in that pane →
`CHAIN_MODEL=anthropic/claude-haiku-4-5`. This is the hop `run-agent.sh` depends on: the script
never reads `MODEL` itself, it just `exec bun "$ENTRY" "$@"`.

**3.3 Motoko's runtime prefers it.** `resolveRuntimeModel(process.env, profileAgent.model)`
(`src/tui/src/index.ts:723`), called directly:

```
env set + profile set      -> anthropic/claude-haiku-4-5   (env wins)
env unset + profile set    -> profile/model
env blank + profile set    -> profile/model
neither                    -> anthropic/claude-sonnet-4-6
env BOGUS + profile set    -> totally/bogus-model-xyz      (unvalidated)
```

So the whole feature, for Motoko delegates, is one `--env MODEL=<x>` in `argv_split`.

## 4. Three findings independent of this feature

**4.1 `loadMotokoConfig` has no call site.** Defined at `src/tui/src/config.ts:366` and exercised by
`config.test.ts`; grep across `src/` finds no other caller. Its mapping contains
`"agent.model": { env: "MODEL" }`, so the TOML `agent.model` key never reaches `process.env.MODEL`.
Environment is the only live channel today. Either a wiring regression or intentionally pending —
worth settling, because the tests pass either way and would not catch the difference.

**4.2 `scripts/run-agent.sh` documents `MODEL` but never references it.** The header lists it under
"Environment variables (all optional)"; the body does not mention it. It works only by inheritance
through `exec bun`. Harmless today, but the header implies handling that does not exist.

**4.3 There is a model registry, and it is not used for validation.** `known_models` in
`src/tui/src/models.ts` is consumed only by `fetchDynamicModelsFromEnv`, which feeds the model
picker. `resolveRuntimeModel` returns whatever string it is handed.

## 5. Why this needs an allowlist rather than a passthrough

Three independent routes now converge on P2-3's *finished but never wrote*:

| route | how it fails |
|---|---|
| codex, unattended (P2-3) | reports success without delivering |
| claude + bogus model (§2.3) | starts "ready", fails at first API call |
| motoko + bogus model (§3.3) | string passes through, fails at first API call |
| any model without auto mode (§2.4) | blocks on approval, never writes |

None is caught before the pane is spent. The extension's own philosophy says they should be —
`register.ail` computes `provided_tools` rather than advertising tools that fail at call time, and
`do_delegate` refuses on kind, depth, and path *"BEFORE ANYTHING IS SPENT"*. A model parameter that
is only validated by the provider breaks that pattern.

**There is also an argv exposure on the claude path.** Today every argv element is operator-
configured; the model-authored prompt travels in a file specifically so it never reaches argv
(`do_delegate`: *"THE MODEL-AUTHORED PROMPT NEVER TOUCHES ARGV"*, the whole reason #158 is avoidable
here). A `model` param would be the **first model-authored string to reach argv**. `argv_is_safe`
only rejects shell metacharacters, so it would happily pass a bogus-but-clean string. An allowlist
closes both problems with one check; widening `argv_is_safe` closes neither and is explicitly warned
against in [`DESIGN-motoko-as-delegate.md`](DESIGN-motoko-as-delegate.md) §4.

## 6. Proposed shape

Mirror the kind policy exactly rather than inventing a second pattern.

| piece | shape |
|---|---|
| operator knob | `HERDR_ALLOWED_MODELS`, beside `HERDR_ALLOWED_KINDS` |
| schema | `model` param in `delegate_params(allowed)`, describing **only** the permitted set — same reasoning as the existing comment: advertising what the operator has not permitted costs the model a turn |
| validation | in `do_delegate`, beside `kind_allowed`, **before** `pane split` |
| claude/codex | `kind_model_args(kind, model)` — per-kind flag map, `--` passthrough |
| motoko | `--env MODEL=<x>` in `argv_split` |
| failure text | name the permitted set and say it is an operator decision, matching the existing `kind_allowed` refusal |

Do **not** widen `argv_is_safe`. Do **not** map "model exists" to "model permitted" (§2.4).

## 7. Open decisions, and what was not measured

**For the owner — do not close these inline** (the handoff's *Stop and report* fence):

1. **Should the model be model-selectable at all**, or operator-fixed per kind? Letting the LLM pick
   its delegate's model is a cost decision, and there is no budget propagation between parent and
   delegate to bound it — the same gap §6 of `DESIGN-motoko-as-delegate.md` names for recursion.
2. **Which models go on the allowlist.** Requires measuring unattended behaviour per model, not just
   existence (§2.4).
3. **Interaction with the billing guard.** `--env ANTHROPIC_API_KEY=` forces subscription auth, so
   entitlement bounds the usable set. An allowlist cannot detect a model the account may not use;
   that still fails at runtime.

**Not measured:** whether `--model` passthrough behaves the same for kinds other than `claude`;
whether the manual-mode constraint in §2.4 is version-specific to Claude Code v2.1.246; whether a
Motoko delegate actually runs to completion on a non-default model end to end (§3 verified the
resolution chain, not a full delegated task).

## 8. Relation to the dagr view

[`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) §3 has the producer record
`model` on every attempt. Today that field would be a guess, because nothing selects or records a
model. If this lands, the extension knows exactly what it passed and the dagr `model` chip becomes a
truthful per-attempt record — which also makes §2.4's failure mode visible on screen, since a
delegate stuck in manual mode shows as `working` with a stale `liveness.last_output_at` beside the
model that caused it.
