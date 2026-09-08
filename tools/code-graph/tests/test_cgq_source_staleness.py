import csv
import hashlib
import importlib.util
import sys
from pathlib import Path


def load_cgq():
    path = Path(__file__).resolve().parents[1] / "query" / "cgq.py"
    spec = importlib.util.spec_from_file_location("cgq_stale_test_module", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_csv(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def test_source_stale_uses_indexed_file_hashes(tmp_path, monkeypatch):
    cgq = load_cgq()
    repo = tmp_path / "repo"
    out = tmp_path / "out"
    repo.mkdir()
    agents = repo / "AGENTS.md"
    agents.write_text("fresh\n")
    (repo / "UNINDEXED.md").write_text("outside\n")
    digest = hashlib.sha256(agents.read_bytes()).hexdigest()
    monkeypatch.setattr(cgq, "REPO_ROOT", repo)
    monkeypatch.setattr(cgq, "OUT_DIR", out)
    monkeypatch.setattr(cgq, "live_ailang_version", lambda: "ailang test")
    write_csv(out / "extraction_status.csv", [
        "module", "iface_status", "iface_detail", "iface_error", "built_at", "ailang_version",
        "graph_schema", "source_schema", "iface_schema", "profile", "include_tests",
    ], [{
        "module": "m", "iface_status": "ok", "iface_detail": "", "iface_error": "",
        "built_at": "2999-01-01T00:00:00+00:00", "ailang_version": "ailang test",
        "graph_schema": cgq.GRAPH_SCHEMA, "source_schema": cgq.SOURCE_SCHEMA,
        "iface_schema": "ailang.iface/v1", "profile": "core", "include_tests": 0,
    }])
    write_csv(out / "modules.csv", [
        "slug", "path", "module_decl", "decl_matches_path", "n_funcs", "is_generated", "is_root", "root_reason",
    ], [])
    write_csv(out / "source_files.csv", [
        "path", "module", "lang", "bytes", "sha256", "n_lines", "profile", "include_tests",
    ], [{
        "path": "AGENTS.md", "module": "", "lang": "markdown", "bytes": agents.stat().st_size,
        "sha256": digest, "n_lines": 1, "profile": "core", "include_tests": 0,
    }])

    meta = cgq.status_meta(cgq.QueryFlags())
    assert meta["source_stale"] is False
    (repo / "UNINDEXED.md").write_text("changed outside\n")
    assert cgq.status_meta(cgq.QueryFlags())["source_stale"] is False
    agents.write_text("changed\n")
    stale = cgq.status_meta(cgq.QueryFlags())
    assert stale["source_stale"] is True
    assert "hash mismatch" in stale["source_stale_reason"]
