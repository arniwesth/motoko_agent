#!/usr/bin/env bash
# scripts/dst/run_declared_vs_performed.sh
#
# WI-C5's declared-versus-performed detector, out-of-process half.
#
# S16 requires the two sides of a check to come from different producers and
# requires them NAMED at the site. They are:
#
#   DECLARED   grep of the effect row in packages/motoko-ext-abi/types.ail and
#              packages/motoko-ext-compose/compose.ail. A static annotation a
#              human wrote. Produced HERE, in this shell, from source text.
#
#   PERFORMED  the exit status of `ailang run --caps <row minus X>` against
#              scripts/dst/declared_vs_performed.ail. The AILANG interpreter
#              traps a capability only when an effect operation is actually
#              evaluated, so a completed run witnesses that the operation was
#              not evaluated. Produced by the RUNTIME, in a separate process.
#
# Neither derives from the other, which is the whole point: WI-C3's in-process
# parity gate stayed green through the exact defect it existed to find because
# both of its sides came from one channel.
#
# THE PAIR DISCIPLINE. A subject completing with a capability withheld is
# meaningless unless the withholding is demonstrably real, so every capability
# is measured by a subject AND a control, and the control must die WITH THE
# NAMED CAPABILITY in its error. A control that dies for an unrelated reason
# would make the subject's completion read as evidence when it is noise.
#
# This gate never runs any arm with the capability under test granted, with one
# deliberate exception noted at `compose_intercept_inline` below.

set -euo pipefail

cd "$(dirname "$0")/../.."

PROBE=scripts/dst/declared_vs_performed.ail
ABI=packages/motoko-ext-abi/types.ail
COMPOSE=packages/motoko-ext-compose/compose.ail

# Everything except Env, FS and Process. Those three are the capabilities under
# test; the rest are granted so that a death is attributable to one of them.
WITHHELD_CAPS=IO,AI,Net,SharedMem,Clock,Stream,Trace,Rand

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }

run_arm() {
  AILANG_RELAX_MODULES=1 ailang run --caps "$WITHHELD_CAPS" --entry "$1" "$PROBE" </dev/null 2>&1
}

echo "declared_vs_performed — D5's missing detector, first build (WI-C5)"
echo ""
echo "-- producer 1: DECLARED, read from source --"

# The ABI row for on_budget_plan. This is the row that blocks every install in
# the tree, so the gate reads it rather than trusting a comment about it.
abi_row=$(grep -n 'on_budget_plan: (ExtCtx, BudgetPlan)' "$ABI" || true)
if [ -z "$abi_row" ]; then
  bad "on_budget_plan's ABI row not found in $ABI — the detector's declared side has no producer"
else
  echo "      $ABI:$(echo "$abi_row" | cut -d: -f1)  $(echo "$abi_row" | cut -d: -f2- | sed 's/^ *//')"
  if echo "$abi_row" | grep -q 'Env' && echo "$abi_row" | grep -q 'FS'; then
    ok "ABI declares on_budget_plan performs {Env, FS}"
  else
    bad "the ABI row no longer declares Env and FS — this gate's claim is stale, re-derive it"
  fi
fi

compose_row=$(grep -n 'func budget_hook' "$COMPOSE" || true)
if [ -z "$compose_row" ]; then
  bad "compose's budget_hook not found in $COMPOSE"
else
  echo "      $COMPOSE:$(echo "$compose_row" | cut -d: -f1)  $(echo "$compose_row" | cut -d: -f2- | sed 's/^ *//')"
  if echo "$compose_row" | grep -q 'Env' && echo "$compose_row" | grep -q 'FS'; then
    ok "compose's binding declares the same closed row {Env, FS}"
  else
    bad "compose's budget_hook row has drifted from the ABI row"
  fi
fi

echo ""
echo "-- producer 2: PERFORMED, observed out of process (Env, FS, Process withheld) --"

# Subjects: must COMPLETE, and must print the WITNESS their dispatch produced.
#
# FOUND BY MUTATION. An earlier version asserted only a fixed completion marker,
# and an arm with its dispatch DELETED — a program measuring nothing at all —
# passed nine of nine rows. The marker's producer was the arm's own code. Each
# expected value below can only be obtained by running the fold past compose's
# hook, so the assertion is on the dispatch rather than on the arm.
check_subject() {
  local arm=$1 expect=$2 why=$3
  if out=$(run_arm "$arm"); then
    if echo "$out" | grep -q "declared_vs_performed\[$arm\] REACHED COMPLETION witness=$expect"; then
      ok "$arm completed with Env, FS and Process withheld — it performs none of them ($why)"
    else
      bad "$arm exited 0 but its witness is not '$expect' — the fold did not run past compose, so this row measures nothing: $(echo "$out" | grep REACHED || echo '<no marker at all>')"
    fi
  else
    bad "$arm died with Env, FS and Process withheld — it performs one of them"
  fi
}

