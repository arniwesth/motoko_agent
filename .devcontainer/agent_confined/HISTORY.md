# `agent_confined` — what was measured, and when

Newest first. This file carries measurements and the reasons behind decisions that would otherwise look
arbitrary in the files themselves. [`README.md`](./README.md) says how to run the thing; this says why it is
shaped the way it is, and what is still only asserted.

---

## 2026-08-22 (sidebar, fonts) — a probe that cannot be right, turned off rather than answered

First run of the sidebar showed *"No Nerd Font detected"* and offered to download JetBrainsMono. The
offer is well-built and, here, meaningless.

**The probe asks the wrong machine.** The sidebar chooses its icon theme by testing whether a Nerd
Font is *installed* — `fc-list` on Linux — and that runs **in this container**. Glyphs are rendered
by the terminal on the operator's **Mac**. The two have nothing to do with each other, so the answer
is always "no", and accepting the offer downloads a font into a container that renders nothing, into
a home directory nothing mounts, to be discarded by the next `agent.sh build`.

The plugin's own notes state the underlying limit plainly: *"A TUI cannot detect whether the terminal
font renders a glyph — missing glyphs (tofu) still occupy their cells, so cursor-position probing
sees nothing."* Its documented resolution order is **env → persisted `icons` in state.json → the
probe**, which is exactly the escape hatch this needs.

**Set in the image:** `HERDR_SIDEBAR_FONT_PROMPT=off` and `HERDR_SIDEBAR_ICONS=material`.

`material` is correct for **Ghostty**, which embeds a symbols-only Nerd Font, so Nerd Font codepoints
render whatever the configured family is and nothing needs installing on either side. It is wrong for
a terminal without that coverage — VS Code's integrated terminal by default — where the icons become
tofu; `HERDR_SIDEBAR_ICONS=emoji` in the compose environment overrides the image default without a
rebuild.

**Why the env rather than the in-app toggle.** Pressing `i` switches theme and persists the choice —
to `state.json` under `/home/motoko`, which the next rebuild discards. The env is what makes an
answer survive. This is the same shape as every other setting in this profile: anything that must
outlive a rebuild belongs in the image or in compose, never in the container's home.

---

## 2026-08-22 (sidebar) — herdr-sidebar, built in a throwaway stage and linked

`alexarthurs/herdr-sidebar` v0.9.0 is registered in the image: a VS Code-style file explorer and
source-control pane for herdr. It is a **ratatui TUI, not a graphics application**, so none of the
constraints that sank terminal-browser here apply — no Kitty graphics, no pixel geometry, no GPU.

**Built in a discarded stage rather than installed by herdr, and the reason is a split in herdr's
own API.** `herdr plugin install owner/repo/subdir` clones and runs the manifest's `[[build]]` —
here `cargo build --release` — and herdr "reports build failures but does not install missing
toolchains", so that path wants a Rust toolchain in the runtime image. `plugin link` deliberately
does *not* run build commands ("local authors build their working tree themselves"). So: `rust:1`
stage clones the pinned tag and compiles, the stage prunes `target/` down to the single binary the
manifest's `[[panes]]` command names, and the runtime image links the result. No cargo, no registry
cache and no intermediates reach the final image. Both commands work with no herdr server running,
which is what makes build time possible at all — and build time is the only option, since nothing
mounts `/home/motoko`.

Ordering matters and is deliberate: the link runs **after** the `herdr.toml` COPY, because
registration writes into herdr's own config/state and a later COPY could discard it.

**Pinned by tag, and deliberately NOT auto-resolved** the way the CLIs are by `agent.sh upgrade`.
This is third-party code that executes inside the confined container — the container holding the
working tree, the API keys, and now a GH_TOKEN with the bot's push rights. `herdr plugin install`
normally shows a source preview for review before confirming; a build-time install would have to
pass `--yes` and skip it forever. **The pin is therefore the review boundary**, and bumping
`HERDR_SIDEBAR_REF` should mean someone read the diff. Same reasoning as `PLAYWRIGHT_VERSION`.

Worth knowing about two of its features in this setting: its AI commit messages shell out to the
`claude` CLI, which is in this image and bills the operator's quota; and its font auto-install writes
into the container, where fonts are irrelevant because the Mac's terminal does the rendering.

**Owed:** not run. Expected first evidence is `herdr plugin list` showing it after a rebuild, then
`herdr plugin action invoke herdr-sidebar.open-sidebar` in a pane.

---

## 2026-08-22 (identity) — the container acts as motoko-agent, and GH_TOKEN is now correct here

Claude Code running in a herdr pane inside this container reported no GitHub access at all: `gh auth
status` not logged in, no `~/.config/gh/hosts.yml`, `git push` asking for a username, `gh api`
refused. All true, and all expected — nothing mounts /home/motoko, so an interactive `gh auth login`
would have to be redone every rebuild, and the agent cannot answer a device-flow prompt anyway.

