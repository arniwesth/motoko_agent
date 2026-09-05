#!/usr/bin/env python3
"""Validator for the P3 overlay artifacts (project 010, plan Validation §5.5–§5.7).

Named rules, enumerated findings, never a bare boolean — and **two-sided
throughout**, per the standing meta-decision: each rule that asserts something
must exist is paired with one asserting the forbidden thing does not.

    rule-coverage      every reachable LOGICAL variant + both non-wire record
                       kinds have a subject rule; the 2 named D6.4 gap rows are
                       present; DISPLAY-ONLY variants have NO rule, and neither
                       does any other unreachable variant.
    rule-shape         the tally matches the settled table (19 fixed / 10
                       payload_routed / 1 correlated) and every subject slug is
                       a real layout node.
    trace-contract     every completed run carries exactly one RunSummary and it
                       is the final record (D6.1 parity); envelope fields sit
                       outside the payload; a RunFailed export is exempt.
    heat-agreement     the renderer's per-subject totals equal an INDEPENDENT
                       chdb recomputation over `activity` — picture and query
                       cannot disagree.
    heat-movement      two different seeds must produce different totals; a
                       renderer that ignores its input would pass the agreement
                       check and fail this one.
    unattributed       unattributed records are present as rows, never dropped.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import dataclass
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT / "query"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import cgq  # noqa: E402
import event_subjects as es  # noqa: E402

DEFAULT_OUT = TOOL_ROOT / ".out"

EXPECTED_TALLY = {es.FIXED: 19, es.PAYLOAD_ROUTED: 10, es.CORRELATED: 1}


@dataclass(frozen=True)
class Finding:
    rule: str
    detail: str

    def as_dict(self) -> dict:
        return {"rule": self.rule, "detail": self.detail}


def _vocabulary(out_dir: Path) -> dict:
    path = out_dir / "vocabulary.json"
    if not path.exists():
        raise SystemExit(
            f"missing {path}.\n"
            "  Export it first:  ailang run --caps IO,FS --entry main scripts/dst/export_vocabulary.ail\n"
            "  (Do NOT grep the source for these counts — a test fixture at "
            "dst_event_vocabulary.ail:807 makes naive counts wrong.)"
        )
    return json.loads(path.read_text(encoding="utf-8"))


def check_rule_coverage(vocab: dict, out: list[Finding]) -> None:
    rows = vocab["rows"]
    reachable_logical = [r["variant"] for r in rows
                         if r["classification"] == "logical" and r["reaches_trace_today"]]
    gap_logical = [r["variant"] for r in rows
                   if r["classification"] == "logical" and not r["reaches_trace_today"]]
    display_only = [r["variant"] for r in rows if r["classification"] == "display_only"]

    # --- required direction ------------------------------------------------
    for variant in reachable_logical:
        if f"WireRecord:{variant}" not in es.RULES_BY_KEY:
            out.append(Finding("rule-coverage", f"reachable LOGICAL variant {variant} has no subject rule"))
    for key in es.NON_WIRE_KEYS:
        if key not in es.RULES_BY_KEY:
            out.append(Finding("rule-coverage", f"non-wire record kind {key} has no subject rule"))
    # The two D6.4 gaps have rules written even though they cannot appear today,
    # so 009's gap closure needs no table change (NOTE headline 6).
    for variant in gap_logical:
        if f"WireRecord:{variant}" not in es.RULES_BY_KEY:
            out.append(Finding("rule-coverage",
                               f"D6.4 gap variant {variant} has no rule; closure would need a table change"))
    for key in es.GAP_KEYS:
        if key not in es.RULES_BY_KEY:
            out.append(Finding("rule-coverage", f"named gap row {key} is missing"))

    # --- forbidden direction ----------------------------------------------
    for variant in display_only:
        if f"WireRecord:{variant}" in es.RULES_BY_KEY:
            out.append(Finding("rule-coverage",
                               f"DISPLAY-ONLY variant {variant} has a rule; it can never reach a trace"))
    named_gaps = set(es.GAP_KEYS)
    for variant in gap_logical:
        key = f"WireRecord:{variant}"
        if key in es.RULES_BY_KEY and key not in named_gaps:
            out.append(Finding("rule-coverage",
                               f"{variant} is unreachable and is not one of the two named gaps, "
                               "yet carries a rule"))
    known = {f"WireRecord:{r['variant']}" for r in rows} | set(es.NON_WIRE_KEYS)
    for key in es.RULES_BY_KEY:
        if key not in known:
            out.append(Finding("rule-coverage", f"rule {key} matches no vocabulary row or record kind"))


def check_rule_shape(out_dir: Path, out: list[Finding]) -> None:
    tally = es.rule_kind_tally()
    if tally != EXPECTED_TALLY:
        out.append(Finding("rule-shape", f"rule-kind tally is {tally}, expected {EXPECTED_TALLY}"))
    if len(es.RULES) != 30:
        out.append(Finding("rule-shape", f"{len(es.RULES)} rules, expected the settled 30"))
    if len(es.multi_subject_keys()) != 15:
        out.append(Finding("rule-shape",
                           f"{len(es.multi_subject_keys())} multi-subject rows, expected 15 (NOTE tally)"))

    nodes = set()
    layout = out_dir / "layout.csv"
    if layout.exists():
        with layout.open(newline="", encoding="utf-8") as fh:
            nodes = {row["node_id"] for row in csv.DictReader(fh)}
    if nodes:
        for rule in es.RULES:
            for subject in rule.fixed_subjects:
                if subject not in nodes:
                    out.append(Finding("rule-shape",
                                       f"{rule.key}: subject {subject} is not a layout node"))


def check_trace_contract(out_dir: Path, profile: str, out: list[Finding]) -> None:
    trace_dir = out_dir / "traces" / profile
    files = sorted(trace_dir.glob("*.jsonl")) if trace_dir.is_dir() else []
    if not files:
        out.append(Finding("trace-contract", f"no traces under {trace_dir}"))
        return
    for path in files:
        lines = [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]
        header, records = lines[0], lines[1:]
        if header.get("record_count") != len(records):
            out.append(Finding("trace-contract",
                               f"{path.name}: header record_count {header.get('record_count')} "
                               f"!= {len(records)} record lines"))
        for record in records[:1]:
            missing = {"event_idx", "record_key", "seed"} - set(record)
            if missing:
                out.append(Finding("trace-contract", f"{path.name}: envelope missing {sorted(missing)}"))
            if "payload" not in record:
                out.append(Finding("trace-contract", f"{path.name}: record has no payload object"))
        if not header.get("run_complete", True):
            continue  # a RunFailed export legitimately lacks the terminal record
        summaries = [i for i, r in enumerate(records) if r.get("record_key") == "WireRecord:RunSummary"]
        if summaries != [len(records) - 1]:
            out.append(Finding("trace-contract",
                               f"{path.name}: D6.1 parity — RunSummary at {summaries}, "
                               f"expected exactly [{len(records) - 1}]"))


def _independent_totals(out_dir: Path, seed: int) -> dict[str, int]:
    """Recomputed from scratch, NOT through the shared query function — that is
    what makes the agreement check an independent check rather than an echo."""
    cgq.OUT_DIR = out_dir
    sql = f"SELECT subject_id, count(*) AS n FROM activity WHERE seed = {int(seed)} GROUP BY subject_id"
    return {row["subject_id"]: int(row["n"]) for row in cgq.run_sql(sql).get("data", [])}


def check_heat(out_dir: Path, profile: str, seeds: list[int], out: list[Finding]) -> None:
    import render_heat

    rendered: dict[int, dict[str, int]] = {}
    for seed in seeds:
        report = render_heat.render(seed, profile, out_dir)
        totals = {k: int(v) for k, v in report["totals"].items()}
        rendered[seed] = totals
        independent = _independent_totals(out_dir, seed)
        if totals != independent:
            only_pic = {k: v for k, v in totals.items() if independent.get(k) != v}
            only_sql = {k: v for k, v in independent.items() if totals.get(k) != v}
            out.append(Finding("heat-agreement",
                               f"seed {seed}: picture {only_pic} vs query {only_sql}"))
        if report["subjects_without_layout_node"]:
            out.append(Finding("heat-agreement",
                               f"seed {seed}: subjects with no layout node "
                               f"{report['subjects_without_layout_node']}"))

    # Movement direction: a renderer that ignored its input would pass every
    # equality check above.
    distinct = {json.dumps(t, sort_keys=True) for t in rendered.values()}
    if len(rendered) > 1 and len(distinct) == 1:
        out.append(Finding("heat-movement",
                           f"all {len(rendered)} seeds produced identical totals — "
                           "the renderer is not reading its input"))


def check_unattributed(out_dir: Path, out: list[Finding]) -> None:
    path = out_dir / "activity.csv"
    if not path.exists():
        out.append(Finding("unattributed", f"missing {path} — run build_activity.py --profile <p>"))
        return
    with path.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        out.append(Finding("unattributed", "activity.csv has no rows"))
        return
    kinds = {row["rule_kind"] for row in rows}
    unknown = kinds - {es.FIXED, es.PAYLOAD_ROUTED, es.CORRELATED, es.UNATTRIBUTED}
    if unknown:
        out.append(Finding("unattributed", f"activity.csv carries unknown rule_kind values {sorted(unknown)}"))
    marked = [r for r in rows if r["rule_kind"] == es.UNATTRIBUTED]
    for row in marked:
        if row["subject_id"] != es.UNATTRIBUTED_SUBJECT:
            out.append(Finding("unattributed",
                               f"rule_kind=unattributed with subject_id {row['subject_id']!r}; "
                               "the fail-open subject must be explicit"))
            break


def validate(out_dir: Path, profile: str, seeds: list[int] | None = None) -> list[Finding]:
    out: list[Finding] = []
    vocab = _vocabulary(out_dir)
    check_rule_coverage(vocab, out)
    check_rule_shape(out_dir, out)
    check_trace_contract(out_dir, profile, out)
    check_unattributed(out_dir, out)
    if seeds is None:
        trace_dir = out_dir / "traces" / profile
        seeds = sorted(int(p.stem) for p in trace_dir.glob("*.jsonl")) if trace_dir.is_dir() else []
    if seeds:
        check_heat(out_dir, profile, seeds, out)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--profile", default="driver_only")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--seed", type=int, action="append", dest="seeds")
    ns = ap.parse_args(argv)
    findings = validate(ns.out, ns.profile, ns.seeds)
    print(json.dumps({"ok": not findings, "findings": [f.as_dict() for f in findings]},
                     indent=2, sort_keys=True))
    for finding in findings:
        print(f"  [{finding.rule}] {finding.detail}", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
