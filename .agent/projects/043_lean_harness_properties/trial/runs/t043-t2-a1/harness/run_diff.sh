#!/usr/bin/env bash
# run_diff.sh — the T2 differential test: the REAL herdrFailureCode / herdrMeansAgentGone
# (bun) against the REAL failure_code / means_agent_gone (ailang), over one generated corpus.
#
#   run_diff.sh <tree root> [work dir] [-- gen_corpus.ts options, e.g. --fuzz 200000 --seed 43]
#
# Steps: gen_corpus.ts -> ts_twin.ts -> 100k-case chunks -> ail_twin.ail (4 in parallel) ->
# compare.ts. Exit is compare.ts's: 1 if any P2.1 disagreement, 0 if none, 2 on a harness fault.
# Needs bun (1.4.4) and ailang (v0.54.14) on PATH. The AILANG half resolves the tree's herdr
# package through ../ailang.toml (path dependency `../tree/packages/motoko-ext-herdr`).
set -euo pipefail

root="$(cd "${1:?usage: run_diff.sh <tree root> [work dir] [-- gen options]}" && pwd)"
shift
work="${1:-$(mktemp -d)}"
[[ $# -gt 0 ]] && shift
[[ "${1:-}" == "--" ]] && shift
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$work/chunks"
rm -f "$work"/chunks/*

bun "$here/gen_corpus.ts" "$work/corpus.json" "$@"
bun "$here/ts_twin.ts" "$root" "$work/corpus.json" "$work/ts.json"
bun -e '
  const fs = require("fs");
  const [src, dir] = process.argv.slice(1);
  const a = JSON.parse(fs.readFileSync(src, "utf8"));
  for (let i = 0; i * 100000 < a.length; i++)
    fs.writeFileSync(`${dir}/c${String(i).padStart(3, "0")}.json`, JSON.stringify(a.slice(i * 100000, (i + 1) * 100000)));
' "$work/ts.json" "$work/chunks"

# ailang must be given an absolute entry path; it runs from the tree root.
( cd "$root" && ls "$work"/chunks/c*.json | xargs -P 4 -I{} sh -c \
    'ailang run --relax-modules --caps IO --entry main --args-file "$1" "$2" 2>"${1%.json}.err" >"${1%.json}.out"' _ {} "$here/ail_twin.ail" )
cat "$work"/chunks/c*.out > "$work/ail.out"
echo "ail: $(wc -l < "$work/ail.out") lines"
bun "$here/compare.ts" "$work/ts.json" "$work/ail.out" 4 | tee "$work/compare.txt"
exit "${PIPESTATUS[0]}"