**The fix inverts a rule, and the inversion is the interesting part.** 016 ADR-001 gives the bot
credential a distinct name — `MOTOKO_BOT_GH_TOKEN`, never `GH_TOKEN` — because `gh` silently prefers
`GH_TOKEN` over stored credentials, so under that name the **operator's own** `gh` would quietly run
as the bot. That rule protects a container the operator and the agent *share*.

They share no such container here. Nothing but the agent runs in this one, and D1-as-amended-by-C9
says what its identity is: anything a mechanism emits is the bot. So this profile now maps
`GH_TOKEN: ${MOTOKO_BOT_GH_TOKEN:-}` deliberately. Every GitHub action from this container is
`motoko-agent` **by construction** rather than by remembering — which is the same conclusion
the profile this was adapted from reached, arrived at from the other direction.

**git got the other half**, because a PR opened as the bot over commits authored by nobody is a worse
record than either alone:

* `credential.helper = !gh auth git-credential` — resolves from GH_TOKEN, so `git push` needs no
  stored credential and no login. No secret is baked into the image; the token arrives at run time.
* `user.name = motoko-agent`, `user.email = motoko-agent@users.noreply.github.com`. **The email is
  the short form and may want changing**: GitHub's canonical modern form is
  `<id>+<login>@users.noreply.github.com`, and commits only link to the bot's profile with that one.
  Get it with `gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"'` as the bot. Left short
  rather than guessing an id.

**R9 leg 4 was inverted to match**, and this is the part worth not skipping: it previously asserted
`GH_TOKEN` was *unset*, which I wrote by mirroring the operator container's concern into a profile
where it is exactly backwards. It now fails when GH_TOKEN is missing, checks the token resolves to
`motoko-agent`, and additionally asserts the credential helper and `user.name`. A check that asserts
the opposite of the intended configuration is worse than no check.

**Owed:** none of this has been run. The expected first evidence is `agent.sh check` showing leg 4
green, then `gh api user --jq .login` returning `motoko-agent` in a pane.

---

## 2026-08-22 (browser, replaced) — agent-browser, verified end to end before it was written down

`agent-browser` (vercel-labs, 0.34.0) is in the image. It is the successor the previous entry named,
and unlike terminal-browser it was **exercised in a container on this architecture before any
Dockerfile line was written**. A real GitHub page loaded and `snapshot -i` returned the ref tree:

```
- button "Search or jump to, type / to search" [expanded=false, ref=e20]
- link "Sign in" [ref=e53]
```

It never touches the terminal, so every constraint that sank terminal-browser here — Kitty graphics,
`docker exec` pixel geometry, the macOS-only GPU path — is simply absent.

### Four things measurement changed about the obvious install

1. **`agent-browser install` does not work on this host.** It fetches Chrome for Testing, which
   answers: *"Chrome for Testing does not provide Linux ARM64 builds."* Its own fallback advice,
   `apt install chromium`, fails too — Ubuntu 24.04 ships chromium as a snap stub. Playwright is the
   only source of a genuine arm64 Chromium, and agent-browser already probes the Playwright cache.
   The profile this was adapted from hit the same wall and solved it the same way; that apparatus,
   declined during the port, is what the tool needs. `--only-shell` is 340 MB against 641 MB and suffices for CDP.
2. **`ldd` says the 19-library list is unchanged** — exactly what Electron needed also covers this
   Chromium. The list was re-measured rather than reused on faith.
3. **The npm postinstall is neither needed nor available.** The package ships all seven platform
   binaries (~90 MB) and a postinstall that selects one — which bun blocks by default (found the
   hard way: `Blocked 1 postinstall`). So the install uses `--ignore-scripts`, picks the binary by
   `uname -m`, and drops the other six.
4. **The lone binary loses its skills.** Copied out on its own it reports *"Skills directory not
   found"*; `AGENT_BROWSER_SKILLS_DIR` pointed at the package's `skill-data` restores all seven
   (`core`, `electron`, `slack`, …). So `skill-data` is kept beside the binary.

### Carried over unchanged from the terminal-browser attempt

`--no-sandbox`, via a `/usr/local/bin/chromium` wrapper. The setuid sandbox cannot work under
`no-new-privileges:true` and unprivileged user namespaces are unavailable, so **the container is the
only boundary for this browser** — a container holding the working tree and the compose
environment's keys. Do not point it at untrusted pages. `--disable-dev-shm-usage` joins it because
docker's default 64 MB `/dev/shm` is a Chromium crash (larger under OrbStack, but nothing should
depend on that).

### One finding that belongs to project 022

`agent-browser mcp` is **stdio** — *"Starts a Model Context Protocol server over stdio"*. Motoko's
only working MCP client is the bundled Node bridge, which speaks to **remote HTTP** servers. So the
MCP route from motoko to agent-browser is closed today, and an extension shelling out to the CLI is
the open one. 022 §7 listed this as an assumption to check; it is now measured.

### Owed

