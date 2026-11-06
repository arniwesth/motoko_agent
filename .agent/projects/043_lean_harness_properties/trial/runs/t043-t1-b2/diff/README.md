# diff/ — step (2) for HerdrGateModel.lean

- `run_seed43.log` / `run_seed43/`: `./run_diff.sh --mutants 43 run_seed43`. Exit 0.
  `ts.out`, `ail.out` and `lean.out` (gzipped) are the real TS, real AILANG and model outputs,
  one line per triple. `ts.mut` and `ail.mut` are the planted mutants. `axioms.txt` is the non-eval
  output of the model run. `ail.err` holds ailang's notices.
- `run_chain_seed43.log` / `chain_seed43/`: `./run_chain.sh 43 240 chain_seed43`. Exit 0.
  `chain_ts.out` is the real host (gate and forwarded HERDR_*), `chain_lean.out` is the model,
  `chain_ail.out` is the real `register_with_config` on the 240 sampled forwarded triples, and
  `chain_lean.reg` is the model's `registerGate` per forwarded triple.
- Value i in every line is `alphabet.json[i]`; `u` is unset.

Copies, derived files and duplicates (`*.raw`, the mutant package copies, the concatenated
`.lean` inputs) were deleted after the runs, to save space. Re-running the scripts recreates them.
