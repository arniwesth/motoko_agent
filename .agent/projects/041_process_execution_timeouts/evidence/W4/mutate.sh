#!/usr/bin/env bash
# 041 W4: run the mutants one at a time against src/core/process_limits.ail.
# Run from the worktree root on a commit whose src, packages and scripts are clean:
#   mutate.sh <log directory>. Writes mutants.tsv and commit there, and leaves each mutant's raw
#   test and check output beside them.
#
# Each row names what must notice, written before the run:
#   <fn>_test_<n>     that inline row fails on its assertion
#   verify:<fn>       `ailang verify` answers VIOLATION for that function
#   check             check_single_construction.py exits 1
#   check-clean       the same check exits 0 (the survival rows: legal code must pass)
# A mutant is killed only when everything it names happens. A compile error, or a test failing
# with an evaluation error or a panic, is recorded as what it is and is not a kill. Any other
# failure is listed in `observed` and changes nothing.
set -u
OUT=${1:?log directory}
M=src/core/process_limits.ail
HERE=$(cd "$(dirname "$0")" && pwd)
CHECK="$HERE/check_single_construction.py"
clean() { [ -z "$(git status --porcelain -- src packages scripts)" ]; }
clean || { echo "src, packages or scripts dirty"; exit 2; }
COMMIT=$(git rev-parse HEAD)
TSV=$OUT/mutants.tsv
printf 'id\trule\tedit\texpected\tcommit\tobserved\tverdict\n' >"$TSV"

edit() { python3 - "$M" "$1" "$2" <<'PY' || exit 2
import sys
f, old, new = sys.argv[1:]
s = open(f).read()
if s.count(old) != 1: sys.exit("edit matches %d times: %s" % (s.count(old), old))
open(f, 'w').write(s.replace(old, new))
PY
}

restore() {
  git checkout -q -- "$M"
  rm -f src/core/w4_forged.ail scripts/w4_forged.ail
  clean || { echo "did not restore"; exit 2; }
}

# Prints the failed test names as `name` for an assertion failure and `name!` for anything else,
# or `compile-error` when the module did not build.
tests_failed() { # id
  ailang test --format json "$M" >"$OUT/$1.json" 2>"$OUT/$1.err"
  python3 - "$OUT/$1.json" <<'PY'
import json, re, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("compile-error"); sys.exit()
rows = d.get("tests", []) + d.get("properties", [])
bad = [t for t in rows if t.get("status") == "fail"]
if any("failed to extract" in t.get("error", "") or "type error" in t.get("error", "") for t in bad):
    print("compile-error"); sys.exit()
def name(t):
    e = t.get("error", "")
    return t["name"] + ("!" if re.search(r"panic|failed to evaluate|runtime error", e) else "")
print(" ".join(name(t) for t in bad))
PY
}

# m id rule edit-description expected... : the edit is already applied
m() {
  local id=$1 rule=$2 desc=$3; shift 3
  local want=("$@") failed vout rc obs verdict=killed w
  failed=$(tests_failed "$id")
  python3 "$CHECK" >"$OUT/$id.check" 2>&1; rc=$?
  obs="check=$rc"
  case " ${want[*]} " in
    *" verify:"*) vout=$(ailang verify "$M" 2>&1); ;;
    *) vout= ;;
  esac
  for w in "${want[@]}"; do
    case "$w" in
      check) [ "$rc" = 1 ] || verdict=survived ;;
      check-clean) [ "$rc" = 0 ] || verdict=survived ;;
      verify:*)
        if echo "$vout" | grep -q "VIOLATION ${w#verify:}"; then obs="$obs $w=VIOLATION"
        else obs="$obs $w=none"; verdict=survived; fi ;;
      *) case " $failed " in *" $w "*) ;; *) verdict=survived ;; esac ;;
    esac
  done
  [ "$failed" = compile-error ] && verdict=compile-error
  # A survival row has nothing to kill: legal code passing is its whole result.
  case " ${want[*]} " in *" check-clean "*) [ "$verdict" = killed ] && verdict=passed ;; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$rule" "$desc" "${want[*]}" "${COMMIT:0:8}" "$obs failed=[$failed]" "$verdict" >>"$TSV"
  echo "$id: $verdict | want ${want[*]} | $obs | failed: $(echo "$failed" | cut -c1-140)"
  restore
}

