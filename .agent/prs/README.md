# `.agent/prs/` — frozen as legacy

**This directory is closed. Do not add files to it.**

New PR bodies, per-comment state and response artifacts live in `.agent/github/`, one directory
per PR:

```
.agent/github/prs/<remote-alias>-<number>/
  body.md      # authored PR body, PR number in frontmatter — written by `make pr`
  state.yaml   # per-comment processing state — appended by `make pr_sync`
```

Frozen per ADR-001 D2 in `../projects/016_github_ops/`, following 008's migration stance:
**indexed and referenced, never added to, never moved.** The 13 files here carry no convention
worth preserving — they are two undeclared genres (hand-authored PR bodies, and one PR *response*)
with no join key to GitHub — so migrating them would cost more than it returns. They stay where
they are and remain linkable.

The freeze lands in the same change as the first commit of `.agent/github/`, deliberately: a window
in which both trees are writable is a window in which the convention is ambiguous and new files
land in the wrong place.

## Referencing a file here

State records point at these files with repo-root-relative paths, which is what makes the
reference survive regardless of where the record lives:

```yaml
artifact: .agent/prs/2026-08-13-pr-97-compaction-response.md
```

`2026-08-13-pr-97-compaction-response.md` is the worked example the whole pipeline mechanizes, and
it is the first file referenced this way — see `.agent/github/prs/origin-97/state.yaml`.
