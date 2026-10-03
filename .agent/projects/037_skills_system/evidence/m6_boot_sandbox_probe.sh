#!/usr/bin/env bash
# Does every extension in the default profile still boot when the boot check
# runs under AILANG_FS_SANDBOX, as the TUI runs the runtime? `make
# verify_extensions` runs it without the sandbox, so a skill tree could pass
# in CI and be refused in a session. Evidence for ADR-001 D1. Not a gate.
#
#   bash .agent/projects/037_skills_system/evidence/m6_boot_sandbox_probe.sh
#
# Run from the repo root. It runs the same command as the `verify_extensions`
# recipe, once per extension, with the sandbox set to the repo root. HERDR_ENV
# is unset so the herdr extension's gate stays closed.
set -u

ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
profile=${MOTOKO_CONFIG:-default}
cfg=".motoko/config/$profile/config.json"

echo "ailang: $(ailang --version | head -1)   profile: $profile"
for ext in $(jq -r '.extensions.order[]?' "$cfg"); do
  out=$(env -u HERDR_ENV -u HERDR_PANE_ID \
        MOTOKO_PROFILE_DIR="$ROOT/.motoko/config/$profile" \
        AILANG_RELAX_MODULES=1 \
        AILANG_FS_SANDBOX="$ROOT" \
        ailang run --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
          --ai-stub --entry main scripts/verify_extension_boot.ail -- "$ext" 2>&1)
  rc=$?
  line=$(printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -E '^OK:|UNKNOWN|Error|escapes sandbox|"type":"error"' | head -1 | cut -c1-150)
  printf '%-26s exit=%s  %s\n' "$ext" "$rc" "$line"
done
