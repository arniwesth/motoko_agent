#!/usr/bin/env bash
# 031 PLAN-001 P1.2a follow-up (ADR-001 Amendment 2): check each named package AS ITS OWN
# ROOT, with ITS OWN ailang.toml -- so its [effects].max ceiling and its ABI version pin are
# enforced -- against THIS checkout's ABI package, in a throwaway workspace. Run from a repo
# root (the primary, a clone, or a mutgate throwaway):
#   p12a_pkgroot.sh <pkg-dir>...     e.g. motoko-ext-omnigraph; exit 1 if any package fails
#
# Adapted from evidence/amendment-2/pkgcheck.sh (which reads a git revision of the primary):
# this one copies the cwd's WORKING files, so a mutation applied in a throwaway is what gets
# checked. The ABI dependency is re-pointed at the workspace copy KEEPING its `version`
# constraint; the package's own [effects] and everything else in its manifest are untouched.
# No other path dependency exists in the six batch-A packages (compaction-structural's
# motoko_core dependency went in P1.2a attempt 1); any that appears fails the run.
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <pkg-dir>..." >&2; exit 2; }
fail=0
for P in "$@"; do
  T=$(mktemp -d "${TMPDIR:-/tmp}/p12aroot.XXXXXX")
  mkdir -p "$T/motoko-ext-abi" "$T/pkg"
  cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/motoko-ext-abi/"
  cp packages/$P/*.ail packages/$P/ailang.toml "$T/pkg/"
  python3 - "$T/pkg/ailang.toml" <<'PY' || { echo "p12a: $P manifest has a path dependency other than the ABI"; fail=1; rm -rf "$T"; continue; }
import re, sys
p = sys.argv[1]; s = open(p).read(); indeps = False; out = []; bad = False
for line in s.splitlines():
    t = line.strip()
    if t.startswith('['): indeps = (t == '[dependencies]')
    if indeps and 'path' in line:
        if 'motoko_ext_abi' in line:
            line = re.sub(r'path = "[^"]*"', 'path = "../motoko-ext-abi"', line)
        else:
            bad = True
    out.append(line)
open(p, 'w').write("\n".join(out) + "\n")
sys.exit(1 if bad else 0)
PY
  ( cd "$T/pkg" && ailang lock ) > "$T/lock.log" 2>&1 \
    || { tail -4 "$T/lock.log"; echo "p12a: $P own-root lock FAILED"; fail=1; rm -rf "$T"; continue; }
  ( cd "$T/pkg" && AILANG_RELAX_MODULES=1 ailang check . ) > "$T/out.txt" 2>&1; rc=$?
  max=$(sed -nE 's/^max = \[(.*)\]/\1/p' packages/$P/ailang.toml | tr -d '" ')
  if [ $rc -eq 0 ]; then echo "p12a: $P own root ok (max=[$max])"
  else
    sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$T/out.txt" | grep -E "effect ceiling|Error|•" | cut -c1-260 | head -8
    echo "p12a: $P own root FAILED (exit $rc; max=[$max])"; fail=1
  fi
  rm -rf "$T"
done
exit $fail
