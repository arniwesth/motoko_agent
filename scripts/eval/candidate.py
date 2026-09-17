#!/usr/bin/env python3
"""The runner's candidate mode: refusals, assembly, execution provenance, K0–K7.

ADR-004 v5 D3 ("Refused before running", K0, "Candidate checks", "The
verdict") and D5 ("The assembled tree", "Execution provenance"); PLAN-004 v2
§3 P1.9a (refusals, assembly, provenance, K0) and P1.9b (K1–K7 and the
verdict, wired here by P1R R1). Driven by
`scripts/eval/journal_replay.sh candidate`, or directly:

    candidate.py run  --repo R --entry DIR --parent P --candidate C
                      --record candidate.json --evaluator <rev|dir>
                      --peak-bytes N --peak-source TEXT [--run-id ID]
                      [--guard-lock PATH] [--keep-tree] [--fixture NAME]
    candidate.py pin  --repo R --at A --lock-root DIR --entry DIR
                      [--manifest M] [--out FILE]
    candidate.py matrix --repo R [--expected F] [--out F] [--logs DIR] [--no-live]

`run` exit codes: 0 Reproduced (the only verdict that permits a score);
1 Refused or Diverged; 2 usage or an evaluator failure (nothing is scored).

WHAT RUNS, IN ORDER (each step's first finding is the verdict; later steps do
not run after a refusal):

1. Refusals before running, on C's diff against P (`git diff --no-renames`,
   both sides of a move count), in the plan's order:
   - D3's path list (`D3_PATHS`, below) and the package rule (`ailang.lock`,
     `ailang.toml`, `packages/**`) → `InadmissibleCandidate(path:…)`;
   - the declared intent (`candidate.json`, supplied by the operator or the
     orchestrator, never written here: `intent` = "resource-only", a
     non-blank `reviewer`, `parent` and `candidate` naming P and C)
     → `InadmissibleCandidate(intent:…)`;
   - an evaluator path (`EVALUATOR_PATHS`) → `EvaluatorTouched`;
   - `tools/eval_protected check` at C (E's checker and manifest) →
     `ProtectedRegionTouched(<finding>:<symbol>)`; a checker hard error at C
     refuses too (the closure cannot be verified).
2. Assembly under `<entry>/runs/<run-id>/` (umask 077; the run directory must
   not exist): E's evaluator files materialised in `evaluator/`; the worktree
   `tree/` from C (`git worktree add --detach`), owned and removed by this
   runner; E's evaluator paths copied over it; each lock `path` package copied
   from A's pinned tree (never from C) to `packages/<name>`; the effective lock
   written into `tree/ailang.lock`, differing from A's lock only in those
   `path` fields (a JSON diff showing anything else refuses). Identity: the
   tree hash of the assembled files, E, the compatibility patch (none).
   Before the run: E's hash, the corpus hashes and the protected check at the
   assembled tree; again after it.
3. The run, under `scripts/eval/mem_guard.py` (its record decides
   `GuardTripped`): `ailang run -debug-compile -trace-loader … --entry main
   scripts/eval/journal_replay.ail` with `EVAL_MODE=candidate`, from the
   assembled root, `AILANG_CACHE_DIR=<run>/cache` fresh and empty (non-empty →
   refused before running), `AILANG_NO_CACHE` and `AILANG_STDLIB_PATH` unset.
   The runner loads the entry's program (`ProgramUndecodable(ReplayRefusal)`
   when it cannot), prints the build's identities for K0, reads the entry
   records (`witness.json`, `census.txt`: `EVAL_ENTRY_DIR`), runs the
   assembled build as C against `world_state_of(program)` and prints K1–K7's
   verdict (`KVERDICT`, `KALL`, `CANDIDATE`, the `ENVELOPE` lines; D3).
4. K0: every pinned identity equals what was assembled and observed, and the
   three execution-provenance records agree (below). Any disagreement or
   missing record → `PreflightMismatch(<class>:…)`. K0 is decided after the
   run because two of its records (the compiled set, the selections) are the
   run's own; a K0 finding discards the run's K verdict (recorded as
   `k_discarded`, never scored).
5. The verdict: the runner's K1–K7 verdict, taken only when K0 passed —
   `Reproduced` (exit 0, score permitted) or `Diverged(<Kn>:<finding>@
   <location>)` (exit 1, no score); `Refused(ProgramUndecodable)` from K1.
   A run that printed no K verdict (`CANDIDATE error`, or nothing) is an
   evaluator failure (exit 2), never a verdict.

EXECUTION PROVENANCE (D5; AILANG coordinates are the installed source
`/home/motoko/.local/share/ailang` at `ae36986`, whose rule files are pinned
by hash in `LOADER_SOURCES` — a moved source is a mismatch, since the
re-derivation below would be stale):

- compiled set, from the compiler: `[CACHE] <id>: MISS` lines and the one
  `[CACHE] Summary: h hits, m misses (k modules cached)` line
  (`pipeline_module.go:267,:282,:287,:408`); required: summary present, h = 0,
  no `SKIP`/`HIT` line, the MISS ids unique, m of them, k = m, and equal to the
  entries of `<cache>/compile/manifest.json` (`cache_store.go:61–105`); the log
  and the manifest are hashed. The modules directory (compiled artefacts,
  ~165 MB) is removed after hashing.
- selected paths, from this runner: every compiled id resolved by the
  loader's rules (`loader.go:132–240`): `pkg/` through the effective lock
  (`pkg/loader.go:44–136`, path packages relative to the project root);
  `std/` through `StdlibResolver`'s search order (`stdlib_resolver.go:215–271`:
  `<root>/std`, `<binary>/../std`, `AILANG_STDLIB_PATH`,
  `$XDG_DATA_HOME|~/.local/share` + `/ailang/std`, `/usr/local/share/ailang/std`,
  `/usr/share/ailang/std`), else the embedded copy (`loader.go:158–185`, covered
  by the binary hash); a bare id through the module-prefix map (the root's
  `module_prefix`, and each dependency's) then `<root>/<id>.ail`. Each
  selection must exist and lie (real path) under the assembled root (project),
  the effective package root `packages/<name>` (path packages; a registry
  package under its pinned directory) or the pinned stdlib root; its SHA-256
  must equal the assembled tree's (project) or the entry's pin (pkg, std).
  NOTE — `-trace-loader` is passed, but `ailang run` at `ae36986` discards it
  (`cmd/ailang/main_run_exec.go:141–143`, `_ = traceLoader`), so no search
  path is printed: the stdlib order is re-derived from the pinned source
  instead, the trace is recorded as absent, and if trace lines ever appear
  their first existing candidate must equal the re-derivation.
- import closure, from P1.4b's statement parser (`tools/eval_protected/
  ailspan.py`): the statement-level closure from the runner entry equals the
  compiled set minus what only the entry prelude injection reaches
  (`loader.go:292`, `prelude_imports.go:70–120`: `std/option`, `std/result`
  into every module exporting a nullary `main`, unless imported or shadowed),
  listed by name.
- RESIDUAL_GAP (printed in every envelope): a module's selected path is this
  runner's re-derivation of the loader's rules, cross-checked against the
  compiler's set, not the loader's own report.

THE MATRIX (`make eval_matrix`, PLAN-004 §0.8 and §3 "The D8 P1 matrix";
`matrix`, P1R R1). Runs every suite a `MATRIX.expected.tsv` row names, one at
a time — the pure modules (`ailang test --format json`), the live runners
(`*_live_test.ail`), `tools/eval_protected/selftest.py --observed-tsv`,
`gen_fixtures.py --check`, `test_candidate.py` (junit, `EVAL_MATRIX_OBS`),
and `test_mem_guard.py` as a gate — and writes `MATRIX.tsv` with the case
id, the test name and OBSERVED fields only (verdict, first finding,
position), `observed_by` and the commit; nothing is copied from the expected
file. Then it joins the two on `case_id`. Two observation tiers:

- `record`: the suite printed the verdict of the one row that names the
  test — selftest's observed TSV, `test_candidate.py`'s `observe` records,
  a live runner's `<test>: <Verdict>` line (`SourceFaithful(…)`,
  `Refused(AdmissionCheck(Ak):Name@pos)`, `Refused(Refusal(X)@pos)`,
  `Reproduced(…)`, `Diverged(Kn:Name[Family]@pos)`, a candidate refusal).
  First findings are rendered per the C1 ruling: finding-level `Ak:Name`,
  verdict-level `AdmissionCheck(Ak)` only on the verdict-mapping rows
  (`M10.verdict.*`, `P17a.*`). The join requires the three fields equal.
- `assertion`: a boolean test (the pure modules, most live checks) or a
  test several rows share. The row's triple is asserted inside the test;
  the only observation is its outcome, written as `pass`/`fail` with
  `(asserted)` fields, and the join credits the row only when it passed.

`inapplicable` rows (test `-`) are satisfied by their recorded reason. A
row whose test failed, was skipped (`--no-live` skips the live compiles, so
it cannot give a clean matrix), or was not found is not equal. Exit 0 only
when every row is equal, credited or inapplicable and every suite exited 0.

§0.6: synthetic entries only before P1G; the files written here hold digests,
counts, identities and paths, never corpus content.
"""

from __future__ import annotations

import argparse
import contextlib
import fnmatch
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import uuid
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# Pinned policy
# ---------------------------------------------------------------------------

INTENT = "resource-only"
RECORD_SCHEMA = "eval-candidate/1"
PINS_SCHEMA = "eval-execution-pins/1"
RUNNER_ENTRY = "scripts/eval/journal_replay.ail"
RUNNER_ID = "scripts/eval/journal_replay"
CAPS = "IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand"
PRELUDE = ("std/option", "std/result")
PRELUDE_SYMBOLS = {"std/option": ("Option", "Some", "None"), "std/result": ("Result", "Ok", "Err")}

# PLAN-004 §0.5's evaluator paths. `scripts/eval/` is taken whole (the runner,
# its shell driver, this module, the guard and their tests): a superset of the
# plan's file list, so it refuses more, never less.
EVALUATOR_PATHS = ("src/eval/journal/", "scripts/eval/", "tools/eval_protected/")

