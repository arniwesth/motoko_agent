#!/usr/bin/env bash
# 037 P1.2: one headless session under `skills_proto` on the fixture workdir, with
# the provider endpoint pointed at the local recorder (capture_server.py). No model
# is called and no provider key is forwarded. Run from the worktree root.
#   .motoko/herdr-delegates/p1.2/run_listing_session.sh [fixture-dir] [out-dir]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FX="${1:-/tmp/motoko-037-p1-fixture}"
OUT="${2:-$HERE/capture}"
PORT="${PORT:-18437}"
mkdir -p "$OUT"; rm -f "$OUT"/req-*.json
python3 "$HERE/capture_server.py" "$OUT" "$PORT" > "$OUT/server.log" 2>&1 &
SRV=$!; trap 'kill $SRV 2>/dev/null' EXIT
sleep 1
# An explicit allowlist, as the TUI's buildChildEnv builds one. OPENAI_API_KEY is a
# placeholder for the local recorder, not a credential.
timeout 240 env -i PATH="$PATH" HOME="$HOME" \
    OPENAI_API_KEY="p1-capture-not-a-key" \
    OPENAI_BASE_URL="http://127.0.0.1:$PORT/v1" \
    AILANG_FS_SANDBOX="$FX" \
    AILANG_NO_VERSION_WARNINGS=1 \
    MOTOKO_STREAM_EVENTS=1 \
    MOTOKO_HEADLESS=1 \
    MOTOKO_PROFILE_DIR="$FX/.motoko/config/skills_proto" \
    MOTOKO_JOURNAL_WORKDIR="$FX" \
    MOTOKO_SESSION_ID="p1_2_listing_$(date +%s)" \
    MOTOKO_RESUME_COUNT=0 \
  ailang run \
    --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace \
    --ai gpt5 --entry main \
    --net-allow-http --net-allow-localhost \
    --stream-allow-http --stream-allow-localhost \
    --max-recursion-depth 1000000 \
    src/core/supervisor.ail \
    -- --profile skills_proto --model openai/p1-capture --workdir "$FX" --port 8080 \
       --system-prompt "$FX/.motoko-system-prompt.md" --no-backend \
       "Which skills can you load? Load the workdir-stamp skill." \
  < /dev/null > "$OUT/session.stdout.jsonl" 2> "$OUT/session.stderr.log"
RC=$?
echo "session rc=$RC; requests recorded: $(ls "$OUT"/req-*.json 2>/dev/null | wc -l)"
python3 - "$OUT/req-01.json" <<'PY'
import json, sys
b = json.load(open(sys.argv[1]))["body"]
sk = [t for t in b["tools"] if t["function"]["name"] == "Skill"]
print("Skill schemas in request 1:", len(sk))
print(sk[0]["function"]["description"])
print(json.dumps(sk[0]["function"]["parameters"]))
PY
exit $RC