Nothing has been run inside `agent_confined` itself — the verification above was in the operator's
devcontainer, which has the same base image and the same 19 libraries but **not**
`no-new-privileges:true`. That flag is precisely what makes `--no-sandbox` necessary, so the wrapper
is the one piece still taken on reasoning rather than observation.

---

## 2026-08-22 (browser, removed) — it worked, and it still belongs on the host

`terminal-browser` was installed here and removed again the same day. The two entries below stay as
the record of how it was made to work; this one says why it is gone, so nobody re-adds it expecting
a different outcome.

**It did work.** After the sandbox fix the browser started in a herdr pane and rendered GitHub. Two
problems remained: clicks did nothing, and scrolling was very slow. Installed natively on the
operator's Mac — same herdr, same terminal-browser — it behaved well.

**The gap is architectural, not tuning.** From the shipped `browser/dist/main.js`:

```js
var SHM_FRAMES = process.platform === "linux" && process.env.TERMINAL_BROWSER_SHM !== "0";
function offscreenPreferences(deviceScaleFactor) {
  if (process.platform === "darwin") {
    return { useSharedTexture: true, sharedTexturePixelFormat: "argb", deviceScaleFactor };
  }
  return { useSharedTexture: false, useSharedMemory: SHM_FRAMES, deviceScaleFactor };
}
```

The zero-copy GPU shared-texture path — the "reads pixels directly from the GPU" the project
advertises — is **macOS only**. Every Linux host takes a shared-memory CPU copy instead. So the
answer to "is this just GPU access?" is *no*: a GPU-equipped Linux container would not get the fast
path either. On top of that this container has no GPU at all, so SwiftShader software-rasterises
before the copy, and the frames then cross `docker exec` and the OrbStack VM boundary as
Kitty-graphics bytes.

**The clicks are a second, separate defect, and also structural.** Docker's exec resize API carries
rows and columns only — there is no pixel field — so `ws_xpixel`/`ws_ypixel` inside a `docker exec`
TTY are `0`. terminal-browser tracks whether a terminal `reportsCssPixels` and otherwise falls back
to Electron's own display scale, which is meaningless here. Mouse events arrive as cell coordinates
and must be mapped to CSS pixels; without a true cell pixel size that mapping cannot be right.
**This one is not fixable from inside the container at all.**

Note this also retired an earlier hypothesis of mine: `ui.mouse_capture` defaults to `true` on the
host install too, where clicking works — so herdr capturing the mouse was not the cause.

**Removed:** the terminal-browser layer, the 19-library Electron apt layer that existed only for it,
`ELECTRON_DISABLE_SANDBOX=1`, the `experimental.kitty_graphics` setting in `herdr.toml`, the two
build args, the `versions.env` pins, the installer-parsing branch of `agent.sh`'s resolver, and the
`terminal-browser` entry in R9 leg 5. The resolver round-trip was re-verified: a no-op
`agent.sh upgrade` produces an empty diff again.

**What it cost and what it bought.** ~342 MB of image and a day's detour, against three findings
worth keeping: the platform split above; the `docker exec` pixel-geometry limit, which constrains
*any* pixel-accurate TUI in this profile; and the confirmation that Electron cannot use its SUID
sandbox under `no-new-privileges:true`, which will be true of the next browser too.

**If an agent needs the web later**, the thing to reach for is not this. `agent-browser` — bundled
in that tarball but a separate upstream tool (`vercel-labs/agent-browser`, on npm) — drives a browser
over CDP and never touches the terminal, so none of the above applies to it. It needs its own Chrome
(`agent-browser install`) plus the same 19 libraries. That is the shape of a future attempt.

---

## 2026-08-22 (browser, fix) — "daemon did not start" was Chromium's SUID sandbox

First real run after the rebuild:

```
terminal-browser
terminal-browser: could not start the browser: Error: daemon did not start
```

That message is a symptom two layers above the cause, and it is worth noting what it ruled *in*:
the herdr backend had already been selected and the pane identified, so detection, `HERDR_PANE_ID`
and the CLI were all fine. The failure was Electron.

**Reproduced outside the confined container** (same base image, same 19 libraries), by running the
shipped binary directly:

```
FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:166] The SUID sandbox helper binary was
found, but is not configured correctly. Rather than run without sandboxing I'm aborting now.
You need to make sure that .../electron/chrome-sandbox is owned by root and has mode 4755.
```

The tarball extracts `chrome-sandbox` as `motoko:motoko 0755`. Electron refuses to start rather than
run unsandboxed.

**The upstream remedy is wrong for this image, twice over.** `chown root:root && chmod 4755` would
put a setuid-root binary inside a container whose entire thesis is that privileges cannot be
escalated — and it would not work anyway: `no-new-privileges:true` neuters the setuid bit and
unprivileged user namespaces are unavailable, so the sandbox cannot function here by construction.

**Fix:** `ENV ELECTRON_DISABLE_SANDBOX=1`. Verified both that and `--no-sandbox` get Electron to
report `v43.3.0`; the env var is the one that works here because terminal-browser spawns Electron
itself and there is no argv of ours to add a flag to. (`Failed to connect to the bus:
/run/dbus/system_bus_socket` is logged and is benign — there is no dbus in the image and Chromium
does not need one.)