# ADR-004 v5 D3's path list, as concrete paths at A (65003110). The phrase is
# D3's; the mapping is this part's reading and is reviewed at P1R. The loop
# D5 leaves unfrozen on purpose (session.ail, phase_vocab.ail, journal.ail,
# context_usage.ail, step_machine.ail, tool_phase.ail) is not listed, nor are
# ports.ail and stub_step.ail (candidate files; their closure is the protected
# check's). `*` does not cross `/`; `**` does.
D3_PATHS = (
    ("src/core/prompts.ail", "prompt and system builders"),
    ("src/core/agents_md.ail", "prompt and system builders"),
    ("src/core/ext/**", "extensions and extension prompt builders"),
    ("src/core/ext_world.ail", "extensions"),
    ("src/core/hook_phase.ail", "extensions"),
    ("src/core/tool_catalog.ail", "the tool catalogue and schemas"),
    ("src/core/tool_contract.ail", "the tool catalogue and schemas"),
    ("src/core/backend.ail", "provider adapters and encoding"),
    ("src/core/ai_compat.ail", "provider adapters and encoding"),
    ("src/core/env_client.ail", "provider adapters and encoding"),
    ("src/core/config.ail", "model or parameter selection"),
    ("src/core/context_limit.ail", "model or parameter selection"),
    ("src/core/tool_runtime.ail", "tool implementations"),
    ("src/core/tool_dispatch_adapter.ail", "tool implementations"),
    ("src/core/tool_envelope_dispatch.ail", "tool implementations"),
    ("src/core/tool_stream_phase.ail", "streaming handlers"),
    ("src/core/dst_*.ail", "src/core/dst_*.ail"),
    ("src/core/test/**", "src/core/test/*.ail"),
    ("scripts/dst/strict_replay_dst.ail", "scripts/dst/strict_replay_dst.ail"),
)
LOCK_PATHS = (("ailang.lock", "ailang.lock"), ("ailang.toml", "ailang.toml"), ("packages/**", "packages/**"),
              ("**/ailang.lock", "ailang.lock"), ("**/ailang.toml", "ailang.toml"))

AILANG_SOURCE = "/home/motoko/.local/share/ailang"
AILANG_COMMIT = "ae36986c5c0a1e8ad4f0fc1e607efddefbbae46a"
LOADER_SOURCES = {
    "internal/loader/loader.go": "b1dd1250f35ddda5521fc4580479d5ab3c128dcdbaf4dbd2c6f81a3b7844448f",
    "internal/loader/stdlib_resolver.go": "0859f5cbcc976c725717e18ffe144115cf20896568b3100ec61302e0d923306f",
    "internal/loader/prelude_imports.go": "2af6c8d58c7ba1b466c476b347375af4cfbca3c4adea0eb47c665c7f6455fcfa",
    "internal/loader/loader_intra_pkg.go": "add429f369e773e8df15eea28125d06c6b0352bd9b90442c1fcdba604584318d",
    "internal/pkg/loader.go": "d240882f86fd72b3f62559508e477b04132b256751d4309326bad19d4462c695",
    "internal/pkg/manifest.go": "6649c288104633352fd2724a47e98d277f5ab5a439b08f2e9ac2b54e20653228",
    "internal/pkg/lockfile.go": "c79fb356821cc6e41f98c5b6798e0e886cf716655f45bca3e0e5c9620bb1ebbc",
    "internal/pkg/registry.go": "9fd71532717d3a856a4281439887b5cbac8cef18747e8643932ea83975899a9f",
    "internal/pipeline/pipeline_module.go": "acac8c116b0ab625633764f16ab0af863ba26982b1a5f04f0140b34dce51c437",
    "internal/pipeline/package_resolver.go": "a0f296c13fc342390ca0659cd67d6a38bc6520701857db9eea077f5e58f40405",
    "internal/pipeline/cache_store.go": "3fc55b2faa6f419cb41a30a3c3aaf73d8296736a0337d3aea93b41b8b60afaea",
    "cmd/ailang/main_run_exec.go": "3dff9e7f9fb71427f01e4ca9028245f731af2c0dffcf38a8ed9aea6bce20888d",
}

RESIDUAL_GAP = ("a module's selected path is the runner's re-derivation of the loader's rules "
                "(ailang ae36986), cross-checked against the compiler's module set, not the loader's own "
                "report; ailang run discards -trace-loader at ae36986, so the stdlib search order is "
                "re-derived from the pinned source; a loader flag printing id -> selected path would close "
                "this (AILANG feature request)")

K0_CLASSES = ("manifest", "profile", "toolchain", "binary", "corpus", "t0_settings", "program",
              "lock", "effective_lock", "packages", "compiled_set", "selection", "closure",
              "evaluator", "protected", "tree", "loader_rules", "warm_cache", "e_unpinned", "record")


class Refused(Exception):
    def __init__(self, reason, finding, detail=""):
        super().__init__(f"{reason}({finding}) {detail}")
        self.reason, self.finding, self.detail = reason, finding, detail

    def label(self):
        return f"{self.reason}:{self.finding}"


class EvalError(Exception):
    """The evaluator itself failed (usage, git, I/O): exit 2, nothing scored."""


