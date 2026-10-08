#!/usr/bin/env bash
# What std/fs does for skill discovery under AILANG_FS_SANDBOX: which calls
# see a skill root inside the workdir, and what each call does for a root
# outside it, for a `..` escape, and for a symlink that points outside.
# Evidence for RESEARCH-skills-system.md §9 M1. Not a gate.
#
#   bash .agent/projects/037_skills_system/evidence/m1_sandbox_probe.sh
#
# Runs in a temp dir and touches nothing in the repo. Needs `ailang` on PATH.
# One process per case, because a call that panics ends the run and would hide
# every case after it.
set -u

D=$(mktemp -d)
W="$D/work"        # the workdir, and the sandbox root
O="$D/outside"     # a sibling, outside the sandbox
mkdir -p "$W/.claude/skills/good" "$O/skills/far"
printf -- '---\nname: good\ndescription: in the workdir\n---\nbody\n' > "$W/.claude/skills/good/SKILL.md"
printf -- '---\nname: far\ndescription: outside the workdir\n---\nbody\n' > "$O/skills/far/SKILL.md"
ln -s "$O/skills/far" "$W/.claude/skills/linked"            # dir symlink, target outside
ln -s "$O/skills/far/SKILL.md" "$W/.claude/skills/good/LINK.md"  # file symlink, target outside
mkdir -p "$W/.claude/skills/inlink_target"
printf -- '---\nname: inlink\ndescription: symlink target inside\n---\nbody\n' > "$W/.claude/skills/inlink_target/SKILL.md"
ln -s "$W/.claude/skills/inlink_target/SKILL.md" "$W/.claude/skills/good/INLINK.md"  # file symlink, ABSOLUTE target inside
ln -s ../inlink_target/SKILL.md "$W/.claude/skills/good/RELLINK.md"                  # file symlink, RELATIVE target inside
mkdir -p "$W/.motoko"
ln -s ../.claude/skills "$W/.motoko/skills_rel"                                      # dir symlink, RELATIVE target inside
printf 'x' > "$W/.claude/skills/.DS_Store"                                           # a stray regular file in a root

cd "$W" || exit 1
echo "ailang: $(ailang --version | head -1)"
echo "workdir: $W"
echo

# $1 label, $2 an AILANG expression of type string, evaluated under the sandbox.
run_case() {
  cat > probe.ail <<EOF
module probe

import std/io (println)
import std/fs (readFile, readFileResult, fileExists, isDir, isFile, listDir, walk, glob)
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
  printf '%-44s exit=%s  %s\n' "$1" "$code" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-230)"
}

echo "== inside the workdir, relative paths"
run_case "listDir(.claude/skills)"            'join(",", listDir(".claude/skills"))'
run_case "isDir(.claude/skills/good)"         'show(isDir(".claude/skills/good"))'
run_case "isFile(good/SKILL.md)"              'show(isFile(".claude/skills/good/SKILL.md"))'
run_case "readFileResult(good/SKILL.md)"      'rr(readFileResult(".claude/skills/good/SKILL.md"))'
run_case "glob(.claude/skills, /SKILL.md)"    'join(",", glob(".claude/skills", "/SKILL.md"))'
run_case "listDir(missing root)"              'join(",", listDir(".motoko/skills"))'
run_case "isDir(missing root)"                'show(isDir(".motoko/skills"))'

echo
echo "== inside the workdir, absolute path"
run_case "readFileResult(ABS good/SKILL.md)"  "rr(readFileResult(\"$W/.claude/skills/good/SKILL.md\"))"

echo
echo "== outside the workdir, absolute paths"
run_case "fileExists(outside SKILL.md)"       "show(fileExists(\"$O/skills/far/SKILL.md\"))"
run_case "isDir(outside root)"                "show(isDir(\"$O/skills\"))"
run_case "isFile(outside SKILL.md)"           "show(isFile(\"$O/skills/far/SKILL.md\"))"
run_case "readFileResult(outside SKILL.md)"   "rr(readFileResult(\"$O/skills/far/SKILL.md\"))"
run_case "readFile(outside SKILL.md)"         "readFile(\"$O/skills/far/SKILL.md\")"
run_case "listDir(outside root)"              "join(\",\", listDir(\"$O/skills\"))"

echo
echo "== .. escape"
run_case "readFileResult(../outside/...)"     'rr(readFileResult("../outside/skills/far/SKILL.md"))'
run_case "isDir(../outside/skills)"           'show(isDir("../outside/skills"))'

echo
echo "== symlinks inside the workdir"
run_case "isDir(linked -> outside dir)"       'show(isDir(".claude/skills/linked"))'
run_case "listDir(linked -> outside dir)"     'join(",", listDir(".claude/skills/linked"))'
run_case "isFile(linked/SKILL.md)"            'show(isFile(".claude/skills/linked/SKILL.md"))'
run_case "readFileResult(linked/SKILL.md)"    'rr(readFileResult(".claude/skills/linked/SKILL.md"))'
run_case "isFile(LINK.md -> outside file)"    'show(isFile(".claude/skills/good/LINK.md"))'
run_case "readFileResult(LINK.md -> outside)" 'rr(readFileResult(".claude/skills/good/LINK.md"))'
run_case "isFile(INLINK.md -> inside, abs)"   'show(isFile(".claude/skills/good/INLINK.md"))'
run_case "readFileResult(INLINK.md, abs target)" 'rr(readFileResult(".claude/skills/good/INLINK.md"))'
run_case "isFile(RELLINK.md -> inside, rel)"  'show(isFile(".claude/skills/good/RELLINK.md"))'
run_case "readFileResult(RELLINK.md, rel target)" 'rr(readFileResult(".claude/skills/good/RELLINK.md"))'
run_case "isDir(.motoko/skills_rel -> inside)" 'show(isDir(".motoko/skills_rel"))'
run_case "listDir(.motoko/skills_rel -> inside)" 'join(",", listDir(".motoko/skills_rel"))'
run_case "readFileResult(skills_rel/good/SKILL.md)" 'rr(readFileResult(".motoko/skills_rel/good/SKILL.md"))'

echo
echo "== a stray regular file in a root"
run_case "isFile(.claude/skills/.DS_Store)"   'show(isFile(".claude/skills/.DS_Store"))'
run_case "isDir(.claude/skills/.DS_Store)"    'show(isDir(".claude/skills/.DS_Store"))'

echo
echo "== control: no sandbox variable, outside read"
cat > probe.ail <<EOF
module probe
import std/io (println)
import std/fs (readFileResult)
import std/result (Result, Ok, Err)
export func main() -> () ! {IO, FS} {
  println(match readFileResult("$O/skills/far/SKILL.md") { Ok(s) => "Ok", Err(e) => "Err(\${e})" })
}
EOF
out=$(env -u AILANG_FS_SANDBOX ailang run --caps IO,FS --entry main probe.ail 2>&1); code=$?
printf '%-44s exit=%s  %s\n' "readFileResult(outside), unsandboxed" "$code" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"

rm -rf "$D"