# The unmutated tree first.
base=$(tests_failed base)
[ -z "$base" ] || { echo "base tests not green: $base"; exit 2; }
python3 "$CHECK" || { echo "base check not green"; exit 2; }
ailang verify "$M" 2>&1 | grep -E 'VIOLATION|ERROR' && { echo "base verify not green"; exit 2; }
echo "base: tests, check and verify green"

# ---- The plan's nine named mutants.
edit 'if request <= ceiling then request else ceiling' 'request'
m r1 'I1: a request above the ceiling is clamped (plan r1)' 'clamp_ms returns the request' clamp_ms_test_3 row_resolve_test_7 row_fields_test_2 verify:clamp_ms
edit 'if request <= ceiling then request else ceiling' 'ceiling'
m r1.fits 'I1, second half: a request that fits is the request' 'clamp_ms always answers the ceiling' clamp_ms_test_1 row_resolve_test_5 verify:clamp_ms
edit 'if request <= ceiling then request else ceiling' 'if request <= ceiling then request else ceiling - 1'
m r1.low 'D7 row 3: above the ceiling is exactly the ceiling' 'one under the ceiling; the contract admits this, so a row must catch it' clamp_ms_test_3 row_resolve_test_7
edit 'NoDeadline => (ExplicitMs(r), false),' 'NoDeadline => (SessionDefault, r * 1000000 > 0),'
m r2 'D7: NoDeadline is matched, never compared (plan r2)' 'SameAsDefault with NoDeadline compares it as a default of 0' row_resolve_test_18 row_fields_test_12 row_project_test_7
edit 'else n / 1000000 + 1' 'else n / 1000000'
m r3 'D4: display rounds up (plan r3)' 'a fractional default rounds down' ms_rounded_up_test_1 row_fields_test_7 verify:ms_rounded_up
edit 'Finite(n) => if n <= 0 then true else' 'Finite(n) => if n <= 0 then false else'
m r4 'D7/A10: Finite(0) expires at t=0 (plan r4)' 'a non-positive default is read as no deadline' row_expires_test_3 row_expires_test_4 row_expires_test_5
edit 'if x > 0.0 && x == floor(x)' 'if x >= 0.0 && x == floor(x)'
m r5 'D2: zero is invalid (plan r5)' 'zero is accepted' row_request_test_11 row_fields_test_17
edit 'if x > 0.0 && x == floor(x) &&' 'if x > 0.0 &&'
m r6 'D2: a fractional request is invalid (plan r6)' 'accept 1.5, truncated to 1000' row_request_test_13 row_request_test_14 row_fields_test_16
edit 'if r_ns < d then (ExplicitMs(r), false) else (SessionDefault, r_ns > d)' '(ExplicitMs(r), false)'
m r7 'R7/D7: SameAsDefault cannot extend (plan r7)' 'a request above the default runs as asked' row_resolve_test_12 row_resolve_test_14 row_fields_test_4 row_loopback_test_1
edit 'if attempted then' 'if true then'
m r8 'D4: no attempt, no timeout_ms (plan r8)' 'timeout_ms is written with attempted false' row_fields_test_14 row_fields_test_15

R9_LITERAL='Some({ budget: SessionDefault, requested_ms: None, clamped: false, session_default: NoDeadline, effective_ceiling: SameAsDefault })'
EXT_CALL='ProcessResolved(resolved) => Some(resolved),'
edit "$EXT_CALL" "ProcessResolved(resolved) => $R9_LITERAL,"
m r9 'D7: only the resolver builds a result (plan r9)' 'extension_process writes the literal with a stale session_default' row_extension_test_2 check
edit "$EXT_CALL" 'ProcessResolved(resolved) => Some({ resolved | session_default: NoDeadline }),'
m r9.update 'D7: only the resolver builds a result' 'a record update makes session_default stale' row_extension_test_2 check
edit "$EXT_CALL" 'ProcessResolved(resolved) => Some({ resolved | clamped: true }),'
m r9.flag 'D7: only the resolver builds a result' 'a record update forges clamped, leaving session_default alone' row_extension_test_2 check
edit 'BadRequest(requested) => ProcessInvalid({
      requested_ms: requested,
      session_default: limits.default,' 'BadRequest(requested) => ProcessInvalid({
      requested_ms: requested,
      session_default: NoDeadline,'
m r9.invalid 'D7: the copy agrees with the limits' 'the resolver writes a stale session_default on an invalid request' row_agreement_test_4 check
edit '          session_default: limits.default,
          effective_ceiling: limits.ceiling
        })' '          session_default: NoDeadline,
          effective_ceiling: limits.ceiling
        })'
