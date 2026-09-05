# agent_confined — the agent's own image.
#
# Adapted from a confined-agent container profile developed for another project. Every absence below
# is a decision rather than an omission, and the reason is stated where it is made. This file records
# only what differs from .devcontainer/Dockerfile, and why:
#
#   * NO sudo and NO sudoers drop-in in the FINAL image. The operator's profile writes
#     `motoko ALL=(root) NOPASSWD:ALL` (.devcontainer/Dockerfile:13), which is what makes "ssh is absent from
#     the image" a speed bump rather than a boundary — the agent can `apt-get install openssh-client`. sudo is
#     kept during the build because scripts/install-prerequisites.sh needs root for apt, and is purged in the
#     root layer that follows. The build then ASSERTS its absence, so a future edit that reintroduces it fails
#     here rather than silently in production.
#   * NO openssh-client/-server, NO docker CLI. The ssh oracle is the whole point of the exercise
#     (checks/agent-socket-probe.py measures it on the operator's side); a docker socket would hand this
#     container host root.
#   * herdr and the agent CLIs are BAKED IN *because* the agent cannot install anything. Corollary the
#     operator owns: the agent cannot upgrade its own harness either — `agent.sh build` is the upgrade path,
#     and it resolves the current release of each one on the host every time (see the version-arg note below).
#
# Build context is the REPOSITORY ROOT, not this directory: install-prerequisites.sh runs against a copy of
# the tree. See docker-compose.yml.

# ---------------------------------------------------------------------------- herdr-sidebar (stage)
# A VS Code-style sidebar for herdr — file explorer plus source control — from
# github.com/alexarthurs/herdr-sidebar (MIT, 156 stars). It is a ratatui TUI, NOT a graphics
# application, so none of the reasons terminal-browser failed in this container apply to it.
#
# A SEPARATE STAGE so a Rust toolchain never reaches the final image. The plugin publishes no
# binaries (11 releases, 0 assets), so it must be compiled; `rust:1` is ~1.5 GB and the target
# directory another chunk, and all of it is discarded here. Only the linked binary survives.
#
# WHY BUILD HERE RATHER THAN LET `herdr plugin install` DO IT. That command clones and runs the
# manifest's `[[build]]` — `cargo build --release` — so it would need cargo in the runtime image, and
# herdr "reports build failures but does not install missing toolchains". `plugin link` deliberately
# does NOT run build commands ("local authors build their working tree themselves"), which is exactly
# the split this stage exploits.
#
# PINNED BY TAG, and deliberately not auto-resolved by agent.sh like the CLIs are. This is
# third-party code that executes inside the confined container; the pin IS the review boundary, and
# bumping it should mean someone read the diff. Same reasoning as PLAYWRIGHT_VERSION below.
# The pruning inside the RUN keeps the manifest and the one binary the manifest's [[panes]] command
# names, and drops every intermediate — without it the COPY carries a multi-hundred-MB target/ into
# the final image, which is the whole thing this stage exists to avoid.
FROM rust:1 AS herdr-sidebar-build
ARG HERDR_SIDEBAR_REF=v0.9.0
RUN git clone --depth 1 --branch "${HERDR_SIDEBAR_REF}" \
        https://github.com/alexarthurs/herdr-sidebar /src \
    && cd /src/plugins/herdr-sidebar \
    && cargo build --release \
    && test -x target/release/herdr-sidebar \
    && find target -mindepth 1 -maxdepth 1 ! -name release -exec rm -rf {} + \
    && find target/release -mindepth 1 -maxdepth 1 ! -name herdr-sidebar -exec rm -rf {} + \
    && rm -rf /src/.git \
    && du -sh /src/plugins/herdr-sidebar

FROM ubuntu:24.04

ARG USERNAME=motoko
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# `sudo` IS in this list, and it is removed again further down. install-prerequisites.sh takes root from
# either `id -u == 0` or `sudo` (scripts/install-prerequisites.sh:201-209) and installs the user-space half —
# bun, go, the ailang toolchain, ~/.local/bin — into $HOME. Running the whole script as root would put that
# half in /root, where the agent's uid cannot reach it; running it as `motoko` needs sudo for the apt half.
# So: sudo during the build, purged before the image is finished. RESEARCH §4.2 calls this the cheap route
# and notes it reaches the same end state as splitting the script in two.
#
# ncurses-bin/ncurses-term are NOT in the operator's image and are here on purpose: agent.sh resolves a TERM
# the container can actually look up (`infocmp`), and installs the host's own entry with `tic` when it cannot
# — the difference between a usable TUI and a wall of `_` for anyone on Ghostty or kitty.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        sudo \
        unzip \
        ncurses-bin \
        ncurses-term \
        bash-completion \
        less \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "$USER_GID" "$USERNAME" && \
    useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME" && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" && \
    chmod 0440 "/etc/sudoers.d/$USERNAME"

ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.bun/bin:/usr/local/go/bin:${PATH}"