**What is given up, recorded rather than buried:** Chromium's renderer sandbox. The container is now
the only boundary for this browser, and it is a container holding the working tree and the API keys
from the compose environment. **Do not point this browser at untrusted pages.** This is the same
trade the profile this was adapted from made for headless Chromium, for the same reason.

**A second defect, in my own check.** The build asserted `ldd | grep 'not found'` and passed —
because `ldd` reports only DT_NEEDED entries and says nothing about whether the binary can actually
run. It cannot catch a fatal at startup. The build now also *executes* `electron --version`, so this
class of failure stops the image instead of reaching a pane. An install that cannot run is not an
install.

---

## 2026-08-22 (browser) — terminal-browser added, after I twice said it could not work

`terminal-browser` (v0.6.0) is now baked into the image. Recorded at length because the route to
"yes" ran through two wrong answers of mine, and the reason for each is worth not repeating.

**Wrong answer 1: a malformed grep.** Asked whether the tool could work here, I grepped the shipped
build for supported terminals with a pattern that required literal quote characters around each
name. It matched nothing, so a follow-up grep with a hand-written list "found" only kitty, ghostty
and wezterm. The build actually contains **90 mentions of herdr**. A grep that returns nothing is
evidence about the grep, not about the corpus.

**Wrong answer 2: generalising from a forced test.** I then set `TERM=xterm-kitty` in a VS Code
terminal, got *"could not work out which kitty pane you are in"*, and concluded the tool was
host-side by nature — that it must drive a terminal emulator's own control protocol, which nothing
in this container can offer. The error was real; the conclusion was about a terminal I had lied to
it about, not about herdr.

**What the code actually does** (`cli/dist/main.js`, `terminals/src/terminals/herdr.ts`):

```js
var herdr = (env, run2) => {
  if (!env.HERDR_PANE_ID) return null;
  const bin = env.HERDR_BIN_PATH || "herdr";
  ...  herdr2(["pane", "split", ...args, "--right-click", "pane"])
```

and its `prepare()` writes `[experimental] kitty_graphics = true` into herdr's `config.toml` and
calls `herdr server reload-config`. So every gap I had listed is handled by the integration itself:
detection is `HERDR_PANE_ID` — which herdr injects into pane processes, i.e. **inside this
container** — pane control is herdr's own CLI, and the graphics flag is self-configuring. The owner
was right, and the correct question was never "can it" but "which terminal is it in".

### What was installed, and what was measured

* **19 system libraries**, and the list is `ldd`'s, not a tutorial's: the exact `not found` output
  against the shipped `electron` binary on ubuntu:24.04/arm64. Root-only, so image-only — with no
  sudo a missing entry is a browser that never starts. **No GPU is needed**: `libvk_swiftshader.so`
  ships in the tarball.
* **terminal-browser itself**, pinned and checksum-verified from the same installer script that
  carries both inline, parsed on the host by `agent.sh` exactly as herdr's `latest.json` is. Piping
  that installer to `sh` would bake one version into the image for ever.
* **A wrapper script, not a symlink**, in `~/.local/bin`. `app/bin/terminal-browser` resolves its own
  root with `cd "$(dirname "$0")/.."`; through a symlink that evaluates to `~/.local` and it fails.
  Upstream's installer writes the same two-line wrapper, which is how this was caught before a build.
* **The agent skills**, linked into `~/.claude/skills`, `~/.codex/skills` and `~/.agents/skills` per
  `app/skills/manifest`. Without them the capability is installed and undiscoverable.
* **`experimental.kitty_graphics = true` in `herdr.toml`**, declared rather than left to
  terminal-browser's runtime rewrite — which would be discarded on rebuild anyway, since nothing
  mounts `/home/motoko`.

### The thing this buys that a headless browser would not

`terminal-browser action -- snapshot | click | eval` is an agent-browser compatible CDP CLI pointed
at **the tab already open in the pane**. So the agent and the human are looking at the same browser,
not at two. That is the 019 §5 thread — a human who can watch and type — extended to the web.

A detour worth recording as *not* taken: `agent-browser` ships standalone inside the tarball and I
nearly installed it separately. Its `doctor` reports **No Chrome binary found**, and a first
apparent success (`read <url>` returning real page text) turned out to be a plain HTTP fetch with no
browser involved. Driven through `terminal-browser action` it needs no separate Chrome, because it
attaches to the Electron already running. One install, not two.

### Owed

Nothing has been rendered. The herdr backend is read from source, the Electron runtime is verified to
resolve all 19 libraries on this architecture, and the CLI runs — but no pixel has travelled
container → `docker exec` → herdr → Ghostty. That chain is the test, and it needs the container up.

---

## 2026-08-22 (correction) — "no route to host services" was wrong; it was never a route

