"""cgq.py's layout staleness banner (010, task 1.5 / Q7).

Two-sided: a layout built from the current extraction must report fresh, and a
layout whose snapshot key no longer matches the extraction must report stale.
The whole point of Q7's decision is that a stale map is a distrusted map, so
"never fires" and "always fires" are equally broken.
"""

from __future__ import annotations

import csv
import importlib.util
import sys
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT / "layout"))

import build_layout as bl  # noqa: E402


def load_cgq():
    path = TOOL_ROOT / "query" / "cgq.py"
    spec = importlib.util.spec_from_file_location("cgq_layout_test_module", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


STATUS_FIELDS = [
    "module", "iface_status", "iface_detail", "iface_error", "built_at", "ailang_version",
    "graph_schema", "source_schema", "iface_schema", "profile", "include_tests",
]


def _write(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _status_rows(built_at: str) -> list[dict]:
    return [{
        "module": "src/core/alpha", "iface_status": "ok", "iface_detail": "ok", "iface_error": "",
        "built_at": built_at, "ailang_version": "AILANG test", "graph_schema": 1, "source_schema": 1,
        "iface_schema": "ailang.iface/v1", "profile": "all", "include_tests": 0,
    }]


def _make_store(tmp_path: Path, built_at: str) -> tuple[Path, list[dict]]:
    out = tmp_path / "out"
    rows = _status_rows(built_at)
    _write(out / "extraction_status.csv", STATUS_FIELDS, rows)
    _write(
        out / "modules.csv",
        ["slug", "path", "module_decl", "decl_matches_path", "n_funcs", "is_generated", "is_root", "root_reason"],
        [{"slug": "src/core/alpha", "path": "src/core/alpha.ail", "module_decl": "src/core/alpha",
          "decl_matches_path": 1, "n_funcs": 3, "is_generated": 0, "is_root": 0, "root_reason": ""}],
    )
    _write(out / "imports.csv", ["from_module", "to_module", "alias", "symbols"], [])
    _write(out / "invokes.csv", ["from_slug", "to_slug", "resolution", "approximate"], [])
    bl.build(out, write=True, validate=True)
    return out, rows


def test_layout_reports_fresh_when_snapshot_matches(tmp_path, monkeypatch) -> None:
    cgq = load_cgq()
    out, rows = _make_store(tmp_path, "2026-08-08T00:00:00+00:00")
    monkeypatch.setattr(cgq, "OUT_DIR", out)
    stale, reason, snapshot = cgq._layout_freshness(rows, "all")
    assert stale is False
    assert reason is None
    assert snapshot == bl.compute_snapshot(rows, "all")


def test_layout_reports_stale_after_a_new_extraction(tmp_path, monkeypatch) -> None:
    cgq = load_cgq()
    out, _ = _make_store(tmp_path, "2026-08-08T00:00:00+00:00")
    monkeypatch.setattr(cgq, "OUT_DIR", out)
    # A re-extraction moves built_at; the layout on disk still carries the old key.
    newer = _status_rows("2026-08-09T00:00:00+00:00")
    stale, reason, _ = cgq._layout_freshness(newer, "all")
    assert stale is True
    assert "build_layout.py" in (reason or "")


def test_layout_reports_stale_when_the_table_is_missing(tmp_path, monkeypatch) -> None:
    cgq = load_cgq()
    out, rows = _make_store(tmp_path, "2026-08-08T00:00:00+00:00")
    (out / "layout.csv").unlink()
    monkeypatch.setattr(cgq, "OUT_DIR", out)
    stale, reason, snapshot = cgq._layout_freshness(rows, "all")
    assert stale is True
    assert snapshot is None
    assert "missing" in (reason or "")


def test_raw_sql_arms_the_right_projection_flags() -> None:
    cgq = load_cgq()
    assert cgq.flags_for_sql("SELECT * FROM layout").layout_query is True
    assert cgq.flags_for_sql("SELECT * FROM edges_agg").layout_query is True
    assert cgq.flags_for_sql("SELECT * FROM activity").activity_query is True
    plain = cgq.flags_for_sql("SELECT * FROM modules")
    assert plain.layout_query is False and plain.activity_query is False
