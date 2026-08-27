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

# THE SUBJECT LIST IS DERIVED, NOT WRITTEN (ADR-001 Phase A step A2). It is the
# host's own generated registry, in registry order, so an extension added to the
# host is a subject the moment `registry_generated.ail` names it. The hand list
# that stood here said fifteen after the tree had grown to seventeen, and this
# gate went red on STALENESS (agentcli, herdr unmeasured) rather than on a
# violation -- which is the right direction, and the reason the list is now read
# rather than kept. The probe's imports and arms are still hand-written, and the
# member-for-member row below is what holds THEM to this list.
# `[a-z0-9_]` rather than `[a-z_]`: the first version of this row truncated
# `register_a2a` to `a` and reported a disagreement that did not exist. A
# character class is a claim about the data too.
EXTS=$(grep -o 'register_with_config as register_[a-z0-9_]*' "$GENREG" \
       | sed 's/.*as register_//' | tr '\n' ' ')
N_EXTS=$(echo $EXTS | wc -w | tr -d ' ')

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }

run_arm() {
  AILANG_RELAX_MODULES=1 ailang run --caps "$2" --entry "$1" "$PROBE" </dev/null 2>&1
}

echo "declared_vs_performed — D5's missing detector (WI-C5), all $N_EXTS bindings (WI-D6; count read from $GENREG)"
echo ""
echo "-- producer 1: DECLARED, read from source --"

# The ABI row for on_budget_plan. WI-D6 NARROWED it from the closed `! {Env, FS}`
# that blocked every install in the tree to no row at all. The gate reads the
# row rather than trusting a comment about it, and it asserts the NEW state:
# a re-widening must turn this red rather than pass quietly.
# B8: the slot is the `BudgetShaper` payload of the 6.0 `Capability` sum.
abi_row=$(grep -n 'BudgetShaper((ExtCtx, BudgetPlan)' "$ABI" || true)
if [ -z "$abi_row" ]; then
  bad "BudgetShaper's payload row (was on_budget_plan's ABI row) not found in $ABI — the detector's declared side has no producer"
else
  echo "      $ABI:$(echo "$abi_row" | cut -d: -f1)  $(echo "$abi_row" | cut -d: -f2- | sed 's/^ *//')"
  if echo "$abi_row" | grep -q '!'; then
    bad "the ABI row carries an effect row again — WI-D6 narrowed it to none, and D5 criterion 1 fails the moment it comes back"
  else
    ok "ABI declares the BudgetShaper payload (on_budget_plan through 5.x) effect-free (WI-D6 narrowed it; was the closed ! {Env, FS} through WI-D5)"
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

# THE PROBE'S ARMS ARE HAND-WRITTEN AND THE SUBJECT LIST IS NOT. WI-D6's handoff
# named eight extensions binding this slot; the tree had fifteen, and the six it
# missed are exactly the ones a reader would skip. Then the tree grew to
# seventeen and the hand list here missed two more (agentcli, herdr) [ADR-001
# Phase A, A2]. So `EXTS` is now READ from the host's generated registry, and
# what this row compares member for member is the registry against the probe's
# own `reg_<ext>`/`budget_<ext>` arms -- the part that still has to be typed by
# hand, and therefore the part that can still drift. An extension the host can
# install with no arm in the probe is a subject this gate would otherwise skip
# in silence.
reg_names=$(echo $EXTS | tr ' ' '\n' | sort)
arm_names=$(grep -oE '^export func (reg|budget)_[a-z0-9_]+\(' "$PROBE" \
            | sed -E 's/^export func (reg|budget)_//; s/\($//' | sort | uniq -c \
            | awk '$1 == 2 { print $2 }')
if [ "$reg_names" == "$arm_names" ]; then
  ok "every extension in $GENREG's install set has a reg_/budget_ arm pair in $PROBE ($N_EXTS extensions, member for member)"
else
  bad "the host's generated registry and the probe's arm pairs DISAGREE — an installable extension is unmeasured:
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
# ITEM 4 (6.0 trimming, 2026-08-27): compose no longer registers a Compactor
# (nor a BudgetShaper or SolverJudge -- the constant no-ops were trimmed), so
# the pre-step fold skips it by construction and `stages` can no longer name
# it. The arm now prints the runtime's `loaded_extension_names` of the registry
# beside the stage list, so the row still reddens when compose leaves the
# constructor; compose_budget and compose_solver now measure the fold running
# THROUGH an entry that holds no atom of that kind, which is the 6.0 shape.
#
# The two are joined by `compose_pre_step` plus the structural row below: all
# four arms build their registry from the SAME constructor, so an arm set that
# has lost compose cannot leave `compose_pre_step` green.
check_subject compose_pre_step  "dvp_witness|installed=compose+dvp_witness" \
  "the stage list names the witness alone (compose registers no Compactor since item 4) and the registry names compose — the ONLY arm of the four that does"
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
# 1 definition + 7 call sites: four subjects, the inline limit arm, WI-D19's
# reachability arm and WI-D20's. It went 5 -> 6 when D19 added
# `compose_intercept_threading` and 6 -> 7 when D20 added
# `compose_tool_handle_threading`, which is the guard doing its job — a new arm
# has to be admitted here on purpose.
if [ "$arms_using_shared_ctor" -eq 8 ]; then
  ok "all seven dispatching arms build their registry from compose_then_witness — the join holds"
else
  bad "expected 7 mentions of compose_then_witness (1 definition + 6 arms), found $arms_using_shared_ctor — an arm may be pointed at a registry compose_pre_step does not certify"
fi

echo ""
echo "   all $N_EXTS on_budget_plan bindings, register-vs-dispatch differential:"
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
  echo "      MEASURED   ($n_measured/$N_EXTS): $(echo $measured_set)"
  echo "      CONFOUNDED ($n_confounded/$N_EXTS): $(echo $confounded_set)"
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
echo "-- WI-D26: the inline branch is FULLY mediated, and the row that used to prove otherwise --"

# THIS ROW INVERTED AT WI-D26, AND IT INVERTED ON SCHEDULE. Kept two-part per
# plan rule S15, because what stood here was a `must_die_on` and it is now a
# completion — a reader who found the old assertion in a diff and not its reason
# would be entitled to think the gate had been weakened to make an item pass.
#
# WHAT STOOD HERE, and why it stood: "The SAME hook and the SAME declared row as
# compose_intercept_noninline above, differing only in `mode` and in the response
# carrying an AILANG fence. It reaches a capability the other input never asks
# for, and dies. Asserting this is what stops the non-inline row's green from
# being read as a claim about the HOOK rather than about the hook AND ITS INPUT."
# The capability had already moved once — WI-D19 routed the five FS sites and the
# arm stopped dying on FS and started dying on Process. That block ended with a
# prediction:
#
#     "So this row is now also the standing witness for that unrouted seam: the
#      day `tool_handle` grows an exit code and compose routes through it, this arm
#      stops dying and says so."
#
# WI-D23 grew the exit code, WI-D26 routed the seam, and the arm stopped dying.
# The prediction is the reason this is a re-tensing rather than a repair: the row
# was built to detect exactly this event and it detected it, red, on the first
# run after the routing landed.
#
# WHAT REPLACES IT IS THE STRONGER CLAIM, not a weaker one. The old row asserted
# that ONE ambient capability was still reachable; this one asserts that NONE is.
# `compose_intercept_inline` runs under the base withheld set — Env, FS AND
# Process all withheld — and must COMPLETE. Every effect the inline branch
# performs now leaves through `ctx.ports`, whose bindings here are the constant
# `probe_*` stubs. That is what mediation is, measured from the outside, and it
# is the row that goes red if ANY of the six routed sites is put back.
#
# THE LESSON THE OLD ROW CARRIED IS NOW HOMELESS HERE, and that is reported
# rather than quietly dropped. "Performed is a property of a hook AND ITS INPUTS"
# needed a hook with two inputs and two different performed answers; compose's
# intercept no longer has two, because it no longer has one. The limit it made
# executable — that this detector witnesses exercised paths and not all inputs —
# is unchanged and is still stated in this file's header; what is gone is the
# executable demonstration of it. Finding a second home for that demonstration
# does not block the goal line's clause 1 or clause 2, so per the endgame scope
# rule it goes on the maintenance register rather than on the queue.
if out=$(run_arm compose_intercept_inline "$WITHHELD_CAPS"); then
  ok "compose_intercept_inline COMPLETES with Env, FS AND Process all withheld — the inline branch performs NO ambient effect; through WI-D25 this arm died on Process"
