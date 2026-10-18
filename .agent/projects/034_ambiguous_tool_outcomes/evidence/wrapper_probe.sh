#!/usr/bin/env bash
# 034 PLAN-001 W0b.1: a deadline wrapper, probed through `run_process_result`
# and read off the rendered tool message. Cases 22-46, continuing
# start_probe.sh's numbering. Evidence for PLAN-001 W0b.1/W0b.2 and ADR-001
# D6. Not a gate.
#
#   bash .agent/projects/034_ambiguous_tool_outcomes/evidence/wrapper_probe.sh
#
# Unlike exec_probe.sh and start_probe.sh, every case is one BashExec or
# RunTests call sent through `dispatch_one_typed` -> `run_native_batch` ->
# `run_process_result` (src/core/tool_runtime.ail), and what is printed is the
# tool message the model reads (`tool_result_message`). The driver is
# wrapper_probe.ail beside this script. The wrapper does not exist yet (W0b.3),
# so each case writes it into the call: `cmd: "timeout"` with the wrapped argv
# reaches the direct-exec arm unchanged; `timeout ...` inside a command string
# with shell tokens reaches the `bash -lc` arm.
#
# Runs in a temp dir: a scratch tree that links the repo's src/, packages/,
# ailang.toml and ailang.lock, holds the driver at scripts/dst/, and is
# removed at the end. Touches nothing in the repo. Takes about 4 minutes.
# Needs `ailang` (the pinned v0.52.5), GNU coreutils `timeout`, python3.
set -u

REPO=$(cd "$(dirname "$0")/../../../.." && pwd)
EVID=$(cd "$(dirname "$0")" && pwd)
D=$(mktemp -d)
trap 'chmod -R u+w "$D" 2>/dev/null; rm -rf "$D"' EXIT
mkdir -p "$D/tree/scripts/dst" "$D/work" "$D/bin_none" "$D/bin_g"
for f in src packages ailang.toml ailang.lock; do ln -s "$REPO/$f" "$D/tree/$f"; done
cp "$EVID/wrapper_probe.ail" "$D/tree/scripts/dst/wrapper_probe_034.ail"
W="$D/work"
export AILANG_FS_SANDBOX="$W"   # the exec'd process's cwd

# A PATH with no `timeout`: only what the direct-exec cases name. And one where
# it exists only as `gtimeout`, as Homebrew coreutils installs it on macOS.
for b in sleep tail; do ln -s "$(command -v $b)" "$D/bin_none/$b"; done
for b in sleep tail; do ln -s "$(command -v $b)" "$D/bin_g/$b"; done
ln -s "$(command -v timeout)" "$D/bin_g/gtimeout"

# $1: cmd, rest: args -> the call's arguments as JSON.
call_json() { python3 -I -c 'import json,sys; print(json.dumps({"cmd":sys.argv[1],"args":sys.argv[2:]}))' "$@"; }

# What a case reads off the message: the arm-independent fields a W0b.3 row
# would assert.
summarise() {
  python3 -I -c '
import json,sys
m=sys.stdin.read()
try: j=json.loads(m)
except Exception: print("    (message is not JSON)"); sys.exit()
f=j.get("fault")
fs="no fault" if f is None else "fault kind=%s effects=%s%s" % (f.get("kind"), f.get("effects"),
    "".join(" %s=%s" % (k, f[k]) for k in ("elapsed_ms","bytes","signal","signal_name") if k in f))
print("    %s | exit_code=%s | stdout=%r | stderr=%r%s" % (fs, j.get("exit_code"), j.get("stdout","")[:120], j.get("stderr","")[:160],
    " | passed=%s failed=%s" % (j.get("passed"), j.get("failed")) if "passed" in j else ""))
'
}

