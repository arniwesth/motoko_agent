from extractor.effects import compute_effect_edges, oracle_report


def test_backward_effect_propagation_and_oracle():
    invokes = [{"from_slug": "m#a", "to_slug": "m#b", "resolution": "local", "approximate": 1}]
    std_calls = [{"from_slug": "m#b", "std_module": "std/env", "symbol": "getEnv", "resolution": "selective"}]
    catalog = {"granularity": "module", "module_effects": {"std/env": ["Env"]}, "symbol_effects": {}}
    edges = compute_effect_edges(std_calls, invokes, catalog)
    assert {"func_slug": "m#b", "effect": "Env", "source_func_slug": "m#b", "distance": 0, "derivation": "primitive_seed"} in edges
    assert {"func_slug": "m#a", "effect": "Env", "source_func_slug": "m#b", "distance": 1, "derivation": "backward_reachable"} in edges
    funcs = [{"slug": "m#a", "exported": 1, "module_iface_status": "ok"}]
    report = oracle_report(funcs, [{"func_slug": "m#a", "effect": "Env"}], edges)
    assert report["missing_declared"] == []