m r9.resolved 'D7: the copy agrees with the limits' 'the resolver writes a stale session_default on a resolved request' row_agreement_test_1 row_agreement_test_2 check
edit '          session_default: limits.default,
          effective_ceiling: limits.ceiling
        })' '          session_default: limits.default,
          effective_ceiling: SameAsDefault
        })'
m r9.ceiling 'D7: the copy agrees with the limits' 'the resolver writes a stale effective_ceiling on a resolved request' row_agreement_test_1 check
edit 'export pure func loopback_limits(' 'export pure func rewrap(r: ResolvedProcess) -> ProcessResolution { ProcessResolved(r) }

export pure func loopback_limits('
m r9.wrap 'D7: only the resolver builds a result' 'a new function wraps a record in ProcessResolved; no stale value, so only the check can see it' check
printf 'module src/core/w4_forged\nimport src/core/process_limits (SessionLimit, NoDeadline, Ceiling, SameAsDefault, SessionDefault)\nexport pure func forged() = { budget: SessionDefault, requested_ms: None, clamped: false,\n  session_default\n    : NoDeadline, effective_ceiling: SameAsDefault }\n' >src/core/w4_forged.ail
m r9.other-module 'D7: only the resolver builds a result' 'another module writes the literal, label and colon on separate lines; no row there, so only the check can see it' check
printf 'module scripts/w4_forged\nimport src/core/process_limits (ProcessInvalid as Mk)\nexport pure func forged(i) = Mk(i)\n' >scripts/w4_forged.ail
m r9.alias 'D7: only the resolver builds a result' 'another directory imports the constructor under an alias' check
printf 'module src/core/w4_forged\n-- session_default: NoDeadline, ProcessResolved({ clamped: true })\nimport src/core/process_limits (ResolvedProcess, ProcessResolution, ProcessResolved, ProcessInvalid)\nexport pure func text() -> string { "session_default: x, ProcessResolved(r)" }\nexport pure func read(r: ProcessResolution) -> bool { match r { ProcessResolved(p) => p.clamped, ProcessInvalid(i) => false } }\n' >src/core/w4_forged.ail
m r9.survive 'survival: reading, matching, comments and strings are legal' 'a caller that imports, matches and reads fields, and mentions the labels in a comment and a string' check-clean

# ---- D2's request table, and E3's.
edit '    None => NoRequest,
    Some(JNull) => NoRequest,' '    None => BadRequest(None),
    Some(JNull) => NoRequest,'
m d2.absent 'D2: no argument is the default' 'an absent argument is invalid' row_request_test_1 row_resolve_test_1 row_extension_test_2
edit 'Some(JNull) => NoRequest,' 'Some(JNull) => BadRequest(None),'
m d2.null 'D2/E3: null is the default' 'null is invalid' row_request_test_2
edit 'then ValidMs(floatToInt(x) * 1000)' 'then ValidMs(floatToInt(x) * 100)'
m e3.whole 'E3: 60, 60.0 and 1e3 are whole seconds' 'seconds convert with the wrong factor' row_request_test_3 row_request_test_4 row_request_test_5 row_request_test_7
edit 'if x > 0.0 && x == floor(x)' 'if x != 0.0 && x == floor(x)'
m d2.negative 'D2: a negative request is invalid' 'a negative whole request is accepted' row_request_test_12
edit ' && x <= intToFloat(max_request_secs())
' '
'
m e3.1e16 'D2/E3: 10^16 is out of range' 'no upper bound on a request' row_request_test_9 row_request_test_10
edit ' && x <= intToFloat(max_request_secs())
' ' && x < intToFloat(max_request_secs())
'
m d2.bound 'D2: one year exactly is in range' 'the bound excludes itself' row_request_test_8
edit 'Some(_) => BadRequest(None)' 'Some(JString(_)) => NoRequest,
    Some(_) => BadRequest(None)'
m d2.string 'D2/E3: a string is invalid' 'a string is treated as no argument' row_request_test_16
edit 'Some(_) => BadRequest(None)' 'Some(JBool(_)) => NoRequest,
    Some(_) => BadRequest(None)'
m d2.boolean 'D2: a boolean is invalid' 'a boolean is treated as no argument' row_request_test_17
edit 'Some(_) => BadRequest(None)' 'Some(JArray(_)) => NoRequest,
    Some(_) => BadRequest(None)'
m d2.array 'D2: an array is invalid' 'an array is treated as no argument' row_request_test_18
edit 'Some(_) => BadRequest(None)' 'Some(JObject(_)) => NoRequest,
    Some(_) => BadRequest(None)'
m d2.object 'D2: an object is invalid' 'an object is treated as no argument' row_request_test_19
edit 'else BadRequest(whole_ms_of_secs(x))' 'else BadRequest(None)'
m d4.report-1.5 'D4/plan: 1.5 reports 1500' 'an invalid request reports nothing' row_request_test_13 row_fields_test_16
edit 'if k > 0.0 && k / 1000.0 == x then Some(floatToInt(k)) else None' 'if k >= 0.0 then Some(floatToInt(k)) else None'
m d4.report-tiny 'D4/plan: 0.0000001 reports none' 'the whole-millisecond test is dropped' row_whole_ms_test_6 row_request_test_15
edit 'if k > 0.0 && k / 1000.0 == x then' 'if k > 0.0 && k == x * 1000.0 then'
m d4.product 'E3: the whole-millisecond test runs on a float' 'the test compares the inexact product' row_whole_ms_test_3 row_request_test_14
edit 'if x > intToFloat(max_request_secs()) then None' 'if false then None'
m d4.report-bound 'D4: requested_ms only within D2 bound' 'an out-of-range request reports its value' row_whole_ms_test_11 row_whole_ms_test_12 row_fields_test_18
edit 'if k > 0.0 && k / 1000.0 == x then' 'if k / 1000.0 == x then'
m d4.report-negative 'D4: requested_ms only for a positive request' 'zero and a negative request report a value' row_whole_ms_test_8 row_whole_ms_test_9

# E3's last row has no mutant: `1e400` fails inside std/json's decoder, so no change to this module
# can alter it. row_undecodable pins the fact, and W7 owns the path it leads to.
printf 'e3.1e400\tE3: 1e400 fails to decode, so it never reaches the resolver\tnone possible in this module\trow_undecodable_test_1\t%s\tnot run\tn/a\n' "${COMMIT:0:8}" >>"$TSV"

# ---- D7's resolver table, by row.
edit '_ => ((SessionDefault, false), None)' '_ => ((ExplicitMs(0), false), None)'
m t1.none 'D7 row 1: no request is SessionDefault' 'no request gets an explicit budget' row_resolve_test_1 row_resolve_test_2 row_resolve_test_3 row_resolve_test_4
edit '_ => ((SessionDefault, false), None)' '_ => ((SessionDefault, true), None)'
m t1.flag 'D7 row 1: no request is not clamped' 'no request reports clamped' row_resolve_test_1
edit 'CeilingMs(c) => (ExplicitMs(clamp_ms(r, c)), r > c),' 'CeilingMs(c) => (SessionDefault, r > c),'
m t2.fits 'D7 row 2: r <= c is ExplicitMs(r)' 'under a ceiling the budget is the default' row_resolve_test_5 row_resolve_test_8
edit '(ExplicitMs(clamp_ms(r, c)), r > c)' '(ExplicitMs(clamp_ms(r, c)), r >= c)'
m t2.equal 'D7 row 2: r = c is not clamped' 'equality reports clamped' row_resolve_test_6
edit '(ExplicitMs(clamp_ms(r, c)), r > c)' '(ExplicitMs(clamp_ms(r, c)), false)'
m t3.flag 'D7 row 3: r > c says so' 'a clamp is not reported' row_resolve_test_7 row_resolve_test_9 row_fields_test_2
edit 'if r_ns < d then (ExplicitMs(r), false)' 'if r_ns <= d then (ExplicitMs(r), false)'
m t4.equal 'D7 row 4: equality is not r_ns < d' 'equality gets an explicit budget' row_resolve_test_11 row_project_test_2
edit 'let r_ns = r * 1000000;' 'let r_ns = r * 1000000 + 1000000000;'
m t4.shorten 'D7 row 4: a shorter request is honoured' 'requests compare a second too long' row_resolve_test_10
edit 'if r_ns < d then (ExplicitMs(r), false) else' 'if r < d / 1000000 then (ExplicitMs(r), false) else'
m t4.fractional 'D7 row 4: ns, not ms, decide' 'the comparison truncates a fractional default to ms' row_resolve_test_21
edit '(SessionDefault, r_ns > d)' '(SessionDefault, r_ns >= d)'
m t5.equal 'D7 row 5: equality is not clamped' 'equality reports clamped' row_resolve_test_11 row_fields_test_5
edit '(SessionDefault, r_ns > d)' '(SessionDefault, false)'
m t5.flag 'D7 row 5/R7: above the default says so' 'a clamp to the default is not reported' row_resolve_test_12 row_fields_test_4 row_loopback_test_1
edit 'if r_ns < d then (ExplicitMs(r), false) else' 'if r_ns < d || d <= 0 then (ExplicitMs(r), false) else'
m t5.non-positive 'D7/A9: a non-positive default still decides' 'a request beats a non-positive default' row_resolve_test_16 row_resolve_test_17 row_project_test_6
edit '(outcome, Some(r))' '(outcome, None)'
m t.requested 'D7: requested_ms carries the request' 'a valid request is not recorded' row_resolve_test_5 row_fields_test_2

# ---- D7's expiry table, by row, and the large-t comparison.
edit 'None => legacy_timeout_ms > 0 && t > legacy_timeout_ms,' 'None => t > legacy_timeout_ms,'
m x1.zero 'D7/A10: timeout_ms 0 with no carrier is no deadline' 'the legacy guard is dropped' row_expires_no_carrier_test_2 row_expires_no_carrier_test_5
edit 'None => legacy_timeout_ms > 0 && t > legacy_timeout_ms,' 'None => legacy_timeout_ms > 0 && t >= legacy_timeout_ms,'
m x1.strict 'D7: today predicate is strict' 'legacy expiry is inclusive' row_expires_no_carrier_test_3
edit 'NoDeadline => false,' 'NoDeadline => true,'
m x2.never 'D7: SessionDefault, NoDeadline never expires' 'NoDeadline expires' row_expires_test_1 row_expires_test_2
edit 'Finite(n) => if n <= 0 then true else' 'Finite(n) => if n == 0 then true else'
m x3.negative 'D7: n <= 0 expires always' 'only 0 expires always' row_expires_test_18
edit '  t > n / 1000000
' '  t * 1000000 > n
'
m x4.naive 'plan: t * 1000000 compared safely (the boundary row)' 'the naive multiply' scripted_duration_exceeds_test_6 scripted_duration_exceeds_test_7 row_expires_test_13
edit '  t > n / 1000000
' '  intToFloat(t) * 1000000.0 > intToFloat(n)
'
m x4.float 'plan: t * 1000000 compared safely' 'the multiply in floats, which loses precision' scripted_duration_exceeds_test_8
edit '  t > n / 1000000
' '  t > n / 1000000 + 1
'
m x4.ceil 'plan: rounded down' 'the quotient is rounded up' scripted_duration_exceeds_test_2 scripted_duration_exceeds_test_4 row_expires_test_9 verify:scripted_duration_exceeds
edit '  t > n / 1000000
' '  t >= n / 1000000
'
m x4.equal 'D7: expiry is strictly greater' 'expires at the boundary' scripted_duration_exceeds_test_3 row_expires_test_6 row_expires_test_12 verify:scripted_duration_exceeds
edit 'ExplicitMs(m) => t > m,' 'ExplicitMs(m) => t >= m,'
m x5.explicit 'D7: ExplicitMs(m) expires when t > m' 'expires at m' row_expires_test_14 row_expires_test_16
edit 'ExplicitMs(m) => t > m,' 'ExplicitMs(m) => false,'
m x5.never 'D7: ExplicitMs(m) expires' 'an explicit budget never expires' row_expires_test_15 row_expires_test_17

# ---- D4's display values, A8's fields, A9's projection.
edit 'if n <= 0 then 0
' 'if n <= 0 then n
'
m v.non-positive 'D4: any non-positive default displays 0' 'a negative default displays as itself' ms_rounded_up_test_9 row_fields_test_9 verify:ms_rounded_up
edit 'else n / 1000000 + 1' 'else (n + 999999) / 1000000'
m v.overflow 'D4: rounding up does not overflow' 'the textbook round-up' ms_rounded_up_test_7
edit 'NoDeadline => None,
    Finite(n) => Some(ms_rounded_up(n))' 'NoDeadline => Some(0),
    Finite(n) => Some(ms_rounded_up(n))'
m v.no-deadline 'D4: null means no deadline, 0 does not' 'NoDeadline displays 0' row_fields_test_10 row_fields_test_11 row_fields_test_12 verify:display_session_limit
edit 'ExplicitMs(m) => Some(m),' 'ExplicitMs(m) => display_session_limit(resolved.session_default),'
m v.timeout 'D4: timeout_ms is the limit given to the attempt' 'an explicit budget displays the default' row_fields_test_1
edit 'CeilingMs(c) => Some(c),' 'CeilingMs(c) => display_session_limit(session_limit),'
m v.max-ceiling 'D4: max_timeout_ms is the ceiling' 'a ceiling displays the default' row_fields_test_1
edit 'SameAsDefault => display_session_limit(session_limit)' 'SameAsDefault => None'
m v.max-same 'D4/R7: under SameAsDefault max_timeout_ms is the default' 'SameAsDefault displays null' row_fields_test_4
edit '    None => JNull
' '    None => jint(0)
'
m f.null 'A8: null, not 0, for no deadline' 'None renders as 0' row_fields_test_10 row_fields_test_12
edit '(if resolved.clamped then requested_field(resolved.requested_ms) else [])' '[]'
m f.clamped 'D4: requested_timeout_ms when clamped' 'a clamp does not name the request' row_fields_test_2 row_fields_test_4
edit '(if resolved.clamped then requested_field(resolved.requested_ms) else [])' 'requested_field(resolved.requested_ms)'
m f.unclamped 'D4: no requested_timeout_ms unless clamped' 'every attempt names the request' row_fields_test_1 row_fields_test_5
edit 'requested_field(resolved.requested_ms) ++ [max_field(resolved.session_default, resolved.effective_ceiling)]' '[max_field(resolved.session_default, resolved.effective_ceiling)]'
m f.no-attempt 'plan: no attempt names a known request' 'the no-attempt arm drops the request' row_fields_test_15
edit 'requested_field(invalid.requested_ms) ++ [max_field(invalid.session_default, invalid.effective_ceiling)]' '[max_field(invalid.session_default, invalid.effective_ceiling)]'
m f.invalid 'plan: an InvalidRequest names a known request' 'the invalid arm drops the request' row_fields_test_16
edit 'requested_field(invalid.requested_ms) ++ [max_field(invalid.session_default, invalid.effective_ceiling)]' '[max_field(invalid.session_default, invalid.effective_ceiling)] ++ requested_field(invalid.requested_ms)'
m f.order-invalid 'D4: the fields keep their order' 'max_timeout_ms before requested_timeout_ms' row_fields_test_16
edit '[{key: "timeout_ms", value: optional_ms_json(display_timeout_ms(resolved))}]
          ++ (if resolved.clamped then requested_field(resolved.requested_ms) else [])' '(if resolved.clamped then requested_field(resolved.requested_ms) else [])
          ++ [{key: "timeout_ms", value: optional_ms_json(display_timeout_ms(resolved))}]'
m f.order-attempt 'D4: the fields keep their order' 'requested_timeout_ms before timeout_ms' row_fields_test_2
edit 'ExplicitMs(m) => m,' 'ExplicitMs(m) => legacy_timeout_ms,'
m p.explicit 'D7/A9: ExplicitMs(m) records m' 'the projection ignores an explicit budget' row_project_test_1 row_project_test_7 row_project_test_9
edit 'SessionDefault => legacy_timeout_ms' 'SessionDefault => 0'
m p.default 'D7/A9: SessionDefault records today value' 'SessionDefault records 0' row_project_test_2 row_project_test_3 row_project_test_4 row_project_test_5 row_project_test_6 row_project_test_8
edit '    None => legacy_timeout_ms
  }
}' '    None => 0
  }
}'
m p.none 'D7: no carrier records today value' 'no carrier records 0' row_project_no_carrier_test_2

