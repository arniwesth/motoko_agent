#!/usr/bin/env bash
# scripts/dst/run_declared_vs_performed.sh
#
# WI-C5's declared-versus-performed detector, out-of-process half.
# WI-D6 extended it from ONE binding of `on_budget_plan` to all FIFTEEN, and
# added a third producer because the second one has a blind spot the first
# fifteen subjects walked straight into.
#
# S16 requires the sides of a check to come from different producers and
# requires them NAMED at the site. There are now three:
#
#   DECLARED   grep of the effect row in packages/motoko-ext-abi/types.ail and
#              at every binding site. A static annotation a human wrote.
#              Produced HERE, in this shell, from source text.
#
#   PERFORMED  the exit status of `ailang run --caps <row minus X>` against
#   (runtime)  scripts/dst/declared_vs_performed.ail. The AILANG interpreter
#              traps a capability only when an effect operation is actually
#              evaluated, so a completed run witnesses that the operation was
#              not evaluated. Produced by the RUNTIME, in a separate process.
#              A WITNESS OVER THE PATH THE ARM EXERCISES — not a proof.
#
#   PERFORMED  the exit status of `ailang check` over a binding carrying the
#   (static)   narrowed row. The effect checker rejects a body that performs
#              more than its row admits, over ALL inputs. Produced by the
#              COMPILER. Added at WI-D6, and it is what settles the EIGHT
#              subjects the runtime producer cannot reach — see THE CONFOUND.
#
# No two of them derive from each other: the annotation is what a human wrote,
# the trap is what the interpreter did, the rejection is what the type checker
# inferred from the body.
#
# ============================================================================
# THE CONFOUND, and why every runtime subject is a PAIR of arms
# ============================================================================
#
# `register_with_config` is not effect-free for most extension packages: nine
# of fifteen read `Env` at registration (a `getEnvOr` for a workdir or profile
# directory) and seven of those also read `FS` (a config file, or a portability
# gate probing for a marker file). Those reads happen BEFORE any hook is
# dispatched.
#
# So the naive arm — install, dispatch, capability withheld — dies for nine of
# fifteen subjects, and every one of those deaths would be scored as "the hook
# performs Env". That is a FALSE POSITIVE in the direction that blocks the
# narrowing, and nothing in the exit status distinguishes it from the real
# thing.
#
# Hence the differential. Each extension has TWO arms run under the SAME
# withheld capabilities, and the runner reads the PAIR:
#
#   reg completes, budget completes  -> the HOOK performs neither. MEASURED.
#   reg completes, budget dies       -> the HOOK performs it.      BLOCKING.
#   reg dies                         -> registration performed it first; the
#                                       hook was never reached.    CONFOUNDED.
#
# THE PAIR DISCIPLINE for the vacuity controls is C5's and is unchanged: a
# subject completing with a capability withheld is meaningless unless the
# withholding is demonstrably real, so the control must die WITH THE NAMED
# CAPABILITY in its error. A control that dies for an unrelated reason would
# make the subject's completion read as evidence when it is noise. WI-D6 hit
# exactly that while building the compile-time control: the first mutant failed
# on `undefined variable: getEnvOr` rather than on the effect row, and would
# have certified nothing.

set -euo pipefail

cd "$(dirname "$0")/../.."

PROBE=scripts/dst/declared_vs_performed.ail
ABI=packages/motoko-ext-abi/types.ail
COMPOSE=packages/motoko-ext-compose/compose.ail
GENREG=src/core/ext/registry_generated.ail
MUTANT=scripts/dst/.dvp_mutant_probe.ail

# The mutant is generated, checked and deleted inside this run. The trap is not
# decoration: a mutant left in the tree would be a permanently-red file in the
# whole-tree sweep, whose failing set is pinned member-for-member by S13.
cleanup() { rm -f "$MUTANT"; }
trap cleanup EXIT

# Everything except Env, FS and Process. Those three are the capabilities under
# test; the rest are granted so that a death is attributable to one of them.
WITHHELD_CAPS=IO,AI,Net,SharedMem,Clock,Stream,Trace,Rand
# Env granted, FS and Process withheld. Isolates the FS axis for the subjects
# whose REGISTRATION reads Env but not FS — recovers `test_dummy` and
# `scratchpad`, which the primary regime can only report as confounded.
FS_ONLY_CAPS=IO,AI,Net,SharedMem,Clock,Stream,Trace,Rand,Env

# The fifteen extensions the host can install, in registry_generated order.
EXTS="test_dummy omnigraph context_mode mcp exa_search ailang_docs compose a2a
      decision_framework microrag compaction_ai scratchpad compaction_structural
      empty_stop_guard progress_contract_guard"

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }

run_arm() {
  AILANG_RELAX_MODULES=1 ailang run --caps "$2" --entry "$1" "$PROBE" </dev/null 2>&1
}

echo "declared_vs_performed — D5's missing detector (WI-C5), all fifteen bindings (WI-D6)"
echo ""
echo "-- producer 1: DECLARED, read from source --"

# The ABI row for on_budget_plan. WI-D6 NARROWED it from the closed `! {Env, FS}`
# that blocked every install in the tree to no row at all. The gate reads the
# row rather than trusting a comment about it, and it asserts the NEW state:
# a re-widening must turn this red rather than pass quietly.
abi_row=$(grep -n 'on_budget_plan: (ExtCtx, BudgetPlan)' "$ABI" || true)
if [ -z "$abi_row" ]; then
  bad "on_budget_plan's ABI row not found in $ABI — the detector's declared side has no producer"
else
  echo "      $ABI:$(echo "$abi_row" | cut -d: -f1)  $(echo "$abi_row" | cut -d: -f2- | sed 's/^ *//')"
  if echo "$abi_row" | grep -q '!'; then
    bad "the ABI row carries an effect row again — WI-D6 narrowed it to none, and D5 criterion 1 fails the moment it comes back"
  else
    ok "ABI declares on_budget_plan effect-free (WI-D6 narrowed it; was the closed ! {Env, FS} through WI-D5)"
  fi
fi

# Every binding must MATCH the ABI row exactly — closed-row equality on a record
# field admits exactly one width, which WI-D6 measured directly:
#   incompatible closed rows: r1 has extra labels [], r2 has extra labels [Env FS]
# So a single site left at the old row fails to compile, and a site that grows
# one back fails the same way. This row asserts the grep agrees with that.
#
# SCOPED TO SOURCE. `.packages/` is the resolved tree `make sync_packages`
# writes and `./ailang/` is a git-ignored clone of the compiler — both are
# build output, and asserting an ABI property over a cache reports staleness as
# a conformance failure. Measured while building this row: the unscoped version
# went red on five rows in a `.packages/` copy that was two days old, which is a
# real defect but not this gate's.
stale=$(grep -rn 'BudgetPatch ! {' --include=*.ail . \
        --exclude-dir=.packages --exclude-dir=ailang --exclude-dir=.git || true)
if [ -z "$stale" ]; then
  ok "no binding site in the tree declares an effect row on a BudgetPatch-returning hook (all 48 former sites narrowed)"
else
  bad "$(echo "$stale" | wc -l) binding site(s) still declare an effect row on on_budget_plan:
$(echo "$stale" | head -5)"
fi

compose_row=$(grep -n 'func budget_hook' "$COMPOSE" || true)
if [ -z "$compose_row" ]; then
  bad "compose's budget_hook not found in $COMPOSE"
else
  echo "      $COMPOSE:$(echo "$compose_row" | cut -d: -f1)  $(echo "$compose_row" | cut -d: -f2- | sed 's/^ *//')"
  if echo "$compose_row" | grep -q '!'; then
    bad "compose's budget_hook row has drifted from the ABI row"
  else
    ok "compose's binding declares the same (empty) row as the ABI slot"
  fi
fi

# THE SUBJECT LIST IS NOT HAND-WRITTEN. WI-D6's handoff named eight extensions
# binding this slot; the tree has fifteen, and the six it missed are exactly the
# ones a reader would skip. So the list is derived from the host's own generated
# registry and compared member for member — an extension added to the host
# cannot escape measurement by not being noticed.
# `[a-z0-9_]` rather than `[a-z_]`: the first version of this row truncated
# `register_a2a` to `a` and reported a disagreement that did not exist. A
# character class is a claim about the data too.
reg_names=$(grep -o 'register_with_config as register_[a-z0-9_]*' "$GENREG" \
            | sed 's/.*as register_//' | sort)
arm_names=$(echo $EXTS | tr ' ' '\n' | sort)
if [ "$reg_names" == "$arm_names" ]; then
  ok "the subject list equals $GENREG's install set member for member ($(echo "$arm_names" | wc -l) extensions)"
else
  bad "the subject list and the host's generated registry DISAGREE — an installable extension is unmeasured:
$(diff <(echo "$reg_names") <(echo "$arm_names") | head -10)"
fi

echo ""
echo "-- producer 2: PERFORMED, observed out of process (runtime capability trap) --"
echo "   compose's four slots, WI-C5's original subjects:"

