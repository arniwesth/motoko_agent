"""Tests for the runner's candidate mode (PLAN-004 v2 §3 P1.9a; matrix M13 and
M15's candidate-row family halves). Run:

    python3 -m pytest scripts/eval/test_candidate.py

Candidates are commits made with `git commit-tree` in a `--shared` scratch
clone of this repository (the real repository's refs and objects are never
written). E is this checkout (a `-dev` evaluator). The entry is synthetic
(§0.6): `candidate.ail`'s synthetic program, `journal_replay.sh collect`'s
identities for a world fixture with A's lock entries, and `candidate.py pin`'s
execution pins at A.

The `live` tests assemble and compile for real (one fresh-cache compile of the
runner, ~1–2 min each, guarded by mem_guard.py against the host cgroup). Set
EVAL_CANDIDATE_LIVE=0 to skip them.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import types

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "eval_protected"))

import candidate as C  # noqa: E402
import ailspan  # noqa: E402
import mem_guard  # noqa: E402

A = "65003110ff5a15e2ae5b1f0e205e0ffa705d18dc"
LOCK_ROOT = "/workspaces/motoko_agent"
CHECKER = os.path.join(REPO, "tools/eval_protected/protected.py")
MANIFEST = os.path.join(REPO, "tools/eval_protected/manifest-A.json")
FIXTURE = "m3_selector_end"
LIVE = os.environ.get("EVAL_CANDIDATE_LIVE", "1") != "0"
live = pytest.mark.skipif(not LIVE, reason="EVAL_CANDIDATE_LIVE=0")


# ---------------------------------------------------------------------------
# Fixtures: a shared clone, candidate commits, a synthetic entry
# ---------------------------------------------------------------------------

def git(repo, *args, env=None, inp=None):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, env=env, input=inp)
    assert r.returncode == 0, r.stderr.decode()
    return r.stdout.decode().strip()


def show(repo, rev, path):
    return subprocess.run(["git", "-C", repo, "show", f"{rev}:{path}"], capture_output=True, check=True).stdout


class Clone:
    def __init__(self, root):
        self.root = root
        git(REPO, "clone", "-q", "--shared", "--no-checkout", REPO, root)
        self.head = git(root, "rev-parse", "HEAD")
        self.n = 0

    def commit(self, parent, changes, msg="fx"):
        """changes: {path: bytes | None | (old, new)} — (old, new) replaces exactly one occurrence."""
        self.n += 1
        idx = os.path.join(os.path.dirname(self.root), f"index-{self.n}")
        env = dict(os.environ, GIT_INDEX_FILE=idx, GIT_AUTHOR_NAME="fx", GIT_AUTHOR_EMAIL="fx@invalid",
                   GIT_COMMITTER_NAME="fx", GIT_COMMITTER_EMAIL="fx@invalid",
                   GIT_AUTHOR_DATE="2026-09-16T00:00:00Z", GIT_COMMITTER_DATE="2026-09-16T00:00:00Z")
        git(self.root, "read-tree", parent, env=env)
        for path, ch in changes.items():
            if ch is None:
                git(self.root, "update-index", "--force-remove", path, env=env)
                continue
            if isinstance(ch, tuple):
                old, new = (x.encode() for x in ch)
                src = show(self.root, parent, path)
                assert src.count(old) == 1, (path, old, src.count(old))
                ch = src.replace(old, new)
            sha = git(self.root, "hash-object", "-w", "--stdin", inp=ch)
            git(self.root, "update-index", "--add", "--cacheinfo", f"100644,{sha},{path}", env=env)
        tree = git(self.root, "write-tree", env=env)
        return git(self.root, "commit-tree", tree, "-p", parent, "-m", msg, env=env)


@pytest.fixture(scope="session")
def work(tmp_path_factory):
    return tmp_path_factory.mktemp("cand")


@pytest.fixture(scope="session")
def clone(work):
    return Clone(str(work / "repo"))


def record_for(path, parent, cand, /, **over):
    rec = {"schema": C.RECORD_SCHEMA, "intent": C.INTENT, "parent": parent, "candidate": cand,
           "reviewer": "fx-reviewer"}
    rec.update(over)
    with open(path, "w") as f:
        json.dump(rec, f)
    return str(path)


def refuse(clone, work, changes, name, **rec):
    cand = clone.commit(clone.head, changes)
    path = record_for(work / f"rec-{name}.json", clone.head, cand, **rec)
    return C.refuse_before_running(clone.root, clone.head, cand, path, CHECKER, MANIFEST)


# The candidate edits, each against HEAD (whose src/core equals A's).
# PERMITTED_EDIT changes only the digest-only `m-end;` terminator of
# `canonical_messages` (whose one user is `digest_messages`): no sent message
# changes (P1R R3). Kept as M15's digest-function-only row and as the M13 edit.
PERMITTED_EDIT = {"src/core/phase_vocab.ail": ('["m-end;"]', '["m-end!"]')}
# P1R R3: a named permitted file edited so that a sent message changes: each
# tool-role result message the model is sent gains a trailing space, so the
# first affected call is the first one after a tool result.
SENT_MESSAGE_EDIT = {"src/core/phase_vocab.ail": ("content: cap_tool_message_content(content),",
                                                  'content: cap_tool_message_content("${content} "),')}
TOOL_PHASE_EDIT = {"src/core/tool_phase.ail": ("MOTOKO_TOOL_TIMEOUT_MS", "MOTOKO_TOOL_TIMEOUT_MX")}
OUTSIDE_SPANS_EDIT = {"src/core/ports.ail": (  # has_key: an unlisted callee of decode_provider_outcome
    "pure func has_key(obj: Json, key: string) -> bool {",
    "pure func has_key(obj: Json, key: string) -> bool {\n  -- fx: outside every protected span")}


# ---------------------------------------------------------------------------
# M13: InadmissibleCandidate by path
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("path", [
    "src/core/prompts.ail", "src/core/ext/registry.ail", "src/core/tool_catalog.ail", "src/core/backend.ail",
    "src/core/config.ail", "src/core/tool_runtime.ail", "src/core/tool_stream_phase.ail",
    "src/core/dst_replay.ail", "src/core/test/stub_step.ail", "scripts/dst/strict_replay_dst.ail",
])
def test_m13_inadmissible_path_d3(clone, work, path):
    first, _, steps = refuse(clone, work, {path: b"-- fx\n"}, "d3")
    assert first.label() == f"InadmissibleCandidate:path:{path}"
    assert steps == ["path"]


@pytest.mark.parametrize("path", ["ailang.lock", "ailang.toml", "packages/motoko-ext-abi/src/types.ail",
                                  "src/core/ailang.toml"])
def test_m13_inadmissible_path_packages(clone, work, path):
    first, _, steps = refuse(clone, work, {path: b"{}\n"}, "pkg")
    assert first.reason == "InadmissibleCandidate" and first.finding == f"path:{path}"
    assert steps == ["path"]


def test_m13_inadmissible_path_deletion_counts(clone, work):
    first, _, _ = refuse(clone, work, {"src/core/prompts.ail": None}, "del")
    assert first.label() == "InadmissibleCandidate:path:src/core/prompts.ail"


def test_m13_path_list_globs():
    assert C.glob_match("src/core/dst_replay.ail", "src/core/dst_*.ail")
    assert not C.glob_match("src/core/sub/dst_replay.ail", "src/core/dst_*.ail")
    assert C.glob_match("src/core/test/a/b.ail", "src/core/test/**")
    assert C.glob_match("ailang.toml", "**/ailang.toml")
    for loop_file in ("src/core/session.ail", "src/core/phase_vocab.ail", "src/core/journal.ail",
                      "src/core/context_usage.ail", "src/core/step_machine.ail", "src/core/tool_phase.ail",
                      "src/core/ports.ail"):
        assert C.path_refusals([loop_file]) == [], loop_file


# ---------------------------------------------------------------------------
# M13: InadmissibleCandidate by intent
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("over,label", [
    ({"intent": "behavior-change"}, "InadmissibleCandidate:intent:behavior-change"),
    ({"reviewer": ""}, "InadmissibleCandidate:intent:unreviewed"),
    ({"parent": "0" * 40}, "InadmissibleCandidate:intent:parent"),
    ({"candidate": "0" * 40}, "InadmissibleCandidate:intent:candidate"),
    ({"schema": "other/1"}, "InadmissibleCandidate:intent:schema"),
], ids=["behavior_change", "unreviewed", "parent", "candidate", "schema"])
def test_m13_inadmissible_intent(clone, work, over, label):
    first, _, steps = refuse(clone, work, PERMITTED_EDIT, "intent", **over)
    assert first.label() == label
    assert steps == ["path", "intent"]


def test_m13_inadmissible_intent_record_unreadable(clone, work):
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    first, _, steps = C.refuse_before_running(clone.root, clone.head, cand, str(work / "absent.json"),
                                              CHECKER, MANIFEST)
    assert first.label() == "InadmissibleCandidate:intent:record_unreadable"
    assert steps == ["path", "intent"]


def test_m13_path_before_intent(clone, work):
    first, _, steps = refuse(clone, work, {"ailang.lock": b"{}"}, "order", intent="behavior-change")
    assert first.label() == "InadmissibleCandidate:path:ailang.lock" and steps == ["path"]


# ---------------------------------------------------------------------------
# M13: EvaluatorTouched
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("path", ["src/eval/journal/reader.ail", "scripts/eval/mem_guard.py",
                                  "scripts/eval/journal_replay.ail", "tools/eval_protected/manifest-A.json",
                                  "src/eval/journal/testdata/gen_fixtures.py"])
def test_m13_evaluator_touched(clone, work, path):
    first, _, steps = refuse(clone, work, {path: b"# fx\n"}, "eval")
    assert first.label() == f"EvaluatorTouched:{path}"
    assert steps == ["path", "intent", "evaluator"]


# ---------------------------------------------------------------------------
# M13: ProtectedRegionTouched (at C, by symbol)
# ---------------------------------------------------------------------------

PROTECTED_CASES = {
    "span_hash": ({"src/core/ports.ail": ("status: OutcomeFault, fault_class_id: fault_class_tool_failed() }",
                                          "status: OutcomeOk, fault_class_id: fault_class_tool_failed() }")},
                  "ProtectedRegionTouched:changed:tool_outcome_record"),
    "missing": ({"src/core/ports.ail": ("pure func scripted_step_faults(", "pure func scripted_step_faultz(")},
                "ProtectedRegionTouched:missing:scripted_step_faults"),
    "duplicate": ({"src/core/session.ail": ("pure func provider_api_model(model: string, openai_base_url: string) -> string {",
                                            "pure func provider_api_model(model: string) -> string { model }\n\n"
                                            "pure func provider_api_model(model: string, openai_base_url: string) -> string {")},
                  "ProtectedRegionTouched:duplicate:provider_api_model"),
    "import_statement": ({"src/core/session.ail": ("import src/core/step_machine (decide)\n",
                                                   "import src/core/step_machine (decide)\nimport std/math (abs)\n")},
                         "ProtectedRegionTouched:changed:<imports:1>"),
}


@pytest.mark.parametrize("case", sorted(PROTECTED_CASES))
def test_m13_protected_region_touched(clone, work, case):
    changes, label = PROTECTED_CASES[case]
    first, _, steps = refuse(clone, work, changes, f"prot-{case}")
    assert first.label() == label
    assert steps == ["path", "intent", "evaluator", "protected"]


def test_m13_protected_region_moved(clone, work):
    ports = show(clone.root, clone.head, "src/core/ports.ail").decode()
    session = show(clone.root, clone.head, "src/core/session.ail").decode()
    start = session.index("pure func provider_api_model(")
    end = session.index("\n}\n", start) + 3
    fn = session[start:end]
    first, _, _ = refuse(clone, work, {"src/core/session.ail": (session[:end] + session[end:]).replace(fn, "").encode(),
                                       "src/core/ports.ail": (ports + "\n" + fn).encode()}, "prot-moved")
    assert first.label() == "ProtectedRegionTouched:moved:provider_api_model"
    assert "src/core/ports.ail" in first.detail


def test_m13_protected_checker_error_refuses(clone, work):
    first, _, _ = refuse(clone, work, {"src/core/ports.ail": ("pure func has_key(obj: Json, key: string) -> bool {",
                                                              "pure func has_key(obj: Json, key: string) -> bool { \"")},
                         "prot-lex")
    assert first.label() == "ProtectedRegionTouched:checker_error"


# ---------------------------------------------------------------------------
# M13 clean twin and M15's candidate rows (family halves)
# ---------------------------------------------------------------------------

def test_m13_clean_twin_passes_every_refusal(clone, work):
    first, rs, steps = refuse(clone, work, PERMITTED_EDIT, "clean")
    assert first is None and rs == []
    assert steps == ["path", "intent", "evaluator", "protected"]


def m15_passes_path_and_protected(clone, work, changes, name):
    first, rs, steps = refuse(clone, work, changes, name)
    assert first is None and rs == []
    assert steps == ["path", "intent", "evaluator", "protected"]
    for path in changes:
        assert C.path_refusals([path]) == [], path


def m15_passes_intent(clone, work, changes, name):
    # Declared and reviewed resource-only, but it changes one output.
    cand = clone.commit(clone.head, changes)
    rec = C.load_record(record_for(work / f"rec-{name}.json", clone.head, cand))
    assert C.intent_refusals(rec, clone.head, cand) == []
    first, _, _ = C.refuse_before_running(clone.root, clone.head, cand, str(work / f"rec-{name}.json"),
                                          CHECKER, MANIFEST)
    assert first is None


def test_m15_inadmissible_path_passes_path_refusal(clone, work):
    # The sent-message edit: the path refusal and the protected check pass
    # (K0: the live test below).
    m15_passes_path_and_protected(clone, work, SENT_MESSAGE_EDIT, "m15-path")


def test_m15_inadmissible_path_edit_changes_a_sent_message(clone):
    # The edit sits in `tool_result_message`, which builds the tool-role
    # messages the model is sent, and in no span of the manifest.
    (path, (old, _)), = SENT_MESSAGE_EDIT.items()
    src = show(clone.root, clone.head, path)
    fn = src.index(b"export func tool_result_message(call: ToolCall, content: string) -> Message {")
    at = src.index(old.encode())
    assert fn < at < src.index(b"\n}\n", fn)
    with open(MANIFEST) as f:
        spans = [s for s in json.load(f)["spans"] if s["file"] == path]
    assert all(not (s["bytes"][0] <= at < s["bytes"][1]) for s in spans), spans


def test_m15_inadmissible_intent_passes_intent_refusal(clone, work):
    m15_passes_intent(clone, work, SENT_MESSAGE_EDIT, "m15-intent")


def test_m15_digest_function_only_passes_path_refusal(clone, work):
    # PERMITTED_EDIT: the digest-only terminator (P1R R3's renamed row).
    m15_passes_path_and_protected(clone, work, PERMITTED_EDIT, "m15-digest-path")


def test_m15_digest_function_only_passes_intent_refusal(clone, work):
    m15_passes_intent(clone, work, PERMITTED_EDIT, "m15-digest-intent")


def test_m15_evaluator_touched_passes_evaluator_refusal(clone, work):
    # tool_phase.ail is outside §0.5's paths and D3's list; the edit changes the
    # environment key a tool dispatch reads (MOTOKO_TOOL_TIMEOUT_MS).
    first, _, steps = refuse(clone, work, TOOL_PHASE_EDIT, "m15-eval")
    assert first is None and steps == ["path", "intent", "evaluator", "protected"]


def test_m15_protected_region_passes_protected_refusal(clone, work):
    # An edit outside every protected span, inside `has_key` — an unlisted
    # callee of `decode_provider_outcome` in the manifest: the checker allows it.
    first, _, steps = refuse(clone, work, OUTSIDE_SPANS_EDIT, "m15-prot")
    assert first is None and steps[-1] == "protected"
    with open(MANIFEST) as f:
        m = json.load(f)
    assert "has_key@src/core/ports.ail" in m["unlisted_callees"]["decode_provider_outcome@src/core/ports.ail"]


# ---------------------------------------------------------------------------
# M13: GuardTripped
# ---------------------------------------------------------------------------

def guard_record(path, **over):
    rec = {"status": "pass", "trip": False, "valid": True, "interrupted": None,
           "monitor": {"started": True, "gaps": []}, "child": {"exit_code": 0}}
    for k, v in over.items():
        rec[k] = v
    with open(path, "w") as f:
        json.dump(rec, f)
    return str(path)


@pytest.mark.parametrize("over,why", [
    ({"trip": True, "status": "tripped", "valid": False}, "trip"),
    ({"monitor": {"started": True, "gaps": [{"after_sample": 3, "seconds": 9.0}]}}, "monitor_gap"),
    ({"status": "refused", "valid": False}, "invalid"),
    ({"status": "refused", "valid": False, "monitor": {"started": False, "gaps": []}}, "monitor_not_started"),
    ({"interrupted": {"signal": 2}}, "interrupted"),
    ({"status": "child_failed", "child": {"exit_code": 1}}, "status:child_failed"),
], ids=["trip", "monitor_gap", "refused", "monitor_not_started", "interrupted", "child_failed"])
def test_m13_guard_tripped(tmp_path, over, why):
    g = C.guard_verdict(guard_record(tmp_path / "guard.json", **over), [], mem_guard.verify_record)
    assert g is not None and g.label() == f"GuardTripped:{why}"


def test_m13_guard_missing(tmp_path):
    g = C.guard_verdict(str(tmp_path / "absent.json"), [], mem_guard.verify_record)
    assert g.label() == "GuardTripped:missing"


def test_m13_guard_clean_and_runner_refusal(tmp_path):
    assert C.guard_verdict(guard_record(tmp_path / "g1.json"), [], mem_guard.verify_record) is None
    # the runner's own refusal (exit 1) with a healthy guard is not a trip
    p = guard_record(tmp_path / "g2.json", status="child_failed", child={"exit_code": 1})
    assert C.guard_verdict(p, ["CANDIDATE refused ProgramUndecodable x"], mem_guard.verify_record) is None


# ---------------------------------------------------------------------------
# M13: PreflightMismatch — the compiler's record
# ---------------------------------------------------------------------------

def cache_manifest(tmp, ids):
    p = tmp / "manifest.json"
    p.write_text(json.dumps({"version": "v3", "entries": {i: {} for i in ids}}))
    return str(p)


def cache_log(ids, hits=0, cached=None, extra=()):
    lines = [f"[CACHE] {i}: MISS" for i in ids] + list(extra)
    lines.append(f"[CACHE] Summary: {hits} hits, {len(ids)} misses ({len(ids) if cached is None else cached} modules cached)")
    return "\n".join(lines) + "\n"


def test_m13_compiled_set_clean(tmp_path):
    ids = ["std/io", "src/core/a", "scripts/eval/journal_replay"]
    got, fs, rec = C.compiled_set(cache_log(ids), cache_manifest(tmp_path, ids))
    assert fs == [] and got == sorted(ids) and rec["summary"] == {"hits": 0, "misses": 3, "cached": 3}


@pytest.mark.parametrize("case,log,man,want", [
    ("summary_missing", "[CACHE] std/io: MISS\n", ["std/io"], "compiled_set:summary_missing"),
    ("hits", cache_log(["std/io"], hits=2, cached=3), ["std/io"], "compiled_set:hits"),
    ("skip", cache_log(["std/io"], extra=["[CACHE] std/fs: SKIP (cached 1s ago)"]), ["std/io"],
     "compiled_set:skip_or_hit"),
    ("hit_failed", cache_log(["std/io"], extra=["[CACHE] std/fs: HIT but load failed, recompiling"]), ["std/io"],
     "compiled_set:skip_or_hit"),
    ("manifest_differs", cache_log(["std/io", "std/fs"]), ["std/io"], "compiled_set:manifest_differs"),
    ("manifest_missing", cache_log(["std/io"]), None, "compiled_set:manifest_unreadable"),
], ids=["summary_missing", "hits", "skip", "hit_failed", "manifest_differs", "manifest_missing"])
def test_m13_preflight_compiled_set(tmp_path, case, log, man, want):
    mpath = cache_manifest(tmp_path, man) if man is not None else str(tmp_path / "absent.json")
    _, fs, _ = C.compiled_set(log, mpath)
    assert want in [f["finding"] for f in fs], fs


def test_m13_preflight_warm_cache_dir(tmp_path):
    assert C.cache_dir_state(str(tmp_path / "absent")) is None
    (tmp_path / "empty").mkdir()
    assert C.cache_dir_state(str(tmp_path / "empty")) is None
    (tmp_path / "warm" / "compile").mkdir(parents=True)
    assert C.cache_dir_state(str(tmp_path / "warm"))["finding"] == "warm_cache:cache_not_empty"


# ---------------------------------------------------------------------------
# M13: PreflightMismatch — selection and closure on a synthetic root
# ---------------------------------------------------------------------------

def mini_root(tmp):
    """A tiny project: a root package with module_prefix src, one path package."""
    root = tmp / "tree"
    (root / "src/core").mkdir(parents=True)
    (root / "scripts/eval").mkdir(parents=True)
    (root / "ailang.toml").write_text('[package]\nname = "local/fx"\nversion = "0.1.0"\nmodule_prefix = "src"\n'
                                      '[dependencies]\n"fx/pkg" = { path = "packages/pkg" }\n')
    (root / "src/core/a.ail").write_text("module src/core/a\nimport pkg/fx/pkg/m\nexport pure func a() -> int { 1 }\n")
    (root / "scripts/eval/journal_replay.ail").write_text(
        "module scripts/eval/journal_replay\nimport std/io (println)\nimport std/option (Option)\n"
        "import std/result (Result)\nimport src/core/a (a)\nexport func main() -> () ! {IO} { println(\"x\") }\n")
    pkg = tmp / "run" / "packages" / "fx/pkg"
    (pkg / "src").mkdir(parents=True)
    (pkg / "ailang.toml").write_text('[package]\nname = "fx/pkg"\nversion = "1.0"\n[exports]\nmodules = ["fx/pkg/m"]\n')
    (pkg / "src/m.ail").write_text("module fx/pkg/m\nexport pure func m() -> int { 2 }\n")
    std = tmp / "stdroot"
    std.mkdir()
    for n in ("io", "option", "result"):
        (std / f"{n}.ail").write_text(f"module std/{n}\n")
    lock = {"packages": [{"name": "fx/pkg", "source": "path",
                          "path": os.path.relpath(str(pkg), str(root))}]}
    pins = {"stdlib": {"root": str(std), "files": C.walk_files(str(std))},
            "path_packages": {"fx/pkg": {"files": C.walk_files(str(pkg))}}, "registry_packages": {}}
    env = {"HOME": str(tmp / "home"), "XDG_DATA_HOME": str(tmp / "xdg")}
    (tmp / "xdg" / "ailang").mkdir(parents=True)
    os.symlink(str(std), str(tmp / "xdg" / "ailang" / "std"))
    return root, lock, pins, env, str(tmp / "run" / "packages")


MINI_IDS = ["pkg/fx/pkg/m", "scripts/eval/journal_replay", "src/core/a", "std/io", "std/option", "std/result"]


def mini_ctx(tmp, lock_over=None, pins_over=None):
    root, lock, pins, env, pkg_root = mini_root(tmp)
    if lock_over:
        lock = lock_over(lock)
    if pins_over:
        pins = pins_over(pins)
    ctx = C.LoaderContext(str(root), lock, shutil.which("ailang") or "/nonexistent/bin/ailang", env, pins, pkg_root)
    return root, ctx


def test_m13_selection_clean(tmp_path):
    root, ctx = mini_ctx(tmp_path)
    rows, fs = C.selections(MINI_IDS, ctx, C.walk_files(str(root)))
    assert fs == [], fs
    assert {r["id"]: r["root"] for r in rows} == {
        "pkg/fx/pkg/m": "package:fx/pkg", "scripts/eval/journal_replay": "assembled", "src/core/a": "assembled",
        "std/io": "stdlib", "std/option": "stdlib", "std/result": "stdlib"}
    stmt, prelude_only, injected, cfs = C.import_closure(C.RUNNER_ID, ctx, ailspan.parse)
    assert cfs == [] and prelude_only == set() and injected == {}
    assert C.closure_findings(stmt, prelude_only, MINI_IDS) == []


def test_m13_preflight_module_outside_root(tmp_path):
    root, ctx = mini_ctx(tmp_path)
    assembled = C.walk_files(str(root))
    outside = tmp_path / "elsewhere.ail"
    outside.write_text((root / "src/core/a.ail").read_text())
    os.remove(root / "src/core/a.ail")
    os.symlink(str(outside), str(root / "src/core/a.ail"))
    _, fs = C.selections(MINI_IDS, ctx, assembled)
    assert [f["finding"] for f in fs] == ["selection:module_outside_root:src/core/a"]


def test_m13_preflight_project_file_changed(tmp_path):
    root, ctx = mini_ctx(tmp_path)
    assembled = C.walk_files(str(root))
    (root / "src/core/a.ail").write_text("module src/core/a\n-- changed after assembly\n")
    _, fs = C.selections(MINI_IDS, ctx, assembled)
    assert [f["finding"] for f in fs] == ["selection:project_hash:src/core/a"]


def test_m13_preflight_pkg_outside_pinned_root(tmp_path):
    # the lock's path pointing at the package's original location, not the copy
    elsewhere = tmp_path / "orig" / "pkg"

    def relocate(lock):
        shutil.copytree(str(tmp_path / "run" / "packages" / "fx/pkg"), str(elsewhere))
        lock["packages"][0]["path"] = str(elsewhere)
        return lock

    root, ctx = mini_ctx(tmp_path, lock_over=relocate)
    _, fs = C.selections(MINI_IDS, ctx, C.walk_files(str(root)))
    assert [f["finding"] for f in fs] == ["selection:pkg_outside_pinned_root:pkg/fx/pkg/m"]


def test_m13_preflight_pkg_file_differs(tmp_path):
    root, ctx = mini_ctx(tmp_path)
    (tmp_path / "run/packages/fx/pkg/src/m.ail").write_text("module fx/pkg/m\n-- drift\n")
    _, fs = C.selections(MINI_IDS, ctx, C.walk_files(str(root)))
    assert [f["finding"] for f in fs] == ["selection:pkg_hash:pkg/fx/pkg/m"]


def test_m13_preflight_pkg_unresolved(tmp_path):
    root, ctx = mini_ctx(tmp_path, lock_over=lambda lock: {"packages": []})
    _, fs = C.selections(MINI_IDS, ctx, C.walk_files(str(root)))
    assert [f["finding"] for f in fs] == ["selection:unresolved:pkg/fx/pkg/m"]


def test_m13_preflight_std_shadowed_in_root(tmp_path):
    # <root>/std is the first stdlib search path: a tree carrying std/io.ail wins
    root, ctx = mini_ctx(tmp_path)
    (root / "std").mkdir()
    (root / "std/io.ail").write_text("module std/io\n")
    _, fs = C.selections(MINI_IDS, ctx, C.walk_files(str(root)))
    assert [f["finding"] for f in fs] == ["selection:std_outside_root:std/io"]


def test_m13_preflight_std_hash(tmp_path):
    root, ctx = mini_ctx(tmp_path, pins_over=lambda p: {**p, "stdlib": {**p["stdlib"],
                                                                         "files": {**p["stdlib"]["files"], "io.ail": "0" * 64}}})
    _, fs = C.selections(MINI_IDS, ctx, C.walk_files(str(root)))
    assert [f["finding"] for f in fs] == ["selection:std_hash:std/io"]


def test_m13_preflight_closure_differs(tmp_path):
    root, ctx = mini_ctx(tmp_path)
    stmt, prelude_only, _, _ = C.import_closure(C.RUNNER_ID, ctx, ailspan.parse)
    assert [f["finding"] for f in C.closure_findings(stmt, prelude_only, MINI_IDS + ["src/core/unimported"])] \
        == ["closure:differs"]
    assert [f["finding"] for f in C.closure_findings(stmt, prelude_only, MINI_IDS[1:])] == ["closure:differs"]


def test_m13_closure_prelude_injection_listed(tmp_path):
    root, ctx = mini_ctx(tmp_path)
    (root / "scripts/eval/journal_replay.ail").write_text(
        "module scripts/eval/journal_replay\nimport std/io (println)\nimport src/core/a (a)\n"
        "export func main() -> () ! {IO} { println(\"x\") }\n")
    stmt, prelude_only, injected, _ = C.import_closure(C.RUNNER_ID, ctx, ailspan.parse)
    assert prelude_only == {"std/option", "std/result"}
    assert injected == {"scripts/eval/journal_replay": ["std/option", "std/result"]}
    assert C.closure_findings(stmt, prelude_only, MINI_IDS) == []


def test_m13_prefix_ambiguity_refused(tmp_path):
    root, ctx = mini_ctx(tmp_path)
    ctx.prefix["src"] = ["local/fx", "fx/pkg"]
    (tmp_path / "run/packages/fx/pkg/src/core").mkdir()
    (tmp_path / "run/packages/fx/pkg/src/core/a.ail").write_text("module src/core/a\n")
    (tmp_path / "run/packages/fx/pkg/ailang.toml").write_text('[package]\nname = "fx/pkg"\nversion = "1.0"\n')
    assert "ambiguous" in ctx.select("src/core/a").get("error", "")
    _, fs = C.selections(["src/core/a"], ctx, C.walk_files(str(root)))
    assert [f["finding"] for f in fs] == ["selection:unresolved:src/core/a"] and "ambiguous" in fs[0]["detail"]


# ---------------------------------------------------------------------------
# M13: PreflightMismatch — the effective lock
# ---------------------------------------------------------------------------

def a_lock():
    return json.loads(show(REPO, A, "ailang.lock"))


def test_m13_effective_lock_path_only(tmp_path):
    orig = a_lock()
    eff, rewrites = C.effective_lock(orig, str(tmp_path / "tree"), str(tmp_path / "packages"))
    assert C.lock_rewrite_findings(orig, eff) == []
    assert len(rewrites) == sum(1 for p in orig["packages"] if p["source"] == "path")
    assert all(not os.path.isabs(r["to"]) and r["to"].startswith("../packages/") for r in rewrites)


@pytest.mark.parametrize("mutate,want", [
    (lambda e: e["packages"][2].__setitem__("interface_hash", "sha256:0"), "effective_lock:diff:packages/2/interface_hash"),
    (lambda e: e["packages"][0].__setitem__("path", "/x"), "effective_lock:diff:packages/0/path"),  # registry
    (lambda e: e.__setitem__("generated_at", "now"), "effective_lock:diff:generated_at"),
    (lambda e: e["packages"].pop(), "effective_lock:diff:packages"),
], ids=["interface_hash", "registry_path", "generated_at", "package_removed"])
def test_m13_preflight_effective_lock_other_change(tmp_path, mutate, want):
    orig = a_lock()
    eff, _ = C.effective_lock(orig, str(tmp_path / "tree"), str(tmp_path / "packages"))
    mutate(eff)
    assert [f["finding"] for f in C.lock_rewrite_findings(orig, eff)] == [want]


def test_m13_lock_path_mapping():
    assert C.lock_path_rel("/workspaces/motoko_agent/packages/motoko-ext-abi", LOCK_ROOT) == "packages/motoko-ext-abi"
    assert C.lock_path_rel("/elsewhere/pkg", LOCK_ROOT) is None
    assert C.lock_path_rel("../up", LOCK_ROOT) is None
    assert C.lock_path_rel("packages/x", LOCK_ROOT) == "packages/x"


def test_m13_copy_path_packages_from_a(tmp_path):
    lock = a_lock()
    copied = C.copy_path_packages(REPO, A, lock, LOCK_ROOT, str(tmp_path / "packages"))
    abi = copied["sunholo/motoko_ext_abi"]
    assert abi["a_path"] == "packages/motoko-ext-abi"
    assert abi["files"]["ailang.toml"] == C.sha256_bytes(show(REPO, A, "packages/motoko-ext-abi/ailang.toml"))
    # .packages/motoko_core is not in A's tree: recorded, not copied
    assert copied["sunholo/motoko_core"] == {"a_path": None, "files": {}}
    assert not os.path.exists(tmp_path / "packages" / "sunholo/motoko_core")


# ---------------------------------------------------------------------------
# M13: PreflightMismatch — identities (K0's non-provenance classes)
# ---------------------------------------------------------------------------

def base_identities():
    lock = a_lock()
    ids = {"profile_id": "p", "profile_version": "1", "event_vocabulary_version": "v",
           "profile_rules_version": "r", "coverage_rules_version": "c", "attribution_rules_version": "a",
           "fault_catalogue_version": "f", "extension_packages": [], "normalized_configuration": "{}",
           "toolchain": "AILANG v0.33.0 (full)", "toolchain_sha256": "sha256:bin", "lock_sha256": "sha256:lock",
           "packages": [{"name": p["name"], "source": p.get("source", ""), "path": p.get("path", ""),
                         "version": p.get("version", ""), "interface_hash": p.get("interface_hash", "")}
                        for p in lock["packages"]]}
    pins = {"program_digest": "d", "program_file_sha256": "pf", "t0_settings_sha256": "t0",
            "lock_sha256": "sha256:lock", "toolchain_commit": "full"}
    build = {k: ids[k] for k in C.BUILD_KEYS + ("normalized_configuration",)}
    obs = {"build": build,
           "program": {"digest": "d", "manifest": {"profile_id": "p", "profile_version": "1",
                                                   "event_vocabulary_version": "v",
                                                   "toolchain": "AILANG v0.33.0 (full) binary=sha256:bin"}},
           "toolchain": {"toolchain": "AILANG v0.33.0 (full)", "full": "full", "sha256": "sha256:bin"},
           "lock_a_sha256": "sha256:lock", "lock_c_sha256": "sha256:lock", "t0_sha256": "t0",
           "program_file_sha256": "pf", "lock_a": lock}
    return obs, ids, pins


def test_m13_identities_clean():
    obs, ids, pins = base_identities()
    assert C.k0_identity_findings(obs, ids, pins) == []


def _set(path, value):
    def f(o):
        d = o
        for k in path[:-1]:
            d = d[k]
        d[path[-1]] = value
    return f


@pytest.mark.parametrize("mutate,want", [
    (_set(("program", "manifest", "profile_id"), "other"), "manifest:profile_id"),
    (_set(("program", "manifest", "toolchain"), "AILANG v0.33.0 (full) binary=sha256:other"), "manifest:toolchain"),
    (_set(("build", "profile_version"), "2"), "profile:profile_version"),
    (_set(("build", "extension_packages"), ["x"]), "profile:extension_packages"),
    (_set(("toolchain", "toolchain"), "AILANG v0.34.0 (full)"), "toolchain:version"),
    (_set(("toolchain", "full"), "other"), "toolchain:commit"),
    (_set(("toolchain", "sha256"), "sha256:other"), "binary:sha256"),
    (_set(("program_file_sha256",), "other"), "corpus:program.artifact"),
    (_set(("t0_sha256",), "other"), "t0_settings:file"),
    (_set(("build", "normalized_configuration"), "{\"x\":1}"), "t0_settings:normalized_configuration"),
    (_set(("program", "digest"), "other"), "program:digest"),
    (_set(("lock_a_sha256",), "sha256:other"), "lock:lock_a"),
    (_set(("lock_c_sha256",), "sha256:other"), "lock:lock_c"),
    (lambda o: o["lock_a"]["packages"][3].__setitem__("interface_hash", "sha256:0"), "packages:lock_entries"),
    (_set(("build",), None), "record:k0build_missing"),
    (_set(("program",), None), "record:program_missing"),
], ids=["manifest_profile", "manifest_toolchain", "profile_version", "extension_packages", "toolchain_version",
        "toolchain_commit", "binary", "corpus_program", "t0_file", "t0_configuration", "program_digest",
        "lock_a", "lock_c", "package_entries", "k0build_missing", "program_missing"])
def test_m13_preflight_identity_class(mutate, want):
    obs, ids, pins = base_identities()
    obs = json.loads(json.dumps(obs))
    mutate(obs)
    assert [f["finding"] for f in C.k0_identity_findings(obs, ids, pins)] == [want]


def test_m13_preflight_loader_rules_moved(tmp_path):
    src = tmp_path / "ailang"
    for rel in C.LOADER_SOURCES:
        os.makedirs(src / os.path.dirname(rel), exist_ok=True)
        shutil.copy(os.path.join(C.AILANG_SOURCE, rel), src / rel)
    assert C.loader_rule_findings(str(src)) == []
    with open(src / "internal/loader/stdlib_resolver.go", "a") as f:
        f.write("\n// drift\n")
    assert [f["finding"] for f in C.loader_rule_findings(str(src))] == \
        ["loader_rules:moved:internal/loader/stdlib_resolver.go"]


def test_m13_trace_loader_is_discarded_at_ae36986():
    # the reason the stdlib order is re-derived (the residual gap says so)
    src = open(os.path.join(C.AILANG_SOURCE, "cmd/ailang/main_run_exec.go")).read()
    assert "_ = traceLoader" in src
    assert "-trace-loader" in C.RESIDUAL_GAP or "trace-loader" in C.RESIDUAL_GAP


# ---------------------------------------------------------------------------
# Full runs: the synthetic entry
# ---------------------------------------------------------------------------

def run_opts(clone, entry, parent, cand, record, **over):
    o = dict(repo=clone.root, entry=str(entry), parent=parent, candidate=cand, record=record,
             evaluator=REPO, peak_bytes=4 * 1024 ** 3, peak_source="P1.9a synthetic test",
             run_id=None, guard_lock=str(entry.parent / "heavy.lock"), fixture=FIXTURE, synthetic=True,
             keep_tree=False, ailang="ailang", ailang_source=C.AILANG_SOURCE)
    o.update(over)
    return types.SimpleNamespace(**o)


@pytest.fixture(scope="session")
def entry(work, clone):
    """A synthetic entry: program, T0 settings, identities with A's lock and the pins."""
    e = work / "entry"
    e.mkdir()
    for name in ("snapshot.jsonl", "excerpt.jsonl", "selector.txt", "expectations.json", "expected_end.txt",
                 "witness.json", "census.txt", "envelope.json", "scan_report.tsv", "exposure.jsonl"):
        (e / name).write_text("fx\n")
    (e / "t0_settings.json").write_text('{"fx":"t0"}\n')
    out = work / "collect"
    r = subprocess.run(["bash", os.path.join(HERE, "journal_replay.sh"), "collect", "--fixture", FIXTURE,
                        "--out", str(out)], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout[-500:] + r.stderr[-500:]
    ids = json.loads((out / "identities.json").read_text())
    env = dict(os.environ, EVAL_MODE="synthetic_artifact", EVAL_OUT=str(e / "program.artifact"),
               EVAL_TOOLCHAIN=f"{ids['toolchain']} binary={ids['toolchain_sha256']}")
    r = subprocess.run(["ailang", "run", "--caps", C.CAPS, "--ai-stub", "--entry", "main", C.RUNNER_ENTRY],
                       cwd=REPO, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    assert r.returncode == 0, r.stdout[-500:] + r.stderr[-500:]
    lock_bytes = show(REPO, A, "ailang.lock")
    lock = json.loads(lock_bytes)
    # the entry as an admission at A records it: A's lock, not this checkout's
    ids["lock_sha256"] = "sha256:" + C.sha256_bytes(lock_bytes)
    ids["packages"] = [{"name": p["name"], "source": p.get("source", ""), "path": p.get("path", ""),
                        "version": p.get("version", ""), "interface_hash": p.get("interface_hash", "")}
                       for p in lock["packages"]]
    ids["execution_pins"] = C.make_pins(clone.root, A, LOCK_ROOT, str(e), MANIFEST, shutil.which("ailang"),
                                        dict(os.environ))
    (e / "identities.json").write_text(json.dumps(ids, indent=1) + "\n")
    return e


def test_m13_pins_shape(entry):
    pins = json.loads((entry / "identities.json").read_text())["execution_pins"]
    assert pins["schema"] == C.PINS_SCHEMA and pins["admission_commit"] == A
    assert pins["path_packages"]["sunholo/motoko_core"]["a_path"] is None
    assert pins["path_packages"]["sunholo/motoko_ext_abi"]["tree"]
    assert pins["stdlib"]["files"] and pins["loader_sources"] == C.LOADER_SOURCES
    assert pins["program_digest"] and pins["toolchain_commit"] == C.AILANG_COMMIT


def test_m13_run_refused_before_assembly(clone, entry, work):
    cand = clone.commit(clone.head, {"src/core/prompts.ail": b"-- fx\n"})
    rec = record_for(work / "rec-run-path.json", clone.head, cand)
    code, lines, record = C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="refused-path"))
    assert code == 1 and record["verdict"]["reason"] == "InadmissibleCandidate"
    assert any(l.startswith("ENVELOPE residual_gap=") for l in lines)
    run_dir = entry / "runs" / "refused-path"
    assert not (run_dir / "tree").exists() and not (run_dir / "cache").exists()
    assert "refused-path" not in git(clone.root, "worktree", "list")