# ---- R7 and R8.
edit '  { default: limits.default, ceiling: SameAsDefault }' '  { default: limits.default, ceiling: limits.ceiling }'
m l.ceiling 'R7: loopback forces SameAsDefault' 'loopback keeps the run ceiling' row_loopback_test_1 verify:loopback_limits
edit '  { default: limits.default, ceiling: SameAsDefault }' '  { default: NoDeadline, ceiling: SameAsDefault }'
m l.default 'R7: loopback keeps the run default' 'loopback loses the default; the contract does not say this, so a row must' row_loopback_test_1 row_extension_test_2
edit 'resolve_process_limit(loopback_limits(limits), JObject([]))' 'resolve_process_limit(limits, JObject([]))'
m e.ceiling 'R8: an extension runs at SameAsDefault' 'the extension keeps the run ceiling' row_extension_test_2
edit 'resolve_process_limit(loopback_limits(limits), JObject([]))' 'resolve_process_limit(loopback_limits(limits), JObject([{key: "timeout_secs", value: jint(1)}]))'
m e.request 'R8: an extension makes no request' 'the extension sends a request' row_extension_test_2 row_extension_test_3
edit 'Legacy => None,' 'Legacy => extension_process(Limits({ default: NoDeadline, ceiling: SameAsDefault })),'
m e.legacy 'D7: Legacy has no carrier' 'Legacy gets a carrier' row_extension_test_1

