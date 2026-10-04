#!/usr/bin/env bash
# 037 P1.2: (re)build the fixture workdir. Run from the worktree root.
#   .motoko/herdr-delegates/p1.2/build_fixture.sh [dir]   (default /tmp/motoko-037-p1-fixture)
set -euo pipefail
FX="${1:-/tmp/motoko-037-p1-fixture}"
mkdir -p "$FX/.motoko/skills/workdir-stamp" "$FX/.motoko/config"
cat > "$FX/.motoko/skills/workdir-stamp/SKILL.md" <<'MD'
---
name: workdir-stamp
description: >
  Stamp the working directory with a marker file. Use when the user asks to
  stamp, mark or tag the working directory or workspace, or asks for a
  "workdir stamp".
---

# Workdir stamp

Follow these steps exactly. Do not guess the stamp's format; it is in a file
bundled with this skill.

1. Read `stamp-format.txt` in this skill's directory. The directory is the
   first line of the result that delivered these instructions.
2. Create the file `STAMP.txt` in the working directory. Its content is the one
   line from `stamp-format.txt`, with `<reason>` replaced by a few words saying
   why the user asked for the stamp.
3. Tell the user the stamp was written, and quote the line.

Do not create any other file.
MD
printf '%s\n' 'motoko-skill-stamp-7f3a :: <reason>' > "$FX/.motoko/skills/workdir-stamp/stamp-format.txt"
for s in pr-review-loop dagr-producer ailang-feedback; do
  rm -rf "$FX/.motoko/skills/$s"; cp -r ".claude/skills/$s" "$FX/.motoko/skills/$s"
done
printf '%s\n' 'Fixture skills for 037 PLAN-001 P1 (prototype measurements). Not a skill.' > "$FX/.motoko/skills/README.md"
rm -rf "$FX/.motoko/config/skills_proto"; cp -r .motoko/config/skills_proto "$FX/.motoko/config/skills_proto"
cp SYSTEM.md "$FX/.motoko-system-prompt.md"
echo "fixture at $FX"