# ---------------------------------------------------------------------------- motoko's own toolchain
# Identical to .devcontainer/Dockerfile: Go, Bun, Node, DuckDB, Z3, gh, chdb, context-mode, the AILANG
# runtime at its pinned tag, and the src/tui bun dependencies. Kept as one call to the repository's own
# script rather than re-listed here, so the two profiles cannot drift on what "motoko builds" means.
WORKDIR /tmp/motoko_agent
COPY --chown=${USERNAME}:${USERNAME} . /tmp/motoko_agent

# The cache cleanup is in the SAME `RUN`, and that is the whole point: Docker layers are additive, so
# deleting these in a later step would shrink nothing — the bytes are already committed below.
#
# MEASURED in the operator's container, 2026-08-22: `~/go/pkg/mod` alone is **1.2 GB** of Go module
# downloads left behind by building the AILANG toolchain, plus a `go-build` cache on top. None of it
# is needed at runtime; all of it was being baked into the image and into the builder's disk. This
# was found the direct way — a build failed at this very line with
# `/usr/bin/ld: final link failed: No space left on device`.
#
# `~/.local/share/ailang` (537 MB, the toolchain's source clone) is deliberately NOT removed: the
# built binary is copied to ~/.local/bin/ailang, but whether anything resolves the stdlib back
# through that directory has not been checked, and a broken toolchain is a worse trade than 537 MB.
USER ${USERNAME}
RUN ./scripts/install-prerequisites.sh \
    && go clean -modcache \
    && go clean -cache \
    && rm -rf /home/${USERNAME}/.cache/go-build /home/${USERNAME}/.npm \
    && echo "build caches cleared: $(du -sh /home/${USERNAME}/go 2>/dev/null | cut -f1) left in ~/go"

