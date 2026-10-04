#!/usr/bin/env bash
# test.sh — exercise new.sh, status.sh, install-hooks.sh and the pre-commit hook
# against a throwaway repository.
#
#   tools/worktree/test.sh
#
# It never touches the repository it is run from: everything happens under a
# temporary directory with its own origin, its own shared checkout and its own
# config. Each refusal is tested beside the case that must be allowed, and the
# hook's refusals are first shown NOT to happen with the hook removed, so a
# refusal cannot be credited to the hook by accident.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
hooks="$(cd "$here/../githooks" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
# A private global config and config directory, so the installer under test
# never reaches the real ones.
export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_SYSTEM=/dev/null XDG_CONFIG_HOME="$tmp/xdg"
: > "$GIT_CONFIG_GLOBAL"
unset MOTOKO_ALLOW_PRIMARY_COMMIT WORKTREE_MAIN_BRANCH WORKTREE_REMOTE

pass=0 fail=0
ok()  { pass=$((pass + 1)); echo "  ok    $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1"; }
# expect <0|nonzero> <description> <command...>
expect() {
	local want="$1" what="$2"; shift 2
	"$@" >"$tmp/out" 2>&1; local rc=$?
	if { [ "$want" = 0 ] && [ "$rc" = 0 ]; } || { [ "$want" != 0 ] && [ "$rc" != 0 ]; }; then ok "$what"
	else bad "$what (exit $rc)"; sed 's/^/        /' "$tmp/out" | head -6
	fi
}
commit_in() { # commit_in <dir> <message>: change a tracked file and commit it
	echo "$2 $RANDOM" >> "$1/file.txt"
	git -C "$1" add file.txt && git -C "$1" commit -q -m "$2"
}

git init -q --bare -b main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/repo" 2>/dev/null
repo="$tmp/repo"
git -C "$repo" checkout -q -b main 2>/dev/null || true
echo one > "$repo/file.txt"
git -C "$repo" add file.txt && git -C "$repo" commit -q -m init && git -C "$repo" push -q -u origin main

echo "new.sh"
expect 0 "creates a sibling worktree on a new branch" \
	bash -c "cd '$repo' && '$here/new.sh' task-a feat/task-a"
[ -d "$tmp/repo-task-a" ] && ok "the worktree is beside the shared checkout" || bad "the worktree is beside the shared checkout"
[ "$(git -C "$tmp/repo-task-a" branch --show-current)" = "feat/task-a" ] && ok "it is on the new branch" || bad "it is on the new branch"
[ "$(git -C "$tmp/repo-task-a" rev-parse HEAD)" = "$(git -C "$repo" rev-parse origin/main)" ] && ok "it starts at origin/main" || bad "it starts at origin/main"
[ "$(git -C "$repo" branch --show-current)" = "main" ] && ok "the shared checkout stays on main" || bad "the shared checkout stays on main"
expect 1 "refuses a name whose directory exists" \
	bash -c "cd '$repo' && '$here/new.sh' task-a feat/other"
expect 1 "refuses a branch that already exists" \
	bash -c "cd '$repo' && '$here/new.sh' task-b feat/task-a"
expect 1 "refuses a name with characters outside a-z 0-9 -" \
	bash -c "cd '$repo' && '$here/new.sh' Task_B feat/task-b"
expect 0 "works when run from inside another worktree" \
	bash -c "cd '$tmp/repo-task-a' && '$here/new.sh' task-c feat/task-c"
[ -d "$tmp/repo-task-c" ] && ok "and still places it beside the shared checkout" || bad "and still places it beside the shared checkout"

echo "status.sh"
expect 0 "--check passes: shared checkout on main, nothing modified" \
	bash -c "cd '$repo' && '$here/status.sh' --check --no-prs"
echo dirty >> "$repo/file.txt"
expect 1 "--check fails: a tracked file is modified in the shared checkout" \
	bash -c "cd '$repo' && '$here/status.sh' --check --no-prs"
expect 0 "without --check it reports and exits 0" \
	bash -c "cd '$repo' && '$here/status.sh' --no-prs"
git -C "$repo" checkout -q -- file.txt
echo scratch > "$repo/untracked.txt"
expect 0 "--check passes: an untracked file is not a problem" \
	bash -c "cd '$repo' && '$here/status.sh' --check --no-prs"
