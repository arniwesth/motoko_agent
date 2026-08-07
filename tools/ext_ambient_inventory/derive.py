#!/usr/bin/env python3
"""Classifier 3 -- the extension-closure ambient-source inventory (ADR-001, Amendment A).

Decides, per registrable extension, whether EVERY effect it can perform arrives
through a field call on an `ExtPorts`-typed value.  It is the producer criterion
2 needs and did not have: criterion 2 is a claim about the CALL PATH, and a
declared effect row -- at any width, reconciled or not -- is a set of labels.
The effect checker assigns the identical verdict to a fully port-mediated body
and a fully ambient one, so no row-reading instrument can answer this.

The four properties are the amendment's (ADR:1470-1495) and are not re-derived
here.  What each costs in this file:

  1. PROVENANCE, NOT LABELS.  An effect enters an extension's closure by exactly
     two doors: a symbol imported from an effect-bearing `std/*` module, or a
     `_`-prefixed compiler builtin called directly.  Neither is a field call on
     an `ExtPorts` value, so either one is AMBIENT.  The inventory enumerates
     both doors over the whole closure; the `ExtPorts` field calls it finds are
     reported as the mediated paths, and are the positive half of the claim.
     Per plan rule S16 nothing here reads the declaration being tested.

  2. TOTAL OVER THE EXTENSION'S TRANSITIVE CLOSURE, not over the module holding
     the hook's chain.  The unit is `<package>/register.ail` and everything it
     reaches: `pkg/...`, `src/...`, and the `std/*` leaves.  Closures measure
     2-17 modules and none reaches `src/core/session.ail`.

  3. SYMBOL-GRANULAR.  `std/ai.Message` is a type; `std/ai.call` is `! {AI}`.
     Module granularity fails every extension that touches a type from an
     effect-bearing module, which is most of them.

  4. FAIL-CLOSED ON THE UNRESOLVABLE, on classifier 2's discipline.  Five shapes
     are rejections, never passes -- see `SHAPES` below.

THE PRODUCER, AND WHY IT IS NOT THE CHEAP ONE
---------------------------------------------
Per-symbol effect data comes from the compiler's own cached interfaces,
`.ailang/cache/compile/modules/std__*/iface.json`, schema `ailang.iface/v1`.
The two candidates WI-D10 named are both wrong for this job:

  * the per-declaration textual parse FAILS OPEN on 44 of 465 stdlib symbols --
    39 `export func` carrying no row at all and 5 effect-POLYMORPHIC.  An
    unannotated row reads as "infer", not as "performs nothing".  `std/json.jo`
    is one of the 39 and three of the four clean extensions import it, so on the
    textual route this instrument's yield is 1 of 15 rather than 4.
  * `ailang iface`'s stdout needs the stdlib-adjacent cache at
    `~/.local/share/ailang/std/.ailang/cache/`, and WI-D11 proved NO repository
    operation produces it.

The cached interface separates the two facts the yield turns on:

    jo          purity: true   effect_row: labels {}        -- CLOSED EMPTY ROW
    allNumbers  purity: true   effect_row: tail rowvar 'p2' -- EFFECT VARIABLE

A closed empty row is proof; an effect variable is instantiable and is therefore
a rejection under property 4.

THE CACHE PRECONDITION, STATED AND ENFORCED
--------------------------------------------
Classifier 3's coverage is a function of what has been compiled, and that is
exactly the defect WI-D11 bounded for classifier 1, whose selftest returned
`agree=0`, `agree=1` and `agree=45` on the same tree in one day.  This tool does
not inherit it, because unlike classifier 1's it can BUILD its own precondition:

    PRECONDITION: every extension root has a repo-local compile cache holding an
    `iface.json` for each `std/*` module its closure imports.
    ESTABLISHED BY: this tool, which runs `AILANG_RELAX_MODULES=1 ailang check
    <package>/register.ail` per extension before deriving (`--no-provision`
    suppresses it, for measuring what a cold tree would have answered).

Measured two-sided at WI-D12: with every repo-local `.ailang` removed and the
stdlib-adjacent cache emptied, the derivation is 0 of 15 CLEAN with every symbol
UNRESOLVED -- it fails closed rather than reading empty as innocent.  After the
tool's own provisioning from that same cold tree it is 4 of 15 with resolution
21/21, byte-identical to the warm answer.

A green run here means "every extension resolved, and these were clean".  It can
never mean "all clean" by resolving nothing: RESOLUTION is printed as a fraction
and anything short of total is exit 1.  That `agree=0 disagree=0` shape has cost
this project two items already.

Exit codes: 0 clean, 1 unresolved or incomplete resolution, 2 harness error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# classifier 2 is the host: same matcher, same fail-closed discipline, ambient
# symbols instead of `ExtPorts` fields.  Its `strip_noise` and typed field-call
# scan are reused rather than reimplemented, so a fix to either lands in both.
#
# Loaded by PATH under a distinct name, not by `sys.path` and `import derive`:
# this file is also called `derive.py`, so a name-based import from the script's
# own directory resolves to ITSELF.  It does so silently -- the module object
# exists, every attribute lookup that happens to hit a shared name succeeds, and
# only the first classifier-2-only attribute raises.  A tool that fails closed on
# unresolved receivers must not be the thing importing the wrong receiver code.
def _load_classifier_2():
    import importlib.util
    path = Path(__file__).resolve().parent.parent / "ext_call_inventory" / "derive.py"
    spec = importlib.util.spec_from_file_location("motoko_classifier_2", path)
    if spec is None or spec.loader is None:          # pragma: no cover - harness
        raise SystemExit(f"harness: cannot load classifier 2 from {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules["motoko_classifier_2"] = mod
    spec.loader.exec_module(mod)
    return mod


c2 = _load_classifier_2()

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"

#: The five unresolvable shapes the ADR's acceptance criterion requires to be
#: fixture-tested.  Each is a REJECTION, never a pass.
SHAPES = {
    "module-alias": "a whole-module alias import (`import std/x as X`) -- every export "
                    "of the module is in scope under a name this tool cannot attribute "
                    "to a symbol, so it is not symbol-granular",
    "bare-module": "a module import with no symbol list -- the same loss of granularity, "
                   "reached by computed/unqualified access instead of an alias",
    "no-cached-interface": "the producer has no `iface.json` for this module, so no "
                           "per-symbol effect data exists.  This is the CACHE PRECONDITION "
                           "failing, and it is a rejection, not an absence of findings",
    "symbol-not-in-interface": "the symbol is imported but the module's interface exports "
                               "no such name -- a re-export or wrapper this tool cannot "
                               "resolve to a concrete row",
    "effect-variable": "the cached row is a row VARIABLE, not a closed row.  It is "
                       "instantiable at any effect and is therefore not proof of anything",
}

#: A sixth rejection that is not an import shape: a `_`-prefixed compiler builtin
#: called directly.  Builtins need no import, so an import-only inventory misses
#: them entirely -- and `compaction_structural`, the extension this instrument
#: exists to clear, calls `_list_length` at `compaction_structural.ail:251`.
#: Their effects come from the same producer: a builtin is provably effect-free
#: only when some `std/*` export whose body calls it carries a CLOSED EMPTY
#: cached row, and no such export carries labels or a row variable.
BUILTIN_CALL = re.compile(rf"\b(_[a-z][A-Za-z0-9_]*)\s*\(")

STDLIB_ENV = "AILANG_STDLIB_PATH"
DEFAULT_STDLIB = Path.home() / ".local/share/ailang/std"


# --------------------------------------------------------------------------
# the extension list -- resolved through ailang.toml, per plan rule S22
# --------------------------------------------------------------------------

def installable_extensions(repo: Path) -> dict[str, Path]:
    """extension id -> package source directory, resolved through `ailang.toml`.

    NOT by directory-name convention.  `sunholo/motoko_ext_scratchpad` lives at
    `packages/motoko_scratchpad`, so a name-convention resolver silently returns
    14 of 15 -- and 14 is a plausible-looking answer that nothing downstream
    contradicts.  The resolution is therefore ASSERTED, member by member, not
    merely counted: every id must reach a directory that exists, that holds a
    `register.ail`, and whose own `[package] name` is the dependency key that
    named it.
    """
    toml = (repo / "ailang.toml").read_text()
    block = re.search(r"\[extensions\](.*?)(?:\n\[|\Z)", toml, re.S)
    if not block:
        raise SystemExit("harness: ailang.toml has no [extensions] block")
    installable = sorted(set(re.findall(r'"(sunholo/motoko_ext_[a-z0-9_]+)@', block.group(1))))
    if not installable:
        raise SystemExit("harness: [extensions] packages named no installable extension")

    paths = dict(re.findall(r'"(sunholo/[A-Za-z0-9_]+)"\s*=\s*\{\s*path\s*=\s*"([^"]+)"', toml))

    out: dict[str, Path] = {}
    problems: list[str] = []
    for pkg in installable:
        ext_id = pkg[len("sunholo/motoko_ext_"):]
        rel = paths.get(pkg)
        if rel is None:
            problems.append(f"{pkg}: installable but has no path dependency in [dependencies]")
            continue
        d = repo / rel.rstrip("/")
        if not d.is_dir():
            problems.append(f"{pkg}: [dependencies] path `{rel}` is not a directory")
            continue
        if not (d / "register.ail").is_file():
            problems.append(f"{pkg}: `{rel}/register.ail` does not exist, so it has no closure root")
            continue
        man = d / "ailang.toml"
        declared = None
        if man.is_file():
            m = re.search(r'\[package\][^\[]*?name\s*=\s*"([^"]+)"', man.read_text(), re.S)
            declared = m.group(1) if m else None
        if declared != pkg:
            problems.append(f"{pkg}: `{rel}/ailang.toml` declares package name "
                            f"{declared!r}, which is not the dependency key that named it")
            continue
        out[ext_id] = d
    if problems:
        raise SystemExit("harness: extension resolution failed:\n  " + "\n  ".join(problems))
    return out


# --------------------------------------------------------------------------
# the producer -- cached `ailang.iface/v1` interfaces
# --------------------------------------------------------------------------

class Producer:
    """Per-symbol effect data from `.ailang/cache/compile/modules/std__*/iface.json`.

    A repo-local cache is written per source directory, so the same `std/*`
    module appears many times over.  The copies are NOT byte-identical -- type
    variables are renumbered per compilation, so digests differ -- and picking
    whichever the directory walk reached first would make this tool's answer a
    function of walk order.  Every copy is therefore read and its per-symbol
    classification compared; a disagreement is a rejection, not a tie broken
    silently.  Measured at WI-D12 over 331 `std__*` interfaces: 24 modules, 38
    differing digests, ZERO classification disagreements.
    """

    def __init__(self) -> None:
        self.mods: dict[str, dict] = {}
        self.digests: dict[str, set[str]] = {}
        self.copies: dict[str, int] = {}
        self.disagreements: list[tuple[str, str, list[str]]] = []
        self.schemas: set[str] = set()

    def load(self, roots: list[Path]) -> None:
        seen: dict[str, dict[str, set[str]]] = {}
        for root in roots:
            for dirpath, dirnames, filenames in os.walk(root):
                if "node_modules" in dirpath:
                    continue
                if "iface.json" not in filenames:
                    continue
                if "/cache/compile/modules/" not in dirpath.replace(os.sep, "/"):
                    continue
                if not Path(dirpath).name.startswith("std__"):
                    continue
                try:
                    d = json.loads((Path(dirpath) / "iface.json").read_text())
                except (OSError, ValueError):
                    continue
                mod = d.get("module")
                if not mod:
                    continue
                self.schemas.add(d.get("schema", "<none>"))
                self.mods.setdefault(mod, d)
                self.digests.setdefault(mod, set()).add(d.get("digest", ""))
                self.copies[mod] = self.copies.get(mod, 0) + 1
                per = seen.setdefault(mod, {})
                for sym, entry in d.get("exports", {}).items():
                    per.setdefault(sym, set()).add(classify_entry(entry))
                for sym in list(d.get("types", {})) + list(d.get("constructors", {})):
                    per.setdefault(sym, set()).add("TYPE")
        for mod, per in seen.items():
            for sym, kinds in per.items():
                if len(kinds) > 1:
                    self.disagreements.append((mod, sym, sorted(kinds)))

    def classify(self, mod: str, sym: str) -> tuple[str, object]:
        d = self.mods.get(mod)
        if d is None:
            return "no-cached-interface", None
        if sym in d.get("types", {}) or sym in d.get("constructors", {}):
            return "TYPE", None
        entry = d.get("exports", {}).get(sym)
        if entry is None:
            return "symbol-not-in-interface", None
        kind = classify_entry(entry)
        if kind.startswith("EFF:"):
            return "EFFECTFUL", kind[4:].split(",")
        if kind == "ROWVAR":
            return "effect-variable", None
        return kind, None       # PURE or VALUE

    def revision(self, mod: str) -> str:
        return sorted(self.digests.get(mod, {""}))[0][:12] or "-"


def classify_entry(entry: dict) -> str:
    """One cached export -> PURE | VALUE | ROWVAR | EFF:<labels>.

    The distinction that decides this instrument's yield is between `labels: {}`
    with no tail -- a CLOSED EMPTY ROW, provably effect-free -- and a `tail`
    holding a row variable, which is instantiable and proves nothing.  Collapsing
    them is what takes the yield from 4 of 15 to 1.
    """
    inner = entry.get("type", {}).get("type", {})
    if inner.get("tag") not in ("tfunc", "tfunc2"):
        return "VALUE"                      # not a function: performs nothing
    data = (inner.get("data") or {}).get("effect_row") or {}
    row = data.get("data") or {}
    if row.get("labels"):
        return "EFF:" + ",".join(sorted(row["labels"]))
    if row.get("tail") is not None:
        return "ROWVAR"
    return "PURE"


# --------------------------------------------------------------------------
# builtins -- the door an import-only inventory does not watch
# --------------------------------------------------------------------------

DECL = re.compile(rf"^(?:export\s+)?(?:pure\s+)?func\s+({IDENT})", re.M)


def builtin_effects(stdlib: Path, producer: Producer) -> dict[str, str]:
    """`_builtin` -> PURE | EFF:<labels> | <a rejection shape>.

    A builtin is provably effect-free only on compiler-derived evidence: some
    `std/*` export whose body calls it carries a CLOSED EMPTY cached row.  If
    `_str_find` performed an effect, `std/string.find` could not have one -- the
    effect checker is transitive through direct builtin calls, which is the whole
    reason that row is evidence.  Any builtin reached only from private helpers,
    from effect-variable exports, or from a module with no cached interface is
    unresolved and therefore a rejection.
    """
    evidence: dict[str, set[str]] = {}
    for f in sorted(stdlib.glob("*.ail")):
        mod = "std/" + f.stem
        text = c2.strip_noise(f.read_text(errors="replace"))
        decls = list(DECL.finditer(text))
        for i, m in enumerate(decls):
            end = decls[i + 1].start() if i + 1 < len(decls) else len(text)
            kind, _ = producer.classify(mod, m.group(1))
            for b in set(BUILTIN_CALL.findall(text[m.end():end])):
                evidence.setdefault(b, set()).add(kind)
    out: dict[str, str] = {}
    for b, kinds in evidence.items():
        eff = sorted(k for k in kinds if k == "EFFECTFUL")
        if eff:
            out[b] = "EFFECTFUL"
        elif "effect-variable" in kinds:
            out[b] = "effect-variable"
        elif "PURE" in kinds:
            out[b] = "PURE"
        else:
            out[b] = "no-cached-interface"
    return out


# --------------------------------------------------------------------------
# imports and closures
# --------------------------------------------------------------------------

IMPORT = re.compile(rf"^import\s+([A-Za-z0-9_/]+)\s*(\(|as\b)?", re.M)


def imports_of(clean: str) -> list[tuple[str, list[str] | None, str]]:
    """`(module path, symbols or None, form)` for every import in a stripped file.

    The symbol list is brace-balanced rather than line-scoped: several of this
    tree's `pkg/sunholo/motoko_ext_abi/types` imports wrap across lines, and a
    line-scoped reader drops every symbol after the first newline -- silently,
    and in the direction that makes an extension look cleaner than it is.
    """
    out = []
    for m in IMPORT.finditer(clean):
        path, tok = m.group(1), m.group(2)
        if tok == "(":
            depth, i = 0, m.end() - 1
            while i < len(clean):
                if clean[i] == "(":
                    depth += 1
                elif clean[i] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            body = clean[m.end():i]
            syms = []
            for part in body.split(","):
                part = part.strip()
                if not part:
                    continue
                # `getEnvOr as ge` is RESOLVABLE -- the source symbol is named,
                # so the rename costs nothing.  A whole-MODULE alias is not.
                syms.append(part.split()[0])
            out.append((path, syms, "list"))
        elif tok == "as":
            out.append((path, None, "module-alias"))
        else:
            out.append((path, None, "bare-module"))
    return out


def module_resolver(repo: Path):
    """`import` path -> a source file, a std module, or an unresolvable residue.

    Package paths are resolved through `ailang.toml`'s `[dependencies]` by
    longest-prefix match on the package NAME, so `pkg/sunholo/motoko_ext_scratchpad/x`
    reaches `packages/motoko_scratchpad/x.ail` -- the case a name-convention
    resolver loses.
    """
    toml = (repo / "ailang.toml").read_text()
    paths = dict(re.findall(r'"(sunholo/[A-Za-z0-9_]+)"\s*=\s*\{\s*path\s*=\s*"([^"]+)"', toml))
    names = sorted(paths, key=len, reverse=True)

    def resolve(path: str):
        if path.startswith("std/"):
            return ("std", path)
        if path.startswith("src/"):
            return ("file", repo / (path + ".ail"))
        if path.startswith("pkg/"):
            rest = path[4:]
            for pkg in names:
                if rest == pkg or rest.startswith(pkg + "/"):
                    sub = rest[len(pkg):].lstrip("/")
                    return ("file", repo / paths[pkg].rstrip("/") / (sub + ".ail"))
        return ("residue", path)

    return resolve


def closure(root: Path, resolve) -> tuple[list[Path], list[str]]:
    """Every module the extension's root transitively imports, plus the residue.

    The unit is the EXTENSION, not the module holding the hook's chain: criterion
    2 quantifies over every hook an installed extension registers, and
    `compaction_ai`'s hook is bound in `register.ail` while the claim recorded
    for it was scoped to `compaction_ai.ail`.
    """
    seen: set[Path] = set()
    stack, mods, residue = [root], [], []
    while stack:
        f = stack.pop()
        f = f.resolve()
        if f in seen:
            continue
        seen.add(f)
        if not f.is_file():
            residue.append(str(f))
            continue
        mods.append(f)
        for path, _syms, _form in imports_of(c2.strip_noise(f.read_text(errors="replace"))):
            kind, target = resolve(path)
            if kind == "file":
                stack.append(target)
            elif kind == "residue":
                residue.append(path)
    return sorted(mods), sorted(residue)


# --------------------------------------------------------------------------
# the inventory
# --------------------------------------------------------------------------

class Finding:
    def __init__(self, ext: str, file: str, line: int, source: str, sym: str,
                 verdict: str, why: str, labels=None):
        self.ext, self.file, self.line, self.source = ext, file, line, source
        self.sym, self.verdict, self.why, self.labels = sym, verdict, why, labels

    def as_dict(self) -> dict:
        return {"extension": self.ext, "file": self.file, "line": self.line,
                "origin": self.source, "symbol": self.sym, "verdict": self.verdict,
                "why": self.why, "effects": self.labels}


def line_of(clean: str, needle_re: str, fallback: int = 0) -> int:
    # `re.M` is not optional: every pattern here is anchored at `^` against a
    # whole file, and without it every finding is reported at line 0 -- which is
    # not wrong enough to fail anything and not right enough to triage from.
    m = re.search(needle_re, clean, re.M)
    return clean[:m.start()].count("\n") + 1 if m else fallback


def inventory_module(ext: str, path: Path, repo: Path, producer: Producer,
                     builtins: dict[str, str]) -> list[Finding]:
    """Every ambient effect door in one closure module."""
    clean = c2.strip_noise(path.read_text(errors="replace"))
    rel = str(path.relative_to(repo))
    found: list[Finding] = []

    for mpath, syms, form in imports_of(clean):
        if not mpath.startswith("std/"):
            continue
        ln = line_of(clean, rf"^import\s+{re.escape(mpath)}\b", 0)
        if form != "list":
            found.append(Finding(ext, rel, ln, mpath, "*", form, SHAPES[form]))
            continue
        for sym in syms:
            kind, labels = producer.classify(mpath, sym)
            if kind in ("TYPE", "PURE", "VALUE"):
                continue
            if kind == "EFFECTFUL":
                found.append(Finding(ext, rel, ln, mpath, sym, "AMBIENT",
                                     f"`{mpath}.{sym}` performs {{{', '.join(labels)}}} and is "
                                     f"reached by an ambient import, not through an ExtPorts field",
                                     labels))
            else:
                found.append(Finding(ext, rel, ln, mpath, sym, kind, SHAPES[kind]))

    for m in BUILTIN_CALL.finditer(clean):
        b = m.group(1)
        kind = builtins.get(b)
        ln = clean[:m.start()].count("\n") + 1
        if kind == "PURE":
            continue
        if kind == "EFFECTFUL":
            found.append(Finding(ext, rel, ln, "<builtin>", b, "AMBIENT",
                                 f"`{b}` is a compiler builtin wrapped by an effect-bearing "
                                 f"std export; calling it directly bypasses every port"))
        elif kind is None:
            found.append(Finding(ext, rel, ln, "<builtin>", b, "unknown-builtin",
                                 f"`{b}` is called as a compiler builtin and no std export "
                                 f"whose body calls it was found, so its effects are unknown"))
        else:
            found.append(Finding(ext, rel, ln, "<builtin>", b, kind, SHAPES[kind]))
    return found


def mediated_calls(ext: str, mods: list[Path], repo: Path, ext_fields: list[str],
                   other_owners: set[str]) -> tuple[int, int]:
    """`(ExtPorts field calls, unresolved receivers)` in the closure, via classifier 2.

    This is property 1's POSITIVE half: the calls that do arrive through a
    world-mediated port.  It does not soften the verdict -- an ambient import is
    a rejection whether or not the extension also mediates -- but a classifier
    that only ever reports absence cannot be told from one that resolves nothing.
    """
    calls = unresolved = 0
    for p in mods:
        for o in c2.scan_file(p, repo, ext_fields, {}, other_owners):
            if o.kind == "call":
                calls += 1
            else:
                unresolved += 1
    return calls, unresolved


def provision(exts: dict[str, Path], repo: Path) -> list[str]:
    """Establish the cache precondition by compiling each extension root.

    This is the difference between classifier 3 and classifier 1.  Classifier 1's
    producer needs the stdlib-adjacent cache at `~/.local/share/ailang/std/.ailang/`,
    which WI-D11 proved no repository operation rebuilds -- so its coverage moved
    from 45 to 1 to 45 on an unchanged tree, and nothing in the tool said so.
    This producer's cache is repo-local and the project's own compilation writes
    it, so the precondition is not merely stated, it is ESTABLISHED here and then
    reported as a fraction.

    `AILANG_RELAX_MODULES=1` is required because this repo's package layout trips
    MOD010 (`sunholo/motoko_ext_test_dummy/register` vs
    `packages/motoko-ext-test-dummy/register`).  The cache is written during
    compilation, before that check, so it is produced either way -- but relying on
    a failing invocation's side effect is not a precondition, it is a coincidence.
    """
    env = dict(os.environ, AILANG_RELAX_MODULES="1")
    failed = []
    for ext, d in sorted(exts.items()):
        root = d / "register.ail"
        p = subprocess.run(["ailang", "check", str(root.relative_to(repo))],
                           capture_output=True, text=True, cwd=repo, env=env)
        if p.returncode != 0:
            failed.append(f"{ext}: `ailang check {root.relative_to(repo)}` exited "
                          f"{p.returncode}: {(p.stderr or p.stdout).strip().splitlines()[-1:]}")
    return failed


# --------------------------------------------------------------------------

def derive(repo: Path, do_provision: bool) -> dict:
    exts = installable_extensions(repo)
    resolve = module_resolver(repo)

    provision_failures = provision(exts, repo) if do_provision else []

    producer = Producer()
    producer.load([repo / "src", repo / "packages", repo / "scripts"])

    stdlib = Path(os.environ.get(STDLIB_ENV) or DEFAULT_STDLIB)
    builtins = builtin_effects(stdlib, producer) if stdlib.is_dir() else {}

    # classifier 2's typed-receiver machinery, for the mediated half
    abi_types = c2.record_types(c2.strip_noise((repo / c2.ABI_TYPES).read_text()))
    core_types = c2.record_types(c2.strip_noise((repo / c2.CORE_PORTS).read_text()))
    c2.ALL_TYPES.clear()
    c2.ALL_TYPES.update(core_types)
    c2.ALL_TYPES.update(abi_types)
    ext_fields = list(abi_types.get("ExtPorts", {}))
    other_owners = {ty for ty, fs in {**abi_types, **core_types}.items()
                    if ty != "ExtPorts" and any(f in fs for f in ext_fields)}

    report: dict[str, dict] = {}
    std_needed: set[str] = set()
    std_resolved: set[str] = set()

    for ext, d in sorted(exts.items()):
        mods, residue = closure(d / "register.ail", resolve)
        findings: list[Finding] = []
        for p in mods:
            findings.extend(inventory_module(ext, p, repo, producer, builtins))
            for mpath, _s, _f in imports_of(c2.strip_noise(p.read_text(errors="replace"))):
                if mpath.startswith("std/"):
                    std_needed.add(mpath)
                    if mpath in producer.mods:
                        std_resolved.add(mpath)
        calls, unres_recv = mediated_calls(ext, mods, repo, ext_fields, other_owners)

        ambient = [f for f in findings if f.verdict == "AMBIENT"]
        rejected = [f for f in findings if f.verdict not in ("AMBIENT",)]
        if residue:
            for r in residue:
                rejected.append(Finding(ext, "<closure>", 0, r, "*", "unresolvable-module",
                                        "an import in this closure resolves to no source file"))
        if rejected or unres_recv:
            verdict = "UNRESOLVED"
        elif ambient:
            verdict = "AMBIENT"
        else:
            verdict = "PORT-MEDIATED"

        report[ext] = {
            "package_dir": str(d.relative_to(repo)),
            "closure_modules": [str(p.relative_to(repo)) for p in mods],
            "closure_size": len(mods),
            "verdict": verdict,
            "ambient": [f.as_dict() for f in ambient],
            "rejected": [f.as_dict() for f in rejected],
            "ext_ports_calls": calls,
            "unresolved_receivers": unres_recv,
            "producer": "ailang.iface/v1 (.ailang/cache/compile/modules/std__*/iface.json)",
            "producer_revision": {m: producer.revision(m) for m in sorted(
                {mp for p in mods for mp, _s, _f in
                 imports_of(c2.strip_noise(p.read_text(errors="replace")))
                 if mp.startswith("std/")})},
        }

    rc, out, _ = c2.run(["git", "-C", str(repo), "rev-parse", "HEAD"])
    rcv, av, _ = c2.run(["ailang", "version"])

    return {
        "source_revision": out.strip() if rc == 0 else None,
        "compiler": (av.strip().splitlines() or ["<unknown>"])[0] if rcv == 0 else "<unknown>",
        "producer": "ailang.iface/v1",
        "producer_schemas": sorted(producer.schemas),
        "provision_failures": provision_failures,
        "producer_disagreements": producer.disagreements,
        "std_modules_needed": sorted(std_needed),
        "std_modules_resolved": sorted(std_resolved),
        "extensions": report,
    }


def emit(res: dict) -> int:
    exts = res["extensions"]
    needed, resolved = res["std_modules_needed"], res["std_modules_resolved"]
    clean = sorted(e for e, r in exts.items() if r["verdict"] == "PORT-MEDIATED")
    ambient = sorted(e for e, r in exts.items() if r["verdict"] == "AMBIENT")
    unres = sorted(e for e, r in exts.items() if r["verdict"] == "UNRESOLVED")

    print(f"source revision    {res['source_revision']}")
    print(f"compiler           {res['compiler']}")
    print(f"producer           {res['producer']} "
          f"(.ailang/cache/compile/modules/std__*/iface.json)")
    print(f"schemas seen       {', '.join(res['producer_schemas']) or '-'}")
    print()
    print("CACHE PRECONDITION -- every extension root compiled, so every std module its")
    print("closure imports has a cached interface.  Established by this tool via")
    print("`AILANG_RELAX_MODULES=1 ailang check <package>/register.ail`, not assumed.")
    pct = (100.0 * len(resolved) / len(needed)) if needed else 0.0
    print(f"  RESOLUTION       {len(resolved)}/{len(needed)} std modules "
          f"({pct:.0f}%) imported by the fifteen closures")
    missing = sorted(set(needed) - set(resolved))
    if missing:
        print(f"  UNRESOLVED       {', '.join(missing)}")
    print()
    print(f"extensions resolved through ailang.toml: {len(exts)}")
    for e, r in sorted(exts.items()):
        print(f"  {e:<24} {r['package_dir']:<44} closure {r['closure_size']:>2}")
    print()
    print(f"PORT-MEDIATED ({len(clean)} of {len(exts)}): {', '.join(clean) or '-'}")
    print("    every effect these can perform arrives through an ExtPorts field call:")
    print("    their closures import no effect-bearing std symbol and call no")
    print("    effect-bearing builtin.")
    print(f"AMBIENT ({len(ambient)}): {', '.join(ambient) or '-'}")
    print(f"UNRESOLVED ({len(unres)}): {', '.join(unres) or '-'}")
    print()
    for e in ambient:
        r = exts[e]
        print(f"  {e} -- {len(r['ambient'])} ambient source(s), "
              f"{r['ext_ports_calls']} ExtPorts field call(s) in closure")
        for f in r["ambient"][:6]:
            print(f"      {f['file']}:{f['line']}  {f['origin']}.{f['symbol']}"
                  f"  {{{', '.join(f['effects'] or [])}}}")
        if len(r["ambient"]) > 6:
            print(f"      ... {len(r['ambient']) - 6} more")

    bad = False
    if res["provision_failures"]:
        bad = True
        print("\nCACHE PRECONDITION NOT ESTABLISHED -- fail closed:")
        for f in res["provision_failures"]:
            print(f"  {f}")
    if res["producer_disagreements"]:
        bad = True
        print("\nPRODUCER DISAGREES WITH ITSELF across cache copies -- fail closed:")
        for mod, sym, kinds in res["producer_disagreements"][:20]:
            print(f"  {mod}.{sym}: {kinds}")
    if missing:
        bad = True
    if unres:
        bad = True
        print("\nUNRESOLVED -- fail closed, triage required:")
        for e in unres:
            for f in exts[e]["rejected"]:
                print(f"  {e}  {f['file']}:{f['line']}  {f['origin']}.{f['symbol']}"
                      f"  [{f['verdict']}]")
                print(f"      {f['why']}")
            if exts[e]["unresolved_receivers"]:
                print(f"  {e}  {exts[e]['unresolved_receivers']} unresolved ExtPorts "
                      f"receiver(s) in closure (classifier 2 discipline)")

    print()
    if bad:
        print("RESULT: FAIL -- this run resolved less than the whole surface it quantifies")
        print("over.  A green run here means every extension resolved AND these were clean;")
        print("it must never mean the tool found nothing to look at.")
    else:
        print(f"RESULT: PASS -- {len(exts)}/{len(exts)} extensions resolved, "
              f"{len(resolved)}/{len(needed)} std modules resolved, 0 unresolved symbols.")
    return 1 if bad else 0


# --------------------------------------------------------------------------
# self-test
# --------------------------------------------------------------------------

def self_test(repo: Path) -> int:
    """The fixture suite: one fixture per unresolvable shape, each failing closed,
    with RESOLVING CONTROLS beside them.

    The controls are what make the suite falsifiable.  A rejection-only suite
    passes if the classifier resolves nothing at all -- which is precisely the
    `agree=0 disagree=0` shape that has cost this project two items -- so every
    shape fixture is paired with a form the classifier MUST resolve, including
    the two the producer choice turns on: `std/json.jo` (no textual row, closed
    empty cached row) and `std/ai.Message` (a type in an effect-bearing module).
    """
    fixtures = repo / "tools/ext_ambient_inventory/fixtures"
    if not fixtures.is_dir():
        print(f"self-test: no fixture directory at {fixtures}", file=sys.stderr)
        return 2
    expected = json.loads((fixtures / "expected.json").read_text())
    fails: list[str] = []

    producer = Producer()
    producer.load([repo / "src", repo / "packages", repo / "scripts"])
    stdlib = Path(os.environ.get(STDLIB_ENV) or DEFAULT_STDLIB)
    builtins = builtin_effects(stdlib, producer) if stdlib.is_dir() else {}

    present = sorted(p.name for p in fixtures.glob("*.ail"))
    for name in present:
        want = expected["fixtures"].get(name)
        if want is None:
            fails.append(f"{name}: fixture present but not declared in expected.json")
            continue
        got = inventory_module("fixture", fixtures / name, fixtures, producer, builtins)
        verdicts = sorted(f.verdict for f in got)
        if verdicts != sorted(want["verdicts"]):
            fails.append(f"{name}: expected {sorted(want['verdicts'])}, got {verdicts}"
                         f"  [{want['form']}]")
        else:
            print(f"  ok  {name:<34} {want['form']:<26} {verdicts or '[] (resolved clean)'}")
    for gone in sorted(set(expected["fixtures"]) - set(present)):
        fails.append(f"{gone}: declared in expected.json but the fixture file is gone")

    # Every shape the ADR's criterion names must be exercised by some fixture.
    covered = {v for w in expected["fixtures"].values() for v in w["verdicts"]}
    for shape in SHAPES:
        if shape not in covered:
            fails.append(f"SHAPE COVERAGE: no fixture exercises `{shape}`, which the "
                         f"acceptance criterion requires to be fixture-tested")
    if "unknown-builtin" not in covered:
        fails.append("SHAPE COVERAGE: no fixture exercises `unknown-builtin`; builtins need "
                     "no import, so an import-only inventory misses them silently")

    # POSITIVE CONTROL for the suite as a whole.  Without it, a classifier that
    # resolved NOTHING would still report every rejection fixture correctly.
    resolving = [n for n, w in expected["fixtures"].items() if not w["verdicts"]]
    if not resolving:
        fails.append("POSITIVE CONTROL: expected.json declares no fixture that must resolve "
                     "CLEAN.  A rejection-only suite is passed by a classifier that resolves "
                     "nothing, which is the failure this instrument exists to prevent.")
    if not any(f.verdict == "AMBIENT"
               for n, w in expected["fixtures"].items() if "AMBIENT" in w["verdicts"]
               for f in inventory_module("fixture", fixtures / n, fixtures, producer, builtins)):
        fails.append("TWO-SIDED CONTROL: no fixture is reported AMBIENT, so nothing shows the "
                     "matcher is sensitive to an ambient effect at all.")

    # And the yield, pinned in BOTH directions so a drift in either is a failure.
    #
    # This provisions, so the target is runnable from a cold tree on its own
    # rather than depending on the sibling target having run first.  The
    # resolution is then asserted TOTAL: without that, a cold run reports zero
    # clean extensions, the pinned yield fails for the wrong reason, and a future
    # reader debugs the yield instead of the cache.
    res = derive(repo, do_provision=True)
    needed = set(res["std_modules_needed"])
    unresolved_mods = sorted(needed - set(res["std_modules_resolved"]))
    if res["provision_failures"]:
        fails.append(f"CACHE PRECONDITION: {res['provision_failures']}")
    if unresolved_mods:
        fails.append(f"CACHE PRECONDITION: {len(unresolved_mods)} of {len(needed)} std "
                     f"modules the closures import have no cached interface: {unresolved_mods}. "
                     f"Every yield number below is measuring the cache, not the tree.")
    else:
        print(f"  ok  cache precondition      {len(needed)}/{len(needed)} std modules resolved")
    clean = sorted(e for e, r in res["extensions"].items() if r["verdict"] == "PORT-MEDIATED")
    want_clean = sorted(expected["yield"]["port_mediated"])
    want_total = expected["yield"]["extensions"]
    if len(res["extensions"]) != want_total:
        fails.append(f"YIELD: expected {want_total} registrable extensions resolved through "
                     f"ailang.toml, got {len(res['extensions'])}")
    # S22: assert the RESOLUTION, not just the count -- 14 of 15 is a plausible
    # answer that a directory-name resolver produces silently.
    for ext, d in sorted(expected["yield"]["package_dirs"].items()):
        got_dir = res["extensions"].get(ext, {}).get("package_dir")
        if got_dir != d:
            fails.append(f"RESOLUTION {ext}: expected package dir `{d}`, resolved `{got_dir}`")
    if clean != want_clean:
        fails.append(f"YIELD: expected PORT-MEDIATED {want_clean}, derived {clean} "
                     f"(residue {sorted(set(clean) ^ set(want_clean))})")
    else:
        print(f"  ok  yield {len(clean)} of {len(res['extensions'])}      "
              f"{', '.join(clean)}")
        print(f"  ok  resolution asserted    {len(expected['yield']['package_dirs'])} "
              f"package directories, member by member")

    print(f"\nself-test: {len(fails)} failure(s)")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0


def _hook_scope(repo: Path, do_provision: bool, selftest: bool = False) -> int:
    """WI-D15's second answer: criterion 2 quantified over HOOKS.

    Loaded by explicit path under a distinct name, for the reason recorded at
    `_load_classifier_2`: this directory already contains one `derive.py` that
    resolves to itself under a name-based import, and a tool that fails closed on
    unresolved receivers must not be the thing importing the wrong module.

    This mode REPORTS.  It does not change the verdict `derive.py` returns, and
    the shipped closure verdict is what a profile may rely on -- promoting the
    hook-scope answer is an ADR-scope decision, not an instrument's.
    """
    import importlib.util
    path = Path(__file__).resolve().parent / "hook_scope.py"
    spec = importlib.util.spec_from_file_location("motoko_hook_scope", path)
    if spec is None or spec.loader is None:          # pragma: no cover - harness
        raise SystemExit(f"harness: cannot load hook_scope from {path}")
    hs = importlib.util.module_from_spec(spec)
    sys.modules["motoko_hook_scope"] = hs
    spec.loader.exec_module(hs)

    closure = derive(repo, do_provision=do_provision)
    if closure["provision_failures"]:
        print("CACHE PRECONDITION NOT ESTABLISHED -- fail closed:")
        for f in closure["provision_failures"]:
            print(f"  {f}")
        return 1

    producer = Producer()
    producer.load([repo / "src", repo / "packages", repo / "scripts"])
    stdlib = Path(os.environ.get(STDLIB_ENV) or DEFAULT_STDLIB)
    builtins = builtin_effects(stdlib, producer) if stdlib.is_dir() else {}
    abi_types = c2.record_types(c2.strip_noise((repo / c2.ABI_TYPES).read_text()))
    core_types = c2.record_types(c2.strip_noise((repo / c2.CORE_PORTS).read_text()))
    c2.ALL_TYPES.clear()
    c2.ALL_TYPES.update(core_types)
    c2.ALL_TYPES.update(abi_types)
    ext_fields = tuple(abi_types.get("ExtPorts", {}))
    if not ext_fields:
        print("harness: ExtPorts has no fields in the ABI -- property 1's positive half "
              "cannot be measured, so every mediated call would read as unresolvable")
        return 2

    if selftest:
        return hs.self_test(repo, sys.modules[__name__], producer, builtins, ext_fields)

    res = hs.derive_hook_scope(repo, sys.modules[__name__], producer, builtins, ext_fields)
    closure_verdicts = {e: r["verdict"] for e, r in closure["extensions"].items()}
    return hs.emit_hook_scope(res, closure_verdicts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".", help="repository root")
    ap.add_argument("--json", action="store_true", help="emit the inventory as JSON")
    ap.add_argument("--no-provision", action="store_true",
                    help="do not establish the cache precondition; report what the "
                         "producer can reach as found (used to measure a cold tree)")
    ap.add_argument("--self-test", action="store_true", help="run the fixture suite")
    ap.add_argument("--hook-scope-selftest", action="store_true",
                    help="run the hook-scope fixture suite and pin BOTH yields")
    ap.add_argument("--hook-scope", action="store_true",
                    help="also derive criterion 2 over HOOK-reachable text (WI-D15) and print "
                         "it beside the shipped closure verdict. Reports only; the closure "
                         "verdict is what this tool returns and what a profile may rely on")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    if str(repo).startswith("/tmp"):
        # Inherited refusal, from classifier 1 through classifier 2: AILANG
        # auto-relaxes MOD010 under /tmp, so a run from there hides exactly the
        # interface failures this tool exists to report.
        print("harness: repo is under /tmp; AILANG auto-relaxes MOD010 there and interface "
              "failures are hidden. Run from the checkout.", file=sys.stderr)
        return 2

    if args.self_test:
        return self_test(repo)

    if args.hook_scope or args.hook_scope_selftest:
        return _hook_scope(repo, do_provision=not args.no_provision,
                           selftest=args.hook_scope_selftest)

    res = derive(repo, do_provision=not args.no_provision)
    if args.json:
        print(json.dumps(res, indent=2))
        bad = (res["provision_failures"] or res["producer_disagreements"]
               or set(res["std_modules_needed"]) - set(res["std_modules_resolved"])
               or any(r["verdict"] == "UNRESOLVED" for r in res["extensions"].values()))
        return 1 if bad else 0
    return emit(res)


if __name__ == "__main__":
    sys.exit(main())