# Subjects: must COMPLETE, and must print the WITNESS their dispatch produced.
#
# FOUND BY MUTATION. An earlier version asserted only a fixed completion marker,
# and an arm with its dispatch DELETED — a program measuring nothing at all —
# passed nine of nine rows. The marker's producer was the arm's own code. Each
# expected value below can only be obtained by running the fold past compose's
# hook, so the assertion is on the dispatch rather than on the arm.
check_subject() {
  local arm=$1 expect=$2 why=$3
  if out=$(run_arm "$arm" "$WITHHELD_CAPS"); then
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
echo "   all fifteen on_budget_plan bindings, register-vs-dispatch differential:"
echo "      regime A = Env, FS, Process withheld     regime B = FS, Process withheld (Env granted)"

# Counted as SETS of extension names rather than as row tallies. The first
# version incremented a counter per row and reported "7 measured, 18
# confounded" over fifteen subjects — regime B re-counts what regime A could
# not reach, so the confounded total exceeded the population. A count that can
# exceed its own denominator is not a measurement.
measured_set=""
confounded_set=""
blocking=0

# The differential. `reg_<ext>` and `budget_<ext>` differ by EXACTLY the
# dispatch, so the pair attributes a death to registration or to the hook. The
# `budget_` arm's witness (4242) comes from a hook registered AFTER the subject
# in the same unconditional ordered fold, so it is unobtainable unless the
# subject's own `on_budget_plan` ran first.
classify_ext() {
  local ext=$1 caps=$2 label=$3
  local rout bout rrc brc
  rout=$(run_arm "reg_$ext" "$caps") && rrc=0 || rrc=1
  bout=$(run_arm "budget_$ext" "$caps") && brc=0 || brc=1

  if [ "$rrc" -ne 0 ]; then
    local cap
    cap=$(echo "$rout" | grep -o "effect '[A-Za-z]*' requires capability" | head -1 | cut -d"'" -f2)
    echo "      ~ $ext [$label]: CONFOUNDED — register_with_config performs '$cap' before the hook is reached"
    case " $confounded_set " in *" $ext "*) ;; *) confounded_set="$confounded_set $ext" ;; esac
    return
  fi
  if [ "$brc" -ne 0 ]; then
    local cap
    cap=$(echo "$bout" | grep -o "effect '[A-Za-z]*' requires capability" | head -1 | cut -d"'" -f2)
    bad "$ext [$label]: BLOCKING — registration completed but the DISPATCH died on '$cap', so this hook genuinely performs it"
    blocking=$((blocking+1))
    return
  fi
  if echo "$bout" | grep -q "declared_vs_performed\[budget_$ext\] REACHED COMPLETION witness=4242"; then
    echo "      ✓ $ext [$label]: MEASURED — registration and dispatch both completed; the hook performs neither"
    case " $measured_set " in *" $ext "*) ;; *) measured_set="$measured_set $ext" ;; esac
    confounded_set=$(echo " $confounded_set " | sed "s/ $ext / /g" | xargs || true)
  else
    bad "$ext [$label]: exited 0 but the witness is not 4242 — the fold did not run past $ext, so this row measures nothing"
  fi
}

for e in $EXTS; do classify_ext "$e" "$WITHHELD_CAPS" "A"; done
echo "      -- regime B, re-running only what regime A could not reach --"
for e in $EXTS; do
  # Only the subjects regime A confounded are worth re-running; a subject it
  # measured is already settled on both capabilities.
  if run_arm "reg_$e" "$WITHHELD_CAPS" >/dev/null 2>&1; then continue; fi
  classify_ext "$e" "$FS_ONLY_CAPS" "B"
done

# THE ASSERTION THAT MATTERS, and it is about BLOCKING rather than about
# MEASURED. A confounded subject is an admission that this producer cannot see
# it; a blocking subject is a conformance fact that refutes the narrowed row.
n_measured=$(echo $measured_set | wc -w)
n_confounded=$(echo $confounded_set | wc -w)
if [ "$blocking" -eq 0 ]; then
  ok "no binding is BLOCKING: across both regimes not one dispatch died on Env or FS"
  echo "      MEASURED   ($n_measured/15): $(echo $measured_set)"
  echo "      CONFOUNDED ($n_confounded/15): $(echo $confounded_set)"
  echo "      compose is confounded through its register WRAPPER (which reads Env) and"
  echo "      MEASURED separately by compose_budget above, which takes a literal config."
  echo "      The $n_confounded confounded subjects are settled by producer 3 below, not by this one."
else
  bad "$blocking binding(s) genuinely perform Env or FS in on_budget_plan — the narrowed ABI row is WRONG and must be re-widened or the extension excluded"
fi

echo ""
echo "-- the vacuity controls: dispatched hooks whose bodies PERFORM --"

must_die_on() {
  local arm=$1 capability=$2 why_complete=$3 why_died=$4
  if out=$(run_arm "$arm" "$WITHHELD_CAPS"); then
    bad "$arm COMPLETED — $why_complete"
  elif echo "$out" | grep -q "effect '$capability' requires capability"; then
    ok "$arm died on '$capability' — $why_died"
  else
    bad "$arm died, but NOT on '$capability' — it fails for an unrelated reason and establishes nothing"
  fi
}

