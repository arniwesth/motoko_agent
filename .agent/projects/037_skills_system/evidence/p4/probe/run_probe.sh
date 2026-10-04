#!/usr/bin/env bash
# 037 P4 evidence: one process per fixture workdir, because a `listDir` that
# fails ends the process (ADR-001 D1). Run from the root of a tree where the
# skills package is wired into the root manifest.
#
#   bash run_probe.sh <fixture base> <probe .ail, relative to the tree root>
set -u
F=${1:?fixture base}
PROBE=${2:?probe path}
CAPS=Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace,Rand

# case, skill to call, ctx.workdir, ctx.context_limit, "sandbox" or "nosandbox"
run_case() {
  local sb=()
  [ "$5" = sandbox ] && sb=(AILANG_FS_SANDBOX="$F/$1")
  out=$(env AILANG_RELAX_MODULES=1 "${sb[@]}" P4_CASE="$1 ($5)" P4_CALL="$2" P4_WORKDIR="$3" P4_LIMIT="$4" \
        ailang run --caps "$CAPS" --ai-stub --entry main "$PROBE" 2>&1)
  code=$?
  printf '%s\n' "$out" | grep -v "^→\|^✓\|MOD010\|relax-modules\|^Warning: dependency .* content changed\|^Run 'ailang lock' to update" | sed "s#$F#<fixtures>#g"
  printf 'EXIT %s\n\n' "$code"
}

echo "ailang: $(ailang --version | head -1)"
echo "== controls: accepted"
run_case c01-no-motoko "" . 0 sandbox
run_case c02-no-root "" . 0 sandbox
run_case c03-empty-root "nope" . 0 sandbox
run_case c04-valid-set workdir-stamp . 0 sandbox
run_case c04-valid-set crlf-bom "$F/c04-valid-set" 200000 sandbox
run_case c04-valid-set "../config/dogfood" . 0 sandbox
run_case c05-relative-symlink-inside inlink . 0 sandbox
run_case c06-real-skills dagr-producer . 0 sandbox
run_case c06-real-skills dagr-producer . 24309 sandbox
run_case c06-real-skills dagr-producer . 24308 sandbox
echo "== R1: the root"
for c in r1a-root-is-file r1b-root-symlink-out r1c-root-symlink-absolute-inside r1d-root-symlink-dangling; do run_case $c good . 0 sandbox; done
echo "== V1..V8, each beside a valid skill"
for c in v1a-dir-without-skill-md v1b-wrong-case v2-entry-symlink-out v3a-skill-md-unreadable v3b-skill-md-is-directory v3c-skill-md-symlink-out v4a-no-frontmatter v4b-unterminated v4c-bad-yaml v4d-not-a-mapping v5-name-differs v6-empty-description v7-too-large v8-index-over-budget two-violations; do run_case $c good . 0 sandbox; done
echo "== D1, what the guarantee does not cover: a directory that cannot be listed"
run_case x1-unlistable-skill-dir good . 0 sandbox
echo "== D7: started without the sandbox (the root resolves against the process directory)"
run_case c04-valid-set workdir-stamp . 0 nosandbox
run_case c04-valid-set workdir-stamp "$F/c04-valid-set" 0 nosandbox