def finding(cls, what, detail=""):
    assert cls in K0_CLASSES, cls
    return {"class": cls, "finding": f"{cls}:{what}", "detail": detail}


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def git(repo, *args, binary=False, check=True, env=None):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, env=env)
    if check and r.returncode != 0:
        raise EvalError(f"git {' '.join(args[:3])}: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout if binary else r.stdout.decode()


def rev_commit(repo, rev):
    r = subprocess.run(["git", "-C", repo, "rev-parse", "--verify", f"{rev}^{{commit}}"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise EvalError(f"not a commit in {repo}: {rev}")
    return r.stdout.strip()


def glob_match(path, pattern):
    if "**" in pattern:
        rx = "^" + re.escape(pattern).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*") + "$"
        return re.match(rx, path) is not None
    return fnmatch.fnmatchcase(path, pattern) and path.count("/") == pattern.count("/")


def files_digest(pairs):
    """sha256 over sorted `<path>\\0<sha256>\\n` rows: a content identity for a file set."""
    h = hashlib.sha256()
    for p, s in sorted(pairs.items()):
        h.update(p.encode() + b"\0" + s.encode() + b"\n")
    return h.hexdigest()


def walk_files(root, skip=()):
    """{relative path: sha256} of every regular file (and symlink target text) under root."""
    out = {}
    for d, dirs, files in os.walk(root):
        rel_d = os.path.relpath(d, root)
        dirs[:] = sorted(x for x in dirs if os.path.normpath(os.path.join(rel_d, x)) not in skip)
        for f in files:
            full = os.path.join(d, f)
            rel = os.path.normpath(os.path.join(rel_d, f))
            if rel in skip:
                continue
            if os.path.islink(full):
                out[rel] = "link:" + sha256_bytes(os.readlink(full).encode())
            elif os.path.isfile(full):
                out[rel] = sha256_file(full)
    return out


def git_tree_hash(root, skip=(".git",)):
    """git's tree object id of the files under root (blob/tree format re-implemented;
    nothing is written to an object store), as journal_replay.sh computes A's."""
    def blob(data):
        return hashlib.sha1(b"blob %d\0" % len(data) + data).digest()

    entries = {}
    for d, dirs, files in os.walk(root):
        rel_d = os.path.relpath(d, root)
        dirs[:] = [x for x in dirs if os.path.normpath(os.path.join(rel_d, x)) not in skip]
        for f in files:
            full = os.path.join(d, f)
            rel = os.path.normpath(os.path.join(rel_d, f))
            if rel in skip:
                continue
            if os.path.islink(full):
                entries[rel.encode()] = (b"120000", blob(os.readlink(full).encode()))
            elif os.path.isfile(full):
                with open(full, "rb") as fh:
                    data = fh.read()
                mode = b"100755" if os.stat(full).st_mode & 0o100 else b"100644"
                entries[rel.encode()] = (mode, blob(data))

    def tree(items):
        children, leaves = {}, {}
        for p, v in items.items():
            if b"/" in p:
                a, rest = p.split(b"/", 1)
                children.setdefault(a, {})[rest] = v
            else:
                leaves[p] = v
        rows = [(n, m, s) for n, (m, s) in leaves.items()]
        rows += [(n, b"40000", tree(sub)) for n, sub in children.items()]
        rows.sort(key=lambda r: r[0] + (b"/" if r[1] == b"40000" else b""))
        body = b"".join(m + b" " + n + b"\0" + s for n, m, s in rows)
        return hashlib.sha1(b"tree %d\0" % len(body) + body).digest()

    return tree(entries).hex()


def restrict_perms(root):
    """The corpus rule (PLAN-004 PRESERVE): directories 0700, files 0600 (0700 if executable)."""
    for d, dirs, files in os.walk(root):
        os.chmod(d, 0o700)
        for f in files:
            p = os.path.join(d, f)
            if os.path.islink(p):
                continue
            os.chmod(p, 0o700 if os.stat(p).st_mode & 0o111 else 0o600)


def extract_tar(data: bytes, dest: str, strip: str = ""):
    """Extract a `git archive` stream; `strip` removes a leading directory."""
    with tarfile.open(fileobj=io.BytesIO(data)) as t:
        for m in t.getmembers():
            name = m.name
            if strip:
                if name == strip.rstrip("/"):
                    continue
                if not name.startswith(strip):
                    continue
                name = name[len(strip):]
            if not name or m.name == "pax_global_header" or m.type == tarfile.XGLTYPE:
                continue
            target = os.path.join(dest, name)
            if not os.path.abspath(target).startswith(os.path.abspath(dest) + os.sep):
                raise EvalError(f"archive member escapes its destination: {m.name}")
            if m.isdir():
                os.makedirs(target, exist_ok=True)
            elif m.issym():
                os.makedirs(os.path.dirname(target), exist_ok=True)
                os.symlink(m.linkname, target)
            elif m.isfile():
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with t.extractfile(m) as src, open(target, "wb") as out:
                    shutil.copyfileobj(src, out)
                os.chmod(target, 0o700 if m.mode & 0o111 else 0o600)


# ---------------------------------------------------------------------------
# 1. Refusals before running
# ---------------------------------------------------------------------------

def changed_paths(repo, parent, candidate):
    out = git(repo, "diff", "--no-renames", "--name-only", "-z", parent, candidate)
    return sorted({p for p in out.split("\0") if p})


def evaluator_path(path):
    return any(path.startswith(p) for p in EVALUATOR_PATHS)


def path_refusals(paths):
    """D3's path list and the package rule, in path order. Evaluator paths are
    left to `EvaluatorTouched`."""
    out = []
    for p in paths:
        if evaluator_path(p):
            continue
        for pat, phrase in LOCK_PATHS + D3_PATHS:
            if glob_match(p, pat):
                out.append(Refused("InadmissibleCandidate", f"path:{p}", f"D3: {phrase}"))
                break
    return out


def load_record(path):
    try:
        with open(path, encoding="utf-8") as f:
            rec = json.load(f)
    except (OSError, ValueError) as e:
        raise Refused("InadmissibleCandidate", "intent:record_unreadable", str(e)) from None
    if not isinstance(rec, dict):
        raise Refused("InadmissibleCandidate", "intent:record_unreadable", "not an object")
    return rec


def intent_refusals(rec, parent, candidate):
    out = []
    if rec.get("schema") != RECORD_SCHEMA:
        out.append(Refused("InadmissibleCandidate", "intent:schema", f"{rec.get('schema')!r} != {RECORD_SCHEMA}"))
    if rec.get("intent") != INTENT:
        out.append(Refused("InadmissibleCandidate", f"intent:{rec.get('intent')}",
                           f"declared intent is not {INTENT!r}"))
    if not str(rec.get("reviewer", "")).strip():
        out.append(Refused("InadmissibleCandidate", "intent:unreviewed", "no reviewer accepted the intent"))
    if rec.get("parent") != parent:
        out.append(Refused("InadmissibleCandidate", "intent:parent", "the record names another parent"))
    if rec.get("candidate") != candidate:
        out.append(Refused("InadmissibleCandidate", "intent:candidate", "the record names another candidate"))
    return out


def evaluator_refusals(paths):
    return [Refused("EvaluatorTouched", p, "an evaluator path (PLAN-004 §0.5)") for p in paths if evaluator_path(p)]


def protected_check(checker, manifest, tree_spec, cwd):
    """Run E's checker. Returns (refusals, raw)."""
    r = subprocess.run([sys.executable, checker, "check", "--manifest", manifest, "--tree", tree_spec, "--json"],
                       capture_output=True, text=True, cwd=cwd)
    if r.returncode == 2:
        return [Refused("ProtectedRegionTouched", "checker_error", r.stderr.strip()[-300:])], None
    try:
        raw = json.loads(r.stdout)
    except ValueError:
        return [Refused("ProtectedRegionTouched", "checker_error", f"exit {r.returncode}, no JSON")], None
    out = [Refused("ProtectedRegionTouched", f"{f['finding']}:{f['symbol']}", f"{f['file']}: {f['detail']}")
           for f in raw["findings"]]
    if r.returncode == 1 and not out:
        out.append(Refused("ProtectedRegionTouched", "checker_error", "exit 1 without findings"))
    if r.returncode == 0 and out:
        out.append(Refused("ProtectedRegionTouched", "checker_error", "exit 0 with findings"))
    return out, raw


def refuse_before_running(repo, parent, candidate, record_path, checker, manifest):
    """The refusals in the plan's order. Returns (first refusal or None, every
    refusal of the step that refused, the steps run)."""
    paths = changed_paths(repo, parent, candidate)

    def intent():
        try:
            rec = load_record(record_path)
        except Refused as r:
            return [r]
        return intent_refusals(rec, parent, candidate)

    steps = []
    for name, fn in (("path", lambda: path_refusals(paths)),
                     ("intent", intent),
                     ("evaluator", lambda: evaluator_refusals(paths)),
                     ("protected", lambda: protected_check(checker, manifest, candidate, repo)[0])):
        rs = fn()
        steps.append(name)
        if rs:
            return rs[0], rs, steps
    return None, [], steps


# ---------------------------------------------------------------------------
# 2. Assembly
# ---------------------------------------------------------------------------

def evaluator_files(spec, repo):
    """E's evaluator files as {path: bytes}, and E's identity."""
    files = {}
    if os.path.isdir(spec):
        root = os.path.abspath(spec)
        listed = git(root, "ls-files", "-z", "-co", "--exclude-standard", "--", *EVALUATOR_PATHS)
        for p in sorted(x for x in listed.split("\0") if x):
            full = os.path.join(root, p)
            if "__pycache__" in p.split("/") or not os.path.isfile(full):
                continue
            with open(full, "rb") as f:
                files[p] = f.read()
        ident = {"kind": "dir-dev", "path": root, "head": rev_commit(root, "HEAD"),
                 "files_sha256": files_digest({p: sha256_bytes(b) for p, b in files.items()})}
        ident["id"] = f"{ident['head']}+dir:{ident['files_sha256'][:16]}-dev"
    else:
        commit = rev_commit(repo, spec)
        listed = git(repo, "ls-tree", "-r", "-z", "--name-only", commit, "--", *EVALUATOR_PATHS)
        for p in sorted(x for x in listed.split("\0") if x):
            files[p] = git(repo, "show", f"{commit}:{p}", binary=True)
        ident = {"kind": "commit", "commit": commit,
                 "files_sha256": files_digest({p: sha256_bytes(b) for p, b in files.items()})}
        ident["id"] = commit
    if not files:
        raise EvalError(f"E ({spec}) has no evaluator files")
    return files, ident


def write_files(root, files):
    for p, b in files.items():
        full = os.path.join(root, p)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as f:
            f.write(b)
        mode = 0o700 if p.endswith((".sh", ".py")) and b.startswith(b"#!") else 0o600
        os.chmod(full, mode)


def evaluator_hash_in(root):
    pairs = {}
    for prefix in EVALUATOR_PATHS:
        base = os.path.join(root, prefix)
        if os.path.isdir(base):
            for rel, s in walk_files(base).items():
                if "__pycache__" in rel.split("/"):
                    continue
                pairs[os.path.join(prefix, rel)] = s
    return files_digest(pairs)


def corpus_hashes(entry):
    return walk_files(entry, skip=("runs",))


def lock_path_rel(path, lock_root):
    """A lock `path` as a path inside A's tree, or None when it lies outside."""
    if not os.path.isabs(path):
        rel = os.path.normpath(path)
    else:
        root = os.path.normpath(lock_root)
        if not (path == root or path.startswith(root + os.sep)):
            return None
        rel = os.path.relpath(path, root)
    return None if rel.startswith("..") else rel


def json_diff(a, b, at=()):
    if type(a) is not type(b):
        return [at]
    if isinstance(a, dict):
        out = []
        for k in sorted(set(a) | set(b)):
            if k not in a or k not in b:
                out.append(at + (k,))
            else:
                out += json_diff(a[k], b[k], at + (k,))
        return out
    if isinstance(a, list):
        if len(a) != len(b):
            return [at]
        out = []
        for i, (x, y) in enumerate(zip(a, b)):
            out += json_diff(x, y, at + (i,))
        return out
    return [] if a == b else [at]


def lock_rewrite_findings(orig, eff):
    """The effective lock may differ from A's only in path packages' `path`."""
    allowed = {("packages", i, "path") for i, p in enumerate(orig.get("packages", []))
               if isinstance(p, dict) and p.get("source") == "path"}
    return [finding("effective_lock", "diff:" + "/".join(map(str, d)))
            for d in json_diff(orig, eff) if d not in allowed]


def effective_lock(orig, tree, pkg_root):
    eff = json.loads(json.dumps(orig))
    rewrites = []
    for p in eff.get("packages", []):
        if p.get("source") == "path":
            new = os.path.relpath(os.path.join(pkg_root, p["name"]), tree)
            rewrites.append({"name": p["name"], "from": p.get("path", ""), "to": new})
            p["path"] = new
    return eff, rewrites


def copy_path_packages(repo, a_commit, lock, lock_root, pkg_root):
    """Each `path` package from A's tree (never from C). Returns
    {name: {a_path, files}}; a package absent from A's tree is recorded and not
    copied (a module it would serve then fails selection)."""
    out = {}
    for p in lock.get("packages", []):
        if p.get("source") != "path":
            continue
        rel = lock_path_rel(p.get("path", ""), lock_root)
        present = rel is not None and git(repo, "ls-tree", "-d", a_commit, "--", rel).strip() != ""
        rec = {"a_path": rel if present else None, "files": {}}
        if present:
            dest = os.path.join(pkg_root, p["name"])
            os.makedirs(dest, exist_ok=True)
            extract_tar(git(repo, "archive", "--format=tar", a_commit, "--", rel, binary=True),
                        dest, strip=rel.rstrip("/") + "/")
            rec["files"] = walk_files(dest)
        out[p["name"]] = rec
    return out


# ---------------------------------------------------------------------------
# 3. The execution-provenance records
# ---------------------------------------------------------------------------

CACHE_LINE = re.compile(r"^\[CACHE\] (\S+): (MISS|SKIP|HIT but load failed)\b")
CACHE_SUMMARY = re.compile(r"^\[CACHE\] Summary: (\d+) hits, (\d+) misses \((\d+) modules cached\)\s*$")
TRACE_INIT = re.compile(r"^\[trace-loader\] Search paths initialized")
TRACE_EMBEDDED = re.compile(r"^\[trace-loader\] Filesystem stdlib not found, using embedded fallback: (\S+)")


def cache_dir_state(cache):
    """None when absent or empty; else the finding a warm cache is."""
    if not os.path.exists(cache):
        return None
    if not os.path.isdir(cache) or os.listdir(cache):
        return finding("warm_cache", "cache_not_empty", "the run's AILANG_CACHE_DIR is not empty at start")
    return None


def compiled_set(log_text, manifest_path):
    """The compiler's record. Returns (ids, findings, record)."""
    fs = []
    misses, others, summaries = [], [], []
    for line in log_text.splitlines():
        m = CACHE_SUMMARY.match(line)
        if m:
            summaries.append(tuple(int(x) for x in m.groups()))
            continue
        m = CACHE_LINE.match(line)
        if m:
            (misses if m.group(2) == "MISS" else others).append((m.group(1), m.group(2)))
    rec = {"miss_lines": len(misses), "other_lines": len(others), "summary": None,
           "manifest_sha256": None, "manifest_entries": None}
    if len(summaries) != 1:
        fs.append(finding("compiled_set", "summary_missing" if not summaries else "summary_repeated",
                          f"{len(summaries)} summary lines"))
    else:
        h, m, k = summaries[0]
        rec["summary"] = {"hits": h, "misses": m, "cached": k}
        if h != 0:
            fs.append(finding("compiled_set", "hits", f"{h} cache hits"))
        if m != len(misses):
            fs.append(finding("compiled_set", "miss_count", f"summary {m} != {len(misses)} MISS lines"))
        if k != m:
            fs.append(finding("compiled_set", "cached_count", f"{k} cached != {m} misses"))
    if others:
        fs.append(finding("compiled_set", "skip_or_hit", f"{others[0][0]}: {others[0][1]}"))
    ids = [i for i, _ in misses]
    if len(set(ids)) != len(ids):
        fs.append(finding("compiled_set", "miss_repeated", "a module id has two MISS lines"))
    try:
        with open(manifest_path, "rb") as f:
            raw = f.read()
        man = json.loads(raw)
        entries = set(man["entries"])
        rec["manifest_sha256"] = sha256_bytes(raw)
        rec["manifest_entries"] = len(entries)
    except (OSError, ValueError, KeyError, TypeError) as e:
        fs.append(finding("compiled_set", "manifest_unreadable", type(e).__name__))
        entries = None
    if entries is not None and entries != set(ids):
        extra = sorted(entries - set(ids))[:3]
        missing = sorted(set(ids) - entries)[:3]
        fs.append(finding("compiled_set", "manifest_differs", f"manifest-only {extra}, log-only {missing}"))
    return sorted(set(ids)), fs, rec


class LoaderContext:
    """The loader's resolution rules at ae36986, over one assembled root."""

    def __init__(self, root, lock, binary, env, pins, pkg_root):
        self.root = os.path.realpath(root)
        self.lock = lock
        self.pins = pins
        self.pkg_root = os.path.realpath(pkg_root)
        self.env = env
        self.manifests = {}
        root_toml = self._toml(self.root)
        self.root_name = (root_toml or {}).get("package", {}).get("name", "")
        # package_resolver.go:40–74: the root's prefix, then each dependency's.
        prefix = {}
        rp = (root_toml or {}).get("package", {}).get("module_prefix", "")
        if rp:
            prefix.setdefault(rp, []).append(self.root_name)
        for dep in sorted((root_toml or {}).get("dependencies", {})):
            d = self.package_dir(dep)
            m = self._toml(d) if d else None
            dp = (m or {}).get("package", {}).get("module_prefix", "") if m else ""
            if dp:
                prefix.setdefault(dp, []).append(dep)
        self.prefix = prefix
        # stdlib_resolver.go:215–271
        paths = [os.path.join(self.root, "std")]
        paths.append(os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(binary)), "..", "std")))
        for p in env.get("AILANG_STDLIB_PATH", "").split(":"):
            if p.strip():
                paths.append(p.strip())
        base = env.get("XDG_DATA_HOME") or (os.path.join(env["HOME"], ".local", "share") if env.get("HOME") else "")
        if base:
            paths.append(os.path.join(base, "ailang", "std"))
        paths += ["/usr/local/share/ailang/std", "/usr/share/ailang/std"]
        self.std_paths = paths

    @staticmethod
    def _toml(d):
        try:
            with open(os.path.join(d, "ailang.toml"), "rb") as f:
                return tomllib.load(f)
        except (OSError, tomllib.TOMLDecodeError):
            return None

    def locked(self, name):
        for p in self.lock.get("packages", []):
            if p.get("name") == name:
                return p
        return None

    def package_dir(self, name):
        p = self.locked(name)
        if p is None:
            return None
        if p.get("source") == "path":
            d = p.get("path", "")
            if not os.path.isabs(d):
                d = os.path.join(self.root, d)
            return d if os.path.exists(d) else None
        if p.get("source") == "registry":
            home = self.env.get("HOME", "")
            d = os.path.join(home, ".ailang", "cache", "registry", *name.split("/", 1), p.get("version", ""))
            if not os.path.exists(d) and p.get("path"):
                d = p["path"]
            return d if os.path.exists(d) else None
        return None

    def resolve_import(self, import_path):
        """pkg/loader.go ResolveImport. Returns (file, package name) or raises LookupError."""
        parts = import_path.split("/", 2)
        if len(parts) < 2:
            raise LookupError("invalid package import")
        name = parts[0] + "/" + parts[1]
        if self.locked(name) is None:
            if name != self.root_name:
                raise LookupError(f"package {name} not in the lock")
            pkg_dir = self.root
        else:
            pkg_dir = self.package_dir(name)
            if pkg_dir is None:
                raise LookupError(f"package directory of {name} not found")
        man = self.manifests.setdefault(name, self._toml(pkg_dir))
        if man is None:
            raise LookupError(f"no manifest for {name}")
        mprefix = man.get("package", {}).get("module_prefix", "")
        remapped = import_path
        if mprefix and import_path.startswith(man["package"]["name"] + "/"):
            remapped = mprefix + "/" + import_path[len(man["package"]["name"]) + 1:]
        exports = man.get("exports", {}).get("modules", [])
        if exports and import_path not in exports and remapped not in exports:
            raise LookupError(f"{import_path} not exported by {name}")
        mod = "core.ail" if len(parts) == 2 else parts[2] + ".ail"
        cands = [os.path.join(pkg_dir, "src", mod), os.path.join(pkg_dir, mod)]
        if mprefix and len(parts) == 3:
            cands += [os.path.join(pkg_dir, "src", remapped + ".ail"), os.path.join(pkg_dir, remapped + ".ail")]
        for c in cands:
            if os.path.exists(c):
                return c, name
        raise LookupError(f"{import_path} not found in {name}")

    def select(self, mod_id):
        """loader.go Load's route order. Returns {route, path, package}."""
        if mod_id.startswith("./") or mod_id.startswith("../"):
            return {"route": "relative", "path": os.path.join(self.root, mod_id) + ".ail", "package": None}
        if mod_id.startswith("pkg/"):
            try:
                path, name = self.resolve_import(mod_id[4:])
            except LookupError as e:
                return {"route": "pkg", "path": None, "package": None, "error": str(e)}
            return {"route": "pkg", "path": path, "package": name}
        if mod_id.startswith("std/"):
            name = mod_id[4:] + ".ail"
            for sp in self.std_paths:
                c = os.path.join(sp, name)
                if os.path.exists(c):
                    return {"route": "std", "path": c, "package": None, "search_root": sp}
            return {"route": "std-embedded", "path": None, "package": None}
        if mod_id.endswith(".ail"):
            return {"route": "absolute", "path": os.path.join(self.root, mod_id), "package": None}
        if self.root_name and (mod_id == self.root_name or mod_id.startswith(self.root_name + "/")):
            try:
                path, name = self.resolve_import(mod_id)
                return {"route": "self", "path": path, "package": name}
            except LookupError as e:
                return {"route": "self", "path": None, "package": None, "error": str(e)}
        first = mod_id.split("/", 1)[0]
        tried = []
        for pkg in self.prefix.get(first, []):
            try:
                path, name = self.resolve_import(pkg + mod_id[len(first):])
                tried.append((path, name))
            except LookupError:
                continue
        if len({os.path.realpath(p) for p, _ in tried}) > 1:
            # prefixMap iteration order is Go map order: two resolving
            # packages make the selection undefined.
            return {"route": "prefix", "path": None, "package": None,
                    "error": "ambiguous module prefix: " + ", ".join(n for _, n in tried)}
        if tried:
            path, name = tried[0]
            return {"route": "prefix", "path": path, "package": name}
        return {"route": "project", "path": os.path.join(self.root, mod_id + ".ail"), "package": None}