def test_m13_run_guard_refusal_is_guard_tripped(clone, entry, work, monkeypatch, tmp_path):
    # a fake cgroup at the handoff threshold: the guard refuses to start the run
    cg = tmp_path / "cgroup"
    cg.mkdir()
    (cg / "memory.max").write_text(str(24 * 1024 ** 3) + "\n")
    (cg / "memory.current").write_text(str(13 * 1024 ** 3) + "\n")
    monkeypatch.setenv("EVAL_CGROUP_ROOT", str(cg))
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    rec = record_for(work / "rec-run-guard.json", clone.head, cand)
    code, lines, record = C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="guard-refused"))
    assert code == 1 and record["verdict"]["reason"] == "GuardTripped", record["verdict"]
    assert record["verdict"]["finding"] == "monitor_not_started"  # verify_record's first failing rule
    with open(entry / "runs/guard-refused/guard.json") as f:
        assert json.load(f)["status"] == "refused"
    assert not (entry / "runs/guard-refused/tree").exists()
    assert "guard-refused" not in git(clone.root, "worktree", "list")


def test_m13_run_dev_evaluator_refused_for_real_entry(clone, entry, work):
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    rec = record_for(work / "rec-run-dev.json", clone.head, cand)
    code, _, record = C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="dev-real", synthetic=False))
    assert code == 1 and record["verdict"]["finding"] == "e_unpinned:dev_generator"


