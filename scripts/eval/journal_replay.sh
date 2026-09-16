#!/usr/bin/env bash
#
# ADR-004 D2/D3, PLAN-004 §3 P1.6: the evaluator's shell driver — identity
# collection, then the runner (`journal_replay.ail`).
#
# Usage:
#   journal_replay.sh admit --fixture <world fixture> [--at <A>] [--out <dir>] [--e-record <file>]
#   journal_replay.sh admit --entry <path>            [--at <A>] [--out <dir>] [--e-record <file>]
#   journal_replay.sh collect (--fixture <name> | --entry <path>) [--at <A>] [--out <dir>] [--e-record <file>]
#
# `--at` is the assembled tree A (default: this checkout). `--out` receives
# identities.json, comparators.json, the run's wire, identities.after.json and
# summary.txt (default: a fresh temporary directory, printed). `--e-record` is
# E's pinned record from P1G ({toolchain, toolchain_sha256, generator_version,
# packages, lock_sha256}); before P1G there is none, and a REAL entry
# (`--entry`) is then refused at preflight without its content being read.
#
# PROVENANCE: COLLECTED, THEN CHECKED AGAINST A DIFFERENT SOURCE (the table in
# PLAN-004 §3 P1.6; A9b in `src/eval/journal/admission.ail`).
#
#   identities.json — what is checked, collected BEFORE the run:
#     source_revision, scan_root_commit   git -C A rev-parse HEAD
#     tracked_changes                     git -C A status --porcelain --untracked-files=no
#                                         (outside .motoko/eval-corpus/)
#     toolchain, toolchain_sha256         ailang --version; sha256sum of the resolved binary
#     abi_version                         `version` in packages/motoko-ext-abi/ailang.toml
#     classifier_2_set, unrouted_fields   python3 tools/ext_call_inventory/derive.py --json at A
#     scan_roots                          derive.py's `--roots` default at A (read from its argparse)
#     packages, lock_sha256               every ailang.lock entry (name, source, path, version,
#                                         interface_hash) and the lock's SHA-256
#     normalized_configuration, profile/rule/vocabulary versions, extension_packages
#                                         the runner's `identities` mode: the reader's
#                                         RecordedConfig ++ T0Settings and the build's functions
#     generator_version                   git -C ../motoko_agent-eval rev-parse HEAD when E exists;
#                                         before P1G `<HEAD>-dev`
#
#   comparators.json — the independent side:
#     revision_is_commit                  git cat-file -e <rev>^{commit}
#     assembled_tree, revision_tree       the tree hash COMPUTED FROM A's FILES (tracked and
#                                         untracked-not-ignored, git's tree format re-implemented
#                                         here, no object written) vs git rev-parse <rev>^{tree}
#     lock_abi_version                    `sunholo/motoko_ext_abi`'s version in ailang.lock
#     pinned_classifier_2_set / pinned_unrouted_fields
#                                         the reviewed pinned record: the literals in
#                                         scripts/dst/profile_definition_dst.ail (NOT a second
#                                         extractor; `make profile_definition` enforces agreement)
#     leaf_files                          SCAN_FILES in tools/driver_leaf_inventory/derive.py
#     rederived_configuration             gen_fixtures.py's config reader (synthetic entries)
#     e_pin                               --e-record, or null
#   The runner adds, in-process: the profile's scan_roots (driver_only()) and the
#   registry the run used (empty).
#
# After the run the identities are collected again; any change is a
# temporal finding here, and A9b runs again over the second collection.
#
# The run's stdout is the wire: WORLD_RUN_BEGIN/END and the world_request
# lines are checked by scripts/dst/run_world_framed_wire.sh --wire (one frame).
#
# Exit: 0 admitted-as-checked (A5, A6, A9, A9b; A1–A4, A7, A8 are P1.7a/P1.7b's);
# 1 refused or a finding; 2 usage or a collection failure.
#
# Synthetic only at P1.6 (§0.6): the files written here carry identities,
# digests and counts; the runner reads no corpus content.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CAPS="IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand"

usage() { sed -n '5,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

mode="${1:-}"; [ -n "$mode" ] || usage; shift
fixture=""; entry=""; at="$REPO"; out=""; e_record=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fixture) fixture="${2:-}"; shift 2 ;;
    --entry) entry="${2:-}"; shift 2 ;;
    --at) at="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    --e-record) e_record="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done
