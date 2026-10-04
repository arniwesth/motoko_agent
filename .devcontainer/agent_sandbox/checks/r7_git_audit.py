#!/usr/bin/env python3
"""R7 f-1..f-4 — the git-configuration and frozen-content audit.

Adapted from an audit written for another project's confined-agent profile. What changed for motoko
is the root, the frozen-content set and this docstring — the clauses themselves are unchanged, and were
re-validated against this tree on 2026-08-22 (6 configuration files, 527 branch.* entries, 0 violations).

WHY THIS EXISTS AS CODE, and why it is the check that matters most here. Confining a container does not
confine the tree. `/workspaces/motoko_agent` is ONE host directory shared with the operator's container, so
every host-side git command the operator runs consults AGENT-WRITABLE git configuration, and the
exec-or-credential family in those files — [alias] x = !cmd, core.hooksPath, include.path / includeIf,
remote.<n>.url = ext::<cmd>, branch.<n>.remote (which accepts a URL, not only a remote name), core.pager,
diff.external, filter.*.clean/smudge, gpg.program, credential.helper — executes as the OPERATOR, on the
HOST: outside no-new-privileges, outside the :ro binds, outside the container. credential.helper is the
worst member because it defeats not just revocation but ROTATION; a fresh token is captured on first use.

Nothing in the container profile addresses that channel. This does.

The expectation is a TYPED one rather than a snapshot, because literal whole-file equality is not assertable:
.git/config alone carries 517 entries here, 506 of them branch.*, which churn with ordinary work.

Two modes:

    r7_git_audit.py --root "$PWD" --record ~/r7-baseline.json     # on a SANITISED tree — read the warning
    r7_git_audit.py --root "$PWD" --verify ~/r7-baseline.json

RECORD ONLY AFTER SANITISING. A baseline taken over a planted directive approves it for ever. Read the
recorded summary before trusting the file, and re-record (noting why, in the change) after an approved edit
under .devcontainer/**, .vscode/**, .claude/**, .mcp.json, AGENTS.md or .agent/tools/**. Do NOT loosen a
clause because it fails — a clause that false-fails on approved content is how an audit becomes a snapshot.

What --verify asserts, per gitdir found by walking the tree:

  f-1 (1) non-branch entries match the baseline as a MULTISET. Multiset, not set: git takes the last
          occurrence of a single-valued key, so a duplicate is a live override, not noise.
      (2) every branch.* key ends in one of five measured suffixes, and its value matches that suffix's
          measured SHAPE. This is the clause that must never be loosened: branch.<n>.remote accepts a URL,
          which is how a branch entry becomes an exec-or-credential directive.
      (3) no include/includeIf section exists at all -- matched on section+key, never by text search,
          because an approved branch name can contain the word "include".
      (4) no value outside a *.url key contains '!', 'ext::' or '://'.
  f-2   every gitdir's hooks/ directory contains only the files the baseline attested. Motoko's tree has
        three real ones: deepseek-harness/.git/hooks/{pre-commit,pre-merge-commit,pre-push}, installed by
        lefthook (measured 2026-08-22). They are approved by being recorded; a CHANGE to them is a finding.
  f-3   .vscode/** content is unchanged (sha256 per file).
  f-4   .devcontainer/**, .gitmodules, and the harness-executed configuration are unchanged. The last group
        is motoko's replacement for the source record's .omp/lsp.json: the locations that decide which
        programs the harness runs, or that carry security state — .mcp.json (which MCP servers are
        launched), .claude/** (skills the harness loads, and the permission allowlist), AGENTS.md (loaded
        into every session), and .agent/tools/** (scripts the pipeline executes).

Exit status: 0 = every assertion held; 1 = at least one failed; 2 = usage/IO error.
No configuration VALUE is printed for a key whose name suggests a credential, and no token-shaped string is
ever echoed: findings name the key and the gitdir, not the secret.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

# --- measured expectations -------------------------------------------------------------------------------
# Shapes validated against every branch.* entry in the tree on 2026-08-17 (361 remote, 361 merge,
# 348 vscode-merge-base, 546 github-pr-owner-number, 225 github-pr-base-branch; zero violations).
BRANCH_SHAPES = {
    "remote": re.compile(r"^[A-Za-z0-9._-]+$"),                    # a remote NAME, never a URL
    "merge": re.compile(r"^refs/heads/.+$"),
    "vscode-merge-base": re.compile(r"^[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+$"),   # a remote-tracking ref, not an OID
    "github-pr-owner-number": re.compile(r"^[^#\s]+#[^#\s]+#[0-9]+$"),        # owner#repo#number
    "github-pr-base-branch": re.compile(r"^[^#\s]+#[^#\s]+#\S+$"),
}
FORBIDDEN_SECTIONS = ("include", "includeif")
EXEC_MARKERS = ("!", "ext::", "://")
SECRETISH = re.compile(r"(helper|token|password|secret|key)", re.I)
CONTENT_SETS = {
    "f-3 .vscode": [".vscode"],
    "f-4 .devcontainer": [".devcontainer"],
    # Absent from this tree today (the nested repositories are plain clones, not submodules). Kept in the
    # set on purpose: it is git-config-shaped, agent-writable, outside the :ro binds, and is what
    # `git submodule sync` copies into a gitdir's config — so if one appears, f-4 reports it as a NEW file
    # rather than silently accepting it.
    "f-4 .gitmodules": [".gitmodules"],
    # The harness-executed configuration — motoko's counterpart to the source record's .omp/lsp.json. The
    # test for membership is "does something read this and then run a program, or does it carry security
    # state", not "is it a config file": .mcp.json launches MCP servers, .claude/skills/** is loaded into
    # sessions as instructions, .claude/settings.local.json is the permission allowlist, AGENTS.md is loaded
    # into every session, and .agent/tools/** is executed by the pipeline.
    #
    # NOT included, deliberately: the rest of .agent/**. Plans, research, ADRs, handoffs and summaries are
    # prose that nothing executes, they change constantly, and a noisy audit is an ignored audit.
    "f-4 harness config": [".mcp.json", "AGENTS.md", ".claude", ".agent/tools"],
}


def find_config_files(root):
    """Every git configuration file git could read under root, keyed by a stable relative label."""
    found = {}
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        if ".git" in dirnames:
            gitdir = os.path.join(dirpath, ".git")
            for name in ("config", "config.worktree"):
                path = os.path.join(gitdir, name)
                if os.path.isfile(path):
                    found[os.path.relpath(path, root)] = path
            worktrees = os.path.join(gitdir, "worktrees")
            if os.path.isdir(worktrees):
                for wt in sorted(os.listdir(worktrees)):
                    path = os.path.join(worktrees, wt, "config.worktree")
                    if os.path.isfile(path):
                        found[os.path.relpath(path, root)] = path
        # submodule gitdirs live under <root>/.git/modules/**; os.walk reaches them because .git is a dir
        if os.path.basename(dirpath).startswith("modules") or "/modules/" in dirpath:
            path = os.path.join(dirpath, "config")
            if os.path.isfile(path):
                found[os.path.relpath(path, root)] = path
    return found


def read_entries(path):
    """[(key, value)] in file order. git parses it, so an unquoted or continued line cannot fool us."""
    out = subprocess.run(
        ["git", "config", "--file", path, "--list", "-z"],
        capture_output=True, text=True, check=False,
    )
    if out.returncode != 0:
        raise IOError("git could not parse %s: %s" % (path, out.stderr.strip()))
    entries = []
    for record in out.stdout.split("\0"):
        if not record:
            continue
        key, _, value = record.partition("\n")
        entries.append((key, value))
    return entries


def hooks_inventory(config_path):
    hooks = os.path.join(os.path.dirname(config_path), "hooks")
    if not os.path.isdir(hooks):
        return []
    return sorted(f for f in os.listdir(hooks) if not f.endswith(".sample"))


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


# Build byproducts, not attestable content: running the sibling checks in this very directory creates
# `checks/__pycache__/*.pyc`, which f-4 then reports as added-then-removed files on the next two runs. Freezing a
# directory means freezing what a human wrote in it, so these are excluded from BOTH --record and --verify —
# excluding them in one place only would trade a false finding for a blind spot (found by review, 2026-08-18).
IGNORED_DIRS = {"__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache"}
IGNORED_SUFFIXES = (".pyc", ".pyo")
# Churn, not attestable content: a Finder sidecar and a lock file rewritten by scheduled tasks would
# otherwise produce a finding on most runs. Excluded from BOTH --record and --verify — excluding them in
# one place only would trade a false finding for a blind spot.
IGNORED_NAMES = {".DS_Store", "scheduled_tasks.lock"}


def content_inventory(root, targets):
    inv = {}
    for target in targets:
        abs_target = os.path.join(root, target)
        if os.path.isfile(abs_target):
            inv[target] = sha256(abs_target)
        elif os.path.isdir(abs_target):
            for dirpath, dirnames, filenames in os.walk(abs_target, followlinks=False):
                dirnames[:] = sorted(d for d in dirnames if d not in IGNORED_DIRS)
                for name in sorted(filenames):
                    if name.endswith(IGNORED_SUFFIXES) or name in IGNORED_NAMES:
                        continue
                    p = os.path.join(dirpath, name)
                    if os.path.islink(p) or not os.path.isfile(p):
                        continue
                    inv[os.path.relpath(p, root)] = sha256(p)
    return inv


def snapshot(root):
    configs = {}
    for label, path in sorted(find_config_files(root).items()):
        entries = read_entries(path)
        non_branch = sorted("%s=%s" % (k, v) for k, v in entries if not k.startswith("branch."))
        branch_counts = {}
        for k, _v in entries:
            if k.startswith("branch."):
                suffix = k.rsplit(".", 1)[-1]
                branch_counts[suffix] = branch_counts.get(suffix, 0) + 1
        configs[label] = {
            "non_branch": non_branch,
            "branch_total": sum(branch_counts.values()),
            "branch_suffix_counts": branch_counts,
            "hooks_non_sample": hooks_inventory(path),
        }
    return {
        "root": os.path.abspath(root),
        "configs": configs,
        "content": {name: content_inventory(root, targets) for name, targets in CONTENT_SETS.items()},
    }


def verify(root, baseline):
    findings = []

    def fail(msg):
        findings.append(msg)

    live_configs = find_config_files(root)
    base_configs = baseline["configs"]

    for label in sorted(set(live_configs) - set(base_configs)):
        fail("f-1: NEW git configuration file not in the baseline: %s" % label)
    for label in sorted(set(base_configs) - set(live_configs)):
        fail("f-1: baselined git configuration file has DISAPPEARED: %s" % label)

    for label in sorted(set(live_configs) & set(base_configs)):
        path, expected = live_configs[label], base_configs[label]
        entries = read_entries(path)

        # (1) non-branch multiset equality
        live_non_branch = sorted("%s=%s" % (k, v) for k, v in entries if not k.startswith("branch."))
        if live_non_branch != expected["non_branch"]:
            extra = _diff(live_non_branch, expected["non_branch"])
            missing = _diff(expected["non_branch"], live_non_branch)
            for item in extra:
                fail("f-1(1): %s: UNAPPROVED entry %s" % (label, _redact(item)))
            for item in missing:
                fail("f-1(1): %s: approved entry missing %s" % (label, _redact(item)))

        # (2) branch.* suffix allow-list + measured shapes
        for key, value in entries:
            if not key.startswith("branch."):
                continue
            suffix = key.rsplit(".", 1)[-1]
            shape = BRANCH_SHAPES.get(suffix)
            if shape is None:
                fail("f-1(2): %s: branch key with unknown suffix %r" % (label, key))
            elif not shape.match(value):
                fail("f-1(2): %s: %s value does not match its measured shape (%r)" % (label, key, value))

        # (3) include/includeIf by section+key, never by text search
        for key, _value in entries:
            if key.split(".", 1)[0].lower() in FORBIDDEN_SECTIONS:
                fail("f-1(3): %s: %s present — a config include is an unbounded exec/credential channel" % (label, key))

        # (4) exec-ish markers outside *.url
        for key, value in entries:
            if key.endswith(".url"):
                continue
            if any(marker in value for marker in EXEC_MARKERS):
                fail("f-1(4): %s: %s carries an exec-or-URL marker" % (label, key))

        # f-2 hooks
        live_hooks = hooks_inventory(path)
        if live_hooks != expected["hooks_non_sample"]:
            fail("f-2: %s: hooks/ inventory changed: %s (baseline %s)"
                 % (label, live_hooks, expected["hooks_non_sample"]))

    # f-3 / f-4 frozen content
    for name, targets in CONTENT_SETS.items():
        live = content_inventory(root, targets)
        expected = baseline["content"].get(name, {})
        for p in sorted(set(live) - set(expected)):
            fail("%s: NEW file not in the attested inventory: %s" % (name, p))
        for p in sorted(set(expected) - set(live)):
            fail("%s: attested file removed: %s" % (name, p))
        for p in sorted(set(live) & set(expected)):
            if live[p] != expected[p]:
                fail("%s: content changed: %s" % (name, p))

    return findings


def _diff(a, b):
    """Multiset difference a - b, preserving duplicates."""
    remaining = list(b)
    out = []
    for item in a:
        if item in remaining:
            remaining.remove(item)
        else:
            out.append(item)
    return out


def _redact(entry):
    key = entry.split("=", 1)[0]
    return key + "=<value withheld>" if SECRETISH.search(key) else entry


def main():
    ap = argparse.ArgumentParser(description="agent_confined R7 f-1..f-4 git-configuration audit")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--record", metavar="BASELINE", help="write a typed baseline (step 5, sanitised tree)")
    mode.add_argument("--verify", metavar="BASELINE", help="verify the tree against a baseline")
    ap.add_argument("--root", default="/workspaces/motoko_agent",
                    help="tree to audit (default /workspaces/motoko_agent, which is also the path on the\n"
                         "host bind mount; the baseline pins the root it was recorded with, so --record\n"
                         "and --verify must use the same one)")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        print("root does not exist: %s" % root, file=sys.stderr)
        return 2

    if args.record:
        data = snapshot(root)
        with open(args.record, "w") as fh:
            json.dump(data, fh, indent=2, sort_keys=True)
            fh.write("\n")
        configs = data["configs"]
        print("recorded %d git configuration files under %s" % (len(configs), root))
        for label, info in sorted(configs.items()):
            print("  %-58s non-branch=%-4d branch=%-5d hooks_extra=%d"
                  % (label, len(info["non_branch"]), info["branch_total"], len(info["hooks_non_sample"])))
        for name, inv in sorted(data["content"].items()):
            print("  %-58s files=%d" % (name, len(inv)))
        print("baseline written to %s" % args.record)
        print("ATTEST THIS, do not trust it: a baseline recorded after a directive was planted approves it.")
        print("Read the hooks_extra counts above: on this tree the only approved non-sample hooks are")
        print("deepseek-harness/.git/hooks/{pre-commit,pre-merge-commit,pre-push}, installed by lefthook.")
        return 0

    try:
        with open(args.verify) as fh:
            baseline = json.load(fh)
    except OSError as exc:
        print("cannot read baseline %s: %s" % (args.verify, exc), file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print("baseline %s is not valid JSON: %s" % (args.verify, exc), file=sys.stderr)
        return 2
    if os.path.abspath(baseline.get("root", root)) != root:
        print("refusing to verify: baseline was recorded for %s, --root is %s"
              % (baseline.get("root"), root), file=sys.stderr)
        return 2

    findings = verify(root, baseline)
    if not findings:
        print("R7 f-1..f-4 PASS: %d configuration files, hooks and frozen content match the baseline"
              % len(baseline["configs"]))
        return 0
    print("R7 FAIL — %d finding(s):" % len(findings))
    for f in findings:
        print("  * %s" % f)
    return 1


if __name__ == "__main__":
    # The documented contract is 0 = held, 1 = a finding, 2 = could not run. read_entries() raises IOError when
    # git cannot parse a config file, and writing a baseline can fail on permissions; both are "could not run",
    # so they must not surface as a traceback with status 1 — a wrapper keying on 2 to distinguish "retry" from
    # "violation found" would otherwise misread an I/O failure as a real finding (found by review, 2026-08-18).
    try:
        sys.exit(main())
    except OSError as exc:
        print("R7 could not run: %s" % exc, file=sys.stderr)
        sys.exit(2)