# ONE of these four rows names compose; the other three cannot, and mutation
# established which is which rather than leaving it to be assumed.
#
# MEASURED: removing compose from the shared registry constructor reddens
# `compose_pre_step` ONLY. The other three stay green, because compose's binding
# for those three slots is a CONSTANT NO-OP and a no-op is unobservable in a
# dispatch result by definition. That is inherent to the subject, not a defect
# in the gate — but it means those three rows establish "the fold ran and
# performed nothing", NOT "compose ran and performed nothing".
#
# The two are joined by `compose_pre_step` plus the structural row below: all
# four arms build their registry from the SAME constructor, so an arm set that
# has lost compose cannot leave `compose_pre_step` green.
check_subject compose_pre_step  "compose+dvp_witness" \
  "PreStepChainResult.stages names compose by ext_id — the ONLY arm of the four that does"
check_subject compose_budget    "4242" \
  "the witness's requested_total survived the fold; compose's participation rests on the row above"
check_subject compose_solver    "dvp-solver-witness" \
  "the witness's Accept was collected; compose's participation rests on the row above"
check_subject compose_intercept_noninline "dvp-intercept-witness" \
  "first_intercept recursed PAST compose, which means compose returned NoIntercept without performing"

# The structural join. `compose_pre_step` certifies compose is in the registry
# it was handed; this certifies the other three arms are handed the SAME one.
# Without it, an edit could point one arm at a compose-free registry and only a
# reader would notice.
arms_using_shared_ctor=$(grep -c 'compose_then_witness(' "$PROBE" || true)
# 1 definition + 5 call sites (four subjects and the inline limit arm).
if [ "$arms_using_shared_ctor" -eq 6 ]; then
  ok "all five dispatching arms build their registry from compose_then_witness — the join holds"
else
  bad "expected 6 mentions of compose_then_witness (1 definition + 5 arms), found $arms_using_shared_ctor — an arm may be pointed at a registry compose_pre_step does not certify"
fi

echo ""
echo "-- the vacuity controls: same slot, same fold, same declared row, bodies that PERFORM --"

must_die_on() {
  local arm=$1 capability=$2 why_complete=$3 why_died=$4
  if out=$(run_arm "$arm"); then
    bad "$arm COMPLETED — $why_complete"
  elif echo "$out" | grep -q "effect '$capability' requires capability"; then
    ok "$arm died on '$capability' — $why_died"
  else
    bad "$arm died, but NOT on '$capability' — it fails for an unrelated reason and establishes nothing"
  fi
}

must_die_on control_env Env \
  "the Env capability is not actually withheld, so every subject row above is vacuous" \
  "the withholding is real and the subjects reached the hook"
must_die_on control_fs FS \
  "the FS capability is not actually withheld, so every subject row above is vacuous" \
  "the withholding is real and the subjects reached the hook"

echo ""
echo "-- the limit, made executable: performed is a property of a hook AND ITS INPUTS --"

# The SAME hook and the SAME declared row as compose_intercept_noninline above,
# differing only in `mode` and in the response carrying an AILANG fence. It
# reaches mkdirAll/writeFile and dies. Asserting this is what stops the
# non-inline row's green from being read as "on_response_intercept performs no
# FS", which is false.
must_die_on compose_intercept_inline FS \
  "the inline branch no longer reaches the filesystem — then the non-inline row above is a claim about the HOOK rather than about the hook and its input, and this gate is overstating what it measured" \
  "the SAME hook that completed above dies on a different input; performed is a property of a hook AND ITS INPUTS"

echo ""
echo "-- the two producers compared --"
echo "      DECLARED  on_budget_plan : ! {Env, FS}   (ABI row, static, authored)"
echo "      PERFORMED on_budget_plan : ! {}          (runtime, out of process, witnessed)"
echo "      The gap is real and it is the reason D5's declared-row rule blocks an"
echo "      install that the extension's behaviour does not require blocking."
echo ""
echo "      WHAT THIS DOES NOT LICENSE: the gap is a WITNESS over the paths these"
echo "      arms exercise, not a proof over all inputs — compose_intercept_inline"
echo "      above is the counterexample, in the same hook. Reclassifying a slot in"
echo "      a profile on this evidence is a D5 decision, not a consequence of this"
echo "      gate going green."

echo ""
if [ "$fail" -ne 0 ]; then
  echo "declared_vs_performed: $pass passed, $fail FAILED"
  exit 1
fi
echo "declared_vs_performed: $pass passed, 0 failed"
