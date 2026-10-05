#!/usr/bin/env bash
# 037 P5 evidence: the runtime's own entry point on a refused tree, a valid
# one, and across the edits of ADR-001 A2. Not a gate: each run compiles
# src/core/supervisor.ail afresh (about 40 s), so the gate
# (`make verify_skills_refusal`) drives the same two startup calls through a
# small script instead. This shows the two agree.
#
# Each run is the headless launch P1.2 used: `src/core/supervisor.ail` with
# `--no-backend`, an explicit environment, AILANG_FS_SANDBOX set to the
# fixture, and `--ai-stub` in place of a provider, so no model, no network and
# no credential is involved. The stub answers one step and the session ends.
#
#   bash real_entry.sh <empty scratch dir>          (run from the worktree root)
set -u
B=${1:?scratch dir}
ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
mkdir -p "$B"; B=$(cd "$B" && pwd -P)
[ -z "$(ls -A "$B")" ] || { echo "$B is not empty" >&2; exit 1; }

skill() { mkdir -p "$1/.motoko/skills/$2"; printf -- "$3" > "$1/.motoko/skills/$2/SKILL.md"; }
wd() {
  mkdir -p "$B/$1/.motoko/config/probe"
  printf '%s\n' '{"agent":{"model":"stub","max_steps":3},"extensions":{"order":["skills"],"strict":false}}' > "$B/$1/.motoko/config/probe/config.json"
  cp SYSTEM.md "$B/$1/.motoko-system-prompt.md"
  printf '%s' "$B/$1"
}

# workdir name -> stdout in $B/<name>.<n>.jsonl; prints the facts read from it
n=0
run() {
  local name=$1 label=$2 W="$B/$1"; n=$((n + 1))
  local out="$B/$name.$n.jsonl"
  timeout 300 env -i PATH="$PATH" HOME="$HOME" AILANG_FS_SANDBOX="$W" AILANG_NO_VERSION_WARNINGS=1 \
      MOTOKO_HEADLESS=1 MOTOKO_STREAM_EVENTS=1 \
    ailang run --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace,Rand --ai-stub --entry main \
      --max-recursion-depth 1000000 src/core/supervisor.ail \
      -- --profile probe --workdir "$W" --system-prompt "$W/.motoko-system-prompt.md" --no-backend \
         "Say hello." < /dev/null > "$out" 2> "$out.stderr"
  local rc=$?
  echo "RUN $n: $label"
  echo "  exit $rc"
  echo "  JSONL error events: $(jq -cR 'fromjson? | select(type == "object" and .type == "error")' "$out" | wc -l)"
  echo "  session_start events (the runtime's first): $(jq -cR 'fromjson? | select(type == "object" and .type == "session_start" and has("loaded_extensions"))' "$out" | wc -l)"
  jq -cR 'fromjson? | select(type == "object" and .type == "error") | .message' "$out" | sed "s#$B#<scratch>#g; s/^/  error: /"
  jq -cR 'fromjson? | select(type == "object" and .type == "session_start" and has("loaded_extensions")) | "  loaded_extensions: \(.loaded_extensions | join(","))"' "$out" | tr -d '"'
  jq -cR 'fromjson? | select(type == "object" and .type == "v2_mode") | "  header.system_prefix_digest: \(.header.system_prefix_digest)", "  header.ext_set_digest:       \(.header.ext_set_digest)"' "$out" | tr -d '"'
  echo
}

echo "ailang: $(ailang --version | head -1)   HEAD: $(git rev-parse HEAD)"
echo

W=$(wd refused); skill "$W" good '---\nname: good\ndescription: A valid skill beside the case.\n---\n# Good\n'
mkdir -p "$W/.motoko/skills/empty"; skill "$W" renamed '---\nname: other-name\ndescription: d\n---\n'
run refused "A3 through the real entry: two violations (V1, V5) beside a valid skill"

W=$(wd a2)
skill "$W" alpha '---\nname: alpha\ndescription: The first skill.\n---\n# Alpha\n\nThe body.\n'
skill "$W" beta '---\nname: beta\ndescription: The second skill.\n---\n# Beta\n'
run a2 "A2 base: two valid skills (alpha, beta)"
skill "$W" gamma '---\nname: gamma\ndescription: A third skill.\n---\n# Gamma\n'
run a2 "A2: a valid skill added (gamma)"
rm -rf "$W/.motoko/skills/gamma"
skill "$W" alpha '---\nname: alpha\ndescription: The first skill, reworded.\n---\n# Alpha\n\nThe body.\n'
run a2 "A2: gamma removed, alpha's description reworded"
skill "$W" alpha '---\nname: alpha\ndescription: The first skill.\n---\n# Alpha\n\nThe body, rewritten: three more lines.\n\n1. One.\n2. Two.\n'
run a2 "A2: alpha's description restored, only its body reworded"
rm -rf "$W/.motoko/skills"
run a2 "A2 / D12: no root at all"
