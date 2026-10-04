import json
import threading
import time
from types import SimpleNamespace

import pytest

from extractor import iface_pass


def fake_iface(module: str) -> tuple[str, str]:
    # Later modules answer first, so completion order is the reverse of input order.
    time.sleep(0.02 * (5 - int(module[-1])))
    data = {"schema": "ailang.iface/v1", "module": module,
            "types": [{"name": f"T{module[-1]}", "ctors": ["Ok(int)"]}],
            "funcs": [{"name": "f", "type": f"(()) -> T{module[-1]} ! {{FS}}", "effects": ["FS"], "pure": False}]}
    return json.dumps(data), ""


def parsed(n: int) -> list:
    return [SimpleNamespace(slug=f"m{i}", funcs=[{"slug": f"m{i}#f", "module": f"m{i}", "name": "f"}])
            for i in range(n)]


def test_run_iface_all_keeps_input_order(monkeypatch):
    monkeypatch.setattr(iface_pass, "run_iface", fake_iface)
    modules = [f"m{i}" for i in range(5)]
    out = iface_pass.run_iface_all(modules, jobs=4)
    assert list(out) == modules
    assert all(json.loads(out[m][0])["module"] == m for m in modules)


def test_run_iface_all_runs_concurrently(monkeypatch):
    live, peak, lock = [0], [0], threading.Lock()

    def tracked(module: str) -> tuple[str, str]:
        with lock:
            live[0] += 1
            peak[0] = max(peak[0], live[0])
        time.sleep(0.05)
        with lock:
            live[0] -= 1
        return "{}", ""

    monkeypatch.setattr(iface_pass, "run_iface", tracked)
    iface_pass.run_iface_all([f"m{i}" for i in range(6)], jobs=3)
    assert peak[0] == 3
    peak[0] = 0
    iface_pass.run_iface_all([f"m{i}" for i in range(6)], jobs=1)
    assert peak[0] == 1


def test_apply_iface_is_the_same_at_any_job_count(monkeypatch):
    monkeypatch.setattr(iface_pass, "run_iface", fake_iface)
    monkeypatch.setenv("CODE_GRAPH_JOBS", "1")
    sequential = iface_pass.apply_iface(parsed(5))
    monkeypatch.setenv("CODE_GRAPH_JOBS", "4")
    assert iface_pass.apply_iface(parsed(5)) == sequential
    assert [r["module"] for r in sequential[5]] == [f"m{i}" for i in range(5)]


def test_iface_jobs_env(monkeypatch):
    monkeypatch.setenv("CODE_GRAPH_JOBS", "3")
    assert iface_pass.iface_jobs() == 3
    monkeypatch.setenv("CODE_GRAPH_JOBS", "0")
    assert iface_pass.iface_jobs() == 1
    monkeypatch.delenv("CODE_GRAPH_JOBS")
    assert 1 <= iface_pass.iface_jobs() <= 8
    monkeypatch.setenv("CODE_GRAPH_JOBS", "many")
    with pytest.raises(SystemExit):
        iface_pass.iface_jobs()


def test_uses_rows_do_not_depend_on_set_order(monkeypatch):
    # `type_refs` returns a set, and string hashing is seeded per process, so an
    # unsorted walk gives `uses.csv` a different row order on every run.
    def one(module: str) -> tuple[str, str]:
        data = {"schema": "ailang.iface/v1", "module": module, "types": [],
                "funcs": [{"name": "f", "type": "(Zed, Alpha, Mid, Beta, Omega, Kappa) -> Gamma", "effects": [], "pure": True}]}
        return json.dumps(data), ""

    monkeypatch.setattr(iface_pass, "run_iface", one)
    uses = iface_pass.apply_iface(parsed(1))[3]
    names = [u["type_slug"] for u in uses]
    assert names == sorted(names) and len(names) == 7

