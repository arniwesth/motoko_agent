---
repo: arniwesth/motoko_agent
pr: 329
branch: fix/installer-root-only-when-needed
ticket: null
title: "fix(install): need root only at a step that installs system-wide"
---

## Summary

On Debian, `scripts/install-prerequisites.sh` stopped before its first step when the user was not
root and had no `sudo`: "This installer needs root privileges for system packages". It stopped even
when every system package was already installed. That blocked the AILANG v0.60.4 upgrade from #328
in the dev container, where the user is `motoko` with no `sudo`, although AILANG installs under
`$HOME` and has never needed root. Now the installer stops only at a step that must install
system-wide, and the error names the command.

## Changes

- fix(install): need root only at a step that installs system-wide

1 file changed.

- **No root and no `sudo`:** `SUDO` and `SUDO_E` become `need_root`, which stops the run with "This
  step needs root: <command>. Run as root or install sudo." The installer logs a warning when it
  starts. The steps that reach it are apt, Go in `/usr/local`, Node from NodeSource, and Omnigraph's
  apt packages and `/opt` clone. Run as root or with `sudo`, the installer behaves as before.
- **`apt-get update`** runs only when a package is missing. Checking with `dpkg -s` needs no root,
  and the package lists matter only for installing. The missing packages are logged first, so the
  root error follows the line that names them.

## Governing docs

None. The installer has no design record. #328 is the change this unblocks.

## Predicted outcome

In a container with every system package installed, a user without root or `sudo` can run the
installer, and it installs or upgrades everything under `$HOME`, AILANG included. If a system
package is missing, the run stops at the apt step and names the command that needed root. CI, which
has `sudo`, is unaffected: `dst-corpora.yml` runs the installer on GitHub's runners.

## Test evidence

All runs as `motoko` (uid 1001, no `sudo`) in the dev container, Debian arm64, with `HOME` set to
a scratch directory so the real `~/.local/bin/ailang` was not touched.

| Run | Result |
|---|---|
| main's installer | exit 1 at once: "This installer needs root privileges for system packages" |
| this branch, all system packages present | exit 0. Every step reports "already installed" up to AILANG. The AILANG step finds 0.54.14, updates the existing clone to v0.60.4, builds it, prints "ailang installed: AILANG v0.60.4" and then #328's cache warning |
| this branch, a `dpkg` stub on `PATH` that reports `jq` missing | exit 1 at the apt step: "This step needs root: env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get update -qq. Run as root or install sudo." |

The AILANG clone in the scratch `HOME` was seeded from the real one with `git clone --local`, then
pointed at GitHub, so the run took the "existing clone" path a real upgrade takes. Python, Go and
bun caches pointed at the real ones to save downloads. `bash -n` passes.

Not run: the root and `sudo` paths. Their only change is that `apt-get update` moves inside the
missing-packages branch. macOS is unchanged, because `configure_privilege` returns before this
code there.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
