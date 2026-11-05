#!/usr/bin/env bash
# run_t3.sh [scratch dir] — the whole T3 pipeline. Env passed through to stage 1:
# T3_MAXLEN, T3_ALPHA, T3_RANDOM, T3_RLEN, T3_NSYS, T3_OPS (one case, e.g. 7-9-0).
# T3_ADOPT=0 keeps one host instance across a resume; T3_PROP picks the exit status
# (P3.1, P3.2, X-1, X-3, all). T3_REUSE=1 reuses an existing <scratch>/gen.out.
# Exit 1 on a violation of the selected property.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# The tree: T3_TREE, else the current directory when it is the repository root, else ../../tree.
if [[ -n "${T3_TREE:-}" ]]; then tree="$T3_TREE"; elif [[ -f "$PWD/src/core/journal.ail" ]]; then tree="$PWD"; else tree="$(cd "$here/../../tree" && pwd)"; fi
export T3_TREE="$tree"
mkdir -p "$here/../runs"; s="${1:-$(mktemp -d "$here/../runs/tmp.XXXXXX")}"; mkdir -p "$s"; s="$(cd "$s" && pwd)"
[[ -n "${1:-}" ]] || trap 'rm -rf "$s"' EXIT
[[ "${T3_REUSE:-0}" == 1 && -s "$s/gen.out" ]] || "$here/ail_run.sh" "$here/gen_twin.ail" T3_MAXLEN="${T3_MAXLEN:-3}" T3_ALPHA="${T3_ALPHA:-13}" \
  T3_RANDOM="${T3_RANDOM:-0}" T3_RLEN="${T3_RLEN:-6}" T3_NSYS="${T3_NSYS:-1}" ${T3_OPS:+T3_OPS="$T3_OPS"} \
  > "$s/gen.out" 2> "$s/gen.err"
bun "$here/host_write.ts" "$tree" "$s/gen.out" > "$s/host.out"
"$here/ail_run.sh" "$here/fold_host.ail" T3_HOST="$s/host.out" > "$s/fold.out" 2> "$s/fold.err"
bun "$here/compare.ts" "$s/gen.out" "$s/fold.out" "$s/host.out"
