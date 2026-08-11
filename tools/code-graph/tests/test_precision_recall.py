import json
from pathlib import Path

from extractor.source_parser import parse_all


def test_sample3_precision_recall():
    root = Path(__file__).parent / "fixtures" / "sample3"
    expected = set()
    for path in root.glob("*.expected_invokes.json"):
        for row in json.loads(path.read_text()):
            expected.add((row["from_slug"], row["to_slug"]))
    actual = set()
    for module in parse_all(sorted(root.glob("*.ail")), root):
        for row in module.invokes:
            actual.add((row["from_slug"], row["to_slug"]))
    tp = len(actual & expected)
    precision = tp / len(actual) if actual else 1
    recall = tp / len(expected) if expected else 1
    assert precision >= 0.8
    assert recall >= 0.8
