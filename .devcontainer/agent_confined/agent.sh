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
#   agent.sh help                     # this block, coloured on a terminal
#
# (Written `agent.sh` for brevity; invoke it by path — `.devcontainer/agent_confined/agent.sh …` — or alias
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
# VERSIONS ARE PINNED IN THE TREE. versions.env beside this file carries herdr's version and sha256 and the
# three CLI versions; every command here reads it, so `stop`, `sessions` and `logs` work with no network.
# `build` reproduces exactly that file. `upgrade` re-resolves each line from upstream, rewrites the file and
# rebuilds — commit that diff, it is the harness-upgrade record. Override one for a single command by
# exporting it: `HERDR_VERSION=0.8.1 agent.sh build`.
#
# ENVIRONMENT: AGENT_HERDR_SESSION (session name; `session=NAME` overrides it), and any pinned version name
# from versions.env (an exported value wins over the file).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
COMPOSE_FILE="${HERE}/docker-compose.yml"
VERSIONS_FILE="${HERE}/versions.env"
SERVICE="agent"
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

  # The Dockerfile takes ONE sha256 and picks the download target from `uname -m` inside the build, so the
  # selection has to happen here, against the same architecture the build will run on.
  if [[ -z "${HERDR_SHA256:-}" ]]; then
    case "$(uname -m)" in
      aarch64|arm64) export HERDR_SHA256="${HERDR_SHA256_LINUX_AARCH64:-}" ;;
      x86_64|amd64)  export HERDR_SHA256="${HERDR_SHA256_LINUX_X86_64:-}" ;;
      *) die "no herdr release asset for $(uname -m)" ;;
    esac
  fi
  local v
  for v in HERDR_VERSION HERDR_SHA256 AGENT_BROWSER_VERSION \
           AGENT_BROWSER_VERSION CLAUDE_CODE_VERSION CODEX_VERSION OMP_VERSION; do
    [[ -n "${!v:-}" ]] || die "${v} is empty — ${VERSIONS_FILE} is incomplete. Regenerate it:
  $(basename "$0") upgrade"
  done
}
load_versions

# Resolve the current release of everything, print the new file to stdout. Python rather than jq: jq is not
# on macOS by default. Fails loudly rather than falling back to what is already pinned — a silent fallback is
# the exact failure this design removes, and `build` is the command for "use what is pinned".
resolve_versions() {
  # python3 rather than jq: jq is not on macOS by default. python3 is not guaranteed either — it arrives with
  # the Xcode command line tools — so say which one is missing rather than letting "command not found" become
  # the "could not resolve upstream versions" message.
  command -v python3 >/dev/null \
    || die "python3 is not on PATH, and 'upgrade' resolves the current releases with it.
Install the Xcode command line tools (xcode-select --install), or pin the versions by hand in
${VERSIONS_FILE} and run: $(basename "$0") build"
  python3 - <<'PY'
import json, sys, urllib.request

# An explicit User-Agent, not decoration: herdr.dev answers 403 to urllib's default `Python-urllib/3.x`
# (measured 2026-08-22) while serving the identical request under a curl-shaped one. Without this the
# upgrade path fails with "403 Forbidden" and looks like an outage.
UA = "motoko-agent-confined/1.0 (+.devcontainer/agent_confined/agent.sh)"

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)

try:
    m = get("https://herdr.dev/latest.json")
    npm = {}
    for var, pkg in (("AGENT_BROWSER_VERSION", "agent-browser"),
                     ("CLAUDE_CODE_VERSION", "@anthropic-ai/claude-code"),
                     ("CODEX_VERSION", "@openai/codex"),
                     ("OMP_VERSION", "@oh-my-pi/pi-coding-agent")):
        npm[var] = get("https://registry.npmjs.org/%s/latest" % pkg.replace("/", "%2F"))["version"]
except Exception as exc:                                     # network, DNS, TLS, a shape change upstream
    sys.exit("could not resolve upstream versions: %s" % exc)

for key in ("linux-aarch64", "linux-x86_64"):
    if key not in m.get("sha256", {}):
        sys.exit("herdr manifest has no sha256 for %s" % key)

print("HERDR_VERSION=%s" % m["version"])
print("HERDR_SHA256_LINUX_AARCH64=%s" % m["sha256"]["linux-aarch64"])
print("HERDR_SHA256_LINUX_X86_64=%s" % m["sha256"]["linux-x86_64"])
for var in ("AGENT_BROWSER_VERSION", "CLAUDE_CODE_VERSION", "CODEX_VERSION", "OMP_VERSION"):
    print("%s=%s" % (var, npm[var]))
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
# args. COMMITTED ON PURPOSE: this file is what makes "which harness is in the image" a fact in the tree
# rather than a property of whoever last ran a build, and it is what lets \`agent.sh stop\`, \`sessions\` and
# \`logs\` work with no network at all.
#
# Do not hand-edit to upgrade. Run:
#
#   .devcontainer/agent_confined/agent.sh upgrade    # re-resolve every line from upstream, rewrite, rebuild
#
# and commit the diff — that diff IS the harness-upgrade record. \`agent.sh build\` deliberately does NOT
# re-resolve: a rebuild reproduces this file, an upgrade changes it.
#
# Resolved $(date +%Y-%m-%d).

# herdr — https://herdr.dev/latest.json supplies the version and the per-target sha256 together.
# Both architectures are recorded; agent.sh exports the one matching the build host's \`uname -m\`.
HERDR_VERSION=$(get HERDR_VERSION)
HERDR_SHA256_LINUX_AARCH64=$(get HERDR_SHA256_LINUX_AARCH64)
HERDR_SHA256_LINUX_X86_64=$(get HERDR_SHA256_LINUX_X86_64)

# agent-browser (vercel-labs) — headless web access for the agent, over CDP. The Chromium it drives
# is Playwright's, pinned in the Dockerfile instead of here: a floating browser revision would move
# under a measurement, so that one is bumped on purpose rather than by \`upgrade\`.
AGENT_BROWSER_VERSION=$(get AGENT_BROWSER_VERSION)

# The agent CLIs herdr starts, from the npm registry's \`latest\` dist-tag.
CLAUDE_CODE_VERSION=$(get CLAUDE_CODE_VERSION)
CODEX_VERSION=$(get CODEX_VERSION)
OMP_VERSION=$(get OMP_VERSION)
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
  if running; then return; fi
  echo "starting agent_confined  (herdr ${HERDR_VERSION}, claude ${CLAUDE_CODE_VERSION}, codex ${CODEX_VERSION}, omp ${OMP_VERSION})" >&2
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
    # Reproduces versions.env exactly. This is NOT an upgrade — that is a separate verb, so that changing
    # what the agent runs is always a commit and never a side effect of rebuilding.
    echo "building at the pinned versions: herdr ${HERDR_VERSION}, claude ${CLAUDE_CODE_VERSION}, codex ${CODEX_VERSION}, omp ${OMP_VERSION}"
    echo "(to move them forward: $(basename "$0") upgrade)"
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
    unset HERDR_VERSION HERDR_SHA256 HERDR_SHA256_LINUX_AARCH64 HERDR_SHA256_LINUX_X86_64 \
          CLAUDE_CODE_VERSION CODEX_VERSION OMP_VERSION
    load_versions
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
  *)
    die "unknown command: ${cmd}
try: attach | bootstrap | shell | run | sessions | kill | build | upgrade | stop | logs | check | help
A session is selected by a leading 'session=<name>', e.g. $(basename "$0") session=review kill"
    ;;
esac