case "$mode" in admit|collect) ;; *) usage ;; esac
if [ -n "$fixture" ] && [ -n "$entry" ]; then echo "journal_replay: --fixture and --entry are exclusive" >&2; exit 2; fi
if [ -z "$fixture" ] && [ -z "$entry" ]; then usage; fi
at="$(cd "$at" && pwd)"
if [ -z "$out" ]; then out="$(mktemp -d)"; fi
mkdir -p "$out"
if [ -n "$e_record" ] && [ ! -f "$e_record" ]; then echo "journal_replay: no E record at $e_record" >&2; exit 2; fi

runner() {
  ( cd "$at" && env "$@" ailang run --caps "$CAPS" --ai-stub --entry main scripts/eval/journal_replay.ail < /dev/null )
}

# collect_identities FILE — every field of identities.json.
collect_identities() {
  local file="$1" rev tracked tool_version tool_bin tool_sha abi derive build gen

  rev="$(git -C "$at" rev-parse HEAD)"
  tracked="$(git -C "$at" status --porcelain --untracked-files=no | cut -c4- | grep -v '^\.motoko/eval-corpus/' || true)"
  tool_version="$(ailang --version | awk '/^AILANG /{v=$0} /^Full:/{f=$2} END{print v " (" f ")"}')"
  tool_bin="$(readlink -f "$(command -v ailang)")"
  tool_sha="sha256:$(sha256sum "$tool_bin" | cut -d' ' -f1)"
  abi="$(awk -F'"' '/^\[package\]/{p=1} p && /^version *=/{print $2; exit}' "$at/packages/motoko-ext-abi/ailang.toml")"
  derive="$(cd "$at" && python3 tools/ext_call_inventory/derive.py --json)"
  if [ -n "$entry" ]; then
    build="$(runner EVAL_MODE=identities EVAL_ENTRY="$entry" | sed -n 's/^IDENTITIES //p')"
  else
    build="$(runner EVAL_MODE=identities EVAL_FIXTURE="$fixture" | sed -n 's/^IDENTITIES //p')"
  fi
  [ -n "$build" ] || { echo "journal_replay: the runner printed no IDENTITIES line" >&2; return 1; }
  if [ -d "$at/../motoko_agent-eval" ] && git -C "$at/../motoko_agent-eval" rev-parse HEAD >/dev/null 2>&1; then
    gen="$(git -C "$at/../motoko_agent-eval" rev-parse HEAD)"
  else
    gen="${rev}-dev"
  fi

  REV="$rev" TRACKED="$tracked" TOOL="$tool_version" TOOL_SHA="$tool_sha" ABI="$abi" \
  DERIVE="$derive" BUILD="$build" GEN="$gen" AT="$at" python3 - "$file" <<'PY'
import ast, hashlib, json, os, re, sys
at = os.environ["AT"]
derive = json.loads(os.environ["DERIVE"])
build = json.loads(os.environ["BUILD"])
src = open(os.path.join(at, "tools/ext_call_inventory/derive.py"), encoding="utf-8").read()
# derive.py's `--roots` default, read from its argparse call (not from its output)
roots = None
for node in ast.walk(ast.parse(src)):
    if isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "add_argument" \
            and node.args and isinstance(node.args[0], ast.Constant) and node.args[0].value == "--roots":
        for kw in node.keywords:
            if kw.arg == "default":
                roots = kw.value.value.split(",")
if roots is None:
    sys.exit("journal_replay: derive.py has no --roots default")
lock_path = os.path.join(at, "ailang.lock")
lock_bytes = open(lock_path, "rb").read()
lock = json.loads(lock_bytes)
packages = [{"name": p["name"], "source": p.get("source", ""), "path": p.get("path", ""),
             "version": p.get("version", ""), "interface_hash": p.get("interface_hash", "")}
            for p in lock["packages"]]
ids = {
    "source_revision": os.environ["REV"],
    "scan_root_commit": os.environ["REV"],
    "tracked_changes": [t for t in os.environ["TRACKED"].split("\n") if t],
    "toolchain": os.environ["TOOL"],
    "toolchain_sha256": os.environ["TOOL_SHA"],
    "abi_version": os.environ["ABI"],
    "classifier_2_set": derive["classifier_2_set"],
    "unrouted_fields": derive["unrouted_fields"],
    "scan_roots": roots,
    "packages": packages,
    "lock_sha256": "sha256:" + hashlib.sha256(lock_bytes).hexdigest(),
    "generator_version": os.environ["GEN"],
}
for k in ("normalized_configuration", "profile_id", "profile_version", "event_vocabulary_version",
          "profile_rules_version", "coverage_rules_version", "attribution_rules_version",
          "fault_catalogue_version", "extension_packages"):
    ids[k] = build[k]
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(ids, f, indent=1, sort_keys=True, ensure_ascii=False)
    f.write("\n")
PY
}

