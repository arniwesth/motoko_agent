# Spatiotemporal Composability (Cordis) vs. Motoko

**Paper:** "A Programming Paradigm for Spatiotemporal Composability" — Yifan Shi, Wei Zhang, Tianyi Cui (Peking University / DeepSeek-AI), Aug 2026, 88 pp.
**Source:** https://github.com/cordiverse/paper/blob/main/paper.pdf
**Implementation:** Cordis meta-framework (TypeScript); validated on Koishi (chatbot framework, 4000+ community plugins)
**Analyzed:** 2026-08-14

## Why this paper matters to Motoko

The paper's motivating example (§1.2.2) and its closing future-work paragraph (§8) are both **self-evolving agent harnesses** — a system that generates and replaces its own components continuously with little human oversight. That is Motoko's stated purpose. The paper explicitly says applying Cordis to such a harness "would validate the temporal guarantees of complete recovery under rapid component replacement, as well as the spatial guarantees of dependency coordination under frequent topological change." Motoko is the natural testbed the paper is looking for — and the paper supplies the runtime theory Motoko currently answers with restart-and-verify instead.

## Paper summary

The paper identifies two orthogonal dimensions of dynamic composition and lifts classical effect/coeffect theory from static type systems to runtime mechanisms:

- **Temporal composability** — removing a component must completely revert its side effects. Formalized as **revertible effects**: every context transformation has type `Γ → Γ × (Γ → Γ)` — it returns the new context *plus an explicit inverse*, which the runtime tracks and composes (LIFO). Unloading = applying the accumulated inverse. Tracking and recovery are monoid homomorphisms, so composite teardown is derived from loading, never hand-written. An *independence* condition (commuting transformation monoids, Def. 19) lets one component's inverse run correctly even after other components' effects have moved the state — the key to withdrawing one component from a running system.
- **Spatial composability** — dependencies must be declared and reactively managed. Formalized as **reactive coeffects**: a component declares a dependency set `d ⊆ K`; every context change is classified against it as *activating / deactivating / neutral* (Def. 26), driving automatic activation and teardown as providers appear and vanish. Extensions: **coeffect isolation** (realm tables — same key resolves differently per context; runtime ad-hoc polymorphism) and **coeffect interception** (monoid-merged metadata on access — cross-cutting policy, e.g. capability attenuation, installable at runtime without triggering reloads).

The two unify into a single recursive context type `Γ∞ ≔ μΓ. Γ × (Γ → Γ) × Σ` — state + inverse accumulator + dependency table — a tree-shaped hierarchy where loading = plugging in, unloading = unplugging. §4 gives an operational calculus: **components** `(d, p, e)` (dependency spec, provision set, witnessed effect function) instantiate as **fibers** with lifecycle states, target views vs. committed views, an inertial state machine (in-flight transitions run to completion, then chain), and metatheory (preservation, global temporal/spatial composability, progress, confluence). §5 realizes this in Cordis: `ctx.effect` (single mutation primitive returning a dispose closure), `ctx.get/set` + `notify`/`refresh` (reactive resolution keyed by *provider uid*, not value), proxy-mediated access enforcing declared coeffects at point of use, a declarative loader with config reconciliation, and annotation-free HMR with transactional rollback.

Admitted limitations: the runtime **cannot verify that a supplied inverse actually reverts its effect** (`g∘f = id` is an author obligation, §5.1.1/§6.1); emissions past the system boundary can only be withheld or compensated (§6.1); dependency linking is nominal (key identity) with no versioning story (§6.6); the Koishi case study is observational — "an existence-and-adoption result rather than a quantitative one" (§5.3).

## The comparison: opposite bets on both axes

Both systems ask *how does a system safely add, remove, and replace its own components?* — and bet oppositely.

### Temporal: revert-after vs. verify-before

- **Cordis** makes a faulty modification **revertible after the fact**: live, restart-free unload; state, caches, and connections elsewhere survive. §1.2.3 dismisses "restart the process" as the coarse-grained workaround.
- **Motoko** deliberately embraces the restart ([Phoenix Architecture](../phoenix-architecture.md): code is disposable, regenerable; cheap restart + per-profile config is the recovery mechanism) and instead makes modifications **verifiable before the fact**: ~20k lines of DST (`src/core/dst_*.ail`), a 12-family invariant oracle over the typed event ledger, an 11-class fault catalogue, and (project 014) DST as a deterministic *admission gate* for self-modifications — mutants pre-filtered by replay before any live deployment. The Gödel-machine lineage and Cordis both lack this.
- Failure-mode symmetry: the paper warns "a faulty self-modification can disable the very process needed to recover" — and Phoenix's restart answer fails exactly when the modification breaks the restart path. Cordis's answer fails exactly when an author's inverse is wrong (unverified). Each bet has an unguarded flank the other guards.

### Spatial: reactive runtime resolution vs. static registry + fixed hook slots

