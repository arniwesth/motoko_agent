#!/usr/bin/env bash
# What `std/process.exec` returns to Motoko for a command that overruns its
# deadline or its output limit, and whether the command's effects still land.
# Evidence for NOTE-scope-effect-unknown-tool-faults.md §6. Not a gate.
#
#   bash .agent/projects/034_ambiguous_tool_outcomes/evidence/exec_probe.sh
#
# Runs in a temp dir and touches nothing in the repo. Takes about 40 s.
# Needs `ailang` on PATH and, for cases 5-7, GNU coreutils `timeout`.
set -u

D=$(mktemp -d)
cd "$D" || exit 1
export AILANG_FS_SANDBOX="$D"

# $1: the argument list of exec(...), as AILANG source.
write_probe() {
  cat > exec_probe.ail <<EOF
module exec_probe

import std/io (println)
import std/process (exec, ProcessError, ProcessOutput)
import std/bytes (toString)
import std/string (length)
import std/result (Result, Ok, Err)

func err_str(err: ProcessError) -> string {
  match err {
    NotAllowed(cmd) => "NotAllowed(\${cmd})",
    NotFound(cmd) => "NotFound(\${cmd})",
    PermissionDenied(cmd) => "PermissionDenied(\${cmd})",
    Timeout(ms) => "Timeout(\${show(ms)})",
    OutputLimitExceeded(n) => "OutputLimitExceeded(\${show(n)})",
    SpawnFailed(msg) => "SpawnFailed(\${msg})",
    AbnormalExit(sig, name) => "AbnormalExit(\${show(sig)}, \${name})"
  }
}

export func main() -> () ! {IO, Process} {
  match exec($1) {
    Ok(out) => println("Ok exit=\${show(out.exitCode)} truncated=\${show(out.truncated)} stdout_len=\${show(length(toString(out.stdout)))} stderr_len=\${show(length(toString(out.stderr)))}"),
    Err(e) => println("Err \${err_str(e)}")
  }
}
EOF
}

# $1: label, $2: exec argument list, rest: `ailang run` flags.
probe() {
  local label=$1 call=$2
  shift 2
  write_probe "$call"
  local start end
  start=$(date +%s%3N)
  local out
  out=$(timeout 90 ailang run --caps IO,Process "$@" --entry main exec_probe.ail 2>&1 | tail -1)
  end=$(date +%s%3N)
  printf '%-34s %s  (returned after %sms)\n' "$label" "$out" "$((end - start))"
}

marker() { if [ -e "$1" ]; then echo present; else echo absent; fi; }

ailang --version 2>&1 | head -1
timeout --version 2>&1 | head -1
echo

probe "1 non-zero exit (control)" \
  '"bash", ["-lc", "echo out; echo err >&2; exit 3"]'

probe "2 deadline, output already printed" \
  '"bash", ["-lc", "echo PARTIAL; sleep 30"]' --process-timeout 2s

probe "3 deadline, work still running" \
  '"bash", ["-lc", "echo PARTIAL; (sleep 8; touch m_late) >/dev/null 2>&1 & sleep 30"]' --process-timeout 2s
echo "    m_late when exec returned: $(marker m_late)"

probe "4 over the output limit" \
  '"bash", ["-lc", "head -c 5000 /dev/zero; touch m_over; exit 0"]' --process-max-output 1000
echo "    m_over: $(marker m_over)"

probe "5 case 3 under timeout(1)" \
  '"timeout", ["-k", "1", "2", "bash", "-lc", "echo PARTIAL; echo ERRLINE >&2; (sleep 8; touch m_group) >/dev/null 2>&1 & sleep 30"]' --process-timeout 20s

probe "6 case 5, child calls setsid" \
  '"timeout", ["-k", "1", "2", "bash", "-lc", "echo PARTIAL; setsid bash -c \"sleep 8; touch m_setsid\" >/dev/null 2>&1 & sleep 30"]' --process-timeout 20s

probe "7 case 4 under timeout(1)" \
  '"timeout", ["-k", "1", "5", "bash", "-lc", "head -c 5000 /dev/zero; touch m_over2; exit 0"]' --process-timeout 20s --process-max-output 1000
echo "    m_over2: $(marker m_over2)"

# Cases 8-12: which ProcessError arms mean "never started". ADR-001 §0 cases A-D.
probe "8 exit 0, child holds the pipe" \
  '"bash", ["-lc", "echo DONE; touch m_fg; (sleep 9; touch m_bg) & exit 0"]' --process-timeout 20s
echo "    m_fg when exec returned: $(marker m_fg)   m_bg: $(marker m_bg)"

probe "9 case 8, child off the pipe" \
  '"bash", ["-lc", "echo DONE; touch m_fg2; (sleep 9; touch m_bg2) >/dev/null 2>&1 & exit 0"]' --process-timeout 20s

probe "10 no such command" \
  '"definitely-not-a-command-034", []'

printf '#!/bin/sh\ntouch m_noexec\n' > noexec.sh
chmod 644 noexec.sh
probe "11 file without the exec bit" \
  '"./noexec.sh", []'
echo "    m_noexec: $(marker m_noexec)"

probe "12 command kills itself" \
  '"bash", ["-lc", "touch m_sig; kill -9 $$"]'
echo "    m_sig: $(marker m_sig)"

echo
echo "waiting 10 s for work that outlived its result..."
sleep 10
echo "    m_late   (case 3, no wrapper):        $(marker m_late)"
echo "    m_group  (case 5, timeout wrapper):   $(marker m_group)"
echo "    m_setsid (case 6, wrapper + setsid):  $(marker m_setsid)"
echo "    m_bg     (case 8, exit 0):            $(marker m_bg)"
