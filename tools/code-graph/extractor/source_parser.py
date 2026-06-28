from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from . import config
from .slugs import ImportBinding, check_duplicate_unqualified_imports, module_slug, symbol_slug

DECL_RE = re.compile(r"^(?P<export>export\s+)?(?:pure\s+)?func\s+(?P<name>[A-Za-z_]\w*)", re.M)
TOPLEVEL_RE = re.compile(r"^(?:export\s+)?(?:pure\s+)?(?:func|type)\b|^module\b|^import\b", re.M)
IMPORT_RE = re.compile(r"^import\s+(\S+)(?:\s+as\s+(\w+))?\s*(?:\(([^)]*)\))?", re.M)
MODULE_RE = re.compile(r"^module\s+(\S+)", re.M)
CALL_RE = re.compile(r"(?<![.\w])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*\(")
TYPE_RE = re.compile(r"^type\s+([A-Z][A-Za-z0-9_]*)\b", re.M)

KEYWORDS = {
    "if", "then", "else", "let", "match", "func", "type", "module", "import", "requires",
    "ensures", "in", "case", "of", "true", "false", "and", "or", "not", "test", "property",
}


@dataclass
class ParsedModule:
    slug: str
    path: str
    module_decl: str
    decl_matches_path: int
    funcs: list[dict] = field(default_factory=list)
    imports: list[dict] = field(default_factory=list)
    invokes: list[dict] = field(default_factory=list)
    std_calls: list[dict] = field(default_factory=list)
    ctors: list[dict] = field(default_factory=list)
    import_bindings: list[ImportBinding] = field(default_factory=list)


def discover_files(repo_root: Path = config.REPO_ROOT) -> list[Path]:
    files: list[Path] = []
    for root in config.SOURCE_ROOTS:
        base = repo_root / root
        if base.exists():
            files.extend(base.rglob("*.ail"))
    return sorted(files)


def parse_module_decl(text: str, fallback: str) -> str:
    m = MODULE_RE.search(text)
    return m.group(1) if m else fallback


def parse_import_bindings(text: str, source_module: str) -> list[ImportBinding]:
    imports: list[ImportBinding] = []
    for m in IMPORT_RE.finditer(text):
        target, alias, raw_symbols = m.group(1), m.group(2) or "", m.group(3) or ""
        symbols = tuple(s.strip() for s in raw_symbols.split(",") if s.strip())
        imports.append(ImportBinding(source_module, target, alias, symbols, target.startswith("std/")))
    check_duplicate_unqualified_imports(source_module, imports)
    return imports


def func_spans(text: str) -> list[tuple[str, int, int, bool]]:
    lines = text.splitlines()
    starts: list[tuple[str, int, bool]] = []
    top: list[int] = []
    for i, line in enumerate(lines):
        if TOPLEVEL_RE.match(line):
            top.append(i)
        m = re.match(r"^(?P<export>export\s+)?(?:pure\s+)?func\s+(?P<name>[A-Za-z_]\w*)", line)
        if m:
            starts.append((m.group("name"), i, bool(m.group("export"))))
    spans: list[tuple[str, int, int, bool]] = []
    for name, start, exported in starts:
        end = next((idx for idx in top if idx > start), len(lines))
        spans.append((name, start, end, exported))
    return spans


def _strip_comments_keep_newlines(text: str) -> str:
    return re.sub(r"--[^\n]*", "", text)


def _strip_strings_and_collect_interpolations(text: str) -> tuple[str, list[str]]:
    out: list[str] = []
    interps: list[str] = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch != '"':
            out.append(ch)
            i += 1
            continue
        out.append('"')
        i += 1
        while i < len(text):
            if text[i] == "\\":
                out.append(" ")
                i += 2
                continue
            if text[i] == '"' :
                out.append('"')
                i += 1
                break
            if text[i:i + 2] == "${":
                depth = 1
                j = i + 2
                while j < len(text) and depth:
                    if text[j] == "{":
                        depth += 1
                    elif text[j] == "}":
                        depth -= 1
                    j += 1
                interps.append(text[i + 2:j - 1])
                out.extend(" " * (j - i))
                i = j
                continue
            out.append("\n" if text[i] == "\n" else " ")
            i += 1
    return "".join(out), interps


def strip_noise(text: str) -> tuple[str, list[str]]:
    return _strip_strings_and_collect_interpolations(_strip_comments_keep_newlines(text))


def parse_source_ctors(text: str, module: str) -> list[dict]:
    lines = text.splitlines()
    top = [i for i, line in enumerate(lines) if TOPLEVEL_RE.match(line)]
    ctors: list[dict] = []
    for i, line in enumerate(lines):
        m = TYPE_RE.match(line)
        if not m:
            continue
        type_name = m.group(1)
        end = next((idx for idx in top if idx > i), len(lines))
        block = "\n".join(lines[i:end])
        if "=" not in block:
            continue
        rhs = block.split("=", 1)[1]
        for cname in re.findall(r"(?:^|\|)\s*([A-Z][A-Za-z0-9_]*)\b", rhs):
            ctors.append({
                "slug": symbol_slug(module, cname),
                "module": module,
                "name": cname,
                "type_slug": symbol_slug(module, type_name),
                "source": "source",
            })
    return ctors