- **Cordis**: fibers activate when their `inject` keys become provided, tear down reactively when a provider withdraws; open dependency topology across independently-authored plugins (Koishi's IM adapters / database drivers / consumers).
- **Motoko**: extension set fixed at compile time (`ailang.toml` → `registry_generated.ail`); which extensions run and in what order is per-run JSON-profile configuration; no hot-plug. Extensions do not depend on *each other* — they are layered interceptors over eight fixed host hook slots with per-slot combination laws (fold / chain / precedence-merge / first-wins).
- **Uncomfortable observation**: by the paper's own taxonomy, Motoko's extension model is structurally closer to VSCode's "fixed extension points" architecture that §1.2.1 *critiques* (plugins contribute to the host, rarely to one another) than to Cordis's open topology. Mitigation one level down: *tools* are dynamic (MCP and a2a extensions synthesize tools from runtime config; ailang_docs is workdir-gated).

### Deep convergence despite opposite bets

| Concern | Cordis | Motoko |
|---|---|---|
| Ambient authority | Rejected: all mutation via `ctx.effect`, access via declared `inject` | Rejected: extensions get capabilities only via injected `ExtPorts` closures; ambient effect imports mechanically forbidden (`make ext_ambient_inventory`) |
| Coeffect specification | Runtime-checked `inject` declaration; proxy-mediated access fails on undeclared keys | Compile-time **closed effect rows** per ABI hook slot — capability overreach is a type error |
| Effect attribution | Every effect attributable to a fiber's context | Driver is sole ledger emitter; `ExtWorld` token threads state explicitly |
| Composition semantics | Calculus with preservation/progress/confluence proofs | Deterministic per-slot combination laws + empirical gates (`declared_vs_performed`, `ext_hook_scope`, `profile_coverage`) |
| Access control | Capability framing: inject = capability request, proxy = mediator; interception metadata attenuates (§6.3) | Capability framing: ports + derived inventories |
| Lifecycle machine | Inertial fiber state machine (target vs. committed view; transitions run to completion, then chain) | Pure `step_machine.ail` decision policy + driver executing decisions-as-data |

Most striking: the paper's **co-design wishlist** (§6.4, §6.7) — effects/coeffects known to the compiler, dependency specs admitted into the type system, cycles reported at compile time, implicit-but-tracked context — describes roughly what Motoko already gets from AILANG. Cordis is the *library* realization (TypeScript, Proxy, runtime checks); Motoko is a partial existence proof of the *language-level* realization the paper can only sketch. Conversely, AILANG's effect rows track *that* effects happen, not *how to undo them* — classical static effects, exactly what the paper argues is insufficient for dynamic composition.

## Each covers the other's admitted gap

**Motoko covers Cordis's gaps:**
1. *Unverified inverses.* `ctx.effect` never checks `g∘f = id` — an author obligation. DST replay with fault injection and invariant oracles is precisely the machinery to discharge that obligation mechanically (revert-then-replay equivalence as an invariant family).
2. *No quantitative validation, no harness validation.* The Koishi case study is observational; harness validation is deferred to future work. Motoko's measurement culture (deriving claims from inventories, even computing the vacuity of its own coverage numbers) is the missing evaluation methodology.

**Cordis covers Motoko's gaps:**
1. *No zero-downtime self-modification.* Every harness change is rebuild-and-restart — acceptable for episodic coding sessions, not for the continuously-serving future both projects imagine.
2. *Registration outside the ledger.* Extension registration runs before dispatch and is invisible to the ledger oracle. In Cordis, instantiation is itself a tracked revertible effect of the parent fiber (Def. 47 / Algorithm 4) — the hole is closed by construction.
3. *Manual world threading.* ~196 hand-threaded `next_state` sites in core are exactly the discipline Cordis's accumulator automates structurally.

## Convergence point: project 013

Project 013 (`core_architecture_for_dst`) is already moving toward the shape that would make a Cordis-style model adoptable:

- **Defunctionalize the world boundary** (12 port fields × adapter families → one `handle`) and **commands + interpreter**: commands-as-data are exactly the representation to which inverses can be attached. After that refactor, "every command carries an inverse" is one more field on a data type, not a paradigm shift.
- A revertible-effect layer over the command interpreter would let the ledger record inverse accumulation, making unload/replay symmetric and closing the registration gap.
- Reactive coeffects matter less while extensions stay non-interdependent — but the moment extensions provide services to each other (e.g. compose consuming mcp-provided tools as a dependency), Cordis's provider-uid target-view mechanism is the worked-out answer to "reload precisely the dependents whose resolved provider changed."

## Adoption analysis: which concepts to take, and where they land

Cross-referenced against `.agent/projects/013_core_architecture_for_dst/RESEARCH-core-architecture-for-dst.md`, several of the paper's concepts land exactly on gaps 013 has already diagnosed. Ordered by fit.

### Direct hits (the paper solves a problem 013 already names)

**1. Registration as a tracked, revertible effect — lands on 013-E.**
013-E flags that extension registration "runs ambient, before the driver dispatches anything," outside both the world and the ledger. The paper's Definition 47 / Algorithm 4 is the worked-out design for exactly this: instantiation is an ordinary tracked effect of the parent whose inverse is *retire*, so it sits inside the recorded program by construction. Adopting this shape when routing `ExtRuntime` construction through the world boundary closes the hermeticity substitution and enables the `extension_registration_failure` fault class 013 wants. Cheapest, most direct borrow.

**2. Inverse-carrying commands — lands on 013-D (commands + interpreter).**
013-D already proposes `step : (StepState, WorldResponse) -> (StepState, [Command], [LedgerEvent])`. Once effects are commands-as-data, the revertible-effect model is one more field: each command variant optionally carries its inverse command, and the interpreter accumulates them LIFO (the paper's `dispose` composition). Motoko-specific payoffs:
- **Fine-grained rollback.** Today recovery is coarse (env-server tree snapshot/restore). Inverse accumulation gives per-step, per-tool rollback — a failed checkpoint reverts file writes and spawned processes without restoring a whole tree.
- **A new DST invariant family: revert-then-replay equivalence.** Apply a command sequence, run the accumulated inverse, assert the world state matches up to the paper's observational equivalence (Def. 33). This is the part Cordis **cannot do** — `g∘f = id` is an unverified author obligation there (§5.1.1). DST is precisely the machinery to verify inverse witnesses mechanically. A genuine contribution beyond the paper, not just an adoption.
- **A new fault class** (`inverse_mismatch`) slots into the existing 11-class catalogue.

**3. Coeffect interception — the policy algebra for capability attenuation, lands on 013-C.**
013-C wants per-hook capability narrowing (waiting on upstream `m-effect-scope-params`). The paper's interception model (§3.2.3, §6.3) supplies the missing algebra: monoid-merged metadata, right-biased so the enclosing context overrides the component's declaration. Concretely: the `ExtPorts` closures handed to each extension get wrapped by profile-declared metadata before injection — e.g. a profile grants an extension read-only, path-scoped `file_read` without modifying the extension or the ABI. Doable in userland today, ahead of the upstream language feature; converges with `m-effect-scope-params` when it ships.

### Good fits, second wave

**4. Target view vs. committed view — for the dependencies Motoko already has that *can* vanish.**
Extensions don't depend on each other, so full reactive coeffects would be machinery without a client. But runtime dependencies that appear and disappear exist one level down: MCP servers, a2a peers, the backend connection. Cordis's mechanism — record the *provider identity* a consumer activated against, recompute a target view on change, deactivate/reactivate only affected dependents (§5.1.3) — is the right shape for making `delegate_to_<agent>` and MCP tools degrade cleanly: a tool deactivates when its server dies and reactivates on reconnect, instead of erroring at call time.

**5. Coeffect isolation (realms) — a vocabulary for what DST ports-swap already does.**
"Same key resolves to different bindings per context" is exactly the ports-swap / fixture-mode pattern, generalized per-fiber. Useful when compose subagents need scratchpads/env isolated from the parent — but AILANG's planned `FS[mode=fixture]` covers much of this. Wait.

### Explicitly not adopted

- **Hot-pluggable extensions / HMR.** The compile-time registry with closed effect rows is Motoko's differentiator — capability overreach as a *type error* is strictly stronger than Cordis's runtime proxy check, and the paper's own §6.4 concedes compile-time metaprogramming can replace the runtime mediation. Trading that for hot-plug would adopt the paper's weakest realization to solve a problem Phoenix-restart already handles for episodic sessions.
- **The calculus metatheory as such.** Motoko's analogue of confluence/progress proofs is the empirical invariant suite; porting proofs about Cordis's model would verify their model, not Motoko's implementation.

### Sequencing

Composing with 013's existing plan: **B1 (world ordinal) → C (generic profile runner) → E with Def-47 shape (registration as tracked effect) → D (commands + interpreter) → inverse field on `Command` + revert-then-replay invariant family → interception-style attenuation** (userland first, upstream convergence later). Items 1–3 need no upstream AILANG changes.

Summary: don't import the paper's *runtime* machinery wholesale; its *representations* — instantiation-as-tracked-effect, inverse-carrying commands, monoid-merged capability metadata — drop cleanly onto the architecture 013 is already steering toward, and DST would make Motoko the first system able to *verify* the paper's central unverified obligation.

## Bottom line

Cordis and Motoko are **duals, not competitors**. Cordis makes change safe *during* runtime — structural recovery, reactive rewiring, hot replacement — but leaves inverse correctness and the whole self-evolution loop unvalidated. Motoko makes change safe *before* runtime — effect-typed capability confinement, deterministic pre-verification, measured governance — but composes statically and recovers by restarting. A genuinely self-evolving harness plausibly needs the union: **DST-gated admission of mutants feeding a revertible, reactively-wired component runtime.** The paper wants Motoko as its validation target; Motoko's 013/014 roadmap is the on-ramp for the paper's runtime.