def test_m13_run_directory_must_not_exist(clone, entry, work):
    (entry / "runs" / "taken").mkdir(parents=True)
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    rec = record_for(work / "rec-run-taken.json", clone.head, cand)
    with pytest.raises(C.EvalError):
        C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="taken"))


def fake_ailang(tmp, body):
    """A stand-in `ailang` for run() paths that need no compile."""
    p = tmp / "ailang"
    p.write_text("#!/usr/bin/env bash\nif [ \"$1\" = --version ]; then echo 'AILANG v0.0.0-fake'; "
                 "echo 'Full:   fake'; exit 0; fi\n" + body)
    p.chmod(0o755)
    return str(p)


def test_m13_run_corpus_and_tree_changed_during_run(clone, entry, work, tmp_path):
    body = ("echo 'K0BUILD {}'; echo 'PROGRAM {}'; echo 'CANDIDATE loaded'\n"
            f"echo tamper >> {entry}/witness.json\n"
            "echo x > src/core/tamper.ail\nexit 0\n")
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    rec = record_for(work / "rec-run-tamper.json", clone.head, cand)
    try:
        code, _, record = C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="tamper",
                                         ailang=fake_ailang(tmp_path, body)))
    finally:
        (entry / "witness.json").write_text("fx\n")
    found = [f["finding"] for f in record["k0"]]
    assert code == 1 and record["verdict"]["reason"] == "PreflightMismatch"
    for want in ("corpus:changed_during_run", "tree:changed_during_run", "binary:sha256",
                 "toolchain:version", "compiled_set:summary_missing"):
        assert want in found, (want, found)


