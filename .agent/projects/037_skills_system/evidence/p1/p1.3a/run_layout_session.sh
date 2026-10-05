#!/usr/bin/env bash
# 037 P1.3a: P1.2's run_listing_session.sh with the launch directory and the three
# spellings of the workdir made parameters, so one harness runs both layouts. The
# `env -i` allowlist and the `ailang run` command line are P1.2's. The provider
# endpoint is the local recorder; no model is called and no provider key is forwarded.
#
#   run_layout_session.sh <label> <launch-dir> <fixture-abs> <workdir-arg> <sandbox> [script.json]
#
#   launch-dir   the directory `ailang run src/core/supervisor.ail` is started from
#   fixture-abs  the fixture workdir, absolute (MOTOKO_PROFILE_DIR is built from it,
#                as buildChildEnv does with path.resolve)
#   workdir-arg  the value of --workdir, as supervisorWorkdirArg would spell it:
#                the path relative to launch-dir when the workdir is under it,
#                otherwise the workdir as given (src/tui/src/runtime-process.ts:327)
#   sandbox      AILANG_FS_SANDBOX and MOTOKO_JOURNAL_WORKDIR: the workdir as the TUI
#                was given it (runtime-process.ts:475, :526)
#   SYSPROMPT    (env) the --system-prompt value; default is the workdir-relative
#                form systemPromptForWorkspace returns
#   DIAG_MOTOKO_REPO (env, diagnostic only) forwarded as MOTOKO_REPO, which the TUI
#                also forwards; unset in every layout run
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$1"; LAUNCH="$2"; FX="$3"; WD_ARG="$4"; SANDBOX="$5"
SCRIPT="${6:-$HERE/script_skill_readfile.json}"
SYSPROMPT="${SYSPROMPT:-.motoko-system-prompt.md}"
OUT="$HERE/capture/$LABEL"
PORT="${PORT:-18437}"
mkdir -p "$OUT"; rm -f "$OUT"/req-*.json
P13A_SCRIPT="$SCRIPT" python3 "$HERE/capture_server.py" "$OUT" "$PORT" > "$OUT/server.log" 2>&1 &
SRV=$!; trap 'kill $SRV 2>/dev/null' EXIT
sleep 1
cd "$LAUNCH" || exit 2
{
  echo "label=$LABEL"
  echo "launch_dir=$(pwd -P)"
  echo "fixture_abs=$FX"
  echo "workdir_arg=$WD_ARG"
  echo "AILANG_FS_SANDBOX=$SANDBOX"
  echo "MOTOKO_JOURNAL_WORKDIR=$SANDBOX"
  echo "MOTOKO_PROFILE_DIR=$FX/.motoko/config/skills_proto"
  echo "system_prompt_arg=$SYSPROMPT"
  echo "script=$SCRIPT"
  echo "MOTOKO_REPO=${DIAG_MOTOKO_REPO:-<unset>}"
  echo "started=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT/layout.txt"
timeout 240 env -i PATH="$PATH" HOME="$HOME" \
    OPENAI_API_KEY="p1-capture-not-a-key" \
    OPENAI_BASE_URL="http://127.0.0.1:$PORT/v1" \
    AILANG_FS_SANDBOX="$SANDBOX" \
    AILANG_NO_VERSION_WARNINGS=1 \
    MOTOKO_STREAM_EVENTS=1 \
    MOTOKO_HEADLESS=1 \
    MOTOKO_PROFILE_DIR="$FX/.motoko/config/skills_proto" \
    MOTOKO_JOURNAL_WORKDIR="$SANDBOX" \
    MOTOKO_SESSION_ID="p1_3a_${LABEL}_$(date +%s)" \
    MOTOKO_RESUME_COUNT=0 \
    ${DIAG_MOTOKO_REPO:+MOTOKO_REPO="$DIAG_MOTOKO_REPO"} \
  ailang run \
    --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace \
    --ai gpt5 --entry main \
    --net-allow-http --net-allow-localhost \
    --stream-allow-http --stream-allow-localhost \
    --max-recursion-depth 1000000 \
    src/core/supervisor.ail \
    -- --profile skills_proto --model openai/p1-capture --workdir "$WD_ARG" --port 8080 \
       --system-prompt "$SYSPROMPT" --no-backend \
       "Which skills can you load? Load the workdir-stamp skill." \
  < /dev/null > "$OUT/session.stdout.jsonl" 2> "$OUT/session.stderr.log"
RC=$?
echo "rc=$RC" >> "$OUT/layout.txt"
echo "[$LABEL] session rc=$RC; requests recorded: $(ls "$OUT"/req-*.json 2>/dev/null | wc -l)"
python3 "$HERE/summarise.py" "$OUT" | tee "$OUT/summary.txt"
exit $RC
