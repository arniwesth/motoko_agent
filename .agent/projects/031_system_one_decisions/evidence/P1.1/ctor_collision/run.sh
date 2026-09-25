#!/usr/bin/env bash
# 031 P1.1: the constructor-collision probe, re-runnable. Copies this directory
# to a temp workspace, locks it, and checks the six consumers. Run from anywhere.
set -uo pipefail
H=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/p11ctor.XXXXXX"); trap 'rm -rf "$T"' EXIT
cp -r "$H/." "$T/"; rm -rf "$T/.ailang"; cd "$T"
ailang lock > /dev/null 2>&1
for m in no_abi ports_first abi_first abi_first_named both both_named; do
  printf '%-16s ' "$m"
  out=$(ailang check "src/core/$m.ail" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then echo "clean"
  else echo "FAIL: $(echo "$out" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -E 'Error' | head -1 | cut -c1-200)"; fi
done
