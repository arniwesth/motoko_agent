#!/usr/bin/env python3
"""031 PLAN-001 P1.6r: read the root ailang.lock the way the repo's own reader does.

`scripts/eval/journal_replay.sh` collects `abi_version` from
packages/motoko-ext-abi/ailang.toml (identities.json) and, independently,
`lock_abi_version` as `sunholo/motoko_ext_abi`'s version in ailang.lock
(comparators.json); A9b in src/eval/journal/admission.ail compares the two.
`ailang check` does NOT read a lock entry's version (measured: a lock with the ABI
entry set back to 7.4 still checks clean), so this is the check that reads it:

  1. lock_abi_version == the ABI package's declared version (journal_replay's two reads);
  2. every path entry's version equals its own package's ailang.toml `version`;
  3. no entry names a package the root ailang.toml does not reach (the stale
     `sunholo/motoko_core` entry the 7.4 lock carried).

Exit 0 green, 1 red. Run from a repo root.
"""
import json
import os
import re
import sys

root = os.getcwd()
lock = json.load(open(os.path.join(root, "ailang.lock"), encoding="utf-8"))
toml = open(os.path.join(root, "ailang.toml"), encoding="utf-8").read()
bad = []

abi_toml = open(os.path.join(root, "packages/motoko-ext-abi/ailang.toml"), encoding="utf-8").read()
declared = re.search(r'^version\s*=\s*"([^"]+)"', abi_toml, re.M).group(1)
abi = [p.get("version", "") for p in lock["packages"] if p["name"] == "sunholo/motoko_ext_abi"]
if abi != [declared]:
    bad.append(f"lock_abi_version {abi} != packages/motoko-ext-abi/ailang.toml version {declared!r}")
else:
    print(f"  ✓ lock_abi_version {abi[0]} == the ABI package's declared version")

deps = set(re.findall(r'^"([^"]+)"\s*=', toml, re.M))
for p in lock["packages"]:
    if p["name"] not in deps:
        bad.append(f"{p['name']} is in the lock and not a dependency of the root ailang.toml")
    if p.get("source") != "path":
        continue
    # the path is absolute to wherever the lock was generated; read the package by the
    # root toml's relative path so a clone or workspace reads its own copy
    m = re.search(r'^"%s"\s*=\s*\{\s*path\s*=\s*"([^"]+)"' % re.escape(p["name"]), toml, re.M)
    if not m:
        bad.append(f"{p['name']}: no path dependency in the root ailang.toml")
        continue
    t = open(os.path.join(root, m.group(1), "ailang.toml"), encoding="utf-8").read()
    v = re.search(r'^version\s*=\s*"([^"]+)"', t, re.M).group(1)
    if v != p.get("version"):
        bad.append(f"{p['name']}: lock {p.get('version')!r} != {m.group(1)}/ailang.toml {v!r}")
if bad:
    for b in bad:
        print(f"  ✗ {b}")
    print("p16r lock: RED")
    sys.exit(1)
print(f"  ✓ {len(lock['packages'])} entries, every path entry at its package's declared version")
print("p16r lock: GREEN")