# ---- parse_ceiling_ms: D2's strict domain.
edit 'if ns > 0 && ns % 1000000 == 0 then' 'if ns % 1000000 == 0 then'
m c.positive 'D2: the ceiling is positive' 'a zero duration is accepted' row_ceiling_test_20 row_ceiling_test_21 row_ceiling_test_22
edit 'if ns > 0 && ns % 1000000 == 0 then' 'if ns > 0 then'
m c.whole 'D2: the ceiling is whole milliseconds' 'a fractional millisecond truncates' row_ceiling_test_16 row_ceiling_test_17 row_ceiling_test_18
edit 'let body = if startsWith(t, "+") then substring(t, 1, length(t)) else t;' 'let body = if startsWith(t, "+") || startsWith(t, "-") then substring(t, 1, length(t)) else t;'
m c.negative 'D2: a negative ceiling is refused' 'the sign is skipped' row_ceiling_test_23
edit 'let body = if startsWith(t, "+") then substring(t, 1, length(t)) else t;' 'let body = t;'
m c.plus 'Go grammar: an optional +' 'a leading + is refused' row_ceiling_test_12
edit 'let t = trim(s);' 'let t = s;'
m c.trim 'process_wall_ms reads it trimmed' 'surrounding space is refused' row_ceiling_test_2
edit 'Some(v) => if v > max_duration_ns() / unit then None else Some(v * unit),' 'Some(v) => Some(v * unit),'
m c.overflow 'Go grammar: refused past the int64 range' 'a term wraps' row_ceiling_test_38
edit 'if part > max_duration_ns() - w || w + part > max_duration_ns() - acc then None
            else ' ''
