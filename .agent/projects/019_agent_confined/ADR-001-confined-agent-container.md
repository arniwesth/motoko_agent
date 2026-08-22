# ADR-001: What container does the agent live in, what is absent from it, and who does it act as?

Date: 2026-08-22
Status: **Accepted**, and **fully grounded** — both acceptance runs completed 2026-08-22, the
container-side halves from inside and the host-side halves by the operator (C1). Every residual is
closed or deferred with a reason. The profile is built and in daily use; this record is
retrospective. Written from inside the container it describes, in a herdr pane, as `motoko-agent`.
Grounded at: branch `arniwesth/mot-102-formalize-agent_confined-adr-acceptance-sweep-residuals`,
base `43228a57f5651d5ed22d6b0b8d6bbca76095fc99` on `arniwesth/mot-101-agentcli`

Grounding verified 2026-08-22, from inside the running `agent_confined` container
(`MOTOKO_CONTAINER_PROFILE=agent_confined`, host `d36733f423f1`, herdr pane `w1:p1`):

0. **The implementation was uncommitted when this ADR was drafted, and has since become the base
   commit.** `.devcontainer/agent_confined/` existed on no git ref (`git log --all --
   .devcontainer/agent_confined/` was empty); the profile, the herdr state reporter, and five project
   directories were all untracked or modified in one working tree at `d992d73`. The operator
   committed them as `43228a5` on `arniwesth/mot-101-agentcli` on 2026-08-22 — 11 files under
   `.devcontainer/agent_confined/`, plus `src/tui/src/herdr-agent-state.{ts,test.ts}` — and this
   branch is cut from it. Every file reference below is to that commit.
1. The three frozen binds are live and read-only, confirmed by both `mount` and a write attempt:
   ```
   mac on /workspaces/motoko_agent            type virtiofs (rw,relatime)
   mac on /workspaces/motoko_agent/.devcontainer type virtiofs (ro,relatime)
   mac on /workspaces/motoko_agent/.vscode       type virtiofs (ro,relatime)
   mac on /workspaces/motoko_agent/.git/hooks    type virtiofs (ro,relatime)

   $ touch .devcontainer/.__wtest
   touch: cannot touch '.devcontainer/.__wtest': Read-only file system
   ```
2. **R9 container-side legs — first run ever inside this profile.** See *Grounding: the R9 run*
   below for the full paste. Legs 2–5 pass; leg 6 fails, and the failure is a defect in the leg
   rather than in the profile (C7, MOT-107).
3. **R7 f-1..f-4 — record/verify round-trip passes.** See *Grounding: the R7 run* below. **Five**
   git configuration files, 506 `branch.*` entries on `.git/config`, zero shape violations,
   `hooks_extra=3` on `deepseek-harness` alone. It was **six** until `code-graph/` was deleted on
   operator decision the same day (C9); the sixth was `code-graph/lib/slicito/.git/config`, and its
   removal returns the count to the five an earlier survey recorded.
4. **The host-side legs are verified**, by the operator from a host shell on 2026-08-22 —
   `agent.sh check` driven end to end through the wrapper, against the running service. All ten
   host-side assertions pass, including leg 1. `agent.sh` refuses to run inside a container by
   design (`agent.sh:154`), so this half could not be produced from inside; see C1. Full paste
   below.
5. `versions.env` reads `HERDR_VERSION=0.8.2`, `AGENT_BROWSER_VERSION=0.34.0`,
   `CLAUDE_CODE_VERSION=2.1.239`, `CODEX_VERSION=0.149.0`, `OMP_VERSION=17.4.2`, resolved
   2026-08-22, with both herdr sha256s recorded.
6. `gh --version` in the image is `2.97.0 (2026-07-31)`; `gh api user --jq .login` answers
   `motoko-agent`; `git config user.name` is `motoko-agent`; `git config credential.helper` is
   `!gh auth git-credential`.

Relates to:
- `.devcontainer/agent_confined/HISTORY.md` — **the measurement record, and the primary source for
  this ADR.** It is chronological and holds the numbers: the 11.68 GB → 17.9 MB build context, the
  `SUDO_FORCE_REMOVE` refusal, the macOS bash-3.2 floor, the `extra_hosts` correction, the browser
  attempt and its removal, the `ldd` 19-library list, the herdr.dev 403. This ADR states **what** was
  decided and **why**; read HISTORY for *how it was measured*. Nothing here restates a measurement
  that lives there.
- `.devcontainer/agent_confined/README.md` — the operator-facing view: quick start, the absence
  table, *Operating rules*, *Known gaps*.
- `../016_github_ops/ADR-001-github-pr-ops-pipeline.md` — **D1 (identity follows agency) and C9 (a
  separate machine user)** are the premises D5 and D10 build on. `tools/pr/README.md` states the
  rule this profile makes true by construction rather than by discipline.
- `../018_agentcli_delegation/` — the consumer of D4. herdr's pane/agent surface is the delegation
  mechanism that project wants, with no integration code.
- `../020_herdr_agent_integration/ADR-001-herdr-agent-integration.md` — how Motoko reports its own
  lifecycle state to herdr, which is what makes it a first-class agent in the sidebar.
- `../022_linear_integration/RESEARCH-linear-integration.md` — **F-1 is an open dependency of D6.**
  `LINEAR_API_KEY` is in the curated environment, so a delegate in a pane acts as that key's owner.
  The Linear issues tracking this ADR were themselves filed that way.

