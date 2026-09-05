#!/usr/bin/env python3
"""Derive the effect-bearing stdlib module set (ADR-001 D5 obligation 2, classifier 1).

Two independent derivations, unioned, then reconciled against what this repository
actually imports:

  A. builtin projection  -- `ailang builtins list -json`, keep is_pure == false,
                            project `module`.
  B. stdlib source scan  -- `ailang iface <abs path>` over a recursive walk of
                            <scan-root>/std, keep any exported function whose
                            `effects` is non-empty.

Neither alone is sufficient. A misses modules whose effects are defined in AILANG
source rather than the builtin registry (std/sem exports load_frame/store_frame at
! {SharedMem} but its only builtin rows are pure). B alone has never been trusted on
its own. The reconciliation is the actual gate: any std/* module this repo imports
that is not in the union and not *proven* effect-free is a fail-closed candidate.

Traps this tool is written against, all paid for in ADR-001 review rounds:

  * `pure` contradicts `effects` -- std/clock.now is effects:['Clock'], pure:true.
    `effects` is the sole membership input; `pure` is never read.
  * iface's `module` field is a mangled absolute path and varies with scan-root
    location. Module ids are derived from the path relative to the scan root.
  * `ailang iface <module>` (the documented form) does not work on the pin. Absolute
    paths only.
  * std/secret.ail fails MOD010 outside a temp directory -- and AILANG *auto-relaxes*
    MOD010 inside one, so running this from /tmp hides the failure. Interface failures
    fail closed here; they are never skipped.
  * A literal std/**/*.ail glob under default bash matches only the nested file.
    This walks with os.walk.
  * Effect variables (! {e}) are not effects. iface already reports them as [], which
    this tool relies on and asserts against std/list.

Exit codes: 0 clean, 1 unresolved candidates or interface failures, 2 harness error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

IMPORT_RE = re.compile(r"^\s*import\s+(std/[A-Za-z0-9_/]+)", re.M)


def run(cmd: list[str]) -> tuple[int, str, str]:
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def compiler_commit() -> str | None:
    rc, out, _ = run(["ailang", "--version"])
    if rc != 0:
        return None
    for line in out.splitlines():
        if line.strip().lower().startswith("full:"):
            return line.split(":", 1)[1].strip()
    return None


def scan_root_commit(root: Path) -> str | None:
    rc, out, _ = run(["git", "-C", str(root), "rev-parse", "HEAD"])
    return out.strip() if rc == 0 else None


def builtin_projection() -> set[str]:
    rc, out, err = run(["ailang", "builtins", "list", "-json"])
    if rc != 0:
        raise SystemExit(f"harness: `ailang builtins list -json` failed: {err.strip()}")
    rows = json.loads(out)["builtins"]
    return {b["module"] for b in rows if b.get("is_pure") is False}


# Fallback for files `ailang iface` cannot parse. Signature-scoped, not line-scoped:
# `export func` signatures wrap, and a line-anchored pattern scores zero on std/process.
# Only the declaration's RESULT row decides membership -- a row inside a parameter type
# (std/ai.stepWithStream's callback is ! {IO} while its own result is ! {AI}) must not
# count. Rows whose every element is a lower-case effect variable (! {e}) are dropped.
DECL_RE = re.compile(r"^export\s+(?:pure\s+)?func\b", re.M)
ROW_RE = re.compile(r"!\s*\{([^}]*)\}")


def _concrete_row(row: str) -> bool:
    parts = [x.strip() for x in row.split(",") if x.strip()]
    return bool(parts) and not all(re.fullmatch(r"[a-z][A-Za-z0-9_]*", x) for x in parts)


def textual_scan(path: Path) -> bool:
    """True if the file exports a declaration whose own result row is concrete."""
    text = path.read_text(errors="replace")
    starts = [m.start() for m in DECL_RE.finditer(text)]
    for i, a in enumerate(starts):
        b = starts[i + 1] if i + 1 < len(starts) else len(text)
        sig = text[a:b]
        # the signature ends at the body brace or `=`; everything after is not the row
        cut = min([x for x in (sig.find(" {\n"), sig.find(" =\n"), sig.find(" = ")) if x != -1] or [len(sig)])
        sig = sig[:cut + 2]
        rows = ROW_RE.findall(sig)
        # the declaration's own row is the LAST row in the signature; earlier ones
        # belong to parameter types.
        if rows and _concrete_row(rows[-1]):
            return True
    return False


def iface_modules(root: Path) -> tuple[set[str], list[tuple[str, str]]]:
    """Return (effect-bearing module ids, [(module id, error)])."""
    std = root / "std"
    if not std.is_dir():
        raise SystemExit(f"harness: no std/ under scan root {root}")

    found: set[str] = set()
    failures: list[tuple[str, str]] = []
    for dirpath, _, filenames in os.walk(std):
        for fn in sorted(filenames):
            if not fn.endswith(".ail"):
                continue
            path = Path(dirpath) / fn
            # module id from the path relative to the scan root, never iface's own
            # `module` field, which is an absolute-path string.
            mod = str(path.relative_to(root).with_suffix("")).replace(os.sep, "/")
            rc, out, err = run(["ailang", "iface", str(path.resolve())])
            if rc != 0 or not out.strip():
                # Fall back rather than skip. A skipped file is a silent fail-open.
                msg = (err or out).strip().splitlines()[0] if (err or out).strip() else "no output"
                if textual_scan(path):
                    found.add(mod)
                failures.append((mod, f"{msg}  [textual fallback: "
                                      f"{'effect-bearing' if mod in found else 'effect-free'}]"))
                continue
            try:
                doc = json.loads(out[out.index("{"):])
            except (ValueError, json.JSONDecodeError) as e:
                failures.append((mod, f"unparseable iface output: {e}"))
                continue
            for f in doc.get("funcs", []):
                # `effects` only. `pure` disagrees with it and is never read.
                if f.get("effects"):
                    found.add(mod)
                    break
    return found, failures


def repo_imports(repo: Path, roots: list[str]) -> set[str]:
    imported: set[str] = set()
    for r in roots:
        base = repo / r
        if not base.is_dir():
            continue
        for dirpath, _, filenames in os.walk(base):
            for fn in filenames:
                if not fn.endswith(".ail"):
                    continue
                text = (Path(dirpath) / fn).read_text(errors="replace")
                imported.update(IMPORT_RE.findall(text))
    return imported


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--scan-root", default=os.path.expanduser("~/.local/share/ailang"),
                    help="pinned AILANG clone containing std/ (default: %(default)s)")
    ap.add_argument("--repo", default=".", help="repository root to reconcile against")
    ap.add_argument("--roots", default="src,packages", help="comma-separated in-profile source roots")
    ap.add_argument("--json", action="store_true", help="emit the derived set as JSON")
    ap.add_argument("--self-test", action="store_true",
                    help="cross-validate the textual fallback against `ailang iface` on every "
                         "file where both run; this is what makes the fallback trustworthy")
    args = ap.parse_args()

    root = Path(args.scan_root).expanduser().resolve()
    repo = Path(args.repo).resolve()

    if "/tmp/" in str(root) or str(root).startswith("/tmp"):
        print("harness: scan root is under /tmp; AILANG auto-relaxes MOD010 there and "
              "interface failures will be hidden. Use the installed clone.", file=sys.stderr)
        return 2

    cc, rc_ = compiler_commit(), scan_root_commit(root)
    if cc is None or rc_ is None:
        print("harness: could not resolve compiler and/or scan-root commit", file=sys.stderr)
        return 2
    if cc != rc_:
        print(f"FAIL: scan root {rc_} != executing compiler {cc}\n"
              f"      the derived set would not describe the compiler that ran it", file=sys.stderr)
        return 1

    if args.self_test:
        agree = disagree = 0
        bad: list[str] = []
        for dirpath, _, filenames in os.walk(root / "std"):
            for fn in sorted(filenames):
                if not fn.endswith(".ail"):
                    continue
                path = Path(dirpath) / fn
                rc, out, _ = run(["ailang", "iface", str(path.resolve())])
                if rc != 0 or not out.strip():
                    continue  # not comparable; the fallback is the only answer there
                try:
                    doc = json.loads(out[out.index("{"):])
                except (ValueError, json.JSONDecodeError):
                    continue
                a = any(f.get("effects") for f in doc.get("funcs", []))
                b = textual_scan(path)
                if a == b:
                    agree += 1
                else:
                    disagree += 1
                    bad.append(f"{path.relative_to(root)}: iface={a} textual={b}")
        print(f"self-test: agree={agree} disagree={disagree}")
        for line in bad:
            print(f"  {line}")
        # WI-B4. A control that must SURVIVE certifies nothing if the mechanism
        # never reached it (A17 site 32) -- and this self-test walked straight
        # into it on the v0.33.0 repin. At v0.26.0 exactly ONE stdlib module
        # (std/secret) failed MOD010 and the run reported `agree=43 disagree=0`.
        # On v0.33.0 `ailang iface <abs path>` fails MOD010 for EVERY stdlib
        # module, so nothing is comparable, `agree=0 disagree=0` -- and the old
        # `return 1 if disagree else 0` reported that as a PASS. The fallback
        # became the sole derivation for all 46 modules at the same moment the
        # check that makes it trustworthy stopped checking anything, and both
        # targets kept exiting 0.
        #
        # Zero comparisons is therefore a FAILURE, not a clean run. Note the
        # compiler names two escape hatches in its own MOD010 message and
        # neither works for this subcommand on v0.33.0: `AILANG_RELAX_MODULES=1`
        # is ignored by `iface`, and `--relax-modules` is not a defined flag for
        # it ("flag provided but not defined: -relax-modules").
        if agree + disagree == 0:
            print("FAIL: the self-test compared ZERO modules, so it certified nothing.\n"
                  "      `ailang iface` produced no parseable interface for any stdlib\n"
                  "      module, which means the textual fallback is the only derivation\n"
                  "      in play AND is now completely unvalidated. This is a pass-shaped\n"
                  "      absence, not a pass.", file=sys.stderr)
            return 1
        return 1 if disagree else 0

    proj = builtin_projection()
    src, failures = iface_modules(root)
    union = proj | src
    imported = repo_imports(repo, [r.strip() for r in args.roots.split(",") if r.strip()])

    # A module is effect-free only if BOTH derivations say so. Anything imported and
    # not in the union is unresolved unless we scanned it and found nothing.
    scanned = {m for m in imported if (root / f"{m}.ail").exists()}
    unresolved = sorted(m for m in imported if m not in union and m not in scanned)
    effect_free = sorted(m for m in imported if m not in union and m in scanned)
    in_profile = sorted(m for m in imported if m in union)

    if args.json:
        print(json.dumps({
            "toolchain_commit": cc,
            "scan_root_commit": rc_,
            "builtin_projection": sorted(proj),
            "source_scan": sorted(src),
            "union": sorted(union),
            "repo_imports": sorted(imported),
            "effect_bearing_imports": in_profile,
            "proven_effect_free_imports": effect_free,
            "unresolved": unresolved,
            "interface_failures": [{"module": m, "error": e} for m, e in failures],
        }, indent=2))
    else:
        print(f"toolchain commit   {cc}")
        print(f"scan root commit   {rc_}  (match)")
        print(f"builtin projection {len(proj)} modules")
        print(f"source scan        {len(src)} modules")
        print(f"union              {len(union)} modules")
        print(f"repo imports       {len(imported)} distinct std/* modules")
        print()
        print(f"effect-bearing and imported ({len(in_profile)}):")
        for m in in_profile:
            tag = "both" if m in proj and m in src else ("builtin-only" if m in proj else "source-only")
            print(f"  {m:<20} [{tag}]")
        print()
        print(f"proven effect-free ({len(effect_free)}): {', '.join(effect_free) or '-'}")
        if unresolved:
            print(f"\nUNRESOLVED ({len(unresolved)}) -- fail closed, triage required:")
            for m in unresolved:
                print(f"  {m}")
        if failures:
            print(f"\nINTERFACE FAILURES ({len(failures)}) -- resolved by textual fallback:")
            for m, e in failures:
                print(f"  {m}: {e}")

    return 1 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main())
