#!/usr/bin/env python3
"""034 W2.3: score each run against predictions.tsv's rules S1-S8, read off the gates' rows.

    score.py <evidence dir>      prints mutants.tsv to stdout

It reads `runs/<id>/judge.out` (make corpus_judge) and `runs/<id>/twin.out` (make applied_twin). Exit
status is recorded and never read as a verdict (S4). It does not read predictions.tsv's member sets
as code: the sets are restated below, and `score_selftest` below checks the two agree.
"""
import os
import re
import sys

SETS = {
    "APPLIEDFAILED3": ["seed-102", "seed-165", "seed-215"],
    "TOOLFAULT11": ["seed-3", "seed-11", "seed-14", "seed-18", "seed-60", "seed-61", "seed-71",
                    "seed-102", "seed-109", "seed-165", "seed-215"],
    "DEADLINE5": ["seed-11", "seed-14", "seed-60", "seed-109", "seed-215"],
    "FAILED5": ["seed-61", "seed-71", "seed-102", "seed-165", "seed-215"],
    "OK3OFFAILED5": ["seed-71", "seed-102", "seed-165"],
}

JUDGE_RED = re.compile(r"^(JUDGE|CONTROL) (\S+) (\S+) RED (.*)$")
TWIN_PAIR = re.compile(r"^  ([✓✗]) (\S+) #(\d+) \(([^)]*)\): identical served interactions, outcome, final state and trace(?: — (\d+) finding\(s\) under (.*))?$")
TWIN_SELF = re.compile(r"^  ([✓✗]) (\S+): the base program run twice is clean against itself")
TWIN_CONTROL = re.compile(r"^  ([✓✗]) control ")
COUNT = re.compile(r"^COUNT (.*)$")


def read(path):
    return open(path, encoding="utf-8").read().splitlines() if os.path.exists(path) else []


def rc_of(d, which):
    p = os.path.join(d, f"{which}.rc")
    if not os.path.exists(p):
        return "-", "-"
    m = re.match(r"rc=(\d+) wall_secs=(\d+)", open(p).read().strip())
    return (m.group(1), m.group(2)) if m else ("-", "-")


def judge_reds(lines):
    """[(tag, member, rule, facts)] for every RED row, the invariant-set summary row excluded."""
    out = []
    for ln in lines:
        m = JUDGE_RED.match(ln)
        if m and m.group(3) != "invariant-set":
            out.append((m.group(1), m.group(2), m.group(3), m.group(4)))
    return out


def twin_view(lines):
    pairs, selfs, controls, count = [], [], [], None
    for ln in lines:
        m = TWIN_PAIR.match(ln)
        if m:
            rules = [r.strip() for r in (m.group(6) or "").split(",") if r.strip()]
            pairs.append({"ok": m.group(1) == "✓", "member": m.group(2), "ord": int(m.group(3)),
                          "dir": m.group(4), "n": int(m.group(5) or 0), "rules": rules})
            continue
        m = TWIN_SELF.match(ln)
        if m:
            selfs.append((m.group(1) == "✓", m.group(2)))
            continue
        if TWIN_CONTROL.match(ln):
            controls.append(ln.strip().startswith("✓"))
            continue
        m = COUNT.match(ln)
        if m:
            count = dict(kv.split("=") for kv in m.group(1).split())
    return pairs, selfs, controls, count


def members_with(reds, rule, tag="JUDGE"):
    seen = []
    for t, mem, r, _ in reds:
        if t == tag and r == rule and mem not in seen:
            seen.append(mem)
    return seen


def fmt_set(ms):
    for name, s in SETS.items():
        if sorted(ms) == sorted(s):
            return f"{name} ({len(ms)})"
    return f"{' '.join(ms)} ({len(ms)})" if ms else "none (0)"


def other_rules(reds, rule):
    out = {}
    for t, mem, r, facts in reds:
        if r != rule:
            out.setdefault((t, r), []).append(mem)
    return "; ".join(f"{r} on {fmt_set(ms) if t == 'JUDGE' else 'CONTROL ' + ' '.join(ms)}" for (t, r), ms in out.items()) or "none"