A claim this profile made in three places is withdrawn. It was found by asking a small question —
why is `OBSIDIAN_MCP_TOKEN` in the curated environment when the obsidian server is unreachable? —
and the answer turned out to be that the unreachability was overstated.

**What was claimed.** `docker-compose.yml`'s absence list, README's design table, and
`checks/r9-container.sh` leg 6 all said that omitting `extra_hosts: host.docker.internal:host-gateway`
removes *a route to host services*, and leg 6 asserted it by testing that the hostname fails to
resolve.

**What is true.** `extra_hosts` writes an `/etc/hosts` entry. That is the whole of it. It neither
creates nor withdraws reachability, so the check tested a name while its title claimed a route —
a speed bump reported as a control, which is the single thing this sweep exists not to do.

**Measured in the operator's container, 2026-08-22:**

```
host.docker.internal -> 0.250.250.254        (OrbStack's dedicated host address)
default gateway      -> 192.168.107.1        (a DIFFERENT address — the name is not the gateway)
connect 0.250.250.254:27200 -> "Connection refused"   (not a timeout: something answered)
```

A refusal means the SYN was answered rather than dropped. So the address is reachable by IP, and
dropping `extra_hosts` in this profile removes the convenient name while a process here can very
likely still reach the host directly.

**And the probe taught its own lesson.** Leg 6 now probes candidate host addresses instead of
asserting, and on first run it reported **all three** as answering — including `192.168.65.254`,
which is Docker Desktop's host address and has no reason to exist under OrbStack. So a refusal
proves *an* endpoint answered, not that the host did. The leg's wording was narrowed a second time
to say only "egress to this address is not blocked", and it is deliberately `info` rather than
pass/fail: the set of host addresses is platform-specific, and a check that cannot fail correctly is
worse than an honest note. The useful signal is a change over time.

**What changed:** the compose comment, the README table row plus a new paragraph under it, and leg 6
(name check retained and retitled; reachability probed and reported). **What did not:** the obsidian
MCP server is still unreachable from here, because `.mcp.json` addresses it *by name*. That cost was
always real; only its explanation was wrong.

**Still owed.** Whether OrbStack hands the same address to this profile's own network is untested —
this profile's network has never been up. And `OBSIDIAN_MCP_TOKEN` remains in the curated list,
granting delegates a token for a server they cannot address; removing it is a one-line change nobody
has taken.

---

## 2026-08-22 (env surface) — `LINEAR_API_KEY` added to the curated environment

One key added, recorded because it widens what a delegate in this container can reach and because
the reason is not the obvious one.

**It is not for Motoko.** Motoko cannot reach Linear at all — project 022 measures why: its own MCP
extension is a dormant stub, the live client is a bundled bridge that only extensions call directly,
and no Linear extension exists. **The consumer is a `claude` delegate running in a pane here**:
`.mcp.json` is project-scoped and sits on the bind mount, so a delegate picks up the `linear` server
and gets issue write access — acting as this key's *owner*.

That makes it 022's F-1 (whose account an autonomous agent acts as) arriving through the delegate
rather than by decision. Granted deliberately by the owner today; the compose comment carries the
condition for removing it again.

**What was NOT done, and why.** The operator profile's `docker-compose.yml` had its curated
`environment:` list replaced by `env_file: ../.env` the same day, because that list delivered nothing
(Compose interpolates from the compose file's own directory, and `.devcontainer/.env` does not
exist). The obvious move was to mirror that here. It was declined:

* **this profile's list already works** — `agent.sh:284` passes `--env-file "${REPO_ROOT}/.env"` on
  the command line, so interpolation resolves. Same shape, different bug; there was nothing to fix;
* **curation does real work here.** Motoko reads `.env` off the bind mount whatever the list says,
  so curating buys nothing against Motoko — but `codex` and `claude` do **not** read `.env`, they
  read the environment. The list is what bounds a *delegate's* inheritance. Switching to `env_file`
  would newly hand every delegate `CH_HOST`, `CH_USER`, `CH_PASS`, `CH_DB`, `CH_AUTO_SYNC`,
  `CLICKSTACK_INGESTION_KEY`, `FIREWORKS_API_KEY`, `DEEP_INFRA_API_KEY`, `HF` and `PI_CODING_AGENT_DIR`
  — two production database credentials and three metered API keys, i.e. 018 F2's billing guard made
  strictly worse, in the container that exists to be the boundary.

The general rule this leaves: **a curated list is only worth having where the invocation is yours.**
This profile controls its own (`agent.sh`); the Dev Containers profile does not, which is why one
keeps a list and the other takes the file.

---

## 2026-08-22 (later still) — the host is macOS, and bash 3.2 is the floor

The image built. `agent.sh` then died on its own first attach:

```
.devcontainer/agent_confined/agent.sh: line 353: mapfile: command not found
```

`mapfile` is a bash **4** builtin, and macOS ships bash **3.2** as `/bin/bash` — the last GPLv2 release, frozen
in 2007 and never updated. `#!/usr/bin/env bash` finds it unless a newer bash is earlier on `PATH`.

