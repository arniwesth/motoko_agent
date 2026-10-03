#!/usr/bin/env python3
"""Check the structural claims of ADR-001 against the code graph.

    E=.agent/projects/037_skills_system/evidence
    python3 $E/g0_code_graph_private.py extract /tmp/adr037-graph   # build first
    python3 $E/g1_code_graph_grounding.py /tmp/adr037-graph

Each check is one SQL query through tools/code-graph/query/cgq.py, printed with
the ADR claim it bears on. Run from the repo root. Read-only: it queries the
CSVs in the given directory and writes nothing. With no argument it queries the
shared cache in tools/code-graph/.out/; see g0_code_graph_private.py for why a
private directory is used.

How to read the answers (tools/code-graph/AGENTS.md): imports are exact; calls
and reachable effects are source-parsed APPROXIMATIONS; a module whose typed
extraction failed gives "unknown", not "no". The script prints the graph's own
staleness and coverage first, and for every check the iface status of the
modules its rows come from.
"""
import json
import subprocess
import sys

import os

HERE = os.path.dirname(os.path.abspath(__file__))
CGQ = (["python3", os.path.join(HERE, "g0_code_graph_private.py"), "q", sys.argv[1]]
       if len(sys.argv) > 1 else ["python3", "tools/code-graph/query/cgq.py"])


def run(args):
    p = subprocess.run(CGQ + args, capture_output=True, text=True)
    out = p.stdout
    banner = out[: out.find("{")].strip() if "{" in out else out.strip()
    try:
        doc = json.loads(out[out.find("{"):])
    except Exception:
        return banner, {"data": [], "meta": {"error": (out + p.stderr)[-400:]}}
    return banner, doc


def sql(q):
    return run(["sql", " ".join(q.split())])


# (id, ADR section, claim, SQL)
CHECKS = [
    ("G1", "D4", "`ext_config_digest` has no caller outside its own module",
     "SELECT from_slug, resolution FROM invokes WHERE to_slug LIKE '%#ext_config_digest' ORDER BY 1"),
    ("G2", "D2", "`normalize_registration` is reached from the generated registry's `parse_tokens`",
     "SELECT from_slug, resolution FROM invokes WHERE to_slug LIKE '%#normalize_registration' ORDER BY 1"),
    ("G3", "D2", "the three `rejection_*` functions a sixth variant must extend, and who calls them",
     "SELECT to_slug, from_slug FROM invokes WHERE to_slug LIKE 'src/core/ext/registry_normalize#rejection_%' ORDER BY 1, 2"),
    ("G4", "D2", "modules that import `registry_normalize` directly (exact)",
     "SELECT from_module, symbols FROM imports WHERE to_module = 'src/core/ext/registry_normalize' ORDER BY 1"),
    ("G5", "D2", "the host's refusal site: `parse_tokens` prints and exits",
     "SELECT from_slug, std_module, symbol FROM std_calls WHERE from_slug LIKE 'src/core/ext/registry_generated#%' AND symbol IN ('exit', 'println') ORDER BY 1, 3"),
    ("G6", "D2", "no extension's registration module calls `exit` or `println`",
     "SELECT from_slug, symbol FROM std_calls WHERE symbol IN ('exit', 'println') AND from_slug LIKE '%/register#%' ORDER BY 1, 2"),
    ("G7", "§0", "declared effect row of every `register_with_config`",
     "SELECT module, declared_effects, module_iface_status FROM funcs WHERE name = 'register_with_config' ORDER BY module"),
    ("G8", "D7", "precedent: herdr's registration reaches a directory listing",
     "SELECT from_slug, to_slug FROM invokes WHERE from_slug LIKE '%herdr/register#%' AND (to_slug LIKE '%#orchestrator_mode' OR to_slug LIKE '%#read_run_docs') ORDER BY 1, 2"),
    ("G9", "D7", "which functions in extension packages list a directory",
     "SELECT from_slug, symbol FROM std_calls WHERE std_module = 'std/fs' AND symbol IN ('listDir', 'walk', 'glob') AND from_slug LIKE 'packages/%' ORDER BY 1, 2"),
    ("G10", "D7", "non-comment source lines that read `MOTOKO_WORKDIR`, by file",
     "SELECT path, count() AS n FROM source_lines WHERE position(line, 'MOTOKO_WORKDIR') > 0 AND position(line, 'JOURNAL') = 0 AND is_comment = 0 AND lang = 'ailang' GROUP BY path ORDER BY path"),
    ("G11", "D7", "who reads `MOTOKO_JOURNAL_WORKDIR`",
     "SELECT path, line_no FROM source_lines WHERE position(line, 'MOTOKO_JOURNAL_WORKDIR') > 0 AND is_comment = 0 AND lang = 'ailang' ORDER BY path, line_no"),
    ("G12", "D8", "the envelope: what builds the model-visible tool message",
     "SELECT from_slug, to_slug FROM invokes WHERE to_slug LIKE '%#handled_tool_message' OR to_slug LIKE '%#result_env_model_content' OR to_slug LIKE '%#result_to_model_json' OR to_slug LIKE '%#cap_tool_message_content' ORDER BY 2, 1"),
    ("G13", "D8", "`cap_oversized_tool_results` is on the structural compactor's path",
     "SELECT from_slug FROM invokes WHERE to_slug LIKE '%#cap_oversized_tool_results' ORDER BY 1"),
    ("G14", "D8", "the repetition guard's count, and who uses it",
     "SELECT from_slug FROM invokes WHERE to_slug LIKE '%#worst_repeat' ORDER BY 1"),
    ("G15", "D8", "`compaction_ai`'s bounded excerpt of one tool's result",
     "SELECT from_slug, to_slug FROM invokes WHERE to_slug LIKE '%#bounded_status_excerpt' OR to_slug LIKE '%#latest_runtime_status_result' ORDER BY 2, 1"),
    ("G16", "D9", "is `std/yaml` used anywhere in the tree (imports are exact)",
     "SELECT from_module, symbols FROM imports WHERE to_module = 'std/yaml' ORDER BY 1"),
    ("G17", "D10", "the live read adapter's std calls: `isFile`, then the panicking `readFile`",
     "SELECT from_slug, symbol FROM std_calls WHERE from_slug LIKE 'src/core/ports#ambient_file' ORDER BY 2"),
    ("G18", "D13", "the deterministic read adapter performs no std/fs call",
     "SELECT from_slug, std_module, symbol FROM std_calls WHERE from_slug LIKE 'src/core/ports#scripted_file' ORDER BY 3"),
    ("G19", "§5", "native tool results are JSON-encoded: who calls the encoder",
     "SELECT from_slug, to_slug FROM invokes WHERE to_slug LIKE '%#tool_result_item_to_json' OR to_slug LIKE '%#dispatch_one_typed' ORDER BY 2, 1"),
    ("G20", "D4", "the system prompt is built at two sites",
     "SELECT from_slug FROM invokes WHERE to_slug LIKE '%#dispatch_build_system_prompt' ORDER BY 1"),
    ("G21", "D4", "who computes the two resume digests",
     "SELECT to_slug, from_slug FROM invokes WHERE to_slug LIKE '%#ext_set_digest' OR to_slug LIKE '%#system_prefix_digest_for' ORDER BY 1, 2"),
    ("G22", "D12", "the catalogue's fallback when an extension declares no schema",
     "SELECT from_slug, to_slug FROM invokes WHERE from_slug LIKE 'src/core/tool_catalog#hook_schemas' OR to_slug LIKE '%#tools_with_extensions' ORDER BY 1, 2"),
    ("G23", "D1", "the CI boot check goes through the real registration path",
     "SELECT from_slug, to_slug FROM invokes WHERE from_slug LIKE '%verify_extension_boot#%' ORDER BY 1, 2"),
    ("G24", "D13", "extension source lines that call the `file_read` port, by file",
     "SELECT path, count() AS n FROM source_lines WHERE position(line, '.file_read(') > 0 AND is_comment = 0 AND path LIKE 'packages/%' GROUP BY path ORDER BY path"),
    ("G25", "D13", "`ailang_tools` in the four DST profile files (expected: none)",
     "SELECT path, count() AS n FROM source_lines WHERE position(line, 'ailang_tools') > 0 AND path LIKE 'src/core/dst_driver%' GROUP BY path ORDER BY path"),
    ("G26", "D13", "the four `omitted_extensions` / `not_installed` sites",
     "SELECT path, line_no, trim(line) AS line FROM source_lines WHERE path LIKE 'src/core/dst_driver%' AND is_comment = 0 AND (position(line, 'pure func not_installed') > 0 OR position(line, 'omitted_extensions: [') > 0) ORDER BY path, line_no"),
]


