#!/usr/bin/env bash
# Host-side launcher for the confined agent container.
#
# WHY THIS EXISTS: `agent_confined` deliberately has no devcontainer.json, so it does not — and must not —
# appear in VS Code's "Reopen in Container" picker. That picker lists only profiles with a devcontainer.json,
# and a devcontainer.json is what makes a container attachable, which is what forwards the operator's GitHub
# credential and ssh/gpg sockets into the agent's UID. R9 leg 1 asserts the file's absence. This script
# replaces the convenience the picker would have given, without restoring the attach path.
#
# RUN IT ON THE HOST — a terminal on your machine, or the integrated terminal of a VS Code window opened on
# the repository folder WITHOUT reopening in a container. It refuses to run inside a dev container, because
# from there it can reach neither the docker socket nor the point.
#
#   agent.sh                          # start (or re-attach to) the default herdr session
#   agent.sh [session=NAME] attach    # the same, for a named session
#   agent.sh bootstrap                # first-run setup inside the container: src/tui deps, herdr integrations
#   agent.sh shell                    # a bash prompt in the container, outside herdr
#   agent.sh run <command…>           # one-shot command in the container; no herdr, dies with the terminal
#   agent.sh sessions                 # list the herdr sessions inside the container
#   agent.sh [session=NAME] kill      # stop one session and its panes; the container stays up
#   agent.sh build                    # rebuild the image at the PINNED versions and restart
#   agent.sh upgrade                  # re-resolve every pinned version from upstream, rewrite, rebuild
#   agent.sh stop                     # stop and remove the container
#   agent.sh logs                     # follow container logs
#   agent.sh check                    # run the R9 acceptance sweep against the running service
#   agent.sh ovis [on|off|status]     # Ovis (phone client) on this machine and, over HTTPS, the tailnet
#   agent.sh help                     # this block, coloured on a terminal
#
# (Written `agent.sh` for brevity; invoke it by path — `.devcontainer/agent_sandbox/agent.sh …` — or alias
# it.)
#
# TWO KINDS OF SESSION, and the difference is the whole trick:
#
#   * a HERDR session is the background server that holds the panes. It lives in the container, survives this
#     script exiting, and its name is the handle you use here. `session=NAME` picks it; the default session
#     is unnamed and is addressed as `default`.
#   * inside one session, each AGENT is a pane. motoko, claude, codex and omp are all just panes, started
#     from herdr's own UI or from a script with `herdr pane split` / `herdr pane run`. Starting a second
#     agent does NOT need a second session, and usually should not have one.
#
# STARTING ANOTHER SESSION. Name one that does not exist yet: that is the entire gesture. Use it when you
# want panes that are genuinely independent — separate server, separate sockets, separate persisted state.
#
#   agent.sh                                     # the default session
#   agent.sh session=review                      # NEW: a second, independent herdr server
#   agent.sh session=review                      # again: RE-ATTACHES to it
#   agent.sh sessions                            # which names exist
#   agent.sh session=review kill                 # end just that one
#
# `session=NAME` must come FIRST, before the command, and applies to whatever follows. It is spelled
# `session=` rather than as a bare word because the first word is a command: `agent.sh shell` must stay the
# shell, and a session someone names `stop` must not become the `stop` command. No command contains `=`, so
# the two can never collide. `AGENT_HERDR_SESSION=NAME agent.sh …` is equivalent for scripts; the argument
# wins when both are given.
#
# Detach with `ctrl+b q` and the panes keep running. `stop` and `build` replace the container, so they end
# EVERY session; `kill` ends one.
#
# ONCE YOU ARE INSIDE, herdr's CLI is how agents get started and read back — it talks to the same socket the
# UI does, so a script and a human drive the identical thing:
#
#   herdr pane split --direction right --cwd /workspaces/motoko_agent   # -> .result.pane.pane_id
#   herdr pane run <pane_id> 'make run'                                 # start motoko in it
#   herdr agent list                                                    # what is running, and its state
#   herdr agent prompt <target> 'summarise the diff' --wait --until idle
#   herdr agent read <target> --source recent --lines 120
#
# HERDR AND THE AGENT CLIs ALWAYS BUILD AT LATEST; ONLY AGENT-BROWSER IS PINNED. `build` resolves herdr's
# current release and its sha256 from https://herdr.dev/latest.json on every run, and re-resolves the agent
# CLIs (claude, codex, omp) at npm `latest` — reproducibility of those is not a goal. versions.env beside
# this file pins the agent-browser version; every command reads it, so `stop`, `sessions` and `logs` work
# with no network (only `build` and `upgrade` touch the network). `upgrade` moves the agent-browser pin
# forward, rewrites the file and rebuilds — commit that diff. To build an older herdr for one command,
# export BOTH values: `HERDR_VERSION=0.8.2 HERDR_SHA256=<sha256 of your arch> agent.sh build`.
#
# ENVIRONMENT: AGENT_HERDR_SESSION (session name; `session=NAME` overrides it), AGENT_BROWSER_VERSION from
# versions.env (an exported value wins over the file), and HERDR_VERSION + HERDR_SHA256 (both or neither).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
COMPOSE_FILE="${HERE}/docker-compose.yml"
VERSIONS_FILE="${HERE}/versions.env"
SERVICE="agent"
# The agent image is BUILT here and never pushed anywhere, so a missing local image is not a pull away from
# being fixed. Named here so ensure_up can say that, instead of letting compose fall through to a registry
# and report "pull access denied … repository does not exist" — which reads like a credentials problem and
# is not one. `docker system prune -a` (make prune) is the usual way it goes missing.
IMAGE="motoko_agent_confined/dev:1.0"
# The proxy sidecar is the agent's ONLY route off-box (docker-compose.yml, egress boundary). It is named
# here because "is the stack up" has to mean both containers: an agent running beside a dead proxy looks
# healthy and fails every network call with a timeout that reads like a broken internet connection.
EGRESS_SERVICE="egress-proxy"
# Owns Ovis's published port (docker-compose.yml, ovis-relay). Not part of "is the stack up": only
# `agent.sh ovis` needs it, and that command starts it.
OVIS_RELAY_SERVICE="ovis-relay"
CONTAINER_USER="motoko"
WORKDIR="/workspaces/motoko_agent"
SESSION="${AGENT_HERDR_SESSION:-}"

