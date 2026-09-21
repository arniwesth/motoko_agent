#!/usr/bin/env python3
"""Rebuild TYPE-SWEEP-<label>.tsv from TYPE-SWEEP-<label>.log: per module, ok or
FAIL with the first REAL error line (a relaxed-mode `WARNING MOD010` is skipped;
it is a warning, not the failure). Usage: p11_sweep_tsv.py core|scripts|tools"""
import re, sys, pathlib
E = pathlib.Path(__file__).resolve().parent
lab = sys.argv[1]
log = (E / f"TYPE-SWEEP-{lab}.log").read_text(errors="replace").split("\n")
rows, block = [], []
ERR = re.compile(r"Error|PAT_|PAR_|LDR0|MOD0|TC0|EFF|parse error|type error")
for l in log:
    m = re.match(r"^p11: check (\S+) (ok|FAILED)", l)
    if not m:
        block.append(l); continue
    f, verdict = m.group(1), m.group(2)
    if verdict == "ok":
        rows.append((f, "ok", ""))
    else:
        cands = [b for b in block if ERR.search(b) and not b.startswith("WARNING")]
        first = (cands[0] if cands else (re.sub(r"^p11: check \S+ FAILED \(exit \d+\): ?", "", l))).strip()
        rows.append((f, "FAIL", first[:400].replace("\t", " ")))
    block = []
out = E / f"TYPE-SWEEP-{lab}.tsv"
out.write_text("file\tresult\tfirst_error\n" + "".join("\t".join(r) + "\n" for r in rows))
ok = sum(1 for r in rows if r[1] == "ok")
print(f"{lab}: {ok}/{len(rows)} ok -> {out.name}")