# collect_comparators FILE — the independent side.
collect_comparators() {
  local file="$1" rev is_commit rev_tree rederived=""
  rev="$(git -C "$at" rev-parse HEAD)"
  if git -C "$at" cat-file -e "${rev}^{commit}" 2>/dev/null; then is_commit=true; else is_commit=false; fi
  rev_tree="$(git -C "$at" rev-parse "${rev}^{tree}")"
  if [ -n "$fixture" ]; then
    rederived="$(cd "$at" && python3 src/eval/journal/testdata/gen_fixtures.py --normalized-configuration "$fixture")"
  fi
  IS_COMMIT="$is_commit" REV_TREE="$rev_tree" REDERIVED="$rederived" AT="$at" E_RECORD="$e_record" \
  python3 - "$file" <<'PY'
import ast, hashlib, json, os, re, subprocess, sys
at = os.environ["AT"]

def git(*args):
    return subprocess.run(["git", "-C", at, *args], check=True, capture_output=True).stdout

# The assembled tree's hash, from the files: git's blob and tree object format
# re-implemented; nothing is written to the object store.
def blob_sha(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).digest()

staged = {}
for rec in git("ls-files", "-s", "-z").split(b"\0"):
    if rec:
        meta, path = rec.split(b"\t", 1)
        mode, sha, _stage = meta.split(b" ")
        staged[path] = (mode, sha)
untracked = [p for p in git("ls-files", "-z", "--others", "--exclude-standard").split(b"\0") if p]
entries = {}
for path in list(staged) + untracked:
    full = os.path.join(at.encode(), path)
    mode_sha = staged.get(path)
    if mode_sha and mode_sha[0] == b"160000":
        entries[path] = (b"160000", bytes.fromhex(mode_sha[1].decode()))
        continue
    if os.path.islink(full):
        entries[path] = (b"120000", blob_sha(os.readlink(full)))
    elif os.path.isfile(full):
        with open(full, "rb") as f:
            data = f.read()
        mode = b"100755" if os.stat(full).st_mode & 0o111 else b"100644"
        entries[path] = (mode, blob_sha(data))
    # a deleted tracked file is absent from the assembled tree

def tree_sha(items):
    # items: {relative path bytes: (mode, sha)}
    children, files = {}, {}
    for p, v in items.items():
        if b"/" in p:
            d, rest = p.split(b"/", 1)
            children.setdefault(d, {})[rest] = v
        else:
            files[p] = v
    rows = [(name, mode, sha) for name, (mode, sha) in files.items()]
    rows += [(name, b"40000", tree_sha(sub)) for name, sub in children.items()]
    rows.sort(key=lambda r: r[0] + (b"/" if r[1] == b"40000" else b""))
    body = b"".join(mode + b" " + name + b"\0" + sha for name, mode, sha in rows)
    return hashlib.sha1(b"tree %d\0" % len(body) + body).digest()

assembled = tree_sha(entries).hex()

lock = json.load(open(os.path.join(at, "ailang.lock"), encoding="utf-8"))
abi = [p.get("version", "") for p in lock["packages"] if p["name"] == "sunholo/motoko_ext_abi"]

fixture_src = open(os.path.join(at, "scripts/dst/profile_definition_dst.ail"), encoding="utf-8").read()
def literal_list(field):
    m = re.search(re.escape(field) + r":\s*\[(.*?)\]", fixture_src, re.S)
    if not m:
        sys.exit(f"journal_replay: '{field}' is not in profile_definition_dst.ail")
    return re.findall(r'"([^"]*)"', m.group(1))

leaf_src = open(os.path.join(at, "tools/driver_leaf_inventory/derive.py"), encoding="utf-8").read()
leaves = None
for node in ast.parse(leaf_src).body:
    if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "SCAN_FILES" for t in node.targets):
        leaves = ast.literal_eval(node.value)