def _binding_maps(bindings: list[ImportBinding]):
    bare: dict[str, ImportBinding] = {}
    qualified: dict[str, ImportBinding] = {}
    for imp in bindings:
        q = imp.alias or imp.target_module.split("/")[-1]
        qualified[q] = imp
        if not imp.alias:
            for sym in imp.symbols:
                bare[sym] = imp
    return bare, qualified


def _resolve_call(call: str, module: str, local_funcs: set[str], all_funcs: dict[str, set[str]],
                  bare: dict[str, ImportBinding], qualified: dict[str, ImportBinding],
                  ctor_names: set[str]) -> tuple[str, str, str] | None:
    if call in KEYWORDS or call in ctor_names:
        return None
    if "." in call:
        prefix, member = call.split(".", 1)
        imp = qualified.get(prefix)
        if not imp or member in ctor_names:
            return None
        if imp.is_std:
            return ("std", imp.target_module, member)
        if member in all_funcs.get(imp.target_module, set()):
            return ("import", symbol_slug(imp.target_module, member), member)
        return None
    if call in local_funcs:
        return ("local", symbol_slug(module, call), call)
    imp = bare.get(call)
    if imp:
        if imp.is_std:
            return ("std", imp.target_module, call)
        if call in all_funcs.get(imp.target_module, set()):
            return ("import", symbol_slug(imp.target_module, call), call)
    return None


def parse_all(files: list[Path] | None = None, repo_root: Path = config.REPO_ROOT) -> list[ParsedModule]:
    files = files or discover_files(repo_root)
    texts = {path: path.read_text() for path in files}
    modules = {path: module_slug(path, repo_root) for path in files}
    all_funcs: dict[str, set[str]] = {}
    for path, text in texts.items():
        all_funcs[modules[path]] = {name for name, _, _, _ in func_spans(text)}

    parsed: list[ParsedModule] = []
    for path in files:
        text = texts[path]
        mod = modules[path]
        decl = parse_module_decl(text, mod)
        rel = path.resolve().relative_to(repo_root.resolve()).as_posix()
        bindings = parse_import_bindings(text, mod)
        p = ParsedModule(mod, rel, decl, int(decl == mod), import_bindings=bindings)
        for imp in bindings:
            if not imp.is_std and imp.target_module in all_funcs:
                p.imports.append({
                    "from_module": mod,
                    "to_module": imp.target_module,
                    "alias": imp.alias,
                    "symbols": "|".join(imp.symbols),
                })
        spans = func_spans(text)
        p.funcs = [{
            "slug": symbol_slug(mod, name),
            "module": mod,
            "name": name,
            "exported": int(exported),
            "is_internal": int(not exported),
            "has_typed_sig": 0,
            "type_sig": "",
            "declared_effects": "",
            "pure": "",
            "module_iface_status": "",
        } for name, _, _, exported in spans]
        p.ctors = parse_source_ctors(text, mod)
        ctor_names = {row["name"] for row in p.ctors}
        local_funcs = {row["name"] for row in p.funcs}
        bare, qualified = _binding_maps(bindings)
        lines = text.splitlines()
        for name, start, end, _exported in spans:
            body = "\n".join(lines[start:end])
            clean, interps = strip_noise(body)
            from_slug = symbol_slug(mod, name)
            seen: set[tuple[str, str, str]] = set()
            for call in CALL_RE.findall(clean):
                if call == name:
                    continue
                resolved = _resolve_call(call, mod, local_funcs, all_funcs, bare, qualified, ctor_names)
                if not resolved:
                    continue
                kind, target, member = resolved
                if kind == "std":
                    key = (from_slug, target, member)
                    if key not in seen:
                        p.std_calls.append({"from_slug": from_slug, "std_module": target, "symbol": member,
                                            "resolution": "qualified" if "." in call else "selective"})
                        seen.add(key)
                else:
                    key = (from_slug, target, kind)
                    if key not in seen:
                        p.invokes.append({"from_slug": from_slug, "to_slug": target,
                                          "resolution": kind, "approximate": 1})
                        seen.add(key)
            for expr in interps:
                for call in CALL_RE.findall(expr):
                    if call == name:
                        continue
                    resolved = _resolve_call(call, mod, local_funcs, all_funcs, bare, qualified, ctor_names)
                    if not resolved:
                        continue
                    kind, target, member = resolved
                    if kind == "std":
                        p.std_calls.append({"from_slug": from_slug, "std_module": target, "symbol": member,
                                            "resolution": "qualified" if "." in call else "selective"})
                    else:
                        p.invokes.append({"from_slug": from_slug, "to_slug": target,
                                          "resolution": "interpolation", "approximate": 1})
        parsed.append(p)
    return parsed
