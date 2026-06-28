from pathlib import Path

import pytest

from extractor.slugs import GraphIntegrityError
from extractor.source_parser import parse_all


def write(root: Path, rel: str, text: str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def parse(root: Path):
    return parse_all(sorted(root.rglob("*.ail")), root)


def test_imports_alias_selective_std_ctor_interpolation(tmp_path):
    write(tmp_path, "a/b.ail", "module a/b\nexport func f() -> int { 1 }\nexport func g() -> int { 2 }\n")
    main = write(tmp_path, "m.ail", """module m
import a/b as B
import std/env (getEnv)
type T = Ok(int) | Err(string)
func local() -> int { 1 }
func main() -> int {
  -- B.g()
  let s = "plain local() ignored ${ local() }"
  Ok(1)
  B.f() + getEnv("X")
}
""")
    mods = {p.slug: p for p in parse(tmp_path)}
    p = mods["m"]
    assert {"from_module": "m", "to_module": "a/b", "alias": "B", "symbols": ""} in p.imports
    assert {"from_slug": "m#main", "to_slug": "a/b#f", "resolution": "import", "approximate": 1} in p.invokes
    assert {"from_slug": "m#main", "to_slug": "m#local", "resolution": "interpolation", "approximate": 1} in p.invokes
    assert {"from_slug": "m#main", "std_module": "std/env", "symbol": "getEnv", "resolution": "selective"} in p.std_calls
    assert not [e for e in p.invokes if e["to_slug"].endswith("#Ok")]


def test_same_name_local_wins_and_strings_ignored(tmp_path):
    write(tmp_path, "a/b.ail", "module a/b\nexport func f() -> int { 1 }\n")
    write(tmp_path, "m.ail", """module m
import a/b (f)
func f() -> int { 2 }
func main() -> int { "f()"; f() }
""")
    p = {m.slug: m for m in parse(tmp_path)}["m"]
    assert {"from_slug": "m#main", "to_slug": "m#f", "resolution": "local", "approximate": 1} in p.invokes
    assert not [e for e in p.invokes if e["to_slug"] == "a/b#f"]


def test_duplicate_unqualified_import_errors(tmp_path):
    write(tmp_path, "a/b.ail", "module a/b\nexport func f() -> int { 1 }\n")
    write(tmp_path, "c/d.ail", "module c/d\nexport func f() -> int { 1 }\n")
    write(tmp_path, "m.ail", "module m\nimport a/b (f)\nimport c/d (f)\nfunc main() -> int { f() }\n")
    with pytest.raises(GraphIntegrityError):
        parse(tmp_path)
