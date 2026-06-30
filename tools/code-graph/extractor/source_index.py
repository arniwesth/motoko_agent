from __future__ import annotations

import hashlib
from pathlib import Path

from . import config
from .slugs import module_slug, symbol_slug
from .source_parser import discover_files, func_spans

SOURCE_FILE_FIELDS = ["path", "module", "lang", "bytes", "sha256", "n_lines", "profile", "include_tests"]
SOURCE_LINE_FIELDS = ["path", "module", "lang", "line_no", "line", "is_comment", "profile", "include_tests"]
SOURCE_CHUNK_FIELDS = [
    "chunk_slug", "func_slug", "path", "module", "lang", "kind", "name", "start_line", "end_line", "text",
    "profile", "include_tests",
]


def language_for(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".ail":
        return "ailang"
    if suffix in {".ts", ".tsx"}:
        return "typescript"
    if suffix == ".md":
        return "markdown"
    if suffix == ".toml":
        return "toml"
    if suffix == ".json":
        return "json"
    if suffix == ".sh" or path.name.endswith(".sh"):
        return "shell"
    return "other"


def is_comment_line(lang: str, line: str) -> int:
    stripped = line.lstrip()
    if lang == "ailang":
        return int(stripped.startswith("--"))
    if lang == "typescript":
        return int(stripped.startswith("//"))
    if lang in {"shell", "toml"}:
        return int(stripped.startswith("#"))
    return 0


def _rel(path: Path, repo_root: Path) -> str:
    return path.resolve().relative_to(repo_root.resolve()).as_posix()


def _host_files(repo_root: Path, profile: str) -> list[Path]:
    if profile not in config.HOST_FILE_GLOBS:
        raise ValueError(f"unknown code-graph profile: {profile}")
    found: set[Path] = set()
    for pattern in config.HOST_FILE_GLOBS[profile]:
        matches = repo_root.glob(pattern)
        for path in matches:
            if path.is_file() and path.suffix.lower() != ".ail":
                found.add(path)
    return sorted(found, key=lambda p: _rel(p, repo_root))


def active_source_files(repo_root: Path, profile: str, include_tests: bool) -> list[Path]:
    ailang = discover_files(repo_root, profile=profile, include_tests=include_tests)
    files = set(ailang)
    files.update(_host_files(repo_root, profile))
    return sorted(files, key=lambda p: _rel(p, repo_root))


def _trim_trailing_blank(lines: list[str]) -> list[str]:
    end = len(lines)
    while end > 0 and lines[end - 1].strip() == "":
        end -= 1
    return lines[:end]


def build_source_index(
    repo_root: Path = config.REPO_ROOT,
    profile: str = config.DEFAULT_PROFILE,
    include_tests: bool = False,
) -> tuple[list[dict], list[dict], list[dict]]:
    source_files: list[dict] = []
    source_lines: list[dict] = []
    source_chunks: list[dict] = []
    include = int(include_tests)

    for path in active_source_files(repo_root, profile, include_tests):
        rel = _rel(path, repo_root)
        raw = path.read_bytes()
        text = raw.decode("utf-8")
        lines = text.splitlines()
        lang = language_for(path)
        module = module_slug(path, repo_root) if lang == "ailang" else ""
        source_files.append({
            "path": rel,
            "module": module,
            "lang": lang,
            "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "n_lines": len(lines),
            "profile": profile,
            "include_tests": include,
        })
        for idx, line in enumerate(lines, start=1):
            source_lines.append({
                "path": rel,
                "module": module,
                "lang": lang,
                "line_no": idx,
                "line": line,
                "is_comment": is_comment_line(lang, line),
                "profile": profile,
                "include_tests": include,
            })
        if lang != "ailang":
            continue
        for name, start, end, _exported in func_spans(text):
            chunk_lines = _trim_trailing_blank(lines[start:end])
            if not chunk_lines:
                raise ValueError(f"empty source chunk after trimming: {rel}:{start + 1}")
            source_chunks.append({
                "chunk_slug": f"{module}#func:{name}",
                "func_slug": symbol_slug(module, name),
                "path": rel,
                "module": module,
                "lang": "ailang",
                "kind": "func",
                "name": name,
                "start_line": start + 1,
                "end_line": start + len(chunk_lines),
                "text": "\n".join(chunk_lines),
                "profile": profile,
                "include_tests": include,
            })

    source_files.sort(key=lambda r: r["path"])
    source_lines.sort(key=lambda r: (r["path"], r["line_no"]))
    source_chunks.sort(key=lambda r: (r["path"], r["start_line"], r["chunk_slug"]))
    return source_files, source_lines, source_chunks