elif echo "$out" | grep -q "effect 'Process' requires capability"; then
  bad "compose_intercept_inline still dies on Process — a site WI-D26 claims to have routed is still ambient, and the routing is partial in a way the compiler will not report"
elif echo "$out" | grep -q "effect 'FS' requires capability"; then
  bad "compose_intercept_inline dies on FS — a site WI-D19 routed has been put back; the Process half may be fine and this arm cannot tell you, so read the FS-axis row below"
else
  bad "compose_intercept_inline died, but not on FS or Process — the row establishes nothing: $(echo "$out" | grep -E '^Error' | head -1)"
fi

# WI-D19's FS AXIS, KEPT AFTER WI-D26 SUBSUMED IT, and the reason is diagnostic
# rather than logical. The row above is strictly stronger — it withholds Process
# too — so this one cannot fail while that one passes. What it buys is
# DISCRIMINATION when both regress: the capability check above reports whichever
# ambient effect the branch reaches FIRST, so a Process-side regression masks an
# FS-side one entirely. Granting Process here puts the FS sites back in front of
# the compiler on their own. A gate that can only say "something went ambient" is
# a gate that costs an item to act on.
if out=$(run_arm compose_intercept_inline "$WITHHELD_CAPS,Process"); then
  ok "compose_intercept_inline COMPLETES with FS withheld and Process granted — the FS axis alone, isolated from the routed subprocess; before WI-D19 this arm died on FS"
elif echo "$out" | grep -q "effect 'FS' requires capability"; then
  bad "compose_intercept_inline still dies on FS — a site WI-D19 claims to have routed is still ambient, and the routing is partial in a way the compiler will not report"
else
  bad "compose_intercept_inline died, but not on FS — the row establishes nothing: $(echo "$out" | grep -E '^Error' | head -1)"
fi

echo ""
echo "-- WI-D20: the on_tool_handle spine, asserted separately (S24) --"

# WHY THIS EXPECTS TWO CLOCKS AND NOT SEVENTEEN SEAMS. `on_tool_handle` reaches
# its filesystem sites only THROUGH A MODEL CALL — `one_attempt` calls
# `callStreamResult`, which is ambient AI from `ai_compat` and not
# `ExtPorts.ai_step`, so `trace_ports` cannot stub it and the author returns
# nothing. What remains reachable in-process is the THREADING SPINE, and that is
# what this row pins: one `clock_now` at `handle_compose_tool`'s entry and one at
# the exhausted `run_attempts` (compose_cfg sets max_attempts: 1).
#
# IT PINS TWO LINKS AND NOT THREE, and the difference was MEASURED rather than
# assumed. `on_tool_handle` reverting to `next_state: ctx.world` empties this
# string; `handle_compose_tool` passing its own `w` instead of
# `started.next_state` shortens it to one clock. But `run_attempts` recursing on
# `w` rather than `w2` leaves it UNCHANGED — without a model `one_attempt` never
# reaches a routed seam, so the two worlds are identical and the row cannot tell
# them apart. See the probe for why no in-process fixture separates them.
#
# The full seventeen-site chain is graded where a model exists; what grades the
# DRIVER's half is discovery_dst's batch_handle_scenario.
D20_EXPECT='clock_now;clock_now;'
d20_out=$(run_arm compose_tool_handle_threading "IO,AI,Net,SharedMem,Clock,Stream,Trace,Rand,Env,FS,Process" || true)
d20_got=$(printf '%s\n' "$d20_out" | sed -n 's/^declared_vs_performed\[compose_tool_handle_threading\] REACHED COMPLETION witness=//p')
if [ "$d20_got" = "$D20_EXPECT" ]; then
  ok "on_tool_handle threaded its successor out of handle_compose_tool and back through the hook — two links, and the probe names the third one it CANNOT pin: $d20_got"
elif [ -z "$d20_got" ]; then
  bad "the on_tool_handle reachability arm produced no witness at all — the hook did not complete: $(printf '%s\n' "$d20_out" | grep -E '^Error' | head -1)"
elif [ "$d20_got" = ";" ]; then
  bad "the hook returned an EMPTY world token — the successor was dropped somewhere between handle_compose_tool and on_tool_handle (\`next_state: ctx.world\`), and it compiles clean"
else
  bad "the on_tool_handle spine changed: expected '$D20_EXPECT' got '$d20_got' — a SHORTER string means a wrapper record or the run_attempts recursion returned the world it was handed instead of the one it produced"
fi

echo ""
echo "-- WI-D19: reachability, asserted separately from every verdict above (S24) --"

# THE EXPECTED SEQUENCE IS WRITTEN OUT LITERALLY AND NOT DERIVED FROM THE RUN.
# A witness computed from the run is satisfied by a run that did nothing; this
# one is satisfied only by the five seams being called, in this order, on these
# path keys. See `compose_intercept_threading` for what each part pins.
#
# The clock is granted here and FS is not withheld, because this arm is not
# measuring a capability — it is measuring a VALUE, which is the one question
# `must_die_on` cannot ask.
D19_EXPECT='clock_now;dir_make(tmp);file_write(tmp/inline_7.ail);path_stat(tmp/inline_7.ail);file_remove(tmp/inline_7.ail);'
d19_out=$(run_arm compose_intercept_threading "IO,AI,Net,SharedMem,Clock,Stream,Trace,Rand,Env,FS,Process" || true)
d19_got=$(printf '%s\n' "$d19_out" | sed -n 's/^declared_vs_performed\[compose_intercept_threading\] REACHED COMPLETION witness=//p')
if [ "$d19_got" = "$D19_EXPECT" ]; then
  ok "on_response_intercept CALLED five ExtPorts seams in order and threaded every successor out: $d19_got"
elif [ -z "$d19_got" ]; then
  bad "the reachability arm produced no witness at all — the hook did not complete, so nothing above about routing is established: $(printf '%s\n' "$d19_out" | grep -E '^Error' | head -1)"
elif [ "$d19_got" = "" ] || [ "$d19_got" = ";" ]; then
  bad "the hook returned an EMPTY world token — either no seam was called, or the successor was dropped (\`next_state: ctx.world\`), and both compile clean"
else
  bad "the routed sequence changed: expected '$D19_EXPECT' got '$d19_got' — check the path keys (one spelling per path, WI-D18 §5), the clock source, and whether the fileExists guard still takes its removing arm"
fi

echo ""
echo "-- producer 3: PERFORMED, inferred by the compiler (total over inputs) --"

# THE CONTROL THAT MUST DIE, for the producer that settles the ten confounded
# subjects. Producer 2 is a witness over one path; the effect checker is a
# proof over all of them, and it is the only reason this gate can say anything
# at all about `mcp`, `a2a`, `omnigraph`, `context_mode`, `exa_search`,
# `ailang_docs` and `compaction_ai`, whose registrations read Env and FS before
# any hook runs.
#
# WHAT THIS PRODUCER IS, STATED PRECISELY (ADR-001 Phase B, B1; AR-codex
# correction 4). "The compiler enforces the row" is five different claims, and
# only the first of them is what this section measures:
#   (a) the compiler checks each NAMED function's body against ITS OWN declared
#       row -- `mutant_budget` below, and `mutant_register` after it, which
#       makes the same claim about `register_with_config`'s row (the row that
#       bounds every INLINE hook, see declared_vs_performed.ail's note);
#   (b) the compiler does NOT compare a function value against the capability
#       PAYLOAD row it is bound into -- measured by the CONSTRUCTOR-ARGUMENT
#       probe in the limitation section: a wide-rowed named function is
#       accepted into a narrower `K((..) -> T ! {row})`, and an unannotated
#       inline lambda is bounded only by the enclosing function;
#   (c) static transitive BODY reading -- `tools/ext_ambient_inventory/
#       hook_scope.py` (classifier 3, per atom from B2), which scans a
#       named binding rather than trusting its row;
#   (d) the runtime witnesses in producer 2 above -- one path each, never a
#       proof;
#   (e) coverage/atom exhaustion -- `src/core/dst_profile_coverage.ail` (B3),
#       which makes an unclassified atom a rejection rather than a gap.
# A green row here is claim (a) alone. Claims (b)-(e) are what the rest of this
# file and the two tools carry, and the 6.0 release criteria read: a named
# binding passes on (a)+(c); an inline lambda passes on the enclosing row plus
# (c); every same-kind atom is enumerated by (e) and read by (c); an atom (c)
# cannot parse is NOT certifiable and its extension is not installable.
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

