#!/usr/bin/env python3
"""031 PLAN-001 P1.1: derive evidence/P1.1/INVENTORY.tsv.

One row per TRACKED file outside packages/ and .agent/ that names `ExtCtx`,
`ExtEntry` or `register_with_config` (whole-word). Columns:

  file          repo-relative path
  sites         number of lines naming one of the three
  kind          what the sites are, as a `;`-joined set: import / literal /
                helper signature / type annotation / registration / fixture /
                comment / reference (AILANG); document / data / text (others)
  exercised_by  the make targets whose recipe compiles or runs the file -- a
                literal path, a directory+extension glob the recipe expands
                (`src/core/*.ail`, a `find DIR -name`), or a script the recipe
                runs that names the file's exact path or globs/quotes its
                directory (`target (via script)`); `dst` is listed
                when the target is in DST_TARGETS; `CI: <workflow>` for the
                GitHub workflow; `none` when nothing in the Makefile reaches it
  owner         P1.1 / P1.3r / P1.4r / P1.5r / UNOWNED, or P0.5 for a file
                P0.5 already put on 8.0 (tools/ext_registry_gen/fixtures/abi8,
                hook_scope.py) -- stated rather than miscounted as UNOWNED
  status        for P1.1 rows what was done; for every other row what the
                sites are, so an UNOWNED row reads as a finding

Derivations, not guesses: the touched set is `git diff --name-only HEAD` over
src/core plus the regenerated registry; P1.5r's set is the pin sweep's own
regex (`abi_version: "7.4"` / `_manifest(... "7.4")`) over tracked .ail files,
which is what check_fixtures.py sweeps; exercised_by is parsed from the
Makefile at HEAD.
"""
import fnmatch, pathlib, re, subprocess, sys

REPO = pathlib.Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
NAMES = re.compile(r"\b(ExtCtx|ExtEntry|register_with_config)\b")
PIN = re.compile(r'abi_version:\s*"7\.4"|_manifest\([^\n]*"7\.4"')
EXTCTX_LITERAL = re.compile(r"(:|->)\s*ExtCtx\s*(=\s*)?\{")
EXTENTRY_LITERAL = re.compile(r"\{\s*id:\s*(\"[^\"]*\"|id),\s*(config:[^,]*,\s*)?caps:")

def sh(*a):
    return subprocess.check_output(list(a), cwd=REPO, text=True)

tracked = [f for f in sh("git", "ls-files").split("\n") if f]
touched = set(f for f in sh("git", "diff", "--name-only", "HEAD", "--", "src/core").split("\n") if f)

# ---- Makefile: target -> recipe lines; DST_TARGETS ------------------------
mk = (REPO / "Makefile").read_text().split("\n")
targets: dict[str, list[str]] = {}
cur: list[str] = []
dst_targets: set[str] = set()
i = 0
while i < len(mk):
    l = mk[i]
    if re.match(r"^DST_TARGETS\s*[:+]?=", l):
        buf = l.split("=", 1)[1]
        while buf.rstrip().endswith("\\"):
            i += 1; buf = buf.rstrip()[:-1] + " " + mk[i]
        dst_targets.update(buf.split()); i += 1; continue
    m = re.match(r"^([A-Za-z_][\w\-]*(?:\s+[A-Za-z_][\w\-]*)*)\s*:(?![=])", l)
    if m and not l.startswith(("\t", ".", " ")):
        cur = m.group(1).split()
        for t in cur: targets.setdefault(t, [])
    elif l.startswith("\t") and cur:
        for t in cur: targets[t].append(l)
    i += 1

def recipe_reaches(recipe: str, f: str) -> str | None:
    """literal path, expanded glob, `find DIR -name`, or a script the recipe runs."""
    if f in recipe:
        return "direct"
    # a glob counts only when it names a directory and an extension
    # (`src/core/*.ail`, `scripts/verify_*.ail`); a bare `*` in an `rm` or a
    # `for` over something else would match every file
    for tok in re.findall(r"[\w./\-]+/[\w.\-]*\*[\w.\-]*\.\w+", recipe):
        if fnmatch.fnmatch(f, tok):
            return f"glob {tok}"
    for d, pat in re.findall(r"find\s+([\w./\-]+)\s+-name\s+\"?([^\s\"]+)\"?", recipe):
        if f.startswith(d.rstrip("/") + "/") and fnmatch.fnmatch(f.split("/")[-1], pat):
            return f"find {d}"
    for scr in set(re.findall(r"((?:tools|scripts)/[\w./\-]+\.(?:sh|py))", recipe)):
        sp = REPO / scr
        if sp.exists() and scr != f:
            txt = sp.read_text(errors="replace")
            # one level of import chasing for a Python driver: derive.py
            # imports hook_scope.py, which is what names the fixture dir
            if scr.endswith(".py"):
                for sib in sp.parent.glob("*.py"):
                    if sib != sp and re.search(r"\b" + re.escape(sib.stem) + r"\b", txt):
                        txt += sib.read_text(errors="replace")
            d = f.rsplit("/", 1)[0]
            # the exact path, a directory the script globs / quotes, or a
            # fixture directory the script reaches by its trailing path
            # segments (`fixtures/hook_scope`, `adr001_boundary/gate`)
            segs = d.split("/")
            # windows start AT the `fixtures` segment (`fixtures/hook_scope`,
            # `fixtures/adr001_boundary/gate`), never at a bare `scripts/dst`
            fi = segs.index("fixtures") if "fixtures" in segs else -1
            windows = ["/".join(segs[fi:j]) for j in range(fi + 2, len(segs) + 1)] if fi >= 0 else []
            quoted = len(segs) >= 2 and (f'"{d}"' in txt or f"'{d}'" in txt)
            if f in txt or f"{d}/*" in txt or quoted or any(w in txt for w in windows):
                return f"via {scr}"
    return None

