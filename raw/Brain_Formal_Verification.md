# Brain Formal Verification: Dafny + Lean 4 Gates

## Goal

Extend the upgrade validation pipeline established in `Brain_Test_Suite.md` with two
formal verification tiers that sit above inline tests, property tests, and Z3. These
tiers are **research bets** — each is independently removable via an environment
variable. They are not part of the pre-MVP test suite; they are optional gates that
activate once the self-modification machinery is operational.

---

## Relationship to other plans

```
Brain_Test_Suite.md         ← inline tests, properties, Z3 (hard gates, run today)
Brain_Formal_Verification.md ← Dafny + Lean 4 (advisory gates, require self-mod machinery)
Self_Modifying_Brain_Safe_Cutover.md ← upgrade orchestration that calls all gates
```

---

## The Three-Tier Formal Verification Stack

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Tier 1 — Z3 direct (existing @verify annotations in AILANG)            │
│                                                                         │
│  What it handles:                                                       │
│    Quantifier-free invariants. Simple boolean predicates. Properties    │
│    that reduce to linear arithmetic or bitvector reasoning after        │
│    unfolding one level of definition.                                   │
│                                                                         │
│  Brain effort:  None — @verify annotation on the function is enough.   │
│  Solver effort: Milliseconds.                                           │
│  Failure output: Counterexample (SAT witness) or timeout.              │
│                                                                         │
│  Brain module targets:                                                  │
│    is_root(path) ⟹ str_length(path) ≤ 3                               │
│    with_cache_hint(s, "") == s                                          │
│    fmt_obs always contains "$ " prefix (quantifier-free)               │
│                                                                         │
│  Ceiling: Cannot reason about split(), recursive functions,             │
│  or anything requiring induction. Times out on string list ops.        │
└─────────────────────────────────────────────────────────────────────────┘
                              │ Z3 times out or returns Unknown
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Tier 2 — Dafny (Phase 1 below)                                         │
│                                                                         │
│  What it handles:                                                       │
│    Termination via decreases measures. Postconditions on recursive      │
│    functions. Sequence/string structural properties expressible as      │
│    existential quantifiers that Z3 can discharge with guided framing.  │
│    Anything needing an intermediate lemma to help Z3 across the line.  │
│                                                                         │
│  Brain effort:  Write requires/ensures/decreases clauses. Occasionally │
│    write a helper lemma. No proof tactics.                              │
│  Solver effort: 1–10 s typical; up to DAFNY_TIMEOUT_MS (default 60s). │
│  Failure output: Concrete counterexample with variable bindings.       │
│                                                                         │
│  Brain module targets:                                                  │
│    walk_agents terminates: decreases |current|                         │
│    dirname strictly shrinks: ensures |result| < |path| (when path≠"/") │
│    extract_fence structural: ensures result.Some? ⟹                   │
│      fence + result.value + "```" ∈ text                               │
│    parse_cwd absolute-or-unchanged postcondition                       │
│                                                                         │
│  Ceiling: Still backed by Z3. Cannot prove properties requiring        │
│  structural induction over the full grammar of a data type, or         │
│  meta-theoretic properties about the language itself.                  │
└─────────────────────────────────────────────────────────────────────────┘
                              │ Dafny times out or cannot find lemma
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Tier 3 — Lean 4 (Phase 2 below)                                        │
│                                                                         │
│  What it handles:                                                       │
│    Full structural induction over unbounded data. Properties of the    │
│    form "for all strings of all lengths, regardless of content".       │
│    Equivalence proofs between old and new implementations. Properties  │
│    about the language's own type system or effect annotations.         │
│    Anything requiring a multi-step proof strategy the brain must plan. │
│                                                                         │
│  Brain effort:  Write theorem statements + tactic blocks. Revise       │
│    tactics on unsolved goals. May revise implementation on proof       │
│    failure.                                                             │
│  Solver effort: 2–60 s; can be much longer for complex induction.      │
│  Failure output: Unsolved proof goals (directed, not a counterexample).│
│                                                                         │
│  Brain module targets:                                                  │
│    is_done_spec: definitional equivalence to contains                  │
│    parse_cwd_absolute_or_unchanged: induction on split result          │
│    with_cache_hint full behavioural contract                           │
│    Upgrade equivalence: new extract_bash ≡ old extract_bash            │
│                                                                         │
│  Ceiling: Requires the brain to write valid Lean 4 tactics, which      │
│  LLMs do at moderate reliability today. Proof budget exhaustion leads  │
│  to advisory warning, not hard rejection (research phase).             │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key design principle:** The brain tries the cheapest tier first. A property
verified in Tier 1 never reaches Tier 2. A property verified in Tier 2 never
reaches Tier 3. The tiers are a cost escalation ladder, not parallel redundant
checks.

