#!/usr/bin/env bash
# 037 live smoke: what the two sessions ran on. These are the commands that were
# run by hand on 2026-10-05, collected here; the script itself was not re-run.
#
#   build.sh <scratch dir> <a checkout of the code under test> <this repo's evidence/p1>
#
# <scratch dir>/launch  a disposable copy of the code, without .git and .agent:
#                       the session is started in it, so a stray write lands there
# <scratch dir>/home    a scratch HOME whose .profile puts the stubs first on PATH
# <scratch dir>/stubs   P1.3's `gh` and `herdr` stubs: log the call and exit 1
# <scratch dir>/tpl     the fixture workdir: P1.2's four skills, the committed
#                       `skills` profile with agent.max_steps set to 8, and SYSTEM.md
set -euo pipefail
S=$1; SRC=$2; EV=$3
rm -rf "$S"; mkdir -p "$S/launch" "$S/home" "$S/stubs" "$S/out"
rsync -a --exclude .git --exclude .review --exclude .agent --exclude node_modules \
  --exclude little-coder "$SRC/" "$S/launch/"
cp "$EV"/p1.3/stubs/* "$S/stubs/"; chmod +x "$S/stubs/"*
ln -sfn "$HOME/.ailang" "$S/home/.ailang"
printf '%s\n' "export PATH=\"$S/stubs:\$PATH\"" > "$S/home/.profile"
# P1.2's fixture builder, with the prototype's profile name replaced by the
# committed profile's. It writes the `workdir-stamp` skill and copies three of
# the repository's own skills beside it.
sed 's/skills_proto/skills/g' "$EV/p1.2/build_fixture.sh" > "$S/build_fixture.sh"
(cd "$SRC" && bash "$S/build_fixture.sh" "$S/tpl")
python3 - "$S/tpl/.motoko/config/skills/config.json" <<'PY'
import json, sys
p = sys.argv[1]; c = json.load(open(p)); c["agent"]["max_steps"] = 8
json.dump(c, open(p, "w"), indent=2)
PY
cp "$(dirname "$0")/run_live.py" "$S/run_live.py"
echo "built in $S; run: python3 $S/run_live.py <label> <model>"