def under(path, root):
    rp, rr = os.path.realpath(path), os.path.realpath(root)
    return rp == rr or rp.startswith(rr + os.sep)


def selections(ids, ctx, assembled, trace_text=""):
    """The runner's record: every compiled id's selected file, checked and hashed.
    `assembled` is {tree-relative path: sha256} taken when the tree was assembled."""
    fs, rows = [], []
    pins = ctx.pins
    std_root = pins.get("stdlib", {}).get("root", "")
    std_files = pins.get("stdlib", {}).get("files", {})
    for mod_id in ids:
        s = ctx.select(mod_id)
        row = {"id": mod_id, "route": s["route"], "path": s.get("path"), "sha256": None, "root": None}
        rows.append(row)
        if s.get("error"):
            fs.append(finding("selection", f"unresolved:{mod_id}", s["error"]))
            continue
        if s["route"] == "std-embedded":
            row.update(path="<embedded>/std/" + mod_id[4:] + ".ail", root="embedded")
            if TRACE_INIT.search(trace_text) and f"embedded fallback: <embedded>/std/{mod_id[4:]}.ail" not in trace_text:
                fs.append(finding("selection", f"trace_disagrees:{mod_id}", "trace shows no embedded fallback"))
            continue
        path = s["path"]
        if not os.path.isfile(path):
            fs.append(finding("selection", f"missing:{mod_id}", "selected file does not exist"))
            continue
        digest = sha256_file(path)
        row["sha256"] = digest
        if s["route"] == "std":
            row["root"] = "stdlib"
            if not std_root or not under(path, std_root):
                fs.append(finding("selection", f"std_outside_root:{mod_id}",
                                  f"selected under {s.get('search_root')}, pinned root {std_root or '(none)'}"))
            elif std_files.get(os.path.relpath(os.path.realpath(path), os.path.realpath(std_root))) != digest:
                fs.append(finding("selection", f"std_hash:{mod_id}", "stdlib file differs from the entry's pin"))
            continue
        if s["package"] and s["package"] != ctx.root_name:
            name = s["package"]
            locked = ctx.locked(name) or {}
            row["root"] = f"package:{name}"
            if locked.get("source") == "path":
                pkg_dir = os.path.join(ctx.pkg_root, name)
                pinned = pins.get("path_packages", {}).get(name, {})
                if not under(path, pkg_dir):
                    fs.append(finding("selection", f"pkg_outside_pinned_root:{mod_id}",
                                      "selected outside the effective package root"))
                elif pinned.get("files", {}).get(os.path.relpath(os.path.realpath(path),
                                                                 os.path.realpath(pkg_dir))) != digest:
                    fs.append(finding("selection", f"pkg_hash:{mod_id}", "package file differs from A's pin"))
            else:
                pinned = pins.get("registry_packages", {}).get(name, {})
                pdir = pinned.get("dir", "")
                if not pdir or not under(path, pdir):
                    fs.append(finding("selection", f"pkg_outside_pinned_root:{mod_id}",
                                      "registry package outside its pinned directory"))
                elif pinned.get("files", {}).get(os.path.relpath(os.path.realpath(path),
                                                                 os.path.realpath(pdir))) != digest:
                    fs.append(finding("selection", f"pkg_hash:{mod_id}", "registry file differs from the pin"))
            continue
        row["root"] = "assembled"
        if not under(path, ctx.root):
            fs.append(finding("selection", f"module_outside_root:{mod_id}",
                              "a project module resolves outside the assembled root"))
            continue
        rel = os.path.relpath(path, ctx.root)
        if assembled.get(rel) != digest:
            fs.append(finding("selection", f"project_hash:{mod_id}", "differs from the file as assembled"))
    return rows, fs