This is a category error rather than a typo, and it is worth naming because everything in this directory is
split across two very different runtimes: the container is Ubuntu 24.04 with bash 5, and **`agent.sh` and
`checks/r9-container.sh`'s host legs run on the operator's Mac**. The host half's floor is bash 3.2 plus BSD
userland. Two more instances were found by auditing for the same class rather than waiting to hit them:

| construct | why it fails on the host | replacement |
|---|---|---|
| `mapfile -t ARR < <(…)` | bash 4 builtin | build the array directly — it was two elements |
| `tmp="$(mktemp)"` | BSD `mktemp` **requires** a template; only GNU's supplies a default | `mktemp "${TMPDIR:-/tmp}/agent-confined-versions.XXXXXX"` |
| bare `python3` in `upgrade` | not shipped with macOS; arrives with the Xcode command line tools | a `command -v` guard that names python3, so the failure is not reported as "could not resolve upstream versions" |

Audited and confirmed clear in both scripts: no `readarray`, `declare -A`, `local -n`, `globstar`, `;;&`,
`&>` or `${var,,}`. `${!name:-}` is kept — variable indirection is bash 2.0 and the modifier applies to the
indirected value, which bash 3.2's own manual states. `shopt -s nullglob` and the other bash-5-only comfort
is confined to `in_container`, which by definition runs in the container.

Empty-array expansion is the trap that would bite next and is already handled: under `set -u`, bash 3.2
treats `"${ARR[@]}"` on an empty array as unbound, so both optional-argument arrays use the
`${ARR[@]+"${ARR[@]}"}` form.

---

## 2026-08-22 (later) — first build attempt: two defects, both fixed

The first `agent.sh bootstrap` on the host got as far as step 7 of 17 and failed. Both findings are the kind
that only a real build produces, which is why README's *Known gaps* item 1 said so rather than claiming the
image was good.

### 1. `apt-get purge sudo` is refused, by design, and exits 100

```
Removing sudo (1.9.15p5-3ubuntu5.24.04.2) ...
You have asked that the sudo package be removed, but no root password has been set.
Without sudo, you may not be able to gain administrative privileges.
…
Refusing to remove sudo.
dpkg: error processing package sudo (--remove): … exit status 1
```

Debian's `sudo` prerm script guards against a human locking themselves out of their own machine when no root
password exists. Here that outcome **is the objective**, and there is nothing to lock out of: the container
is disposable, and the operator reaches root with `docker exec -u root` from the host whenever they need to.
The documented override is `SUDO_FORCE_REMOVE=yes`, which the layer now exports.

Worth stating plainly because it looks like a workaround and is not: the guard's premise (a human will need
administrative access to this system later) is false for this image, and the guard has no other effect. The
Dockerfile comment says not to copy the line into a profile where somebody actually logs in.

### 2. The build context was 11.68 GB

```
=> [internal] load build context                    83.5s
=> => transferring context: 11.68GB                 81.6s
=> [ 5/17] COPY --chown=motoko:motoko . /tmp/…     120.0s
```

Over three minutes before a single package was installed, on every build. The root `.dockerignore` is tuned
for the operator profile and drops only `node_modules`, `dist`, `tmp` and `.git`.

The fix is `Dockerfile.dockerignore` beside the Dockerfile — BuildKit reads `<dockerfile>.dockerignore` in
preference to the context root's, so the operator's build is untouched. It **replaces** rather than extends
the root file, so the root's entries are repeated in it.

What made this available: the COPY exists for exactly one purpose, to give
`scripts/install-prerequisites.sh` a tree to run against, and the real working tree arrives at run time
through the bind mount. Reading the installer, all it takes from the tree is itself and `src/tui` (for
`bun install && bun run build`, which is `tsc` and self-contained). It notably does **not** read the in-tree
`ailang/`: `install_ailang()` clones the pinned tag into `~/.local/share/ailang` and builds from there.

Measured after: **17.9 MB**, from 11.68 GB. The largest single exclusions were `.ailang` (2.4 G),
`deepseek-harness` (1.6 G), `.emsdk` (1.6 G), `.pnpm-store` (1.4 G) and `.motoko` (1.0 G).

It is a denylist rather than an allowlist deliberately: an allowlist that misses a future in-tree dependency
fails the build in a way that reads as a script bug, whereas a stale denylist only makes the build slower.

**One-off cost of taking this now.** Changing the context invalidates the `COPY` layer and therefore
step 6 as well, so the next build re-runs `install-prerequisites.sh` (~227 s on the first attempt) instead of
resuming from step 7. Every build after that saves the ~200 s the context cost.

**How to tell the ignore file took effect:** the `transferring context:` line in the build output. It read
`11.68GB` before, and should now read tens of megabytes. If it still reads gigabytes, this BuildKit is old
enough not to look for a per-Dockerfile ignore file — the build still works, just slowly.

---

## 2026-08-22 — adapted from another project's profile, targeted at motoko + herdr