---

## Context

Attaching VS Code to a container is not a neutral act. It is the mechanism that injects the
operator's GitHub credential and their ssh-agent socket into the container's UID. Measured inside
motoko's own devcontainer on 2026-08-22, with the checks in `.devcontainer/agent_confined/checks/`:

```
FAIL  leg2: sudo -n true SUCCEEDED
FAIL  leg3: SSH_AUTH_SOCK / REMOTE_CONTAINERS_IPC / REMOTE_CONTAINERS_SOCKETS / VSCODE_IPC_HOOK_CLI are set
FAIL  leg3: forwarded socket file(s) exist: /tmp/vscode-ssh-auth-….sock, …ipc-….sock, ~/.gnupg/S.gpg-agent
FAIL  leg4: a VS Code remote-containers helper is configured
FAIL  leg4: git credential fill returns a gho_-shaped value
FAIL  leg6: host.docker.internal resolves
```

The fifth line is the one that forced the question. A `gho_` value is a GitHub **OAuth app access
token for the operator's own account** — not a scoped PAT — and in the attached container it is
*live*, not merely announced: `git credential fill` returns it. The forwarded ssh-agent answered as
a **conduit** (0 identities) and the extension-created gpg socket was **dead**, so neither was an
oracle that day; but one `ssh-add` on the host re-arms the first with no signal inside the
container, which is why absence rather than emptiness is the thing worth asserting.

An agent running in that container can therefore act as the operator on GitHub, and — with
`NOPASSWD: ALL` — can install whatever else it needs to. Every absence in this profile follows from
removing that, plus one rule that makes the absences stick: **an agent that cannot install anything
cannot undo an absence.**

The counterweight, stated here rather than buried in Consequences because the list of absences will
otherwise oversell what was bought: **confining a container does not confine the tree.** D9 is that
decision, and it is the honest limit on everything else.

---

## Options considered

| | option | why not |
|---|---|---|
| **A** | Harden the existing devcontainer in place — drop the sudoers file, stop attaching | VS Code attach *is* what forwards the credential, and attach is what provides the editor. Hardening it to the point of safety leaves a container nobody would open. This is not rejected so much as deferred and then re-scoped by D10; see C8 and MOT-108. |
| **B** | One container, careful habits — keep attaching, remember not to act as the operator | Makes every isolation claim a matter of discipline. The failure mode is silent: a commit lands under the wrong name with no warning, and nothing checks. |
| **C** | A second, unattachable container on the same tree | **Chosen.** Additive, so nothing existing breaks; the absences are properties of the compose file rather than of habit; and they are regression-testable by named legs that fail loudly. |
| **D** | A second container on an isolated *copy* of the tree | Closes D9's gap — the one real limit of option C — at the cost of the thing the whole arrangement is for: a human and an agent looking at the same working tree. Left open as the `herdr worktree` question, not taken. |

For the session layer specifically, `tmux` and `herdr` were both available. tmux needed a
from-source build for synchronized output plus a substantial config to make mouse handling behave
with agent TUIs, and delivered a session layer and nothing else. See D4.

---

## Decisions

### D1 — The profile carries no `devcontainer.json`, and the container is never attached

This is the load-bearing decision; every other absence is downstream of it. VS Code's picker lists
only profiles that have a `devcontainer.json`, so `agent_confined` is invisible to it while
`.devcontainer/default` is listed. This is a **compose service**, not a dev container.

`checks/r9-container.sh` leg 1 asserts the file's absence, and separately asserts that no other
profile's `devcontainer.json` references this one. Without leg 1 the whole sweep is voluntary: a
`devcontainer.json` beside the compose file makes the service attachable, and legs 3 and 4 then
describe a habit rather than a configuration.

