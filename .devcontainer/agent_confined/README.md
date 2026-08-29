# `agent_confined` — a container the agent lives in, that VS Code cannot attach to

A second container on the same working tree, running [herdr](https://herdr.dev) as its session layer, from
which motoko and the delegate CLIs (`claude`, `codex`, `omp`) are started as panes.

**This profile is additive.** `.devcontainer/default` is untouched: you keep *Reopen in Container* exactly as
before, with its `sudo` and its VS Code attach. Nothing here is read by it.

**Note the split runtime.** The container is bash 5, but `agent.sh` and `checks/r9-container.sh`'s host
legs run on the host — so bash 3.2 + BSD userland is the floor for those, and a GNU-only construct in
either will work here and fail there.

| you want | read |
|---|---|
| to run it | **Quick start**, below |
| why the profile exists at all | **What this is for**, below |
| why each absence is there | the comment at the point it is made, in `Dockerfile` and `docker-compose.yml` |
| what is still open | **Known gaps**, below, and RESEARCH §7 |

---

## What this is for

Attaching VS Code to a container is the mechanism that injects the operator's GitHub credential and
ssh-agent socket into the agent's UID. The credential VS Code's helper serves is an **OAuth app access
token for the operator's own account** — not a scoped PAT — and it is live in the attached container
rather than merely announced. Every absence in this profile follows from removing that, and from one
further rule: **an agent that cannot install anything cannot undo an absence**, which is why there is no
`sudo` here and why herdr, the CLIs and motoko's whole toolchain are baked into the image.

`checks/` is what turns that from a claim into something testable; run it against any container to see
which of these properties actually hold there.

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
| the obsidian MCP server never connects | expected. What stops it is the **egress boundary**, at every layer: on the internal-only network the embedded resolver does not even serve `host.docker.internal` (on a routed network it does, with or without `extra_hosts`); there is no route to the host's address range regardless; and the proxy, which *can* resolve the name, refuses the destination by CIDR. See *Design* |
| `claude` or `codex` asks you to log in again after a rebuild | expected: nothing mounts `/home/motoko`, so a subscription login dies with the container. Use the API keys, or uncomment the named-volume block in `docker-compose.yml` |
| a `git checkout` fails part-way with `EROFS` | you switched to a branch whose content differs under `.devcontainer`, `.vscode` or `.git/hooks`, which are mounted read-only. Do that from the host or your own container |

**`agent_confined` will never appear in VS Code's "Reopen in Container" list.** That is by design; if it ever
does, something is wrong and `checks/r9-container.sh` leg 1 will fail.

---

## Operating rules

**This is where the work happens.** Not a second container beside the operator's — the working one. The operator's devcontainer is kept, deliberately, but its job narrowed: it is for
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
* **Keeping the devcontainer keeps its privileges.** It is a normal attached dev container, with
  everything that implies, and it mounts the same tree — that is an accepted cost of having a usable
  editor, not an oversight, and it is why the *agent* does not live there. `agent.sh check` run against
  it will tell you exactly which properties it does and does not have.

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
#   leg 7:          the egress boundary — no direct route off-box, public egress ONLY through the proxy,
#                   and the proxy itself refuses private/reserved destinations

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
| `extra_hosts: host.docker.internal:host-gateway` | a convenient *name* for the host — not the route itself, and under this runtime not even the name (see below) | on its own, **nothing** — the name is served anyway. **The obsidian MCP server in `.mcp.json` is unreachable**, but that is the egress boundary's doing, not this row's. The `ailang-docs` and `linear` MCP servers are public https and reach it through the proxy |
| an external network join | the source profile joined the operator's stack to share its ClickHouse; motoko has no such dependency | nothing — outbound access to the model APIs, npm and github.com is unaffected |
| host credential mounts (`~/.config/gcloud`, `~/.ssh`, `~/.claude`) | each hands the operator's host credentials straight back to the agent | subscription logins do not persist across a rebuild; see the commented opt-in in `docker-compose.yml` |

**`extra_hosts` is a name, not a boundary — and under this runtime, not even the name.** It writes an
`/etc/hosts` entry and nothing else. It is also a *Docker-Engine* idiom: on Engine, `host.docker.internal`
resolves only because Engine writes that mapping. This stack runs on **OrbStack**, whose embedded resolver
synthesises the name on any routed network regardless — so dropping the directive removes neither a name
nor a route. Worth carrying to the rest of the table: **a control reasoned from "the runtime won't do X by
default" has to be verified against the runtime actually in use.**

What closes both the name and the route is the egress boundary below. On the internal-only network the
name does not resolve at all, there is no route to the host's address range under any name, and the proxy
— which is on a routed network and does resolve it — refuses that destination outright.

### The egress boundary: one way out, and it is a proxy

Every absence in the table above withholds a **credential or a privilege**. None of them withholds a
**destination** — and a container with unrestricted outbound access can reach whatever private networks
its host is attached to, as that host. That is a different category of control, so it gets its own.

`agent` sits on a single `internal: true` network. Docker installs **no gateway and no NAT** for such a
network, so there is no route off-box at all: not to the internet, not to the host's own address range,
not into RFC1918 or CGNAT space. The one container dual-homed onto both that network and a routed one is
`egress-proxy`, a squid forward proxy, and the agent's `HTTP(S)_PROXY` points at it. It never decrypts —
clients issue `CONNECT host:443` and it decides by destination — so there is no CA to install and no
credential exposed to it.

**Its policy today is deliberately permissive: forward to every public host, deny every private and
reserved range.** GitHub, npm and the model APIs are unaffected; what is removed is reachability of
private networks and of the host. `squid.conf` carries a commented strict-allowlist block, so tightening
to "only these domains" is that one edit and nothing else.

Two properties follow, and both are the point rather than side effects:

* **It fails closed.** A tool that ignores `HTTP(S)_PROXY` does not leak — it has no route, so it simply
  fails. That is also how you find a proxy-unaware tool: it stops working instead of quietly going direct.
* **This is what makes `NET_RAW` harmless.** The container keeps Docker's default capability set, raw
  sockets included; on a network with no gateway, they have nowhere to go.

`checks/r9-container.sh` **leg 7** asserts the whole shape: no direct route to a public IP, no direct route
into CGNAT space, public egress *through* the proxy works, and the proxy refuses a private destination when
asked through it. An edit that puts `agent` back on a routed network fails the first two legs loudly.

**One thing to know before reading leg 7's output.** Through a proxy, an `https://` URL is a `CONNECT`
tunnel, and curl reports `http_code 000` for *any* tunnel that fails to open — so a proxy that denied the
destination and a proxy that is not running would be indistinguishable. Leg 7 therefore probes the private
range over `http://`, where a deny comes back as a real `403`, and treats `000` as *the proxy did not
answer at all*. A check whose pass condition is also one of its failure modes is not a check.

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

### Identity: which account acts, and what that does not settle

Everything GitHub-related here acts as a **machine user**: `MOTOKO_BOT_GH_TOKEN` and the `motoko-agent`
login, per 016_github_ops ADR-001 C9. R9 leg 4 asserts *which account answers*, not merely that a
credential exists.

What that does **not** settle is the other half of the problem. A credential with `contents: write` carries
push, merge *and* ref deletion as one grant, so **protection**, not permission, has to do the denying
— and **whether `arniwesth/motoko_agent` carries any branch or tag ruleset at all is unmeasured.** A
separate bot account bounds *who* acts; it does not bound *what* the credential can do. Reading that
state needs `administration: read`, which the bot is expected not to hold, so it is an operator-side
check, and the bot's refusal in R9 leg 4 is a pass rather than the answer.

---

## Where the measurement record lives

The working notes for this profile — how each property was measured, and the reasoning behind decisions
that would otherwise look arbitrary in the files themselves — are kept **outside this repository**, in
`.agent/local/` (git-ignored). This README states what the boundary *is*; those notes state how it was
arrived at.

Not having them costs you the reasoning, not the rules: everything load-bearing here is asserted by
`checks/`, not by prose.

## Known gaps

Everything in this list is a thing this port did not do, stated so it is not mistaken for done.

1. **Does motoko's TUI render correctly in a herdr pane?** herdr's defaults were tuned for full-screen agent
   TUIs and its own scrollback handling replaces the forty lines of `tmux.conf` the source profile needed —
   but motoko's TUI grabs mouse tracking, and that combination is unmeasured.
2. **Do the herdr integrations install at build time?** herdr's CLI normally talks to a running server, and
   there is none during a build. `agent.sh bootstrap` re-runs them against the live server, which is the path
   expected to work.
3. **Does `claude` / `codex` authenticate from the curated environment?** `ANTHROPIC_API_KEY` is not in the
   repository `.env` today; `OPENAI_API_KEY` is.
4. **The operator's own container is unchanged.** Narrowing it the way this profile is narrowed — the
   sudoers drop-in, `extra_hosts` — is a separate, deliberate change nobody has made. `agent.sh check`
   run against it reports where it stands.
5. **A *visible* browser is deliberately absent.** Terminal-rendering browsers work markedly worse in a
   container than on the host, for architectural reasons rather than tunable ones — run one of those on
   your own machine. `agent-browser` covers the agent's purposes and has no rendering path at all.
6. **No AppArmor here, and nothing should assume otherwise.** On Docker Engine on a Linux host, every
   container additionally runs under the `docker-default` AppArmor profile — a mandatory-access-control
   layer above capabilities and seccomp. Under OrbStack (and Docker Desktop) there is no host AppArmor, so
   that layer is simply **absent**: no `/proc/self/attr/current`, and the `apparmor`
   LSM is not visible under this runtime. Nothing in this profile claims it, so nothing written here is
   false — the gap is that a future hardening step reaching for `apparmor=docker-default` would **silently no-op** here
   instead of failing. Same class as the `extra_hosts` case: an Engine default assumed under a runtime
   that is not Engine.
7. **`tools/tmux-web` was not ported.** herdr supersedes most of it — `herdr terminal session observe` and
   `control` emit newline-delimited JSON frames, which is a better bridge than scraping `capture-pane` — but
   nothing here serves a browser.
