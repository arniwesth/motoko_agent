from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


class GraphIntegrityError(RuntimeError):
    pass


def module_slug(path: Path, repo_root: Path) -> str:
    rel = path.resolve().relative_to(repo_root.resolve())
    return rel.with_suffix("").as_posix()


def symbol_slug(module: str, name: str) -> str:
    return f"{module}#{name}"


def assert_unique(table: str, rows: Iterable[dict], key: str = "slug") -> None:
    seen: dict[str, int] = {}
    for idx, row in enumerate(rows):
        value = row.get(key, "")
        if not value:
            continue
        if value in seen:
            raise GraphIntegrityError(f"duplicate {table}.{key}: {value} at rows {seen[value]} and {idx}")
        seen[value] = idx


@dataclass(frozen=True)
class ImportBinding:
    source_module: str
    target_module: str
    alias: str
    symbols: tuple[str, ...]
    is_std: bool


def check_duplicate_unqualified_imports(module: str, imports: Iterable[ImportBinding]) -> None:
    owner: dict[str, str] = {}
    for imp in imports:
        if imp.alias:
            continue
        for sym in imp.symbols:
            previous = owner.get(sym)
            if previous and previous != imp.target_module:
                raise GraphIntegrityError(
                    f"duplicate unqualified import in {module}: {sym} from {previous} and {imp.target_module}"
                )
            owner[sym] = imp.target_module
