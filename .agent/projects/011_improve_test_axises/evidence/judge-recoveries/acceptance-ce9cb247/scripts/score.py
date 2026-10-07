#!/usr/bin/env python3
"""Acceptance of ADR-003's rules (011 WI-4): the scorer.

    score.py [--tsv mutants.tsv]      score every row of predictions.tsv that has a run
    score.py --extra <file.tsv>       also score rows of another predictions-shaped file (the
                                      blind reviewer's), against the same runs/ folder

It reads ROWS, never exit status. A gate run is a kill only when its output holds
`JUDGE <member> <rule id> RED` for the rule the row names (predictions.tsv, S1 to S7). A timeout,
a run with no member row, and another rule red alone are each reported as that.

`score3.py` of the spike read a timed-out gate as green. Here a run that printed no closing
verdict line is INCOMPLETE whatever else it printed, a timeout is TIMEOUT, and neither is ever
"clean"; `score_selftest.py` holds both cases.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
E = os.path.dirname(HERE)

ALL16 = ("seed-1 seed-2 seed-4 seed-5 seed-7 seed-9 seed-10 seed-12 seed-15 seed-19 seed-30 "
         "seed-32 seed-62 seed-141 seed-244 constructed-empty-terminal").split()
GROUPS = {
    "ALL16": ALL16,
    "OK10": "seed-1 seed-2 seed-4 seed-9 seed-10 seed-12 seed-15 seed-62 seed-141 constructed-empty-terminal".split(),
    "PROVFAIL5": "seed-5 seed-7 seed-19 seed-30 seed-32".split(),
    "RETRY4": "seed-9 seed-19 seed-32 seed-141".split(),
    "DISPATCH10": "seed-1 seed-4 seed-10 seed-12 seed-15 seed-19 seed-32 seed-62 seed-141 seed-244".split(),
}
# The `also` column of predictions.tsv, in a form the scorer can check. Informational except for
# r07, whose `none` is part of the handoff's row ("and no other rule").
ALSO = {
    "r05": [("steps-not-contiguous", set(GROUPS["RETRY4"])), ("provider-calls-exceed-budget", {"seed-19"})],
    "r07": "none",
    "P3": "guard:every member's trace holds a prepared call",
}
# r09's direction is this acceptance's own reading (S2): a miss there is a prediction miss.
SOFT_DIRECTION = {"r09"}
DIRECTED_RULE = {"r09": "provider-calls-unbalanced"}

ROW = re.compile(r"^JUDGE (\S+) (\S+) (clean|RED|not-evaluated)(?: (.*))?$")
ORDER = {m: i for i, m in enumerate(ALL16)}


def order(members):
    return sorted(members, key=lambda m: ORDER.get(m, 99))


def names(members):
    """A member set as text: a group name when it is exactly one, else the labels."""
    s = set(members)
    if not s:
        return "none"
    for g, ms in GROUPS.items():
        if s == set(ms):
            return f"{g} ({len(s)})"
    return " ".join(order(s)) + f" ({len(s)})"


def expand(text):
    """predictions.tsv `members` -> (set or None, count or None)."""
    if text in GROUPS:
        return set(GROUPS[text]), None
    if text.startswith("count:"):
        return None, int(text[6:])
    return set(text.split()), None


def parse(text):
    """What a gate run printed, without any judgement of it."""
    members, red, rows = [], {}, 0
    closing = None
    guards = []
    for line in text.splitlines():
        if line.startswith("JUDGEROW "):
            members.append(line.split()[1])
        m = ROW.match(line)
        if m:
            rows += 1
            if m.group(3) == "RED":
                red.setdefault((m.group(1), m.group(2)), []).append(m.group(4) or "")
        if line.startswith("✓ corpus_judge:"):
            closing = "green"
        if line.startswith("✗ corpus_judge FAILED"):
            closing = "red"
        if line.startswith("  ✗ "):
            guards.append(line[4:].strip())
    return {"members": members, "red": red, "rows": rows, "closing": closing, "guards": guards}


def state_of(parsed, rc):
    """How far the run got. Never a verdict on a rule."""
    if rc == 124:
        return "TIMEOUT"
    if not parsed["members"]:
        return "NO-ROWS"
    if parsed["closing"] is None or len(parsed["members"]) < 16:
        return f"INCOMPLETE ({len(parsed['members'])} of 16 members judged, no closing verdict)" \
            if parsed["closing"] is None else f"INCOMPLETE ({len(parsed['members'])} of 16 members judged)"
    return "complete"


def red_on(parsed, rule, direction=None):
    """Members with `rule` RED; with a direction, (in that direction, in another only)."""
    hit, other = set(), set()
    for (member, r), details in parsed["red"].items():
        if r != rule:
            continue
        if direction is None or any(d.startswith(direction + ":") for d in details):
            hit.add(member)
        else:
            other.add(member)
    return hit, other


def other_red(parsed, named):
    out = {}
    for (member, r) in parsed["red"]:
        if r in named or r == "invariant-set":
            continue
        out.setdefault(r, set()).add(member)
    return out


def score(pred, text, rc):
    """One mutant row. Returns a dict of plain strings."""
    mid = pred["id"]
    parsed = parse(text)
    state = state_of(parsed, rc)
    rules = pred["expect_red"].split("+")
    direction = None if pred["direction"] == "-" else pred["direction"]
    want, want_n = expand(pred["members"])
    seen, misses, killed = {}, [], {}
    for rule in rules:
        d = direction if (len(rules) == 1 or DIRECTED_RULE.get(mid) == rule) else None
        if d and mid in SOFT_DIRECTION:
            hit_any, _ = red_on(parsed, rule)
            hit_dir, other = red_on(parsed, rule, d)
            killed[rule] = bool(hit_any)
            seen[rule] = hit_any
            if other:
                misses.append(f"{rule}: predicted '{d}', another direction on {names(other)}")
        elif d:
            hit, other = red_on(parsed, rule, d)
            killed[rule] = bool(hit)
            seen[rule] = hit
            if other:
                misses.append(f"{rule}: red in another direction than '{d}' on {names(other)}")
        else:
            hit, _ = red_on(parsed, rule)
            killed[rule] = bool(hit)
            seen[rule] = hit
        if killed[rule]:
            if want is not None and seen[rule] != want:
                misses.append(f"{rule}: predicted {names(want)}, seen {names(seen[rule])}")
            if want_n is not None and len(seen[rule]) != want_n:
                misses.append(f"{rule}: predicted {want_n} members, seen {len(seen[rule])}")
    others = other_red(parsed, set(rules))
    also = ALSO.get(mid)
    also_note = ""
    if also == "none":
        if others:
            misses.append("predicted no other rule red; also red: " + "; ".join(f"{r} on {names(ms)}" for r, ms in sorted(others.items())))
    elif isinstance(also, str) and also.startswith("guard:"):
        g = also[6:]
        also_note = "guard red as predicted" if any(g in x for x in parsed["guards"]) else "MISS: predicted guard not red"
        if "MISS" in also_note:
            misses.append(f"predicted the guard '{g}' red; it is not")
    elif also:
        for r, ms in also:
            got = others.get(r, set())
            if got != ms:
                misses.append(f"also-predicted {r} on {names(ms)}, seen {names(got)}")
    if all(killed.values()):
        verdict = "KILL"
    elif state == "TIMEOUT":
        verdict = "NOT A KILL: timeout"
    elif state == "NO-ROWS":
        verdict = "NOT A KILL: no member row (compile, type or start-up error)"
    elif any(killed.values()):
        verdict = "NOT A KILL: only " + ", ".join(r for r in rules if killed[r]) + " red of the rules named"
    elif others:
        verdict = "NOT A KILL: other rule(s) red alone"
    elif state != "complete":
        verdict = "NOT A KILL: run incomplete and the named rule not printed red"
    else:
        verdict = "NOT A KILL: SURVIVED, no rule red"
    if verdict == "KILL" and state != "complete":
        verdict = f"KILL (run {state})"
    return {
        "verdict": verdict,
        "seen": "; ".join(f"{r}: {names(seen[r])}" for r in rules) if len(rules) > 1 else names(seen[rules[0]]),
        "prediction": "as predicted" if (all(killed.values()) and not misses) else ("MISS: " + " | ".join(misses) if misses else "-"),
        "others": "; ".join(f"{r} on {names(ms)}" for r, ms in sorted(others.items())) or "none",
        "guards": " | ".join(g.split(":")[0][:90] for g in parsed["guards"]) or "none",
        "state": state,
        "also": also_note,
    }


def score_blind(row, text, rc):
    """One row of the blind reviewer's file, by blind/blind-scoring.tsv's rules B-S1 to B-S4."""
    parsed = parse(text)
    state = state_of(parsed, rc)
    rule = row["rule_named"]
    hit, _ = red_on(parsed, rule)
    others = other_red(parsed, {rule})
    any_red = bool(hit) or bool(others)
    if hit:
        verdict = "KILL" if state == "complete" else f"KILL (run {state})"
    elif state == "TIMEOUT":
        verdict = "NOT A KILL: timeout"
    elif state == "NO-ROWS":
        verdict = "NOT A KILL: no member row (compile, type or start-up error)"
    elif others:
        verdict = "NOT A KILL: other rule(s) red alone"
    elif state != "complete":
        verdict = "NOT A KILL: run incomplete and the named rule not printed red"
    else:
        verdict = "NOT A KILL: SURVIVED, no rule red"
    f = row["reviewer_predicts"]
    if f == "none":
        forecast = "reviewer forecast no rule red: " + ("right" if (state == "complete" and not any_red) else "WRONG")
    else:
        got, _ = red_on(parsed, f)
        forecast = f"reviewer forecast {f} red: " + ("right" if got else "WRONG")
    return {
        "verdict": verdict, "seen": names(hit), "prediction": forecast,
        "others": "; ".join(f"{r} on {names(ms)}" for r, ms in sorted(others.items())) or "none",
        "guards": " | ".join(g.split(":")[0][:90] for g in parsed["guards"]) or "none", "state": state,
    }


def read_blind(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        rows.append(dict(zip(["id", "file", "rule_broken", "rule_named", "reviewer_predicts", "members"], line.rstrip("\n").split("\t"))))
    return rows


def read_predictions(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        f = line.rstrip("\n").split("\t")
        rows.append(dict(zip(["kind", "id", "decision", "edit", "expect_red", "direction", "members", "also", "basis"], f)))
    return rows


def rc_of(d):
    p = os.path.join(d, "rc")
    if not os.path.exists(p):
        return None, {}
    kv = dict(x.split("=", 1) for x in open(p).read().split() if "=" in x)
    return int(kv.get("rc", "-1")), kv


def judge_lines(text):
    return [l for l in text.splitlines() if re.match(r"^(JUDGEROW|JUDGE|CONTROLROW|CONTROL) ", l)]


def control(pred):
    """A control row -> (verdict, what was seen)."""
    cid = pred["id"]
    d = os.path.join(E, "runs", cid)
    read = lambda p: open(p, encoding="utf-8", errors="replace").read() if os.path.exists(p) else None
    if cid == "C-gate":
        t = read(os.path.join(d, "gate.out")); rc, _ = rc_of(d)
        if t is None:
            return "NOT RUN", "-"
        p = parse(t)
        clean_rows = len(re.findall(r"^JUDGEROW \S+ n=\d+ ended=\S+ finish=\S+ set=\[\] checks=\[\] not_evaluated=\[\]$", t, re.M))
        ctl_rows = len(re.findall(r"^CONTROLROW \S+ n=\d+ ended=\S+ finish=\S+ set=\[\] checks=\[\] not_evaluated=\[\]$", t, re.M))
        ctl_red = len(re.findall(r"^CONTROL \S+ \S+ (RED|not-evaluated)", t, re.M))
        ok = rc == 0 and p["closing"] == "green" and clean_rows == 16 and not p["red"] and ctl_rows == 2 and ctl_red == 0 and not p["guards"]
        return ("PASS" if ok else "FAIL"), f"exit {rc}; {clean_rows} of 16 JUDGEROW clean; {len(p['red'])} JUDGE row(s) RED; {ctl_rows} CONTROLROW clean, {ctl_red} CONTROL row(s) not clean; {len(p['guards'])} report row(s) crossed"
    if cid == "K0":
        t = read(os.path.join(d, "gate.out")); b = read(os.path.join(E, "runs", "C-gate", "gate.out")); rc, _ = rc_of(d)
        if t is None or b is None:
            return "NOT RUN", "-"
        a, c = judge_lines(b), judge_lines(t)
        ok = rc == 0 and a == c and parse(t)["closing"] == "green" and len(a) > 0
        return ("PASS" if ok else "FAIL"), f"exit {rc}; {len(c)} JUDGEROW/JUDGE/CONTROLROW/CONTROL lines, {'equal to' if a == c else 'DIFFERENT from'} C-gate's {len(a)} line for line"
    if cid == "P2":
        t = read(os.path.join(E, "runs", "C-gate", "gate.out"))
        if t is None:
            return "NOT RUN", "-"
        ticks = len(re.findall(r"^  ✓ (retry with two steps left|no retry with one step left):", t, re.M))
        crosses = len(re.findall(r"^  ✗ (retry with two steps left|no retry with one step left):", t, re.M))
        clean = len(re.findall(r"^CONTROL (retry-with-two-steps-left|no-retry-with-one-step-left) \S+ clean", t, re.M))
        ok = ticks == 6 and crosses == 0 and clean == 14
        return ("PASS" if ok else "FAIL"), f"C-gate's two CONTROL runs: {clean} of 14 CONTROL rows clean, {ticks} of 6 report rows ticked"
    if cid in ("C-invariants", "C-stream-parity", "C-inline-tests"):
        t = read(os.path.join(d, "out.txt")); rc, _ = rc_of(d)
        if t is None:
            return "NOT RUN", "-"
        t = re.sub(r"\x1b\[[0-9;]*m", "", t)
        if cid == "C-inline-tests":
            m = re.search(r"^(\d+) tests: (\d+) passed, (\d+) failed, (\d+) skipped", t, re.M)
            if not m:
                return "FAIL", f"exit {rc}; no test summary line"
            ok = rc == 0 and int(m.group(2)) > 0 and m.group(3) == "0" and m.group(4) == "0"
            return ("PASS" if ok else "FAIL"), f"exit {rc}; {m.group(1)} tests: {m.group(2)} passed, {m.group(3)} failed, {m.group(4)} skipped"
        ticks = len(re.findall(r"^\s*✓ ", t, re.M))
        crosses = len(re.findall(r"^\s*✗ ", t, re.M))
        seen = f"exit {rc}; {ticks} ticks, {crosses} crosses"
        ok = rc == 0 and crosses == 0 and ticks > 0
        if cid == "C-stream-parity":
            a = re.search(r"^\s*\[scripted\] the whole invariant set over the real run: (.*)$", t, re.M)
            b = re.search(r"^\s*\[recording\] the whole invariant set over the real run: (.*)$", t, re.M)
            pins = len(re.findall(r"^\s*✓ (scripted|recording): the whole invariant set reports exactly its expected rules$", t, re.M))
            ok = ok and a is not None and b is not None and a.group(1).strip() == "1 finding(s) — clock-balance" \
                and b.group(1).strip() == "0 finding(s)" and pins == 2
            seen += f"; scripted run: {a.group(1).strip() if a else '?'}; recording run: {b.group(1).strip() if b else '?'}; {pins} of 2 'exactly its expected rules' rows ticked"
        return ("PASS" if ok else "FAIL"), seen
    if cid == "MX":
        t = read(os.path.join(E, "matrix", "compare.txt"))
        if t is None:
            return "NOT RUN", "-"
        ident = "VERDICT: IDENTICAL" in t
        live = read(os.path.join(E, "matrix", "live-suites.txt")) or ""
        live_ok = len(re.findall(r"^src/eval/journal/(?:witness|candidate_checks|admission)_live_test\.ail exit=0 baseline_exit=0$", live, re.M)) == 3
        return ("PASS" if ident and live_ok else "FAIL"), ("VERDICT: IDENTICAL" if ident else "VERDICT: DIFFERS") + f"; the three real-run suites exit 0: {'yes' if live_ok else 'NO'}"
    if cid in ("KB-D2", "KB-D3"):
        want = {"KB-D2": "A8:outcome-finish-disagrees@aggregate:invariants:outcome-agreement",
                "KB-D3": "A8:driver-step-repeated@aggregate:invariants:bounded-progress"}[cid]
        t = read(os.path.join(E, "known-bad", cid, "witness_live_test.log"))
        rcs = read(os.path.join(E, "known-bad", cid, "rc")) or ""
        if t is None:
            return "NOT RUN", "-"
        hits = [l for l in t.splitlines() if want in l]
        w_rc = re.search(r"witness_live_test rc=(\d+)", rcs)
        ok = bool(hits) and w_rc is not None and w_rc.group(1) != "0"
        return ("PASS" if ok else "FAIL"), f"witness_live_test exit {w_rc.group(1) if w_rc else '?'}; {len(hits)} line(s) with {want}"
    if cid == "P4":
        t = read(os.path.join(E, "hook-probe", "probe.out"))
        if t is None:
            return "NOT RUN", "-"
        m = re.search(r"^HOOKPROBE hook-calls-model .*prepared=(\d+) providers_logged=(\d+) .*healthy=(\w+)", t, re.M)
        if not m:
            return "FAIL", "no HOOKPROBE row"
        ok = int(m.group(2)) > int(m.group(1)) and m.group(3) == "true"
        return ("PASS" if ok else "FAIL"), f"prepared={m.group(1)}, provider interactions logged={m.group(2)}, healthy={m.group(3)}"
    return "UNKNOWN CONTROL", "-"


def main():
    args = sys.argv[1:]
    out = None
    extra = None
    if "--tsv" in args:
        out = args[args.index("--tsv") + 1]
    if "--extra" in args:
        extra = args[args.index("--extra") + 1]
    preds = read_predictions(extra if extra else os.path.join(E, "predictions.tsv"))
    head = ["id", "kind", "decision", "edit", "site", "expect_red", "direction", "members_predicted",
            "members_seen", "verdict", "prediction", "also_red", "report_rows_crossed", "run", "exit", "wall_secs"]
    lines = ["\t".join(head)]
    for p in preds:
        d = os.path.join(E, "runs", p["id"])
        if p["kind"] == "control":
            v, seen = control(p)
            rc, kv = rc_of(d)
            lines.append("\t".join([p["id"], "control", p["decision"], p["edit"], "-", p["expect_red"], "-", "-", seen, v,
                                    "-", "-", "-", "-", "-" if rc is None else str(rc), kv.get("wall_secs", "-")]))
            continue
        g = os.path.join(d, "gate.out")
        if not os.path.exists(g):
            lines.append("\t".join([p["id"], "mutant", p["decision"], p["edit"], "-", p["expect_red"], p["direction"], p["members"],
                                    "-", "NOT RUN", "-", "-", "-", "-", "-", "-"]))
            continue
        rc, kv = rc_of(d)
        r = score(p, open(g, encoding="utf-8", errors="replace").read(), rc)
        site = open(os.path.join(d, "apply.log")).read().strip().replace(p["id"] + " applied at ", "")
        lines.append("\t".join([p["id"], "mutant", p["decision"], p["edit"], site, p["expect_red"], p["direction"], p["members"],
                                r["seen"], r["verdict"], r["prediction"], r["others"], r["guards"], r["state"], str(rc), kv.get("wall_secs", "-")]))
    # The blind reviewer's rows, when its file was there: same runs/ folder, its own scoring file.
    bpath = os.path.join(E, "blind", "blind-scoring.tsv")
    if os.path.exists(bpath) and not extra:
        edits = {}
        for i, line in enumerate(open(os.path.join(E, "blind", "blind-mutants.tsv"), encoding="utf-8")):
            f = line.rstrip("\n").split("\t")
            if i > 0 and len(f) >= 9:
                edits[f[0]] = f[8]
        for b in read_blind(bpath):
            d = os.path.join(E, "runs", b["id"])
            g = os.path.join(d, "gate.out")
            decision = f"blind: the reviewer's rule {b['rule_broken']}"
            if not os.path.exists(g):
                lines.append("\t".join([b["id"], "blind mutant", decision, edits.get(b["id"], "-"), "-", b["rule_named"], "-", b["members"],
                                        "-", "NOT RUN", "-", "-", "-", "-", "-", "-"]))
                continue
            rc, kv = rc_of(d)
            r = score_blind(b, open(g, encoding="utf-8", errors="replace").read(), rc)
            site = open(os.path.join(d, "apply.log")).read().strip().replace(b["id"] + " applied at ", "")
            lines.append("\t".join([b["id"], "blind mutant", decision, edits.get(b["id"], "-"), site, b["rule_named"], "-", b["members"],
                                    r["seen"], r["verdict"], r["prediction"], r["others"], r["guards"], r["state"], str(rc), kv.get("wall_secs", "-")]))
    text = "\n".join(lines) + "\n"
    if out:
        open(out, "w", encoding="utf-8").write(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
