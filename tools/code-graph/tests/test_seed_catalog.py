from extractor.seed_catalog import effects_for, parse_builtins_by_effect


def test_parse_builtins_by_effect_drops_pure():
    text = """# Net (2)
  _net_httpGet                  std/net

# Pure (1)
  _list_length                  std/list
"""
    cat = parse_builtins_by_effect(text)
    assert cat["std/net"] == {"Net"}
    assert cat["std/list"] == set()


def test_effects_for_module_granular():
    catalog = {"granularity": "module", "module_effects": {"std/env": ["Env"]}, "symbol_effects": {}}
    assert effects_for(catalog, "std/env", "getEnv") == {"Env"}
