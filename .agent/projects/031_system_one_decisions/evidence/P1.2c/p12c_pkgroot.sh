#!/usr/bin/env bash
# 031 PLAN-001 P1.2c (ADR-001 Amendment 2): check each named package AS ITS OWN ROOT, with
# ITS OWN ailang.toml -- so its [effects].max ceiling and its ABI version pin are enforced --
# in a throwaway workspace. Run from a repo root (the primary, a clone, or a mutgate throwaway):
#   p12c_pkgroot.sh <pkg-dir>...     e.g. motoko-ext-mcp; exit 1 if any package fails
#
# Adapted from evidence/P1.2a/p12a_pkgroot.sh (itself from evidence/amendment-2/pkgcheck.sh).
# Differences, each for a reason:
#  - THE ABI COMES FROM COMMITTED HEAD (`git show HEAD:`), never the working tree (PLAN-001
#    §0 item 13: check against committed state; other parts share this checkout). The package
#    under test is the cwd's WORKING copy, so a mutation applied in a throwaway is what gets
#    checked.
#  - A PATH DEPENDENCY ON ANOTHER in-tree PACKAGE is allowed when it is one of batch C's own
#    (motoko-ext-ailang-docs depends on motoko-ext-mcp): that package's working .ail files and
#    manifest are copied beside it and the path re-pointed, KEEPING any `version` constraint.
#    Any other path dependency fails the run.
#  - Subdirectories are not copied: none of batch C's packages has .ail files below its root
#    (mcp's assets/ holds a .mjs, which `ailang check` does not read).
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <pkg-dir>..." >&2; exit 2; }
git rev-parse HEAD >/dev/null 2>&1 || { echo "p12c: not in a git repo" >&2; exit 2; }
OWN="motoko-ext-a2a motoko-ext-agentcli motoko-ext-ailang-docs motoko-ext-mcp motoko-ext-compaction-ai"
fail=0
for P in "$@"; do
  T=$(mktemp -d "${TMPDIR:-/tmp}/p12croot.XXXXXX")
  mkdir -p "$T/motoko-ext-abi" "$T/$P"
  git show HEAD:packages/motoko-ext-abi/types.ail > "$T/motoko-ext-abi/types.ail"
  git show HEAD:packages/motoko-ext-abi/ailang.toml > "$T/motoko-ext-abi/ailang.toml"
  cp packages/$P/*.ail packages/$P/ailang.toml "$T/$P/"
  bad=0
  for toml in "$T/$P/ailang.toml"; do
    python3 - "$toml" "$OWN" > "$T/deps.txt" <<'PY' || bad=1
import re, sys
p, own = sys.argv[1], sys.argv[2].split(); s = open(p).read(); indeps = False; out = []; bad = False
for line in s.splitlines():
    t = line.strip()
    if t.startswith('['): indeps = (t == '[dependencies]')
    if indeps and 'path' in line:
        m = re.search(r'path = "([^"]*)"', line); dep = m.group(1).rstrip('/').split('/')[-1]
        if dep == 'motoko-ext-abi' or dep in own:
            line = re.sub(r'path = "[^"]*"', 'path = "../%s"' % dep, line)
            if dep != 'motoko-ext-abi': print(dep)
        else:
            bad = True
    out.append(line)
open(p, 'w').write("\n".join(out) + "\n")
sys.exit(1 if bad else 0)
PY
  done
  [ $bad -eq 0 ] || { echo "p12c: $P manifest has a path dependency outside the ABI and batch C"; fail=1; rm -rf "$T"; continue; }
  for D in $(cat "$T/deps.txt"); do
    mkdir -p "$T/$D"; cp packages/$D/*.ail packages/$D/ailang.toml "$T/$D/"
    python3 - "$T/$D/ailang.toml" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r'path = "[^"]*motoko-ext-abi"', 'path = "../motoko-ext-abi"', s)
open(p, 'w').write(s)
PY
  done
  ( cd "$T/$P" && ailang lock ) > "$T/lock.log" 2>&1 \
    || { tail -4 "$T/lock.log"; echo "p12c: $P own-root lock FAILED"; fail=1; rm -rf "$T"; continue; }
  ( cd "$T/$P" && AILANG_RELAX_MODULES=1 ailang check . ) > "$T/out.txt" 2>&1; rc=$?
  max=$(sed -nE 's/^max = \[(.*)\]/\1/p' packages/$P/ailang.toml | tr -d '" ')
  if [ $rc -eq 0 ]; then echo "p12c: $P own root ok (max=[$max])"
  else
    sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$T/out.txt" | grep -E "effect ceiling|Error|error|•" | cut -c1-300 | head -10
    echo "p12c: $P own root FAILED (exit $rc; max=[$max])"; fail=1
  fi
  rm -rf "$T"
done
exit $fail
