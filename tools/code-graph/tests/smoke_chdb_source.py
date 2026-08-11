#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import tempfile
from pathlib import Path

import chdb


def query(sql: str) -> dict:
    return json.loads(str(chdb.query(sql, "JSON")))


def main() -> int:
    checks = [
        "SELECT positionCaseInsensitive('Alpha beta', 'BETA') AS ok",
        "SELECT match('alpha beta', '(?i)\\\\bbeta\\\\b') AS ok",
        "SELECT length(extractAll('a b c', '\\\\w+')) AS ok",
        "SELECT trimBoth('  x  ') = 'x' AS ok",
        "SELECT hasToken('a b', 'b') AS ok",
        "SELECT length(tokens('a b')) AS ok",
    ]
    for sql in checks:
        row = query(sql)["data"][0]
        if not int(row["ok"]):
            raise SystemExit(f"chDB source smoke failed: {sql}")

    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "roundtrip.csv"
        with path.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["id", "text"])
            writer.writeheader()
            writer.writerow({"id": 1, "text": 'line one\nline, two with "quote"'})
        escaped = str(path).replace("'", "''")
        row = query(
            f"SELECT text FROM file('{escaped}', 'CSVWithNames', 'id Int64, text String') WHERE id = 1"
        )["data"][0]
        if row["text"] != 'line one\nline, two with "quote"':
            raise SystemExit("chDB multiline CSV round-trip failed")

    print("source chdb smoke ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
