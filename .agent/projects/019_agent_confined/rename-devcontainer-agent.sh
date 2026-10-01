#!/usr/bin/env bash
# Rename .devcontainer/agent_confined/ -> .devcontainer/agent/
#
# RUN THIS FROM THE HOST, at the repo root. Inside the agent container
# .devcontainer/ is a read-only virtiofs mount, by design.
#
# Only the DIRECTORY PATH changes. The profile identity stays `agent_confined`:
# compose project motoko_agent_confined, image motoko_agent_confined/dev:1.0,
# MOTOKO_CONTAINER_PROFILE=agent_confined, make agent_confined_check.
# That is what keeps the existing container and volumes attached.
#
# Stop the stack FIRST, with the old path:
#   .devcontainer/agent_confined/agent.sh stop
#
# macOS: install gsed and set SED=gsed, or the -i calls will misbehave.
set -euo pipefail

SED="${SED:-sed}"

[[ -d .devcontainer/agent_confined ]] || { echo "no .devcontainer/agent_confined here — wrong cwd, or already renamed" >&2; exit 1; }
[[ -d .git ]] || { echo "run from the repo root" >&2; exit 1; }

git mv .devcontainer/agent_confined .devcontainer/agent

# Every path reference, across Makefile / .devcontainer / src / packages (12 files).
$SED -i 's#\.devcontainer/agent_confined#.devcontainer/agent#g' \
  $(git grep -l '\.devcontainer/agent_confined' -- Makefile .devcontainer src packages)

# Three prose references in .devcontainer/README.md that are not full paths.
$SED -i 's#`agent_confined/agent.sh`#`agent/agent.sh`#; s#(\./agent_confined/README.md)#(./agent/README.md)#; s#\[`agent_confined/README.md`\]#[`agent/README.md`]#' \
  .devcontainer/README.md

# r9: split the directory name from the profile identity.
f=.devcontainer/agent/checks/r9-container.sh
$SED -i 's|^PROFILE_DIR_NAME="agent_confined"$|PROFILE_DIR_NAME="agent"\nPROFILE_NAME="agent_confined"  # compose project, image and MOTOKO_CONTAINER_PROFILE keep the old name|' "$f"
# leg 5 compares the env var against the identity, not the directory.
# leg 1's referrer grep becomes /agent/|agent_confined — a bare `agent` would
# false-match /workspaces/motoko_agent in every devcontainer.json.
$SED -i 's#"\$PROFILE_DIR_NAME" \]\]#"$PROFILE_NAME" ]]#; s#MOTOKO_CONTAINER_PROFILE=\${PROFILE_DIR_NAME}#MOTOKO_CONTAINER_PROFILE=${PROFILE_NAME}#; s#grep -qE "\${PROFILE_DIR_NAME}"#grep -qE "/${PROFILE_DIR_NAME}/|${PROFILE_NAME}"#' "$f"

echo
echo "rename applied. checks:"
if git grep -n '\.devcontainer/agent_confined' -- Makefile .devcontainer src packages; then
  echo "  FAIL: path references remain (above)"; exit 1
else
  echo "  ok: no .devcontainer/agent_confined path references left"
fi
bash -n .devcontainer/agent/agent.sh && bash -n .devcontainer/agent/checks/r9-container.sh
echo "  ok: bash -n clean"
echo
echo "next, by hand:"
echo "  .devcontainer/agent/agent.sh      # starts the stack, same volumes"
echo "  make agent_confined_check         # expect R9 PASS"
