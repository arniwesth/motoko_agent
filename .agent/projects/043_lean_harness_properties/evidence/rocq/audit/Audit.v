(* Audit.v -- what Rocq's `Print Assumptions` says about proofs by computation
   (NOTE-001-rocq-compared-2026-11-03.md, "The axiom audit"). Compare Audit.lean.
   `rocq compile Audit.v`. A Rocq built without the native compiler turns `native_compute`
   and `<<:` into the VM, with a warning, so those two lines test the VM again there. *)
From Stdlib Require Import Arith.
Theorem by_vm : 2 ^ 10 = 1024. Proof. vm_compute. reflexivity. Qed.
Theorem by_vm_cast : 2 ^ 10 = 1024. Proof. exact (eq_refl 1024 <: 2 ^ 10 = 1024). Qed.
Theorem by_native : 2 ^ 10 = 1024. Proof. native_compute. reflexivity. Qed.
Theorem by_native_cast : 2 ^ 10 = 1024. Proof. exact (eq_refl 1024 <<: 2 ^ 10 = 1024). Qed.
Theorem by_admit : 1 = 2. Proof. Admitted.
Print Assumptions by_vm.
Print Assumptions by_vm_cast.
Print Assumptions by_native.
Print Assumptions by_native_cast.
Print Assumptions by_admit.
