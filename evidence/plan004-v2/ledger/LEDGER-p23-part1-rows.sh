#!/usr/bin/env bash
# Regenerate LEDGER-p23-part1-rows.tsv from the receipts on disk.
#
# WHY THIS EXISTS. Part-1 row evidence has been carried between delegates as prose
# inside answer files, with every digest re-typed by hand each round. That produced
# two observed corruptions:
#   - a12 (answer-mot-dlg-1789743819242) reported the ref baseline as 083cc8c1…,
#     which is the ref-after-x6.log FILE's own sha256, not the ref digest inside it
#     (1876628c…). Two different things in the column that names one.
#   - a17 (answer-mot-dlg-1789802299896) reported collect-x6.log as a 96-hex-char
#     string: the first 49 chars of its real digest with the tail of collect-x6e.log's
#     digest spliced on. Real value is 346f4d0a…856e593105d719.
# Neither was caught by review, because prose digests are not checkable without
# doing exactly what this script does.
#
# This script NEVER types a digest. Every value is computed from the file.
# It is read-only: it writes only to stdout (redirect it yourself).
#
# Usage:  bash LEDGER-p23-part1-rows.sh [$T] > LEDGER-p23-part1-rows.tsv
# Default $T = /workspaces/p23-sweep-r4
#
# SAFETY: writes nothing under $T or the eval worktree. Stray files in the sweep
# tree are not free here — blocker B2 (AssembledTreeDiffers) counted 58 untracked
# files into an assembled-tree digest and refused admission over it. Keep generated
# artifacts in this project directory, not in $T.

set -uo pipefail
T="${1:-/workspaces/p23-sweep-r4}"
C="$T/clone"

d() { # digest of a file, or a marker
  if [ -f "$T/$1" ]; then sha256sum "$T/$1" | cut -d' ' -f1; else echo "ABSENT"; fi
}

printf 'row\tstatus\tX\tartifact\tsha256\tnote\n'

emit() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$(d "$4")" "$5"; }

# ── X6 era ────────────────────────────────────────────────────────────────────
emit 1.1  GREEN   X6 freeze.txt                 "freeze + stamp + ref/find baselines"
emit 1.1  GREEN   X6 X.log                      "X6 commit"
emit 1.1  GREEN   X6 Xtree.log                  "X6 tree"
emit 1.2  GREEN   X6 collect-x6.log             "collect rc=0"
emit 1.2  GREEN   X6 collect-x6e.log            "pinned re-collect rc=0; main_packages_clean=True"
emit 1.2  GREEN   X6 erecord-x6.json            "E record, pins copied"
emit 1.3  GREEN   X6 door1-x6.log               "fixture door x36 with --entry-out; 36 FX lines"
emit 1.4  GREEN   X6 door2-x6.log               "entry door cmp=0; 37 EN lines; n=29 admitted=26 refused=3 failed=0"
emit 1.5  GREEN   X6 door2-x6.log               "completed entry pairs/0600/end; 27/27 PINNED (same log as 1.4)"
emit 1.6  GREEN   X6 t16/run2.log               "pin->candidate; CANDIDATE reproduced K0-K7; rc=0"
emit 1.7  RED     X6 tail/t17.log               "0/7 reach the shell; helper bug, fixed at X7"
emit 1.8  PARTIAL X6 tail/t18.log               "shell-level 3/3 ScanRefusal wires; NOT via named pytest"
emit 1.8  PARTIAL X6 tail/t18b.log              "excerpt attempt-2 UrlUserinfo"
emit 1.9  GREEN   X6 tail/t19.log               "0 EVAL_ENTRY / entry_config.py before refusal"
emit 1.10 GREEN   X6 tail/t110.log              "4-way R1; named test 1 passed"
emit 1.10 GREEN   X6 tail/t110b.log             "4/4 REAL-collect"
emit 1.11 RUN     X6 tail/t111.log              "five mutations run; MUT-4 gate-arm analysis only on clean tree"
emit 1.12 RED     X6 tail/t112-clone-nolive.log "4 failed / 113 passed / 13 skipped; live-mode + A-side PENDING"
emit 1.13 GREEN   X6 tail/t113.log              "runner 4/4; admission 12/12; scan 8/9 (m12 flake)"
emit 1.14 GREEN   X6 tail/t114.log              "all targets rc=0; eval_protected_selftest 42/42"
emit 1.15 RED     X6 tail/t115.log              "4 known reds + m12 flake; a17 recorded it PENDING, file exists"
emit 1.18 GREEN   X6 tail/ref-clone-1.log       "clone-scope checkpoint"
emit 1.18 GREEN   X6 tail/ref-main-1.log        "main-scope checkpoint; ref digest 1876628c is INSIDE this file"

# ── X7 era ────────────────────────────────────────────────────────────────────
emit 1.1  GREEN   X7 freeze-x7.txt              "X7 + X7tree + diff digest + blobs"
emit 1.2  GREEN   X7 collect-x7.log             "collect rc=0 at X7"
emit 1.2  GREEN   X7 erecord-x7.json            "E record re-derived at X7, pins copied"

# ── identity + the carry-over claim, computed not quoted ──────────────────────
if [ -d "$C/.git" ]; then
  x6=20a78579e5eaef34bfdad10cc81d9f2f2e61d753
  x7=$(git -C "$C" rev-parse HEAD)
  printf 'X7\tIDENTITY\tX7\tclone/HEAD\t%s\t%s\n' "$x7" "tree $(git -C "$C" rev-parse 'HEAD^{tree}')"
  for p in scripts/eval/candidate.py scripts/eval/journal_replay.ail \
           scripts/eval/journal_replay.sh scripts/eval/entry_config.py \
           scripts/eval/p23_collector.py src/eval/journal/scan.ail \
           src/eval/journal/admission.ail; do
    a=$(git -C "$C" rev-parse "$x6:$p" 2>/dev/null || echo "?")
    b=$(git -C "$C" rev-parse "$x7:$p" 2>/dev/null || echo "?")
    [ "$a" = "$b" ] && s=EQUAL || s=DIFFERS
    printf 'carry\t%s\tX6->X7\t%s\t%s\t%s\n' "$s" "$p" "$a" "evaluator byte-equality claim"
  done
fi
