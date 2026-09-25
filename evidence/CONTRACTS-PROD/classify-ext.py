#!/usr/bin/env python3
"""ADR-001 §1's two probes (TAUT / DETERMINE), run against a file that
`classify.py`'s own glob does not reach.

`classify.py:collect()` and `verify_core` both walk `src/core/*.ail` — FLAT —
so nothing under `src/core/ext/` is classified or pinned in contracts.register.
This runs the same machinery on one named file so a contract living there can
still be shown substantive rather than asserted to be.

Usage: evidence/CONTRACTS-PROD/classify-ext.py src/core/ext/runtime.ail
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/verify_classify"))
import classify as C  # noqa: E402

path = ROOT / sys.argv[1]
contracts = C.scan(path)
if not contracts:
    sys.exit(f"no contracts in {path}")

real = C.verdicts(path, {c.name for c in contracts})
for c in contracts:
    v = real.get(c.name)
    if v and v[0] == "VERIFIED":
        c.solve_ms = v[1]

# NOTE: probe_source names the module after `path.stem`, so the probe FILE must
# be `<stem>_probe.ail` or ailang rejects the module/path mismatch. That stem is
# also why this helper takes one file at a time: `src/core/foo.ail` and
# `src/core/ext/foo.ail` would collide on it (see contracts.md).
probe = C.GEN / f"{path.stem}_probe.ail"
probe.write_text(C.probe_source(path, contracts))
got = C.verdicts(probe, {n for c in contracts for n in (f"taut_{c.name}", f"det_{c.name}")})
probe.unlink(missing_ok=True)

for c in contracts:
    c.taut = got[f"taut_{c.name}"][0]
    c.det = got[f"det_{c.name}"][0]
C.classify(contracts)
for c in contracts:
    print(f"  {c.cls:16} {c.name}  (taut={c.taut}, det={c.det}, solve={c.solve_ms}ms)")
