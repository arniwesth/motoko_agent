# LEG-P1.3a — workdir-not-launch-dir measurement (PLAN-001 P1.3a, dagr task `P1.3a`, settles Q3)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the plan,
you do not write any dagr run file, and you do not touch other panes, tabs or worktrees.

## What this is

`P1.3a` in `PLAN-001-implement-adr-001.md` §3 (measurement row a): with the session
launched elsewhere and pointed at a fixture workdir, are the indexed and loaded skills
that workdir's? In both layouts, does `ReadFile` on a bundled file under the directory
line succeed? Settles Q3 (ADR A10 and part of A9). Reported, not gated.

If the bare relative root does NOT index the workdir's skills in a real session: STOP that
line, keep the evidence, and report — D7 returns to the operator. Do not design around it.
If native file tools fail only in the subdirectory layout (workdir is a subdirectory of
the launch directory), record it and raise it as its own issue; it does not block the
default layout.

## Where you work

Worktree `/workspaces/motoko_agent-p1proto`, scratch branch `scratch/p1-prototype`
(verify with `git rev-parse HEAD` and `git branch --show-current` before you start). Your
`cwd` is that worktree root. Do not touch the shared checkout at
`/workspaces/motoko_agent`, the worktrees `/workspaces/motoko_agent-skills` and
`/workspaces/motoko_agent-fix3`, or any other session's panes, tabs or paths. Push
nothing. Commit nothing — neither on the scratch branch nor on `feat/skills-extension`.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0 standing rules, §3 P1.3 row a.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D7** (bare relative
   root; sandbox resolves it against the workdir; un-sandboxed + `--workdir` elsewhere
   indexes the wrong tree), **D10** (directory line `.motoko/skills/<name>` relative to
   the workdir, the form native file tools accept), **A9/A10**.
3. `.motoko/herdr-delegates/p1.2/run_listing_session.sh` in this worktree — the P1.2
   delegate's spend-free listing session (local recorder as provider endpoint, `env -i`
   allowlist, sandbox set to the fixture workdir). Reuse it; do not rewrite it.
4. The P1.2 delegate's report (your orchestrator holds it): fixture workdir at
   `/tmp/motoko-037-p1-fixture` (rebuild with `p1.2/build_fixture.sh`), profile
   `skills_proto` (`.motoko/config/skills_proto/` in this worktree, mirrored into the
   fixture workdir), the `workdir-stamp` fixture skill (reads bundled
   `stamp-format.txt`, writes `STAMP.txt` — the shape a later model run needs).

## What you run

Two layouts, each a listing-style session reusing the recorder harness (no model calls,
no provider keys — this task needs no spend approval):

- **Layout 1 (sibling/default):** launch directory ≠ fixture workdir, workdir NOT under
  the launch dir (as P1.2 ran it: worktree root → `/tmp/motoko-037-p1-fixture`).
- **Layout 2 (subdirectory):** launch directory is the PARENT of the fixture workdir
  (e.g. copy/mirror the fixture under a temp dir you launch from, workdir = its child).

In each layout, establish and record:

1. The `Skill` description in the first provider request lists the fixture workdir's
   skills (paste it verbatim per layout, or diff it against P1.2's captured description).
2. A scripted `Skill({"name":"workdir-stamp"})` call through the real dispatcher returns
   exit 0 with the directory line `.motoko/skills/workdir-stamp` first (as P1.2's steps 0–2 did).
3. Whether a native `ReadFile` on the bundled file under that directory
   (`.motoko/skills/workdir-stamp/stamp-format.txt`) succeeds in a real session in that
   layout. If layout 2 fails here while layout 1 succeeds, that is the raised-as-own-issue
   finding — record the exact error verbatim.

Keep `AILANG_FS_SANDBOX` set to the fixture workdir (as the TUI does). Note the sandbox
setting in your report; an un-sandboxed run answers a different question than D7 asks.

## Rules that bind you

- Touch only this worktree (new scripts under `.motoko/herdr-delegates/p1.3a/`, which is
  gitignored) plus `/tmp` fixture copies. Commit nothing. Heavy runs one at a time.
- No model calls, no provider keys, no credentials in any file or output. If anything
  would cost spend, stop and report instead of running it — b–e are separate tasks with a
  separate go-ahead (Q-SPEND).

## Done when

Both layouts have an observed answer for (1)–(3) above, with the captured request bodies
and session logs kept under `.motoko/herdr-delegates/p1.3a/` for P1.N.

## What to send back

In your completed answer AND in the answer file (use WriteFile for the answer file before
replying): per layout — the `Skill` description (verbatim or diffed), the scripted-load
result, the `ReadFile`-on-bundled-file result with exact errors if any; the verdict on
Q3; HEAD plus `git status --short` / `git diff --stat`; anything that could not run and why.
