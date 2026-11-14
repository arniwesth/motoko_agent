-- Audit.lean -- what `#print axioms` says about the same proof by computation. Compare Audit.v.
-- `lean Audit.lean` with Lean 4.28.0.
theorem by_decide : 2 ^ 10 = 1024 := by decide
theorem by_native : 2 ^ 10 = 1024 := by native_decide
#print axioms by_decide
#print axioms by_native