def _is_entry_module(parsed):
    """prelude_imports.go:158: an exported `main` with no parameter or one unit parameter."""
    return re.search(rb"(?m)^export\s+(?:pure\s+)?func\s+main\s*\(\s*(?:\w+\s*:\s*\(\s*\)\s*)?\)",
                     parsed.lx.src) is not None


def _shadowed(parsed, mod):
    """prelude_imports.go:94: a local type or constructor named like the prelude's."""
    local = set()
    for d in parsed.decls:
        if d.kind.startswith("type"):
            local.add(d.symbol)
            local.update(d.names)
    return any(sym in local for sym in PRELUDE_SYMBOLS[mod])


def import_closure(ids_root, ctx, parse):
    """P1.4b's statement-level closure from the runner entry. Returns
    (statement closure, prelude-only set, per-module injections, findings)."""
    fs = []
    injected = {}

    def imports_of(mod_id):
        s = ctx.select(mod_id)
        if s.get("error") or s["route"] == "std-embedded" or not s.get("path") or not os.path.isfile(s["path"]):
            return None, None
        with open(s["path"], "rb") as f:
            src = f.read()
        try:
            p = parse(src, s["path"])
        except Exception as e:  # the checker's hard errors
            fs.append(finding("closure", f"unparsable:{mod_id}", str(e)[:200]))
            return [], []
        mods = []
        for st in p.stmts:
            m = st.module
            if m.startswith("./"):
                m = m[2:]
            mods.append(m)
        pre = []
        if _is_entry_module(p):
            for pm in PRELUDE:
                if pm not in mods and not _shadowed(p, pm):
                    pre.append(pm)
        return mods, pre

    def walk(starts, follow_prelude):
        seen, stack = set(), list(starts)
        while stack:
            mid = stack.pop()
            if mid in seen:
                continue
            seen.add(mid)
            mods, pre = imports_of(mid)
            if mods is None:
                if not mid.startswith("std/"):
                    fs.append(finding("closure", f"unreadable:{mid}", "no source to read imports from"))
                continue
            if pre:
                injected[mid] = pre
            stack.extend(mods)
            if follow_prelude:
                stack.extend(pre)
        return seen

    stmt = walk([ids_root], False)
    full = walk([ids_root], True)
    return stmt, full - stmt, injected, fs


def closure_findings(stmt, prelude_only, compiled):
    fs = []
    if set(compiled) - prelude_only != stmt:
        a = sorted(stmt - set(compiled))[:3]
        b = sorted(set(compiled) - prelude_only - stmt)[:3]
        fs.append(finding("closure", "differs", f"closure-only {a}, compiled-only {b}"))
    return fs


# ---------------------------------------------------------------------------
# 4. K0
# ---------------------------------------------------------------------------

BUILD_KEYS = ("profile_id", "profile_version", "event_vocabulary_version", "profile_rules_version",
              "coverage_rules_version", "attribution_rules_version", "fault_catalogue_version",
              "extension_packages")
PROFILE_KEYS = ("profile_id", "profile_version", "event_vocabulary_version")


def toolchain_now(binary):
    out = subprocess.run([binary, "--version"], capture_output=True, text=True).stdout
    ver = full = ""
    for line in out.splitlines():
        if line.startswith("AILANG "):
            ver = line
        if line.startswith("Full:"):
            full = line.split()[1]
    return {"toolchain": f"{ver} ({full})", "full": full,
            "sha256": "sha256:" + sha256_file(os.path.realpath(binary))}


def loader_rule_findings(source=AILANG_SOURCE):
    fs = []
    for rel, want in LOADER_SOURCES.items():
        p = os.path.join(source, rel)
        got = sha256_file(p) if os.path.isfile(p) else None
        if got != want:
            fs.append(finding("loader_rules", f"moved:{rel}", "the pinned loader source changed or is absent"))
    return fs


def parse_runner(out_text):
    """The runner's lines: K0BUILD, PROGRAM, CANDIDATE."""
    build = program = None
    verdicts = []
    for line in out_text.splitlines():
        if line.startswith("K0BUILD "):
            build = json.loads(line[len("K0BUILD "):])
        elif line.startswith("PROGRAM "):
            program = json.loads(line[len("PROGRAM "):])
        elif line.startswith("CANDIDATE "):
            verdicts.append(line)
    return build, program, verdicts


def parse_k(out_text):
    """The runner's K1–K7 lines: (verdict or None, every K finding, envelope lines).
    The verdict is {"word", "first", "position"} from the one `KVERDICT` line;
    two such lines are no verdict."""
    ks, kall, env = [], [], []
    for line in out_text.splitlines():
        if line.startswith("KVERDICT "):
            parts = line[len("KVERDICT "):].split("\t")
            if len(parts) == 3:
                ks.append({"word": parts[0], "first": parts[1], "position": parts[2]})
        elif line.startswith("KALL [") and line.endswith("]"):
            kall = [x for x in line[len("KALL ["):-1].split(";") if x]
        elif line.startswith("ENVELOPE "):
            env.append(line)
    return (ks[0] if len(ks) == 1 else None), kall, env


def verdict_triple(record):
    """The MATRIX fields of a run record's verdict: (verdict, first finding, position),
    as `candidate_checks.ail`'s candidate_verdict_word / _first_finding / _position."""
    v = record.get("verdict") or {}
    st = v.get("status")
    if st == "reproduced":
        return "reproduced", "-", "-"
    if st == "diverged":
        return "diverged", v["finding"], v["position"]
    if st == "refused":
        pos = {"ProgramUndecodable": "aggregate:program", "GuardTripped": "aggregate:guard",
               "PreflightMismatch": "aggregate:k0"}.get(v["reason"], "aggregate:refusal")
        return "refused", f"{v['reason']}:{v['finding']}", pos
    return "error", v.get("detail", "-"), "-"


def k0_identity_findings(obs, ids, pins):
    """Everything K0 compares that is not the provenance records.
    `obs`: {build, program, toolchain, lock_a_sha256, lock_c_sha256, t0_sha256,
            program_file_sha256, lock_a}; `ids`: the entry's identities.json."""
    fs = []
    build, program, tool = obs.get("build"), obs.get("program"), obs.get("toolchain") or {}
    if build is None:
        fs.append(finding("record", "k0build_missing", "the runner printed no K0BUILD line"))
    else:
        for k in BUILD_KEYS:
            if build.get(k) != ids.get(k):
                fs.append(finding("profile", k, "build differs from the entry"))
        if build.get("normalized_configuration") != ids.get("normalized_configuration"):
            fs.append(finding("t0_settings", "normalized_configuration", "T0 configuration differs from the entry"))
    if program is None:
        fs.append(finding("record", "program_missing", "the runner printed no PROGRAM line"))
    else:
        man = program.get("manifest", {})
        for k in PROFILE_KEYS:
            if man.get(k) != ids.get(k):
                fs.append(finding("manifest", k, "the program's manifest differs from the entry"))
        if man.get("toolchain") != f"{ids.get('toolchain')} binary={ids.get('toolchain_sha256')}":
            fs.append(finding("manifest", "toolchain", "the program's manifest names another toolchain"))
        if program.get("digest") != pins.get("program_digest"):
            fs.append(finding("program", "digest", "the loaded program's digest differs from the pin"))
    if tool.get("toolchain") != ids.get("toolchain"):
        fs.append(finding("toolchain", "version", "ailang --version differs from the entry"))
    if tool.get("full") != pins.get("toolchain_commit"):
        fs.append(finding("toolchain", "commit", "ailang build commit differs from the pin"))
    if tool.get("sha256") != ids.get("toolchain_sha256"):
        fs.append(finding("binary", "sha256", "ailang binary differs from the entry"))
    if obs.get("program_file_sha256") != pins.get("program_file_sha256"):
        fs.append(finding("corpus", "program.artifact", "program artifact differs from the pin"))
    if obs.get("t0_sha256") != pins.get("t0_settings_sha256"):
        fs.append(finding("t0_settings", "file", "t0_settings.json differs from the pin"))
    for side in ("lock_a_sha256", "lock_c_sha256"):
        if obs.get(side) != pins.get("lock_sha256") or obs.get(side) != ids.get("lock_sha256"):
            fs.append(finding("lock", side[:-7], "ailang.lock differs from the entry's pin"))
    want = [{"name": p["name"], "source": p.get("source", ""), "path": p.get("path", ""),
             "version": p.get("version", ""), "interface_hash": p.get("interface_hash", "")}
            for p in (obs.get("lock_a") or {}).get("packages", [])]
    if want != ids.get("packages"):
        fs.append(finding("packages", "lock_entries", "A's lock entries differ from the entry's"))
    return fs


# ---------------------------------------------------------------------------
# The guard
# ---------------------------------------------------------------------------

def guard_verdict(record_path, runner_verdicts, verify):
    """None when the run may be credited; else the GuardTripped refusal."""
    ok, why = verify(record_path)
    if ok:
        return None
    if why == "status:child_failed":
        with open(record_path) as f:
            rec = json.load(f)
        child = rec.get("child") or {}
        if child.get("exit_code") == 1 and any(v.startswith("CANDIDATE refused ") for v in runner_verdicts):
            return None  # the runner's own refusal, with a healthy guard
        if child.get("exit_code") == 2 and any(v.startswith("CANDIDATE error ") for v in runner_verdicts):
            return None  # the runner could not read its inputs: an evaluator failure, not a trip
    return Refused("GuardTripped", why, f"guard record {os.path.basename(record_path)}")


def decide(k0, kv, runner_errors):
    """After the run: K0 first (a finding refuses and discards any K verdict),
    then the runner's K1–K7 verdict, which must be exactly one reproduced or
    diverged line with no runner error. Returns ("refused", Refused),
    ("error", why) or ("k", verdict)."""
    if k0:
        return "refused", Refused("PreflightMismatch", k0[0]["finding"], k0[0]["detail"])
    if runner_errors:
        return "error", runner_errors[0]
    if kv is None or kv["word"] not in ("reproduced", "diverged"):
        return "error", "the runner printed no K1-K7 verdict"
    return "k", kv


# ---------------------------------------------------------------------------
# pin
# ---------------------------------------------------------------------------

