#!/usr/bin/env python3
"""SPIKE ONLY — the part-3 scorer on planted inputs. Every case must come back as named."""
import os, sys, tempfile, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("score3", os.path.join(HERE, "score3.py"))
s3 = importlib.util.module_from_spec(spec); spec.loader.exec_module(s3)
G = s3.GATES
rows = [l for l in open(os.path.join(HERE, "out2", "baseline", "probe.out"), encoding="utf-8", errors="replace").read().splitlines() if l.startswith("FAMROW ")]
PROBE_OK = "FAMPROBE begin\n" + "\n".join(rows) + "\nFAMPROBE end\n"
PANIC = "something\npanic: division by zero [recovered]\n"

def mk(root, name, red=(), logs=None, probe_rc=0, probe_text=PROBE_OK, drop=(), check=0):
    d = os.path.join(root, name); os.makedirs(d)
    lines = [f"step\tcheck\trc={check}\tsecs=1"]
    if check == 0:
        for g in G:
            if g in drop: continue
            lines.append(f"step\t{g}\trc={2 if g in red else 0}\tsecs=1")
        if "bank_probe" not in drop: lines.append(f"step\tbank_probe\trc={probe_rc}\tsecs=1")
    open(os.path.join(d, "summary.tsv"), "w").write("\n".join(lines) + "\n")
    for g, t in (logs or {}).items(): open(os.path.join(d, g + ".log"), "w").write(t)
    open(os.path.join(d, "probe.out"), "w").write(probe_text)
    open(os.path.join(d, "rc"), "w").write(f"rc={probe_rc} secs=0 rows=16 end=1\n")

def run(p_kw, t_kw):
    with tempfile.TemporaryDirectory() as root:
        mk(root, "P1", **p_kw); mk(root, "T1", **t_kw); s3.OUT = root
        ok, why, base = s3.score2.parse_text(PROBE_OK) if hasattr(s3.score2, "parse_text") else (True, "", None)
        d = os.path.join(root, "B"); os.makedirs(d); open(os.path.join(d, "probe.out"), "w").write(PROBE_OK); open(os.path.join(d, "rc"), "w").write("rc=0 secs=0 rows=16 end=1\n")
        ok, why, base = s3.score2.parse(d); assert ok, why
        return s3.verdict(1, base)

FAM = rows[5].replace("A=[]", "A=[tool-pairing:tool-call-unpaired]")
PROBE_RED = "FAMPROBE begin\n" + "\n".join(rows[:5] + [FAM] + rows[6:]) + "\nFAMPROBE end\n"
cases = [
  ("reached and killed in the same gate", dict(red=["corpus_pr"], logs={"corpus_pr": PANIC}), dict(red=["corpus_pr"], logs={"corpus_pr": "FAIL: real\n"}),
     lambda r: r["verdict"] == "KILLED" and r["reached"] == ["corpus_pr"] and not r["reached_green"] and not r["unreached_kill"]),
  ("reached in two gates, killed in one", dict(red=["discovery", "stream_parity"], logs={"discovery": PANIC, "stream_parity": PANIC}), dict(red=["discovery"], logs={"discovery": "✗ x\n"}),
     lambda r: r["verdict"] == "KILLED" and r["reached_green"] == ["stream_parity"]),
  ("reached, every gate green", dict(red=["strict_replay"], logs={"strict_replay": PANIC}), dict(),
     lambda r: r["verdict"] == "SURVIVED" and r["reached"] == ["strict_replay"]),
  ("reached only on the bank probe", dict(probe_rc=2, probe_text=PANIC), dict(),
     lambda r: r["verdict"] == "SURVIVED" and r["bank"] is True),
  ("no gate reaches it", dict(), dict(),
     lambda r: r["verdict"] == "NOT REACHED" and r["bank"] is False),
  ("probe red without the panic is not reach", dict(red=["discovery"], logs={"discovery": "FAIL: unrelated\n"}), dict(),
     lambda r: r["verdict"] == "NOT REACHED" and r["odd"] == ["discovery"]),
  ("mutant red where the probe did not reach", dict(), dict(red=["world_state"], logs={"world_state": "✗ y\n"}),
     lambda r: r["verdict"] == "KILLED" and r["unreached_kill"] == ["world_state"]),
  ("corpus_pr red on its wall-clock ceiling only", dict(red=["corpus_pr"], logs={"corpus_pr": PANIC}), dict(red=["corpus_pr"], logs={"corpus_pr": "FAIL: the PR corpus target took 207000 ms against a declared ceiling of 180000 ms.\n"}),
     lambda r: r["verdict"] == "SURVIVED"),
  ("a gate step missing", dict(), dict(drop=["ledger_parity"]),
     lambda r: r["verdict"] == "INCOMPLETE"),
  ("the mutant does not type-check", dict(), dict(check=1),
     lambda r: r["verdict"] == "INCOMPLETE"),
  ("families go red on the bank", dict(probe_rc=2, probe_text=PANIC), dict(probe_text=PROBE_RED),
     lambda r: r["fam"][0] == "RED"),
]
bad = 0
for label, pk, tk, okf in cases:
    r = run(pk, tk); good = bool(okf(r))
    print(("ok  " if good else "BAD ") + f"{label}: {r['verdict']} reached={r['reached']} reds={r['reds']} bank={r['bank']} fam={r['fam'][0]}")
    bad += 0 if good else 1
print(f"selftest: {len(cases) - bad}/{len(cases)}"); sys.exit(1 if bad else 0)
