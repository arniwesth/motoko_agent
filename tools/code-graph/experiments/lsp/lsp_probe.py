#!/usr/bin/env python3
"""Minimal LSP client to probe `ailang lsp --stdio` for the code-graph investigation."""
from __future__ import annotations
import json, subprocess, threading, time, sys
from pathlib import Path

REPO = Path("/workspaces/motoko_agent")

class LSP:
    def __init__(self, verbose=False):
        cmd = ["ailang", "lsp", "--stdio"] + (["--verbose"] if verbose else [])
        self.p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, cwd=str(REPO))
        self._id = 0
        self._responses = {}
        self._notes = []
        self._lock = threading.Lock()
        self._stderr = []
        threading.Thread(target=self._read_loop, daemon=True).start()
        threading.Thread(target=self._read_stderr, daemon=True).start()

    def _read_stderr(self):
        for line in self.p.stderr:
            self._stderr.append(line.decode("utf-8", "replace").rstrip())

    def _read_loop(self):
        buf = b""
        f = self.p.stdout
        while True:
            # read headers
            header = b""
            while b"\r\n\r\n" not in header:
                ch = f.read(1)
                if not ch:
                    return
                header += ch
            length = 0
            for h in header.decode().split("\r\n"):
                if h.lower().startswith("content-length:"):
                    length = int(h.split(":")[1].strip())
            body = f.read(length)
            try:
                msg = json.loads(body)
            except Exception:
                continue
            with self._lock:
                if "id" in msg and ("result" in msg or "error" in msg):
                    self._responses[msg["id"]] = msg
                else:
                    self._notes.append(msg)

    def _send(self, obj):
        data = json.dumps(obj).encode()
        self.p.stdin.write(f"Content-Length: {len(data)}\r\n\r\n".encode() + data)
        self.p.stdin.flush()

    def request(self, method, params, timeout=15):
        self._id += 1
        rid = self._id
        self._send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
        start = time.time()
        while time.time() - start < timeout:
            with self._lock:
                if rid in self._responses:
                    return self._responses.pop(rid)
            time.sleep(0.01)
        return {"error": "timeout"}

    def notify(self, method, params):
        self._send({"jsonrpc": "2.0", "method": method, "params": params})

    def notes(self):
        with self._lock:
            return list(self._notes)

    def stderr(self):
        return list(self._stderr)


def uri(rel):
    return (REPO / rel).as_uri()

def open_doc(c, rel):
    text = (REPO / rel).read_text()
    c.notify("textDocument/didOpen", {"textDocument": {
        "uri": uri(rel), "languageId": "ailang", "version": 1, "text": text}})
    return text

def pos_of(text, needle, occurrence=1):
    """Return 0-indexed (line, char) of the nth occurrence of needle."""
    count = 0
    for i, line in enumerate(text.splitlines()):
        idx = 0
        while True:
            j = line.find(needle, idx)
            if j < 0:
                break
            count += 1
            if count == occurrence:
                return {"line": i, "character": j}
            idx = j + 1
    return None


