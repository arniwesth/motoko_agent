#!/usr/bin/env python3
from __future__ import annotations
import json, time, subprocess, tempfile, os
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location("lsp_probe", "/tmp/claude-1001/-workspaces-motoko-agent/641bdaa9-87ab-4fdb-b9c9-45db3abb007e/scratchpad/lsp_probe.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
LSP, uri, open_doc, pos_of, REPO = m.LSP, m.uri, m.open_doc, m.pos_of, m.REPO

c = LSP(verbose=False)
root = REPO.as_uri()
c.request("initialize", {"processId": None, "rootUri": root,
    "workspaceFolders":[{"uri":root,"name":"motoko"}], "capabilities":{}})
c.notify("initialized", {})
docs = ["src/core/version.ail","src/core/backend.ail","src/core/compaction.ail",
        "src/core/agent_loop_v2.ail","src/core/test/stub_step.ail"]
texts = {d: open_doc(c, d) for d in docs}
time.sleep(3.0)

def hov(rel,l,ch): return c.request("textDocument/hover",{"textDocument":{"uri":uri(rel)},"position":{"line":l,"character":ch}}).get("result")
def df(rel,l,ch): return c.request("textDocument/definition",{"textDocument":{"uri":uri(rel)},"position":{"line":l,"character":ch}}).get("result")
def rf(rel,l,ch,incl=True): return c.request("textDocument/references",{"textDocument":{"uri":uri(rel)},"position":{"line":l,"character":ch},"context":{"includeDeclaration":incl}}).get("result")

# 1. FULL hover text for dispatch_step usage (exported fn in hard module)
p = pos_of(texts["src/core/agent_loop_v2.ail"],"dispatch_step",2)
h = hov("src/core/agent_loop_v2.ail",p["line"],p["character"])
print("### FULL hover dispatch_step (agent_loop_v2, iface-unloadable module) ###")
print(h["contents"]["value"] if h else "null")
print("  ENDS WITH EFFECT ROW '! {':", "! {" in (h["contents"]["value"] if h else ""))

# 2. definition cross-module at the working usage position
print("\n### definition dispatch_step usage (line1201 char21), retried 3x ###")
for i in range(3):
    r = df("src/core/agent_loop_v2.ail",p["line"],p["character"])
    print(f"  try{i}: {[Path(x['uri']).name+':'+str(x['range']['start']['line']+1) for x in r] if isinstance(r,list) else r}")
    time.sleep(0.3)

# 3. close-world test: references for httpGet usage (only backend opened; std/net users not opened)
print("\n### references httpGet usage (backend) — close-world check ###")
p2 = pos_of(texts["src/core/backend.ail"],"httpGet",2)
r = rf("src/core/backend.ail",p2["line"],p2["character"])
print(f"  count={len(r) if isinstance(r,list) else r} files={set(Path(x['uri']).name for x in r) if isinstance(r,list) else None}")

# 4. references precision: does it match a constructor / same identifier broadly?
#    'Ok' appears as constructor many places — test identifier over-match
p3 = pos_of(texts["src/core/compaction.ail"],"Ok(",2)
if p3:
    r = rf("src/core/compaction.ail",p3["line"],p3["character"])
    print(f"\n### references on 'Ok' constructor usage: count={len(r) if isinstance(r,list) else r}")

# 5. references when target users live in an UNOPENED file.
#    Open ONLY compaction; ask refs for try_emergency_compaction usages. Its callers
#    (compact_step* are in same file). Then check a symbol used by an unopened module.
print("\n### references compact_step usage (who calls it; only 5 docs opened) ###")
p4 = pos_of(texts["src/core/compaction.ail"],"compact_step",4)  # a usage
if p4:
    r = rf("src/core/compaction.ail",p4["line"],p4["character"])
    print(f"  count={len(r) if isinstance(r,list) else r} files={set(Path(x['uri']).name for x in r) if isinstance(r,list) else None}")

# 6. diagnostics on a deliberately BROKEN module
print("\n### diagnostics on a broken module ###")
broken = REPO/"src/core/__lsp_probe_broken.ail"
broken.write_text("module src/core/__lsp_probe_broken\nexport func bad() -> int { let x = }\n")
try:
    c.notify("textDocument/didOpen",{"textDocument":{"uri":broken.as_uri(),"languageId":"ailang","version":1,"text":broken.read_text()}})
    time.sleep(2.5)
    found=[n for n in c.notes() if n.get("method")=="textDocument/publishDiagnostics" and "broken" in n["params"]["uri"]]
    if found:
        d=found[-1]["params"]["diagnostics"]
        print(f"  diagnostics={len(d)}")
        for x in d[:3]: print(f"   - sev={x.get('severity')} {x.get('message','')[:140]}")
    else:
        print("  no diagnostics notification for broken module")
finally:
    broken.unlink(missing_ok=True)

c.request("shutdown",None,timeout=5); c.notify("exit",{})

# 7. PERFORMANCE: init + open all core (non-test) modules + documentSymbol each
print("\n### PERFORMANCE: full core profile ###")
core = [p for p in (REPO/"src/core").rglob("*.ail")
        if "/test/" not in p.as_posix() and not p.name.endswith("_test.ail")]
print(f"  core modules: {len(core)}")
t0=time.time()
c2=LSP(verbose=False)
c2.request("initialize",{"processId":None,"rootUri":root,"workspaceFolders":[{"uri":root,"name":"m"}],"capabilities":{}})
c2.notify("initialized",{})
t_init=time.time()-t0
t0=time.time()
for p in core:
    rel=p.relative_to(REPO).as_posix()
    c2.notify("textDocument/didOpen",{"textDocument":{"uri":p.as_uri(),"languageId":"ailang","version":1,"text":p.read_text()}})
t_open=time.time()-t0
time.sleep(2.0)
t0=time.time(); total_syms=0; ok=0
for p in core:
    r=c2.request("textDocument/documentSymbol",{"textDocument":{"uri":p.as_uri()}},timeout=20).get("result")
    if isinstance(r,list): ok+=1; total_syms+=len(r)
t_sym=time.time()-t0
print(f"  init={t_init:.2f}s  didOpen(all,async)={t_open:.2f}s  documentSymbol(all)={t_sym:.2f}s")
print(f"  modules with symbols={ok}/{len(core)}  total top-level symbols={total_syms}")
c2.request("shutdown",None,timeout=5); c2.notify("exit",{})

# compare: current extractor source-parse + iface timing
print("\n### baseline: current extractor timings ###")
t0=time.time(); subprocess.run(["python3","-c","import sys;sys.path.insert(0,'tools/code-graph');from extractor import source_parser as sp;sp.parse_all()"],cwd=str(REPO),capture_output=True); print(f"  source_parser.parse_all (core default): {time.time()-t0:.2f}s")
t0=time.time(); subprocess.run(["ailang","iface","src/core/compaction"],cwd=str(REPO),capture_output=True); print(f"  ailang iface (1 module, compaction): {time.time()-t0:.2f}s")