def test_m13_run_program_undecodable_from_runner(clone, entry, work, tmp_path):
    body = "echo 'CANDIDATE refused ProgramUndecodable ProgramStructurallyInvalid(artifact-digest-mismatch)'\nexit 1\n"
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    rec = record_for(work / "rec-run-undec.json", clone.head, cand)
    code, _, record = C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="undecodable-fake",
                                     ailang=fake_ailang(tmp_path, body)))
    assert code == 1
    assert record["verdict"]["reason"] == "ProgramUndecodable"
    assert record["verdict"]["finding"] == "ProgramStructurallyInvalid(artifact-digest-mismatch)"


# ---------------------------------------------------------------------------
# Live: a real assembly and compile
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def near_miss_run(clone, entry, work):
    """M15 digest-function-only (PERMITTED_EDIT), assembled and compiled; the M13 live tests reuse it."""
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    rec = record_for(work / "rec-live.json", clone.head, cand)
    code, lines, record = C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="live-near-miss",
                                         keep_tree=True))
    yield code, lines, record, entry / "runs" / "live-near-miss"
    git(clone.root, "worktree", "remove", "--force", str(entry / "runs/live-near-miss/tree"))


@pytest.fixture(scope="session")
def sent_message_run(clone, entry, work):
    """M15 InadmissibleCandidate(path): the sent-message edit, assembled and compiled."""
    cand = clone.commit(clone.head, SENT_MESSAGE_EDIT)
    rec = record_for(work / "rec-live-sent.json", clone.head, cand)
    code, lines, record = C.run(run_opts(clone, entry, clone.head, cand, rec, run_id="live-sent-message"))
    return code, lines, record