This profile was adapted from a confined-agent container developed for a different project, whose
paths, harness, database and repository names were all its own. Everything below is motoko's; the
source material is not reproduced here and nothing in this directory depends on it.

Decisions taken by the owner before any file was written:

* **Full profile**, minus `tools/tmux-web` (RESEARCH §7 F-3, F-4).
* **Payload: herdr**, running motoko's own toolchain plus Claude Code, Codex and OMP as panes. This is the
  thing that reshaped the port — see §3.
* **The operator's devcontainer is untouched** (F-2): two containers, one tree, nothing existing breaks.
* **Standalone network, no host route** (§4.3), accepting that the obsidian MCP server becomes
  unreachable. *(Left as written. The phrase "no host route" is withdrawn by the 2026-08-22
  correction at the top of this file: dropping `extra_hosts` removes the host NAME, not the route.
  The obsidian consequence stands, because `.mcp.json` addresses that server by name.)*

### 1. The gap this closes, re-measured in motoko's own devcontainer

`checks/r9-container.sh --in-container` and `checks/agent-socket-probe.py`, run inside the attached
devcontainer this port was written in:

| leg | result |
|---|---|
| 2 — no docker socket, no docker binary | PASS |
| 2 — `sudo -n true` refused | **FAIL** — `.devcontainer/Dockerfile:13` writes `motoko ALL=(root) NOPASSWD:ALL` |
| 2 — no ssh binaries | PASS *nominally* — all six absent, but with passwordless root that is a speed bump |
| 3 — no forwarded sockets | **FAIL on five**: `SSH_AUTH_SOCK`, `REMOTE_CONTAINERS`, `REMOTE_CONTAINERS_IPC`, `REMOTE_CONTAINERS_SOCKETS`, `VSCODE_IPC_HOOK_CLI`, plus five live socket **files** including `~/.gnupg/S.gpg-agent` |
| 4 — no remote-containers credential helper | **FAIL** — configured in `/etc/gitconfig` *and* `~/.gitconfig` |
| 4 — no `gho_`-shaped credential | **FAIL** |
| 6 — no `host.docker.internal` | **FAIL** — `.devcontainer/docker-compose.yml:9-10` |

**One line is sharper than the research doc recorded.** RESEARCH §2 (2026-08-20) noted that
`git credential fill` returned *no* credential at the time of measurement, and was careful to say that this
did not clear the leg. Today it returns a **`gho_`-shaped value**: the operator's OAuth session is not merely
announced to this UID, it *answers*. The value was never printed — the grep is the whole test.

The socket probe, separately, reports the ssh-agent as a **CONDUIT** (answers, 0 identities) and the
extension-created gpg socket as **DEAD**. Neither is an oracle *today*. That is not a control: one `ssh-add`
on the host re-arms the first with no signal inside the container, which is exactly why R9 leg 3 asserts
absence rather than emptiness.

Also measured, and relevant to the compose file: **`MOTOKO_BOT_GH_TOKEN` is unset in the operator's running
container** even though it is present in the repository `.env`. `.devcontainer/docker-compose.yml` declares
`${MOTOKO_BOT_GH_TOKEN:-}`, and Compose interpolates from a `.env` in the *compose file's* directory —
`.devcontainer/.env`, which does not exist. So the whole curated environment block there resolves empty.
`agent.sh` passes `--env-file <repo>/.env` explicitly, which is why the same block does resolve here.

### 2. The R7 audit transfers unchanged, and the tree is clean

`r7_git_audit.py` was run against this tree before any edit, with the clauses exactly as the source recorded
them (shapes validated there against 1841 branch entries):

```
recorded 6 git configuration files under /workspaces/motoko_agent
  .emsdk/.git/config                     non-branch=7   branch=3    hooks_extra=0
  .git/config                            non-branch=11  branch=506  hooks_extra=0
  ailang/.git/config                     non-branch=11  branch=12   hooks_extra=0
  code-graph/lib/slicito/.git/config     non-branch=7   branch=3    hooks_extra=0
  deepseek-harness/.git/config           non-branch=7   branch=3    hooks_extra=3
  deepseek-harness/.git/config.worktree  non-branch=3   branch=0    hooks_extra=3
R7 f-1..f-4 PASS
```

Six configuration files, not the five RESEARCH §6 counted — `code-graph/lib/slicito` is deeper than that
survey's walk reached, and `deepseek-harness` carries a `config.worktree` as well. **527 `branch.*` entries,
zero shape violations**, so clause f-1(2) needed no adjustment for this tree: the measured suffix allow-list
and value shapes hold here as they did there.

**The three non-sample hooks are real and benign**: `deepseek-harness/.git/hooks/{pre-commit,
pre-merge-commit,pre-push}`, installed by `lefthook` and dispatching to a vendored
`node_modules/.../lefthook` binary. They answer RESEARCH §8 item 7 — the tree was *not* carrying an
exec-or-credential directive nobody put there deliberately. They are approved by being recorded; a change to
them is a finding.

