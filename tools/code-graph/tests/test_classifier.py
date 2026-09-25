from pathlib import Path

from extractor.iface_pass import classify

FIX = Path(__file__).parent / "fixtures" / "iface"


def test_classifier_fixtures():
    cases = {
        "empty_stdout.txt": "failed",
        "warning_prefixed_json.txt": "ok",
        "truncated_json.txt": "failed",
        "valid_empty_funcs.txt": "partial",
        "stderr_only.txt": "failed",
        "valid_full.txt": "ok",
    }
    for name, expected in cases.items():
        assert classify((FIX / name).read_text(), 1).status == expected
