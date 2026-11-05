import os, sys, subprocess, shutil, importlib.util
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("seeds_spec", os.path.join(here, "seeds_spec.py"))
S = importlib.util.module_from_spec(spec); spec.loader.exec_module(S)
BASE = sys.argv[1]; OUT = sys.argv[2]   # base tree, planter dir
edits = {}  # id -> [(path, old, new)]
for sid, cls, tgt, path, old, new in S.SEEDS:
    edits.setdefault(sid, []).append((path, old, new))
for sid, lst in S.EXTRA.items():
    edits[sid].extend(lst)
def apply(text, old, new, sid):
    n = text.count(old)
    if n != 1: raise SystemExit(f"{sid}: old string occurs {n} times")
    return text.replace(old, new)
def udiff(path, a, b):
    import difflib
    return "".join(difflib.unified_diff(a.splitlines(True), b.splitlines(True), f"a/{path}", f"b/{path}", n=3))
os.makedirs(os.path.join(OUT, "seeds"), exist_ok=True)
combined = {}
for sid in sorted(edits):
    per = {}
    for path, old, new in edits[sid]:
        src = per.get(path) or open(os.path.join(BASE, path)).read()
        per[path] = apply(src, old, new, sid)
        comb = combined.get(path) or open(os.path.join(BASE, path)).read()
        combined[path] = apply(comb, old, new, sid)
    with open(os.path.join(OUT, "seeds", f"{sid}.patch"), "w") as f:
        for path in sorted(per):
            f.write(udiff(path, open(os.path.join(BASE, path)).read(), per[path]))
# Blinding hygiene, not a seed: refresh ailang.lock's content_hash for every package whose
# files the seeds change, so that ailang's lock warning reads as it does on the unseeded tree.
lockmap = os.path.join(here, "lock_hashes.json")
if len(sys.argv) > 3 and sys.argv[3] == "--with-lock" and os.path.exists(lockmap):
    import json
    lp = "ailang.lock"; txt = combined.get(lp) or open(os.path.join(BASE, lp)).read()
    for old, new in json.load(open(lockmap)).items():
        txt = apply(txt, f'"content_hash": "{old}"', f'"content_hash": "{new}"', "lock")
    combined[lp] = txt
with open(os.path.join(OUT, "seeds.patch"), "w") as f:
    for path in sorted(combined):
        f.write(udiff(path, open(os.path.join(BASE, path)).read(), combined[path]))
print("ok", len(edits), "seeds")