def assert_k0_passes(code, lines, record):
    assert record.get("k0") == [], record.get("k0")
    assert code == 0 and record["verdict"]["status"] == "preflight-passed"
    assert record["steps"] == ["path", "intent", "evaluator", "protected"]
    assert any(l.startswith("ENVELOPE residual_gap=") for l in lines)


@live
def test_m15_inadmissible_path_k0_passes(sent_message_run):
    assert_k0_passes(*sent_message_run)


@live
def test_m15_digest_function_only_k0_passes(near_miss_run):
    code, lines, record, run_dir = near_miss_run
    assert_k0_passes(code, lines, record)


@live
def test_m13_live_provenance_record(near_miss_run):
    code, _, record, run_dir = near_miss_run
    ex = record["execution"]
    assert ex["compiled"]["summary"]["hits"] == 0
    assert ex["compiled"]["summary"]["misses"] == len(ex["compiled_ids"]) == ex["compiled"]["manifest_entries"]
    assert C.RUNNER_ID in ex["compiled_ids"]
    roots = {r["root"] for r in ex["selected"]}
    assert "assembled" in roots and "stdlib" in roots and any(x.startswith("package:") for x in roots)
    assert all(r["sha256"] for r in ex["selected"] if r["root"] != "embedded")
    assert ex["loader_trace"].startswith("absent")
    assert ex["closure_size"] + len(ex["prelude_only"]) == len(ex["compiled_ids"])
    asm = record["assembly"]
    assert asm["compat_patch"] is None and asm["evaluator"].endswith("-dev")
    assert asm["effective_lock_sha256"] != asm["original_lock_sha256"]
    assert all(r["to"].startswith("../packages/") for r in asm["lock_rewrites"])
    assert not (run_dir / "cache/compile/modules").exists()
    # the corpus rule inside the run directory
    for d, dirs, files in os.walk(run_dir):
        if "/tree" in d:
            continue
        assert os.stat(d).st_mode & 0o077 == 0, d
        for f in files:
            assert os.stat(os.path.join(d, f)).st_mode & 0o077 == 0, f


