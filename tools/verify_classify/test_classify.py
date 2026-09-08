#!/usr/bin/env python3
"""Regression tests for the contract classifier's fail-closed boundaries."""

import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import classify  # noqa: E402


class ClassifyTests(unittest.TestCase):
    def test_scan_preserves_requires_and_hashes_it(self) -> None:
        contracts = classify.scan(classify.SRC / "compress.ail")
        truncate = next(c for c in contracts if c.name == "truncate_with_suffix")
        self.assertEqual(("max_chars >= 0",), truncate.requires)

        changed = classify.Contract(
            module=truncate.module,
            name=truncate.name,
            params=truncate.params,
            ret=truncate.ret,
            requires=("max_chars > 0",),
            ensures=truncate.ensures,
            body=truncate.body,
        )
        self.assertNotEqual(truncate.contract_hash, changed.contract_hash)

    def test_both_probes_keep_the_original_requires(self) -> None:
        path = classify.SRC / "compress.ail"
        truncate = next(
            c for c in classify.scan(path) if c.name == "truncate_with_suffix"
        )
        source = classify.probe_source(path, [truncate])
        taut = source.split("pure func taut_truncate_with_suffix", 1)[1]
        taut, det = taut.split("pure func det_truncate_with_suffix", 1)

        self.assertIn("requires { max_chars >= 0 }", taut)
        self.assertIn(
            "requires { max_chars >= 0, _str_len(probe_result) <= max_chars }",
            det,
        )

    def test_precondition_only_ensures_classifies_as_tautology(self) -> None:
        fixture = HERE / "fixtures" / "precondition_tautology.ail"
        contract = classify.scan(fixture)[0]
        probe = classify.GEN / "precondition_tautology_probe.ail"
        classify.GEN.mkdir(parents=True, exist_ok=True)
        probe.write_text(classify.probe_source(fixture, [contract]))
        try:
            expected = {
                "taut_precondition_only",
                "det_precondition_only",
            }
            got = classify.verdicts(probe, expected)
        finally:
            probe.unlink(missing_ok=True)

        contract.taut = got["taut_precondition_only"][0]
        contract.det = got["det_precondition_only"][0]
        classify.classify([contract])
        self.assertEqual("tautology", contract.cls)

    def test_error_verdict_is_fatal_even_with_zero_exit_status(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=(
                "  \x1b[31m! ERROR\x1b[0m \x1b[1mprobe\x1b[0m\n"
                "    encoding error: unsupported body\n"
            ),
            stderr="",
        )
        with patch.object(classify.subprocess, "run", return_value=completed):
            with self.assertRaisesRegex(SystemExit, "reported ERROR for probe"):
                classify.verdicts(classify.SRC / "compress.ail", {"probe"})

    def test_missing_probe_verdict_is_fatal(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="parse error before verification\n",
            stderr="",
        )
        with patch.object(classify.subprocess, "run", return_value=completed):
            with self.assertRaisesRegex(SystemExit, "no verdict for probe"):
                classify.verdicts(classify.SRC / "compress.ail", {"probe"})


if __name__ == "__main__":
    unittest.main()
