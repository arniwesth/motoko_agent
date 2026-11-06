#!/usr/bin/env bash
# W5 follow-up: D9's reachability. Runs t043-t3-b1's own reproduction, repro/unicode.sh, with its
# probe replaced by a variant (<variant.ail>) that puts the text in the SYSTEM message of the
# seed, the message rpc.ail builds from readFile(SYSTEM.md) and every AGENTS.md from the working
# directory up (agents_md.ail:156). unicode.sh itself, the real host, the real twin and the real
# fold are unchanged.
#   w5_d9_variant.sh <work> <variant.ail> <tree name>=<tree> ... -- <case> ...
# <work>/work/t043-t3-b1 must be prepared by w5_rerun.py (out.pristine, the path rewrite). Each
# run, as w5_rerun.py's run_one: tree/ and out/ restored with rsync --delete (keeping .ailang/),
# tmp/ emptied, the arms' clean environment, 120 s for the process group. Prints one line per
# run: tree, case, exit code, and the verdicts unicode.sh prints.
set -euo pipefail
work="$1"; variant="$2"; shift 2
trees=(); while [ "$1" != "--" ]; do trees+=("$1"); shift; done; shift
w="$work/work/t043-t3-b1"
[ -f "$w/.prepared" ] || { echo "w5_d9_variant: $w is not prepared" >&2; exit 2; }
PATHV="/home/motoko/.local/bin:/home/motoko/.bun/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
mkdir -p "$work/variant-logs"
for tv in "${trees[@]}"; do
  name="${tv%%=*}"; tree="${tv#*=}"
  for c in "$@"; do
    rsync -a --delete --exclude=.ailang/ "$tree/" "$w/tree/"
    rsync -a --delete --exclude=.ailang/ "$w/out.pristine/" "$w/out/"
    rm -rf "$w/tmp"; mkdir -p "$w/tmp"
    cp "$variant" "$w/out/repro/unicode_probe.ail"
    log="$work/variant-logs/$name.$c.log"
    set +e
    (cd "$w/tree" && env -i PATH="$PATHV" HOME=/home/motoko USER=motoko LOGNAME=motoko SHELL=/bin/bash \
       LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color TMPDIR="$w/tmp" \
       setsid timeout -s KILL 120 bash -c "bash ../out/repro/unicode.sh $c" > "$log" 2>&1 < /dev/null)
    rc=$?
    set -e
    host=$(grep -a 'host journal folds to' "$log" | sed 's/.*: //')
    twin=$(grep -a 'twin journal folds to' "$log" | sed 's/.*: //; s/ .*//')
    printf '%s\t%s\texit=%s\thost=%s\ttwin=%s\n' "$name" "$c" "$rc" "$host" "${twin:0:40}"
  done
done
