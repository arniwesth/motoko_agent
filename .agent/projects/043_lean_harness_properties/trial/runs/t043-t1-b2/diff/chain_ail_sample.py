#!/usr/bin/env python3
"""The runtime half of the exploratory chain differential (X-1, X-2), on a sample.

    python3 -I chain_ail_sample.py <alphabet.json> <chain_ts.out> <n> <seed> > chain_ail.out

`register_with_config` reads its environment, so each input is one `ailang run` of
../repro/register_ail.ail (the REAL register_with_config) under `env -i`, which is too slow
for all 226,981 triples. The runtime only sees what buildChildEnv forwarded, so this takes the
DISTINCT forwarded triples in chain_ts.out (the REAL host's output), samples n of them with a
seed (a third with HERDR_BIN_PATH dropped, the X-1 shape, plus every forwarded triple of the
witnesses), and prints, per sampled forwarded triple:

    <fe>,<fb>,<fp>|<true when register_with_config advertises any tool>
"""
import concurrent.futures
import json
import os
import random
import subprocess
import sys

alphabet = json.load(open(sys.argv[1], encoding="utf-8"))
chain_ts = sys.argv[2]
n = int(sys.argv[3])
seed = int(sys.argv[4])
here = os.path.dirname(os.path.abspath(__file__))
repro = os.path.join(os.path.dirname(here), "repro")

fwd = set()
with open(chain_ts, encoding="utf-8") as f:
    for line in f:
        fwd.add(line.rstrip("\n").split("|")[2])
fwd = sorted(fwd)

rnd = random.Random(seed)
no_bin = [t for t in fwd if t.split(",")[1] == "u"]
must = set()
idx = {v: str(i) for i, v in enumerate(alphabet)}
for e, b, p in [("1", None, "w1:p7"), ("1", "/usr/local/bin/herdr", "w1:p7"),
                ("2", "/usr/local/bin/herdr", "w1:p7"), ("1", "/usr/local/bin/herdr", None)]:
    t = ",".join(idx[x] if x is not None else "u" for x in (e, b, p))
    if t in fwd:
        must.add(t)
sample = set(must)
sample.update(rnd.sample(no_bin, min(len(no_bin), n // 3)))
while len(sample) < min(n, len(fwd)):
    sample.add(rnd.choice(fwd))


def run(t):
    env = {"PATH": os.environ["PATH"], "HOME": os.environ["HOME"], "HERDR_ORCHESTRATOR": "off",
           "MOTOKO_WORKDIR": os.environ.get("CHAIN_WORKDIR", "/nonexistent")}
    for name, i in zip(("HERDR_ENV", "HERDR_BIN_PATH", "HERDR_PANE_ID"), t.split(",")):
        if i != "u":
            env[name] = alphabet[int(i)]
    r = subprocess.run(
        ["ailang", "run", "--relax-modules", "--caps", "Clock,Env,FS,IO,Process", "--entry", "main",
         "register_ail.ail"], cwd=repro, env=env, capture_output=True, text=True, timeout=60)
    tools = [l[len("tools="):] for l in r.stdout.splitlines() if l.startswith("tools=")]
    if r.returncode != 0 or len(tools) != 1:
        return t, "ERROR"
    return t, "true" if tools[0] != "" else "false"


with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
    for t, res in sorted(ex.map(run, sorted(sample))):
        print(f"{t}|{res}")
