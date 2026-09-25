#!/usr/bin/env bash
# 031 PLAN-001 P1.2b (ADR-001 Amendment 2): check each named package AS ITS OWN ROOT, with
# ITS OWN ailang.toml -- its [effects].max ceiling and its ABI `version` pin enforced --
# against THIS checkout's ABI package, in a throwaway workspace (never the tracked lock).
# Run from a repo root (the primary, a clone, or a mutgate throwaway):
#   p12b_pkgroot.sh <pkg-dir>...     e.g. motoko-ext-repetition-guard; exit 1 if any fails
#
# Adapted from evidence/P1.2a/p12a_pkgroot.sh (itself from evidence/amendment-2/pkgcheck.sh).
# The cwd's WORKING files of the package are copied, so a mutation in a throwaway is what
# gets checked. Two batch-B differences, both read from COMMITTED HEAD (`git show`), never
# from another part's working tree (PLAN-001 §0 item 13):
#   * a non-ABI path dependency (exa-search -> motoko-ext-mcp, batch C's package) is copied
#     from HEAD and re-pointed inside the workspace;
#   * a package that imports `src/core/...` without declaring it (motoko_scratchpad) gets
#     HEAD's src/core under the workspace package root, where the loader resolves `src/`.
#     Then only the package's OWN modules are checked (`ailang check <file>`), not src/core.
#     A module that reaches core's dispatch (ws_loopback -> tool_envelope_dispatch ->
#     ext/registry_generated -> every extension) cannot load as a package root at all --
#     the registry imports this very package. P12B_ROOT_SKIP names such modules; they
#     are checked in the core workspace instead (p12b_core_check.sh) and the skip is printed.
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <pkg-dir>..." >&2; exit 2; }
fail=0
for P in "$@"; do
  T=$(mktemp -d "${TMPDIR:-/tmp}/p12broot.XXXXXX")
  mkdir -p "$T/motoko-ext-abi" "$T/pkg"
  cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/motoko-ext-abi/"
  cp packages/$P/*.ail packages/$P/ailang.toml "$T/pkg/"
  deps=$(python3 - "$T/pkg/ailang.toml" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read(); indeps = False; out = []; other = []
for line in s.splitlines():
    t = line.strip()
    if t.startswith('['): indeps = (t == '[dependencies]')
    if indeps and 'path' in line:
        if 'motoko_ext_abi' in line:
            line = re.sub(r'path = "[^"]*"', 'path = "../motoko-ext-abi"', line)
        else:
            m = re.search(r'path = "\.\./([^"]*)"', line)
            other.append(m.group(1))
            line = re.sub(r'path = "[^"]*"', 'path = "../%s"' % m.group(1), line)
    out.append(line)
open(p, 'w').write("\n".join(out) + "\n")
print(" ".join(other))
PY
)
  for d in $deps; do
    mkdir -p "$T/$d"
    for f in $(git ls-tree --name-only HEAD packages/$d/); do
      b=$(basename "$f"); case $b in *.ail|ailang.toml) git show HEAD:"$f" > "$T/$d/$b";; esac
    done
    sed -i -E 's#("sunholo/motoko_ext_abi" = \{ path = )"[^"]*"#\1"../motoko-ext-abi"#' "$T/$d/ailang.toml"
  done
  core=0
  if grep -lqE '^import src/core/' packages/$P/*.ail 2>/dev/null; then
    core=1
    git archive HEAD src/core | tar -x -C "$T/pkg"
  fi
  ( cd "$T/pkg" && ailang lock ) > "$T/lock.log" 2>&1 \
    || { tail -4 "$T/lock.log"; echo "p12b: $P own-root lock FAILED"; fail=1; rm -rf "$T"; continue; }
  if [ $core -eq 1 ]; then
    ( cd "$T/pkg" && export AILANG_RELAX_MODULES=1 && rc=0 && for m in *.ail; do case " ${P12B_ROOT_SKIP:-} " in *" $m "*) echo "SKIPPED $m";; *) ailang check "$m" || rc=1;; esac; done; exit $rc ) > "$T/out.txt" 2>&1; rc=$?
  else
    ( cd "$T/pkg" && AILANG_RELAX_MODULES=1 ailang check . ) > "$T/out.txt" 2>&1; rc=$?
  fi
  max=$(sed -nE 's/^max = \[(.*)\]/\1/p' packages/$P/ailang.toml | tr -d '" ')
  extra=""; [ -n "$deps" ] && extra=" deps@HEAD=[$deps]"; [ $core -eq 1 ] && extra="$extra src/core@HEAD"; [ $core -eq 1 ] && [ -n "${P12B_ROOT_SKIP:-}" ] && extra="$extra skipped=[${P12B_ROOT_SKIP}]"
  if [ $rc -eq 0 ]; then echo "p12b: $P own root ok (max=[$max])$extra"
  else
    sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$T/out.txt" | grep -E "effect ceiling|Error|•|Missing|unif" | cut -c1-300 | head -10
    echo "p12b: $P own root FAILED (exit $rc; max=[$max])$extra"; fail=1
  fi
  rm -rf "$T"
done
exit $fail