def modules_of(rows):
    mods = set()
    for r in rows:
        for v in r.values():
            if isinstance(v, str) and "#" in v:
                mods.add(v.split("#")[0])
    return mods


def main():
    banner, status = run(["status"])
    m = status.get("meta", {})
    print("GRAPH STATUS")
    if banner:
        print("  banner:", banner)
    print("  built_at:", m.get("built_at"), "| profile:", m.get("profile"))
    print("  ailang:", str(m.get("ailang_version", "")).split("\n")[0])
    print("  coverage:", m.get("coverage"), "| incomplete:", m.get("incomplete"),
          "| stale:", m.get("stale"), "| source_stale:", m.get("source_stale"))

    _, st = sql("SELECT module, iface_status FROM extraction_status")
    iface = {r["module"]: r["iface_status"] for r in st.get("data", [])}

    for cid, sec, claim, q in CHECKS:
        banner, doc = sql(q)
        rows = doc.get("data", [])
        meta = doc.get("meta", {})
        print(f"\n{cid} [{sec}] {claim}")
        if "error" in meta:
            print("  ERROR:", meta["error"])
            continue
        if banner:
            print("  banner:", banner.splitlines()[0][:120])
        if not rows:
            print("  (no rows)")
        for r in rows[:40]:
            print("  " + " | ".join(str(v).replace("\n", " ")[:110] for v in r.values()))
        if len(rows) > 40:
            print(f"  ... {len(rows) - 40} more")
        bad = sorted(mod for mod in modules_of(rows) if iface.get(mod, "ok") != "ok")
        flags = [k for k in ("stale", "source_stale", "incomplete") if meta.get(k)]
        note = []
        if flags:
            note.append("meta: " + ", ".join(flags))
        if bad:
            note.append("typed extraction not ok for: " + ", ".join(bad))
        if note:
            print("  !! " + "; ".join(note))


if __name__ == "__main__":
    sys.exit(main())
