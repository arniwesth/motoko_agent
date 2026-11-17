#!/usr/bin/env python3
"""039 random-mutant pilot: build mutants.tsv from what is on disk.

    assemble.py        write mutants.tsv: one row per drawn site (38), the 30 mutants and the 8 that
                       did not type-check, with every tier's state read from runs/ by the scorers,
                       the triage from triage.tsv, and the prediction from predictions.tsv

Nothing here is typed by hand except triage.tsv, which is the judgement and says so.
"""
import csv
import os
import sys

E = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(E, "scripts"))
import score  # noqa: E402
import score_target  # noqa: E402

T3 = ["check_core", "strict_replay", "discovery", "stream_parity", "ledger_parity", "corpus_pr"]


def tsv(p):
    with open(os.path.join(E, p), encoding="utf-8") as f:
        rows = list(csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE))
    return [dict(zip(rows[0], r)) for r in rows[1:] if r and r[0]]


def main():
    draws = tsv("draw-checked.tsv")
    cands = {c["id"]: c for c in tsv("enumeration-a1/candidates.tsv")}
    preds = {p["mutant"]: p for p in tsv("predictions.tsv")}
    reach = {r["probe"][2:]: r for r in tsv("reach-probes.tsv") if r["probe"].startswith("X-m")}
    triage = {t["mutant"]: t for t in tsv("triage.tsv")} if os.path.exists(os.path.join(E, "triage.tsv")) else {}
    out = []
    for d in draws:
        c = cands[d["drawn_candidate"]]
        m = d["mutant_no"]
        row = {"rank": d["rank"], "mutant": m, "candidate": d["drawn_candidate"], "function": c["function"],
               "operator": c["operator"], "shape": c["shape"],
               "edit": f"{c['old'][:90]} => {c['new'][:90] or '(deleted)'}", "type_check": d["type_check"]}
        if m == "-":
            row.update({"tier1": "-", "tier1_kills": "-", "tier1_also": "-", "reach": "-",
                        "tier3": "-", "tier4": "-", "stopped_at": "did not type-check: " + d["first_error"][:120]})
            out.append(row)
            continue
        r1 = score.score_id(m)
        row["tier1"] = r1["state"]
        row["tier1_kills"] = r1["kills"]
        row["tier1_also"] = r1["also"]
        rr = reach.get(m)
        row["reach"] = f"{rr['reading']} ({rr['first_reacher']})" if rr else "not probed: killed at tier 1"
        t3 = []
        for t in T3:
            d3 = os.path.join(E, "runs", t, m)
            if os.path.exists(os.path.join(d3, "rc")):
                st, lines, rc, wall = score_target.score_id(t, m)
                t3.append(f"{t}={st}" + (f" [{lines[0][:100]}]" if st not in ("GREEN",) and lines else ""))
        row["tier3"] = "; ".join(t3) or "-"
        d4 = os.path.join(E, "runs", "dst", m)
        if os.path.exists(os.path.join(d4, "rc")):
            st, lines, rc, wall = score_target.score_id("dst", m)
            row["tier4"] = f"dst={st}" + (f" [{' | '.join(lines[:2])[:160]}]" if lines else "")
        else:
            row["tier4"] = "-"
        tr = triage.get(m, {})
        for k in ("verdict", "stopped_at", "stated_rule_says", "checker_reports", "judgement", "known_list"):
            row[k] = tr.get(k, "")
        p = preds[m]
        row["predicted"] = f"{p['predicted_tier1']} / {p['check_expected_to_name_it']}"
        row["prediction_outcome"] = tr.get("prediction_outcome", "")
        out.append(row)
    keys = ["rank", "mutant", "candidate", "function", "operator", "shape", "edit", "type_check", "tier1",
            "tier1_kills", "tier1_also", "reach", "tier3", "tier4", "verdict", "stopped_at", "stated_rule_says",
            "checker_reports", "judgement", "known_list", "predicted", "prediction_outcome"]
    with open(os.path.join(E, "mutants.tsv"), "w", encoding="utf-8") as o:
        o.write("\t".join(keys) + "\n")
        for r in out:
            o.write("\t".join(str(r.get(k, "")).replace("\t", " ").replace("\n", " ") for k in keys) + "\n")
    print(f"{len(out)} rows")


if __name__ == "__main__":
    main()