**Allocation for brain modules:**

| Function | Tier 1 (Z3) | Tier 2 (Dafny) | Tier 3 (Lean 4) |
|---|---|---|---|
| `is_root` | ✓ length ≤ 3 | — | — |
| `dirname` | — | ✓ shrinks, terminates | — |
| `walk_agents` | — | ✓ decreases measure | — |
| `is_done` | ✓ sentinel containment | — | ✓ definitional equiv. |
| `extract_fence` | — | ✓ structural postcondition | — |
| `extract_bash` | — | — | ✓ priority order proof |
| `parse_cwd` | — | ✓ absolute-or-unchanged | ✓ full induction |
| `with_cache_hint` | ✓ empty identity | — | ✓ prefix property |
| `fmt_obs` | ✓ dollar prefix | — | — |
| `base_system` | ✓ contains sentinel | — | — |

Properties marked with two tiers represent layered coverage: the cheaper tier
proves the simpler invariant; the more expensive tier proves the stronger contract.

---

## Phase 1 — Autonomous Dafny Spec + Verification

This phase sits between Z3 (Tier 1) and Lean 4 (Tier 3) in the verification
hierarchy. It is a **research bet**, independently removable via the
`DAFNY_VERIFY` environment variable.

### Why Dafny and not just more Z3 or Lean 4

Dafny is a **verification-aware programming language** from Microsoft Research. You
write code with inline `requires`/`ensures`/`decreases` clauses; Dafny calls Z3
automatically to verify them. No tactics, no proof scripts. When verification fails,
you get a **concrete counterexample with specific input values** — not an unsolved
proof goal. This makes the revision loop qualitatively different:

- **Lean 4 failure:** `unsolved goals ⊢ ∀ s, ¬s.containsSubstr "cd /" → ...`
  The brain must understand proof theory to proceed.

- **Dafny failure:** `Counterexample: cmd = "cd relative/path", result = "/relative/path"`
  The brain reads a specific bug report and fixes the implementation directly.

Dafny's counterexample feedback is more useful for finding real bugs; Lean 4's
unsolved goals are more useful for proving deep structural properties. They are
complementary, not competing.

### What the brain produces (Dafny)

For each upgraded module, the brain generates:

```
swe/dafny/<module>_spec.dfy
```

The file contains:
1. **Dafny mirror functions** — re-implementations of the AILANG functions in
   Dafny's language (using `seq<char>` for strings, Dafny's `Option` type, etc.)
2. **`requires`/`ensures` clauses** — postconditions on each function
3. **`decreases` measures** — termination witnesses for recursive functions
4. **Helper lemmas** — intermediate `lemma` declarations that guide Z3 when
   the main verification goal is too large for direct discharge

