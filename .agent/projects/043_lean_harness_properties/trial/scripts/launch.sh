#!/usr/bin/env bash
# Start one arm session (PLAN-001 A1 items 2-4): its tree, its deny rules, its brief, a fresh
# Claude Code session in its own herdr tab, the brief as its first prompt. The clock starts
# when the brief is sent.
#   launch.sh <name> <A|B> <T0..T6> <minutes> [seeded-tree.tar]
# With a tarball, the tree is the planter's sealed seeded tree, extracted; without one, it is
# built unseeded (the dry run).
set -euo pipefail
source "$(dirname "$0")/common.sh"
name="$1"; arm="$2"; target="$3"; minutes="$4"; sealed="${5:-}"
s="$ROOT/s/$name"; c="$ROOT/collect/$name"
[ -e "$s" ] && { echo "launch: $s exists" >&2; exit 1; }
mkdir -p "$s/out" "$c"
if [ -n "$sealed" ]; then mkdir -p "$s/tree"; tar -xf "$sealed" -C "$s/tree"; tree_sha=$(hash_dir "$s/tree")
else tree_sha=$("$SCRIPTS/build_tree.sh" "$s/tree"); fi
python3 -I "$SCRIPTS/settings.py" "$name" "$ROOT" $ALL_SESSIONS > "$c/settings.json"
python3 -I "$SCRIPTS/brief.py" "$PLAN" "$arm" "$target" "$s/tree" "$s/out" "$minutes" > "$c/brief.md"
sid=$(python3 -I -c 'import uuid; print(uuid.uuid4())')
tab=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$s/tree" --label "$name" --no-focus)
pane=$(jq -r '.result.root_pane.pane_id' <<<"$tab")
herdr agent start "$name" --kind claude --pane "$pane" --timeout 90000 -- \
  --model "$MODEL" --effort "$EFFORT" --permission-mode bypassPermissions --strict-mcp-config \
  --add-dir "$s/out" --settings "$c/settings.json" --session-id "$sid" > "$c/start.json" || {
  # Claude Code asks once per new directory whether to trust it. The directory is the trial tree,
  # a copy of this repository built by build_tree.sh, so the answer is yes. Anything else stops.
  if herdr agent read "$name" --source visible --lines 30 | grep -q "Yes, I trust this folder"; then
    herdr agent send-keys "$name" down >/dev/null; sleep 1; herdr agent send-keys "$name" enter >/dev/null
    for _ in $(seq 1 30); do
      [ "$(herdr agent get "$name" | jq -r '.result.agent.agent_status')" = idle ] && break; sleep 2
    done
    echo "trust prompt answered" >> "$c/start.json"
  fi
  [ "$(herdr agent get "$name" | jq -r '.result.agent.agent_status')" = idle ] || {
    echo "launch: $name did not become ready; pane $pane; see $c/start.json" >&2; exit 3; }
}
herdr agent prompt "$name" "$(cat "$c/brief.md")" > "$c/prompt.json"
start=$(date -u +%s)
cat > "$c/meta" <<META
name=$name
arm=$arm
target=$target
minutes=$minutes
session_id=$sid
pane=$pane
tab=$(jq -r '.result.tab.tab_id' <<<"$tab")
tree_sha256=$tree_sha
brief_sha256=$(sha256sum "$c/brief.md" | cut -d' ' -f1)
settings_sha256=$(sha256sum "$c/settings.json" | cut -d' ' -f1)
start_epoch=$start
start_utc=$(date -u -d @"$start" +%Y-%m-%dT%H:%M:%SZ)
META
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) launched $name arm=$arm target=$target minutes=$minutes session=$sid pane=$pane tree_sha256=$tree_sha"
