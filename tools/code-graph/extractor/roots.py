from __future__ import annotations

import json
import re
from pathlib import Path

from . import config


def _module_from_path(path: Path) -> str:
    return path.relative_to(config.REPO_ROOT).with_suffix("").as_posix()


def assemble_roots(files: list[Path]) -> dict[str, str]:
    roots: dict[str, str] = {}
    for ts in list((config.REPO_ROOT / "src" / "tui" / "src").glob("*.ts")) + [
        config.REPO_ROOT / "src" / "tui" / "src" / "index.ts",
        config.REPO_ROOT / "src" / "tui" / "src" / "runtime-process.ts",
    ]:
        if not ts.exists():
            continue
        for m in re.findall(r"(src/core/[A-Za-z0-9_/.-]+)\.ail", ts.read_text(errors="ignore")):
            roots[m] = "ts_host"

    reg = config.REPO_ROOT / "src/core/ext/registry_generated.ail"
    if reg.exists():
        roots["src/core/ext/registry_generated"] = "generated"
        for m in re.findall(r"(src/core/ext/[A-Za-z0-9_/.-]+)", reg.read_text(errors="ignore")):
            roots[m] = roots.get(m, "extension")

    toml = config.REPO_ROOT / "ailang.toml"
    if toml.exists():
        for m in re.findall(r'"(src/core/ext/[A-Za-z0-9_/.-]+)"', toml.read_text(errors="ignore")):
            roots[m] = "extension"

    cfg = config.REPO_ROOT / "config.json"
    if cfg.exists():
        try:
            data = json.loads(cfg.read_text())
            for key in ("order", "extensions"):
                values = data.get(key) if isinstance(data, dict) else None
                if isinstance(values, list):
                    for value in values:
                        if isinstance(value, str) and value.startswith("src/core/ext/"):
                            roots[value.removesuffix(".ail")] = "extension"
        except json.JSONDecodeError:
            pass

    for path in files:
        text = path.read_text(errors="ignore")
        mod = _module_from_path(path)
        rel = path.relative_to(config.REPO_ROOT).as_posix()
        if "/registry_generated.ail" in rel:
            roots[mod] = "generated"
        elif rel.startswith("scripts/") and re.search(r"^(?:export\s+)?(?:pure\s+)?func\s+main\b", text, re.M):
            roots[mod] = "script_main"
        elif (rel.startswith("examples/") or rel.startswith("src/examples/")) and re.search(
            r"^(?:export\s+)?(?:pure\s+)?func\s+main\b", text, re.M
        ):
            roots[mod] = "example_main"
        elif rel.endswith("_test.ail") or rel.startswith("src/core/test/") or re.search(
            r'^(?:test\s+"|property\s+")', text, re.M
        ):
            roots[mod] = "test"
    return roots