def make_pins(repo, a_rev, lock_root, entry, manifest_path, binary, env):
    a = rev_commit(repo, a_rev)
    lock_bytes = git(repo, "show", f"{a}:ailang.lock", binary=True)
    lock = json.loads(lock_bytes)
    pins = {"schema": PINS_SCHEMA, "admission_commit": a, "lock_root": os.path.normpath(lock_root),
            "lock_sha256": "sha256:" + sha256_bytes(lock_bytes), "path_packages": {}, "registry_packages": {}}
    for p in lock.get("packages", []):
        if p.get("source") == "path":
            rel = lock_path_rel(p.get("path", ""), lock_root)
            tree = ""
            if rel and git(repo, "cat-file", "-t", f"{a}:{rel}", check=False).strip() == "tree":
                tree = git(repo, "rev-parse", f"{a}:{rel}").strip()
            rec = {"a_path": rel if tree else None, "tree": tree or None, "files": {}}
            if tree:
                listed = git(repo, "ls-tree", "-r", "-z", "--name-only", a, "--", rel)
                for f in (x for x in listed.split("\0") if x):
                    rec["files"][os.path.relpath(f, rel)] = sha256_bytes(git(repo, "show", f"{a}:{f}", binary=True))
            pins["path_packages"][p["name"]] = rec
        else:
            home = env.get("HOME", "")
            d = os.path.join(home, ".ailang", "cache", "registry", *p["name"].split("/", 1), p.get("version", ""))
            files = walk_files(d) if os.path.isdir(d) else {}
            pins["registry_packages"][p["name"]] = {"dir": d if files else None, "files": files,
                                                    "tree_sha256": files_digest(files) if files else None}
    base = env.get("XDG_DATA_HOME") or os.path.join(env.get("HOME", ""), ".local", "share")
    std_root = os.path.join(base, "ailang", "std")
    pins["stdlib"] = {"root": std_root, "files": {k: v for k, v in walk_files(std_root).items()
                                                  if k.endswith(".ail")} if os.path.isdir(std_root) else {}}
    tool = toolchain_now(binary)
    pins["toolchain_commit"] = tool["full"]
    pins["binary_sha256"] = tool["sha256"]
    pins["loader_sources"] = dict(LOADER_SOURCES)
    with open(manifest_path, "rb") as f:
        pins["protected_manifest_sha256"] = sha256_bytes(f.read())
    prog = os.path.join(entry, "program.artifact")
    with open(prog, "rb") as f:
        data = f.read()
    pins["program_file_sha256"] = sha256_bytes(data)
    # `recorded_digest` (scan.ail): the artifact's second line, "digest\t<d>".
    lines = data.decode(errors="replace").split("\n")
    pins["program_digest"] = lines[1].split("\t", 1)[1] if len(lines) > 1 and lines[1].startswith("digest\t") else ""
    with open(os.path.join(entry, "t0_settings.json"), "rb") as f:
        pins["t0_settings_sha256"] = sha256_bytes(f.read())
    return pins


# ---------------------------------------------------------------------------
# run
# ---------------------------------------------------------------------------

def emit(out, line):
    out.append(line)
    print(line, flush=True)


def envelope_lines(out, record, runner_envelope=()):
    """Every verdict's envelope: the runner's K1–K7 envelope when a run gave
    one (D3: checked, pinned, the four words, identity evidence, marker check,
    exhausted markers, findings, score, diagnostic), else this runner's; then
    the residual gap (D5) and the record."""
    if runner_envelope:
        for line in runner_envelope:
            if not line.startswith("ENVELOPE residual_gap="):
                emit(out, line)
    else:
        emit(out, "ENVELOPE checked=K0 evidence=execution-provenance "
                  "marker_check=not applicable: no K1-K7 verdict (refused or not run)")
        emit(out, "ENVELOPE score=forbidden: no K1-K7 verdict")
    emit(out, f"ENVELOPE residual_gap={RESIDUAL_GAP}")
    if record:
        emit(out, f"ENVELOPE record={record}")


def run(opts):
    """Returns (exit code, lines, record dict)."""
    lines = []
    repo = os.path.abspath(opts.repo)
    entry = os.path.abspath(opts.entry)
    parent = rev_commit(repo, opts.parent)
    cand = rev_commit(repo, opts.candidate)
    binary = shutil.which(opts.ailang) or opts.ailang
    env = dict(os.environ)
    run_id = opts.run_id or f"cand-{uuid.uuid4().hex[:12]}"
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", run_id) or run_id.startswith("."):
        raise EvalError(f"bad run id {run_id!r}")
    run_dir = os.path.join(entry, "runs", run_id)
    if os.path.lexists(run_dir):
        raise EvalError(f"run directory exists: {run_dir}")
    record = {"schema": "eval-candidate-run/1", "run_id": run_id, "parent": parent, "candidate": cand,
              "residual_gap": RESIDUAL_GAP, "steps": []}
    old_umask = os.umask(0o077)
    os.makedirs(run_dir)
    tree = os.path.join(run_dir, "tree")
    rec_path = os.path.join(run_dir, "provenance.json")
    worktree_added = False
    runner_env = []

    def finish(code, refusal=None, k=None, error=None):
        if refusal is not None:
            record["verdict"] = {"status": "refused", "reason": refusal.reason, "finding": refusal.finding,
                                 "detail": refusal.detail, "score_permitted": False}
            emit(lines, f"CANDIDATE refused {refusal.label()} {refusal.detail}".rstrip())
        elif error is not None:
            record["verdict"] = {"status": "error", "detail": error, "score_permitted": False}
            emit(lines, f"CANDIDATE error {error}")
        elif k["word"] == "reproduced":
            record["verdict"] = {"status": "reproduced", "k0": "passed", "checked": "K0-K7",
                                 "score_permitted": True}
            emit(lines, "CANDIDATE reproduced K0-K7 (score permitted)")
        else:
            check = k["first"].split(":", 1)[0]
            record["verdict"] = {"status": "diverged", "k0": "passed", "check": check, "finding": k["first"],
                                 "position": k["position"], "score_permitted": False}
            emit(lines, f"CANDIDATE diverged {k['first']}@{k['position']} (no score)")
        with open(rec_path, "w", encoding="utf-8") as f:
            json.dump(record, f, indent=1, sort_keys=True)
            f.write("\n")
        envelope_lines(lines, rec_path, runner_env if refusal is None and error is None else ())
        return code, lines, record

    try:
        # --- E, materialised (the checker and the guard come from here)
        e_files, e_ident = evaluator_files(opts.evaluator, repo)
        record["evaluator"] = e_ident
        edir = os.path.join(run_dir, "evaluator")
        write_files(edir, e_files)
        checker = os.path.join(edir, "tools/eval_protected/protected.py")
        manifest = os.path.join(edir, "tools/eval_protected/manifest-A.json")
        if not (os.path.isfile(checker) and os.path.isfile(manifest)):
            raise EvalError("E has no protected checker or manifest")

        # --- 1. refusals
        first, _, steps = refuse_before_running(repo, parent, cand, opts.record, checker, manifest)
        record["steps"] = steps
        if first is not None:
            return finish(1, first)

        # --- the entry's pins
        with open(os.path.join(entry, "identities.json"), encoding="utf-8") as f:
            ids = json.load(f)
        pins = ids.get("execution_pins")
        if not isinstance(pins, dict) or pins.get("schema") != PINS_SCHEMA:
            return finish(1, Refused("PreflightMismatch", "record:pins_missing", "the entry pins no execution record"))
        if ids.get("generator_version", "").endswith("-dev") and not opts.synthetic:
            return finish(1, Refused("PreflightMismatch", "e_unpinned:dev_generator",
                                     "a -dev evaluator never scores a real entry"))
        k0 = []
        k0 += loader_rule_findings(opts.ailang_source)
        with open(manifest, "rb") as f:
            if sha256_bytes(f.read()) != pins.get("protected_manifest_sha256"):
                k0.append(finding("protected", "manifest", "E's manifest differs from the entry's pin"))

        cache = os.path.join(run_dir, "cache")
        warm = cache_dir_state(cache)
        if warm is not None:
            return finish(1, Refused("PreflightMismatch", warm["finding"], warm["detail"]))

        # --- 2. assembly
        a = rev_commit(repo, pins["admission_commit"])
        corpus_before = corpus_hashes(entry)
        git(repo, "worktree", "add", "--detach", "--quiet", tree, cand)
        worktree_added = True
        for prefix in EVALUATOR_PATHS:
            shutil.rmtree(os.path.join(tree, prefix), ignore_errors=True)
        write_files(tree, e_files)
        lock_a_bytes = git(repo, "show", f"{a}:ailang.lock", binary=True)
        lock_a = json.loads(lock_a_bytes)
        with open(os.path.join(tree, "ailang.lock"), "rb") as f:
            lock_c_sha = "sha256:" + sha256_bytes(f.read())
        pkg_root = os.path.join(run_dir, "packages")
        copied = copy_path_packages(repo, a, lock_a, pins["lock_root"], pkg_root)
        eff, rewrites = effective_lock(lock_a, tree, pkg_root)
        eff_text = json.dumps(eff, indent=2) + "\n"
        with open(os.path.join(tree, "ailang.lock"), "w", encoding="utf-8") as f:
            f.write(eff_text)
        with open(os.path.join(tree, "ailang.lock"), encoding="utf-8") as f:
            k0 += lock_rewrite_findings(lock_a, json.load(f))
        for name, c in copied.items():
            pin = pins["path_packages"].get(name, {})
            if c["files"] != pin.get("files", {}) or c["a_path"] != pin.get("a_path"):
                k0.append(finding("packages", f"copy:{name}", "the copied package differs from A's pin"))
        restrict_perms(run_dir)
        assembled = walk_files(tree, skip=(".git",))
        record["assembly"] = {
            "tree_hash": git_tree_hash(tree), "evaluator": e_ident["id"], "compat_patch": None,
            "effective_lock_sha256": "sha256:" + sha256_bytes(eff_text.encode()),
            "original_lock_sha256": "sha256:" + sha256_bytes(lock_a_bytes), "lock_rewrites": rewrites,
            "packages": {n: {"a_path": c["a_path"], "files_sha256": files_digest(c["files"]),
                             "real_path": os.path.realpath(os.path.join(pkg_root, n)) if c["a_path"] else None}
                         for n, c in copied.items()},
        }
        e_before = evaluator_hash_in(tree)
        if e_before != e_ident["files_sha256"]:
            k0.append(finding("evaluator", "assembled", "the tree's evaluator files are not E's"))
        prot_before, _ = protected_check(checker, manifest, tree, repo)
        if prot_before:
            k0.append(finding("protected", "assembled_before", prot_before[0].label()))

        # --- 3. the run, guarded
        run_env = {k: v for k, v in env.items()
                   if k not in ("AILANG_NO_CACHE", "AILANG_STDLIB_PATH", "EVAL_WORKDIR", "EVAL_ENTRY", "EVAL_LABEL")}
        run_env.update(AILANG_CACHE_DIR=cache, EVAL_MODE="candidate",
                       EVAL_PROGRAM=os.path.join(entry, "program.artifact"),
                       EVAL_ENTRY_DIR=entry, EVAL_PROVENANCE=rec_path,
                       EVAL_FIXTURE=opts.fixture or "")
        if opts.guard_lock:
            run_env["EVAL_LOCK_PATH"] = opts.guard_lock
        cmd = [sys.executable, os.path.join(edir, "scripts/eval/mem_guard.py"),
               "--peak-bytes", str(opts.peak_bytes), "--peak-source", opts.peak_source,
               "--record", os.path.join(run_dir, "guard.json"), "--",
               binary, "run", "-debug-compile", "-trace-loader", "--caps", CAPS, "--ai-stub",
               "--entry", "main", RUNNER_ENTRY]
        with open(os.path.join(run_dir, "run.out"), "wb") as so, open(os.path.join(run_dir, "compile.log"), "wb") as se:
            rc = subprocess.run(cmd, cwd=tree, env=run_env, stdout=so, stderr=se, stdin=subprocess.DEVNULL).returncode
        with open(os.path.join(run_dir, "run.out"), encoding="utf-8", errors="replace") as f:
            out_text = f.read()
        with open(os.path.join(run_dir, "compile.log"), encoding="utf-8", errors="replace") as f:
            log_text = f.read()
        record["run"] = {"exit": rc, "run_out_sha256": sha256_file(os.path.join(run_dir, "run.out")),
                         "compile_log_sha256": sha256_file(os.path.join(run_dir, "compile.log"))}
        build, program, verdicts = parse_runner(out_text)
        sys.path.insert(0, os.path.join(edir, "scripts/eval"))
        try:
            import mem_guard  # E's guard
        finally:
            sys.path.pop(0)
        g = guard_verdict(os.path.join(run_dir, "guard.json"), verdicts, mem_guard.verify_record)
        if g is not None:
            return finish(1, g)
        undecodable = [v for v in verdicts if v.startswith("CANDIDATE refused ProgramUndecodable")]
        if undecodable:
            detail = undecodable[0][len("CANDIDATE refused ProgramUndecodable"):].strip().lstrip(":")
            return finish(1, Refused("ProgramUndecodable", detail.split(" ", 1)[0], detail))
        kv, kall, kenv = parse_k(out_text)
        runner_errors = [v[len("CANDIDATE error "):] for v in verdicts if v.startswith("CANDIDATE error ")]

        # --- 4. K0: identities
        tool = toolchain_now(binary)
        with open(os.path.join(entry, "program.artifact"), "rb") as f:
            prog_sha = sha256_bytes(f.read())
        with open(os.path.join(entry, "t0_settings.json"), "rb") as f:
            t0_sha = sha256_bytes(f.read())
        obs = {"build": build, "program": program, "toolchain": tool,
               "lock_a_sha256": "sha256:" + sha256_bytes(lock_a_bytes), "lock_c_sha256": lock_c_sha,
               "t0_sha256": t0_sha, "program_file_sha256": prog_sha, "lock_a": lock_a}
        k0 += k0_identity_findings(obs, ids, pins)

        # --- K0: the three provenance records
        ids_compiled, fs_c, rec_c = compiled_set(log_text, os.path.join(cache, "compile", "manifest.json"))
        k0 += fs_c
        ctx = LoaderContext(tree, eff, binary, run_env, pins, pkg_root)
        sel_rows, fs_s = selections(ids_compiled, ctx, assembled, log_text)
        k0 += fs_s
        trace_present = bool(TRACE_INIT.search(log_text))
        sys.path.insert(0, os.path.join(edir, "tools/eval_protected"))
        try:
            import ailspan
        finally:
            sys.path.pop(0)
        stmt, prelude_only, injected, fs_i = import_closure(RUNNER_ID, ctx, ailspan.parse)
        k0 += fs_i + closure_findings(stmt, prelude_only, ids_compiled)
        record["execution"] = {
            "compiled": rec_c, "compiled_ids": ids_compiled, "selected": sel_rows,
            "stdlib_search_paths": ctx.std_paths, "loader_trace": "present" if trace_present else
            "absent (ailang ae36986 discards -trace-loader: cmd/ailang/main_run_exec.go:141-143)",
            # recorded, not refused: e.g. a lock path package absent from A's tree
            # stops ailang's content-hash validation (lockfile.go:152–166) at
            # the first failure; K0's own pins cover every file that compiled.
            "loader_warnings": [l for l in log_text.splitlines() if l.startswith("Warning:")][:20],
            "closure_size": len(stmt), "prelude_only": sorted(prelude_only),
            "prelude_injected": {k: v for k, v in sorted(injected.items())},
            "env": {"AILANG_CACHE_DIR": cache, "AILANG_NO_CACHE": None, "AILANG_STDLIB_PATH": None,
                    "XDG_DATA_HOME": env.get("XDG_DATA_HOME"), "HOME": env.get("HOME")},
        }
        modules = os.path.join(cache, "compile", "modules")
        if os.path.isdir(modules):
            shutil.rmtree(modules)
            record["execution"]["compiled"]["modules_removed"] = True

        # --- after the run: E, corpus, protected, tree
        if evaluator_hash_in(tree) != e_before:
            k0.append(finding("evaluator", "changed_during_run", "the assembled evaluator files changed"))
        if isinstance(opts.evaluator, str) and os.path.isdir(opts.evaluator):
            if evaluator_files(opts.evaluator, repo)[1]["files_sha256"] != e_ident["files_sha256"]:
                k0.append(finding("evaluator", "source_changed", "E changed during the run"))
        if corpus_hashes(entry) != corpus_before:
            k0.append(finding("corpus", "changed_during_run", "an entry file changed"))
        prot_after, _ = protected_check(checker, manifest, tree, repo)
        if prot_after:
            k0.append(finding("protected", "assembled_after", prot_after[0].label()))
        if walk_files(tree, skip=(".git",)) != assembled:
            k0.append(finding("tree", "changed_during_run", "the assembled tree changed"))
        record["k0"] = k0
        record["k"] = {"verdict": kv, "findings": kall}
        kind, what = decide(k0, kv, runner_errors)
        if kind == "refused":
            if kv is not None:
                record["k_discarded"] = "K0 failed: the run's K verdict is not a verdict"
            return finish(1, what)
        if kind == "error":
            return finish(2, error=what)
        runner_env[:] = kenv
        return finish(0 if what["word"] == "reproduced" else 1, k=what)
    finally:
        if worktree_added and not opts.keep_tree:
            git(repo, "worktree", "remove", "--force", tree, check=False)
            shutil.rmtree(tree, ignore_errors=True)
            git(repo, "worktree", "prune", check=False)
        os.umask(old_umask)