rm -f "$repo/untracked.txt"
git -C "$repo" checkout -q -b side
expect 1 "--check fails: the shared checkout is off main" \
	bash -c "cd '$repo' && '$here/status.sh' --check --no-prs"
git -C "$repo" checkout -q main
expect 0 "--check sees the same thing when run from a worktree" \
	bash -c "cd '$tmp/repo-task-a' && '$here/status.sh' --check --no-prs"

echo "pre-commit, control: hook not installed"
expect 0 "a commit on main in the shared checkout goes through" commit_in "$repo" control-on-main
git -C "$repo" reset -q --hard origin/main

echo "install-hooks.sh"
git init -q -b main "$tmp/unrelated"
config_before="$(cksum < "$repo/.git/config")"
expect 0 "installs" bash -c "cd '$repo' && '$here/install-hooks.sh' '$hooks'"
[ "$(git -C "$repo" config --get core.hooksPath)" = "$hooks" ] && ok "the shared checkout uses the hooks" || bad "the shared checkout uses the hooks"
[ "$(git -C "$tmp/repo-task-a" config --get core.hooksPath)" = "$hooks" ] && ok "and so does a worktree" || bad "and so does a worktree"
[ "$(cksum < "$repo/.git/config")" = "$config_before" ] && ok "the repository's own config is byte-identical" || bad "the repository's own config is byte-identical"
[ -z "$(git -C "$repo" config --local --get core.hooksPath)" ] && ok "and holds no hooksPath" || bad "and holds no hooksPath"
[ -z "$(git -C "$tmp/unrelated" config --get core.hooksPath)" ] && ok "an unrelated repository is not affected" || bad "an unrelated repository is not affected"
expect 0 "installing twice is harmless" bash -c "cd '$repo' && '$here/install-hooks.sh' '$hooks'"
[ "$(git config --global --get-regexp '^includeif\.' | wc -l | tr -d ' ')" = 2 ] && ok "and leaves two includes, not four" || bad "and leaves two includes, not four"
git -C "$repo" config --local core.hooksPath /somewhere/else
expect 1 "refuses when the repository's config already sets a hooks path" bash -c "cd '$repo' && '$here/install-hooks.sh' '$hooks'"
git -C "$repo" config --local --unset core.hooksPath

echo "pre-commit, installed"
before="$(git -C "$repo" rev-parse HEAD)"
expect 1 "refuses a commit on main in the shared checkout" commit_in "$repo" on-main
[ "$(git -C "$repo" rev-parse HEAD)" = "$before" ] && ok "and no commit was made" || bad "and no commit was made"
git -C "$repo" reset -q --hard "$before"
git -C "$repo" checkout -q side
expect 1 "refuses a commit on another branch in the shared checkout" commit_in "$repo" on-side
git -C "$repo" reset -q --hard
expect 0 "allows it with MOTOKO_ALLOW_PRIMARY_COMMIT=1" \
	env MOTOKO_ALLOW_PRIMARY_COMMIT=1 bash -c "echo x >> '$repo/file.txt' && git -C '$repo' add file.txt && git -C '$repo' commit -q -m override"
git -C "$repo" checkout -q main
expect 1 "the override does not allow a commit on main" \
	env MOTOKO_ALLOW_PRIMARY_COMMIT=1 bash -c "echo x >> '$repo/file.txt' && git -C '$repo' add file.txt && git -C '$repo' commit -q -m override-main"
git -C "$repo" reset -q --hard
expect 0 "allows a commit on a task branch in its own worktree" commit_in "$tmp/repo-task-a" in-worktree

echo "install-hooks.sh --uninstall"
expect 0 "uninstalls" bash -c "cd '$repo' && '$here/install-hooks.sh' --uninstall"
[ -z "$(git -C "$repo" config --get core.hooksPath)" ] && ok "no hooks path remains in effect" || bad "no hooks path remains in effect"
[ -z "$(git config --global --get-regexp '^includeif\.')" ] && ok "and the include is gone from the global config" || bad "and the include is gone from the global config"
expect 0 "after which a commit on main goes through again" commit_in "$repo" after-uninstall

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
