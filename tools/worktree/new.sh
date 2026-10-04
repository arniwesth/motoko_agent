#!/usr/bin/env bash
# new.sh — start a task in its own git worktree.
#
#   tools/worktree/new.sh <name> <branch> [--base <ref>] [--no-fetch]
#
# Creates <parent>/<repo>-<name> beside the shared checkout, on a new branch cut
# from origin/main, and says what a fresh worktree does not contain. It refuses
# to reuse a directory or a branch that already exists: a second task never
# borrows the first one's tree.
#
# Run it from any checkout of the repository. It changes nothing in the shared
# checkout except the worktree and branch it registers.
set -euo pipefail

die() { echo "worktree-new: $*" >&2; exit 1; }
usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

name="" branch="" base="" fetch=1
while [ "$#" -gt 0 ]; do
	case "$1" in
		--base) [ "$#" -ge 2 ] || die "--base needs a ref"; base="$2"; shift 2 ;;
		--no-fetch) fetch=0; shift ;;
		-h|--help) usage; exit 0 ;;
		-*) die "unknown option: $1" ;;
		*)
			if [ -z "$name" ]; then name="$1"
			elif [ -z "$branch" ]; then branch="$1"
			else die "unexpected argument: $1"
			fi
			shift ;;
	esac
done
[ -n "$name" ] && [ -n "$branch" ] || { usage >&2; exit 2; }

case "$name" in
	*[!a-z0-9-]*) die "name must be lowercase letters, digits and hyphens: $name" ;;
esac

# The first entry of `git worktree list` is the shared checkout, whichever
# worktree this is run from.
primary="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
[ -n "$primary" ] || die "not inside a git repository"

main="${WORKTREE_MAIN_BRANCH:-main}"
remote="${WORKTREE_REMOTE:-origin}"
[ -n "$base" ] || base="$remote/$main"
dest="$(dirname "$primary")/$(basename "$primary")-$name"

[ ! -e "$dest" ] || die "$dest already exists; pick another name"

if [ "$fetch" = 1 ]; then
	git -C "$primary" fetch --quiet "$remote" || die "git fetch $remote failed (use --no-fetch to skip)"
fi

if git -C "$primary" show-ref --verify --quiet "refs/heads/$branch"; then
	die "branch $branch already exists locally; pick another name"
fi
if git -C "$primary" show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
	die "branch $branch already exists on $remote; pick another name"
fi
git -C "$primary" rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "base $base not found"

git -C "$primary" worktree add --quiet -b "$branch" "$dest" "$base"

got="$(git -C "$dest" branch --show-current)"
[ "$got" = "$branch" ] || die "$dest is on '$got', expected '$branch'"

echo "worktree: $dest"
echo "branch:   $branch (from $base at $(git -C "$dest" rev-parse --short=8 HEAD))"

# A worktree holds tracked files only. Say which ignored things the shared
# checkout has that this one does not, so their absence is not a surprise.
for p in ailang .env .dagr .motoko; do
	if [ -e "$primary/$p" ] && [ ! -e "$dest/$p" ]; then
		echo "absent:   $p (gitignored; it lives in $primary)"
	fi
done