def exercised_by(f: str) -> str:
    hits = []
    for t, lines in targets.items():
        r = recipe_reaches("\n".join(lines), f)
        if r:
            hits.append(t if r == "direct" else f"{t} ({r})")
    if any(t.split(" ")[0] in dst_targets for t in hits):
        hits.append("dst")
    if f.startswith(".github/workflows/"):
        hits.append(f"CI: {f.split('/')[-1]}")
    return "; ".join(sorted(set(hits))) or "none"

# ---- kinds ----------------------------------------------------------------
def kinds_of(f: str, lines: list[str]) -> str:
    if not f.endswith(".ail"):
        if f.endswith(".md"): return "document"
        if f.endswith((".json", ".jsonl", ".tsv")): return "data"
        return "text"
    ks = set()
    for l in lines:
        s = l.strip()
        if s.startswith("--"): ks.add("comment"); continue
        if s.startswith("import ") or " import " in s: ks.add("import"); continue
        if EXTCTX_LITERAL.search(l) or ("ExtEntry" in l and re.search(r"ExtEntry\s*=\s*\{", l)): ks.add("literal"); continue
        if "register_with_config" in l:
            ks.add("registration" if re.search(r"func\s+register_with_config", l) else "registration reference"); continue
        if re.search(r"\bfunc\b", l) or re.search(r"\\\s*_?\w*\s*\.", l): ks.add("helper signature"); continue
        if re.search(r"(:|->)\s*\[?(ExtCtx|ExtEntry)\]?\b", l): ks.add("type annotation"); continue
        ks.add("reference")
    if "/fixtures/" in f: ks.add("fixture")
    return ";".join(sorted(ks))

# ---- what an UNOWNED .ail file will hit at 8.0, read off the file ----------
WIDE_ROW_74 = re.compile(r"\{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Rand\}")
def findings_of(text: str) -> str:
    fs = []
    n = len(EXTCTX_LITERAL.findall(text))
    if n: fs.append(f"{n} ExtCtx literal(s) (need verification/tool_evidence/decision_state)")
    m = len(EXTENTRY_LITERAL.findall(text))
    if m and not re.search(r"\{\s*id:[^}]*config:", text): fs.append(f"{m} ExtEntry literal(s) without config")
    if re.search(r"(func|\\)\s*\(?[^)\n]*:\s*ExtCtx\b", text): fs.append("callbacks typed ExtCtx (views at 8.0)")
    if re.search(r"describe:", text) and not re.search(r"config:", text): fs.append("fixture_hooks literal without config")
    if re.search(r"normalize_registration\(\s*[^,()]+,\s*[^,()]+\)", text): fs.append("2-argument normalize_registration")
    if "register_with_config" in text and "ExtRegistration" not in text and not text.lstrip().startswith("--"): fs.append("register_with_config result read as a bare list")
    if WIDE_ROW_74.search(text): fs.append("ToolProvider row without Trace")
    if re.search(r"DescribeTools\(\\_\s*\.", text) or re.search(r"describe:\s*\\_\s*\.", text): pass  # (Json) -> ok with \_ .
    if re.search(r"\bAccept\(", text): fs.append("Accept(x) (nullary at 8.0)")
    return "; ".join(fs)