# THE SECOND MUTANT (ADR-001 Phase B, B1), and it is about a DIFFERENT row.
# `mutant_budget` measures a named function's OWN row -- claim (a) for a
# binding written as a top-level function. But eight of the seventeen
# extensions bind their hooks INLINE, and for those the note at
# declared_vs_performed.ail:410-420 says the constraint is
# `register_with_config`'s row, not the slot's. That claim was made from one
# observation in `empty_stop_guard` and never had a control of its own. This
# is that control, two-sided on D6's discipline: an inline `on_pre_step`
# performing Env behind a `default_hooks` head must be REJECTED with
# `register_with_config` at its narrow row and ACCEPTED once that row admits
# Env -- and the rejection must NAME `register_with_config`, because a
# rejection at the lambda's own annotation would be a different claim (the one
# the constructor-argument probe below measures).
write_mutant_register() {
  cat > "$MUTANT" <<EOF
module scripts/dst/dvp_mutant_probe
import std/env (getEnvOr)
import pkg/sunholo/motoko_ext_abi/types (Capability, Compactor, ExtCtx, Msg, PreStepOutcome, PassThrough)
export func register_with_config(_cfg: a) -> [Capability]$1 {
  [Compactor(func(ctx: ExtCtx, _m: [Msg]) -> PreStepOutcome ! {AI, IO, Trace} { let _ = getEnvOr("PATH", ""); { decision: { PassThrough }, next_state: ctx.world } })]
}
EOF
}
# B8 RE-PINNED THIS PAIR. Through 5.x the widened control was ACCEPTED (the
# enclosing registration row absorbed an inline record-field lambda's Env).
# At 6.0 the atom sits in CONSTRUCTOR-ARGUMENT position of the IMPORTED sum,
# and an annotated inline lambda is checked against ITS OWN row there: the
# narrow case still fails at register_with_config, and the widened case now
# fails at the lambda's annotation instead of passing. Both measured on
# v0.33.0 at B8; the IMPORTED-SUM rows below carry the full table.
write_mutant_register ""
if mout=$(AILANG_RELAX_MODULES=1 ailang check "$MUTANT" 2>&1); then
  bad "mutant_register: an inline Compactor performing Env was ACCEPTED under a rowless register_with_config — the registration row is decorative and the absorption rows below measure nothing"
elif echo "$mout" | grep -q "Effect checking failed for function 'register_with_config'"; then
  ok "mutant_register: an inline Compactor atom performing Env is REJECTED at register_with_config's row — the enclosing registration row still bounds an inline binding at 6.0"
else
  bad "mutant_register: rejected, but NOT at register_with_config's row — it fails elsewhere and establishes nothing about the registration row: $(echo "$mout" | grep -E '^Error' | head -1)"
fi
write_mutant_register " ! {Env}"
if mout=$(AILANG_RELAX_MODULES=1 ailang check "$MUTANT" 2>&1); then
  bad "mutant_register: the SAME registration with its row WIDENED to ! {Env} is ACCEPTED — the 5.x absorption is back: an annotated inline atom's Env escaped its own payload row in constructor-argument position. Re-measure the IMPORTED-SUM rows below"
elif echo "$mout" | grep -q "uses effects not declared in its"; then
  ok "mutant_register: the SAME registration WIDENED to ! {Env} is STILL rejected, at the LAMBDA'S OWN annotation — at 6.0 an annotated inline atom is bounded by its declared payload row, not by the registration row (5.x: accepted; B8 re-pinned)"
else
  bad "mutant_register: the widened registration is rejected, but NOT at the lambda's annotation — the verdict moved and establishes nothing: $(echo "$mout" | grep -E '^Error' | head -1)"
fi
cleanup

echo ""
echo "-- WI-D7: the other THREE unconditionally-dispatched slots --"

# WI-D6 measured ONE of four unconditionally-dispatched slots and its report
# concluded that an extension had become installable. It had not. D5 forbids
# installing an extension with ANY unconditionally-dispatched hook excluded, so
# all four must be coverable, and the other three were never measured.
#
# WI-D7 measured them the same way D6 measured its own: narrow the row tree-wide
# and let the effect checker answer over ALL inputs, rather than witnessing one
# path with the capability trap. The trap cannot reach these at all — the same
# per-process capability confound documented above applies — so the compiler is
# not the third producer here, it is the ONLY one, and the rows below say so
# rather than implying a witness they do not have.
#
# THE RESULT, and it is the same shape three times: fourteen of fifteen bindings
# accept the empty row, and exactly ONE refuses. The refusing binding is named
# because C5's `must_die_on compose_intercept_inline FS` established the
# discipline — a slot's green is not a claim about the slot until the binding
# that would refuse it has been looked for and either found or ruled out.

# The ABI rows, asserted at the widths WI-D7 measured. Narrower would be a claim
# no binding supports; wider would be a row nothing performs. Either turns this
# red rather than passing quietly.
# B8: the slots are `Capability` payloads. `grep -A3` because ResponseInterceptor's
# row wraps onto the next line; the row is everything from `!` to the payload's
# closing `)`.
check_slot_row() {
  local slot=$1 want=$2 refuser=$3 effects=$4
  local kind got
  case "$slot" in
    on_pre_step) kind=Compactor ;;
    on_response_intercept) kind=ResponseInterceptor ;;
    on_solver_candidate) kind=SolverJudge ;;
    *) bad "check_slot_row: no 6.0 kind for slot $slot"; return ;;
  esac
  got=$(grep -A3 "^  | $kind(" "$ABI" | tr '\n' ' ' \
        | LC_ALL=C perl -ne 'print "$1\n" if /-> *[A-Za-z]+ *(! *\{[^}]*\})?/' | sed 's/ *$//')
  if [ "$got" = "$want" ]; then
    ok "$kind (was $slot) declares $want — the union of what its bindings perform (refused by $refuser: $effects)"
  else
    bad "$kind (was $slot) declares '$got', not '$want' — WI-D7 measured this row against all fifteen bindings; a change of width is a change of claim and must be re-measured, not inherited"
  fi
}
check_refuser() {
  local file=$1 fn=$2 want=$3
  # `--` because every one of these patterns begins with `->`, which grep would
  # otherwise read as an option.
  if grep -qF -- "$want" "$file"; then
    ok "$fn still declares $want — the binding that refuses its slot, named rather than left to a reader"
  else
    bad "$fn no longer declares $want in $file — if it narrowed, its SLOT can narrow too and the row above is now overstated; re-measure"
  fi
}
check_refuser packages/motoko-ext-compaction-ai/compaction_ai.ail compact_with_ai \
  "-> PreStepOutcome ! {AI, IO, Trace}"
check_refuser "$COMPOSE" compose.on_response_intercept \
  "-> ResponseInterceptOutcome ! {IO, Process, FS, Clock}"
check_refuser packages/motoko-ext-context-mode/context_mode.ail finalize_with_index \
  "-> FinalizeDecision ! {Process}"

# No binding site left at the pre-D7 nine-effect row. Closed-row equality means
# a stale site cannot compile, so this row is belt-and-braces for the SOURCE —
# but it is scoped to source deliberately: `.packages/` is build output and
# asserting an ABI property over it reports staleness as non-conformance, which
# is the defect WI-D6 found the first time it wrote a grep like this.
#
# SCOPED TO THE TWO RETURN TYPES, and the first version was not. Bare, the row
# also matches the conformance harness's scenario runners
# (`packages/motoko_ext_conformance/harness.ail`, `scripts/dst/conformance_selftest.ail`),
# which return `Result[(), ScenarioFailure]` and `int`. Those are CALLERS of the
# hooks, not bindings of them, and their nine-effect row is honest — it is
# justified by `on_pre_step`, which did not narrow. A grep whose claim is about
# hook bindings must not be able to match a hook caller.
stale=$(grep -rlE "(ResponseInterceptOutcome|FinalizeOutcome) ! \{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream\}" \
        --include=*.ail packages/ src/ scripts/ 2>/dev/null | grep -v '^\.packages/' || true)
if [ -z "$stale" ]; then
  ok "no source site binds an intercept or solver hook at the pre-D7 nine-effect row"
