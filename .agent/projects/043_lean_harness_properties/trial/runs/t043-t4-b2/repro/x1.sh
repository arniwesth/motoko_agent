#!/usr/bin/env bash
# x1.sh [tree root, default: the current directory] — X-1, the stale comment at
# src/core/journal.ail:225-228. Exit 1 when the comment still names `chain_digest_base` as the
# `history_seeded` digest AND the real code gives that quantity a different value from the
# chain quantity the field actually carries (x1.ail); 0 otherwise; 2 when x1.ail did not run.
here="$(cd "$(dirname "$0")" && pwd)"
tree="${1:-.}"
out="$("$here/../diff/ail_run.sh" "$tree" "$here/x1.ail" 2>/dev/null)"
echo "$out"
if sed -n 220,232p "$tree/src/core/journal.ail" | tr '\n' ' ' | grep -q 'chain_digest_base` is the whole-history digest a `history_seeded` entry *-- *carries as `digest`'; then
  comment=1; echo "comment: journal.ail:225-226 still says chain_digest_base is the history_seeded digest"
else
  comment=0; echo "comment: not present"
fi
case "$out" in
  *"X-1 differ"*) [[ $comment -eq 1 ]] && exit 1 || exit 0 ;;
  *"X-1 same"*) exit 0 ;;
  *) echo "no verdict: the harness did not run" >&2; exit 2 ;;
esac