# ---------------------------------------------------------------------------- the confinement, applied
# Purge sudo and drop the sudoers file, then ASSERT both. The assertion is the point: without it, an edit
# above that reinstalls sudo as a dependency of something else would produce an image that looks confined and
# is not, and nothing would say so until an audit.
#
# SUDO_FORCE_REMOVE=yes is REQUIRED, not belt-and-braces. sudo's prerm script refuses to uninstall itself
# when no root password is set — "Without sudo, you may not be able to gain administrative privileges…
# Refusing to remove sudo" — and dpkg exits 100 (measured on the first build, 2026-08-22). That guard exists
# to stop a human locking themselves out of their own machine. Here, being unable to gain administrative
# privileges is the entire objective, and there is nothing to lock out of: the container is disposable, and
# the operator reaches root through `docker exec -u root` from the host whenever they need it. So the
# override is the correct answer rather than a workaround — but do NOT copy this line into a profile where
# somebody actually logs in.
USER root
RUN SUDO_FORCE_REMOVE=yes; export SUDO_FORCE_REMOVE \
    && rm -f "/etc/sudoers.d/$USERNAME" \
    && apt-get purge -y --auto-remove sudo \
    && rm -rf /tmp/motoko_agent /var/lib/apt/lists/* \
    && ! command -v sudo \
    && ! test -e "/etc/sudoers.d/$USERNAME" \
    && for b in ssh sshd ssh-add ssh-agent ssh-keygen scp docker; do \
         ! command -v "$b" || { echo "REFUSING TO BUILD: $b is present in the image" >&2; exit 1; }; \
       done \
    && echo "confinement asserted: no sudo, no ssh, no docker"

# Off the directory the layer above just deleted, before anything else runs with it as its cwd.
WORKDIR /

# ---------------------------------------------------------------------------- herdr, the session layer
# herdr (https://herdr.dev) replaces the source profile's tmux: a background session server plus terminal
# clients, so `agent.sh attach` hands you a session that survives the terminal closing. It also supplies the
# thing tmux did not — a CLI and local socket API for spawning, reading and waiting on agent panes, which is
# how motoko and the delegate CLIs are started inside here.
#
# WHY NOT `curl https://herdr.dev/install.sh | sh`: that installer resolves "latest" at RUN time, which Docker
# then caches forever — the image would silently keep whatever was current the day the layer was first built.
# agent.sh resolves the version AND its published sha256 from https://herdr.dev/latest.json on the host and
# passes both in, so the arg VALUE changes when upstream publishes, which is what invalidates this layer. The
# checksum is verified here rather than trusted: the same manifest supplies both, so this catches a corrupted
# or truncated download, not a compromised manifest.
#
# INSTALLED AS ROOT, into /usr/local/bin. `herdr update` writes to ~/.local/bin, which IS writable by the
# agent and IS earlier on PATH — so this is a speed bump, not a control, in the same class as
# GH_PROMPT_DISABLED below. What it buys: the binary the operator installed cannot be overwritten in place,
# so `agent.sh build` remains the upgrade path and a self-update is visible as a second binary.
ARG HERDR_VERSION
ARG HERDR_SHA256
RUN test -n "${HERDR_VERSION}" && test -n "${HERDR_SHA256}" \
    || { echo "HERDR_VERSION and HERDR_SHA256 are required — build through agent.sh, which resolves both" >&2; exit 1; }
RUN arch="$(uname -m)" \
    && case "$arch" in \
         aarch64|arm64) target=linux-aarch64 ;; \
         x86_64|amd64)  target=linux-x86_64 ;; \
         *) echo "no herdr release asset for $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSL -o /tmp/herdr \
         "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VERSION}/herdr-${target}" \
    && printf '%s  /tmp/herdr\n' "${HERDR_SHA256}" | sha256sum -c - \
    && install -o root -g root -m 0755 /tmp/herdr /usr/local/bin/herdr \
    && rm -f /tmp/herdr \
    && herdr --version

# ---------------------------------------------------------------------------- headless web access
# `agent-browser` (vercel-labs) — browser automation built for agents rather than for test suites:
# a native Rust binary plus a persistent daemon driving Chromium over CDP. It NEVER touches the
# terminal, which is the whole reason it is here and terminal-browser is not (measured 2026-08-22; the log is local-only, see README *Where the measurement record lives*):
# no Kitty graphics, no pixel geometry from `docker exec`, no GPU path to miss.
#
# The centrepiece for an agent is the ref system: `snapshot -i` returns an accessibility tree with
# stable handles (`[ref=e20]`), and `click @e20` acts on one — deterministic where CSS selectors are
# brittle. Verified end to end on this architecture, 2026-08-22: a real GitHub page loaded and
# snapshotted through exactly the layers below.
#
# THREE PARTS, and the middle one is the awkward one.

# (1) Chromium's shared libraries. MEASURED with `ldd`, not copied from a tutorial: 19 entries, which
# are exactly what the Playwright chromium below requires on ubuntu:24.04/arm64. Root, therefore
# image-only — with no sudo the agent cannot add them later. Fonts are NOT optional: Chromium with no
# fontconfig match dies rather than rendering blank.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
        libasound2t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libatspi2.0-0t64 \
        libcairo2 libcups2t64 libdbus-1-3 libgbm1 libgtk-3-0t64 \
        libnspr4 libnss3 libpango-1.0-0 libxkbcommon0 \
        fonts-liberation fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# (2) A browser, and NOT the one agent-browser wants to install. `agent-browser install` fetches
# Chrome for Testing, which refuses on this host:
#
#     Chrome for Testing does not provide Linux ARM64 builds.
#
# Its own advice — `apt install chromium` — does not work either: Ubuntu 24.04 ships chromium as a
# snap stub. Playwright is the only source of a genuine arm64 Chromium build, and agent-browser
# already probes the Playwright cache among its candidates. `--only-shell` takes 340 MB instead of
# 641 MB and is enough for CDP work; take the full browser only if something needs a headed run or
# extensions.
#
# PINNED DELIBERATELY, unlike the CLIs that track latest: a floating Playwright silently changes the
# Chromium revision underneath a measurement. Bump it on purpose.
ARG PLAYWRIGHT_VERSION=1.62.1
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN npx --yes playwright@${PLAYWRIGHT_VERSION} install --only-shell chromium \
    && chmod -R a+rX /opt/ms-playwright \
    && npm cache clean --force

# A wrapper rather than a bare path, because two flags are mandatory HERE and forgetting either looks
# like a broken browser rather than a misconfigured one:
#   --no-sandbox            the setuid sandbox cannot work under `no-new-privileges:true` (compose)
#                           and unprivileged user namespaces are unavailable. THE CONTAINER IS THE
#                           BOUNDARY for this browser — which is a container holding the working tree
#                           and the compose environment's API keys. Do not point it at untrusted
#                           pages; a renderer exploit has nothing left to stop it.
#   --disable-dev-shm-usage docker gives /dev/shm 64 MB by default, which Chromium exhausts and then
#                           crashes. (It is larger under OrbStack, but this must not depend on that.)
# The glob absorbs Playwright's build-numbered directory, so the pin above can move without editing
# this path.
RUN printf '%s\n' '#!/bin/sh' \
        'exec /opt/ms-playwright/chromium_headless_shell-*/chrome-linux/headless_shell --no-sandbox --disable-dev-shm-usage "$@"' \
        > /usr/local/bin/chromium \
    && chmod 0755 /usr/local/bin/chromium