# ---------------------------------------------------------------------------
# matrix
# ---------------------------------------------------------------------------

MATRIX_EXPECTED = "src/eval/journal/testdata/MATRIX.expected.tsv"
MATRIX_OUT = "src/eval/journal/testdata/MATRIX.tsv"
MATRIX_COLUMNS = ("case_id", "test_name", "observed_verdict", "observed_first_finding", "observed_position",
                  "observed_by", "commit")
VERDICT_LEVEL_ROWS = ("M10.verdict.", "P17a.")
ASSERTED = "(asserted)"


def read_tsv(path):
    with open(path, encoding="utf-8") as f:
        lines = [l.rstrip("\n") for l in f if l.strip()]
    head = lines[0].split("\t")
    return [dict(zip(head, l.split("\t"))) for l in lines[1:]]


def _balanced(text, start):
    """The index just past the parenthesised group opening at text[start]."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i + 1
    return None


def verdict_label(line_rest):
    """The leading verdict label of `<Verdict>(...)` text, or None."""
    m = re.match(r"(SourceFaithful|Reproduced|Refused|Diverged)\(", line_rest)
    if not m:
        return None
    end = _balanced(line_rest, m.end() - 1)
    return None if end is None else line_rest[:end]


CANDIDATE_REFUSAL_POSITION = (("ProgramUndecodable:", "aggregate:program"), ("GuardTripped:", "aggregate:guard"),
                              ("PreflightMismatch:", "aggregate:k0"))


def label_triple(case_id, label):
    """A printed verdict label as MATRIX fields (C1 format), or None."""
    verdict_level = case_id.startswith(VERDICT_LEVEL_ROWS)
    if label.startswith(("SourceFaithful(", )):
        return "admitted", "-", "-"
    if label.startswith("Reproduced("):
        return "reproduced", "-", "-"
    m = re.fullmatch(r"Diverged\((K\d):([^\[]+)\[[^\]]*\]@(.+)\)", label)
    if m:
        return "diverged", f"{m.group(1)}:{m.group(2)}", m.group(3)
    m = re.fullmatch(r"Refused\(AdmissionCheck\((A\d+b?)\):(.+)@([^@]+)\)", label)
    if m:
        first = f"AdmissionCheck({m.group(1)})" if verdict_level else f"{m.group(1)}:{m.group(2)}"
        return "refused", first, m.group(3)
    m = re.fullmatch(r"Refused\(Refusal\((.+)\)@([^@]+)\)", label)
    if m:
        return "refused", m.group(1), m.group(2)
    if label.startswith("Refused(ScanRefusal("):
        return "refused", "ScanRefusal", "aggregate:scan"
    m = re.fullmatch(r"Refused\((.+)\)", label)
    if m:
        inner = m.group(1)
        pos = next((p for pre, p in CANDIDATE_REFUSAL_POSITION if inner.startswith(pre)), "aggregate:refusal")
        return "refused", inner, pos
    return None


def live_observations(out_text):
    """A live runner's output: ({label: passed}, {label: first verdict label})."""
    passed, printed = {}, {}
    for line in out_text.splitlines():
        m = re.match(r"^(PASS|FAIL) (\S+)", line)
        if m:
            passed[m.group(2)] = passed.get(m.group(2), True) and m.group(1) == "PASS"
            continue
        m = re.match(r"^([A-Za-z0-9_]+): (.*)$", line)
        if m and m.group(1) not in printed:
            lab = verdict_label(m.group(2))
            if lab is not None:
                printed[m.group(1)] = lab
    return passed, printed


def pure_observations(out_text):
    """`ailang test --format json` output: {test function: passed}."""
    i = out_text.find("{")
    if i < 0:
        return {}
    try:  # the JSON document, then whatever the runner wrote to stderr
        doc, _ = json.JSONDecoder().raw_decode(out_text[i:])
    except ValueError:
        return {}
    res = {}
    for t in doc.get("tests", []):
        name = re.sub(r"_test_\d+$", "", t.get("name", ""))
        res[name] = res.get(name, True) and t.get("status") == "pass"
    return res


