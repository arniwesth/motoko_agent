---
repo: arniwesth/motoko_agent
pr: 168
branch: arniwesth/mot-102-formalize-agent_confined-adr-acceptance-sweep-residuals
ticket: MOT-102
title: "MOT-102: the agent_confined container profile, and ADR-001 for it"
---

## Summary

Carries **the `agent_confined` container profile and the decision record for it, together** — a
second container on the working tree that VS Code cannot attach to, plus the ADR stating why each
absence is there.

The profile has been in daily use without a record. Every "why" lived either in a comment at the
point of decision or in a chronological `HISTORY.md`, and neither states a decision *as a decision*,
with its alternatives and its consequences. ADR-001 adds D1–D11 and C1–C10, leaves the measurements
in `HISTORY.md` where they belong, and records the disposition of every residual.

**The profile arrived here from #169** (`chore(devcontainer): move agent_confined out to MOT-102`).
Reviewing the boundary in one PR and the reasoning for it in another was the wrong split. No history
was rewritten to do it: #169 got a new commit removing those paths, this branch merged that commit
and kept its own tree, so nothing already pushed changed underneath anyone. #169 keeps the rest of
that work — the herdr agent-state reporter, the 018/020/021/022 records, the `linear` MCP entry and
the operator profile's compose changes.

No behaviour is changed by the ADR itself. Where the record made a decision look wrong, that is
written into Consequences and filed as an issue rather than fixed here — see MOT-106 and MOT-107.

Linear: **MOT-102** (parent), sub-issues **MOT-103**–**MOT-110**.

## Changes

- `feat`: the `agent_confined` profile — `Dockerfile`, `docker-compose.yml`, `agent.sh`, `herdr.toml`, `versions.env`, and the `checks/` sweep (R9 container legs, R7 git-configuration audit, socket probe)
- `docs`: `README.md` and `HISTORY.md` for the profile; the pointer to it from `.devcontainer/README.md`
- `docs(019)`: ADR-001, then the host-side R9 run and the authoritative R7 baseline folded into its grounding blocks
- `build`: `agent_confined_check` and `agent_confined_r7` Makefile targets
- `chore(github)`: the PR state record

16 files changed.

## Governing docs

- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md`
- `.agent/projects/019_agent_confined/HANDOFF-formalize-agent-confined.md`
- `.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md` — D1/C9 are the premises D5 and D10 build on

## Predicted outcome

Landing this should make three things answerable from the tree rather than from whoever remembers:

1. **Why each absence exists**, including the two that read as mistakes without their reasoning —
   the `GH_TOKEN` mapping that inverts 016's naming rule (D5), and the curated `environment:` block
   that is the opposite of the choice made for the operator's profile (D6).
2. **What the profile does *not* buy.** D9 states the honest limit: the tree is mounted whole, so
   agent-writable git configuration still executes as the operator on the host. An operator reading
   only the absence table would overestimate the boundary.
3. **What is still owed, and why it is owed by construction.** The host-side legs and the R7
   baseline cannot be produced by an agent inside the container it is attesting to (D11, C1).

Checked by: the residual-disposition table at the end of the ADR resolving against MOT-104…MOT-110,
and by `agent.sh check` passing end-to-end once MOT-107 is closed.

## Test evidence

Two acceptance runs, both pasted in full into the ADR's grounding blocks. Both turned up findings
that changed the work.

**R9 container-side legs** — `checks/r9-container.sh --in-container`, the first run ever inside this
profile (previously they had only been run in the operator's devcontainer, where they correctly
fail):

```
PASS  leg2: no /var/run/docker.sock · no docker binary · sudo -n true refused · six ssh binaries absent
PASS  leg3: SSH_AUTH_SOCK / REMOTE_CONTAINERS{,_IPC,_SOCKETS} / VSCODE_IPC_HOOK_CLI / GPG_AGENT_INFO unset
PASS  leg3: no ssh-auth, IPC or gpg-agent socket present
PASS  leg4: the bot token authenticates as motoko-agent
PASS  leg4: branch-protection read refused for the bot (no administration grant)
PASS  leg4: no VS Code remote-containers helper · no gho_-shaped credential
PASS  leg5: profile marker correct; all ten baked-in tools present
FAIL  leg6: host.docker.internal RESOLVES — extra_hosts was added back
R9 FAIL — 1 leg(s)
```

**Leg 6 is a defect in the leg, not in the profile.** `extra_hosts` is absent from the compose file
and `/etc/hosts` carries no entry, yet the name resolves to `0.250.250.254` — OrbStack supplies it
over DNS, as it does `gateway.docker.internal`, `host.orb.internal` and
`docker.for.mac.host.internal`. The leg's name-absence proxy cannot hold on this platform. Filed as
**MOT-107**; not fixed here, because this pass does not change behaviour.

**The same measurement falsifies the premise for removing `OBSIDIAN_MCP_TOKEN`**, which was the one
edit this handoff sanctioned. The container *can* address the host (connection **refused**, not a
timeout — the SYN was answered); nothing listens on 27200, which is host-side state. Removing a
granted token on a rationale that does not hold is a worse record than leaving it, so it was left.
The real scope question is stated for an owner decision in **MOT-106**.

**R7 git-configuration and frozen-content audit** — `checks/r7_git_audit.py`, record then verify:

```
recorded 5 git configuration files under /workspaces/motoko_agent
  .emsdk/.git/config            non-branch=7   branch=3    hooks_extra=0
  .git/config                   non-branch=11  branch=506  hooks_extra=0
  ailang/.git/config            non-branch=11  branch=12   hooks_extra=0
  deepseek-harness/.git/config  non-branch=7   branch=3    hooks_extra=3
  deepseek-harness/.git/config.worktree  non-branch=3  branch=0  hooks_extra=3

R7 f-1..f-4 PASS: 5 configuration files, hooks and frozen content match the baseline
```

Five rather than six because `code-graph/` was deleted on operator decision (**MOT-109**) during
this work; the sixth was `code-graph/lib/slicito/.git/config`. Verified before removal to be
untracked and gitignored, distinct from the tracked `tools/code-graph/`, and holding no unpushed
commits. The three non-sample hooks are attested as lefthook shims.

### Not verified, and owed by construction

`agent.sh` refuses to run inside a container (`agent.sh:154`), because an agent is the wrong party
to attest to its own confinement — D11, and C1 records this ADR as a live instance. So the
**host-side legs** (**MOT-104**) and the **authoritative R7 baseline** (**MOT-105**) are outstanding
and need a host shell. The `:ro` flags those legs assert were confirmed independently from inside,
by `mount` and a failed write.

`git filter-repo` was **not** run: history rewriting was declined by the operator (**MOT-110**).
