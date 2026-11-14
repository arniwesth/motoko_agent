# Shared by the repro scripts. Run them FROM THE TREE ROOT (the snapshot); they locate this
# directory themselves. AILANG runs inside $mod, a directory of symlinks back to the tree, so
# `src/core/...` and `pkg/...` imports resolve without writing anything into the tree.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(cd "$here/.." && pwd)"
if [[ -f "$PWD/src/core/journal.ail" ]]; then tree="$PWD"; else tree="$(cd "$out/../tree" && pwd)"; fi
mod="$here/mod"
mkdir -p "$mod/diff" "$mod/repro"
for l in src packages ailang.lock ailang.toml; do ln -sfn "$tree/$l" "$mod/$l"; done
cp "$out/diff/gen.ail" "$out/diff/foldhost.ail" "$mod/diff/"
cp "$here/checkpoint_resume.ail" "$mod/repro/"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
ail() { ( cd "$mod" && ailang run --relax-modules "$@" ) 2>"$work/ail.err"; }
# host_verdict <gen output file> -> prints `F\t<key>\t<verdict>` lines for the REAL host's journals
host_verdict() {
  bun "$out/diff/host.ts" "$tree" "$1" "$work/hostroot" > "$work/host.out"
  ail --caps IO,FS --entry main --args-json "\"$work/host.out\"" diff/foldhost.ail | grep -aE '^F	'
}