else
  bad "binding sites still at the nine-effect row, so the narrowing is partial: $stale"
fi

# ===========================================================================
# WI-D8: `ExtPorts.ai_step`'s ROW, MEASURED — and the two limitations that
# decide how much any of these narrowings is worth
# ===========================================================================
#
# Nothing before this item had ever measured `ExtPorts.ai_step`. WI-D7 took
# its row as given ("whose own port row is exactly those ten") and concluded
# from it that `on_pre_step`'s barrier is the row's VOCABULARY. The row was
# over-declared by seven effects.
#
# MEASURED FROM THE BODIES, not from the annotations: the port's entire effect
# demand comes from `session.ext_ai_step`, which calls `Ports.model_step` and
# nothing else, and the effect checker names its row when it is narrowed —
# `Effect checking failed for function 'ext_ai_step' … Missing effects: AI, IO,
# Trace`. Seven of the ten it declared — Process, FS, Env, Net, SharedMem,
# Clock, Stream — are effects `model_step` cannot produce.

# The port row, and the slot row it propagates to. Both asserted at the
# MEASURED width; both go red if anyone re-widens them without re-measuring.
if grep -qF -- "ai_step: (ExtWorld, string, [Msg]) -> AiStepOutcome ! {AI, IO, Trace}" "$ABI"; then
  ok "ExtPorts.ai_step declares ! {AI, IO, Trace} — the row Ports.model_step performs (WI-D8; was ten effects through WI-D7)"
else
  bad "ExtPorts.ai_step is no longer at its measured row ! {AI, IO, Trace}. It was measured from ext_ai_step's BODY, not from an annotation — re-measure before moving it"
fi
if grep -qF -- "Compactor((ExtCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace})" "$ABI"; then
  ok "Capability.Compactor (ExtensionHooks.on_pre_step through 5.x) declares ! {AI, IO, Trace} — the fixpoint of compaction_ai's chain once the port narrowed"
else
  bad "Capability.Compactor is no longer at ! {AI, IO, Trace}; re-measure the compaction_ai chain before moving it"
fi

# S22: DERIVE the site sets and assert the counts. The WI-D8 handoff said
# "eleven annotation sites"; deriving them found SEVENTEEN, and the first
# derivation written here MISSED THREE MORE because it classified a site by
# the return type named on the same line — which lambda-form bindings
# (`on_pre_step: \ctx _msgs. …  ! {…}`) do not name. Both undercounts are the
# reason this is computed rather than quoted.
derive_sites() {   # $1 = slot regex on the line, $2 = row
  grep -rlE "$1" --include=*.ail src/ scripts/ packages/ tools/ 2>/dev/null \
    | grep -v '^\.packages/' | grep -v '\.ailang' | sort -u
}
old_ten='\{(AI|IO|Process|FS|Env|Net|SharedMem|Clock|Stream|Trace)(, ?(AI|IO|Process|FS|Env|Net|SharedMem|Clock|Stream|Trace)){9}\}'
left=$(grep -rlE "(AiStepOutcome|PreStepOutcome|on_pre_step|ai_step).*! ?$old_ten" \
       --include=*.ail src/ scripts/ packages/ tools/ 2>/dev/null | grep -v '^\.packages/' || true)
if [ -z "$left" ]; then
  ok "no source site binds ai_step or on_pre_step at the pre-D8 ten-effect row (derived, not enumerated)"
else
  bad "sites still at the pre-D8 ten-effect row, so the WI-D8 narrowing is partial: $left"
fi

# THE TWO LIMITATIONS, each two-sided, because the value of every narrowing in
# this file depends on them and BOTH were read wrong on first contact.
#
# The first reading of limitation 1 was "a lambda's row is never checked",
# taken from a single `! {}` probe. That is false: a lambda's row IS checked in
# `let` and in ARGUMENT position. It is record-FIELD position that is not — and
# that happens to be where every hook in this tree is bound.
LIMPROBE=scripts/dst/.dvp_limitation_probe.ail
limcleanup() { rm -f "$LIMPROBE"; }
write_lim() {  # $1 = the binding form's body text
  cat > "$LIMPROBE" <<EOF
module scripts/dst/dvp_limitation_probe
import std/io (println)
import std/env (getEnvOr)
$1
EOF
}

write_lim 'type R = { f: (string) -> () ! {IO} }
export func main() -> () ! {IO, Env} {
  let r: R = { f: func(s: string) -> () ! {IO} { let _ = getEnvOr("PATH",""); println(s) } };
  r.f("x")
}'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "LIMITATION 1 still holds: a RECORD-FIELD lambda's declared row is NOT checked against its body — so narrowing a hook slot constrains only the bindings written as top-level functions"
else
  bad "LIMITATION 1 IS FIXED UPSTREAM: record-field lambda rows are now effect-checked. That is GOOD NEWS and it invalidates this file's controls — control_env/control_fs bind a performing body inline and must be re-sited, and every 'the compiler is the enforcer' claim in WI-D6/D7/D8 becomes true at more sites than it was"
fi

write_lim 'export func main() -> () ! {IO} {
  let f = func(s: string) -> () ! {} { println(s) };
  f("x")
}'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "LIMITATION 2 still holds: an EMPTY row on a lambda reads as 'unannotated, infer' rather than as the claim 'performs nothing' — so a slot narrowed to ! {} (WI-D6's on_budget_plan) constrains a lambda binding not at all"
else
  bad "LIMITATION 2 IS FIXED UPSTREAM: ! {} on a lambda is now a checked claim. Re-read WI-D6's on_budget_plan narrowing — it buys strictly more than it did"
fi

# The two-sided half of limitation 1: the SAME body in argument position IS
# rejected, so the acceptance above is attributable to record-field position
# rather than to the effect checker being off, the file being unreachable, or
# the probe being malformed.
write_lim 'func take(f: (string) -> () ! {IO}) -> () ! {IO} { f("x") }
export func main() -> () ! {IO, Env} {
  take(func(s: string) -> () ! {IO} { let _ = getEnvOr("PATH",""); println(s) })
}'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  bad "the control for limitation 1 was ACCEPTED in argument position too — the probe establishes nothing about record-field position, and rows 'LIMITATION 1' above are measuring the effect checker being absent rather than a positional gap"
else
  ok "control for limitation 1: the same body in ARGUMENT position is rejected, so the record-field acceptance is caused by the position"
fi

# THE THIRD LIMITATION PROBE: RECORD-UPDATE POSITION (ADR-001 Phase A, A4;
# decides plan D8). The `default_hooks` minor moves every migrated binding from
# a record LITERAL field to a record UPDATE field, `{ default_hooks(id) | on_x: f }`,
# and nothing above measured that position. ADR-001's Q3 answer (cases E/G,
# measured on v0.33.1) said a named override with a WIDER declared row would be
# accepted into a narrower slot. Both shapes are pinned here to what the PATH
# `ailang` (v0.33.0, the one `make check_core` uses) actually does, and every row
# names the ADR expectation beside the observation so a toolchain change reads as
# "the ADR's case now reproduces" rather than as a mystery.
#
# MEASURED 2026-08-26 on v0.33.0, and pinned as observed:
#   (a) inline lambda declaring the slot's row but PERFORMING Env, enclosing row
#       admits Env                              -> ACCEPTED   (limitation 1 holds in update position)
#   (a-control) same lambda, enclosing row narrow -> REJECTED  (the enclosing row is the bound, as in literal position)
#   (b) named override declared WIDER than the slot -> REJECTED (closed-row unification at the update field; ADR case E does NOT reproduce here)
#   (b-control) named override at exactly the slot row -> ACCEPTED (so (b)'s rejection is the row's doing)
# So on this toolchain record-update position is literal position: declared rows
# unify, bodies of inline lambdas do not. D8's consequence for A5: the env/fs
# controls, which already sit behind a `control_base() |` head, can stay inline;
# a literal-to-update migration changes nothing the checker sees.
# B8: the ABI no longer HAS a record-update position (`ExtensionHooks` and
# `default_hooks` are gone), so these four rows measure the toolchain on a
# LOCAL record that mirrors the two 5.x slots they exercise -- the same way
# LIMITATION 1/2 above measure on a local `type R`. They are kept because they
# are the record of WHY the 5.x tree absorbed inline effects, and because a
# 6.0 extension can still build a record-field lambda and pass the field into
# a constructor (the IMPORTED SUM `smuggle` row below), so the position is not dead.
write_upd() {  # $1 = declarations after the imports
  cat > "$LIMPROBE" <<EOF
module scripts/dst/dvp_limitation_probe
import std/env (getEnvOr)
import std/io (println)
import std/option (None)
import pkg/sunholo/motoko_ext_abi/types (ExtCtx, Msg, PreStepOutcome, FinalizeOutcome, PassThrough, NoDecision)
type ExtensionHooks = { on_pre_step: (ExtCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace}, on_solver_candidate: (ExtCtx, string) -> FinalizeOutcome ! {Process} }
func default_hooks(_id: string) -> ExtensionHooks { { on_pre_step: \\ctx _m. { decision: PassThrough, next_state: ctx.world } ! {AI, IO, Trace}, on_solver_candidate: \\ctx _c. { decision: NoDecision, next_state: ctx.world } ! {Process} } }
$1
EOF
}
upd_lambda='func(ctx: ExtCtx, _m: [Msg]) -> PreStepOutcome ! {AI, IO, Trace} { let _ = getEnvOr("PATH", ""); { decision: { PassThrough }, next_state: ctx.world } }'