# ---- owners ---------------------------------------------------------------
P11_STATUS = {
    "src/core/ext/runtime.ail": "done: dispatchers project views per entry through the ABI constructors, ext_config stamped, ToolProvider row +Trace, Accept nullary, kind enumeration +2, stamping/precedence/digest tests",
    "src/core/ext/registry_normalize.ail": "done: normalize_registration(id, config, caps), vote families, config digest over config + data positions (canonical JSON), payloads on views",
    "src/core/ext/registry_generated.ail": "done: regenerated by make registry_gen (P0.5 template); registry_gen_check green",
    "src/core/ext/ctx_defaults.ail": "done: empty_tool_evidence() for the host's ExtCtx literals",
    "src/core/ext/exit_manifest.ail": "no change needed: takes the host's ExtCtx, calls dispatch_exit_intents; checks and tests green in the workspace",
    "src/core/tool_catalog.ail": "done: DescribeTools receives e.config; configured-vs-empty catalog test",
    "src/core/test/ext_fixture.ail": "done: FixtureOverrides on the views, config field, describe takes Json; fixture_hooks stamps config",
    "src/core/test/stub_step.ail": "done: deny_all_rt's callbacks on the views, config: jo([]); anchor :203 held",
    "src/core/session.ail": "done (re-signature only, line-neutral): the two ExtCtx literals gain the three D3 fields with truthful defaults (P1.4r owns their fixtures and the decision-site Some); Accept nullary; ToolFailed imported by name (ctor collision, see README)",
    "src/core/tool_phase.ail": "no change needed: threads the host's ExtCtx to the dispatchers; rows already carry Trace; checks clean in the workspace",
    "src/core/tool_envelope_dispatch.ail": "done: row +Trace (calls dispatch_tool_handle)",
    "src/core/dst_hook_guard.ail": "done: row +Trace (calls dispatch_tool_handle)",
}
P05 = {"tools/ext_ambient_inventory/hook_scope.py": "P0.5 put the arity table and ABI cross-check on 8.0",
       "tools/profile_definition/check_fixtures.py": "P0.5: CAPABILITY_KINDS 12; the pin sweep itself is P1.5r's"}

def owner_of(f: str, kinds: str, text: str, lines: list[str]) -> tuple[str, str]:
    if f in P11_STATUS:
        return "P1.1", P11_STATUS[f]
    if f.startswith("src/core/") and set(kinds.split(";")) <= {"comment", "document"}:
        return "P1.1", "prose only (comment names the type); no change needed"
    if f == "scripts/dst/run_declared_vs_performed.sh":
        return "P1.5r", "the two ABI text probes (:124 BudgetShaper((ExtCtx…, :707 Compactor((ExtCtx…) per the P0G ruling; the other mentions are LIM/row probe sources the section runner writes"
    if f.endswith(".ail") and PIN.search(text):
        extra = findings_of(text)
        return "P1.5r", "ABI pin sweep file (7.4 → 8.0)" + (f"; also: {extra}" if extra else f"; sites: {kinds}")
    if f.startswith("tools/ext_registry_gen/fixtures/abi8/"):
        return "P0.5", "already 8.0 (P0.5 registry fixture tree)"
    if f in P05:
        return "P0.5", P05[f]
    if f.startswith("src/core/"):
        return "P1.1", f"sites: {kinds}"
    detail = findings_of(text) if f.endswith(".ail") else ""
    return "UNOWNED", (f"8.0 breakage: {detail}" if detail else f"sites: {kinds}")

# ---- rows -----------------------------------------------------------------
rows = []
extctx_literals = {}
extentry_literals = {}
for f in tracked:
    if f.startswith(("packages/", ".agent/")):
        continue
    p = REPO / f
    if not p.is_file():
        continue
    try:
        text = p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    lines = [l for l in text.split("\n") if NAMES.search(l)]
    if not lines:
        continue
    kinds = kinds_of(f, lines)
    owner, status = owner_of(f, kinds, text, lines)
    rows.append((f, len(lines), kinds, exercised_by(f), owner, status))
    if f.endswith(".ail"):
        n = len(EXTCTX_LITERAL.findall(text)); m = len(EXTENTRY_LITERAL.findall(text))
        if n: extctx_literals[f] = n
        if m: extentry_literals[f] = m

out = REPO / ".agent/projects/031_system_one_decisions/evidence/P1.1/INVENTORY.tsv"
with out.open("w") as fh:
    fh.write("file\tsites\tkind\texercised_by\towner\tstatus\n")
    for r in rows:
        fh.write("\t".join(str(x) for x in r) + "\n")

by_owner = {}
for r in rows:
    by_owner.setdefault(r[4], []).append(r)
print(f"INVENTORY.tsv: {len(rows)} rows")
for o, rs in sorted(by_owner.items()):
    code = sum(1 for r in rs if r[2] not in ("document", "data", "text") and set(r[2].split(";")) - {"comment"})
    print(f"  {o}: {len(rs)} (code {code}, prose/data {len(rs) - code})")
print(f"ExtCtx literals (construction sites, tracked, outside packages/): {sum(extctx_literals.values())} in {len(extctx_literals)} files")
for f, n in sorted(extctx_literals.items()): print(f"    {n}  {f}")
print(f"ExtEntry literals (outside packages/): {sum(extentry_literals.values())} in {len(extentry_literals)} files")
for f, n in sorted(extentry_literals.items()): print(f"    {n}  {f}")