**Alternatives:** add one and simply not use it (rejected — the file is the capability, and nothing
would detect its use); add one with a restricted feature set (rejected — the credential helper and
socket forwarding come from the Dev Containers extension, not from the file's contents).

**The deliberate exception, because "never" invites a workaround.** If attaching is genuinely
required: stop every agent process, attach, do the thing, detach, then **discard the container**
(`agent.sh stop && agent.sh`) rather than reusing it — the forwarded helper and sockets live in the
container — and re-run `agent.sh check` before restarting the agent.

### D2 — No `sudo` in the final image, purged and asserted at build time

`apt-get purge sudo`, followed by `! command -v sudo` as a build-time assertion
(`Dockerfile:130-134`). The assertion is the point: a purge that silently failed would produce an
unconfined image that looks confined.

dpkg refuses the removal unless `SUDO_FORCE_REMOVE=yes` is set, because sudo's `prerm` guards
against a human locking themselves out of a machine with no root password. That premise is false
here — the container is disposable, and the operator reaches root with `docker exec -u root` from
the host whenever they need to — so the override is correct rather than a workaround. It should not
be copied into an image somebody logs into.

**The consequence is the reason for a large image**, and it is intended: with no `sudo`, every new
tool is an operator-side rebuild. That is why herdr, the three agent CLIs, `agent-browser` and
Chromium, and motoko's whole toolchain (Go, Bun, Node, DuckDB, Z3, `gh`, AILANG at its pinned tag)
are baked in rather than installed on demand.

`security_opt: no-new-privileges:true` is set as well. Since this image ships no sudoers drop-in it
is defence in depth against a future image edit, not the primary control.

### D3 — No ssh client or server, no docker socket or CLI, no host credential mounts

Three absences with one rationale each, all asserted by R9 leg 2 and the compose file's own
absence list:

- **`openssh-client` / `openssh-server`.** An ssh-agent socket or key is a GitHub-independent push
  path as the operator — one that a bot-token policy does not bound. Nothing here can use SSH git;
  HTTPS with the bot token is the only route (D5). herdr's own documented remote paths are both SSH
  and neither is used: `docker exec` is the client transport, so the authentication is the host
  docker socket, which the operator holds and the agent does not. There is no `ForwardAgent` to
  forget.
- **`/var/run/docker.sock` and the `docker` CLI.** `docker run -v /:/host` is host root. Nothing
  else about the profile survives that.
- **Host credential mounts** (`~/.config/gcloud`, `~/.ssh`, `~/.claude`). Each hands the operator's
  host credentials straight back to the agent.

**Accepted cost:** `/home/motoko` is not mounted, so a `claude` or `codex` *subscription* login does
not survive `agent.sh stop` or `agent.sh build`. That is a security property — a rebuilt container
holds no credential until given one — but it is a chore if you log in rather than using API keys.
The opt-in (two named volumes) is written out in `docker-compose.yml` so that taking it is one edit
rather than a design session. Nobody has taken it.

### D4 — herdr is the session layer, driven over `docker exec`

[herdr](https://herdr.dev) 0.8.2 — one Rust binary, Apache-2.0, client/server — replaces what would
otherwise be tmux. It buys three things beyond session parity:

- **A delegation surface with no integration code.** `herdr pane split` / `pane run` start an agent;
  `herdr agent list|read|prompt --wait --until idle|wait` observe and drive it; and a human can watch
  and type into the same pane. That last property is what a scraping-based controller cannot give.
- **Structured output.** `herdr terminal session observe|control` emit newline-delimited JSON frames
  with base64 ANSI — a real bridge for any future web view, rather than screen-scraping.
- **Motoko is a first-class agent in it** (020): it reports `working`/`idle`/`blocked` as a
  *lifecycle authority*, so herdr takes Motoko's word rather than pattern-matching the pane.

**Two herdr defaults were changed rather than accepted.** `update.version_check` and `manifest_check`
reach herdr.dev in the background; both are off in `herdr.toml`, because what herdr believes about an
agent's state should not change under a running container with no record of when.

**Stated plainly so it is not mistaken for a control:** `herdr update` writes to `~/.local/bin`,
which the agent can write and which is *earlier* on `PATH` than the root-owned `/usr/local/bin` copy.
Installing herdr as root is a speed bump, not a boundary. The same is true of `GH_PROMPT_DISABLED=1`.

**`herdr worktree create` is available and deliberately not adopted:** its default directory is
`~/.herdr`, which nothing mounts, so a checkout there dies with the container. `herdr.toml` says so
rather than quietly repointing it. Two agents therefore share one worktree — see C6.

### D5 — The agent's GitHub identity is `motoko-agent`, by construction

016 ADR-001 D1 says identity follows agency and C9 gives the mechanism: a separate machine user, so
that *anything the pipeline emits is the bot; anything done by hand in the web UI is you* is
readable off an author field.

This profile makes that true by construction rather than by remembering, in three parts, all baked
into the image or the compose file:

1. `GH_TOKEN: ${MOTOKO_BOT_GH_TOKEN:-}` in `docker-compose.yml`.
2. `credential.helper = !gh auth git-credential`, so `git push` resolves from `GH_TOKEN` and needs
   no stored credential and no interactive login. No secret is baked into the image; the token
   arrives at run time.
3. `user.name = motoko-agent`, `user.email = motoko-agent@users.noreply.github.com`.

**Point 1 inverts a rule elsewhere in this repository, and the inversion is deliberate.** 016
ADR-001 gives the bot credential a distinct name — `MOTOKO_BOT_GH_TOKEN`, never `GH_TOKEN` —
precisely because `gh` silently prefers `GH_TOKEN` over the credentials `gh auth login` stored. Under
that name, the **operator's own** `gh` would quietly run as the bot. That rule protects a container
the operator and the agent *share*.

They share no such container here. Nothing but the agent runs in this one, so there is no operator
`gh` to mislead, and D1 leaves no way to attach one. Mapping the value into `GH_TOKEN` is therefore
the correct configuration for this profile **and only for this profile**. Read the compose comment
before copying the line anywhere else.

**R9 leg 4 was inverted to match, and this is worth not skipping.** The leg previously asserted that
`GH_TOKEN` was *unset* — the operator container's concern, mirrored into a profile where it is
exactly backwards. It now fails when `GH_TOKEN` is missing, checks that the token resolves to
`motoko-agent`, asserts the credential helper and `user.name`, and carries a **negative probe**: the
bot must be *refused* a branch-protection read, since success would mean the credential holds
`administration` and is over-scoped for a machine user. A check that asserts the opposite of the
intended configuration is worse than no check.

**Known and left as-is:** the email is the short noreply form. GitHub's canonical modern form is
`<id>+<login>@users.noreply.github.com`, and commits only link to the bot's profile with that one.
Left short rather than guessing an id.

### D6 — A curated `environment:` list, not `env_file:`

The compose file names each variable the container receives, rather than passing `.env` wholesale.

**Be clear about what this buys, because it is easy to overstate.** Motoko reads
`/workspaces/motoko_agent/.env` itself at start-up (`src/tui/src/index.ts`, `loadDotEnv`), and that
file is on the bind mount — so Motoko holds every secret the file carries whatever this list says.
Curating it is not a boundary against Motoko.

**What it does bound is a delegate.** `codex` and `claude` do not read `.env`; they read the
environment. So the list is exactly what a delegate in a pane inherits. Switching to `env_file`
would newly hand every delegate `CH_HOST`, `CH_USER`, `CH_PASS`, `CH_DB`, `CH_AUTO_SYNC`,
`CLICKSTACK_INGESTION_KEY`, `FIREWORKS_API_KEY`, `DEEP_INFRA_API_KEY`, `HF` and `PI_CODING_AGENT_DIR`
— two production database credentials and three metered API keys — in the container that exists to
be the boundary.

**The opposite choice was correct for the operator's profile**, and the general rule is worth
stating: *a curated list is only worth having where the invocation is yours.* This profile controls
its own invocation (`agent.sh:291` passes `--env-file "${REPO_ROOT}/.env"` on the command line, so
interpolation resolves). The Dev Containers profile does not control its invocation, and its curated
list silently resolved empty — Compose interpolates from a `.env` in the *compose file's* directory,
and `.devcontainer/.env` does not exist — so there, taking the file was the fix.

**`LINEAR_API_KEY` is in the list and its consumer is not Motoko.** Motoko has no Linear access at
all (022). What consumes it is a `claude` delegate in a pane: `.mcp.json` is project-scoped and on
the bind mount, so a delegate picks up the `linear` server and gets issue write access **acting as
this key's owner**. That is 022's F-1 arriving through the delegate rather than by decision. Granted
deliberately by the owner on 2026-08-22; revisit when F-1 is answered.

### D7 — Versions are pinned in the tree, and `upgrade` is a separate verb from `build`

`versions.env` carries herdr's version and both per-architecture sha256s plus the three CLI
versions, and is committed. `agent.sh` reads it on every command and passes the values as build args.

The mechanism matters and is not obvious: `RUN bun install -g …@latest` inside a Dockerfile does
**not** track latest. The instruction text never changes, so Docker reuses the cached layer and the
image keeps whatever was current the day it was first built, indefinitely and invisibly. A build arg
whose *value* changes is what invalidates the layer. The compose file therefore declares each arg
with `${…:?}` and no default, so a bare `docker compose build` **fails** rather than silently
producing an unpinned image.

Two consequences, both intended:

- **`stop`, `sessions`, `logs` and `build` work with no network**, because nothing is resolved at run
  time.
- **An upgrade is a commit.** `agent.sh upgrade` re-resolves every line from upstream, prints the
  diff, rewrites the file and rebuilds. That diff is the record of what the agent now runs, so
  *"which harness is in the image"* is answerable from `git log` rather than from whoever last built.
  `build` never re-resolves.

**Two pins are deliberately outside `upgrade`'s reach**: Playwright's Chromium revision (a floating
browser would move under a measurement) and the herdr sidebar plugin's tag. The sidebar is
third-party code that executes inside the container holding the working tree, the API keys and a
token with the bot's push rights; `herdr plugin install` normally shows a source preview for review,
and a build-time install would have to pass `--yes` and skip it for ever. **The pin is the review
boundary**, and bumping it should mean someone read the diff.

### D8 — `.devcontainer`, `.vscode` and `.git/hooks` are mounted read-only

```yaml
- ../../.git/hooks:/workspaces/motoko_agent/.git/hooks:ro
- ../../.vscode:/workspaces/motoko_agent/.vscode:ro
- ../../.devcontainer:/workspaces/motoko_agent/.devcontainer:ro
```

R9 asserts both that each bind source **exists** and that it is declared `:ro`. Existence matters
independently: a missing source is created empty by `create_host_path` and mounts over nothing,
which is an absence that looks like a control.

`.devcontainer` is the important one: it holds this profile's own definition and its checks. An
agent that can rewrite its own confinement has none.

`.git/hooks` is **defence in depth, not a boundary** — `core.hooksPath` in the agent-writable
`.git/config` redirects hook lookup anywhere, which is why the R7 audit asserts that key rather than
trusting the mount. Nested gitdirs (`ailang/`, `.emsdk/`, `deepseek-harness/`) are not frozen; the
R7 audit covers all five configuration files and their hook inventories instead.

**Operational consequence, stated because it bites:** a `git checkout` between branches whose content
differs under those paths fails part-way with `EROFS`. Do that from the host or the devcontainer.

### D9 — The tree is mounted whole, and that is deliberate: what is *not* absent

D3's table relocates **host-side** credentials. It does not withhold **in-tree** ones, and an
operator who reads only that table will overestimate the boundary. Three things stay reachable:

- **Agent-writable git configuration, which executes on the host as the operator.**
  `/workspaces/motoko_agent` is one host directory, so confining a compose service confines no part
  of it. Every host-side git command the operator runs consults configuration this container can
  write, and the exec-or-credential family in those files — `[alias] x = !cmd`, `core.hooksPath`,
  `include.path`/`includeIf`, `remote.<n>.url = ext::<cmd>`, `branch.<n>.remote` (which accepts a
  URL, not only a remote name), `core.pager`, `diff.external`, `filter.*.clean/smudge`, `gpg.program`,
  `credential.helper` — runs **as the operator, on the host: outside `no-new-privileges`, outside the
  `:ro` binds, outside the container.** `credential.helper` is the worst member because it defeats not
  just revocation but **rotation**: a fresh token is captured on first use.
  **`checks/r7_git_audit.py` is the only thing in this profile that addresses that channel**, and it
  is the check that matters most here. Measured: five configuration files, four of them belonging to
  three gitignored nested repositories (`ailang/`, `.emsdk/`, `deepseek-harness/`), so a change
  inside any of those is invisible to the parent's `git status`.
- **In-tree credentials.** `.env` is on the bind mount and Motoko reads it directly (D6). Closing
  this properly means not mounting `.env`, which means Motoko cannot read it either.
- **One worktree, two agents.** A delegate writing in Motoko's tree leaves changes indistinguishable
  from Motoko's. A container boundary does nothing about that (D4).

Recording this as a decision rather than a gap is the point: the alternative — an isolated copy of
the tree (option D) — was considered and not taken, because a human and an agent looking at the same
files is the thing the arrangement is for.

### D10 — All work happens in this container; the devcontainer is kept, narrowed to reading and review

Operator decision, 2026-08-22. This is what the rest of the profile was building towards, and it is
two decisions rather than one.

**Four places, one job each:**

| where | for | identity |
|---|---|---|
| **the confined container** | all work — commits, pushes, PRs, agents, delegates | `motoko-agent`, by construction |
| **the devcontainer** | reading, rendered markdown, diff review, VS Code tooling | the operator — so do not commit from it |
| **a host shell** | `agent.sh`, and every edit to `.devcontainer/**` | n/a |
| **GitHub's web UI** | human review and approval | the operator |

**D10a — identity fully collapses onto the bot.** With no work happening outside, every commit and
every PR carries `motoko-agent`. 016 anticipated exactly this; `tools/pr/README.md` already reads:

> because both halves now carry the bot's name, identity no longer tells you whether a human decided
> something — that has to come from the state record.

That sentence stops being a caveat and becomes load-bearing. **`.agent/github/` is now the only place
in the repository where the human/mechanism distinction survives**, along with GitHub's web UI, where
the operator still acts as themselves. This is the strongest argument for keeping that record
accurate, and it is why a history rewrite is expensive (MOT-110).

**D10b — the devcontainer is kept on purpose, and keeping it keeps its exposure.** It is not a
fallback working environment; its job is reading and reviewing. Two costs, both accepted:

- **Committing from it silently reintroduces the operator's name.** Nothing warns. This is the one
  way to break D10a, and it is a habit rather than a configuration — the only such thing left in the
  arrangement.
- **It still has passwordless sudo, the forwarded ssh-agent socket, and a live `gho_` credential
  helper, on the same tree.** That is the accepted price of a usable editor, and it is exactly why
  the agent does not live there. Recording it as a decision rather than leaving it as an accident of
  history is the point. See C8 and MOT-108.

### D11 — The profile cannot be maintained from inside itself, and the carve-out is deliberate

D8 mounts `.devcontainer/**` read-only, and this profile lives there. So D10's *"all work happens
here"* has an exception that is not optional: **every edit to the `Dockerfile`, `docker-compose.yml`,
`agent.sh`, `herdr.toml`, `versions.env` or `checks/**` — and `agent.sh build` itself — requires a
host shell.** `agent.sh` enforces the second half independently, refusing to run inside any container
(`agent.sh:154`, on `REMOTE_CONTAINERS` or `/.dockerenv`).

This is by design and follows directly from D8: an agent that can rewrite its own confinement has
none, and an agent that can rebuild its own image can put anything in it. But it means the policy has
a carve-out, and a carve-out belongs in the record rather than in folklore — including the trap it
implies, the `EROFS` branch switch in D8.

**It also bounds what an agent can verify about itself**, which is a feature: R9's host-side legs and
the R7 baseline are assigned to a human on the host precisely because they are statements about a
container's definition and a tree's contents, both of which a compromised agent inside would
misreport. This ADR is a live instance — see C1.

---

## Grounding: the R9 run

Two runs, both 2026-08-22. The container-side legs were run first from inside a herdr pane
(`checks/r9-container.sh --in-container`) — **the first time they had ever run inside this
profile**, previously having been run only in the operator's devcontainer, where they correctly
fail. The operator then drove the full sweep through the wrapper from a host shell
(`agent.sh check`), which runs the host-side legs and re-invokes the container-side legs inside the
service. **The container-side results were identical across both runs.**

### Host-side legs — `agent.sh check`, from a host shell

```
R9 (host-side legs)  repo=/Users/<operator>/Projects2/private/motoko_agent
  PASS  leg1: no devcontainer.json in the agent_confined profile
  PASS  leg1: no .devcontainer/*/devcontainer.json references the profile
  PASS  mounts: bind source exists — .git/hooks
  PASS  mounts: .git/hooks declared :ro
  PASS  mounts: bind source exists — .vscode
  PASS  mounts: .vscode declared :ro
  PASS  mounts: bind source exists — .devcontainer
  PASS  mounts: .devcontainer declared :ro
  PASS  pins: versions.env present (7 pinned values)
  PASS  env: <repo>/.env present (compose interpolates the environment block from it)
```

**Leg 1 is the one that matters most** (D1): the profile carries no `devcontainer.json`, and no other
profile's `devcontainer.json` references its service. Without that, legs 3 and 4 would describe a
habit rather than a configuration. The three `:ro` declarations are confirmed here as read *from the
compose file*, which complements the independent confirmation from inside the container by `mount`
and a failed write (Grounding item 1) — the definition and the running reality agree.

### Container-side legs

```
R9 (container-side legs)
  PASS  leg2: no /var/run/docker.sock
  PASS  leg2: no docker binary on PATH
  PASS  leg2: sudo -n true refused
  PASS  leg2: ssh absent
  PASS  leg2: sshd absent
  PASS  leg2: ssh-add absent
  PASS  leg2: ssh-agent absent
  PASS  leg2: ssh-keygen absent
  PASS  leg2: scp absent
  PASS  leg3: SSH_AUTH_SOCK unset
  PASS  leg3: REMOTE_CONTAINERS unset
  PASS  leg3: REMOTE_CONTAINERS_IPC unset
  PASS  leg3: REMOTE_CONTAINERS_SOCKETS unset
  PASS  leg3: VSCODE_IPC_HOOK_CLI unset
  PASS  leg3: GPG_AGENT_INFO unset
  PASS  leg3: no ssh-auth, IPC or gpg-agent socket present
  PASS  leg4: gh present (gh version 2.97.0 (2026-07-31))
  PASS  leg4: GH_TOKEN is set (mapped from MOTOKO_BOT_GH_TOKEN for this profile)
  PASS  leg4: MOTOKO_BOT_GH_TOKEN present
  PASS  leg4: the bot token authenticates as motoko-agent
  PASS  leg4: branch-protection read refused for the bot (no administration grant)
  PASS  leg4: git credential.helper delegates to gh (so push uses the same identity)
  PASS  leg4: git commits are authored as motoko-agent
  PASS  leg4: no VS Code remote-containers helper configured
  PASS  leg4: no gho_-shaped credential returned for github.com
  PASS  leg5: MOTOKO_CONTAINER_PROFILE=agent_confined
  PASS  leg5: herdr present
  PASS  leg5: agent-browser present
  PASS  leg5: chromium present
  PASS  leg5: claude present
  PASS  leg5: codex present
  PASS  leg5: omp present
  PASS  leg5: bun present
  PASS  leg5: go present
  PASS  leg5: ailang present
  PASS  leg5: gh present
  FAIL  leg6: host.docker.internal RESOLVES — extra_hosts was added back (see docker-compose.yml)
  ----  leg6: 0.250.250.254 ANSWERS (refused, not a timeout) — egress to it is not blocked
  ----  leg6: 192.168.65.254 ANSWERS (refused, not a timeout) — egress to it is not blocked
  ----  leg6: 192.168.117.1 ANSWERS (refused, not a timeout) — egress to it is not blocked

R9 FAIL — 1 leg(s)
EXIT=1
```

**Every assertion D1–D5 makes about this container is confirmed.** The one failure is leg 6, and it
is a defect in the leg rather than in the profile — see C7 and MOT-107.

**Acceptance criterion 2 is met by the host run**: the sweep was driven end to end through the
wrapper, with the container-side legs attempted rather than skipped — not the vacuous exit-2 the
`R9 INCOMPLETE` status exists to report. The only failure in either half is leg 6.

**One cosmetic wrinkle in the wrapper, worth knowing before someone reads it as two failures.** The
host run prints `R9 FAIL — 1 leg(s)` **twice**: once from the container-side invocation's own
`main()`, and once from the host wrapper, which folds the child's exit status into its own `fails`
counter and then prints its own summary. One failing leg, reported twice. Not chased here — this
pass does not change behaviour — but it belongs with MOT-107, since anyone fixing leg 6 will be
looking at exactly this output.

## Grounding: the R7 run

`checks/r7_git_audit.py --record` to a scratch path outside the repository, then `--verify` against
it. Run 2026-08-22 from inside the container. This is a **round-trip proof that the audit works on
this tree**, not the authoritative baseline — see C1.

```
recorded 5 git configuration files under /workspaces/motoko_agent
  .emsdk/.git/config                      non-branch=7    branch=3     hooks_extra=0
  .git/config                             non-branch=11   branch=506   hooks_extra=0
  ailang/.git/config                      non-branch=11   branch=12    hooks_extra=0
  deepseek-harness/.git/config            non-branch=7    branch=3     hooks_extra=3
  deepseek-harness/.git/config.worktree   non-branch=3    branch=0     hooks_extra=3
  f-3 .vscode                             files=5
  f-4 .devcontainer                       files=18
  f-4 .gitmodules                         files=0
  f-4 harness config                      files=7

R7 f-1..f-4 PASS: 5 configuration files, hooks and frozen content match the baseline
EXIT=0
```

**This is the post-deletion inventory.** The run before `code-graph/` was removed reported the same
result over **six** files, the extra one being `code-graph/lib/slicito/.git/config` (`non-branch=7`,
`branch=3`, `hooks_extra=0`) — a clean clone of a public upstream with no unpushed commits. Both runs
passed; the deletion changed the inventory, not the verdict.

### The authoritative baseline, recorded on the host

Recorded and verified by the operator from a host shell on 2026-08-22, to `~/r7-baseline.json`:

```
recorded 5 git configuration files under <repo>
  .emsdk/.git/config                      non-branch=7    branch=3     hooks_extra=0
  .git/config                             non-branch=11   branch=509   hooks_extra=0
  ailang/.git/config                      non-branch=11   branch=12    hooks_extra=0
  deepseek-harness/.git/config            non-branch=7    branch=3     hooks_extra=3
  deepseek-harness/.git/config.worktree   non-branch=3    branch=0     hooks_extra=3
  f-3 .vscode                             files=5
  f-4 .devcontainer                       files=18
  f-4 .gitmodules                         files=0
  f-4 harness config                      files=7
baseline written to ~/r7-baseline.json

R7 f-1..f-4 PASS: 5 configuration files, hooks and frozen content match the baseline
```

**`branch=509` here against `branch=506` in the in-container run, and the difference is the point.**
The three extra entries are this ADR's own branch: `branch.<n>.remote`, `branch.<n>.merge` and a
`vscode-merge-base`, written by creating and tracking
`arniwesth/mot-102-formalize-agent_confined-adr-acceptance-sweep-residuals`. Zero shape violations in
either run. **This is the clearest available demonstration that f-1(2) is a typed expectation rather
than a snapshot** — ordinary work moved the count by three and the audit did not blink, which is
exactly the property that makes it something you can leave switched on. A snapshot-equality check
would have false-failed on a branch being created, and the README's rule — *do not loosen a clause
because it fails* — only survives if the clauses do not false-fail in the first place.

Every other count is byte-identical across the container and host runs, including all four frozen
content sets.

**Attestation of the three non-sample hooks**, per the audit's own instruction to read the
`hooks_extra` counts rather than trust the file: `deepseek-harness/.git/hooks/{pre-commit,
pre-merge-commit,pre-push}` are lefthook shims — `#!/bin/sh` followed by a `LEFTHOOK_VERBOSE` guard —
dispatching to a vendored lefthook binary. Verified by reading all three, 2026-08-22. Every other
gitdir reports `hooks_extra=0`.

---

## Consequences

**C1 — This ADR cannot fully ground itself, and that is D11 working correctly.** The container-side
legs were run by the agent, inside the container they describe; an agent is the wrong party to
attest to its own confinement, so the host-side legs and the authoritative R7 baseline are assigned
to a human on the host. **The host run has since been supplied** (MOT-104, closed), and it is worth
noting what that added rather than merely duplicated: leg 1 — the absence of a `devcontainer.json`,
which D1 rests on — is *only* assertable from outside, and the `:ro` declarations were confirmed as
written in the compose file rather than merely as observed at runtime. The definition and the
running reality agree.

**One acceptance item remains open by construction**: MOT-105, the R7 baseline, which must be
recorded on the host from a sanitised tree (C2). The ADR states this rather than pasting an exit-2
and calling it a pass — `checks/r9-container.sh` exits `2` and prints `R9 INCOMPLETE` for exactly
that reason, and `2` means *not verified*, never *pass*.

**C2 — The R7 baseline has a home problem, and it is a consequence of D3.** The baseline must live
outside the repository (it is the thing the repository is checked against) and it must persist. The
confined container's `$HOME` satisfies neither: nothing mounts `/home/motoko`, so a baseline recorded
there dies with the next `agent.sh build`. **Recorded on the host at `~/r7-baseline.json`, 2026-08-22,
and `--verify` passes against it** (MOT-105, closed).

Two gates had to clear first, and both are worth stating because they recur every time it is
re-recorded. **The tree must be sanitised** — a baseline taken over a planted directive approves it
for ever — so it could not be taken while `.mcp.json`, `Makefile` and `.devcontainer/**`, all in the
f-4 frozen set, were uncommitted. **And the inventory must be settled**: recording before
`code-graph/` was deleted would have frozen six configuration files and false-failed immediately
afterwards.

**Re-record after any approved change** under `.devcontainer/**`, `.vscode/**`, `.claude/**`,
`.mcp.json`, `AGENTS.md` or `.agent/tools/**`, noting why in the change. Editing this profile changes
that inventory every time — which means D11's host-shell carve-out and this re-recording obligation
are the same piece of work, and are best done together.

**C3 — D8 makes routine work fail in a surprising way.** A `git checkout` between branches whose
content differs under `.devcontainer`, `.vscode` or `.git/hooks` fails part-way with `EROFS`,
leaving the tree half-switched. There is no fix inside the container; do it from the host or the
devcontainer.

**C4 — D2 makes the image large and every tool addition an operator-side rebuild.** This is the
intended trade — an agent that cannot install anything cannot undo an absence — but it means the
list of baked-in tools is a design decision that gets revisited every time something is missing, and
the revisiting happens on the host.

**C5 — D5 and D10a together mean git authorship no longer distinguishes a human from a mechanism.**
Everything is `motoko-agent`. `.agent/github/` and GitHub's web UI are the only remaining places the
distinction lives. Two things follow: that record has to be maintained to stay meaningful, and
anything that would invalidate it — notably a history rewrite, since it keys off commit SHAs — costs
more than it appears to (MOT-110).

**C6 — D4's worktree question is open.** Two agents share one worktree, so a delegate's writes are
indistinguishable from Motoko's. `herdr worktree create` would fix it in one command but its default
directory does not survive a rebuild. Not decided here.

**C7 — R9 leg 6 cannot pass on OrbStack, and the profile's `extra_hosts` reasoning needs a third
correction.** Measured 2026-08-22: `extra_hosts` is absent from this compose file and `/etc/hosts`
carries no entry for the name, yet `host.docker.internal` resolves to `0.250.250.254`. OrbStack
supplies it over **DNS** — as it also supplies `gateway.docker.internal`, `host.orb.internal` and
`docker.for.mac.host.internal`. Leg 6 tests the name's absence as a proxy for *"`extra_hosts` was
added back"*, and on this platform that proxy is invalid: the name is there whatever the compose file
says.

This is the third instance of one confusion. The leg was already narrowed twice on 2026-08-22, after
it claimed to test a *route* while testing a *name*; the reachability half was then correctly demoted
to `info`. What remained was the name check, retained on the grounds that it *"still detects
`extra_hosts` being added back"* — and that is the claim measurement has now falsified.

**It follows that the stated cost of dropping `extra_hosts` is also wrong.** The absence table says
the obsidian MCP server is unreachable from here *"because it is addressed by name"*. The name
resolves and the address is routable (connection **refused**, not a timeout — the SYN was answered).
Nothing is listening on 27200 at the moment of measurement, which is host-side state, not a container
boundary. **So `OBSIDIAN_MCP_TOKEN` was not removed**, though the handoff sanctioned it: it was
sanctioned on a premise that does not hold, and removing a granted token on a false rationale is a
worse record than leaving it. The real question — should a delegate hold an Obsidian token at all,
reachability aside — is a scope argument that stands on its own and is now stated for an owner
decision. MOT-106 and MOT-107; neither is fixed here, because this pass does not change behaviour.

**C8 — the devcontainer's exposure is now a standing accepted risk rather than a transitional one**
(D10b). Passwordless sudo, the forwarded ssh-agent socket, and a live `gho_` credential helper, on
the same tree. The argument for keeping it: VS Code attach is the mechanism that forwards the
credential *and* the mechanism that provides the editor, so hardening it mostly means giving up the
thing it is being kept for. The argument against: it bounds every absence this profile establishes,
since an attacker with either container reaches the same tree. What would change if it were hardened:
removing the NOPASSWD drop-in is cheap and independent; removing the credential forwarding is not,
because it comes with attach — so a hardened devcontainer is largely one you no longer attach to,
which is this profile, and there would then be no reading environment. **Not fixed; the operator
chooses.** MOT-108.

**C9 — the two operator decisions were taken on 2026-08-22, and they went opposite ways.**

**`code-graph/` is deleted (MOT-109).** Untracked, gitignored at `.gitignore:56`, 105 MB, 1004 files.
Verified before removal to be distinct from the tracked `tools/code-graph/` (79 tracked files, 793 MB,
untouched), and its one nested repository — a clone of a public upstream — was checked for unpushed
commits and had none. **The R7 consequence is the part to carry forward:** the audit now walks five
configuration files rather than six, so the baseline owed under MOT-105 must be recorded *after* this
deletion, and any baseline predating it would false-fail. `git status` is unchanged by the removal,
because the directory was gitignored.

**Git history is NOT being rewritten (MOT-110).** Operator decision: the removed terms stay in the
roughly ten commits that carry them, on both remotes. This is the right call on the evidence in C5 —
`.agent/github/` keys its records off commit SHAs and is, after D10a, the only place in the repository
where the human/mechanism distinction survives. A `filter-repo` pass would change every SHA, break
that record, invalidate every clone and rewrite PR refs on two remotes, in exchange for scrubbing a
name from history that the working tree no longer carries. Recorded as decided rather than open, so
it is not re-litigated.

**C10 — `no-new-privileges:true` has a cost that shows up in unrelated places.** It neuters setuid,
so Chromium's SUID sandbox cannot function here and `agent-browser` runs `--no-sandbox`. **The
container is therefore the only boundary for that browser** — a container holding the working tree
and the compose environment's keys. Do not point it at untrusted pages. The same constraint will
apply to any future browser.

---

## Residual disposition

| # | residual | disposition | issue |
|---|---|---|---|
| 1 | No R7 baseline recorded | **Closed.** Recorded on the host at `~/r7-baseline.json` from a sanitised, post-deletion tree; `--verify` PASSes against it. Command and location documented in C2. | MOT-105 |
| 2 | `OBSIDIAN_MCP_TOKEN` granted to a container that cannot reach the server | **Deferred, premise falsified.** The container *can* address the host; the token was not removed on a false rationale. The real scope question is stated for an owner decision. | MOT-106 |
| 3 | `agent.sh check` has never passed end-to-end | **Run end-to-end and recorded** (MOT-104, closed): all ten host legs pass, container legs 2–5 pass, container results identical across both runs. **Still not a clean sweep**, and deferred with a reason: leg 6 fails and cannot pass on OrbStack, which is a defect in the leg rather than in the profile (C7) and a behaviour change this pass is fenced out of. | MOT-104, MOT-107 |
| 4 | The operator's profile is unhardened | **Recorded as a standing accepted risk** (D10b, C8). Deliberately not fixed. | MOT-108 |
| 5a | Delete untracked `code-graph/` | **Closed — done.** Operator approved 2026-08-22; deleted after verifying it was distinct from the tracked `tools/code-graph/` and held no unpushed work. R7 inventory is now five files (C9). | MOT-109 |
| 5b | Rewrite pushed git history | **Closed — declined.** Operator decided against; the cost to `.agent/github/` and to both remotes is not worth scrubbing a name the working tree no longer carries (C9). | MOT-110 |

Parent issue: **MOT-102**. ADR: **MOT-103**.
