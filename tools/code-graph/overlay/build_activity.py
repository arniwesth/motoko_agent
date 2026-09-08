#!/usr/bin/env python3
"""Build the `activity` table (project 010, plan task 3.4; ADR-001 D1/D5).

    activity(seed, event_idx, record_key, subject_id, rule_kind)

Traces × the event-subject rules. Multi-subject records fan out to one row per
subject; `rule_kind` records how each subject was derived.

**BUILT PER PROFILE, NOT ACROSS PROFILES.** The D1 schema has no profile or run
column, so the same seed exported under two profiles would collide on every key.
`--profile` is required, only `.out/traces/<profile>/` is read, and the profile
is recorded in the build report. Cross-profile aggregation waits on the plan's
Gap 10 resolution at P5 — a run/profile identity column is one D1 amendment, not
two, and it is the ADR's to make.

**Nothing is ever dropped.** An unknown tool, extension or `ErrorEvent.source`
produces an `unattributed` row *and* a counted token in the build report, so the
growth the curated seed maps cannot anticipate is noticed rather than swallowed.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import event_subjects as es  # noqa: E402

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
DEFAULT_OUT = TOOL_ROOT / ".out"

ACTIVITY_FIELDS = ("seed", "event_idx", "record_key", "subject_id", "rule_kind")
TOOL_MODULE_FIELDS = ("key", "kind", "module")


def registry_names(repo_root: Path = REPO_ROOT) -> list[str]:
    """Extension package names from `ailang.toml [extensions] packages` — the
    same source `ailang generate-extension-registry` reads, so this cannot drift
    from `registry_generated.ail` without ailang.toml drifting first."""
    path = repo_root / "ailang.toml"
    if not path.exists():
        return []
    try:
        import tomllib

        data = tomllib.loads(path.read_text(encoding="utf-8"))
        entries = data.get("extensions", {}).get("packages", [])
    except Exception:
        entries = re.findall(r'"([^"]+)"', path.read_text(encoding="utf-8"))
    names = []
    for entry in entries:
        name = entry.split("@", 1)[0]
        names.append(name.rsplit("/", 1)[-1])
    return [n for n in names if n.startswith("motoko_")]


def known_nodes(out_dir: Path) -> set[str]:
    nodes: set[str] = set()
    layout = out_dir / "layout.csv"
    if layout.exists():
        with layout.open(newline="", encoding="utf-8") as fh:
            nodes |= {row["node_id"] for row in csv.DictReader(fh)}
    modules = out_dir / "modules.csv"
    if modules.exists():
        with modules.open(newline="", encoding="utf-8") as fh:
            nodes |= {row["slug"] for row in csv.DictReader(fh)}
    return nodes


def read_trace(path: Path) -> tuple[dict, list[dict]]:
    lines = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not lines:
        raise SystemExit(f"{path}: empty trace file")
    return lines[0], lines[1:]


def correlation_map(records: list[dict]) -> dict[str, str]:
    """`V2ToolDispatchComplete` carries no `tool` and must join to its Start by
    `id` within the same trace — the one correlated row in the table."""
    out: dict[str, str] = {}
    for record in records:
        if record.get("record_key") == "WireRecord:V2ToolDispatchStart":
            payload = record.get("payload") or {}
            ident, tool = payload.get("id"), payload.get("tool")
            if isinstance(ident, str) and isinstance(tool, str):
                out[ident] = tool
    return out


def build(out_dir: Path, profile: str) -> tuple[list[dict], list[dict], dict]:
    trace_dir = out_dir / "traces" / profile
    if not trace_dir.is_dir():
        raise SystemExit(
            f"no traces for profile {profile!r} at {trace_dir}.\n"
            f"  Export one first:  scripts/dst/run_export_trace.sh --seed <n> --profile {profile}"
        )
    trace_files = sorted(trace_dir.glob("*.jsonl"))
    if not trace_files:
        raise SystemExit(f"{trace_dir} contains no .jsonl traces")

    nodes = known_nodes(out_dir)
    tool_map = es.build_tool_module_map(registry_names(), nodes)
    error_sources = es.load_error_sources()

    rows: list[dict] = []
    report: dict = {
        "profile": profile,
        "trace_files": len(trace_files),
        "seeds": [],
        "records": 0,
        "activity_rows": 0,
        "unattributed_rows": 0,
        "rule_kind_counts": {},
        "record_keys_seen": {},
        "unresolved_tokens": {},
        "incomplete_runs": [],
        "tool_map": {
            "native_tools": len(tool_map.native),
            "extensions_resolved": len(tool_map.ext_packages),
            "extensions_unresolved": tool_map.unresolved_ext,
            "native_rows_rejected": tool_map.rejected_native,
        },
        "unknown_error_sources": [],
    }

    for path in trace_files:
        header, records = read_trace(path)
        seed = header.get("seed")
        report["seeds"].append(seed)
        if not header.get("run_complete", True):
            report["incomplete_runs"].append({"seed": seed, "failure_kind": header.get("failure_kind")})
        correlation = correlation_map(records)
        for record in records:
            key = record.get("record_key", "")
            payload = record.get("payload") or {}
            report["records"] += 1
            report["record_keys_seen"][key] = report["record_keys_seen"].get(key, 0) + 1
            attributions, unresolved = es.attribute(key, payload, tool_map, error_sources, correlation)
            for token in unresolved:
                report["unresolved_tokens"][token] = report["unresolved_tokens"].get(token, 0) + 1
                if "error_source" in token:
                    report["unknown_error_sources"].append(token)
            for attribution in attributions:
                rows.append({
                    "seed": seed,
                    "event_idx": record.get("event_idx"),
                    "record_key": key,
                    "subject_id": attribution.subject_id,
                    "rule_kind": attribution.rule_kind,
                })
                report["rule_kind_counts"][attribution.rule_kind] = \
                    report["rule_kind_counts"].get(attribution.rule_kind, 0) + 1
                if attribution.subject_id == es.UNATTRIBUTED_SUBJECT:
                    report["unattributed_rows"] += 1

    rows.sort(key=lambda r: (r["seed"], r["event_idx"], r["subject_id"], r["rule_kind"]))
    report["activity_rows"] = len(rows)
    report["seeds"] = sorted(set(report["seeds"]))
    return rows, tool_map.rows(), report


def write_csv(path: Path, fields: tuple[str, ...], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(fields), lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--profile", required=True,
                    help="trace profile to build (required: the D1 schema has no profile column, "
                         "so one activity.csv covers exactly one profile)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--dry-run", action="store_true")
    ns = ap.parse_args(argv)

    rows, tool_rows, report = build(ns.out, ns.profile)
    if not ns.dry_run:
        write_csv(ns.out / "activity.csv", ACTIVITY_FIELDS, rows)
        write_csv(ns.out / "tool_modules.csv", TOOL_MODULE_FIELDS, tool_rows)
        report["written"] = [str(ns.out / "activity.csv"), str(ns.out / "tool_modules.csv")]
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