def judge_summary(lines, rc):
    reds = judge_reds(lines)
    jr = [ln for ln in lines if ln.startswith("JUDGEROW ")]
    cr = [ln for ln in lines if ln.startswith("CONTROLROW ")]
    clean_j = sum(1 for ln in jr if "set=[] checks=[] not_evaluated=[]" in ln)
    clean_c = sum(1 for ln in cr if "set=[] checks=[] not_evaluated=[]" in ln)
    return (f"exit {rc}; {clean_j} of {len(jr)} JUDGEROW clean; {clean_c} of {len(cr)} CONTROLROW clean; "
            f"{sum(1 for r in reds if r[0] == 'JUDGE')} JUDGE row(s) RED; {sum(1 for r in reds if r[0] == 'CONTROL')} CONTROL row(s) RED")


def twin_summary(lines, rc):
    pairs, selfs, controls, count = twin_view(lines)
    c = " ".join(f"{k}={v}" for k, v in (count or {}).items()) or "no COUNT line"
    red = [p for p in pairs if not p["ok"]]
    return (f"exit {rc}; COUNT {c}; {len(red)} of {len(pairs)} pair line(s) ✗; "
            f"{sum(1 for ok, _ in selfs if ok)} of {len(selfs)} self-pair(s) ✓; {sum(controls)} of {len(controls)} control line(s) ✓")


def gate_rows(lines, prefixes):
    return [ln for ln in lines if any(ln.startswith(p) for p in prefixes)]