if leaves is None:
    sys.exit("journal_replay: SCAN_FILES is not in driver_leaf_inventory/derive.py")

pin = None
if os.environ["E_RECORD"]:
    pin = json.load(open(os.environ["E_RECORD"], encoding="utf-8"))

cmp = {
    "revision_is_commit": os.environ["IS_COMMIT"] == "true",
    "assembled_tree": assembled,
    "revision_tree": os.environ["REV_TREE"],
    "lock_abi_version": abi[0] if abi else "",
    "pinned_classifier_2_set": literal_list("classifier_2_set"),
    "pinned_unrouted_fields": literal_list("unrouted_fields"),
    "leaf_files": leaves,
    "rederived_configuration": os.environ["REDERIVED"],
    "e_pin": pin,
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(cmp, f, indent=1, sort_keys=True, ensure_ascii=False)
    f.write("\n")
PY
}

echo "=== journal_replay ${mode} (${fixture:+fixture $fixture}${entry:+real entry}) at ${at} ==="
echo "  out: ${out}"

collect_identities "$out/identities.json" || { echo "journal_replay: identity collection failed" >&2; exit 2; }
collect_comparators "$out/comparators.json" || { echo "journal_replay: comparator collection failed" >&2; exit 2; }
echo "  collected identities.json and comparators.json before the run"
[ "$mode" = collect ] && exit 0

kind_env=(EVAL_FIXTURE="$fixture")
[ -n "$entry" ] && kind_env=(EVAL_ENTRY="$entry")

set +e
runner EVAL_MODE=admit "${kind_env[@]}" EVAL_IDENTITIES="$out/identities.json" \
  EVAL_COMPARATORS="$out/comparators.json" EVAL_WORKDIR="$(mktemp -d)" > "$out/wire.txt" 2>&1
rc=$?
set -e
grep -E '^(FINDING|ADMISSION|WORLD_RUN_)' "$out/wire.txt" | sed 's/^/  /' || true

fail=0
[ "$rc" -eq 0 ] || fail=1
ran=false
grep -q '^ADMISSION .* ran=true' "$out/wire.txt" && ran=true

if [ "$ran" = true ]; then
  if bash "$REPO/scripts/dst/run_world_framed_wire.sh" --wire "$out/wire.txt" 1 > "$out/frames.txt" 2>&1; then
    echo "  ✓ wire frames (run_world_framed_wire.sh --wire, 1 frame)"
  else
    echo "  ✗ wire frames:"; sed 's/^/    /' "$out/frames.txt"; fail=1
  fi
fi

# Again after the run: a changed identity is a temporal finding; A9b re-runs.
collect_identities "$out/identities.after.json" || { echo "journal_replay: identity re-collection failed" >&2; exit 2; }
if cmp -s "$out/identities.json" "$out/identities.after.json"; then
  echo "  ✓ identities unchanged across the run"
else
  echo "  ✗ FINDING A9b:IdentitiesChangedDuringRun@aggregate:provenance"
  diff "$out/identities.json" "$out/identities.after.json" | sed 's/^/    /' | head -20
  fail=1
fi
set +e
runner EVAL_MODE=a9b "${kind_env[@]}" EVAL_IDENTITIES="$out/identities.after.json" \
  EVAL_COMPARATORS="$out/comparators.json" > "$out/a9b.after.txt" 2>&1
a9b_rc=$?
set -e
grep -E '^(FINDING|A9B)' "$out/a9b.after.txt" | sed 's/^/  /' || true
[ "$a9b_rc" -eq 0 ] || fail=1

{
  echo "mode=${mode} kind=${entry:+real}${fixture:+synthetic} fixture=${fixture} at=${at}"
  echo "runner_exit=${rc} ran=${ran} a9b_after_exit=${a9b_rc}"
  grep -E '^ADMISSION' "$out/wire.txt" || true
} > "$out/summary.txt"

if [ "$fail" -eq 0 ]; then
  echo "journal_replay ${mode}: CHECKED (A5, A6, A9, A9b; A1–A4, A7, A8 not yet landed)"
  exit 0
fi
echo "journal_replay ${mode}: REFUSED"
exit 1
