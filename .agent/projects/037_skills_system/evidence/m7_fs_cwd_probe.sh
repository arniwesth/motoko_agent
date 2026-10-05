#!/usr/bin/env bash
# How std/fs resolves paths when the process directory is NOT the sandbox root.
# The TUI spawns the runtime in its own directory and sets AILANG_FS_SANDBOX to
# the workdir, so the two differ whenever the workdir is not where the TUI was
# started. m1_sandbox_probe.sh ran with the two equal. Evidence for ADR-001 D7.
#
#   bash .agent/projects/037_skills_system/evidence/m7_fs_cwd_probe.sh
#
# Runs in a temp dir and touches nothing in the repo. Needs `ailang` on PATH.
set -u

D=$(mktemp -d)
W="$D/work"                      # the workdir, and the sandbox root
mkdir -p "$W/.motoko/skills/good" "$D/.motoko/skills/wrong"
printf -- '---\nname: good\ndescription: in the workdir\n---\nbody\n' > "$W/.motoko/skills/good/SKILL.md"
printf -- '---\nname: wrong\ndescription: beside the workdir\n---\nbody\n' > "$D/.motoko/skills/wrong/SKILL.md"

cd "$D" || exit 1                # the process directory is the PARENT of the workdir
echo "ailang: $(ailang --version | head -1)"
echo "process dir: $D"
echo "sandbox    : $W"
echo

run_case() {
  cat > probe.ail <<EOF
module probe

import std/io (println)
import std/fs (readFileResult, isDir, listDir)
import std/string (join)
import std/result (Result, Ok, Err)

func rr(r: Result[string, string]) -> string {
  match r {
    Ok(s) => "Ok(\${show(_str_len(s))} chars)",
    Err(e) => "Err(\${e})"
  }
}

export func main() -> () ! {IO, FS} {
  println($2)
}
EOF
  out=$(AILANG_FS_SANDBOX="$W" ailang run --caps IO,FS --entry main probe.ail 2>&1)
  code=$?
  printf '%-52s exit=%s  %s\n' "$1" "$code" "$(printf '%s' "$out" | grep -v '^→\|^✓' | tr '\n' ' ' | cut -c1-170)"
}

echo "== absolute paths into the workdir"
run_case "isDir(ABS work/.motoko/skills)"            "show(isDir(\"$W/.motoko/skills\"))"
run_case "listDir(ABS work/.motoko/skills)"          "join(\",\", listDir(\"$W/.motoko/skills\"))"
run_case "readFileResult(ABS .../good/SKILL.md)"     "rr(readFileResult(\"$W/.motoko/skills/good/SKILL.md\"))"

echo
echo "== relative to the process dir, landing inside the workdir"
run_case "isDir(work/.motoko/skills)"                'show(isDir("work/.motoko/skills"))'
run_case "listDir(work/.motoko/skills)"              'join(",", listDir("work/.motoko/skills"))'
run_case "readFileResult(work/.../good/SKILL.md)"    'rr(readFileResult("work/.motoko/skills/good/SKILL.md"))'

echo
echo "== bare relative paths: which directory do they resolve against?"
run_case "isDir(.motoko/skills)"                     'show(isDir(".motoko/skills"))'
run_case "listDir(.motoko/skills)"                   'join(",", listDir(".motoko/skills"))'
run_case "readFileResult(.motoko/skills/good/...)"   'rr(readFileResult(".motoko/skills/good/SKILL.md"))'
run_case "readFileResult(.motoko/skills/wrong/...)"  'rr(readFileResult(".motoko/skills/wrong/SKILL.md"))'
run_case "isDir(.)"                                  'show(isDir("."))'

rm -rf "$D"
