#!/usr/bin/env python3
"""031 PLAN-001 P0.6, exit check 3: P0.3's registration-shape gate over the
example package.

This is `hook_scope.py`'s own registration-shape pass -- `Scope.locate()` then
`Scope.registration_shape_result()`, the field `make ext_hook_scope` exits on
(ADR-001 D2 "The gate") -- pointed at each example consumer's module in
`packages/motoko_ext_conformance/examples/` instead of an extension's
`register.ail`. The closure is built with the tree's own resolver
(`ext_ambient_inventory/derive.py`'s `module_resolver` and `closure`, through
the root `ailang.toml`), exactly as `make ext_hook_scope` builds it, so the
ABI 8.0 package is in each closure. Nothing is compiled: the result is textual.

Pass criterion per consumer: shape `pass`, head `config-caps`, the expected
atom count, zero shape rejections. `scripted_backend.ail` is the runner, not a
registration, and is not scanned.

TWO-SIDED CONTROL, in the same run: each consumer is re-scanned from a
temporary copy (beside the original, so every import resolves identically)
whose first payload is replaced by an inline lambda over the same callback; the
gate must FAIL that copy with `payload-inline-lambda`. A pass that the control
cannot turn into a fail is not evidence.

Run from a repo root. Exit 0 only when every pin holds.
"""
import importlib.util
import re
import sys
from pathlib import Path

REPO = Path(".").resolve()
TOOLS = REPO / "tools" / "ext_ambient_inventory"
EXAMPLES = REPO / "packages" / "motoko_ext_conformance" / "examples"

# consumer module -> (atom count, the first payload name, the lambda arity)
CONSUMERS = {
    "completion_guard": (1, "completion_prepare", "\\c k. completion_prepare(c, k)"),
    "repeat_failure_policy": (1, "repeat_prepare", "\\c k. repeat_prepare(c, k)"),
    "config_catalog": (1, "describe_tools", "\\cfg. describe_tools(cfg)"),
}


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def scan(hs, c3, root: Path):
    resolve = c3.module_resolver(REPO)
    mods, _residue = c3.closure(root, resolve)
    sc = hs.Scope(root.stem, root, mods, REPO, resolve)
    sc.locate()
    res = sc.registration_shape_result()
    reasons = sorted({r.shape for r in sc.shape_rejections})
    return res, reasons, len(sc.atoms), mods


def main() -> int:
    sys.path.insert(0, str(TOOLS))
    c3 = load("p06_c3", TOOLS / "derive.py")
    hs = load("p06_hook_scope", TOOLS / "hook_scope.py")
    fails, passed = [], 0
    for name, (atoms, payload, lam) in CONSUMERS.items():
        root = EXAMPLES / f"{name}.ail"
        res, reasons, n, mods = scan(hs, c3, root)
        abi_in = any(m.name == "types.ail" and "motoko-ext-abi" in str(m) for m in mods)
        ok = (res["result"] == "pass" and res.get("head") == "config-caps"
              and n == atoms and not reasons and abi_in)
        print(f"  {'ok  ' if ok else 'FAIL'} {name:<24} shape={res['result']} head={res.get('head')} "
              f"atoms={n} reasons={reasons or '-'} closure={len(mods)} (ABI in closure: {abi_in})")
        if ok:
            passed += 1
        else:
            fails.append(name)

        # the control: same module, first payload inlined
        text = root.read_text()
        bound = re.compile(rf"(\(|, ){re.escape(payload)}(,|\))")
        mutated, k = bound.subn(lambda m: f"{m.group(1)}{lam}{m.group(2)}", text, count=1)
        ctrl = EXAMPLES / f"_p06_control_{name}.ail"
        try:
            ctrl.write_text(mutated)
            cres, creasons, _, _ = scan(hs, c3, ctrl)
        finally:
            ctrl.unlink(missing_ok=True)
        cok = k == 1 and cres["result"] == "fail" and "payload-inline-lambda" in creasons
        print(f"  {'ok  ' if cok else 'FAIL'} {name:<24} control (payload `{payload}` inlined): "
              f"shape={cres['result']} reasons={creasons or '-'}")
        if not cok:
            fails.append(f"{name}: control")
    print(f"\nshape gate on the examples: pass {passed}/{len(CONSUMERS)}; "
          f"controls {len(CONSUMERS) - sum(1 for f in fails if f.endswith('control'))}/{len(CONSUMERS)} rejected")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