@live
def test_m13_live_warm_cache_is_refused(near_miss_run, tmp_path):
    """A warm cache, for real: compile the kept tree twice on one cache."""
    code, _, record, run_dir = near_miss_run
    tree = run_dir / "tree"
    cache = tmp_path / "cache"
    env = {k: v for k, v in os.environ.items() if k not in ("AILANG_NO_CACHE", "AILANG_STDLIB_PATH")}
    env.update(AILANG_CACHE_DIR=str(cache), EVAL_MODE="candidate",
               EVAL_PROGRAM=str(run_dir.parent.parent / "program.artifact"))
    cmd = ["ailang", "run", "-debug-compile", "--caps", C.CAPS, "--ai-stub", "--entry", "main", C.RUNNER_ENTRY]
    first = subprocess.run(cmd, cwd=tree, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    assert first.returncode == 0, first.stdout[-300:]
    assert C.cache_dir_state(str(cache))["finding"] == "warm_cache:cache_not_empty"
    second = subprocess.run(cmd, cwd=tree, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    _, fs, _ = C.compiled_set(second.stderr, str(cache / "compile" / "manifest.json"))
    found = [f["finding"] for f in fs]
    assert "compiled_set:hits" in found and "compiled_set:skip_or_hit" in found, found


@live
def test_m13_live_module_outside_root(near_miss_run, tmp_path):
    code, _, record, run_dir = near_miss_run
    tree = run_dir / "tree"
    ids = json.loads((run_dir.parent.parent / "identities.json").read_text())
    eff = json.loads((tree / "ailang.lock").read_text())
    assembled = C.walk_files(str(tree), skip=(".git",))
    ctx = C.LoaderContext(str(tree), eff, shutil.which("ailang"), dict(os.environ), ids["execution_pins"],
                          str(run_dir / "packages"))
    rows, fs = C.selections(record["execution"]["compiled_ids"], ctx, assembled)
    assert fs == []
    target = tree / "src/core/phase_vocab.ail"
    outside = tmp_path / "phase_vocab.ail"
    shutil.copy(target, outside)
    target.chmod(0o600)
    os.rename(target, tmp_path / "phase_vocab.orig")
    os.symlink(str(outside), str(target))
    try:
        _, fs = C.selections(record["execution"]["compiled_ids"], ctx, assembled)
        assert [f["finding"] for f in fs] == ["selection:module_outside_root:src/core/phase_vocab"]
        # and the A lock (paths outside every assembly) instead of the effective one
        ctx_a = C.LoaderContext(str(tree), a_lock(), shutil.which("ailang"), dict(os.environ),
                                ids["execution_pins"], str(run_dir / "packages"))
        _, fs_a = C.selections(record["execution"]["compiled_ids"], ctx_a, assembled)
        assert fs_a and all(f["finding"].startswith("selection:pkg_outside_pinned_root:pkg/")
                            or f["finding"] == "selection:module_outside_root:src/core/phase_vocab"
                            for f in fs_a), fs_a
    finally:
        os.remove(target)
        os.rename(tmp_path / "phase_vocab.orig", target)


@live
def test_m13_live_program_undecodable(clone, entry, work):
    """A tampered program artifact, loaded inside the assembled run."""
    bad = work / "entry-bad"
    shutil.copytree(entry, bad, ignore=shutil.ignore_patterns("runs"))
    art = (bad / "program.artifact").read_bytes()
    (bad / "program.artifact").write_bytes(art.replace(b"journal_admission", b"journal_admissioN", 1))
    cand = clone.commit(clone.head, PERMITTED_EDIT)
    rec = record_for(work / "rec-live-bad.json", clone.head, cand)
    code, lines, record = C.run(run_opts(clone, bad, clone.head, cand, rec, run_id="live-undecodable"))
    assert code == 1
    assert record["verdict"]["reason"] == "ProgramUndecodable", record["verdict"]
    assert record["verdict"]["finding"] == "ProgramStructurallyInvalid(artifact-digest-mismatch)"
    assert "live-undecodable" not in git(clone.root, "worktree", "list")
