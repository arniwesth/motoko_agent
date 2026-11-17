#!/usr/bin/env python3
"""039 random-mutant pilot: the tier-1 scorer for `make corpus_judge`.

    score.py <id>...           one line per id from runs/corpus_judge/<id>/{out.txt,rc}
    score.py --text <file> <rc> score one output file (the self-test uses this)

It reads ROWS. A run is a KILL only when it is complete and holds a line
`JUDGE <member> <rule id> RED` naming a rule (the aggregate `invariant-set` row is not a rule:
the rule it summarises is printed on its own row). Everything else is recorded as what it is:

  TIMEOUT      the run hit its timeout (rc 124), whatever it printed before
  PANIC        a runtime failure: `panic:` (v0.47.2) or `Error: execution failed` (v0.60.4);
               reported with how many members were judged first
  COMPILE      the program did not start: an `Error:` line and no gate header
  INCOMPLETE   started, but fewer than MEMBERS (18) members judged or no closing verdict
  KILL         complete, and at least one JUDGE row RED on a named rule
  RED-NO-KILL  complete and red, with no JUDGE row RED: a CONTROL row, a guard, a
               not-evaluated rule or a self-check. Not a kill, by the brief's rule
  GREEN        complete, closing verdict green, nothing red

`also` lists every other red thing: CONTROL rows red, guard lines (`  ✗ `), JUDGE rows
not-evaluated. Exit status is reported and is never the verdict.
"""
import os
import re
import sys

E = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROW = re.compile(r"^(JUDGE|CONTROL) (\S+) (\S+) (clean|RED|not-evaluated)(?: (.*))?$")
HEADER = "011 ADR-003 D1"
MEMBERS = 18  # fixed_bank() holds 17 seeds, plus the constructed member; confirmed by the unmutated run's closing line


def score_text(text, rc):
    lines = text.splitlines()
    judgerows = [l.split()[1] for l in lines if l.startswith("JUDGEROW ")]
    closing = "green" if any(l.startswith("✓ corpus_judge:") for l in lines) else \
              "red" if any(l.startswith("✗ corpus_judge FAILED") for l in lines) else None
    kill, control_red, not_eval = {}, {}, []
    for l in lines:
        m = ROW.match(l)
        if not m:
            continue
        tag, who, rule, verdict = m.group(1), m.group(2), m.group(3), m.group(4)
        if verdict == "RED" and rule != "invariant-set":
            (kill if tag == "JUDGE" else control_red).setdefault(rule, []).append(who)
        elif verdict == "not-evaluated" and tag == "JUDGE":
            not_eval.append(f"{who}:{rule}")
    guards = [l.strip()[2:].strip() for l in lines if l.startswith("  ✗ ")]
    # AILANG v0.47.2 printed `panic: division by zero`; v0.60.4 prints
    # `Error: execution failed: RT001: integer division by zero at <file>:<line>:<col>`.
    panic = next((l.strip() for l in lines if "panic:" in l or "execution failed" in l), None)
    started = any(l.startswith(HEADER) for l in lines)
    error = next((l.strip() for l in lines if l.startswith("Error:")), None)

    if rc == 124:
        state = f"TIMEOUT ({len(judgerows)} of {MEMBERS} members judged before it)"
    elif panic:
        state = f"PANIC ({len(judgerows)} of {MEMBERS} members judged before it: {panic[:120]})"
    elif not started and error:
        state = f"COMPILE ({error[:120]})"
    elif len(judgerows) < MEMBERS or closing is None:
        state = f"INCOMPLETE ({len(judgerows)} of {MEMBERS} members judged, closing={closing}, rc={rc})"
    elif kill:
        state = "KILL"
    elif closing == "red" or rc != 0:
        state = "RED-NO-KILL"
    else:
        state = "GREEN"
    also = [f"CONTROL {r} RED on {','.join(w)}" for r, w in sorted(control_red.items())]
    also += [f"guard: {g}" for g in guards]
    if not_eval:
        also.append("not-evaluated: " + ",".join(not_eval))
    if state != "KILL" and kill:
        also.insert(0, "JUDGE rows RED but the run did not complete: "
                    + "; ".join(f"{r} on {','.join(w)}" for r, w in sorted(kill.items())))
    kills = "; ".join(f"{r} on {','.join(w)} ({len(w)})" for r, w in sorted(kill.items())) if state == "KILL" else "-"
    return {"state": state, "kills": kills, "also": " | ".join(also) or "-", "judgerows": len(judgerows),
            "closing": closing, "rc": rc}


def score_id(i, target="corpus_judge"):
    d = os.path.join(E, "runs", target, i)
    text = open(os.path.join(d, "out.txt"), encoding="utf-8").read()
    rcline = open(os.path.join(d, "rc"), encoding="utf-8").read()
    rc = int(re.search(r"rc=(\d+)", rcline).group(1))
    wall = re.search(r"wall_secs=(\d+)", rcline).group(1)
    r = score_text(text, rc)
    r["wall"] = wall
    return r


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--text"] and len(a) == 3:
        r = score_text(open(a[1], encoding="utf-8").read(), int(a[2]))
        print("\t".join([r["state"], r["kills"], r["also"]]))
    elif a:
        print("id\tstate\tkills (rule on members)\talso red\tjudgerows\tclosing\trc\twall_secs")
        for i in a:
            r = score_id(i)
            print("\t".join([i, r["state"], r["kills"], r["also"], str(r["judgerows"]), str(r["closing"]),
                             str(r["rc"]), r["wall"]]))
    else:
        sys.exit(__doc__)