def junit_observations(path):
    """pytest's junit XML: {test name: pass|fail|skipped}."""
    res = {}
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError):
        return res
    for tc in root.iter("testcase"):
        kids = {c.tag for c in tc}
        st = "fail" if kids & {"failure", "error"} else "skipped" if "skipped" in kids else "pass"
        res[tc.get("name")] = st
    return res


def join_row(exp, obs):
    """One row's join status."""
    if exp["test_name"] == "-":
        return "inapplicable" if exp["expected_verdict"] == "inapplicable" and obs["observed_verdict"] == "inapplicable" \
            else "mismatch"
    st = obs["observed_verdict"]
    if obs["observed_by"] == "record":
        if obs.get("_outcome") != "pass":
            return {"skipped": "skipped", "missing": "missing"}.get(obs.get("_outcome"), "failed")
        same = all(exp[f"expected_{k}"] == obs[f"observed_{k}"] for k in ("verdict", "first_finding", "position"))
        return "equal" if same else "mismatch"
    return {"pass": "credited", "skipped": "skipped", "missing": "missing"}.get(st, "failed")


def matrix(opts):
    repo = os.path.abspath(opts.repo)
    expected_path = os.path.join(repo, opts.expected)
    out_path = os.path.join(repo, opts.out)
    logs = opts.logs or tempfile.mkdtemp(prefix="eval-matrix-")
    os.makedirs(logs, exist_ok=True)
    rows = read_tsv(expected_path)
    head = git(repo, "rev-parse", "HEAD").strip()
    dirty = git(repo, "status", "--porcelain", "--untracked-files=no", "--", *EVALUATOR_PATHS).strip()
    commit = head + ("+dirty" if dirty else "")
    by_test = {}
    for r in rows:
        by_test.setdefault(r["test_name"], []).append(r["case_id"])
    files = sorted({t.split(":", 1)[0] for t in by_test if t != "-"})
    env = {k: v for k, v in os.environ.items() if k not in ("EVAL_MATRIX_OBS",)}
    suites, outcome, printed = [], {}, {}

    def run_suite(name, cmd, log, timeout, extra_env=None):
        e = dict(env, **(extra_env or {}))
        print(f"eval_matrix: {name} ...", flush=True)
        try:
            r = subprocess.run(cmd, cwd=repo, env=e, capture_output=True, text=True, timeout=timeout,
                               stdin=subprocess.DEVNULL)
            rc, text = r.returncode, r.stdout + r.stderr
        except subprocess.TimeoutExpired as ex:
            rc, text = 124, (ex.stdout or b"").decode(errors="replace") if isinstance(ex.stdout, bytes) else (ex.stdout or "")
        with open(os.path.join(logs, log), "w", encoding="utf-8") as f:
            f.write(text)
        suites.append({"suite": name, "exit": rc, "log": log})
        print(f"eval_matrix: {name} exit {rc}", flush=True)
        return rc, text

    obs_path = os.path.join(logs, "candidate_obs.tsv")
    for f in files:
        base = os.path.basename(f)
        if f.endswith("_live_test.ail"):
            rc, text = run_suite(f, [opts.ailang, "run", "--caps", CAPS, "--ai-stub", "--entry", "main", f],
                                 base + ".log", 1800)
            passed, labels = live_observations(text)
            for k, v in passed.items():
                outcome[f"{f}:{k}"] = "pass" if v and rc == 0 else "fail"
            for k, v in labels.items():
                printed[f"{f}:{k}"] = v
        elif f.endswith(".ail"):
            rc, text = run_suite(f, [opts.ailang, "test", "--format", "json", f], base + ".log", 1800)
            for k, v in pure_observations(text).items():
                outcome[f"{f}:{k}"] = "pass" if v else "fail"
        elif f == "tools/eval_protected/selftest.py":
            tsv = os.path.join(logs, "selftest_observed.tsv")
            rc, text = run_suite(f, [sys.executable, f, "--observed-tsv", tsv], "selftest.log", 1800)
            failed = set(re.findall(r"^\s+FAIL M7\.(\S+):", text, re.M))
            if os.path.isfile(tsv):
                for o in read_tsv(tsv):
                    cid = o["test_name"].split(":", 1)[1]
                    outcome[o["test_name"]] = "fail" if cid in failed else "pass"
                    printed[o["test_name"]] = (o["observed_verdict"], o["observed_first_finding"],
                                               o["observed_position"])
        elif f == "src/eval/journal/testdata/gen_fixtures.py":
            rc, _ = run_suite(f, [sys.executable, f, "--check"], "gen_fixtures.log", 600)
            for t in by_test:
                if t.startswith(f + ":"):
                    outcome[t] = "pass" if rc == 0 else "fail"
        elif f == "scripts/eval/test_candidate.py":
            if os.path.exists(obs_path):
                os.remove(obs_path)
            xml = os.path.join(logs, "test_candidate.xml")
            extra = {"EVAL_MATRIX_OBS": obs_path}
            if opts.no_live:
                extra["EVAL_CANDIDATE_LIVE"] = "0"
            rc, _ = run_suite(f, [sys.executable, "-B", "-m", "pytest", "-q", f, f"--junitxml={xml}"],
                              "test_candidate.log", 7200, extra)
            for k, v in junit_observations(xml).items():
                outcome[f"{f}:{k}"] = v
            if os.path.isfile(obs_path):
                with open(obs_path, encoding="utf-8") as fh:
                    for line in fh:
                        parts = line.rstrip("\n").split("\t")
                        if len(parts) == 4:
                            printed.setdefault(parts[0], tuple(parts[1:]))
        else:
            suites.append({"suite": f, "exit": None, "log": "-", "note": "no runner for this test file"})
    rc, _ = run_suite("scripts/eval/test_mem_guard.py",
                      [sys.executable, "-B", "-m", "pytest", "-q", "scripts/eval/test_mem_guard.py"],
                      "test_mem_guard.log", 900)

    observed, joined = [], []
    for r in rows:
        t = r["test_name"]
        o = {"case_id": r["case_id"], "test_name": t, "observed_by": "assertion", "commit": commit}
        if t == "-":
            o.update(observed_verdict="inapplicable", observed_first_finding="(no test)", observed_position="-",
                     observed_by="reason")
        else:
            oc = outcome.get(t, "missing")
            p = printed.get(t)
            triple = None
            if p is not None and len(by_test[t]) == 1:
                triple = label_triple(r["case_id"], p) if isinstance(p, str) else p
            if triple is not None:
                o.update(observed_verdict=triple[0], observed_first_finding=triple[1],
                         observed_position=triple[2], observed_by="record", _outcome=oc)
            else:
                o.update(observed_verdict=oc, observed_first_finding=ASSERTED, observed_position=ASSERTED)
        observed.append(o)
        joined.append((r["case_id"], join_row(r, o)))
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\t".join(MATRIX_COLUMNS) + "\n")
        for o in observed:
            f.write("\t".join(o[c] for c in MATRIX_COLUMNS) + "\n")
    counts = {}
    with open(os.path.join(logs, "join.tsv"), "w", encoding="utf-8") as f:
        f.write("case_id\tstatus\n")
        for cid, st in joined:
            counts[st] = counts.get(st, 0) + 1
            f.write(f"{cid}\t{st}\n")
    with open(os.path.join(logs, "suites.json"), "w", encoding="utf-8") as f:
        json.dump(suites, f, indent=1)
    bad = [(c, st) for c, st in joined if st not in ("equal", "credited", "inapplicable")]
    bad_suites = [x for x in suites if x["exit"] != 0]
    print(f"eval_matrix: {len(rows)} rows: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print(f"eval_matrix: suites {len(suites)}, non-zero exit: "
          + (", ".join(f"{x['suite']}={x['exit']}" for x in bad_suites) or "none"))
    for c, st in bad[:40]:
        print(f"eval_matrix: {st} {c}")
    print(f"eval_matrix: wrote {os.path.relpath(out_path, repo)} (commit {commit}); logs {logs}")
    return 0 if not bad and not bad_suites else 1


def main(argv=None):
    ap = argparse.ArgumentParser(prog="candidate.py", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--repo", default=".")
    r.add_argument("--entry", required=True)
    r.add_argument("--parent", required=True)
    r.add_argument("--candidate", required=True)
    r.add_argument("--record", required=True)
    r.add_argument("--evaluator", required=True)
    r.add_argument("--peak-bytes", required=True, type=int)
    r.add_argument("--peak-source", required=True)
    r.add_argument("--run-id")
    r.add_argument("--guard-lock")
    r.add_argument("--fixture", default="")
    r.add_argument("--synthetic", action="store_true", help="a synthetic entry (a -dev E is allowed)")
    r.add_argument("--keep-tree", action="store_true")
    r.add_argument("--ailang", default="ailang")
    r.add_argument("--ailang-source", default=AILANG_SOURCE)
    p = sub.add_parser("pin")
    p.add_argument("--repo", default=".")
    p.add_argument("--at", required=True)
    p.add_argument("--lock-root", required=True)
    p.add_argument("--entry", required=True)
    p.add_argument("--manifest", default=os.path.join(HERE, "..", "..", "tools/eval_protected/manifest-A.json"))
    p.add_argument("--ailang", default="ailang")
    p.add_argument("--out")
    mx = sub.add_parser("matrix")
    mx.add_argument("--repo", default=".")
    mx.add_argument("--expected", default=MATRIX_EXPECTED)
    mx.add_argument("--out", default=MATRIX_OUT)
    mx.add_argument("--logs")
    mx.add_argument("--no-live", action="store_true", help="skip test_candidate's live compiles (never a clean matrix)")
    mx.add_argument("--ailang", default="ailang")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "matrix":
            return matrix(a)
        if a.cmd == "pin":
            pins = make_pins(os.path.abspath(a.repo), a.at, a.lock_root, a.entry, a.manifest,
                             shutil.which(a.ailang) or a.ailang, dict(os.environ))
            text = json.dumps(pins, indent=1, sort_keys=True) + "\n"
            if a.out:
                with open(a.out, "w", encoding="utf-8") as f:
                    f.write(text)
            else:
                sys.stdout.write(text)
            return 0
        code, _, _ = run(a)
        return code
    except EvalError as e:
        print(f"CANDIDATE error {e}", flush=True)
        return 2


if __name__ == "__main__":
    sys.exit(main())