write_upd "export func build() -> ExtensionHooks ! {Env} { { default_hooks(\"p\") | on_pre_step: $upd_lambda } }"
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "UPDATE POSITION (a): an inline lambda that declares the slot row and performs Env is ACCEPTED behind a default_hooks head when the enclosing row admits Env — limitation 1 holds in record-update position (D8: the controls need not move)"
else
  bad "UPDATE POSITION (a) CHANGED: an inline lambda's body is now checked against its declared row in record-update position. GOOD NEWS upstream, and it means env_control_hooks/fs_control_hooks (already behind a \`control_base() |\` head) no longer compile as written — re-site them, and re-read D8"
fi

write_upd "export func build() -> ExtensionHooks { { default_hooks(\"p\") | on_pre_step: $upd_lambda } }"
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  bad "UPDATE POSITION (a-control) was ACCEPTED with a NARROW enclosing row — the inline lambda's Env escaped every row, so (a) above measured the checker being absent, not a positional gap"
else
  ok "UPDATE POSITION (a-control): the same lambda is REJECTED once the enclosing row drops Env — in update position, as in literal position, the enclosing function's row is what bounds an inline hook"
fi

write_upd 'func finalize(ctx: ExtCtx, _c: string) -> FinalizeOutcome ! {IO, Process} { let _ = println("x"); { decision: { NoDecision }, next_state: ctx.world } }
export func build() -> ExtensionHooks { { default_hooks("p") | on_solver_candidate: finalize } }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  bad "UPDATE POSITION (b): a named override declared ! {IO, Process} was ACCEPTED into the ! {Process} slot — ADR-001 case E now REPRODUCES on this toolchain. The 'closed-row equality admits exactly one width' rows above are false in update position; a wide named override is bounded only by its own row [RC], and the enforcement plane for the default_hooks migration is hook_scope/declared_vs_performed alone"
else
  ok "UPDATE POSITION (b): a named override declared ! {IO, Process} is REJECTED at the ! {Process} slot (closed-row unification at the update field). ADR-001 case E (v0.33.1: accepted) does NOT reproduce on v0.33.0 — pinned as observed; this row goes red by design when it does"
fi

write_upd 'func finalize(ctx: ExtCtx, _c: string) -> FinalizeOutcome ! {Process} { { decision: { NoDecision }, next_state: ctx.world } }
export func build() -> ExtensionHooks { { default_hooks("p") | on_solver_candidate: finalize } }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "UPDATE POSITION (b-control): the same named override at exactly the slot row is ACCEPTED, so (b)'s rejection is attributable to the row and not to the update head, the import, or the probe"
else
  bad "UPDATE POSITION (b-control) was REJECTED — a clean named override at the slot's own row does not compile behind a default_hooks head, so nothing in this section measures rows and the empty_stop_guard migration itself should not compile either"
fi
limcleanup

# THE CONSTRUCTOR-ARGUMENT PROBE (ADR-001 Phase B, B1; ADR Q3). At 6.0 a hook
# is no longer a record field: it is the ARGUMENT of a capability constructor,
# `K(f)` for `type C = K((string) -> () ! {IO})`. ADR-001 Q3 (measured on
# v0.33.1) said the payload row bounds NOTHING in that position, for inline
# lambdas AND for named functions. Every row here is pinned to what the PATH
# `ailang` (v0.33.0) does, with the ADR expectation beside it.
#
# MEASURED 2026-08-26 on v0.33.0, and pinned as observed:
#   (i-named)   a named function declared WIDER (! {Env, IO}) than the payload
#               row (! {IO}), passed as the constructor argument
#                                            -> ACCEPTED   (THE HOLE: payload-row
#                                                          assignability is unchecked)
#   (i-unannot) an UNANNOTATED inline lambda performing Env, enclosing row
#               admits {Env, IO}              -> ACCEPTED   (the hole for inline
#                                                          lambdas: the payload row
#                                                          bounds nothing; only the
#                                                          enclosing row does)
#   (i-annot)   an inline lambda that DECLARES the payload row and performs Env
#                                            -> REJECTED   at the lambda's own
#                                                          annotation. ADR Q3's
#                                                          inline case does NOT
#                                                          reproduce on v0.33.0:
#                                                          argument position checks
#                                                          a lambda's declared row
#                                                          (limitation 1 is about
#                                                          record-FIELD position)
#   (control)   the unannotated lambda with the enclosing row narrowed to {IO}
#                                            -> REJECTED   at the enclosing row, so
#                                                          (i-unannot)'s acceptance is
#                                                          the position's doing
#   (named-ctl) a named function at exactly the payload row -> ACCEPTED
# So on this toolchain the enforcement plane for a constructor argument is:
# a NAMED binding is checked against its OWN row only (claim (a)) and never
# against the payload row (claim (b) is absent); an inline lambda is bounded by
# the enclosing function's row, and additionally by its own annotation if it
# writes one. Neither reads the payload row. That is why B2 scans a named
# binding's body rather than trusting its row, and why every green row in
# producer 3 is claim (a) alone.
write_ctor() {  # $1 = declarations after the imports
  cat > "$LIMPROBE" <<EOF
module scripts/dst/dvp_limitation_probe
import std/env (getEnvOr)
import std/io (println)
type C = K((string) -> () ! {IO}) | Noop
$1
EOF
}

write_ctor 'func impl(s: string) -> () ! {Env, IO} { let _ = getEnvOr("PATH",""); println(s) }
export func build() -> C ! {IO} { K(impl) }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "CONSTRUCTOR ARGUMENT (i-named): a named function declared ! {Env, IO} is ACCEPTED as the argument of K((string) -> () ! {IO}) -- the payload row does not bound a named binding (ADR Q3 holds on v0.33.0); B2 must SCAN a named atom, not trust its row"
else
  bad "CONSTRUCTOR ARGUMENT (i-named) CHANGED: a wide-rowed named function is now REJECTED at the payload row. GOOD NEWS upstream -- payload-row assignability is checked -- and it means claim (b) exists; re-read B2's 'scanned, not trusted' rationale, which becomes belt-and-braces rather than the only enforcement"
fi

write_ctor 'export func build() -> C ! {Env, IO} { K(func(s: string) -> () { let _ = getEnvOr("PATH",""); println(s) }) }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "CONSTRUCTOR ARGUMENT (i-unannot): an UNANNOTATED inline lambda performing Env is ACCEPTED into the ! {IO} payload when the enclosing row admits Env -- the payload row bounds an inline lambda not at all; the enclosing function's row is the bound"
else
  bad "CONSTRUCTOR ARGUMENT (i-unannot) CHANGED: an unannotated inline lambda is now checked against the payload row it is bound into. GOOD NEWS upstream; claim (b) now exists for inline lambdas and the enclosing-row reasoning in this file is no longer the whole story"
fi

