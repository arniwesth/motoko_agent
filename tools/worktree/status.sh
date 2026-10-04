#!/usr/bin/env bash
# status.sh — what is checked out where, what is uncommitted, and who else is
# touching a path.
#
#   tools/worktree/status.sh [--check] [--no-prs] [path ...]
#
# Lists every worktree with its branch and its uncommitted files, and reports
# two problems with the shared checkout: it is off the main branch, or it has
# modified tracked files. With paths, it also lists the open pull requests that
# change anything under them. That is the overlap check to run before a task.
#
#   --check    exit 1 when the shared checkout has a problem (default: report, exit 0)
#   --no-prs   skip the pull request lookup (it needs `gh` and the network)
#
# SCOPE. A clean report means the shared checkout is on main with no modified
# tracked files. It does not mean nobody is working there: untracked files are
# counted but are not a problem, and an edit that has not been saved is invisible.
# The pull request lookup sees open pull requests only, not unpushed branches.
set -uo pipefail

check=0 prs=1 paths=()
while [ "$#" -gt 0 ]; do
	case "$1" in
		--check) check=1; shift ;;
		--no-prs) prs=0; shift ;;
		-h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "worktree-status: unknown option: $1" >&2; exit 2 ;;
		*) paths+=("${1%/}"); shift ;;
	esac
done

main="${WORKTREE_MAIN_BRANCH:-main}"
primary="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
[ -n "$primary" ] || { echo "worktree-status: not inside a git repository" >&2; exit 2; }

printf '%-9s %-44s %-46s %8s %9s\n' "" "WORKTREE" "BRANCH" "MODIFIED" "UNTRACKED"
problems=0
while IFS= read -r wt; do
	[ -d "$wt" ] || continue
	branch="$(git -C "$wt" branch --show-current 2>/dev/null)"
	[ -n "$branch" ] || branch="(detached)"
	modified="$(git -C "$wt" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')"
	untracked="$(git -C "$wt" status --porcelain 2>/dev/null | grep -c '^??' || true)"
	tag=""
	[ "$wt" = "$primary" ] && tag="shared"
	printf '%-9s %-44s %-46s %8s %9s\n' "$tag" "$wt" "$branch" "$modified" "$untracked"
	if [ "$wt" = "$primary" ]; then
		if [ "$branch" != "$main" ]; then
			problems=$((problems + 1))
			problem_lines="${problem_lines:-}PROBLEM: the shared checkout is on '$branch', not '$main'."$'\n'
		fi
		if [ "$modified" != 0 ]; then
			problems=$((problems + 1))
			problem_lines="${problem_lines:-}PROBLEM: the shared checkout has $modified modified tracked file(s)."$'\n'
		fi
	fi
done < <(git worktree list --porcelain | sed -n 's/^worktree //p')

echo
if [ "$problems" = 0 ]; then
	echo "shared checkout: on '$main', no modified tracked files."
else
	printf '%s' "${problem_lines:-}"
	echo "Task work belongs in its own worktree: tools/worktree/new.sh <name> <branch>"
fi

if [ "${#paths[@]}" -gt 0 ] && [ "$prs" = 1 ]; then
	echo
	if ! command -v gh >/dev/null 2>&1; then
		echo "open pull requests: not checked (gh is not installed)"
	elif ! numbers="$(gh pr list --state open --limit 100 --json number -q '.[].number' 2>/dev/null)"; then
		echo "open pull requests: not checked (gh pr list failed)"
	else
		echo "open pull requests changing: ${paths[*]}"
		found=0
		for n in $numbers; do
			files="$(gh pr diff "$n" --name-only 2>/dev/null)" || continue
			hits=""
			for p in "${paths[@]}"; do
				m="$(printf '%s\n' "$files" | awk -v p="$p" '$0 == p || index($0, p "/") == 1')"
				[ -n "$m" ] && hits="$hits$m"$'\n'
			done
			[ -n "$hits" ] || continue
			found=$((found + 1))
			count="$(printf '%s' "$hits" | sort -u | grep -c .)"
			head="$(gh pr view "$n" --json headRefName -q .headRefName 2>/dev/null)"
			echo "  #$n ($head): $count file(s)"
			printf '%s' "$hits" | sort -u | head -5 | sed 's/^/      /'
		done
		[ "$found" != 0 ] || echo "  none"
		[ "$found" = 0 ] || echo "On overlap, stop and ask before starting."
	fi
fi

[ "$check" = 1 ] && [ "$problems" != 0 ] && exit 1
exit 0
