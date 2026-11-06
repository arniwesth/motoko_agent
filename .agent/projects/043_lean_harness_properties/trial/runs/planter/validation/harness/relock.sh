#!/usr/bin/env bash
# Compute the content hashes the seeded tree's packages have, as `ailang lock` would write them.
set -euo pipefail
P=/home/motoko/trial-043/planter; W=$P/work; cd $W
python3 -I tools/make_patches.py base $P            # seeds.patch without the lock hunk
rm -rf locktmp; mkdir locktmp; (cd base && tar --exclude=./src/tui/node_modules -cf - .) | tar -xf - -C locktmp
(cd locktmp && patch -s -p1 < $P/seeds.patch && ailang lock >/dev/null 2>&1)
python3 -I - <<'PY'
import json
b=json.load(open('/home/motoko/trial-043/planter/work/base/ailang.lock')); s=json.load(open('/home/motoko/trial-043/planter/work/locktmp/ailang.lock'))
r=json.load(open('/home/motoko/trial-043/planter/work/locktmp0/ailang.lock'))
B={p['name']:p.get('content_hash') for p in b['packages']}; S={p['name']:p.get('content_hash') for p in s['packages']}; R={p['name']:p.get('content_hash') for p in r['packages']}
m={B[n]:S[n] for n in B if B[n]!=S[n] and B[n]==R[n]}   # changed by the seeds, and fresh at base
json.dump(m, open('/home/motoko/trial-043/planter/work/tools/lock_hashes.json','w'), indent=1); print(len(m), "package hashes")
PY
python3 -I tools/make_patches.py base $P --with-lock
rm -rf locktmp
