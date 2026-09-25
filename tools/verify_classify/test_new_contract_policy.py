#!/usr/bin/env python3
"""The mutation gate for new_contract_policy's SCOPE pass (027 ADR-001 §4, reading 2).

A new `pure func` reachable only from a `tests [...]` block is out of §4. The
GateTests hold the policy to what the ruling needs of it, by mutating a fixture
and running the REAL policy script against a scratch git repository -- the gate
asserted is the one CI runs, not a model of it:

  (a) a test-only helper made reachable from production ENTERS scope and turns
      the gate red -- applied, unapplied, aliased, interpolated, in a contract,
      in a lambda, exported, or by production calling the test itself;
  (b) a production declaration does NOT leave scope by being named test_* or
      *_test, moved under a test/ path, put in a *_test.ail file, commented as
      test-only, or given a tests block of its own;
  (c) the unmutated fixture is green, before and after.

Each mutation asserts its anchor text is present exactly once, so a fixture edit
that stops a mutation from applying fails here instead of passing vacuously.
"""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import new_contract_policy as policy  # noqa: E402

FIXTURE = (HERE / "fixtures" / "scope_gate.ail").read_text()
FIXTURE_MODULE = "module tools/verify_classify/fixtures/scope_gate"
TEST_ONLY = {"tag_of", "bump", "hook_fixture", "scope_gate_check"}


