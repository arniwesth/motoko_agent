# worktree

Tools for the rule in `AGENTS.md`: one task, one worktree, one branch, and nothing committed to
`main` or from the shared checkout.

| File | What it does |
|---|---|
| `tools/worktree/new.sh` | Creates `../<repo>-<name>` on a new branch cut from `origin/main`. Refuses a directory or branch that exists. |
| `tools/worktree/status.sh` | Lists every worktree with its uncommitted files, reports a shared checkout that is off `main` or modified, and lists open pull requests that change the paths you name. |
| `tools/githooks/pre-commit` | Refuses a commit on `main`, and a commit from the shared checkout on any branch. |
| `tools/worktree/install-hooks.sh` | Turns the hook on for your git, in this repository only. Never writes the repository's config. |
| `tools/worktree/test.sh` | Tests all of the above in a throwaway repository. |

## Use

```bash
tools/worktree/status.sh src/core packages/motoko-ext-herdr   # who else is in there?
tools/worktree/new.sh retry-backoff fix/stream-retry-backoff  # then work in ../motoko_agent-retry-backoff
```

`status.sh --check` exits 1 when the shared checkout is off `main` or has modified tracked files,
so it can gate something. `--no-prs` skips the pull request lookup, which needs `gh` and the
network and makes one request per open pull request.

## Turning the hook on

```bash
tools/worktree/install-hooks.sh
```

This is not done for you. It turns the hook on for your git, in this repository and its worktrees
only, by adding a conditional include to your global git config. All agent sessions in one
container share a home directory, so one run covers them. `--uninstall` removes it.

It never writes the repository's own config, and that is deliberate. The R7 audit
(`.devcontainer/agent_sandbox/checks/r7_git_audit.py`) names `core.hooksPath` among the settings
through which agent-writable configuration runs as the operator on the host. A hooks path in the
repository's config would fail that audit and be the channel it guards.

**Do not run it on the host.** `tools/githooks` is tracked and agent-writable, and there the hook
would run as you. On the host, the control for "nothing is committed to `main`" is branch
protection on GitHub, which no local hook can replace.

To commit from the shared checkout anyway, on a branch other than `main`:

```bash
MOTOKO_ALLOW_PRIMARY_COMMIT=1 git commit ...
```

There is no override for `main`.

## Test

```bash
tools/worktree/test.sh
```

It builds its own origin, shared checkout and worktrees under a temporary directory and never
touches this repository or its config. Each refusal is tested beside the case that must be
allowed, and the hook's refusals are first shown not to happen with the hook absent.

## What these do not do

- **The hook stops a commit, not an edit.** Files can still be changed in the shared checkout.
  `status.sh` reports that after the fact.
- **The hook can be skipped** with `git commit --no-verify`, and merges and rebases do not run it.
- **`status.sh` sees open pull requests only**, not branches that have not been pushed, and not
  edits that have not been saved.
- **Nothing here gives a delegate a worktree by default.** `Delegate` still starts in the
  orchestrator's directory unless it is passed a `cwd`. The delegate mailbox and `.dagr/` stay
  in the orchestrator's checkout either way.
- **A worktree shares everything git does not track**: ports, the nested `ailang/` build, and
  the shared checkout's `.motoko/`.
