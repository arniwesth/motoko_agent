# `agent_confined` — a container the agent lives in, that VS Code cannot attach to

A second container on the same working tree, running [herdr](https://herdr.dev) as its session layer, from
which motoko and the delegate CLIs (`claude`, `codex`, `omp`) are started as panes.

**This profile is additive.** `.devcontainer/default` is untouched: you keep *Reopen in Container* exactly as
before, with its `sudo` and its VS Code attach. Nothing here is read by it.

**Status (2026-08-22): the image builds; first attach in progress.** Three defects so far, all fixed and all
recorded in [`HISTORY.md`](./HISTORY.md): `apt-get purge sudo` is refused by dpkg without
`SUDO_FORCE_REMOVE=yes`; the build context was 11.68 GB; and `agent.sh` used bash-4-and-GNU-only constructs
on a host that is macOS bash 3.2. **Note the split runtime** — the container is bash 5, but `agent.sh` and
`checks/r9-container.sh`'s host legs run on your Mac, so bash 3.2 + BSD userland is the floor for those.

| you want | read |
|---|---|
| to run it | **Quick start**, below |
| why the profile exists at all | **What this is for**, below |
| why each absence is there | the comment at the point it is made, in `Dockerfile` and `docker-compose.yml` |
| what is still open | **Known gaps**, below, and RESEARCH §7 |

---

## What this is for

Attaching VS Code to a container is the mechanism that injects the operator's GitHub credential and
ssh-agent socket into the agent's UID. Measured inside motoko's own devcontainer on 2026-08-22, with
`checks/`:

```
FAIL  leg2: sudo -n true SUCCEEDED
FAIL  leg3: SSH_AUTH_SOCK / REMOTE_CONTAINERS_IPC / REMOTE_CONTAINERS_SOCKETS / VSCODE_IPC_HOOK_CLI are set
FAIL  leg3: forwarded socket file(s) exist: /tmp/vscode-ssh-auth-….sock, …ipc-….sock, ~/.gnupg/S.gpg-agent
FAIL  leg4: a VS Code remote-containers helper is configured
FAIL  leg4: git credential fill returns a gho_-shaped value
FAIL  leg6: host.docker.internal resolves
```

That last-but-one line is the point. A `gho_` value is a GitHub **OAuth app access token** for the operator's
own account — not a scoped PAT — and it is *live* in the attached container, not merely announced. Every
absence in this profile follows from removing that, and from one further rule: **an agent that cannot install
anything cannot undo an absence**, which is why there is no `sudo` here and why herdr, the CLIs and motoko's
whole toolchain are baked into the image.

The counterweight, stated up front because the table of absences will otherwise oversell it: **confining a
container does not confine the tree.** See *What is deliberately not absent*.

---

## Quick start

Everything below happens on the **host** — a terminal on your machine, or the integrated terminal of a VS
Code window opened on the repository folder that is *not* reopened in a container. `agent.sh` refuses to run
inside a dev container.

### Prerequisites

* **OrbStack or Docker Desktop running.** Your own dev container does *not* need to be up — this stack is
  standalone and joins no external network.
* **A repository-root `.env`.** `agent.sh` refuses without one. It is where the model keys come from, by two
  separate routes: compose interpolates the curated `environment:` block from it, and motoko reads the file
  directly at start-up (`src/tui/src/index.ts:150-204`).

### Every session

```sh
cd <your host checkout>            # the folder that is /workspaces/motoko_agent inside either container
.devcontainer/agent_confined/agent.sh bootstrap   # FIRST RUN ONLY — builds the image, then src/tui + herdr integrations
.devcontainer/agent_confined/agent.sh             # attach; detach with ctrl+b q
```

The first run builds the image and takes several minutes: it runs `scripts/install-prerequisites.sh` (Go,
Bun, Node, DuckDB, Z3, `gh`, the AILANG toolchain at its pinned tag) and then installs herdr and the three
agent CLIs. Later runs attach in seconds.

`bootstrap` is separate from `attach` on purpose. It runs `bun install && bun run build` in `src/tui` **on
the shared tree**, so do not run it while your own container is building the same directory — that is the one
collision two containers on one tree can produce. Skip it if your own container has already done it;
`attach` warns you if `src/tui/node_modules` is missing.

### Inside

herdr is a background session server plus terminal clients: the panes keep running when you detach, and
`agent.sh` re-attaches to them. Start motoko the way you would anywhere:

```sh
make run                                  # in a pane
```

and start anything else in another pane — from herdr's own UI, or from a script, which is the same thing
because the CLI talks to the socket the UI does:

```sh
herdr pane split --direction right --cwd /workspaces/motoko_agent   # -> .result.pane.pane_id
herdr pane run <pane_id> 'codex'
herdr agent list                                                    # what is running, and its state
herdr agent prompt <target> 'summarise the diff' --wait --until idle
herdr agent read <target> --source recent --lines 120
```

**The agent can browse the web.** `agent-browser` drives a headless Chromium over CDP — no terminal
rendering involved, so none of the graphics constraints in *Known gaps* apply to it:

```sh
agent-browser open https://example.com
agent-browser snapshot -i          # accessibility tree with stable refs: [ref=e20]
agent-browser click @e20           # act on a ref, not a brittle CSS selector
agent-browser eval "document.title"
agent-browser skills get core --full   # its own usage guide, shipped with the binary
```

Two things to know. The Chromium is Playwright's, because Chrome for Testing publishes **no Linux
ARM64 build** and Ubuntu's `chromium` is a snap stub — `agent-browser install` will tell you the
first of those if you run it; don't, the browser is already baked in and `AGENT_BROWSER_EXECUTABLE_PATH`
points at it. And it runs `--no-sandbox`, because the setuid sandbox cannot work under
`no-new-privileges:true`: **the container is the only boundary for that browser, so do not point it
at untrusted pages.**

That last group is why herdr is here rather than tmux: it is a delegation surface with no integration code —
a delegate is a pane, its state is queryable, and a human can watch and type into the same pane. Project 018
(`.agent/projects/018_agentcli_delegation/`) is the consumer.

**Motoko reports its own state to herdr**, so it appears in the sidebar beside `claude`, `codex` and `omp` and
answers `herdr agent wait motoko --until idle`. It does so as a *lifecycle authority* — herdr takes Motoko's
word for `working`/`idle`/`blocked` rather than pattern-matching the pane, which is a stronger integration
than Claude Code or Codex get. The reporter is `src/tui/src/herdr-agent-state.ts` and is inert outside a herdr
pane; the decision record is `.agent/projects/020_herdr_agent_integration/ADR-001-herdr-agent-integration.md`.
Note that herdr cannot *launch* Motoko (`agent start --kind` is a fixed list) — start it with
`herdr pane run <pane_id> 'make run'` and it is recognised once it reports.

### The other commands

```sh
.devcontainer/agent_confined/agent.sh session=review   # a second, independent herdr server
.devcontainer/agent_confined/agent.sh sessions         # which exist (does not start the container)
.devcontainer/agent_confined/agent.sh session=review kill
.devcontainer/agent_confined/agent.sh shell            # a bash prompt, outside herdr
.devcontainer/agent_confined/agent.sh run make test    # one-shot; dies with this terminal
.devcontainer/agent_confined/agent.sh build            # rebuild at the PINNED versions
.devcontainer/agent_confined/agent.sh upgrade          # re-resolve every version, rewrite versions.env, rebuild
.devcontainer/agent_confined/agent.sh stop             # stop and remove the container
.devcontainer/agent_confined/agent.sh check            # the R9 sweep
.devcontainer/agent_confined/agent.sh help             # the header block of the script, coloured
```

A **session** is a whole herdr server with its own panes, sockets and persisted state. You usually want one,
with several panes in it — a second session is for work that must be genuinely independent.

### Versions are pinned in the tree

[`versions.env`](./versions.env) carries herdr's version and sha256 and the three CLI versions, and is
committed. Two things follow, both deliberate:

* **`stop`, `sessions`, `logs` and `build` work with no network**, because nothing is resolved at run time.
* **An upgrade is a commit.** `agent.sh upgrade` re-resolves each line from upstream, prints the diff,
  rewrites the file and rebuilds; that diff is the record of what the agent now runs. `build` never
  re-resolves.

This replaces the source profile's resolve-on-every-start arrangement, and it exists for the same reason:
`RUN bun install -g …@latest` inside a Dockerfile does **not** track latest — the instruction text never
changes, so Docker reuses the cached layer and the image keeps whatever was current the day it was first
built, indefinitely and invisibly. A build arg whose *value* changes is what invalidates the layer. Override
one for a single command by exporting it: `HERDR_VERSION=0.8.1 agent.sh build`.

**The agent cannot upgrade itself**, and that is the same property as the missing `sudo`. herdr is installed
root-owned in `/usr/local/bin`, `update.version_check` is off, and `GH_PROMPT_DISABLED=1` is set — but
`~/.local/bin` is writable and earlier on `PATH`, so all three are speed bumps rather than controls. Stated
plainly so nobody mistakes them for a boundary.

### If something does not work

| symptom | what to do |
|---|---|
| *"Run this on the HOST, not inside a dev container"* | you ran it from a terminal attached to a container. Use a terminal on your machine, or a VS Code window not reopened in a container |
| *"missing …/.env"* | create the repository-root `.env` first — an empty file starts the container, but motoko will have no model keys |
| `docker not found` | OrbStack / Docker Desktop is not running |
| the build fails with *"HERDR_VERSION and HERDR_SHA256 are required"* | you ran `docker compose build` directly. Use `agent.sh build`, which exports the pinned values |
| `agent.sh upgrade` fails with *403 Forbidden* | herdr.dev rejects some HTTP clients by User-Agent; the resolver sets one. If it still fails, the site is down — `agent.sh build` still works from the pinned file |
| motoko fails at start-up on a missing module | `src/tui/node_modules` is not on the tree: `agent.sh bootstrap` |
| the obsidian MCP server never connects | expected, and named: `host.docker.internal` is deliberately not routed here. See *Design* |
| `claude` or `codex` asks you to log in again after a rebuild | expected: nothing mounts `/home/motoko`, so a subscription login dies with the container. Use the API keys, or uncomment the named-volume block in `docker-compose.yml` |
| a `git checkout` fails part-way with `EROFS` | you switched to a branch whose content differs under `.devcontainer`, `.vscode` or `.git/hooks`, which are mounted read-only. Do that from the host or your own container |

**`agent_confined` will never appear in VS Code's "Reopen in Container" list.** That is by design; if it ever
does, something is wrong and `checks/r9-container.sh` leg 1 will fail.

---

## Operating rules

**As of 2026-08-22 this is where the work happens.** Not a second container beside the operator's —
the working one. The operator's devcontainer is kept, deliberately, but its job narrowed: it is for
**reading and reviewing** (rendered markdown, diffs, VS Code's own tooling), not for producing
changes. Four places, one job each:

| where | for | identity |
|---|---|---|
| **this container** | all work — commits, pushes, PRs, agents, delegates | `motoko-agent`, by construction |
| **the devcontainer** | reading, rendered markdown, diff review, VS Code tooling | the operator — so do not commit from it |
| **a host shell** | `agent.sh`, and every edit to `.devcontainer/**` | n/a |
| **GitHub's web UI** | human review and approval | the operator — and this is now the *only* place a human decision is legible |

Three consequences, in order of how likely they are to catch you:

* **This container cannot maintain itself.** `.devcontainer/**` is mounted read-only, so every edit
  to this profile — and `agent.sh build` itself — is host-side work. Deliberate: an agent that can
  rewrite its own confinement has none. A `git checkout` between branches whose content differs
  under those paths fails part-way with `EROFS`.
* **Everything GitHub-related is `motoko-agent`**, by construction rather than by discipline. Nothing
  here can act as the operator, which is the point — and it means git authorship no longer
  distinguishes a human decision from a mechanism. `.agent/github/` and the web UI are where that
  distinction now lives. The corollary is the second row of the table: **committing from the
  devcontainer would quietly reintroduce the operator's name**, which is the one way to break this.
* **Keeping the devcontainer keeps its exposure.** It has passwordless sudo, the forwarded
  ssh-agent socket, and a live `gho_` credential helper — the findings this whole profile answers —
  and it mounts the same tree. That is an accepted cost of having a usable editor, not an oversight;
  it is why the *agent* does not live there.

Three rules, because the tree is still shared with the host and with any other container you start.

1. **Don't build in both containers at the same moment.** `src/tui/node_modules`, `dist/` and the Go build
   cache are on the tree. Two simultaneous `bun run build` or `make build` runs write the same directories:
   file locks and confusing incremental failures, not corrupted source.
2. **`.devcontainer`, `.vscode` and `.git/hooks` are read-only inside the agent's container.** Two
   consequences: a branch switch whose content differs under those paths fails part-way with `EROFS`, and
   every edit to this directory — including this file — must be made from your own container or the host,
   never from inside the agent's.
3. **Re-record the R7 baseline after an approved change** under `.devcontainer/**`, `.vscode/**`,
   `.claude/**`, `.mcp.json`, `AGENTS.md` or `.agent/tools/**`, and note why in the change. Editing this
   directory changes that inventory every time.

---

## Checks

The boundary is asserted by scripts with named legs that fail loudly, rather than by prose. That is most of
what makes this worth porting: it is a boundary you can regression-test.

```sh
# R9 — the container is the one this profile describes. Run it THROUGH THE WRAPPER, from a host shell.
.devcontainer/agent_confined/agent.sh check
make agent_confined_check                    # the same thing
#   host legs:      no devcontainer.json, no profile references it, bind sources exist AND are :ro,
#                   versions.env present, .env present
#   container legs: no docker socket/binary, sudo refused, no ssh binaries, no forwarded sockets,
#                   gh present, GH_TOKEN/GITHUB_TOKEN unset, the bot token authenticates as motoko-agent
#                   and is REFUSED on a branch-protection read, no remote-containers helper, no gho_
#                   credential, the profile marker, every baked-in tool present, no host.docker.internal

# R7 — the git-configuration and frozen-content audit. Owner: a human, from a host terminal.
#   RECORD ONLY AFTER SANITISING: a baseline taken over a planted directive approves it.
.devcontainer/agent_confined/checks/r7_git_audit.py --root "$PWD" --record ~/r7-baseline.json
.devcontainer/agent_confined/checks/r7_git_audit.py --root "$PWD" --verify ~/r7-baseline.json
make agent_confined_r7 R7_BASELINE=~/r7-baseline.json     # the verify leg

# Is a forwarded agent socket a conduit or an actual oracle? Read-only; no signature is requested.
#   Run it in the OPERATOR's attached container — this profile should have no socket at all (R9 leg 3).
.devcontainer/agent_confined/checks/agent-socket-probe.py
```

**`checks/r9-container.sh` exits `2` and prints `R9 INCOMPLETE` when it cannot reach the service.** Treat `2`
as *not verified*, never as a pass: it means nothing checked for a docker socket, `sudo`, or a forwarded
credential socket. Run it through `agent.sh check`, which refuses from inside a container and refuses when
the service is down.

`r7_git_audit.py` asserts a **typed** expectation rather than a snapshot, because literal whole-file equality
is not assertable: `.git/config` alone carries 517 entries here, 506 of them `branch.*`. Two rules for living
with it: **do not loosen a clause because it fails** — a clause that false-fails on approved content is how
an audit gets replaced by a snapshot — and **do** re-record from the reviewed tree after an approved change.

---

## Design: what is absent, and what breaks because of it

| absent | why | what you lose |
|---|---|---|
| `devcontainer.json` | attach forwards the operator's credential and sockets — measured live in the operator's container, above | no VS Code attach; drive it from a host shell |
| `sudo`, any sudoers drop-in | with `NOPASSWD: ALL` the agent can `apt-get install openssh-client`, so every other absence is a speed bump | every new tool is an operator-side image rebuild; that is why herdr, the CLIs and the toolchain are baked in |
| `openssh-client`, `openssh-server` | an ssh-agent socket or key is a GitHub-independent push path as the operator | no SSH git from here; HTTPS with the bot token instead |
| `/var/run/docker.sock`, `docker` CLI | `docker run -v /:/host` is host root | no container-based tests here |
| `extra_hosts: host.docker.internal:host-gateway` | a convenient *name* for the host — **not**, as an earlier version of this table claimed, the route itself (see below) | **the obsidian MCP server in `.mcp.json` is unreachable**, because it is addressed by name. The `ailang-docs` and `linear` MCP servers are public https and are unaffected |
| an external network join | the source profile joined the operator's stack to share its ClickHouse; motoko has no such dependency | nothing — outbound access to the model APIs, npm and github.com is unaffected |
| host credential mounts (`~/.config/gcloud`, `~/.ssh`, `~/.claude`) | each hands the operator's host credentials straight back to the agent | subscription logins do not persist across a rebuild; see the commented opt-in in `docker-compose.yml` |

**`extra_hosts` is a name, not a boundary — corrected 2026-08-22.** The row above used to read "a route
to host services", and that was wrong. `extra_hosts` writes an `/etc/hosts` entry and nothing else.
Measured in the operator's container: the name resolves to `0.250.250.254` (OrbStack's dedicated host
address, *not* the default gateway `192.168.107.1`), and a connection to it is **refused** rather than
timing out — packets reach the host and are actively rejected, so the address is routable. Dropping
`extra_hosts` here therefore removes the hostname, and a process in this container can very likely still
reach the host by IP. Treat it as a speed bump, in the same class as `GH_PROMPT_DISABLED` and the
root-owned herdr binary. Whether the same address is routable from *this* profile's network is untested,
because that network has never been up.

### What is deliberately *not* absent

The table above relocates **host-side** credentials. It does not withhold **in-tree** ones, and an operator
who reads only that table will overestimate the boundary.

* **The tree is shared and mounted whole.** `/workspaces/motoko_agent` is one host directory, so confining a
  compose service confines no part of it. Every host-side git command the operator runs consults
  **agent-writable git configuration**, and the exec-or-credential family in those files (`[alias] x = !cmd`,
  `core.hooksPath`, `include.path`/`includeIf`, `remote.<n>.url = ext::<cmd>`, `branch.<n>.remote` — which
  accepts a URL, not only a remote name — `core.pager`, `diff.external`, `filter.*.clean/smudge`,
  `gpg.program`, `credential.helper`) **executes as the operator, on the host: outside `no-new-privileges`,
  outside the `:ro` binds, outside the container.** `credential.helper` is the worst member because it
  defeats not just revocation but **rotation** — a fresh token is captured on first use. `checks/r7_git_audit.py`
  is the only thing here that addresses this channel. Measured on this tree: 6 git configuration files, all
  four nested ones gitignored, so a change inside any of them is invisible to the parent's `git status`.
* **In-tree credentials stay reachable.** The curated `environment:` block in `docker-compose.yml` is not a
  boundary: `.env` is on the bind mount and motoko reads it directly. Curating the block keeps a *delegate*
  that does not read `.env` to the keys named there, and keeps this container no more exposed than the
  operator's. Closing it properly means not mounting `.env`, which means motoko cannot read it either.
* **Two agents, one worktree.** A delegate running in motoko's tree leaves writes indistinguishable from
  motoko's. A container boundary does nothing about that; `herdr worktree create` would, and is the open
  question RESEARCH §7 F-5 leaves for the owner. Note that herdr's default worktree directory is
  `~/.herdr/worktrees`, which does **not** survive a rebuild — see `herdr.toml`.

### There is no `devcontainer.json` here, on purpose

Do not add one. Do not "complete the profile".

VS Code's picker lists only profiles that have one, so this container is invisible to it while
`.devcontainer/default` is listed. This is a **compose service**, not a dev container. A `devcontainer.json`
beside `docker-compose.yml` makes the service attachable, and every isolation claim above becomes a matter of
habit rather than of configuration — which is why `checks/r9-container.sh` leg 1 asserts the file's absence.

**If you genuinely must attach**, the deliberate-exception procedure is: stop every agent process first;
attach, do the thing, detach; then **discard the container** (`agent.sh stop && agent.sh`) rather than
reusing it, because the forwarded helper and sockets live in the container; then re-run `agent.sh check`
before restarting the agent.

### Identity: what did *not* transfer from the source record

The source ADR's §D1–§D3 are about minting a fine-grained PAT from the **operator's own account**, with
attribution explicitly out of scope. Motoko already answered that question differently and better:
016_github_ops ADR-001 C9 uses a **machine user**, so `MOTOKO_BOT_GH_TOKEN` and the `motoko-agent` login
replace the whole PAT-delivery apparatus — there is no `agent.sh github` here, and no
`github-agent-token.sh`. R9 leg 4 is retargeted accordingly: it asserts *which account answers*, not merely
that a credential exists.

What is **not** settled is the other half of the problem. A credential with `contents: write` carries
push, merge *and* ref deletion as one grant, so **protection**, not permission, has to do the denying
— and **whether `arniwesth/motoko_agent` carries any branch or tag ruleset at all is unmeasured.** A
separate bot account bounds *who* acts; it does not bound *what* the credential can do. Reading that
state needs `administration: read`, which the bot is expected not to hold, so it is an operator-side
check, and the bot's refusal in R9 leg 4 is a pass rather than the answer.

---

## Known gaps

Everything in this list is a thing this port did not do, stated so it is not mistaken for done.

1. **The image has not finished building.** The first attempt got to step 7 of 17; steps 8-17 — the herdr
   download, the three CLIs, the integrations — have never run. Items 3-5 are what a completed build
   settles.
2. ~~**Does the image build with `sudo` purged?**~~ Settled: yes, with `SUDO_FORCE_REMOVE=yes`. dpkg's
   prerm refuses otherwise, and the build asserted the absence loudly rather than producing an
   unconfined image, which is what that assertion is for.
3. **Does motoko's TUI render correctly in a herdr pane?** herdr's defaults were tuned for full-screen agent
   TUIs and its own scrollback handling replaces the forty lines of `tmux.conf` the source profile needed —
   but motoko's TUI grabs mouse tracking, and that combination is unmeasured.
4. **Do the herdr integrations install at build time?** herdr's CLI normally talks to a running server, and
   there is none during a build. `agent.sh bootstrap` re-runs them against the live server, which is the path
   expected to work.
5. **Does `claude` / `codex` authenticate from the curated environment?** `ANTHROPIC_API_KEY` is not in the
   repository `.env` today; `OPENAI_API_KEY` is.
6. **The operator's own container is unchanged**, so the findings at the top of this file are still true of
   it. Removing the NOPASSWD drop-in and `host.docker.internal` from `.devcontainer/Dockerfile` and
   `.devcontainer/docker-compose.yml` is a separate, deliberate change nobody has made.
7. **A *visible* browser is deliberately absent.** `terminal-browser` was installed here on
   2026-08-22 and removed the same day: it renders, but markedly worse in a container than on the
   host, for architectural reasons rather than tunable ones. Run that one on your Mac.
   `agent-browser` replaces it for the agent's purposes and has no rendering path at all.
   [`HISTORY.md`](./HISTORY.md) has both sets of measurements.
8. **`tools/tmux-web` was not ported.** herdr supersedes most of it — `herdr terminal session observe` and
   `control` emit newline-delimited JSON frames, which is a better bridge than scraping `capture-pane` — but
   nothing here serves a browser.