# WI-D6 MOVED THESE FROM `on_budget_plan` TO `on_pre_step`. Not a weakening — a
# consequence of the result: the narrowed row makes a performing body in this
# slot UNWRITABLE, so the compiler rejected both controls where they stood. The
# control they used to provide is promoted to producer 3 below.
must_die_on control_env Env \
  "the Env capability is not actually withheld, so every subject row above is vacuous" \
  "the withholding is real and the subjects reached a dispatched hook"
must_die_on control_fs FS \
  "the FS capability is not actually withheld, so every subject row above is vacuous" \
  "the withholding is real and the subjects reached a dispatched hook"

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
echo "-- producer 3: PERFORMED, inferred by the compiler (total over inputs) --"

# THE CONTROL THAT MUST DIE, for the producer that settles the ten confounded
# subjects. Producer 2 is a witness over one path; the effect checker is a
# proof over all of them, and it is the only reason this gate can say anything
# at all about `mcp`, `a2a`, `omnigraph`, `context_mode`, `exa_search`,
# `ailang_docs` and `compaction_ai`, whose registrations read Env and FS before
# any hook runs.
#
# It is asserted TWO-SIDED. The mutant must be REJECTED with the narrowed row
# AND ACCEPTED with a widened one — otherwise a rejection caused by anything
# else in the file (a typo, a missing import) would read as the effect checker
# doing its job. WI-D6's first attempt failed exactly that way, on
# `undefined variable: getEnvOr`.
write_mutant() {
  cat > "$MUTANT" <<EOF
module scripts/dst/dvp_mutant_probe
import std/env (getEnvOr)
import std/option (Option, Some, None)
import pkg/sunholo/motoko_ext_abi/types (ExtCtx, BudgetPlan, BudgetPatch)
export func mutant_budget(_ctx: ExtCtx, _plan: BudgetPlan) -> BudgetPatch$1 {
  let _ = getEnvOr("PATH", "");
  { requested_total: None, requested_solver: None, requested_verifier: None }
}
EOF
}

write_mutant ""
if mout=$(AILANG_RELAX_MODULES=1 ailang check "$MUTANT" 2>&1); then
  bad "a body performing Env under the NARROWED row was ACCEPTED — the row is decorative and every 'MEASURED' row above rests on nothing"
elif echo "$mout" | grep -q "Effect checking failed for function 'mutant_budget'"; then
  ok "mutant REJECTED by the effect checker: a body performing Env cannot carry the narrowed row"
else
  bad "the mutant was rejected, but NOT by effect checking — it fails for an unrelated reason and establishes nothing: $(echo "$mout" | grep -E '^Error' | head -1)"
fi

write_mutant " ! {Env}"
if AILANG_RELAX_MODULES=1 ailang check "$MUTANT" >/dev/null 2>&1; then
  ok "the SAME mutant with the row WIDENED to ! {Env} is accepted — so the rejection above is caused by the row, not by the file"
else
  bad "the widened mutant is also rejected — the negative result above is not attributable to the effect row"
fi
cleanup

echo ""
echo "-- the three producers compared --"
echo "      DECLARED  on_budget_plan : ! {}   (ABI row, static, authored — WI-D6 narrowed it)"
echo "      PERFORMED on_budget_plan : ! {}   (runtime trap, out of process, $n_measured of 15 witnessed)"
echo "      PERFORMED on_budget_plan : ! {}   (effect checker, all 15 bindings, total over inputs)"
echo "      Through WI-D5 the declared row was the closed ! {Env, FS} and the gap"
echo "      between it and the behaviour was the sole reason no extension in the"
echo "      tree was installable in a conformant profile. WI-D6 closed the gap by"
echo "      moving the DECLARATION to the measurement, per D5's own verdict that"
echo "      the barrier was 'the rule, not the behaviour'."
echo ""
echo "      WHAT THIS DOES NOT LICENSE — AND IT IS THE SENTENCE D5 MADE MANDATORY:"
echo "      the axis's extension-model coverage is still ZERO. driver_only installs"
echo "      no extension. What changed is that the empty install list is no longer"
echo "      FORCED — it is now CHOSEN — and a chosen emptiness covers exactly as"
echo "      much as a forced one. Coverage needs a profile that installs something,"
echo "      which is WI-C5 and is not this item."

echo ""
if [ "$fail" -ne 0 ]; then
  echo "declared_vs_performed: $pass passed, $fail FAILED"
  exit 1
fi
echo "declared_vs_performed: $pass passed, 0 failed"
