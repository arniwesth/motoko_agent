#!/usr/bin/env bash
# mutgate for D11-CEIL.
#
# NOT `mutgate.sh --clone-from`: that does a plain `git clone`, which carries the
# tracked ailang.lock's ABSOLUTE path deps into the primary checkout — the exact
# trap this item is about. The clone is made and SYNCED here first, then handed
# to mutgate with --repo so every row runs against the clone's own packages.
set -uo pipefail
ROOT=/tmp/claude-1001/-workspaces-motoko-agent/bd8176ff-ae08-43f2-b32d-d7d1bfa1141e/scratchpad/d11
PRIMARY=/workspaces/motoko_agent
CLONE=$ROOT/clone-mut
rm -rf "$CLONE"
git clone -q --no-hardlinks "$PRIMARY" "$CLONE" || exit 1
git -C "$CLONE" checkout -q cdf0f65f || exit 1
# the constants under test, as they stand in the working tree
cp "$PRIMARY/src/core/dst_corpus.ail" "$CLONE/src/core/dst_corpus.ail" || exit 1
( cd "$CLONE" && make CI=1 sync_packages ) > "$ROOT/mut-sync.log" 2>&1 || { echo "SYNC_FAIL"; exit 1; }
grep -q "$CLONE" "$CLONE/ailang.lock" || { echo "LOCK_NOT_REPOINTED"; exit 1; }
echo "MUTGATE clone synced, starting rows"
bash "$PRIMARY/.agent/projects/013_core_architecture_for_dst/mutgate.sh" \
  --spec "$PRIMARY/evidence/D11-CEIL/mutgate_spec.tsv" \
  --repo "$CLONE" --out "$ROOT/mutgate-out"
echo "MUTGATE rc=$?"