die() { printf '%s\n' "$*" >&2; exit 1; }

# A LEADING `session=<name>` selects the herdr session for whatever command follows, so the common case needs
# no environment variable. Parsed before everything, including `help`, so `help` still answers from anywhere.
SESSION_GIVEN=0
if [[ "${1:-}" == session=* ]]; then
  SESSION="${1#session=}"
  SESSION_GIVEN=1
  shift
  [[ -n "$SESSION" ]] || die "session= needs a name, e.g. session=review"
  # herdr session names address a server; keep them to what a shell and a socket path handle without quoting.
  [[ "$SESSION" =~ ^[A-Za-z0-9_.-]+$ ]] \
    || die "invalid session name '${SESSION}': use letters, digits, '.', '-' or '_'."
fi

# `help` answers from anywhere: someone reading this file inside the agent's own container should still be
# able to see what it does. Everything else needs the host. The header block is printed to its own end (the
# first line that is not a comment) rather than to a hardcoded line number, which drifts as the block grows.
#
# COLOUR is derived from the text rather than marked up in it, so the comments stay readable as comments —
# which matters, because this file is also read as source by anyone auditing what the wrapper does. Off when
# stdout is not a terminal, so `help | grep`, `> file` and the r7 inventory see byte-identical plain text;
# NO_COLOR (no-color.org) disables it on a terminal; FORCE_COLOR keeps it through a pipe, for `help | less -R`.
print_help() {
  local colour=0
  [[ -t 1 && -z "${NO_COLOR:-}" ]] && colour=1
  [[ -n "${FORCE_COLOR:-}" && -z "${NO_COLOR:-}" ]] && colour=1
  awk -v colour="$colour" '
    BEGIN {
      if (colour) { B="\033[1m"; D="\033[2m"; C="\033[36m"; Y="\033[1;33m"; R="\033[0m" }
    }
    function lit(s,  inner) {
      if (!colour) return s
      while (match(s, /`[^`]+`/)) {
        inner = substr(s, RSTART + 1, RLENGTH - 2)
        s = substr(s, 1, RSTART - 1) C inner R substr(s, RSTART + RLENGTH)
      }
      return s
    }
    function bare(s) { if (colour) gsub(/`/, "", s); return s }
    NR == 1 { next }                       # the shebang
    { if ($0 !~ /^#/) exit; sub(/^# ?/, "") }
    NR == 2 { print B $0 R; next }         # the one-line title
    /^ +#/ { print D bare($0) R; next }
    /^ +.*(agent\.sh|herdr )/ {
      if (match($0, / #/)) {
        print C substr($0, 1, RSTART - 1) R D bare(substr($0, RSTART)) R
      } else {
        print C $0 R
      }
      next
    }
    /^ +\* / { sub(/\*/, Y "*" R); print lit($0); next }
    /^[A-Z][A-Z0-9]*([ ][A-Z0-9'"'"'-]+)+/ {
      match($0, /^[A-Z0-9 ,'"'"'-]+/)
      print Y substr($0, 1, RLENGTH) R lit(substr($0, RLENGTH + 1)); next
    }
    { print lit($0) }
  ' "${BASH_SOURCE[0]}"
}

case "${1:-}" in
  -h|--help|help) print_help; exit 0 ;;
esac

# Not from inside a container: REMOTE_CONTAINERS covers a VS Code dev container, /.dockerenv covers the rest.
# The point is to fail with an explanation rather than with "docker: command not found".
if [[ -n "${REMOTE_CONTAINERS:-}" || -f /.dockerenv ]]; then
  die "Run this on the HOST, not inside a dev container.
The agent's container is driven from outside precisely so that nothing attaches to it.
Open a terminal on your machine, or a VS Code window on ${REPO_ROOT} that is NOT reopened in a container.
(Run '$(basename "${BASH_SOURCE[0]}") help' for the command list.)"
fi

command -v docker >/dev/null || die "docker not found on PATH. Is OrbStack (or Docker Desktop) running?"
[[ -f "${REPO_ROOT}/.env" ]] || die "missing ${REPO_ROOT}/.env — the container's model credentials come from
it (see README, Prerequisites). An empty file is enough to start, but motoko will have no keys."

# ---------------------------------------------------------------------------------- pinned versions
# Read from versions.env, with an exported value winning. Sourced rather than parsed: the file is ours, it is
# committed, and it contains only KEY=value lines and comments.
load_versions() {
  [[ -f "$VERSIONS_FILE" ]] || die "missing ${VERSIONS_FILE} — it carries the pinned herdr and CLI versions.
Restore it from git, or regenerate it with: $(basename "$0") upgrade"
  local key val
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
    # An exported value wins over the file, so a one-off override needs no edit.
    [[ -n "${!key:-}" ]] || export "$key=$val"
  done < "$VERSIONS_FILE"

  [[ -n "${AGENT_BROWSER_VERSION:-}" ]] || die "AGENT_BROWSER_VERSION is empty — ${VERSIONS_FILE} is incomplete. Regenerate it:
  $(basename "$0") upgrade"
}
load_versions

# Herdr is not in versions.env: every build takes the current release. Only `build` and `upgrade` call this,
# so the other commands stay offline. The Dockerfile takes ONE sha256 and picks the download target from
# `uname -m` inside the build, so the selection happens here, against the architecture the build will run on.
# An exported HERDR_VERSION + HERDR_SHA256 pair skips the lookup (build an older release on purpose); one
# without the other is refused, because a version with the wrong checksum would fail late, inside the build.
resolve_herdr() {
  if [[ -n "${HERDR_VERSION:-}" || -n "${HERDR_SHA256:-}" ]]; then
    [[ -n "${HERDR_VERSION:-}" && -n "${HERDR_SHA256:-}" ]] \
      || die "export HERDR_VERSION and HERDR_SHA256 together, or neither (neither builds the latest herdr)."
    export HERDR_VERSION HERDR_SHA256
    return
  fi
  local target
  case "$(uname -m)" in
    aarch64|arm64) target=linux-aarch64 ;;
    x86_64|amd64)  target=linux-x86_64 ;;
    *) die "no herdr release asset for $(uname -m)" ;;
  esac
  command -v python3 >/dev/null || die "python3 is not on PATH, and resolving the latest herdr needs it.
Install the Xcode command line tools (xcode-select --install), or export HERDR_VERSION and HERDR_SHA256."
  local out
  out="$(fetch_herdr_manifest "$target")" \
    || die "build aborted — could not resolve the latest herdr from https://herdr.dev/latest.json"
  HERDR_VERSION="$(sed -n 1p <<<"$out")"
  HERDR_SHA256="$(sed -n 2p <<<"$out")"
  [[ -n "$HERDR_VERSION" && -n "$HERDR_SHA256" ]] || die "herdr manifest gave an empty version or sha256"
  export HERDR_VERSION HERDR_SHA256
}

# Print herdr's latest version and the sha256 for target $1, one per line. Python rather than jq: jq is not
# on macOS by default. Fails loudly; there is no pin to fall back to. A function of its own, not a heredoc
# inside "$(...)": macOS /bin/bash 3.2 mis-parses quotes in a heredoc there (an apostrophe in a comment broke
# `agent.sh build` with "unexpected EOF while looking for matching `"'").
fetch_herdr_manifest() {
  python3 - "$1" <<'PY'
import json, sys, urllib.request

# An explicit User-Agent, not decoration: herdr.dev answers 403 to urllib's default `Python-urllib/3.x`
# (measured 2026-08-22) while serving the identical request under a curl-shaped one.
UA = "motoko-agent-confined/1.0 (+.devcontainer/agent_sandbox/agent.sh)"
try:
    req = urllib.request.Request("https://herdr.dev/latest.json", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        m = json.load(r)
    version, sha = m["version"], m["sha256"][sys.argv[1]]
except Exception as exc:                                     # network, DNS, TLS, a shape change upstream
    sys.exit("could not resolve the latest herdr: %r" % (exc,))
print(version)
print(sha)
PY
}

# Resolve the current release of the pinned part (agent-browser) and print the new file to stdout.
# Python rather than jq: jq is not on macOS by default. Fails loudly rather than falling back to what is
# already pinned — a silent fallback is the exact failure this design removes, and `build` is the command
# for "use what is pinned".
resolve_versions() {
  # python3 rather than jq: jq is not on macOS by default. python3 is not guaranteed either — it arrives with
  # the Xcode command line tools — so say which one is missing rather than letting "command not found" become
  # the "could not resolve upstream versions" message.
  command -v python3 >/dev/null \
    || die "python3 is not on PATH, and 'upgrade' resolves the current release with it.
Install the Xcode command line tools (xcode-select --install), or set the version by hand in
${VERSIONS_FILE} and run: $(basename "$0") build"
  python3 - <<'PY'
import json, sys, urllib.request

UA = "motoko-agent-confined/1.0 (+.devcontainer/agent_sandbox/agent.sh)"
try:
    req = urllib.request.Request("https://registry.npmjs.org/agent-browser/latest", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        npm_browser = json.load(r)["version"]
except Exception as exc:                                     # network, DNS, TLS, a shape change upstream
    sys.exit("could not resolve upstream versions: %s" % exc)

print("AGENT_BROWSER_VERSION=%s" % npm_browser)
PY
}

# Regenerate versions.env from a template. $1 = destination, $2 = the KEY=value block resolve_versions
# produced. Grouping and comments are reproduced here rather than preserved from the old file, so the two can
# never disagree about what a line means.
write_versions_file() {
  local dest="$1" resolved="$2"
  get() { printf '%s\n' "$resolved" | sed -n "s/^$1=//p"; }
  cat > "$dest" <<EOF
# Pinned versions for the agent_confined image. Read by agent.sh on every command, passed to the build as
# args. COMMITTED ON PURPOSE: this file is what makes "which agent-browser is in the image" a fact in the
# tree rather than a property of whoever last ran a build, and it is what lets \`agent.sh stop\`, \`sessions\`
# and \`logs\` work with no network at all.
#
# Do not hand-edit to upgrade. Run:
#
#   .devcontainer/agent_sandbox/agent.sh upgrade    # re-resolve every line from upstream, rewrite, rebuild
#
# and commit the diff. \`agent.sh build\` deliberately does NOT re-resolve this file.
#
# Resolved $(date +%Y-%m-%d).

# herdr is NOT pinned: \`agent.sh build\` resolves the latest release and its sha256 from
# https://herdr.dev/latest.json every time (resolve_herdr in agent.sh).

# agent-browser (vercel-labs) — headless web access for the agent, over CDP. The Chromium it drives
# is Playwright's, pinned in the Dockerfile instead of here: a floating browser revision would move
# under a measurement, so that one is bumped on purpose rather than by \`upgrade\`.
AGENT_BROWSER_VERSION=$(get AGENT_BROWSER_VERSION)

# The agent CLIs herdr starts (claude, codex, omp) are deliberately NOT pinned here: the Dockerfile
# installs them at npm \`latest\` on every build, by decision 2026-09-06.
EOF
}

# ---------------------------------------------------------------------------------- compose plumbing
# `--env-file` is not decoration. Compose interpolates ${VAR} from a `.env` in the COMPOSE FILE's directory,
# not the repository root — so without this, keys sitting in the repo-root .env would be invisible to
# interpolation and every `${…:-}` in the environment block would resolve empty. Shell environment still wins
# over the file, which is how the version overrides above reach the build.
#
# An ARRAY, not only a function: `exec` replaces the shell with an external program and cannot exec a shell
# function. The interactive commands below must keep exec — herdr then owns the terminal, signals and exit
# status — so they expand this array, while everything non-interactive uses the function for readability.
COMPOSE=(docker compose --env-file "${REPO_ROOT}/.env" -f "$COMPOSE_FILE")
compose() { "${COMPOSE[@]}" "$@"; }

running() { compose ps --status running --services 2>/dev/null | grep -qx "$SERVICE"; }

# Both halves, in one `compose ps` call. Used by ensure_up so that a crash-looping proxy is repaired by the
# next `agent.sh` instead of being invisible until every tool in the container starts timing out.
stack_running() {
  local svcs
  svcs="$(compose ps --status running --services 2>/dev/null)"
  grep -qx "$SERVICE" <<<"$svcs" && grep -qx "$EGRESS_SERVICE" <<<"$svcs"
}

# `attach` and `shell` hand the terminal to herdr/bash, so `docker compose exec` allocates a TTY — and it
# REFUSES to do that when stdin is a pipe, with a message about attaching stdin to a TTY-enabled container
# that says nothing about what you typed.
require_tty() {
  [[ -t 0 ]] && return
  die "'$(basename "$0") ${1}' needs a terminal on stdin, and stdin here is a pipe or a file.
Docker refuses to allocate a TTY in that case. For a non-interactive run, use:
  $(basename "$0") run <command…>"
}

ensure_up() {
  if stack_running; then return; fi
  docker image inspect "$IMAGE" >/dev/null 2>&1 || die "the image ${IMAGE} is not present locally.
It is built from this profile's Dockerfile and never pushed, so compose cannot pull it — that is what a
\"pull access denied … repository does not exist\" message here means. A \`docker system prune -a\`
(\`make prune\`) removes it once the containers are down. Rebuild it with: $(basename "$0") build
  — herdr and the agent CLIs build at latest; agent-browser reproduces versions.env."
  echo "starting agent_confined" >&2
  echo "the first run builds the image; expect several minutes" >&2
  compose up -d
  compose ps
}

# TERMINAL ENVIRONMENT. `docker compose exec` carries over none of it, and each missing piece degrades the
# TUI differently: no UTF-8 locale and every non-ASCII cell is rewritten; no COLORTERM and anything probing
# it instead of terminfo assumes 256 colours.
TERM_ENV=(-e "COLORTERM=${COLORTERM:-truecolor}" -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8)

# The outer TERM has to name an entry the CONTAINER can look up. xterm-ghostty and xterm-kitty are absent
# from Ubuntu 24.04's ncurses and ncurses-term does not add them, so: use the host's TERM if the container
# knows it; otherwise teach the container the host's own entry with `tic`, keeping that terminal's real
# capabilities; otherwise fall back to xterm-256color, which all of them speak. `tic` writes to
# ~motoko/.terminfo, so both probes run as that user.
resolve_term() {
  local t="${TERM:-xterm-256color}"
  if compose exec -T -u "$CONTAINER_USER" "$SERVICE" infocmp "$t" >/dev/null 2>&1; then printf '%s' "$t"; return; fi
  if command -v infocmp >/dev/null 2>&1 \
     && infocmp -x "$t" 2>/dev/null | compose exec -T -u "$CONTAINER_USER" "$SERVICE" tic -x - >/dev/null 2>&1 \
     && compose exec -T -u "$CONTAINER_USER" "$SERVICE" infocmp "$t" >/dev/null 2>&1; then
    echo "installed terminfo for ${t} inside the container" >&2
    printf '%s' "$t"; return
  fi
  echo "note: the container has no terminfo for TERM=${t} and it could not be installed — using xterm-256color." >&2
  printf 'xterm-256color'
}

# The default herdr session is UNNAMED on the command line — `herdr` with no --session — but is addressed as
# `default` by `herdr session stop`. So the name used for reporting and for `kill` is not the same thing as
# the flag `attach` passes, and the flag is built inline at its one use site.
herdr_session_name() { printf '%s' "${SESSION:-default}"; }

# ---------------------------------------------------------------------------------------------------- ovis
# OVIS, THE PHONE CLIENT, END TO END FROM THE HOST. The container half is fixed by the image and
# docker-compose.yml: Ovis is installed, listens on all interfaces only when OVIS_TOKEN is set, and the
# ovis-relay service publishes it on the host's 127.0.0.1:${OVIS_HOST_PORT:-17317} (the agent itself
# cannot publish a port: its only network is internal). This is the host half, which is the part that
# used to be typed by hand: start the relay, check that the published port answers, and put Tailscale's
# HTTPS in front of it so a phone on the tailnet can open it.
#
# Tailscale is pointed at the host's LOOPBACK and never at the container's IP: the sandboxed Tailscale Mac
# app cannot open OrbStack's container network, and `serve` aimed there answers every request with an
# empty body, which Safari saves as an empty document.txt.
#
# The value of OVIS_HOST_PORT comes from the environment first, then from .env, the same two places compose
# reads it from. OVIS_TAILNET_PORT is the HTTPS port on the tailnet (default 7317), so 443 stays free.
ovis_env_value() {  # the last `KEY=value` for $1 in .env, without quotes; empty if absent
  sed -n -E "s/^[[:space:]]*(export[[:space:]]+)?$1=[\"']?([^\"']*)[\"']?[[:space:]]*\$/\\2/p" \
    "${REPO_ROOT}/.env" | tail -n 1
}
ovis_host_port() {
  local p="${OVIS_HOST_PORT:-$(ovis_env_value OVIS_HOST_PORT)}"
  printf '%s' "${p:-17317}"
}
ovis_tailnet_port() { printf '%s' "${OVIS_TAILNET_PORT:-7317}"; }

# The Tailscale CLI: on PATH, else inside the Mac app (the App Store and standalone builds both ship it
# there, and neither puts it on PATH by default).
ovis_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then printf 'tailscale'; return; fi
  local app="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
  [[ -x "$app" ]] && printf '%s' "$app"
}

# Whether Ovis answers on the published port. /api/health is public in Ovis, so this needs no token and
# proves only reachability; the token is checked by Ovis itself on everything else.
ovis_answers() {
  curl -fsS -m 3 -o /dev/null --noproxy '*' "http://127.0.0.1:$(ovis_host_port)/api/health" 2>/dev/null
}

# PIDs of any socat listening on the host's port $1, space-separated: a relay started by hand before this
# command existed. It holds the port ahead of the ovis-relay container's forward (measured 2026-11-21 on the
# Mac: lsof showed `socat1` on 127.0.0.1:17317 and curl there got an empty reply, while the container
# answered). Found by its listening socket, not by its command line, which varies: Homebrew's binary is
# `socat1`, and options or a lowercase address can come before the listen address. pgrep is the fallback
# for a host without lsof.
ovis_stray_socat() {
  local pid
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null); do
      case "$(ps -o comm= -p "$pid" 2>/dev/null)" in
        *socat*) printf '%s ' "$pid" ;;
      esac
    done
  else
    for pid in $(pgrep -if "socat.*listen:$1" 2>/dev/null); do printf '%s ' "$pid"; done
  fi
}

# The https:// address `tailscale serve` is serving on OVIS_TAILNET_PORT, read from its own status output so
# no JSON parser is needed (bash 3.2 and BSD userland are the floor here; jq is not guaranteed on a Mac).
ovis_tailnet_url() {
  local ts="$1"
  "$ts" serve status 2>/dev/null | grep -Eo "https://[^ ]+:$(ovis_tailnet_port)" | head -n 1
}

ovis_cmd() {
  local sub="${1:-on}"
  local port ts url stray
  port="$(ovis_host_port)"
  ts="$(ovis_tailscale || true)"
  case "$sub" in
    on)
      # 1. A token, or Ovis stays on the container's loopback by design and nothing below can reach it.
      #    Checked for presence only; the value is never printed.
      if [[ -z "${OVIS_TOKEN:-}" && -z "$(ovis_env_value OVIS_TOKEN)" ]]; then
        die "OVIS_TOKEN is not set in ${REPO_ROOT}/.env.
Without it Ovis listens on the container's loopback only, which is the safe default and also unreachable.
Add a line like this to .env, then run this command again:
  OVIS_TOKEN=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 32)
(that value was generated just now; any long random string works, and every browser enters it once)"
      fi

      # 2. The hand-started relay from before this command existed. It holds the host port ahead of the
      #    ovis-relay container's forward. Only a socat listening on this exact port is stopped, so nothing
      #    else is hit. The relay container is then restarted, so its forward takes the freed port.
      stray="$(ovis_stray_socat "$port")"
      if [[ -n "$stray" ]]; then
        echo "stopping the old socat relay on 127.0.0.1:${port} (pid ${stray% }); the ${OVIS_RELAY_SERVICE} container publishes this port now" >&2
        # Unquoted on purpose: one argument per PID.
        kill $stray 2>/dev/null || true
        sleep 1
        compose restart "$OVIS_RELAY_SERVICE" >/dev/null 2>&1 || true
      fi

      ensure_up

      # The relay that owns the published port. ensure_up returns early on a running stack, so a stack
      # started before the relay existed would never get it. `--no-deps` creates or starts the relay alone:
      # without it compose would also recreate the agent if its config drifted, ending every herdr session.
      compose up -d --no-deps "$OVIS_RELAY_SERVICE" >/dev/null 2>&1 \
        || die "could not start the ${OVIS_RELAY_SERVICE} service, which publishes Ovis on 127.0.0.1:${port}.
See why with:  ${COMPOSE[*]} up --no-deps ${OVIS_RELAY_SERVICE}"

      # 3. The container must have been CREATED with the token. Adding it to .env later does not reach a
      #    running container; compose only reads .env when it creates one. Recreating would end every herdr
      #    session, so this says so instead of doing it.
      compose exec -T -u "$CONTAINER_USER" "$SERVICE" sh -c 'test -n "${OVIS_TOKEN:-}"' \
        || die "the running container was created before OVIS_TOKEN was in .env, so Ovis inside it has no
token and stays on loopback. Recreate the container (this ends every herdr session in it):
  $(basename "$0") stop && $(basename "$0") ovis"

      # 4. Ovis itself. It starts with the herdr server (its plugin's [[startup]] entry), so with no session
      #    attached since the container came up it is not running yet. `ovis start` detaches, and is a no-op
      #    when it is already running.
      if ! ovis_answers; then
        echo "starting Ovis in the container" >&2
        compose exec -T -u "$CONTAINER_USER" -w "$WORKDIR" "$SERVICE" ovis start >/dev/null 2>&1 || true
        local i
        for i in 1 2 3 4 5 6 7 8 9 10; do ovis_answers && break; sleep 1; done
      fi
      ovis_answers || die "Ovis does not answer on http://127.0.0.1:${port}.
Look inside the container:  $(basename "$0") run ovis status
  and its settings file:    $(basename "$0") run cat /home/${CONTAINER_USER}/.config/herdr/plugins/config/devswha.ovis/env
(the file should hold HOST=0.0.0.0 and PORT=7317; docker-compose.yml's command: writes them at start)
  and the relay's log:      ${COMPOSE[*]} logs ${OVIS_RELAY_SERVICE}
If the file is right but Ovis started before it was, Ovis listens on the container's loopback only.
Restart Ovis, which leaves the herdr sessions running:
  $(basename "$0") run ovis stop && $(basename "$0") ovis"
      echo "Ovis answers on http://127.0.0.1:${port} (this machine only)"

      # 5. HTTPS on the tailnet. Turned off first so a stale target (the old relay, a container IP) is
      #    replaced rather than kept; `off` on a port with nothing configured is harmless.
      if [[ -z "$ts" ]]; then
        echo "Tailscale CLI not found, so nothing was served to the tailnet."
        echo "Install Tailscale, or put its CLI on PATH, and run this again to reach Ovis from a phone."
        return 0
      fi
      "$ts" serve --https="$(ovis_tailnet_port)" off >/dev/null 2>&1 || true
      "$ts" serve --bg --https="$(ovis_tailnet_port)" "http://127.0.0.1:${port}" >/dev/null \
        || die "tailscale serve failed. If it says HTTPS is not enabled, turn on HTTPS certificates for
your tailnet in the Tailscale admin console (DNS page), then run this again."
      url="$(ovis_tailnet_url "$ts")"
      echo "Ovis on your tailnet: ${url:-https://<this machine>.<tailnet>.ts.net:$(ovis_tailnet_port)}"
      echo "Open it on the phone (Tailscale on) and enter the token once. Stop serving with: $(basename "$0") ovis off"
      ;;
    off)
      # Only the tailnet half. Ovis keeps running in the container and stays reachable on this machine's
      # loopback; it goes when the container does.
      [[ -n "$ts" ]] || die "Tailscale CLI not found — nothing to turn off."
      "$ts" serve --https="$(ovis_tailnet_port)" off >/dev/null 2>&1 || true
      echo "no longer serving Ovis on the tailnet (port $(ovis_tailnet_port)); it is still on http://127.0.0.1:${port} here"
      ;;
    status)
      # Read-only: starts nothing, changes nothing.
      if ovis_answers; then echo "local:   http://127.0.0.1:${port} answers"
      else echo "local:   http://127.0.0.1:${port} does not answer"; fi
      stray="$(ovis_stray_socat "$port")"
      [[ -z "$stray" ]] || echo "         a hand-started socat (pid ${stray% }) holds 127.0.0.1:${port} ahead of the ${OVIS_RELAY_SERVICE} container; $(basename "$0") ovis stops it"
      if [[ -z "$ts" ]]; then echo "tailnet: Tailscale CLI not found"
      else
        url="$(ovis_tailnet_url "$ts")"
        if [[ -n "$url" ]]; then echo "tailnet: ${url}"
        else echo "tailnet: not served (turn it on with: $(basename "$0") ovis)"; fi
      fi
      ;;
    *)
      die "usage: $(basename "$0") ovis [on|off|status]
  on      (default) check Ovis answers, start it if needed, serve it on the tailnet over HTTPS
  off     stop serving it on the tailnet; it stays on this machine's loopback
  status  what answers where, changing nothing"
      ;;
  esac
}

cmd="${1:-attach}"
[[ $# -gt 0 ]] && shift || true

# Only `attach` and `kill` address a session, so `session=` in front of anything else would be a silent
# no-op — refused rather than ignored, on the principle that a flag that would be dropped is an error.
if [[ $SESSION_GIVEN -eq 1 && "$cmd" != attach && "$cmd" != kill ]]; then
  die "'session=${SESSION}' does not apply to '${cmd}' — only 'attach' (the default) and 'kill' address a
session. Everything else acts on the container. Drop the prefix, or run:
  $(basename "$0") session=${SESSION} attach"
fi

case "$cmd" in
  attach|"")
    require_tty attach
    [[ $# -eq 0 ]] || die "'attach' takes no arguments — herdr decides what runs in a pane, not this script.
To start something in the session, attach and use herdr, or from the host:
  $(basename "$0") run herdr pane run <pane_id> '<command>'"
    ensure_up
    # A one-time nudge rather than a check that runs every start: src/tui/node_modules lives on the shared
    # tree, so it is usually already there from the operator's container. When it is not, motoko fails at
    # `bun run build` with something that reads like a code error.
    if [[ ! -d "${REPO_ROOT}/src/tui/node_modules" ]]; then
      echo "note: src/tui/node_modules is missing on the tree — motoko will not start until you run:" >&2
      echo "        $(basename "$0") bootstrap" >&2
    fi
    # Built directly rather than with `mapfile`, which is a bash 4 builtin: macOS ships bash 3.2 as
    # /bin/bash, and this script runs on the HOST by design, so bash 3.2 is the floor for everything here
    # (measured 2026-08-22: "mapfile: command not found").
    SESSION_FLAG=()
    if [[ -n "$SESSION" ]]; then
      SESSION_FLAG=(--session "$SESSION")
    fi
    echo "attaching to herdr session '$(herdr_session_name)' (detach with ctrl+b q)" >&2
    exec "${COMPOSE[@]}" exec -u "$CONTAINER_USER" -w "$WORKDIR" -e "TERM=$(resolve_term)" "${TERM_ENV[@]}" \
      "$SERVICE" herdr ${SESSION_FLAG[@]+"${SESSION_FLAG[@]}"}
    ;;
  bootstrap)
    # The equivalent of the operator profile's postCreateCommand, plus the herdr integrations. Separate from
    # `attach` because it is slow, it writes to the shared tree, and it must not run implicitly on every
    # start — two containers building src/tui at the same moment is the one collision this pair of
    # containers can produce.
    ensure_up
    echo "==> src/tui dependencies and build (on the SHARED tree — do not run this while your own container builds)"
    compose exec -T -u "$CONTAINER_USER" -w "$WORKDIR" "$SERVICE" \
      bash -lc 'cd src/tui && bun install && bun run build'
    echo "==> herdr integrations, against the running server"
    compose exec -T -u "$CONTAINER_USER" -w "$WORKDIR" "$SERVICE" \
      bash -lc 'for i in claude codex omp; do herdr integration install "$i" || echo "  (integration $i did not install)"; done'
    echo "bootstrap done — start a session with: $(basename "$0")"
    ;;
  shell)
    require_tty shell
    ensure_up
    exec "${COMPOSE[@]}" exec -u "$CONTAINER_USER" -w "$WORKDIR" -e "TERM=$(resolve_term)" "${TERM_ENV[@]}" \
      "$SERVICE" bash
    ;;
  run)
    ensure_up
    [[ $# -gt 0 ]] || die "usage: $(basename "$0") run <command…>
  e.g. $(basename "$0") run make test
       $(basename "$0") run herdr agent list
No herdr session is involved, so the command dies with this terminal. For work that must outlive it, start
it in a herdr pane instead."
    # -T when stdin is not a terminal: `docker compose exec` allocates a TTY by default and REFUSES when
    # stdin is a pipe, which is how `echo x | agent.sh run cat` would otherwise fail with a message about
    # TTY-enabled containers rather than doing the obvious thing.
    RUN_TTY=()
    [[ -t 0 ]] || RUN_TTY=(-T)
    exec "${COMPOSE[@]}" exec ${RUN_TTY[@]+"${RUN_TTY[@]}"} \
      -u "$CONTAINER_USER" -w "$WORKDIR" -e "TERM=${TERM:-xterm-256color}" \
      "${TERM_ENV[@]}" "$SERVICE" "$@"
    ;;
  sessions)
    # Deliberately does NOT start the container: "which runs exist" must be answerable without creating one.
    running || { echo "agent_confined is not running — no sessions."; exit 0; }
    compose exec -T -u "$CONTAINER_USER" "$SERVICE" herdr session list 2>/dev/null \
      || echo "no herdr server is running in the container (start one with: $(basename "$0"))"
    ;;
  kill)
    running || die "agent_confined is not running — nothing to kill."
    name="$(herdr_session_name)"
    compose exec -T -u "$CONTAINER_USER" "$SERVICE" herdr session stop "$name" \
      || die "could not stop session '${name}' (list them with: $(basename "$0") sessions)"
    echo "stopped session '${name}' and its panes; the container and any other sessions are untouched."
    ;;
  build)
    # Only agent-browser reproduces versions.env. Herdr (resolve_herdr) and the agent CLIs (claude, codex,
    # omp) re-resolve at latest on EVERY build — reproducibility of those is not a goal — so `build` is not
    # a pure reproduction, and that is intended.
    resolve_herdr
    echo "building: herdr ${HERDR_VERSION} (latest), agent CLIs at npm latest, agent-browser ${AGENT_BROWSER_VERSION} (pinned)"
    echo "(to move the agent-browser pin forward: $(basename "$0") upgrade)"
    export AGENTS_CACHE_BUST="$(date +%s)"
    compose up -d --build
    compose ps
    ;;
  upgrade)
    # Re-resolve, show the diff, rewrite, rebuild. The rewrite preserves the file's comment header, because
    # that header is where the "do not hand-edit" instruction lives.
    echo "resolving current releases…"
    new="$(resolve_versions)" || die "upgrade aborted — nothing was rewritten.
Build at the versions already pinned with: $(basename "$0") build"
    # An explicit template: BSD mktemp (macOS) REQUIRES one and errors out on a bare `mktemp`, where GNU
    # mktemp supplies a default. Same class of defect as the mapfile one — this script runs on the host, so
    # macOS is a first-class target, not an afterthought.
    tmp="$(mktemp "${TMPDIR:-/tmp}/agent-confined-versions.XXXXXX")"
    # The file is regenerated from this template rather than patched in place, so its prose cannot drift out
    # of step with its contents and a hand-edit is always visible as a diff of the whole file.
    write_versions_file "$tmp" "$new"
    echo
    if diff -u "$VERSIONS_FILE" "$tmp"; then
      echo "(already current — nothing changed)"
    fi
    mv "$tmp" "$VERSIONS_FILE"
    echo
    echo "versions.env rewritten. Commit that diff: it is the record of what the agent now runs."
    # Re-read so the build below uses the new values rather than the ones loaded at start-up.
    unset AGENT_BROWSER_VERSION
    load_versions
    resolve_herdr
    export AGENTS_CACHE_BUST="$(date +%s)"
    compose up -d --build
    compose ps
    ;;
  stop)
    compose down
    ;;
  logs)
    compose logs -f "$SERVICE"
    ;;
  check)
    running || die "service is not running — start it with: $(basename "$0")"
    exec "${HERE}/checks/r9-container.sh"
    ;;
  ovis)
    ovis_cmd "$@"
    ;;
  *)
    die "unknown command: ${cmd}
try: attach | bootstrap | shell | run | sessions | kill | build | upgrade | stop | logs | check | ovis | help
A session is selected by a leading 'session=<name>', e.g. $(basename "$0") session=review kill"
    ;;
esac
