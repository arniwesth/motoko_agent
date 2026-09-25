#!/usr/bin/env python3
"""Follow-up probes: symbol kinds/types, hover on usages, refs/def on usages."""
from __future__ import annotations
import json, time
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location("lsp_probe", "/tmp/claude-1001/-workspaces-motoko-agent/641bdaa9-87ab-4fdb-b9c9-45db3abb007e/scratchpad/lsp_probe.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
LSP, uri, open_doc, pos_of, REPO = m.LSP, m.uri, m.open_doc, m.pos_of, m.REPO

KINDS = {5:"Class",6:"Method",11:"Interface",12:"Function",22:"Struct",23:"Event",10:"Enum",26:"TypeParam"}

c = LSP(verbose=False)
root = REPO.as_uri()
c.request("initialize", {"processId": None, "rootUri": root,
    "workspaceFolders":[{"uri":root,"name":"motoko"}], "capabilities":{}})
c.notify("initialized", {})

docs = ["src/core/version.ail","src/core/backend.ail","src/core/compaction.ail",
        "src/core/agent_loop_v2.ail","src/core/test/stub_step.ail","src/core/types.ail"]
texts = {d: open_doc(c, d) for d in docs}
time.sleep(3.0)

def syms(rel):
    return c.request("textDocument/documentSymbol", {"textDocument":{"uri":uri(rel)}}).get("result") or []

print("### compaction.ail ALL symbol names + kinds ###")
for s in syms("src/core/compaction.ail"):
    print(f"  kind={s['kind']:>2} ({KINDS.get(s['kind'],'?'):9}) {s['name']}  children={len(s.get('children') or [])}")

print("\n### types.ail symbols (ADT module) ###")
for s in syms("src/core/types.ail")[:25]:
    print(f"  kind={s['kind']:>2} ({KINDS.get(s['kind'],'?'):9}) {s['name']}  children={len(s.get('children') or [])}")
    for ch in (s.get('children') or [])[:6]:
        print(f"       child kind={ch['kind']} {ch['name']}")

# count: how many funcs does source-parser see in compaction vs documentSymbol?
import re
ctext = texts["src/core/compaction.ail"]
src_funcs = re.findall(r'^(?:export\s+)?(?:pure\s+)?func\s+(\w+)', ctext, re.M)
print(f"\n### compaction: source-regex funcs={len(src_funcs)} vs documentSymbol funcs={sum(1 for s in syms('src/core/compaction.ail') if s['kind']==12)}")
ds_names = {s['name'] for s in syms('src/core/compaction.ail')}
print(f"  in-source-not-in-DS: {set(src_funcs)-ds_names}")
print(f"  in-DS-not-in-source: {ds_names-set(src_funcs)}")

def hover_at(rel, line, char):
    return c.request("textDocument/hover",{"textDocument":{"uri":uri(rel)},
        "position":{"line":line,"character":char}}).get("result")

# hover on a stdlib usage: println in version.ail line14 col2
print("\n### hover: println usage (version.ail) ###")
p = pos_of(texts["src/core/version.ail"], "println", 2)  # 2nd = usage
print(p, "->", json.dumps(hover_at("src/core/version.ail", p["line"], p["character"]))[:300] if p else None)

# hover on dispatch_step USAGE (call site) in agent_loop_v2
print("\n### hover: dispatch_step usage (agent_loop_v2 call site) ###")
p = pos_of(texts["src/core/agent_loop_v2.ail"], "dispatch_step", 2)
print(p, "->", json.dumps(hover_at("src/core/agent_loop_v2.ail", p["line"], p["character"]))[:400] if p else None)

# hover on a local internal func call within same module (compaction)
print("\n### hover: try_emergency_compaction_with_limit usage (compaction internal call) ###")
p = pos_of(texts["src/core/compaction.ail"], "try_emergency_compaction_with_limit", 2)
print(p, "->", json.dumps(hover_at("src/core/compaction.ail", p["line"], p["character"]))[:400] if p else None)

def refs_at(rel, line, char, incl=True):
    return c.request("textDocument/references",{"textDocument":{"uri":uri(rel)},
        "position":{"line":line,"character":char},"context":{"includeDeclaration":incl}}).get("result")
def def_at(rel, line, char):
    return c.request("textDocument/definition",{"textDocument":{"uri":uri(rel)},
        "position":{"line":line,"character":char}}).get("result")

# references positioned on a USAGE of dispatch_step (call site in agent_loop_v2)
print("\n### references: dispatch_step positioned on USAGE in agent_loop_v2 ###")
p = pos_of(texts["src/core/agent_loop_v2.ail"], "dispatch_step", 2)
r = refs_at("src/core/agent_loop_v2.ail", p["line"], p["character"])
print(f"  result={'null' if r is None else len(r)}", json.dumps(r)[:400] if r else "")

# definition positioned on a SAME-FILE internal call: in compaction, try_emergency_compaction calls *_with_limit
print("\n### definition: same-file internal call (try_emergency_compaction_with_limit usage in compaction) ###")
p = pos_of(texts["src/core/compaction.ail"], "try_emergency_compaction_with_limit", 2)
r = def_at("src/core/compaction.ail", p["line"], p["character"])
print(f"  pos={p} result={json.dumps(r)[:400] if r else r}")

# references on same-file: a function used multiple times in one file
print("\n### references: same-file func used 3x — usage_percent_with_limit in compaction ###")
p = pos_of(texts["src/core/compaction.ail"], "usage_percent_with_limit", 1)
r = refs_at("src/core/compaction.ail", p["line"], p["character"])
print(f"  decl-pos result={'null' if r is None else len(r)}")
p2 = pos_of(texts["src/core/compaction.ail"], "usage_percent_with_limit", 2)
r2 = refs_at("src/core/compaction.ail", p2["line"], p2["character"]) if p2 else None
print(f"  usage-pos result={'null' if r2 is None else (len(r2) if isinstance(r2,list) else r2)}")
if isinstance(r2, list):
    for x in r2[:8]:
        print(f"     {Path(x['uri']).name}:{x['range']['start']['line']+1}")

c.request("shutdown", None, timeout=5); c.notify("exit", {})