# (3) agent-browser itself. Installed with --ignore-scripts and the platform binary selected by hand:
# the package ships all seven platform binaries (~90 MB) and a postinstall that picks one, and that
# postinstall is both unnecessary here and blocked by default under bun. The other six are dropped.
#
# The skills need the package directory — the lone binary reports "Skills directory not found" — so
# skill-data stays and AGENT_BROWSER_SKILLS_DIR names it.
ARG AGENT_BROWSER_VERSION
RUN test -n "${AGENT_BROWSER_VERSION}" \
    || { echo "AGENT_BROWSER_VERSION is required — build through agent.sh, which resolves it" >&2; exit 1; }
RUN arch="$(uname -m)" \
    && case "$arch" in \
         aarch64|arm64) bin=agent-browser-linux-arm64 ;; \
         x86_64|amd64)  bin=agent-browser-linux-x64 ;; \
         *) echo "no agent-browser build for $arch" >&2; exit 1 ;; \
       esac \
    && npm install --no-save --ignore-scripts --prefix /tmp/ab "agent-browser@${AGENT_BROWSER_VERSION}" \
    && mkdir -p /opt/agent-browser \
    && cp -a /tmp/ab/node_modules/agent-browser/skill-data /opt/agent-browser/ \
    && cp -a /tmp/ab/node_modules/agent-browser/skills /opt/agent-browser/ \
    && install -o root -g root -m 0755 "/tmp/ab/node_modules/agent-browser/bin/${bin}" /usr/local/bin/agent-browser \
    && rm -rf /tmp/ab /root/.npm \
    && agent-browser --version

ENV AGENT_BROWSER_SKILLS_DIR=/opt/agent-browser/skill-data
ENV AGENT_BROWSER_EXECUTABLE_PATH=/usr/local/bin/chromium

# ---------------------------------------------------------------------------- the hand tools
# The everyday terminal kit, baked in because the agent CANNOT INSTALL ANYTHING — no sudo, and no
# route to apt — so "I'll grab it when I need it" is not available in this profile the way it is in
# the operator's. Baking them in is the only way they exist at all. Sourced from
# https://rockstardeveloperuniversity.com/best-terminal-cli-tools, minus its #14 (tmux/Zellij):
# herdr IS the session layer here, and a second multiplexer inside it is a way to lose a pane. `just`
# is the one addition that is not from that list.
#
# jq is already installed by scripts/install-prerequisites.sh and is deliberately not repeated.
#
# ripgrep IS listed below even though `rg` appears to work already — that `rg` is a shell FUNCTION
# the Claude Code CLI defines, which re-execs the claude binary with its bundled copy. It exists only
# in an interactive shell that sourced claude's shim, it is not on PATH for anything else, and it
# disappears if that CLI is not installed. A real binary is a different thing from a shim.
#
# ROOT, into /usr/local/bin, for the same reason herdr is: what the operator installed cannot be
# overwritten in place. Same caveat too — ~/.local/bin is writable and earlier on PATH, so this is a
# speed bump, not a control.
USER root