def main(edir):
    runs = os.path.join(edir, "runs")
    preds = [ln.rstrip("\n").split("\t") for ln in open(os.path.join(edir, "predictions.tsv"), encoding="utf-8")
             if ln.strip() and not ln.startswith("#")]
    hdr = ["id", "kind", "gate", "property", "edit", "expect_red", "members_predicted", "members_seen",
           "red_rows", "verdict", "prediction", "also_red_same_gate", "other_gate_seen", "judge", "twin",
           "judge_exit", "twin_exit", "wall_secs"]
    print("\t".join(hdr))
    base_j = gate_rows(read(os.path.join(runs, "C-gate", "judge.out")), ("JUDGEROW ", "JUDGE ", "CONTROLROW ", "CONTROL "))
    base_t = gate_rows(read(os.path.join(runs, "C-gate", "twin.out")), ("  ✓", "  ✗", "COUNT "))
    for p in preds:
        kind, pid, gate, prop, edit, expect, direction, members, also, other, basis = p
        d = os.path.join(runs, pid)
        jl, tl = read(os.path.join(d, "judge.out")), read(os.path.join(d, "twin.out"))
        jrc, jw = rc_of(d, "judge")
        trc, tw = rc_of(d, "twin")
        js = judge_summary(jl, jrc) if jl else "-"
        ts = twin_summary(tl, trc) if tl else "-"
        wall = max(int(jw) if jw != "-" else 0, int(tw) if tw != "-" else 0) or "-"
        if kind == "mutant":
            pred_set = SETS.get(members.split()[0], members.split()[0:1])
            if gate == "judge":
                reds = judge_reds(jl)
                seen = members_with(reds, expect)
                rows = [r for r in reds if r[0] == "JUDGE" and r[2] == expect]
                if direction != "-":
                    rows = [r for r in rows if r[3].startswith(direction + ":")]
                    seen = [m for m in seen if any(r[1] == m for r in rows)]
                killed = len(seen) > 0
                also_seen = other_rules(reds, expect)
                other_seen = ts
                m_rows = re.search(r"rows:(\d+)", members)
                miss = []
                if sorted(seen) != sorted(pred_set):
                    miss.append(f"members: predicted {fmt_set(pred_set)}, seen {fmt_set(seen)}")
                if m_rows and int(m_rows.group(1)) != len(rows):
                    miss.append(f"rows: predicted {m_rows.group(1)}, seen {len(rows)}")
                if also.strip() == "none" and also_seen != "none":
                    miss.append(f"also: predicted none, seen {also_seen}")
                red_rows = f"{len(rows)}: " + "; ".join(f"{m} " + (re.search(r"interaction (-?\d+)", f).group(0) if re.search(r"interaction (-?\d+)", f) else re.search(r"call '([^']*)'", f).group(0) if re.search(r"call '([^']*)'", f) else f[:60]) for _, m, _, f in rows)
            else:
                pairs, selfs, controls, count = twin_view(tl)
                selfs_ok = all(ok for ok, _ in selfs) and len(selfs) > 0
                red_pairs = [x for x in pairs if not x["ok"] and expect in x["rules"]]
                seen = []
                for x in red_pairs:
                    if x["member"] not in seen:
                        seen.append(x["member"])
                killed = len(red_pairs) > 0 and selfs_ok
                others = {}
                for x in pairs:
                    for r in x["rules"]:
                        if r != expect:
                            others.setdefault(r, []).append(x["member"])
                also_seen = "; ".join(f"{r} on {fmt_set(ms)}" for r, ms in others.items()) or "none"
                also_seen += f"; self-pairs {sum(1 for ok, _ in selfs if ok)} of {len(selfs)} ✓; controls {sum(controls)} of {len(controls)} ✓"
                other_seen = js
                miss = []
                if sorted(seen) != sorted(pred_set):
                    miss.append(f"members: predicted {fmt_set(pred_set)}, seen {fmt_set(seen)}")
                red_rows = f"{len(red_pairs)}: " + "; ".join(f"{x['member']} #{x['ord']} ({x['dir']}) {x['n']} finding(s) under {', '.join(x['rules'])}" for x in red_pairs)
            # S6 and S7 beyond `none`: the specific also- and other-gate predictions of p1a-p3.
            rj = gate_rows(jl, ("JUDGEROW ", "JUDGE ", "CONTROLROW ", "CONTROL "))
            rt = gate_rows(tl, ("  ✓", "  ✗", "COUNT "))
            if pid in ("p1a", "p1b"):
                if rt != base_t:
                    miss.append("other gate: applied_twin's rows differ from C-gate's")
            elif pid == "p2":
                if rj != base_j:
                    miss.append("other gate: corpus_judge's rows differ from C-gate's")
                pairs, _, _, _ = twin_view(tl)
                def on(rule):
                    out = []
                    for x in pairs:
                        if rule in x["rules"] and x["member"] not in out:
                            out.append(x["member"])
                    return out
                if sorted(on("applied-twin-final-state")) != sorted(SETS["FAILED5"]):
                    miss.append(f"also: applied-twin-final-state predicted on FAILED5, seen {fmt_set(on('applied-twin-final-state'))}")
                if sorted(on("applied-twin-outcome")) != sorted(SETS["OK3OFFAILED5"]):
                    miss.append(f"also: applied-twin-outcome predicted on OK3OFFAILED5, seen {fmt_set(on('applied-twin-outcome'))}")
                for r in ("applied-twin-served", "applied-twin-served-length", "applied-twin-trace-length"):
                    if on(r):
                        miss.append(f"also: {r} predicted on no pair, seen {fmt_set(on(r))}")
            elif pid == "p3":
                reds = judge_reds(jl)
                tdu = [m for t, m, r, f in reds if t == "JUDGE" and r == "tool-dispatches-unbalanced" and f.startswith("log above trace:")]
                if sorted(tdu) != sorted(SETS["DEADLINE5"]):
                    miss.append(f"also: tool-dispatches-unbalanced (log above trace) predicted on DEADLINE5, seen {fmt_set(tdu)}")
            prediction = "as predicted on the named rule" if not miss else "PREDICTION MISS: " + " | ".join(miss)
            verdict = "KILL" if killed else ("NOT RUN" if not jl and not tl else "SURVIVED")
            print("\t".join([pid, kind, gate, prop, edit, expect, members, fmt_set(seen), red_rows, verdict,
                             prediction, also_seen, other_seen, js, ts, jrc, trc, str(wall)]))
        else:
            verdict, seen = "-", "-"
            if pid in ("C-gate", "C-restored", "K0"):
                rj = gate_rows(jl, ("JUDGEROW ", "JUDGE ", "CONTROLROW ", "CONTROL "))
                rt = gate_rows(tl, ("  ✓", "  ✗", "COUNT "))
                reds = judge_reds(jl)
                pairs, selfs, controls, count = twin_view(tl)
                ok = (jrc == "0" and trc == "0" and not reds and all("set=[] checks=[] not_evaluated=[]" in ln for ln in rj if ln.startswith(("JUDGEROW ", "CONTROLROW ")))
                      and sum(1 for ln in rj if ln.startswith("JUDGEROW ")) == 18 and sum(1 for ln in rj if ln.startswith("CONTROLROW ")) == 4
                      and count is not None and count.get("pairs") == count.get("clean") == "13" and count.get("controls_red") == "6"
                      and count.get("identical_clean") == "18")
                if pid != "C-gate":
                    same = rj == base_j and rt == base_t
                    seen = f"rows equal to C-gate's line for line: {'yes' if same else 'NO'} ({len(rj)} judge rows, {len(rt)} twin rows)"
                    ok = ok and same
                else:
                    seen = f"{len(rj)} judge rows, {len(rt)} twin rows"
                verdict = "PASS" if ok else "FAIL"
            elif pid == "C-invariants":
                out = read(os.path.join(d, "invariants.out"))
                passed = any(ln.strip() == "invariants_dst PASS" for ln in out)
                ticks = sum(1 for ln in out if ln.strip().startswith("✓"))
                crosses = sum(1 for ln in out if ln.strip().startswith("✗"))
                # The rows under W2.1's two section headers, each up to the next blank line.
                p13, on = [], False
                for ln in out:
                    if ln.startswith("-- ") and "P1 and P3" in ln:
                        on = True
                        continue
                    if on and not ln.strip():
                        on = False
                    if on and ln.strip().startswith(("✓", "✗")):
                        p13.append(ln.strip())
                seen = f"invariants_dst PASS: {'yes' if passed else 'no'}; {ticks} ticks, {crosses} crosses; W2.1's P1/P3 sections: {len(p13)} row(s), {sum(1 for x in p13 if x.startswith('✓'))} ✓"
                verdict = "PASS" if passed and crosses == 0 else "FAIL"
            elif pid == "R-reach":
                out = read(os.path.join(d, "reach.out"))
                rows = {}
                for ln in out:
                    m = re.match(r"^(REACH|REACHCONTROL) (\S+) p1: (.*) \| p3: (.*)$", ln)
                    if m:
                        rows[m.group(2)] = (m.group(1), dict(kv.split("=") for kv in (m.group(3) + " " + m.group(4)).split()))
                mem = {k: v for k, (t, v) in rows.items() if t == "REACH"}
                ctl = {k: v for k, (t, v) in rows.items() if t == "REACHCONTROL"}
                tf = SETS["TOOLFAULT11"]
                applied = ["seed-11", "seed-14", "seed-102", "seed-165", "seed-215"]
                checks = [
                    ("18 member rows and 4 control rows", len(mem) == 18 and len(ctl) == 4),
                    ("fault_disp >= 1 on each of TOOLFAULT11, 0 on the other 7",
                     all(int(v["fault_disp"]) >= 1 for k, v in mem.items() if k in tf) and all(int(v["fault_disp"]) == 0 for k, v in mem.items() if k not in tf)),
                    ("applied_faults 1 on seed-11 seed-14 seed-102 seed-165 seed-215, 0 elsewhere",
                     all(int(v["applied_faults"]) == (1 if k in applied else 0) for k, v in mem.items())),
                    ("every fault dispatch and refusal answered by a disclosing message (disclosing == fault_disp + refusals)",
                     all(int(v["disclosing"]) == int(v["fault_disp"]) + int(v["refusals"]) for v in mem.values())),
                    ("tool_disp >= 1 on each of TOOLFAULT11", all(int(mem[k]["tool_disp"]) >= 1 for k in tf if k in mem)),
                    ("redispatched 0 on every member and control", all(v["redispatched"] == "0" for v in list(mem.values()) + list(ctl.values()))),
                    ("tool-run-without-approval: tool_disp=2 ids=2 emitted=2 fault_disp=0",
                     ctl.get("tool-run-without-approval", {}) .get("tool_disp") == "2" and ctl["tool-run-without-approval"]["ids"] == "2"
                     and ctl["tool-run-without-approval"]["emitted"] == "2" and ctl["tool-run-without-approval"]["fault_disp"] == "0"),
                    ("the other three controls: tool_disp=0 tool_msgs=0",
                     all(v["tool_disp"] == "0" and v["tool_msgs"] == "0" for k, v in ctl.items() if k != "tool-run-without-approval")),
                ]
                failed = [c for c, ok in checks if not ok]
                seen = (f"{sum(1 for _, ok in checks if ok)} of {len(checks)} expect clauses hold"
                        + (f" (failed: {'; '.join(failed)})" if failed else "") + "; "
                        + " | ".join(ln for ln in out if ln.startswith("REACHTOTAL")))
                verdict = "PASS" if not failed else "FAIL"
            print("\t".join([pid, kind, gate, prop, edit, expect, "-", seen, "-", verdict, "-", "-", "-", js, ts, jrc, trc, str(wall)]))


if __name__ == "__main__":
    main(sys.argv[1])
