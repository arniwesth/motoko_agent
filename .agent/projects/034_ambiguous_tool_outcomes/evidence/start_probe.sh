#!/usr/bin/env bash
# Which `std/process.exec` error arms are returned before the target program
# runs: `NotAllowed` and `PermissionDenied`. Cases 13-21, continuing
# exec_probe.sh's numbering. Evidence for ADR-001 D2 and its rulings
# (2026-10-17). Not a gate.
#
#   bash .agent/projects/034_ambiguous_tool_outcomes/evidence/start_probe.sh
#
# Runs in a temp dir and touches nothing in the repo. Takes about 10 s.
# DEBUG_PROCESS=1 makes AILANG print `[process] start` just before it launches
# a process and the raw Go error after it, so a case with no start line was
# refused before any launch.
set -u

D=$(mktemp -d)
cd "$D" || exit 1
export AILANG_FS_SANDBOX="$D"
export DEBUG_PROCESS=1

# $1: the argument list of exec(...), as AILANG source.
write_probe() {
  cat > "$D/exec_probe.ail" <<EOF
module exec_probe

import std/io (println)
import std/process (exec, ProcessError, ProcessOutput)
import std/bytes (toString)
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
    Ok(out) => println("Ok exit=\${show(out.exitCode)} stderr=\${toString(out.stderr)}"),
    Err(e) => println("Err \${err_str(e)}")
  }
}
EOF
}

# $1: label, $2: exec argument list, rest: `ailang run` flags. Prints the
# launch trace and the result, with the temp dir shown as $D.
probe() {
  local label=$1 call=$2
  shift 2
  write_probe "$call"
  echo "== $label"
  timeout 60 ailang run --caps IO,Process "$@" --entry main "$D/exec_probe.ail" 2>&1 \
    | grep -E '^\[process\]|^Ok |^Err ' | sed "s|$D|\$D|g; s/^/    /"
}

marker() { if [ -e "$1" ]; then echo present; else echo absent; fi; }

ailang --version 2>&1 | head -1
echo

probe "13 NotAllowed: command not on the allowlist" \
  '"touch", ["m_na"]' --process-allowlist bash
echo "    m_na: $(marker m_na)"

probe "14 NotAllowed: subcommand chain does not match" \
  '"bash", ["-c", "touch m_na2"]' --process-allowlist 'bash:-x'
echo "    m_na2: $(marker m_na2)"

printf '#!/bin/sh\ntouch %s/m_pd1\n' "$D" > "$D/noexec2.sh"; chmod 644 "$D/noexec2.sh"
probe "15 allowlisted absolute path, mode-644 script" \
  "\"$D/noexec2.sh\", []" --process-allowlist "$D/noexec2.sh"
echo "    m_pd1: $(marker m_pd1)"

mkdir -p "$D/adir"
probe "16 allowlisted absolute path that is a directory" \
  "\"$D/adir\", []" --process-allowlist "$D/adir"

printf 'not a program\n' > "$D/interp"; chmod 644 "$D/interp"
printf '#!%s/interp\ntouch %s/m_pd3\n' "$D" "$D" > "$D/badinterp.sh"; chmod 755 "$D/badinterp.sh"
probe "17 script whose #! interpreter is mode 644" \
  "\"$D/badinterp.sh\", []"
echo "    m_pd3: $(marker m_pd3)"

printf '#!/bin/sh\ntouch %s/m_pd4\n' "$D" > "$D/xonly.sh"; chmod 111 "$D/xonly.sh"
probe "18 script with mode 111 (exec, no read)" \
  "\"$D/xonly.sh\", []"
echo "    m_pd4: $(marker m_pd4)"

cp /usr/bin/true "$D/xonly_bin"; chmod 111 "$D/xonly_bin"
probe "19 binary with mode 111" \
  "\"$D/xonly_bin\", []"

mkdir -p "$D/nox"; chmod 600 "$D/nox"
( export AILANG_FS_SANDBOX="$D/nox"
  probe "20 sandbox cwd with mode 600" \
    "\"bash\", [\"-c\", \"touch $D/m_pd5\"]" )
echo "    m_pd5: $(marker m_pd5)"

mkdir -p "$D/lock/inner"; chmod 000 "$D/lock"
( export AILANG_FS_SANDBOX="$D/lock/inner"
  probe "21 sandbox cwd under a mode-000 parent" \
    "\"bash\", [\"-c\", \"touch $D/m_pd6\"]" )
echo "    m_pd6: $(marker m_pd6)"

chmod 755 "$D/lock" "$D/nox"
