# Population, fixed before enumeration

Base: `dd8a12f1` (see `base.txt`).

**The rule** (from the code's structure; no test, gate or coverage record was read to make it):

1. The run under judgement is one traced run. Every traced run goes through
   `session.run_v2_traced_from_seed`, so the candidates are the functions of `session.ail`,
   `recovery.ail`, `step_machine.ail` and `tool_phase.ail` that its call graph reaches. A function
   applied, or passed as a value, counts as a call. `scripts/population.py` computes the graph from
   the source text: 133 functions.
2. A candidate is in when it does at least one of:
   - **W, hands a world on.** It takes a `WorldState` (or the loop state or the ported provider,
     which carry one) and returns a value that carries the successor to the loop or out of the run.
   - **R, chooses a recovery.** It chooses the driver's response to an abnormal outcome: a failure,
     an exhausted budget or context, a retry, a suspension and its resume, an approval interruption,
     a refused tool call, a park and its wake, a judge's send-back.
3. Every other reachable function is out under one named class: message and event builders; trace,
   journal and wire plumbing; projection, digest, telemetry, cost and status helpers; the extension
   port layer; list and lookup utilities; tool routing that is neither a refusal nor a handoff.
   `population-accounting.tsv` gives each of the 133 its verdict and its class, and the script
   exits 1 if any is unaccounted for.

**The population**: the 31 functions in `population.tsv`. 22 in `session.ail`, 1 in
`recovery.ail`, 3 in `step_machine.ail`, 5 in `tool_phase.ail`. Sites are taken only inside a
function's body, so a signature, its effect row, its contract and its `tests [...]` are outside.

**Judgement calls in the rule, stated so they can be disputed:**

- Plumbing is out as a function, but every call to it from inside the population is a site of the
  record-removal shape of statement removal (`operators.md`).
- `c2_step_state`, `c2_final_state` and `c2_pending_context` are read by recovery arms and are
  excluded as projections: none chooses a response or hands a world on.
- `should_checkpoint` is out: a checkpoint is a policy under context pressure, not a response to an
  exhausted context; the `ContextExhausted` failure is in, through `call_model_or_fail`.
- `ext_ports_of` and `ext_ai_step` take and return worlds and are out as the extension port layer.
- `witness_drain` is out as plumbing; `witness`, which calls it and clears the pending list, is in.
- `wake_matches` and `apply_wake` are in; their list helpers (`has_wait_id`, `remove_wait_id`,
  `remove_timer_id`) are out as utilities.