**Mirror drift:** Dafny specs are re-implementations. When the AILANG source
changes, `swe/dafny/*.dfy` must be regenerated. The upgrade manager must treat a
stale Dafny spec (one that does not match the current module's function signatures)
as a verification failure, not a skip.

Example for `walk_agents` termination:

```dafny
function dirname(path: string): string
  ensures |dirname(path)| < |path| || path == "/"

method walk_agents(current: string, acc: seq<string>)
    returns (result: seq<string>)
  decreases |current|   // ← Dafny verifies termination via this measure
{
  if is_root(current) {
    return if file_exists(current + "/AGENTS.md")
           then reverse(acc + [current + "/AGENTS.md"])
           else reverse(acc);
  }
  var parent := dirname(current);
  // ... recursive call on parent, which is strictly shorter
}
```

Example for `extract_fence` structural postcondition:

```dafny
function extract_fence(text: string, fence: string): Option<string>
  ensures extract_fence(text, fence).Some? ==>
    exists i :: 0 <= i < |text| &&
      text[i..i+|fence|] == fence &&
      "```" in text[i+|fence|..]  // closing fence exists after opening
{
  ...
}
```

### The revision loop (Dafny)

```
Brain generates swe/dafny/parse_spec.dfy
        │
        ▼
dafny verify swe/dafny/parse_spec.dfy
        │
   ┌────┴────┐
   │ passes  │  → proceed to Lean 4 gate
   └─────────┘
        │
   ┌────┴────┐
   │  fails  │  → counterexample fed back to brain
   └─────────┘
        │
        ▼
Brain reads counterexample, revises spec or implementation
(max DAFNY_REVISION_BUDGET attempts, default 5)
        │
   ┌────┴──────────┐
   │ budget        │  → dafny gate: SKIP (log warning, proceed to Lean 4)
   │ exhausted     │
   └───────────────┘
```

**Error feedback format sent to brain:**

```
Dafny verification attempt 2/5 failed.

File: swe/dafny/agents_md_spec.dfy
Error:
  agents_md_spec.dfy:34: A postcondition might not hold on this return path.
  Postcondition: ensures |result| < |path| || path == "/"
  Counterexample:
    path  = "/"
    result = ""      ← dirname("/") returned "" not "/"
  
Please revise swe/dafny/agents_md_spec.dfy or swe/agents_md.ail.
The counterexample suggests dirname("/") has an edge-case bug.
```

### Dafny installation and invocation

```bash
dotnet tool install --global Dafny
dafny --version  # verify
```

The upgrade manager invokes it as a subprocess:

```typescript
const result = await spawnWithTimeout(
  "dafny",
  ["verify", dafnyFilePath],
  { cwd: workspacePath, timeout: DAFNY_TIMEOUT_MS }
);
```

`DAFNY_TIMEOUT_MS` defaults to 60 000 (60 s). The `DAFNY_VERIFY` environment
variable gates the phase; missing binary → skip with warning.

---

## Phase 2 — Autonomous Lean 4 Spec + Proof Generation

This phase is explicitly a **research bet**. If it works, the upgrade gate gains a
mathematically rigorous final check. If LLM-generated Lean 4 proofs prove too
unreliable in practice, the phase is removed and the pipeline falls back to Phase 1.
It is designed to be additive and independently removable.

### What the brain produces

For each upgraded module, the brain generates a single Lean 4 file:

```
swe/lean4/<module>_spec.lean
```

The file contains three things, in order:

1. **The axiom layer** — correspondence between AILANG stdlib primitives and Lean 4's
   native `String` operations. These are `axiom` declarations (not proofs) that
   establish the bridge between the two languages. The brain generates these once per
   module based on which stdlib functions the module imports.

2. **The spec** — `theorem` statements expressing the behavioural contract of each
   exported function. The brain authors these as part of the upgrade task.

3. **The proof** — tactic blocks that discharge each theorem. The revision loop
   targets this section when `lean --check` fails.

### The axiom layer

AILANG's stdlib functions (`contains`, `startsWith`, `split`, `trim`) are implemented
in Go and have no Lean 4 definition. To reason about them in Lean 4, the brain
declares `axiom`s asserting their correspondence with Lean 4's native equivalents:

```lean
-- Axioms the brain generates based on swe/parse.ail's imports
-- These are trust anchors: correct by construction from the Go implementation.

axiom ailang_contains (s sub : String) :
  ailang.contains s sub = s.containsSubstr sub

axiom ailang_startsWith (s pre : String) :
  ailang.startsWith s pre = s.startsWith pre

axiom ailang_trim (s : String) :
  ailang.trim s = s.trim
```

**Known risk:** The brain might generate axioms that are false (mismatching Go and
Lean 4 semantics). A false axiom makes all downstream proofs meaningless — you can
prove anything from `False`. Mitigation: flag any axiom that asserts equality between
functions with different edge-case behaviour (e.g., `split` on empty string differs
between implementations). In practice, the axiom layer is small (~10 axioms for all
of `parse.ail`) and a human reviewer should audit it once.

**Long-term:** The axiom layer is a one-time cost. Once established for the current
modules, it only changes when new stdlib imports are added. The brain extends it
incrementally when it adds new imports.

### The spec

The brain writes `theorem` statements for each exported function. These are the
behavioural contracts — what the function is *supposed to do*.

Example for `is_done`:

```lean
-- is_done is exactly a containment check on the sentinel string
theorem is_done_spec (stdout : String) :
    ailang.is_done stdout =
    stdout.containsSubstr "COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT" := by
  simp [ailang.is_done, ailang_contains]
```

Example for `with_cache_hint`:

```lean
-- empty hint is identity
theorem with_cache_hint_empty_identity (system : String) :
    ailang.with_cache_hint system "" = system := by
  simp [ailang.with_cache_hint]

-- non-empty hint prepends the system string
theorem with_cache_hint_prefix (system hint : String) (h : hint ≠ "") :
    (ailang.with_cache_hint system hint).startsWith system := by
  simp [ailang.with_cache_hint, String.startsWith_append, h]
```

Example for `parse_cwd` (the inductive case Z3 cannot handle):

```lean
-- parse_cwd without "cd /" is the identity on cwd
theorem parse_cwd_no_cd_identity (cmd cwd : String)
    (h : ¬cmd.containsSubstr "cd /") :
    ailang.parse_cwd cmd cwd = cwd := by
  simp [ailang.parse_cwd, ailang_contains, h]

-- parse_cwd result is always an absolute path or the original cwd
theorem parse_cwd_absolute_or_unchanged (cmd cwd : String) :
    ailang.parse_cwd cmd cwd = cwd ∨
    (ailang.parse_cwd cmd cwd).startsWith "/" := by
  ...
```

**The non-triviality problem:** A brain trying to minimise proof effort might write
specs that are trivially true: `theorem foo : True := trivial`. Guard against this
with two mechanical checks in the upgrade manager before calling `lean --check`:

1. The spec file must contain at least one `theorem` per exported function.
2. Each theorem statement must reference the function name being verified (syntactic
   check on the theorem body — grep for the function identifier).
3. At least one theorem per function must have a hypothesis (`h :`) or a universal
   quantifier (`∀`) — ruling out fully ground theorems like `f "x" = "x"`.

These checks are syntactic and fast. They don't guarantee quality but prevent the
most obvious degeneracy.

### The revision loop

```
Brain generates swe/lean4/parse_spec.lean
        │
        ▼
lean --check swe/lean4/parse_spec.lean
        │
   ┌────┴────┐
   │ passes  │  → upgrade proceeds to swap
   └─────────┘
        │
   ┌────┴────┐
   │  fails  │  → stderr fed back to brain as new message
   └─────────┘
        │
        ▼
Brain reads error, revises spec or proof
(max LEAN4_REVISION_BUDGET attempts, default 5)
        │
   ┌────┴──────────┐
   │ budget        │  → lean4 gate: SKIP (log warning, proceed)
   │ exhausted     │     upgrade accepted without lean4 guarantee
   └───────────────┘
```

**Budget exhaustion behaviour:** When the revision budget is exhausted, the upgrade
is not *rejected* — it is accepted without the Lean 4 guarantee, with a warning
emitted to the UI. This keeps the gate advisory during the research phase. Once
confidence in the brain's proof-generation ability is established, the budget
exhaustion path can be changed to rejection.

**Error feedback format sent to brain:**

```
Lean 4 verification attempt 2/5 failed.

File: swe/lean4/parse_spec.lean
Error:
  parse_spec.lean:31:4: error: unsolved goals
  case h
  cmd cwd : String
  h : cmd.containsSubstr "cd /"
  ⊢ (cmd.splitOn "cd /").tail.head?.map (·.splitOn " ").head? = some cwd
    ∨ ailang.parse_cwd cmd cwd = cwd

Please revise swe/lean4/parse_spec.lean to discharge the remaining goals.
You may also revise swe/parse.ail if the proof reveals a spec issue.
```

The key phrase is the last line: the brain is permitted to revise the *implementation*
if the proof reveals an actual bug. This is the most valuable feedback pathway —
a failing proof can expose a correctness issue that all other tests missed.

### Lean 4 installation and invocation

```bash
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
lean --version  # verify
```

The upgrade manager invokes it as a subprocess:

```typescript
const result = await spawnWithTimeout(
  "lean",
  ["--check", lean4FilePath],
  { cwd: workspacePath, timeout: LEAN4_TIMEOUT_MS }
);
```

`LEAN4_TIMEOUT_MS` defaults to 60 000 (60 s). The `LEAN4_VERIFY` environment
variable gates the entire phase:

```typescript
if (process.env.LEAN4_VERIFY !== "1") {
  logger.info("LEAN4_VERIFY not set — skipping Lean 4 verification");
  return { passed: true, skipped: true };
}
if (!await leanInstalled()) {
  logger.warn("lean not found in PATH — skipping Lean 4 verification");
  return { passed: true, skipped: true };
}
```

---

## Full Upgrade Pipeline (with formal verification)

```
1. ailang check ${workspace}/swe/rpc.ail           ← type safety
2. ailang test ${workspace}/swe/parse.ail           ← inline tests
   ailang test ${workspace}/swe/parse_test.ail      ← property tests
   ailang test ${workspace}/swe/prompts_test.ail
   ailang test ${workspace}/swe/agents_md.ail
3. ailang ai-check --verify ${workspace}/swe/agents_md.ail   ← Z3 (Tier 1)
4. dafny verify ${workspace}/swe/dafny/parse_spec.dfy        ← Dafny (Phase 1, Tier 2)
   dafny verify ${workspace}/swe/dafny/agents_md_spec.dfy
5. lean --check ${workspace}/swe/lean4/parse_spec.lean       ← Lean 4 (Phase 2, Tier 3)
   lean --check ${workspace}/swe/lean4/prompts_spec.lean
6. probe_main smoke test
7. swap
```

Gates 1–3 are hard failures (candidate rejected).
Gates 4–5 are advisory during research phase (budget exhaustion → warning, not rejection).
Gate 6 is a hard failure.

---

## What success looks like

A brain upgrade that passes Phases 1 and 2 has done something remarkable: it has not
only modified its own source code but also produced machine-checked evidence — at two
independent levels of rigour — that the new code satisfies the same behavioural
contracts as the old code. Both the Dafny and Lean 4 artefacts are stored in
`swe/dafny/` and `swe/lean4/` alongside the implementation, constituting a formal
record of what the brain believes its own functions do.

This is qualitatively different from all other test layers. Inline tests say "it
works on these inputs". Properties say "it works on 100 random inputs". Z3 says
"this simple invariant holds for all inputs". Dafny says "this postcondition holds
and here is a counterexample if it doesn't". Lean 4 says "this behavioural contract
holds, and here is a proof you can check independently of the brain that generated it".