# $1: label, $2: wall (--process-timeout), $3: tool, $4: args JSON, rest: extra
# `ailang run` flags. Env PROBE_PATH overrides PATH for the run.
probe() {
  local label=$1 wall=$2 tool=$3 args=$4
  shift 4
  local out
  out=$(cd "$D/tree" && PATH="${PROBE_PATH:-$PATH}" W0B_TOOL="$tool" W0B_ARGS="$args" \
        "$TIMEOUT" 120 "$AILANG" run --caps IO,Env,FS,Clock,Process --process-timeout "$wall" "$@" \
        --entry main scripts/dst/wrapper_probe_034.ail < /dev/null 2>&1)
  local elapsed msg
  elapsed=$(printf '%s\n' "$out" | sed -n 's/^ELAPSED_MS //p' | tail -1)
  msg=$(printf '%s\n' "$out" | sed -n 's/^MESSAGE //p' | tail -1)
  echo "== $label   [wall $wall, dispatch took ${elapsed:-?} ms]"
  if [ -z "$msg" ]; then
    echo "    NO MESSAGE. Driver output:"; printf '%s\n' "$out" | tail -5 | sed 's/^/      /'
  else
    echo "    message: $(printf '%s' "$msg" | sed "s|$D|\$D|g" | cut -c1-420)"
    printf '%s' "$msg" | summarise
  fi
}

marker() { if [ -e "$W/$1" ]; then echo present; else echo absent; fi; }
alive() { if pgrep -f "$1" >/dev/null; then echo alive; else echo gone; fi; }

AILANG=$(command -v ailang)
TIMEOUT=$(command -v timeout)
BASH=$(command -v bash)
"$AILANG" --version 2>&1 | head -1
timeout --version 2>&1 | head -1
echo "uid $(id -u); bash -l turns PATH=/nonexistent into: $(env -i PATH=/nonexistent "$BASH" -lc 'echo $PATH')"
echo "repo $(git -C "$REPO" rev-parse --short HEAD)"
echo

S='echo PARTIAL; echo ERRLINE >&2'

echo "--- no wrapper: what W0 renders today (the 0.52.5 baseline) ---"
probe "22 bash -lc arm, deadline, work still running" 2s BashExec \
  "$(call_json "$S; (sleep 8; touch m22) >/dev/null 2>&1 & sleep 30")"
echo "    m22 when the message was rendered: $(marker m22)"
probe "23 direct-exec arm, deadline (sleep 30)" 3s BashExec "$(call_json sleep 30)"
probe "24 command's own exit 124, no wrapper" 20s BashExec "$(call_json 'echo OWN; exit 124')"

echo
echo "--- exit 124: wrapper deadline vs the command's own 124 (bash -lc arm, deadline 2 s, grace 1 s, wall 20 s) ---"
probe "25 wrapper deadline, work still running" 20s BashExec \
  "$(call_json "timeout -k 1 2 bash -c '$S; (sleep 8; touch m25) >/dev/null 2>&1 & sleep 30'")"
probe "26 command's own exit 124, early" 20s BashExec \
  "$(call_json "timeout -k 1 2 bash -c 'echo OWN; exit 124'")"
probe "27 command's own exit 124 at 1.8 s, just inside the deadline" 20s BashExec \
  "$(call_json "timeout -k 1 2 bash -c 'sleep 1.8; echo OWN; exit 124'")"
probe "28 --verbose, wrapper deadline" 20s BashExec \
  "$(call_json "timeout --verbose -k 1 2 bash -c '$S; sleep 30'")"
probe "29 --verbose, command forges the verbose line and exits 124" 20s BashExec \
  "$(call_json "timeout --verbose -k 1 2 bash -c 'echo \"timeout: sending signal TERM to command ‘bash’\" >&2; exit 124'")"
LC_ALL=C probe "29b --verbose under LC_ALL=C: the same line, other quotes" 20s BashExec \
  "$(call_json "timeout --verbose -k 1 2 bash -c 'sleep 30'")"
probe "30 command ignores TERM: KILL after the grace" 20s BashExec \
  "$(call_json "timeout -k 1 2 bash -c 'trap \"\" TERM; $S; sleep 30'")"
probe "31 command exits on TERM with its own code (trap ... exit 3)" 20s BashExec \
  "$(call_json "timeout -k 1 2 bash -c 'trap \"exit 3\" TERM; $S; sleep 30 & wait'")"
echo
echo "--- process groups ---"
probe "46 process groups: the wrapped command's pgid vs timeout's and the runtime's" 20s BashExec \
  "$(call_json "timeout -k 1 5 bash -c 'echo cmd=\$(ps -o pgid= -p \$\$) timeout=\$(ps -o pgid= -p \$PPID) timeout_pid=\$PPID timeout_parent=\$(ps -o comm= -p \$(ps -o ppid= -p \$PPID)) runtime=\$(ps -o pgid= -p \$(ps -o ppid= -p \$PPID))'")"