def mutate(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise AssertionError(f"mutation anchor found {text.count(old)} times: {old!r}")
    return text.replace(old, new)


def scope_of(body: str) -> "policy.Scope":
    return policy.module_scope("module src/core/m\n\n" + body)


class ScopeTests(unittest.TestCase):
    """The pass on its own: what makes an edge, and where it gives up."""

    def test_fixture_as_written(self) -> None:
        sc = policy.module_scope(FIXTURE)
        self.assertEqual(TEST_ONLY, {n for n in sc.edges if sc.exempt(n)})
        self.assertIn("export api", sc.why("render"))

    def test_dead_code_stays_in_scope(self) -> None:
        sc = scope_of("pure func orphan() -> int { 1 }\n")
        self.assertFalse(sc.exempt("orphan"))
        self.assertIn("dead code", sc.why("orphan"))

    def test_reached_from_both_is_in_scope(self) -> None:
        sc = scope_of("export pure func api() -> int { h() }\n"
                      "pure func h() -> int { 1 }\n"
                      "pure func t() -> bool\n  tests [((), true)]\n{ h() == 1 }\n")
        self.assertFalse(sc.exempt("h"))
        self.assertTrue(sc.exempt("t"))

    def test_test_case_inputs_are_test_roots(self) -> None:
        sc = scope_of("pure func sq(x: int) -> int\n  tests [(seven(), 49)]\n{ x * x }\n"
                      "pure func seven() -> int { 7 }\n")
        self.assertTrue(sc.exempt("sq"))
        self.assertTrue(sc.exempt("seven"))

    def test_every_mention_from_production_is_an_edge(self) -> None:
        # Applied or not: the edge is on the mention, never on the call.
        for how in ("h(1)",                                   # applied
                    "{ name: \"p\", run: h }",                # stored, not applied
                    "let f = h; f(1)",                        # aliased
                    "\"${show(h(1))}\"",                      # interpolated
                    "(func(y: int) -> int { h(y) })(1)",      # inside a lambda
                    "map(h, [1])"):                           # handed to a higher-order call
            sc = scope_of(f"export pure func api() -> int {{ {how} }}\n"
                          "pure func h(x: int) -> int { x }\n"
                          "pure func t() -> bool\n  tests [((), true)]\n{ h(1) == 1 }\n")
            self.assertFalse(sc.exempt("h"), how)

    def test_a_contract_clause_is_production_text(self) -> None:
        sc = scope_of("export pure func api(x: int) -> int\n  ensures { result == h(x) }\n{ x }\n"
                      "pure func h(x: int) -> int { x }\n"
                      "pure func t() -> bool\n  tests [((), true)]\n{ h(1) == 1 }\n")
        self.assertFalse(sc.exempt("h"))

    def test_comments_and_string_text_do_not_execute(self) -> None:
        sc = scope_of("export pure func api() -> string {\n"
                      "  -- calls h? no\n  // nor here: h\n  \"h -- h ${\"h\"}\"\n}\n"
                      "pure func h() -> int { 1 }\n"
                      "pure func t() -> bool\n  tests [((), true)]\n{ h() == 1 }\n")
        self.assertTrue(sc.exempt("h"))

    def test_equals_bodied_let_parses(self) -> None:
        sc = scope_of("export pure func api(x: int) -> int =\n  let y = h(x) in\n  y\n"
                      "pure func h(x: int) -> int { x }\n")
        self.assertFalse(sc.exempt("h"))

    def test_what_it_cannot_read_it_refuses(self) -> None:
        for bad in ("pure func f() -> string { \"open }\n",               # unterminated string
                    "pure func f() -> int { (1 }\n",                      # mismatched bracket
                    "instance Show Foo { show = h }\n",                   # no rule for it
                    "pure func f() -> int { 1 }\n  test \"x\" { h() }\n",  # absorbed into f
                    "pure func f() -> char { 'a' }\n",
                    "pure func f() -> int = tests [1]\n",
                    "pure func f() -> int { 1 }\npure func f() -> int { 2 }\n",
                    "import std/list [bad]\n"):
            with self.assertRaises(policy.ScopeUnknown, msg=bad):
                scope_of(bad)

    def test_every_module_in_src_core_is_read(self) -> None:
        # A module the pass cannot read keeps all its new declarations in scope,
        # which is safe but silent; this makes it loud.
        root = HERE.parents[1] / "src" / "core"
        for path in sorted(root.rglob("*.ail")):
            with self.subTest(path=path.relative_to(root)):
                policy.module_scope(path.read_text())


class GateTests(unittest.TestCase):
    """(a), (b), (c) against the real policy script in a scratch repository."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.repo = Path(tempfile.mkdtemp(prefix="scope_gate_"))
        cls.git("init", "-q")
        (cls.repo / "src" / "core").mkdir(parents=True)
        (cls.repo / "src" / "core" / "README").write_text("scratch\n")
        cls.git("add", "-A")
        cls.git("commit", "-q", "-m", "base")
        cls.base = cls.git("rev-parse", "HEAD").strip()

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls.repo, ignore_errors=True)

    @classmethod
    def git(cls, *args: str) -> str:
        return subprocess.run(
            ["git", "-c", "user.name=scope-gate", "-c", "user.email=scope-gate@invalid",
             "-c", "commit.gpgsign=false", *args],
            cwd=cls.repo, capture_output=True, text=True, check=True).stdout

    def gate(self, text: str, path: str = "src/core/scope_gate.ail") -> tuple[int, str]:
        """Commit `text` at `path` as the only module on top of the base; run the policy."""
        self.git("reset", "-q", "--hard", self.base)
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text.replace(FIXTURE_MODULE, f"module {path[:-len('.ail')]}", 1))
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "head")
        res = subprocess.run(
            [sys.executable, str(HERE / "new_contract_policy.py"),
             "--base", self.base, "--root", str(self.repo)],
            capture_output=True, text=True)
        return res.returncode, res.stdout + res.stderr

    def assert_green(self, text: str = FIXTURE) -> None:
        rc, out = self.gate(text)
        self.assertEqual(0, rc, out)
        self.assertIn("2 in-scope new pure func declarations, all justified; "
                      "4 more out of scope", out)

    def assert_red_on(self, text: str, names: set[str], path: str = "src/core/scope_gate.ail",
                      witness: str = "reachable from production: export api") -> None:
        rc, out = self.gate(text, path)
        self.assertEqual(1, rc, out)
        for name in names:
            self.assertIn(f"✗ {path} {name}:", out)
        self.assertIn(witness, out)

    # (c) ------------------------------------------------------------------
    def test_c_fixture_is_green(self) -> None:
        self.assert_green()

    # (a) ------------------------------------------------------------------
    def test_a_test_only_helper_reached_from_production_turns_red(self) -> None:
        api_body, render_body = "{\n  render(x)\n}", "{\n  x + 1\n}"
        cases = {
            "applied": (render_body, "{\n  let _t = tag_of(x);\n  x + 1\n}", {"tag_of"}),
            "unapplied": (api_body, "{\n  let _h: Hook = { name: \"p\", run: bump };\n"
                                    "  render(x)\n}", {"bump"}),
            "aliased": (render_body, "{\n  let f = tag_of;\n  x + 1\n}", {"tag_of"}),
            "interpolated": (api_body, "{\n  let _s = \"${tag_of(x)}\";\n  render(x)\n}",
                             {"tag_of"}),
            "in a lambda": (api_body, "{\n  let g = func(y: int) -> string { tag_of(y) };\n"
                                      "  render(x)\n}", {"tag_of"}),
            "in a contract": ("ensures { result == x + 1 }\n{\n  x + 1",
                              "ensures { result == x + 1 && tag_of(x) != \"\" }\n{\n  x + 1",
                              {"tag_of"}),
            "the test itself": (api_body, "{\n  if scope_gate_check() then render(x) "
                                          "else render(x)\n}", TEST_ONLY),
            "exported": ("pure func tag_of", "export pure func tag_of", {"tag_of"}),
        }
        for how, (old, new, names) in cases.items():
            with self.subTest(how=how):
                witness = ("export tag_of" if how == "exported"
                           else "reachable from production: export api")
                self.assert_red_on(mutate(FIXTURE, old, new), names, witness=witness)
        self.assert_green()   # (c) restored

    # (b) ------------------------------------------------------------------
    def test_b_production_does_not_leave_scope_by_looking_like_a_test(self) -> None:
        uncontracted = mutate(FIXTURE, "pure func render(x: int) -> int\n"
                                       "  ensures { result == x + 1 }\n{",
                              "pure func render(x: int) -> int\n{")
        self.assert_red_on(uncontracted, {"render"})   # the red it must keep

        def renamed(to: str) -> str:
            return uncontracted.replace("render(", f"{to}(")

        commented = mutate(uncontracted, "pure func render(",
                           "-- TEST-ONLY: fixture scaffolding, not production code.\n"
                           "-- contracts: test helper, out of scope\n"
                           "pure func render(")
        own_tests = mutate(uncontracted, "pure func render(x: int) -> int\n{",
                           "pure func render(x: int) -> int\n  tests [(1, 2)]\n{")
        everything = mutate(own_tests.replace("render(", "test_render("),
                            "pure func test_render(", "-- TEST-ONLY\npure func test_render(")
        cases = {
            "named test_*": (renamed("test_render"), {"test_render"}, None),
            "named *_test": (renamed("render_test"), {"render_test"}, None),
            "commented": (commented, {"render"}, None),
            "under test/": (uncontracted, {"render"}, "src/core/test/scope_gate.ail"),
            "a *_test.ail file": (uncontracted, {"render"}, "src/core/scope_gate_test.ail"),
            "with its own tests": (own_tests, {"render"}, None),
            "all of them": (everything, {"test_render"}, "src/core/test/scope_gate_test.ail"),
        }
        for how, (text, names, path) in cases.items():
            with self.subTest(how=how):
                self.assert_red_on(text, names, path or "src/core/scope_gate.ail")
        self.assert_green()   # (c) restored


if __name__ == "__main__":
    unittest.main()
