#!/usr/bin/env bash
# x2.sh [tree root, default: the current directory] — X-2 (observation). Exit 1 when the real
# chain_digest_after gives the same value for ("", m1) and ("m{role:4:user;content:24:", m2),
# 0 when it does not, 2 when x2.ail did not run.
here="$(cd "$(dirname "$0")" && pwd)"
out="$("$here/../diff/ail_run.sh" "${1:-.}" "$here/x2.ail" 2>/dev/null)"
echo "$out"
case "$out" in
  *"X-2 collide"*) exit 1 ;;
  *"X-2 distinct"*) exit 0 ;;
  *) echo "no verdict: the harness did not run" >&2; exit 2 ;;
esac
