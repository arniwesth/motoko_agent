#!/usr/bin/env bash
# pkgcheck.sh <rev> <pkg>: check one package with ITS OWN ailang.toml (effects ceiling included)
# against the ABI at <rev>, in a throwaway workspace (no primary lock).
set -u
REV=$1; PKG=$2; R=/workspaces/motoko_agent
T=$(mktemp -d "${TMPDIR:-/tmp}/pkgck.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/abi" "$T/pkg"
git -C $R show $REV:packages/motoko-ext-abi/types.ail > "$T/abi/types.ail"
git -C $R show $REV:packages/motoko-ext-abi/ailang.toml > "$T/abi/ailang.toml"
for f in $(git -C $R ls-tree --name-only $REV packages/motoko-ext-$PKG/); do
  b=$(basename $f); case $b in *.ail|ailang.toml) git -C $R show $REV:$f > "$T/pkg/$b";; esac; done
# point the ABI dependency at the workspace copy; drop other path deps (core etc.)
python3 - "$T/pkg/ailang.toml" "$T/abi" <<'PY'
import re,sys
p,abi=sys.argv[1],sys.argv[2]; s=open(p).read()
out=[]; indeps=False
for line in s.splitlines():
    if line.strip().startswith('['): indeps = line.strip()=='[dependencies]'
    if indeps and '=' in line and 'motoko_ext_abi' in line:
        line='"sunholo/motoko_ext_abi" = { path = "%s" }'%abi
    elif indeps and 'path' in line and 'motoko_ext_abi' not in line:
        continue
    out.append(line)
open(p,'w').write("\n".join(out)+"\n")
PY
cd "$T/pkg" && ailang lock >/dev/null 2>&1
out=$(AILANG_RELAX_MODULES=1 ailang check . 2>&1); rc=$?
echo "$REV $PKG rc=$rc $(echo "$out" | grep -E "•|effect ceiling" | sed "s#^ *##" | cut -c1-170 | tr "\n" "|")"
