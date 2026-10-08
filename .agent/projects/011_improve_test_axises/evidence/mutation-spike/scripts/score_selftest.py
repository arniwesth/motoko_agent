#!/usr/bin/env python3
"""SPIKE ONLY — the scorer on planted inputs. Every case must come back as named, or exit 1."""
import os, sys, tempfile, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("score", os.path.join(HERE, "score.py"))
score = importlib.util.module_from_spec(spec); spec.loader.exec_module(score)
G = score.GATES

def mk(root, mid, rcs, logs=None, drop=None):
    d = os.path.join(root, mid); os.makedirs(d)
    lines = [f"step\tcheck\trc={rcs.get('check', 0)}\tsecs=1", "step\tcontract\trc=0\tsecs=1"]
    for g in G:
        if drop and g in drop: continue
        if rcs.get("check", 0) != 0: continue
        lines.append(f"step\t{g}\trc={rcs.get(g, 0)}\tsecs=1")
    open(os.path.join(d, "summary.tsv"), "w").write("\n".join(lines) + "\n")
    for g, t in (logs or {}).items():
        open(os.path.join(d, g + ".log"), "w").write(t)

M = {m["id"]: m for m in score.mutants.MUTANTS}
SIG_K1 = "      [discovery-env-read-under-recorded] this scenario's control flow reaches 1 read(s) of 'MOTOKO_RETRY_STREAM_ERROR' and the log records 0"
cases = [
  # (mutant id, rcs, logs, drop, expected verdict, expected match prefix)
  ("K0", {}, None, None, "SURVIVED_T", "as predicted"),
  ("K0", {"corpus_pr": 1}, None, None, "KILLED", "killed, predicted to survive"),
  ("K1", {"strict_replay": 2}, {"strict_replay": SIG_K1}, None, "KILLED", "as predicted"),
  ("K1", {"strict_replay": 2}, {"strict_replay": "something else failed"}, None, "KILLED", "predicted gate, different check"),
  ("K1", {"discovery": 2}, {"discovery": SIG_K1}, None, "KILLED", "killed by another gate"),
  ("K1", {}, None, None, "SURVIVED_T", "survived, predicted to be killed"),
  ("M2", {"corpus_pr": 1}, None, None, "KILLED", "predicted gate (no signature named)"),
  ("M3", {"check": 1}, None, None, "COMPILE_FAIL", "-"),
  ("M3", {"discovery": 124}, None, None, "TIMEOUT", "-"),
  ("M3", {"discovery": 124, "corpus_pr": 1}, None, None, "KILLED", "killed, predicted to survive"),
  ("M3", {}, None, ["ledger_parity"], "INCOMPLETE", "-"),
  # red only on the wall-clock ceiling: the machine was measured, not the mutant
  ("K0", {"corpus_pr": 2}, {"corpus_pr": "  ✓ everything else\nFAIL: the PR corpus target took 207000 ms against a declared ceiling of 180000 ms.\n"}, None, "TIMEOUT", "-"),
  # the ceiling AND a real failure: still a kill
  ("M5", {"corpus_pr": 2}, {"corpus_pr": "FAIL: the fixed bank reached the fault class and the wire carries NO\n      record of the recovery branch 'session.c2_loop/empty_stop_finalize' executing.\nFAIL: the PR corpus target took 207000 ms against a declared ceiling of 180000 ms.\n"}, None, "KILLED", "as predicted"),
  # a signature sitting in the WRONG gate's log must not count
  ("M10", {"corpus_pr": 1}, {"strict_replay": "NON-RETRYABLE", "corpus_pr": "FAIL: other"}, None, "KILLED", "predicted gate, different check"),
]
bad = 0
for i, (mid, rcs, logs, drop, ev, em) in enumerate(cases):
    with tempfile.TemporaryDirectory() as root:
        mk(root, mid, rcs, logs, drop); score.OUT = root
        r = score.row(M[mid])
        ok = r["verdict"] == ev and r["match"].startswith(em)
        print(("ok  " if ok else "BAD ") + f"case {i}: {mid} -> {r['verdict']} / {r['match']}" + ("" if ok else f"   expected {ev} / {em}"))
        bad += 0 if ok else 1
# a directory with no summary at all
with tempfile.TemporaryDirectory() as root:
    os.makedirs(os.path.join(root, "M1")); score.OUT = root
    r = score.row(M["M1"]); ok = r["verdict"] == "INCOMPLETE"
    print(("ok  " if ok else "BAD ") + f"case no-summary: {r['verdict']}"); bad += 0 if ok else 1
print(f"selftest: {len(cases) + 1 - bad}/{len(cases) + 1}")
sys.exit(1 if bad else 0)
