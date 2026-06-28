import importlib.util
import sys


def load_cgq():
    path = __import__("pathlib").Path(__file__).resolve().parents[1] / "query" / "cgq.py"
    spec = importlib.util.spec_from_file_location("cgq_test_module", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_sql_literals_are_escaped():
    cgq = load_cgq()
    assert cgq.sql_lit("a'b") == "'a''b'"


def test_token_probe_failure_falls_back(monkeypatch):
    cgq = load_cgq()
    monkeypatch.setenv("CGQ_FORCE_TOKEN_PROBE_FAIL", "1")
    cgq._TOKEN_SUPPORT = None
    predicate, mode = cgq.search_predicate("text", "httpGet", "token")
    assert mode == "substring_fallback"
    assert "positionCaseInsensitive" in predicate