m c.sum 'Go grammar: refused past the int64 range' 'a sum wraps' row_ceiling_test_39
edit 'if acc > (max_duration_ns() - d) / 10 then None else ' ''
m c.digits 'Go grammar: refused past the int64 range' 'the digits wrap' row_ceiling_test_40
edit '  else if startsWith(rest, "ms") then (1000000, 2)
' ''
m c.ms 'Go grammar: ms is not m' 'ms is not a unit' row_ceiling_test_3
edit '  else if startsWith(rest, "µs") then (1000, length("µs"))
' ''
m c.micro-b5 'Go grammar: the micro sign U+00B5' 'U+00B5 is not a unit' row_ceiling_test_10
edit '  else if startsWith(rest, "μs") then (1000, length("μs"))
' ''
m c.micro-3bc 'Go grammar: the micro sign U+03BC' 'U+03BC is not a unit' row_ceiling_test_11
edit 'let nine = match stringToInt(substring("${digits}000000000", 0, 9)) { Some(v) => v, None => 0 };' 'let nine = 0;'
m c.fraction 'Go grammar: a decimal fraction' 'the fraction is dropped' row_ceiling_test_6 row_ceiling_test_7
edit 'substring("${digits}000000000", 0, 9)' 'digits'
m c.fraction-digits 'Go: precision past nanoseconds is dropped' 'the digits are not cut or padded to nine' row_ceiling_test_6 row_ceiling_test_14
edit '(0, _) => None,' '(0, _) => Some(acc),'
m c.no-unit 'Go grammar: every term has a unit' 'trailing text ends the parse' row_ceiling_test_41
edit 'if j == i && fraction == "" then None
    else ' ''
m c.no-digits 'Go grammar: every term has digits' 'a unit alone is a term' row_ceiling_test_37

clean && echo "tree clean" || { echo "tree dirty"; exit 2; }
echo "commit $COMMIT"
echo "$COMMIT" >"$OUT/commit"
cut -f7 "$TSV" | tail -n +2 | sort | uniq -c