def main():
    c = LSP(verbose=True)
    root = REPO.as_uri()
    init = c.request("initialize", {
        "processId": None,
        "rootUri": root,
        "workspaceFolders": [{"uri": root, "name": "motoko"}],
        "capabilities": {"textDocument": {
            "documentSymbol": {"hierarchicalDocumentSymbolSupport": True},
            "definition": {}, "references": {}, "hover": {}}},
    })
    print("### initialize.result.capabilities ###")
    print(json.dumps(init.get("result", init).get("capabilities", init), indent=2)[:2500])
    c.notify("initialized", {})

    docs = ["src/core/version.ail", "src/core/backend.ail",
            "src/core/compaction.ail", "src/core/agent_loop_v2.ail",
            "src/core/test/stub_step.ail"]
    texts = {d: open_doc(c, d) for d in docs}
    time.sleep(3.0)  # let diagnostics/typecheck settle

    print("\n### publishDiagnostics notifications ###")
    for n in c.notes():
        if n.get("method") == "textDocument/publishDiagnostics":
            p = n["params"]
            print(f"  {Path(p['uri']).name}: {len(p.get('diagnostics', []))} diagnostics")
            for d in p.get("diagnostics", [])[:3]:
                print(f"     - [{d.get('severity')}] {d.get('message','')[:160]}")

    def doc_symbols(rel):
        r = c.request("textDocument/documentSymbol", {"textDocument": {"uri": uri(rel)}})
        return r.get("result")

    print("\n### documentSymbol: version.ail ###")
    print(json.dumps(doc_symbols("src/core/version.ail"), indent=2)[:2000])

    syms = doc_symbols("src/core/compaction.ail")
    print("\n### documentSymbol: compaction.ail (count + first 3) ###")
    print(f"count={len(syms) if isinstance(syms,list) else 'n/a'}")
    print(json.dumps(syms[:3] if isinstance(syms,list) else syms, indent=2)[:2000])

    syms2 = doc_symbols("src/core/agent_loop_v2.ail")
    print("\n### documentSymbol: agent_loop_v2.ail (HARD module) ###")
    print(f"count={len(syms2) if isinstance(syms2,list) else 'n/a'}")
    print(json.dumps(syms2[:3] if isinstance(syms2,list) else syms2, indent=2)[:1500])

    # hover on print_version (exported) and a local binding
    def hover(rel, needle, occ=1):
        p = pos_of(texts[rel], needle, occ)
        if not p: return f"(no pos for {needle})"
        r = c.request("textDocument/hover", {"textDocument": {"uri": uri(rel)}, "position": p})
        return r.get("result")
    print("\n### hover: print_version (exported) ###")
    print(json.dumps(hover("src/core/version.ail", "print_version"), indent=2)[:800])
    print("\n### hover: httpGet (stdlib import) in backend.ail ###")
    print(json.dumps(hover("src/core/backend.ail", "httpGet", 2), indent=2)[:800])
    print("\n### hover: try_emergency_compaction (exported, compaction) ###")
    print(json.dumps(hover("src/core/compaction.ail", "try_emergency_compaction", 2), indent=2)[:800])

    # definition + references
    def definition(rel, needle, occ):
        p = pos_of(texts[rel], needle, occ)
        if not p: return f"(no pos for {needle})"
        r = c.request("textDocument/definition", {"textDocument": {"uri": uri(rel)}, "position": p})
        return r.get("result")
    def references(rel, needle, occ, incl=True):
        p = pos_of(texts[rel], needle, occ)
        if not p: return f"(no pos for {needle})"
        r = c.request("textDocument/references", {"textDocument": {"uri": uri(rel)},
            "position": p, "context": {"includeDeclaration": incl}})
        return r.get("result")

    print("\n### definition: dispatch_step call-site in agent_loop_v2 (line 1202) ###")
    print(json.dumps(definition("src/core/agent_loop_v2.ail", "dispatch_step", 2), indent=2)[:800])
    print("\n### definition: httpGet call-site in backend.ail ###")
    print(json.dumps(definition("src/core/backend.ail", "httpGet", 2), indent=2)[:800])

    print("\n### references: dispatch_step (def in stub_step) ###")
    refs = references("src/core/test/stub_step.ail", "dispatch_step", 1)
    print(f"count={len(refs) if isinstance(refs,list) else refs}")
    print(json.dumps(refs if not isinstance(refs,list) else [{ 'uri': Path(r['uri']).name, 'range': r['range']} for r in refs], indent=2)[:1200])

    print("\n### references: try_emergency_compaction (def in compaction) ###")
    refs2 = references("src/core/compaction.ail", "try_emergency_compaction", 2)
    print(f"count={len(refs2) if isinstance(refs2,list) else refs2}")
    print(json.dumps(refs2 if not isinstance(refs2,list) else [{'uri': Path(r['uri']).name, 'range': r['range']} for r in refs2], indent=2)[:1200])

    print("\n### references: Ok constructor (in compaction) ###")
    refsok = references("src/core/compaction.ail", "Ok(", 1)
    print(f"count={len(refsok) if isinstance(refsok,list) else refsok}")

    print("\n### STDERR (first 40 lines) ###")
    for l in c.stderr()[:40]:
        print("  " + l)

    c.request("shutdown", None, timeout=5)
    c.notify("exit", {})

if __name__ == "__main__":
    main()
