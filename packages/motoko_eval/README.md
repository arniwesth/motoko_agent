# motoko_eval

`motoko_eval` provides the `eval` extension for Motoko agent sessions.

It runs persistent evaluation cells in:

- `py` / `js` for scripting, data inspection, plotting, and quick calculations.
- `ail` for persistent AILANG snippets gated by `ailang check`, with optional Z3 contract verification.
- `lean` for persistent Lean 4 theorem proving through `leanprover-community/repl`, with proof honesty checks via `sorries[]` and `#print axioms`.

Lean cells report `metadata.lean.proof = "verified"` only when the cell elaborates, has no `sorry`, and all named theorem axioms are in the standard allowed set. AILANG cells report `metadata.ailang.verify = "verified"` only when Z3 proves the requested contracts.

## Lean Setup

Lean eval needs a built `leanprover-community/repl` checkout. The installer can prepare it:

```sh
./scripts/install-prerequisites.sh --with-lean
```

Mathlib is opt-in and heavier:

```sh
./scripts/install-prerequisites.sh --with-lean-mathlib
```

## Mixed Lean + AILANG Test Prompt

Use this prompt to verify that Lean and AILANG eval work in the same session:

```text
Use the eval tool in one session with both language:"lean" and language:"ail".

Goal: Lean proves a general mathematical fact; AILANG implements and verifies the corresponding executable step relation in Z3's linear arithmetic fragment.

1. Use a Lean cell with prove:"required" to prove a named theorem about arithmetic progression updates:

   theorem tri_step_identity (n t : Nat)
       (h : 2 * t = n * (n + 1)) :
       2 * (t + (n + 1)) = (n + 1) * ((n + 1) + 1) := by
     omega

   Report metadata.lean.proof and committed.

2. Use a second Lean cell with prove:"required" that uses tri_step_identity to prove a concrete step:

   theorem tri_step_10 :
       2 * (55 + 11) = 11 * (11 + 1) := by
     have h : 2 * 55 = 10 * (10 + 1) := by omega
     simpa using tri_step_identity 10 55 h

   Report metadata.lean.proof and committed.

3. Now use an AILANG cell with verify:"required" to implement the same step update over ints:

   tri_step(n, t) = t + (n + 1)

   Add contracts in linear arithmetic only:
   - requires { n >= 0 }
   - requires { t >= 0 }
   - ensures { result == t + n + 1 }
   - ensures { result >= t }
   - ensures { result >= 0 }

   Do not ask AILANG/Z3 to prove the nonlinear invariant
   2 * result == (n + 1) * ((n + 1) + 1). Lean proved that step identity.

4. Add an AILANG run cell that calls tri_step(10, 55), prints the result, and confirms it prints 66.

5. Summarize honestly:
   - Lean verified the nonlinear invariant-preservation theorem.
   - AILANG verified the executable step function's linear postconditions.
   - The AILANG execution produced 66 for the concrete step from n=10, t=55.
   - Include the exact fields:
     metadata.lean.elaborated, metadata.lean.proof, metadata.lean.committed,
     metadata.ailang.check, metadata.ailang.verify, metadata.ailang.committed,
     and the AILANG run stdout.
```