Retargeted for motoko: the default `--root`, and the frozen-content set. `f-4 .omp/lsp.json` had no
counterpart, so its place is taken by `f-4 harness config` — `.mcp.json`, `AGENTS.md`, `.claude/**` and
`.agent/tools/**`, chosen on "does something read this and then run a program, or does it carry security
state". The rest of `.agent/**` is deliberately out: prose nothing executes, changing constantly, and a noisy
audit is an ignored audit. `.DS_Store` and `scheduled_tasks.lock` are excluded from both `--record` and
`--verify` for the same reason.

### 3. herdr replaces tmux, and changes what the profile is worth

The source profile spent a multi-stage Docker build and a 79-line `tmux.conf` on the session layer: tmux 3.7
compiled from source for DEC 2026 synchronized output, wheel bindings taken back from a TUI that grabs mouse
tracking, `history-limit`, RGB advertisement. None of that is here, because
[herdr](https://herdr.dev) (v0.8.2, Apache-2.0, one Rust binary) is the session layer instead, and it is a
client/server design whose client attaches over `docker exec` exactly as tmux's did.

What that buys beyond parity, and why it is worth the swap:

* **The delegation surface project 018 wants, with no integration code.** `herdr pane split` / `pane run`
  start an agent; `herdr agent list|read|prompt --wait --until idle|wait` observe and drive it; a human can
  watch and type into the same pane. The source profile needed `tools/tmux-web` (397 lines of controller
  plus a socat sidecar) to get the last of those.
* **`herdr worktree create`** is a per-delegate git worktree as one command, which is RESEARCH §7 F-5's
  option available for free — though **not adopted**: herdr's default worktree directory is `~/.herdr`,
  which nothing mounts, so a checkout there dies with the container. `herdr.toml` says so rather than
  quietly repointing it.
* **`herdr terminal session observe|control`** emit newline-delimited JSON frames with base64 ANSI, which is
  a better bridge for any future web view than scraping `capture-pane`. That is most of why `tools/tmux-web`
  was not ported.

**No sshd, for the same reason the source rejected it.** herdr's documented remote paths are both SSH —
`ssh host && herdr`, or `herdr --remote host` — and neither is used: `docker exec` is the client transport,
so the authentication is the host docker socket, which the operator holds and the agent does not. `ssh -A`
or a stray `ForwardAgent yes` would re-forward the operator's agent socket into the namespace this profile
exists to clear; `docker exec` has no such flag, so there is nothing to forget.

**Two things about herdr that needed handling rather than accepting.** `update.version_check` and
`manifest_check` are on by default and reach herdr.dev in the background; both are off in `herdr.toml`,
because what herdr believes about an agent's state should not change under a running container with no
record of when. And `herdr update` writes to `~/.local/bin`, which the agent *can* write and which is
*earlier* on `PATH` than the root-owned `/usr/local/bin` copy — so installing it as root is a speed bump, not
a control, and both the Dockerfile and the README say so in those words.

### 4. Versions are pinned in the tree, not resolved on every start

The source profile resolved `omp@latest` on the host at every start and passed it as a build arg. The
mechanism is right — a build arg whose *value* changes is what invalidates a Docker layer, and
`RUN bun install -g …@latest` on its own caches for ever — but the consequence is that every command needs
the network, including `stop`.

`versions.env` keeps the mechanism and moves the value into the tree: five pins plus both herdr sha256s,
read by `agent.sh` on every command, so `stop`, `sessions`, `logs` and `build` work offline. `agent.sh
upgrade` is the only thing that re-resolves, and it rewrites the file from a template and prints the diff —
so an upgrade is a commit, and "what is the agent running" is answerable from `git log` rather than from
whoever last built.

Verified today: the resolver's output and the committed `versions.env` are byte-identical, so a no-op
`upgrade` produces an empty diff.

**One defect found by running it.** `https://herdr.dev/latest.json` answers **403 Forbidden** to urllib's
default `Python-urllib/3.x` User-Agent while serving the identical request under a curl-shaped one. The
resolver therefore sets an explicit UA. Without it the upgrade path fails in a way that reads as an outage.

### 5. Deliberately not done

Listed here because a silent omission reads as an oversight later.

* **Nothing was run that needs docker.** The image has not been built; no session has been started. README's
  *Known gaps* enumerates what a first run settles — chiefly whether the build survives `sudo` being purged,
  whether motoko's TUI renders in a herdr pane, and whether the herdr integrations take at build time
  (they may need a running server, which is why `agent.sh bootstrap` re-runs them).
* **The operator's container was not hardened.** Removing the NOPASSWD drop-in and `host.docker.internal`
  from `.devcontainer/**` is a separate, deliberate change, and the owner chose "untouched" for this pass.
* **The repository's branch/tag protection is still unmeasured** (RESEARCH §8 item 6). The bot account bounds
  *who* acts; protection bounds *what* the credential can do, and a bot account does not imply it. This is
  the half of the source record motoko has not answered, and it is operator-side work — reading it needs
  `administration: read`, which the bot must not hold.
