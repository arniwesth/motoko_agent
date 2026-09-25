#!/usr/bin/env bash
# P1.2b observation on the pin: does binding a payload IMPORTED from another module make the
# registering function's effect check demand the payload's row? ABI from committed HEAD, lock-free.
set -uo pipefail
R=$(pwd); D=$R/.agent/projects/031_system_one_decisions/evidence/P1.2b/import_leak_probe
T=$(mktemp -d "${TMPDIR:-/tmp}/p12bleak.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/abi" "$T/pkg"
git show HEAD:packages/motoko-ext-abi/types.ail > "$T/abi/types.ail"; git show HEAD:packages/motoko-ext-abi/ailang.toml > "$T/abi/ailang.toml"
for f in handler reg_imported reg_local; do sed "s/@V@/leak/g" "$D/$f.ail" > "$T/pkg/$f.ail"; done
printf '[package]\nname = "local/leak"\nversion = "0.1.0"\nedition = "1"\nailang = ">=0.33.0"\n[dependencies]\n"sunholo/motoko_ext_abi" = { path = "../abi" }\n[effects]\nmax = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]\n' > "$T/pkg/ailang.toml"
cd "$T/pkg" && ailang lock >/dev/null 2>&1
echo "ABI at $(git -C "$R" rev-parse --short HEAD); $(ailang --version 2>&1 | head -1)"
for m in reg_local reg_imported; do
  AILANG_RELAX_MODULES=1 ailang check $m.ail > out.txt 2>&1; rc=$?
  echo "$m: ailang check exit $rc"; sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' out.txt | grep -E 'Missing effects|Current signature' | head -2
done