# apt for the four that Ubuntu packages at a version worth having and that ship no useful standalone
# binary. httpie is the one with a real cost — it is Python, not a static binary — but python3 and
# pip are already in this image from install-prerequisites.sh, so what it adds is its own dependency
# tree rather than an interpreter. If that ever needs to go, `xh` is the static-binary replacement
# that speaks the same command line.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ripgrep \
        htop \
        ncdu \
        httpie \
    && rm -rf /var/lib/apt/lists/* \
    && rg --version && htop --version && ncdu -v && http --version

# The rest come from upstream release archives rather than apt, and each for a stated reason:
#
#   eza       not packaged in Ubuntu 24.04 at all.
#   bat, fd   apt renames the binaries to `batcat` and `fdfind` (Debian name clashes), so every
#             snippet and muscle memory in the world is wrong against the packaged version.
#   fzf       noble ships 0.44; the shell integration used below (`fzf --bash`) landed in 0.48.
#   delta     noble ships 0.16 as `git-delta`, three minor versions behind.
#   tldr      the client is `tlrc`, the tldr-pages project's own Rust client, which installs its
#             binary as `tldr`. Not in noble.
#   just      noble ships 1.16, from June 2023; upstream is 1.58. Modules and most of the recipe
#             attributes landed in between, so the packaged version cannot read a current justfile.
#             This repo drives itself with make rather than just — `just` is here for the justfiles
#             that arrive with somebody else's repository.
#   lazygit   noble has no package.
#   spiceedit https://spice-edit.com — a mouse-first terminal editor for SSH/tmux work. Binary name
#             has no hyphen. Not in any distro.
#
# PINNED BY VERSION ARG WITH A DEFAULT HERE, deliberately NOT in versions.env. That file is the set of
# pins `agent.sh upgrade` re-resolves from upstream on demand, which is right for the harness — herdr
# and the agent CLIs — and wrong for hand tools whose version nobody is racing. This is the same call
# PLAYWRIGHT_VERSION already makes, and for the reason versions.env states beside it: a pin that lives
# in the Dockerfile is one somebody bumps on purpose.
#
# NOT `curl … | sh` for any of them, and this is the reason the herdr block above already gives: those
# installers resolve "latest" at RUN time, Docker caches the layer, and the image then keeps whatever
# was current the day it was first built, forever. A pinned archive URL changes when the ARG changes,
# which is what makes the layer invalidate honestly.
#
# INTEGRITY follows the convention this file already uses: verify when upstream publishes a digest
# (herdr does, from its manifest), otherwise pin the version and assert the binary runs (as
# PLAYWRIGHT_VERSION and AGENT_BROWSER_VERSION do). Four of the ten publish a checksums file and
# get the third field; the other six do not publish one at all, and inventing hardcoded hashes here
# would only restate a digest computed from the same download. `--ignore-missing` is required for the
# ones that do: the file lists every platform's archive and exactly one of them is on disk.
#
# THE ARCHIVES DISAGREE ON EVERYTHING — how to spell amd64 (`x86_64`, `amd64`, `linux_x86_64`),
# whether the tag carries a `v`, and whether the binary sits at the archive root or one directory
# down. Rather than encode ten layouts, the loop extracts and then FINDS the executable by name,
# which is the one thing all ten agree on. zoxide publishes musl-only builds for Linux; that is
# fine, and is why it gets its own target token.
ARG FZF_VERSION=0.74.3
ARG BAT_VERSION=0.26.1
ARG EZA_VERSION=0.23.5
ARG FD_VERSION=10.5.0
ARG ZOXIDE_VERSION=0.10.0
ARG DELTA_VERSION=0.19.2
ARG TLRC_VERSION=1.13.1
ARG JUST_VERSION=1.58.0
ARG LAZYGIT_VERSION=0.64.1
ARG SPICEEDIT_VERSION=0.0.43
RUN set -eu; \
    arch="$(uname -m)"; \
    case "$arch" in \
      aarch64|arm64) rust=aarch64-unknown-linux-gnu; musl=aarch64-unknown-linux-musl; go=linux_arm64; lg=linux_arm64 ;; \
      x86_64|amd64)  rust=x86_64-unknown-linux-gnu;  musl=x86_64-unknown-linux-musl;  go=linux_amd64; lg=linux_x86_64 ;; \
      *) echo "no release assets for $arch" >&2; exit 1 ;; \
    esac; \
    gh=https://github.com; \
    for spec in \
      "fzf|$gh/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${go}.tar.gz|$gh/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf_${FZF_VERSION}_checksums.txt" \
      "bat|$gh/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-${rust}.tar.gz|" \
      "eza|$gh/eza-community/eza/releases/download/v${EZA_VERSION}/eza_${rust}.tar.gz|" \
      "fd|$gh/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${rust}.tar.gz|" \
      "zoxide|$gh/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-${musl}.tar.gz|" \
      "delta|$gh/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-${rust}.tar.gz|" \
      "tldr|$gh/tldr-pages/tlrc/releases/download/v${TLRC_VERSION}/tlrc-v${TLRC_VERSION}-${rust}.tar.gz|" \
      "just|$gh/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${musl}.tar.gz|$gh/casey/just/releases/download/${JUST_VERSION}/SHA256SUMS" \
      "lazygit|$gh/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_${lg}.tar.gz|$gh/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/checksums.txt" \
      "spiceedit|$gh/cloudmanic/spice-edit/releases/download/v${SPICEEDIT_VERSION}/spiceedit_${SPICEEDIT_VERSION}_${go}.tar.gz|$gh/cloudmanic/spice-edit/releases/download/v${SPICEEDIT_VERSION}/checksums.txt" \
    ; do \
      bin="${spec%%|*}"; rest="${spec#*|}"; url="${rest%%|*}"; sums="${rest#*|}"; \
      rm -rf /tmp/tool; mkdir -p /tmp/tool; \
      curl -fsSL -o "/tmp/tool/$(basename "$url")" "$url"; \
      if [ -n "$sums" ]; then \
        curl -fsSL -o /tmp/tool/checksums.txt "$sums"; \
        ( cd /tmp/tool && sha256sum --ignore-missing -c checksums.txt ); \
      else \
        echo "==> $bin: upstream publishes no checksum file; pinned at its version arg"; \
      fi; \
      tar xzf "/tmp/tool/$(basename "$url")" -C /tmp/tool; \
      found="$(find /tmp/tool -type f -perm -u+x -name "$bin" | head -1)"; \
      [ -n "$found" ] || { echo "no '$bin' executable inside $url" >&2; exit 1; }; \
      install -o root -g root -m 0755 "$found" "/usr/local/bin/$bin"; \
    done; \
    rm -rf /tmp/tool; \
    fzf --version; bat --version; eza --version; fd --version; \
    zoxide --version; delta --version; tldr --version; just --version; \
    lazygit --version; spiceedit --version

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ---------------------------------------------------------------------------- the agents herdr starts
# Pinned by the same host-resolved-arg mechanism as herdr, for the same caching reason. `bun install -g`
# rather than npm: bun is already first on PATH from install-prerequisites.sh, and its global prefix is
# ~/.bun/bin, which is inside the image rather than a root-owned tree.
#
# Each `herdr integration install` is run at BUILD time. It writes into the agent's own config directories
# (~/.claude, ~/.codex, ~/.config/herdr), and nothing mounts /home/motoko — so an install done at runtime
# would be discarded by the next `agent.sh stop`. Session identity and lifecycle reporting are what these
# buy; herdr detects the agents without them, but cannot restore their native sessions.
ARG CLAUDE_CODE_VERSION
ARG CODEX_VERSION
ARG OMP_VERSION
RUN test -n "${CLAUDE_CODE_VERSION}" && test -n "${CODEX_VERSION}" && test -n "${OMP_VERSION}" \
    || { echo "agent CLI versions are required — build through agent.sh, which resolves them" >&2; exit 1; }
RUN bun install -g \
        "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
        "@openai/codex@${CODEX_VERSION}" \
        "@oh-my-pi/pi-coding-agent@${OMP_VERSION}" \
    && claude --version \
    && codex --version \
    && omp --version

# herdr's configuration. See the file for what each setting answers.
#
# It is copied BEFORE the integrations below, not after: `herdr integration install` may write into
# ~/.config/herdr itself, and a COPY placed after it would silently discard whatever it wrote. That ordering
# costs a rebuild of the two layers below whenever this file changes, which is seconds.
#
# The mkdir is not redundant. COPY creates missing parent directories owned by ROOT, and herdr writes its
# logs and runtime state into this same directory as `motoko` — so without this the container starts and
# then fails to log, which is a confusing way to discover a permissions problem.
RUN mkdir -p /home/${USERNAME}/.config/herdr
COPY --chown=${USERNAME}:${USERNAME} .devcontainer/agent_confined/herdr.toml \
     /home/${USERNAME}/.config/herdr/config.toml

# The integrations, attempted at build time. Failures are reported and tolerated for two distinct reasons: an
# integration upstream renames must not fail the whole build, and herdr's CLI normally talks to a RUNNING
# server — which there is none of during a build, so these may legitimately not take here. `agent.sh
# bootstrap` re-runs the same three against the live server, which is the path that is expected to work; this
# layer is the cheap attempt that saves it when it does.
RUN for i in claude codex omp; do \
        herdr integration install "$i" || echo "note: build-time 'herdr integration install $i' did not take"; \
    done; true

# ---------------------------------------------------------------------------- the agent's git identity
# Everything this container does on GitHub is the bot (016 ADR-001 D1 as amended by C9), and that has
# to be true of git as well as of `gh` — a PR opened as motoko-agent over commits authored by nobody
# is a worse record than either alone.
#
# CREDENTIAL: `gh auth git-credential` resolves from GH_TOKEN, which docker-compose.yml maps from
# MOTOKO_BOT_GH_TOKEN for this profile. So `git push` works with no stored credential and no
# interactive login — which matters because nothing mounts /home/motoko, so anything interactive
# would have to be redone on every rebuild. No secret is baked here: this is a pointer to a helper,
# and the token arrives at run time through the environment.
#
# EMAIL: the `<user>@users.noreply.github.com` form. GitHub's canonical modern form is
# `<id>+<user>@users.noreply.github.com`, and if commits should link to the bot's profile you want
# that one — get it with `gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"'` while
# authenticated as the bot, and set it here. Left as the short form deliberately rather than guessing
# an id.
RUN git config --global user.name  "motoko-agent" \
    && git config --global user.email "motoko-agent@users.noreply.github.com" \
    && git config --global credential.helper '!gh auth git-credential' \
    && git config --global --list | grep -E '^(user|credential)\.'

# ---------------------------------------------------------------------------- herdr-sidebar (link)
# Registered with `plugin link`, not `plugin install`: the binary was already built in the stage
# above, and link is the path that does not want a toolchain. Both work with no herdr server running,
# which is what makes this possible at build time — and build time is the only option, because
# nothing mounts /home/motoko, so a plugin installed at run time would vanish on the next rebuild.
#
# Placed after the herdr.toml COPY on purpose: registration writes into herdr's own config/state, and
# a COPY landing afterwards could discard it.
#
# Open it with `herdr plugin action invoke herdr-sidebar.open-sidebar`, or bind that to a key.
COPY --from=herdr-sidebar-build --chown=${USERNAME}:${USERNAME} \
     /src/plugins/herdr-sidebar /opt/herdr-sidebar
RUN herdr plugin link /opt/herdr-sidebar \
    && herdr plugin list

# ---------------------------------------------------------------------------- herdr-dagr (install)
# The live delegation DAG viewer (`scripts/dagr-pane.sh`, MOT-136/137) and the contract
# checker `make verify_dagr_producer` runs against. Installed with `plugin install`, not
# `plugin link`: unlike herdr-sidebar this plugin publishes checksum-verified release
# binaries, so its own `scripts/install.sh` fetches the binary for the exact pinned commit
# and no Rust toolchain is needed in this image. Install works with no herdr server
# running, which is what makes this possible at build time - and build time is the only
# option, because nothing mounts /home/motoko, so a plugin installed at run time would
# vanish on the next rebuild.
#
# PIN: Makefile DAGR_VERSION is the source of truth (CI parses it out of the Makefile
# and refuses the skip with DAGR_REQUIRED=1). This re-reads it from the build context
# rather than carrying a second version literal, so the two cannot drift. The symlink
# puts `dagr` on PATH so `command -v dagr` - the first thing Makefile DAGR_BIN probes -
# resolves without knowing the plugin's hashed install directory.
#
# The --chown is LOAD-BEARING, not tidiness. COPY lands as root:root whatever USER is in
# effect, /tmp carries the sticky bit, and the `rm` below runs as ${USERNAME} - which is
# EPERM on a root-owned file in a sticky directory, and `rm -f` does not swallow that (it
# only swallows a missing file). The build failed exactly there: the plugin installed, then
# the step died on the cleanup. Owning the file makes the removal the no-op it was meant
# to be. It shrinks nothing either way - the COPY layer keeps the bytes - it just stops a
# stale pin from sitting in the running container's /tmp.
COPY --chown=${USERNAME}:${USERNAME} Makefile /tmp/motoko_Makefile.pin
RUN version="$(sed -nE 's/^DAGR_VERSION \?= ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' /tmp/motoko_Makefile.pin | head -n1)" \
    && test -n "$version" \
    && herdr plugin install aemrebarut/herdr-dagr --ref "v${version}" --yes \
    && rm -f /tmp/motoko_Makefile.pin \
    && herdr plugin list | grep -q herdr-dagr \
    && ln -sf "$(ls /home/${USERNAME}/.config/herdr/plugins/github/herdr-dagr-*/bin/dagr | head -n1)" \
         /home/${USERNAME}/.local/bin/dagr \
    && /home/${USERNAME}/.local/bin/dagr --version



