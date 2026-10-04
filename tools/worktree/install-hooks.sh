#!/usr/bin/env bash
# install-hooks.sh — turn on the hooks in tools/githooks for YOUR git, in this
# repository only.
#
#   tools/worktree/install-hooks.sh [--uninstall] [hooks-dir]
#
# It never writes the repository's own config. It adds a conditional include to
# your global git config, scoped to this repository's git directory, and the
# included file sets core.hooksPath. Every worktree of the repository is covered,
# other repositories are not, and another user's git (the operator's, on the
# host) is unaffected.
#
# WHY NOT `git config core.hooksPath` IN THE REPOSITORY. The R7 audit
# (.devcontainer/agent_sandbox/checks/r7_git_audit.py) treats the repository's
# config as agent-writable configuration that the operator's host git executes,
# and names core.hooksPath in the family it guards. A hooks path there would
# both fail that audit and be the channel it exists to close: a tracked,
# agent-writable script run as the operator. Keep it out of the repository.
#
# DO NOT RUN THIS ON THE HOST for the same reason: tools/githooks is tracked and
# agent-writable, and there the hook would run as you.
set -euo pipefail

die() { echo "install-hooks: $*" >&2; exit 1; }

uninstall=0 dir=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--uninstall) uninstall=1; shift ;;
		-h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) die "unknown option: $1" ;;
		*) dir="$1"; shift ;;
	esac
done

primary="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
[ -n "$primary" ] || die "not inside a git repository"
[ -n "$dir" ] || dir="$primary/tools/githooks"

common="$(git -C "$primary" rev-parse --path-format=absolute --git-common-dir)"
# Two conditions, because one does not cover both cases (measured, git 2.43):
# the bare path matches the shared checkout, whose git directory is exactly
# that path, and the path with a trailing slash matches everything under it,
# which is where each worktree's own git directory lives.
keys=("includeIf.gitdir:${common%/}.path" "includeIf.gitdir:${common%/}/.path")
conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/git"
tag="$(printf '%s' "$common" | cksum | cut -d' ' -f1)"
inc="$conf_dir/worktree-hooks-$tag.gitconfig"

if [ "$uninstall" = 1 ]; then
	removed=0
	for key in "${keys[@]}"; do
		if git config --global --get-all "$key" 2>/dev/null | grep -qxF "$inc"; then
			git config --global --unset-all "$key" "$(printf '%s' "$inc" | sed 's/[][\.*^$]/\\&/g')"
			removed=1
		fi
	done
	if [ "$removed" = 1 ]; then echo "install-hooks: removed the includes from your global git config"
	else echo "install-hooks: no include to remove"
	fi
	rm -f "$inc"
	exit 0
fi

[ -d "$dir" ] || die "$dir does not exist"
[ -x "$dir/pre-commit" ] || die "$dir/pre-commit is missing or not executable"
if [ -n "$(git -C "$primary" config --local --get core.hooksPath || true)" ]; then
	die "the repository's own config already sets core.hooksPath; remove that first"
fi

mkdir -p "$conf_dir"
printf '[core]\n\thooksPath = %s\n' "$dir" > "$inc"
for key in "${keys[@]}"; do
	if ! git config --global --get-all "$key" 2>/dev/null | grep -qxF "$inc"; then
		git config --global --add "$key" "$inc"
	fi
done

echo "install-hooks: hooks = $dir"
echo "install-hooks: scoped to $common and its worktrees, in your global git config"
echo "install-hooks: the repository's config was not changed"