write_ctor 'export func build() -> C ! {Env, IO} { K(func(s: string) -> () ! {IO} { let _ = getEnvOr("PATH",""); println(s) }) }'
if out=$(AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" 2>&1); then
  bad "CONSTRUCTOR ARGUMENT (i-annot): an inline lambda DECLARING ! {IO} and performing Env was ACCEPTED in argument position -- ADR Q3's inline case now REPRODUCES on this toolchain (it was measured on v0.33.1). Argument position no longer checks a lambda's own annotation; limitation 1 has widened from record-field to argument position and the LIMITATION 1 control above should have gone red with it"
elif echo "$out" | grep -q "uses effects not declared in its"; then
  ok "CONSTRUCTOR ARGUMENT (i-annot): an inline lambda that DECLARES the payload row and performs Env is REJECTED at its own annotation -- argument position checks a lambda's declared row on v0.33.0 (ADR Q3's inline case does not reproduce here; pinned as observed)"
else
  bad "CONSTRUCTOR ARGUMENT (i-annot): rejected, but NOT at the lambda's annotation -- it fails elsewhere and establishes nothing about the position: $(echo "$out" | grep -E '^Error' | head -1)"
fi

write_ctor 'export func build() -> C ! {IO} { K(func(s: string) -> () { let _ = getEnvOr("PATH",""); println(s) }) }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  bad "CONSTRUCTOR ARGUMENT (control) was ACCEPTED with the enclosing row narrowed to ! {IO} -- the inline lambda's Env escaped every row, so (i-unannot) above measured the checker being absent rather than a positional gap"
else
  ok "CONSTRUCTOR ARGUMENT (control): the same unannotated lambda is REJECTED once the enclosing row drops Env -- so (i-unannot)'s acceptance is attributable to the position, and the enclosing function's row is the only bound on an inline atom"
fi

write_ctor 'func impl(s: string) -> () ! {IO} { println(s) }
export func build() -> C ! {IO} { K(impl) }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "CONSTRUCTOR ARGUMENT (named-ctl): a named function at exactly the payload row is ACCEPTED, so (i-named) is not an artefact of the sum type, the import, or the probe"
else
  bad "CONSTRUCTOR ARGUMENT (named-ctl) was REJECTED -- a clean named function at the payload's own row does not compile as a constructor argument, so nothing in this section measures rows and the 6.0 registration shape itself would not compile"
fi
limcleanup
echo ""
echo "-- B8: CONSTRUCTOR ARGUMENT on the IMPORTED ABI sum (the rows above use a LOCAL sum) --"
# MEASURED AT B8 ON v0.33.0, AND IT REVERSES THE LOCAL-SUM VERDICTS: for a sum
# type IMPORTED from another module the compiler unifies a constructor argument's
# row against the payload row as CLOSED rows -- exactly what it does for a
# record field -- so ADR Q3's hole is a property of LOCALLY declared sums only.
# The ABI's `Capability` is imported by every extension, so at 6.0 the payload
# rows ARE compiler-enforced for named functions and unannotated lambdas, and an
# annotated lambda is checked at its own annotation. What survives is the
# record-field smuggle (limitation 1), pinned last.
write_abi_ctor() {  # $1 = declarations after the imports
  cat > "$LIMPROBE" <<EOF
module scripts/dst/dvp_limitation_probe
import std/env (getEnvOr)
import pkg/sunholo/motoko_ext_abi/types (Capability, Compactor, ExtCtx, Msg, PreStepOutcome, PassThrough)
$1
EOF
}
write_abi_ctor 'func impl(ctx: ExtCtx, _m: [Msg]) -> PreStepOutcome ! {AI, IO, Trace, Env} { let _ = getEnvOr("PATH",""); { decision: PassThrough, next_state: ctx.world } }
export func build() -> [Capability] ! {Env} { [Compactor(impl)] }'
if out=$(AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" 2>&1); then
  bad "IMPORTED SUM (named-wide): a named function declared ! {AI, IO, Trace, Env} was ACCEPTED as a Compactor atom -- the payload row does not bound a named binding on the REAL ABI, and B2's named-atom body scan is the only thing that catches it"
elif echo "$out" | grep -q "incompatible closed rows"; then
  ok "IMPORTED SUM (named-wide): a named function declared ! {AI, IO, Trace, Env} is REJECTED as a Compactor atom (incompatible closed rows) -- on the real ABI the payload row IS compiler-enforced for named atoms"
else
  bad "IMPORTED SUM (named-wide): rejected, but not on closed-row unification -- establishes nothing: $(echo "$out" | grep -E '^Error' | head -1)"
fi
write_abi_ctor 'export func build() -> [Capability] ! {Env} { [Compactor(func(ctx: ExtCtx, _m: [Msg]) -> PreStepOutcome { let _ = getEnvOr("PATH",""); { decision: PassThrough, next_state: ctx.world } })] }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  bad "IMPORTED SUM (unannot): an UNANNOTATED inline lambda performing Env was ACCEPTED as a Compactor atom under an enclosing ! {Env} -- the 5.x absorption survives on the real ABI"
else
  ok "IMPORTED SUM (unannot): an UNANNOTATED inline lambda performing Env is REJECTED at the payload row even though the enclosing row admits Env -- the enclosing row no longer absorbs an inline atom"
fi
write_abi_ctor 'export func build() -> [Capability] ! {Env} { [Compactor(func(ctx: ExtCtx, _m: [Msg]) -> PreStepOutcome ! {AI, IO, Trace} { let _ = getEnvOr("PATH",""); { decision: PassThrough, next_state: ctx.world } })] }'
if out=$(AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" 2>&1); then
  bad "IMPORTED SUM (annot): an inline lambda DECLARING the payload row and performing Env was ACCEPTED -- limitation 1 now applies in constructor-argument position"
elif echo "$out" | grep -q "uses effects not declared in its"; then
  ok "IMPORTED SUM (annot): an inline lambda DECLARING the payload row and performing Env is REJECTED at its own annotation -- same verdict as the local-sum (i-annot) row"
else
  bad "IMPORTED SUM (annot): rejected, but not at the lambda's annotation: $(echo "$out" | grep -E '^Error' | head -1)"
fi
write_abi_ctor 'export func build() -> [Capability] { [Compactor(func(ctx: ExtCtx, _m: [Msg]) -> PreStepOutcome ! {AI, IO, Trace} { { decision: PassThrough, next_state: ctx.world } })] }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "IMPORTED SUM (exact-ctl): an inline lambda at exactly the payload row, performing nothing, is ACCEPTED -- so the three rejections above are caused by the rows, not by the probe"
else
  bad "IMPORTED SUM (exact-ctl) was REJECTED -- a clean atom at the payload's own row does not compile, so nothing in this section measures rows"
fi
write_abi_ctor 'type W = { f: (ExtCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace} }
export func build() -> [Capability] ! {Env} {
  let w: W = { f: func(ctx: ExtCtx, _m: [Msg]) -> PreStepOutcome ! {AI, IO, Trace} { let _ = getEnvOr("PATH",""); { decision: PassThrough, next_state: ctx.world } } };
  [Compactor(w.f)]
}'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "IMPORTED SUM (smuggle): the SAME performing lambda bound to a LOCAL record field first and then passed as the atom is ACCEPTED -- limitation 1 is the one remaining door into a 6.0 payload, and it is what this file's control_env/control_fs use"
else
  bad "IMPORTED SUM (smuggle) was REJECTED: record-field lambda rows are now checked upstream. GOOD NEWS, and control_env/control_fs (built through that door) can no longer be constructed -- rebuild them before trusting the runtime rows above"
fi
# The local-vs-imported control: the SAME sum, once imported, flips the verdict.
LIMMOD=scripts/dst/dvp_limitation_sum.ail   # no dot prefix: the module name must match the file name to be importable
cat > "$LIMMOD" <<EOF
module scripts/dst/dvp_limitation_sum
export type C = K((string) -> () ! {IO}) | Noop
EOF
write_imp() {
  cat > "$LIMPROBE" <<EOF
module scripts/dst/dvp_limitation_probe
import std/env (getEnvOr)
import std/io (println)
import scripts/dst/dvp_limitation_sum (C, K, Noop)
$1
EOF
}
write_imp 'func impl(s: string) -> () ! {Env, IO} { let _ = getEnvOr("PATH",""); println(s) }
export func build() -> C ! {IO} { K(impl) }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  bad "LOCAL-vs-IMPORTED: the (i-named) shape is ACCEPTED against the IMPORTED copy of the same sum -- so the imported-sum rejections above are about the ABI's rows, not about import position, and this section's explanation is wrong"
else
  ok "LOCAL-vs-IMPORTED: the (i-named) shape accepted on the LOCAL sum is REJECTED against the IMPORTED copy of the same sum -- import position is what closes ADR Q3's hole"
fi
write_imp 'func impl(s: string) -> () ! {IO} { println(s) }
export func build() -> C ! {IO} { K(impl) }'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "LOCAL-vs-IMPORTED (control): the exact-row impl is ACCEPTED against the imported sum, so the rejection above is the row"
else
  bad "LOCAL-vs-IMPORTED (control) REJECTED -- the imported-sum probe does not compile at all and the row above establishes nothing"
fi
rm -f "$LIMMOD"

# THE FOURTH LIMITATION PROBE: CONSUMPTION / MATCH-OUT POSITION (ADR-001 Phase B,
# B1; decides plan D9). The previous rows all bound a hook at CONSTRUCTION. D9
# asks the consumer-side of the same hole: once a capability payload is matched
# out of a sum (`K(f) => f(...)`) and APPLIED under a narrow declared row, does
# the consumer's row bound what the payload body performs, or is it decorative?
# ADR-001 §5.4 flagged this unmeasured and marked it a 6.0 blocker unless the
# dispatcher rows actually bound.
#
# MEASURED 2026-08-26 on v0.33.0 (pinned toolchain), isolated so the ONLY Env in
# the program lives inside the payload (a wider-declared named impl, ADR case E
# route; build() is rowless so no call leaks Env):
#   match9_named   a narrow ! {IO} consumer matches K(f) out and applies f
#                  whose body performs Env                     -> ACCEPTED (DECORATIVE)
#   consumer_direct the same consumer with Env performed DIRECTLY   -> REJECTED (control proves the instrument is sound)
# So dispatcher rows are DECORATIVE at consumption: the body of an applied
# capability is not bounded by the consumer's row. Consequence for B8: the
# dispatch sites that apply matched-out payloads need body-reading coverage too,
# not only register_with_config / the registration function.
write_con() {  # $1 = declarations after the imports
  cat > "$LIMPROBE" <<EOF
module scripts/dst/dvp_limitation_probe
import std/env (getEnvOr)
import std/io (println)
$1
EOF
}

# D9 main case: only-Env-inside-payload via named impl (case E route).
write_con 'type C = K((string) -> () ! {IO}) | Noop
func impl(s: string) -> () ! {Env, IO} { let _ = getEnvOr("PATH","none"); println("effect performed: ${s}") }
func build() -> C { K(impl) }
export func consume() -> () ! {IO} {
  match build() {
    K(f) => { let _ = f("x"); () },
    Noop => ()
  }
}'
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  ok "CONSUMPTION (D9): a narrow ! {IO} consumer that matches a {IO}-rowed capability payload out and applies it is ACCEPTED even though the payload body performs Env -- dispatcher rows are DECORATIVE at consumption. 6.0 dispatch sites need body-reading coverage (B1 consequence)"
else
  bad "CONSUMPTION (D9): the narrow consumer REJECTED the matched-out payload -- dispatcher rows DO bound the applied payload on this toolchain. That is GOOD NEWS upstream and flips D9's consequence: reject the 'decorative dispatcher' claim and drop the B8 body-reading coverage requirement if it holds consistently"
fi

# D9 positive control: the SAME consumer with Env performed directly (not via a
# payload), proving the narrow row is real and the instrument can detect Env.
write_con "export func consume() -> () ! {IO} { let _ = getEnvOr("PATH",""); println("direct"); () }"
if AILANG_RELAX_MODULES=1 ailang check "$LIMPROBE" >/dev/null 2>&1; then
  bad "CONSUMPTION (D9) CONTROL: a narrow !{IO} consumer performing Env DIRECTLY was ACCEPTED -- the probe cannot detect Env at all, so the main D9 row above is measuring the checker being absent rather than a consumption-side gap"
else
  ok "CONSUMPTION (D9) CONTROL: the same consumer performing Env directly is REJECTED -- so the match-out acceptance above is attributable to the payload being applied, not to the probe or the checker being off"
fi
limcleanup

# WHERE THE ENFORCEMENT ACTUALLY LIVES, and it is not where WI-D6 and WI-D7
# put it. A record-field lambda's row is unchecked, but its body's effects
# still propagate to the ENCLOSING function — so for the eight extensions that
# bind on_pre_step inline, the row that constrains them is
# `register_with_config`'s, not the slot's.
#
# THE FIRST VERSION OF THIS ROW SAID "all fifteen carry the wide row and
# therefore absorb anything". THAT WAS WRONG AND THE DERIVATION CAUGHT IT —
# exactly ONE registration (compaction_ai's) carries the ten-effect row; the
# other fourteen are already narrow, and two (decision_framework, microrag)
# declare no row at all and absorb NOTHING. The absorption is per EFFECT, not
# global, so it is computed per effect rather than asserted.
# THE DENOMINATOR IS ROWS, NOT EXTENSIONS, and the two differ — which is why it
# is stated rather than left to be inferred from a fraction. Fifteen extensions
# declare FOURTEEN registration rows between them: `decision_framework` and
# `microrag` declare no row at all (so they absorb nothing), and `compose`
# declares TWO — a wrapper in `register.ail` and the real one in `compose.ail`,
# which is the file that also binds the hook.
# 14 -> 16 at ADR-001 Phase A (A2): the registry grew by agentcli and herdr,
# both of which declare a row. The denominator is still ROWS, and it is still
# (extensions - 2 rowless + 1 for compose's second), stated as that arithmetic
# so the next extension moves it by a visible +1 rather than by a re-pin.
want_reg_rows=$((N_EXTS - 2 + 1))
n_reg_rows=$( { grep -rlE "func register_with_config.*!" --include=*.ail packages/ 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "$n_reg_rows" -eq "$want_reg_rows" ]; then
  ok "$n_reg_rows register_with_config rows across the $N_EXTS extensions (decision_framework and microrag declare none; compose declares two) — the denominator for the absorption rows below"
else
  bad "the number of register_with_config rows moved from $want_reg_rows to $n_reg_rows, so every absorption fraction below has a different denominator than the one they were measured against"
fi
absorb() {  # $1 = effect name, $2 = expected count of ROWS admitting it
  local n
  n=$( { grep -rhE "func register_with_config.*!" --include=*.ail packages/ 2>/dev/null || true; } \
       | grep -oE '!\s*\{[^}]*\}' | grep -cE "[{,]\s*$1\s*[,}]" || true )
  if [ "$n" -eq "$2" ]; then
    ok "absorption of '$1' by register_with_config rows: $n of $n_reg_rows, unchanged — an inline hook that begins performing '$1' compiles silently under exactly those $n"
  else
    bad "absorption of '$1' moved from $2 to $n rows. That changes how much the WI-D6/D7/D8 slot narrowings actually enforce — re-read the note in declared_vs_performed.ail"
  fi
}
# Re-measured at ADR-001 Phase A (A2) over the seventeen-extension registry:
# agentcli (`! {Env, FS, IO, Process}`) and herdr (`! {Clock, Env, FS, IO,
# Process}`) each admit all three, so every count below moved by exactly +2
# from the WI-D8 values (14, 12, 7). These are PINS, and the producer of the
# expected value is the rows in `packages/*/register.ail` -- the next change is
# a re-measurement, not a re-pin.
absorb Env 16
absorb FS 14
absorb Process 9
# The one registration that absorbs EVERYTHING, named rather than counted.
if grep -qE "func register_with_config.*! ?$old_ten" packages/motoko-ext-compaction-ai/register.ail; then
  ok "compaction_ai's register_with_config still carries the ten-effect row — the ONE registration that absorbs any effect its inline hooks begin performing (recorded, not fixed: narrowing it is its own measurement item)"
else
  ok "compaction_ai's register_with_config is no longer at the ten-effect row — the single total-absorption site WI-D8 recorded is closed; that finding is now stale"
fi

# TWO-SIDED compile-time controls, one per narrowed slot, on D6's discipline:
# the mutant must be REJECTED under the narrowed row and ACCEPTED under a
# widened one, so the rejection is attributable to the row rather than to
# anything else in the file.
write_slot_mutant() {  # $1 = return type, $2 = row, $3 = extra import, $4 = body
  cat > "$MUTANT" <<EOF
module scripts/dst/dvp_mutant_probe
$3
import pkg/sunholo/motoko_ext_abi/types (ExtCtx)
export func mutant_hook(ctx: ExtCtx, _s: string) -> $1$2 {
  $4
}
EOF
}

control_pair() {  # $1 = label, $2 = ret, $3 = narrow row, $4 = wide row, $5 = import, $6 = body
  local label=$1
  write_slot_mutant "$2" "$3" "$5" "$6"
  if mout=$(AILANG_RELAX_MODULES=1 ailang check "$MUTANT" 2>&1); then
    bad "$label: a performing body was ACCEPTED under the narrowed row — the row is decorative and the slot's measurement rests on nothing"
  elif echo "$mout" | grep -q "Effect checking failed for function 'mutant_hook'"; then
    ok "$label: mutant REJECTED by the effect checker under the narrowed row"
  else
    bad "$label: rejected, but NOT by effect checking — it fails for an unrelated reason and establishes nothing: $(echo "$mout" | grep -E '^Error' | head -1)"
  fi
  write_slot_mutant "$2" "$4" "$5" "$6"
  if AILANG_RELAX_MODULES=1 ailang check "$MUTANT" >/dev/null 2>&1; then
    ok "$label: the SAME mutant with the row WIDENED is accepted — the rejection is caused by the row"
  else
    bad "$label: the widened mutant is also rejected — the negative result is not attributable to the effect row"
  fi
}

control_pair "on_solver_candidate" "int" " ! {Process}" " ! {Process, Env}" \
  "import std/env (getEnvOr)" 'let _ = getEnvOr("PATH", ""); 0'
control_pair "on_response_intercept" "int" " ! {IO, Process, FS, Clock}" " ! {IO, Process, FS, Clock, Env}" \
  "import std/env (getEnvOr)" 'let _ = getEnvOr("PATH", ""); 0'

# ============================================================================
# WI-D25: THE TWO AUDITED SLOTS' CAPABILITY BOUNDS, AS COMPILER VERDICTS
# ============================================================================
#
# The goal line's disclosure table needs each slot's REACHABLE SURFACE stated
# with a measured reason, and the effect checker answers it totally: a port call
# type-checks in a hook body exactly when the port's row is INCLUDED in the
# slot's row. That is a different question from "does the slot's row contain the
# effect", and WI-D24 answered the second while writing the first —
# `on_solver_candidate` declares `! {Process}` and WI-D24 concluded it "reaches
# the seam", which is S33's shape: a proxy (the effect is present) standing in
# for the truth (the whole row is admitted). `tool_handle` demands
# `{IO, Process, FS}` and gets one of three.
#
# So the bound is asserted the only way that cannot be inferred wrong: a probe
# the compiler REJECTS beside one it ACCEPTS, per slot, plus the widened control
# that attributes each rejection to the row rather than to a malformed call.
#
#   on_pre_step        ! {AI, IO, Trace}  ai_step   ACCEPT   (the one field)
#                                         clock_now REJECT   (needs Clock)
#   on_solver_candidate ! {Process}       tool_handle REJECT   (needs IO, FS too)
#                                         std/process.exec ACCEPT (AMBIENT)
#
# The last row is the one that says what the slot CAN do, and it is why the
# narrowed claim in `ext/runtime.decide_one_finalize` is "ambient subprocess
# only" rather than "no subprocess": `context_mode`'s binding spawns a `node`
# bridge through `std/process.exec` today, unmediated, and no ExtPorts widening
# is involved.
#
# THE SIGNATURE IS `(ExtCtx, string) -> int` ON EVERY PROBE and the slots' real
# arities are not reproduced, for the same reason `control_pair` above does not:
# effect checking is a property of the BODY against the ROW, and the parameter
# list and return type take no part in it. What is faithful here is the row and
# the port call.
write_port_probe() {  # $1 = row, $2 = extra import lines, $3 = body
  cat > "$MUTANT" <<EOF
module scripts/dst/dvp_mutant_probe
$2
import pkg/sunholo/motoko_ext_abi/types (ExtCtx)
export func mutant_hook(ctx: ExtCtx, _s: string) -> int$1 {
  $3
}
EOF
}

port_accepts() {  # $1 = label, $2 = row, $3 = imports, $4 = body
  write_port_probe "$2" "$3" "$4"
  if AILANG_RELAX_MODULES=1 ailang check "$MUTANT" >/dev/null 2>&1; then
    ok "$1: ACCEPTED under$2 — the call is within the slot's declared surface"
  else
    bad "$1: REJECTED under$2, and this handoff's row algebra says it must be accepted. The disclosure table's clause-2 entry for this slot rests on this verdict: $(AILANG_RELAX_MODULES=1 ailang check "$MUTANT" 2>&1 | grep -E '^Error|Missing effects' | head -1)"
  fi
}

port_rejects() {  # $1 = label, $2 = narrow row, $3 = wide row, $4 = imports, $5 = body
  write_port_probe "$2" "$4" "$5"
  if pout=$(AILANG_RELAX_MODULES=1 ailang check "$MUTANT" 2>&1); then
    bad "$1: ACCEPTED under$2 — the slot reaches this port after all, and the disclosure table's entry for it is wrong"
  else
    ok "$1: REJECTED under$2 — the port's own row is not included in the slot's ($(echo "$pout" | grep -oE 'Missing effects: .*' | head -1))"
  fi
  write_port_probe "$3" "$4" "$5"
  if AILANG_RELAX_MODULES=1 ailang check "$MUTANT" >/dev/null 2>&1; then
    ok "$1: the SAME call with the row WIDENED to$3 is accepted — the rejection is caused by the row, not by the call being malformed"
  else
    bad "$1: the widened probe is also rejected, so the negative result above is not attributable to the effect row and states nothing about the slot"
  fi
}

port_accepts "on_pre_step -> ports.ai_step" " ! {AI, IO, Trace}" "" \
  'let o = ctx.ports.ai_step(ctx.world, "m", []); 0'
port_rejects "on_pre_step -> ports.clock_now" " ! {AI, IO, Trace}" " ! {AI, IO, Trace, Clock}" "" \
  'let o = ctx.ports.clock_now(ctx.world); 0'
port_rejects "on_solver_candidate -> ports.tool_handle" " ! {Process}" " ! {Process, IO, FS}" "" \
  'let o = ctx.ports.tool_handle(ctx.world, "BashExec", "{}"); 0'
port_accepts "on_solver_candidate -> AMBIENT std/process.exec" " ! {Process}" "import std/process (exec)" \
  'let _ = exec("true", []); 0'
cleanup

echo ""
echo "-- the three producers compared --"
echo "      DECLARED  on_budget_plan : ! {}   (ABI row, static, authored — WI-D6 narrowed it)"
echo "      PERFORMED on_budget_plan : ! {}   (runtime trap, out of process, $n_measured of $N_EXTS witnessed)"
echo "      PERFORMED on_budget_plan : ! {}   (effect checker, all $N_EXTS bindings, total over inputs)"
echo "      Through WI-D5 the declared row was the closed ! {Env, FS} and the gap"
echo "      between it and the behaviour was the sole reason no extension in the"
echo "      tree was installable in a conformant profile. WI-D6 closed the gap by"
echo "      moving the DECLARATION to the measurement, per D5's own verdict that"
echo "      the barrier was 'the rule, not the behaviour'."
echo ""
echo ""
echo "      AND WHAT IT DID NOT DO, CORRECTED AT WI-D7. This block used to end"
echo "      'the empty install list is no longer FORCED — it is now CHOSEN'. It is"
echo "      still FORCED. on_budget_plan was ONE of FOUR unconditionally-dispatched"
echo "      slots; the other three are measured above and all three still declare"
echo "      non-empty rows, so all three still fail D5 criterion 1."
echo "      THREE BARRIERS STAND AND NO EXTENSION IS INSTALLABLE."
echo "      The count is derived from the ABI and the dispatch table on every run"
echo "      by \`make profile_definition\`, which goes RED if it reaches zero."
echo ""
echo "      WHAT THIS DOES NOT LICENSE — AND IT IS THE SENTENCE D5 MADE MANDATORY:"
echo "      the axis's extension-model coverage is still ZERO. driver_only installs"
echo "      no extension, and nothing about the extension model has been tested by"
echo "      this gate. Coverage needs a profile that installs something, which is"
echo "      WI-C5 and is not this item."

echo ""
if [ "$fail" -ne 0 ]; then
  echo "declared_vs_performed: $pass passed, $fail FAILED"
  exit 1
fi
echo "declared_vs_performed: $pass passed, 0 failed"