# ---------------------------------------------------------------------------- the hand tools, wired up
# Three of the tools above do nothing useful as a bare binary on PATH — they are shell and git
# integrations that happen to ship as a binary. This is the half that makes them real, and it has to
# happen at BUILD time for the same reason the herdr integrations do: nothing mounts /home/motoko, so
# anything written here at run time is discarded by the next `agent.sh stop`.
#
# WHAT IS DELIBERATELY NOT HERE: aliases for `ls` → eza and `cat` → bat. They are the first thing every
# guide suggests and they are a bad trade in a container an AGENT drives — the agent reads command
# output as data, and silently swapping the formatter under two of the most-parsed commands in
# existence buys nicer colours at the cost of surprising a parser. `eza` and `bat` are one word away
# for anyone who wants them.
RUN printf '%s\n' \
      '' \
      '# --- hand tools (baked in by .devcontainer/agent_confined/Dockerfile) ---' \
      '# zoxide: adds `z <partial>` to jump to a directory you have visited. `cd` is untouched.' \
      'command -v zoxide >/dev/null && eval "$(zoxide init bash)"' \
      '# fzf: CTRL-T (paste a file path), CTRL-R (fuzzy history), ALT-C (cd), and ** completion.' \
      'command -v fzf >/dev/null && eval "$(fzf --bash)"' \
    >> /home/${USERNAME}/.bashrc \
    && tail -8 /home/${USERNAME}/.bashrc