echo
echo "--- the direct-exec arm (no shell tokens) ---"
printf 'line one\nline two\n' > "$W/tail.txt"
probe "32 direct arm, no wrapper: tail -f (prints, then waits)" 3s BashExec "$(call_json tail -f tail.txt)"
probe "33 direct arm under timeout: tail -f" 20s BashExec "$(call_json timeout -k 1 2 tail -f tail.txt)"
probe "34 direct arm under timeout: sleep 30" 20s BashExec "$(call_json timeout -k 1 2 sleep 30)"
probe "35 an arg with a shell token moves the call to bash -lc, which drops args" 20s BashExec \
  "$(call_json timeout -k 1 2 sh -c 'echo A; sleep 30')"

echo
echo "--- where GNU timeout is absent ---"
PROBE_PATH="$D/bin_none" probe "36 direct arm, PATH without timeout" 20s BashExec \
  "$(call_json timeout -k 1 2 sleep 30)"
probe "37 bash -lc arm, wrapper binary absent (named motoko-w0b-no-timeout)" 20s BashExec \
  "$(call_json "motoko-w0b-no-timeout -k 1 2 bash -c 'touch m37; echo RAN'")"
echo "    m37 (did the command run?): $(marker m37)"
PROBE_PATH="$D/bin_g" probe "38 direct arm, PATH with gtimeout only (Homebrew on macOS)" 20s BashExec \
  "$(call_json gtimeout -k 1 2 sleep 30)"

echo
echo "--- case A (exit 0, a child holds the pipe) ---"
probe "39 case A, no wrapper" 20s BashExec \
  "$(call_json 'echo DONE; touch m39fg; (sleep 9; touch m39bg) & exit 0')"
echo "    m39fg at render: $(marker m39fg)   m39bg: $(marker m39bg)"
probe "40 case A under the wrapper" 20s BashExec \
  "$(call_json "timeout -k 1 2 bash -c 'echo DONE; touch m40fg; (sleep 9; touch m40bg) & exit 0'")"
echo "    m40fg at render: $(marker m40fg)   m40bg: $(marker m40bg)"
probe "41 case A under the wrapper, exit 7 (the #1879 contrast)" 20s BashExec \
  "$(call_json "timeout -k 1 2 bash -c 'echo DONE; (sleep 9; touch m41bg) & exit 7'")"

echo
echo "--- the clamp, RunTests, and the output limit ---"
probe "42 wrapper deadline above the wall (10 s vs 3 s)" 3s BashExec \
  "$(call_json "timeout -k 1 10 bash -c '$S; sleep 120.42'")"
echo "    at render: the wrapped command (sleep 120.42) $(alive 'sleep 120.42'); its timeout process $(alive '^timeout -k 1 10 ')"
probe "43 deadline under the wall, deadline + grace over it (3+2 s vs 4 s), TERM ignored" 4s BashExec \
  "$(call_json "timeout -k 2 3 bash -c 'trap \"\" TERM; $S; sleep 120.43'")"
echo "    at render: the wrapped command (sleep 120.43) $(alive 'sleep 120.43'); its timeout process $(alive '^timeout -k 2 3 ')"
probe "44 RunTests, wrapper deadline" 20s RunTests \
  "$(call_json "timeout -k 1 2 bash -c '$S; sleep 30'")"
probe "45 wrapper deadline 5 s, output passes a 1,000-byte limit first" 20s BashExec \
  "$(call_json "timeout -k 1 5 bash -c 'head -c 5000 /dev/zero; touch m45; exit 0'")" --process-max-output 1000
echo "    m45: $(marker m45)"

echo
echo "waiting 10 s for work that outlived its result..."
sleep 10
echo "    m22   (case 22, no wrapper):          $(marker m22)"
echo "    m25   (case 25, wrapper deadline):    $(marker m25)"
echo "    m39bg (case 39, case A):              $(marker m39bg)"
echo "    m40bg (case 40, case A under wrapper): $(marker m40bg)"
echo "    m41bg (case 41):                       $(marker m41bg)"
echo "    case 42 (deadline above the wall):          sleep 120.42 $(alive 'sleep 120.42'), its timeout $(alive '^timeout -k 1 10 ')"
echo "    case 43 (deadline + grace over the wall):   sleep 120.43 $(alive 'sleep 120.43'), its timeout $(alive '^timeout -k 2 3 ')"
pkill -KILL -f 'sleep 120[.]4[23]|^timeout -k (1 10|2 3) ' 2>/dev/null
