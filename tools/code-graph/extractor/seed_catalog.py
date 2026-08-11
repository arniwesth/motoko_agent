"""Stdlib effect seed catalog.

v1 uses module-granular seeding from `ailang builtins list --by-effect` because
`ailang iface` cannot read stdlib modules in v0.26.0. The upstream request for public
stdlib function effect rows could not be filed from this environment because the
`ailang-feedback` skill is not installed in this Codex session; when filed, record the
URL here and flip `config.SEED_GRANULARITY` after implementing `parse_stdlib_public_iface`.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

from . import config


def parse_builtins_by_effect(text: str) -> dict[str, set[str]]:
    current = ""
    modules: dict[str, set[str]] = {}
    for line in text.splitlines():
        h = re.match(r"#\s+([A-Za-z0-9_]+)\s+\(\d+\)", line.strip())
        if h:
            current = h.group(1)
            continue
        m = re.match(r"\s+\S+\s+(std/\S+)", line)
        if not m or not current:
            continue
        modules.setdefault(m.group(1), set())
        if current != "Pure":
            modules[m.group(1)].add(current)
    return modules


def parse_stdlib_public_iface() -> dict[tuple[str, str], set[str]]:
    return {}


def build_catalog() -> dict:
    result = subprocess.run(["ailang", "builtins", "list", "--by-effect"],
                            capture_output=True, text=True, check=False)
    module_effects = parse_builtins_by_effect(result.stdout)
    symbol_effects: dict[tuple[str, str], set[str]] = {}
    if config.SEED_GRANULARITY == "symbol":
        symbol_effects = parse_stdlib_public_iface()
    return {
        "ailang_version": subprocess.run(["ailang", "--version"], capture_output=True, text=True,
                                         check=False).stdout.strip(),
        "granularity": config.SEED_GRANULARITY,
        "source": "builtins_by_effect",
        "module_effects": {k: sorted(v) for k, v in sorted(module_effects.items())},
        "symbol_effects": {f"{m}#{s}": sorted(v) for (m, s), v in sorted(symbol_effects.items())},
    }


def effects_for(catalog: dict, std_module: str, symbol: str) -> set[str]:
    if catalog.get("granularity") == "symbol":
        sym = set(catalog.get("symbol_effects", {}).get(f"{std_module}#{symbol}", []))
        if sym:
            return sym
    return set(catalog.get("module_effects", {}).get(std_module, []))


def write_catalog(path: Path = config.OUT_DIR / "seed_catalog.json") -> dict:
    path.parent.mkdir(parents=True, exist_ok=True)
    catalog = build_catalog()
    path.write_text(json.dumps(catalog, indent=2, sort_keys=True))
    return catalog