# delta is a PAGER, so it is configured through git rather than invoked. This is safe for the agent's
# own scripted use: git disables its pager when stdout is not a tty, so `git diff` captured into a
# variable is byte-identical to before — only an interactive `git diff` changes.
#
# `merge.conflictStyle = zdiff3` is what delta's own README recommends alongside these and is
# deliberately LEFT OUT: it rewrites conflict markers, which is text the agent parses during a merge,
# and that is a real behaviour change rather than a display one.
#
# Appended to the git identity block's settings rather than merged into it: that block is about WHO
# commits, this one is about how a diff looks, and the grep at its end asserts the former.
RUN git config --global core.pager delta \
    && git config --global interactive.diffFilter 'delta --color-only' \
    && git config --global delta.navigate true \
    && git config --global --get core.pager

# tldr ships no pages — it downloads them on first use. Baking the cache in means the tool works on a
# container with no network and costs no first-run wait. ~30 MB for the English pages, measured.
RUN tldr --update

# THE FONT PROBE CANNOT BE RIGHT IN THIS TOPOLOGY, so it is turned off rather than answered.
#
# The sidebar picks its icon theme by asking whether a Nerd Font is INSTALLED — `fc-list` on Linux.
# That probe runs in this container; the thing that renders glyphs is the terminal on the operator's
# Mac. The two are unrelated. Left alone it always concludes "no Nerd Font" and offers to download
# JetBrainsMono into the container, where it changes nothing about rendering and is discarded on the
# next rebuild anyway, because nothing mounts /home/motoko. The plugin's own notes concede the
# underlying limit: "A TUI cannot detect whether the terminal font renders a glyph."
#
# ICONS=material is right for Ghostty specifically, which embeds a symbols-only Nerd Font, so Nerd
# Font codepoints render whatever the configured font family is — nothing needs installing anywhere.
# It is WRONG for a terminal without that coverage (VS Code's integrated terminal, by default), where
# the icons come out as tofu boxes. If that is where you attach, set HERDR_SIDEBAR_ICONS=emoji in
# docker-compose.yml's environment block, which overrides this.
#
# Why env and not the in-app toggle: pressing `i` in the sidebar switches theme and persists the
# choice to state.json under /home/motoko — which the next `agent.sh build` discards. The env is what
# makes the answer survive a rebuild.
ENV HERDR_SIDEBAR_FONT_PROMPT=off
ENV HERDR_SIDEBAR_ICONS=material

# UTF-8, and it is load-bearing rather than hygiene. `docker compose exec` does NOT forward the host's locale,
# so without this a client renders every non-ASCII cell as `_`. C.UTF-8 is built into glibc here, so nothing
# has to be generated and no `locales` package is needed.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Profile marker: makes "which image is this" a fact rather than an inference from a hostname.
# checks/r9-container.sh asserts it.
ENV MOTOKO_CONTAINER_PROFILE=agent_confined

# gh must never mint a second credential: its device flow issues a user OAuth token carrying
# repo/read:org/gist/workflow, which is precisely the forwarded-session shape this profile exists to avoid.
# The agent's GitHub identity is the 016_github_ops machine user, delivered as MOTOKO_BOT_GH_TOKEN through
# the compose environment. This is a speed bump, not a control — an agent can unset a variable.
ENV GH_PROMPT_DISABLED=1
ENV GH_NO_UPDATE_NOTIFIER=1

WORKDIR /workspaces/motoko_agent
