# Lean 4 Eval Guide

Use `language:"lean"` when you want Lean to check a proposition or theorem.
Use named `theorem` or `lemma` declarations when you need a machine-auditable proof verdict:

```lean
theorem add_comm_named (a b : Nat) : a + b = b + a := by
  omega
```

Lean 4 basics:

- A proof usually has the shape `theorem name : proposition := by ...`.
- Common tactics: `rfl`, `simp`, `omega`, `decide`, `exact`, `apply`, `intro`, `constructor`, `cases`, `induction`.
- Tactic blocks are Lean 4 syntax, not Lean 3 syntax. Prefer `by` blocks and avoid old Lean 3 tactic punctuation.
- Use `example` only for quick elaboration checks. Anonymous examples cannot be audited with `#print axioms`, so they never receive a full `verified` verdict.
- Do not use `sorry`, `admit`, custom `axiom`, or `native_decide` if you need a verified proof. They are reported as `sorry` or `axiom_tainted`, not proved.
- A Lean result is proved only when `metadata.lean.proof` is exactly `verified`.

`#eval` runs real Lean code. `#eval (e : IO α)` can read/write files and spawn processes, so treat it as execution, not pure proof checking.
