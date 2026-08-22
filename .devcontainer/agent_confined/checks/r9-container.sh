#!/usr/bin/env bash
# R9 — the agent's service is the one this profile describes, and nothing re-attaches it.
#
# Adapted from an acceptance sweep written for another project's confined-agent profile. The leg
# numbering is kept because the per-leg comments refer to it; what each leg asserts is motoko's.
#
# Run from a HOST shell. The legs are statements about the container's definition, which a compromised agent
# inside it would misreport — which is also why the git-configuration audit (r7_git_audit.py) is assigned to
# a human rather than folded in here:
#
#     .devcontainer/agent_confined/agent.sh check      # preferred: refuses from inside a container,
#                                                      #   refuses when the service is down
#     .devcontainer/agent_confined/checks/r9-container.sh
#
# It runs the host-side legs itself, then re-invokes itself inside the service with --in-container.
# --in-container can also be run directly to probe the shell you are already in — which is how the gap was
# measured in the OPERATOR's container on 2026-08-22, where it correctly fails legs 2, 3 and 4.
#
# Exit status: 0 = every leg passed; 1 = at least one failed; 2 = could not run.

set -uo pipefail

PROFILE_DIR_NAME="agent_confined"
SERVICE="agent"
CONTAINER_USER="motoko"
WORKDIR="/workspaces/motoko_agent"
COMPOSE_FILE=".devcontainer/${PROFILE_DIR_NAME}/docker-compose.yml"
# The repository the bot credential is scoped to. Leg 4's negative probe reads its branch protection and
# requires that read to be REFUSED.
REPO="${REPO:-arniwesth/motoko_agent}"
# The machine user from 016_github_ops ADR-001 C9. The agent's GitHub identity must be this, never the
# operator's.
BOT_LOGIN="${BOT_LOGIN:-motoko-agent}"

fails=0
# Legs that could not be attempted (no docker CLI, service not running). Tracked separately from `fails`,
# because an unattempted leg is not a passing one: without this the container-side legs — the ones that prove
# no docker.sock, no sudo and no forwarded credential socket — are skipped and the script still prints PASS,
# which is the vacuous check the exit-2 status exists to report.
skipped=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
info() { printf '  ----  %s\n' "$1"; }

# ----------------------------------------------------------------------------------------------------------
# container-side legs
# ----------------------------------------------------------------------------------------------------------
in_container() {
  echo "R9 (container-side legs)"

  # leg 2 — no route to host root, no privilege escalation, no ssh client to install a signing path with.
  #
  # The sudo assertion is the one motoko's operator profile fails: .devcontainer/Dockerfile:13 writes
  # `motoko ALL=(root) NOPASSWD:ALL`, which makes every other absence in this leg a speed bump — an agent
  # with root can apt-get install whatever was left out. agent_confined's Dockerfile purges sudo and asserts
  # it at build time; this is the runtime confirmation.
  if [[ -S /var/run/docker.sock ]]; then
    fail "leg2: /var/run/docker.sock EXISTS — docker run -v /:/host reaches host root"
  else
    pass "leg2: no /var/run/docker.sock"
  fi
  if command -v docker >/dev/null 2>&1; then
    fail "leg2: a docker binary is on PATH ($(command -v docker))"
  else
    pass "leg2: no docker binary on PATH"
  fi
  if sudo -n true >/dev/null 2>&1; then
    fail "leg2: sudo -n true SUCCEEDED — this image ships a sudoers drop-in, so every other absence here is optional"
  else
    pass "leg2: sudo -n true refused"
  fi
  local bin
  for bin in ssh sshd ssh-add ssh-agent ssh-keygen scp; do
    if command -v "$bin" >/dev/null 2>&1; then
      fail "leg2: $bin is present ($(command -v "$bin"))"
    else
      pass "leg2: $bin absent"
    fi
  done

  # leg 3 — no forwarded VS Code sockets.
  #
  # SSH is not the only channel: the Dev Containers extension announces the gpg-agent socket in the same
  # REMOTE_CONTAINERS_SOCKETS list and creates ~/.gnupg/S.gpg-agent, which is a commit-signing path as the
  # host user whenever the host runs an agent holding a key. Measured in the operator's container on
  # 2026-08-22: the ssh-agent answered as a CONDUIT (0 identities) and the gpg socket was DEAD — both latent
  # rather than live, which is exactly why this leg asserts ABSENCE rather than emptiness. One `ssh-add` on
  # the host turns a conduit into an oracle with no signal inside the container.
  # checks/agent-socket-probe.py is what tells those states apart, on the operator's side.
  local var
  for var in SSH_AUTH_SOCK REMOTE_CONTAINERS REMOTE_CONTAINERS_IPC REMOTE_CONTAINERS_SOCKETS \
             VSCODE_IPC_HOOK_CLI GPG_AGENT_INFO; do
    if [[ -n "${!var:-}" ]]; then
      fail "leg3: $var is set — a forwarded socket or attach is announced to this UID"
    else
      pass "leg3: $var unset"
    fi
  done
  # Existence is tested per path. A literal path is NOT removed by nullglob (which only drops words
  # containing glob characters), so the two kinds are collected separately — conflating them is how this leg
  # false-failed for ever in the source version.
  shopt -s nullglob
  local candidates=(
    /tmp/vscode-ssh-auth-*.sock
    /tmp/vscode-remote-containers-ipc-*.sock
    /tmp/vscode-ipc-*.sock
  )
  shopt -u nullglob
  local present=("${candidates[@]}")
  local literal
  for literal in "$HOME/.gnupg/S.gpg-agent" "$HOME/.gnupg/S.gpg-agent.extra"; do
    [[ -e "$literal" ]] && present+=("$literal")
  done
  if ((${#present[@]})); then
    fail "leg3: forwarded socket file(s) exist: ${present[*]}"
  else
    pass "leg3: no ssh-auth, IPC or gpg-agent socket present"
  fi

  # leg 4 — the agent's GitHub identity is the machine user, and it is not the operator's session.
  #
  # The assertion here is about WHICH account answers, not merely that some credential is installed.
  # 016_github_ops ADR-001 C9 settles it: a separate machine user, so that "anything the pipeline emits
  # is the bot; anything done by hand in the web UI is you" is checkable from an author field alone.
  if ! command -v gh >/dev/null 2>&1; then
    fail "leg4: gh is NOT installed — the .agent/github pipeline has no transport"
  else
    pass "leg4: gh present ($(gh --version 2>/dev/null | head -1))"
  fi
  # GH_TOKEN IS EXPECTED TO BE SET HERE, and that is the opposite of what the operator's container
  # wants. The naming rule in 016 ADR-001 exists so the OPERATOR's own `gh` is never silently the bot
  # in a container they share with it. Nothing but the agent runs in this one, and its identity is
  # supposed to be motoko-agent — so the value being absent is the failure, not its presence.
  if [[ -z "${GH_TOKEN:-}" ]]; then
    fail "leg4: GH_TOKEN is unset — this container is supposed to act as the bot for everything.
             docker-compose.yml maps it from MOTOKO_BOT_GH_TOKEN; an empty value means .env does not
             carry that key, or agent.sh was not the thing that started the stack (it passes --env-file)"
  else
    pass "leg4: GH_TOKEN is set (mapped from MOTOKO_BOT_GH_TOKEN for this profile)"
  fi
  if [[ -z "${MOTOKO_BOT_GH_TOKEN:-}" ]]; then
    fail "leg4: MOTOKO_BOT_GH_TOKEN is unset — put it in the repository-root .env"
  else
    pass "leg4: MOTOKO_BOT_GH_TOKEN present"
    local who
    who="$(gh api user --jq .login 2>/dev/null)"
    if [[ "$who" == "$BOT_LOGIN" ]]; then
      pass "leg4: the bot token authenticates as ${BOT_LOGIN}"
    elif [[ -z "$who" ]]; then
      fail "leg4: the bot token does not authenticate at all (expired, revoked, or no network)"
    else
      fail "leg4: the bot token authenticates as '${who}', NOT ${BOT_LOGIN} — this is an operator credential
             in the agent's container, which is the finding this profile exists to remove"
    fi
    # THE NEGATIVE PROBE. Reading branch protection needs `administration`, which the bot is expected NOT to
    # hold. A refusal is the pass; success means the credential is over-scoped for a machine user, and
    # GitHub's 404-for-private-resources means "cannot see it" and "not allowed" look alike — either is a
    # refusal, and both are correct here.
    local body
    body="$(gh api "repos/${REPO}/branches/main/protection" 2>&1)"
    if grep -qi '"required_status_checks"\|"enforce_admins"' <<<"$body"; then
      fail "leg4: the bot can READ branch protection on ${REPO} — it holds administration and is over-scoped"
    else
      pass "leg4: branch-protection read refused for the bot (no administration grant)"
    fi
  fi
  # git must be able to push as the bot too, or a PR opens over commits nobody can attribute.
  local helper
  helper="$(git config --get credential.helper 2>/dev/null || true)"
  if [[ "$helper" == '!gh auth git-credential' ]]; then
    pass "leg4: git credential.helper delegates to gh (so push uses the same identity)"
  else
    fail "leg4: git credential.helper is '${helper:-<unset>}' — git push will prompt for a username"
  fi
  local gituser
  gituser="$(git config --get user.name 2>/dev/null || true)"
  if [[ "$gituser" == "$BOT_LOGIN" ]]; then
    pass "leg4: git commits are authored as ${BOT_LOGIN}"
  else
    fail "leg4: git user.name is '${gituser:-<unset>}', expected ${BOT_LOGIN} — commits would not read as the bot"
  fi

  # No operator OAuth session, by either route. The value is never printed: the grep is the entire test.
  if git config --show-origin --get-regexp '^credential\.helper$' 2>/dev/null | grep -q 'vscode-remote-containers'; then
    fail "leg4: a VS Code remote-containers helper is configured — this service has been attached"
  else
    pass "leg4: no VS Code remote-containers helper configured"
  fi
  if printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | grep -q '^password=gho_'; then
    fail "leg4: git credential fill returns a gho_-shaped value — an operator OAuth session is reachable here"
  else
    pass "leg4: no gho_-shaped credential returned for github.com"
  fi

  # leg 5 — the image is the one this profile builds, and the harness it was given is present.
  if [[ "${MOTOKO_CONTAINER_PROFILE:-}" == "$PROFILE_DIR_NAME" ]]; then
    pass "leg5: MOTOKO_CONTAINER_PROFILE=${PROFILE_DIR_NAME}"
  else
    fail "leg5: MOTOKO_CONTAINER_PROFILE is '${MOTOKO_CONTAINER_PROFILE:-<unset>}' — wrong image or wrong service"
  fi
  # The agent cannot install anything, so anything missing here is missing for the life of the container.
  local tool
  for tool in herdr agent-browser chromium claude codex omp bun go ailang gh; do
    if command -v "$tool" >/dev/null 2>&1; then
      pass "leg5: ${tool} present"
    else
      fail "leg5: ${tool} is NOT in the image — with no sudo the agent cannot add it; rebuild instead"
    fi
  done

  # leg 6 — the host-services NAME, and separately what is actually reachable.
  #
  # CORRECTED 2026-08-22. This leg used to be titled "no route to host services" and asserted only that
  # `host.docker.internal` fails to resolve. That conflated two different things: `extra_hosts` writes an
  # /etc/hosts entry, and removing it withdraws the NAME while leaving reachability untouched. Measured in
  # the operator's container that day: the name resolves to 0.250.250.254 — OrbStack's dedicated host
  # address, not the default gateway — and connecting to it is REFUSED rather than timing out, i.e. packets
  # reach the host. A leg that reads "no route" while testing a hostname is a speed bump reported as a
  # control, which is the one thing this whole sweep exists not to do.
  #
  # So: the name check stays (it still detects `extra_hosts` being added back, which is a real change to
  # the profile) but says what it tests. The reachability question is then probed and REPORTED rather than
  # asserted — the set of host addresses is platform-specific (OrbStack vs Docker Desktop vs plain Linux)
  # and cannot be enumerated reliably, and a check that cannot fail correctly is worse than an honest note.
  #
  # READ THE PROBE NARROWLY. A refusal proves a SYN got an answer, not that the host is what answered:
  # run in the operator's container on 2026-08-22 it reported all three candidates as answering, including
  # 192.168.65.254 — Docker Desktop's host address, which has no reason to exist under OrbStack. The
  # defensible reading is "egress to these addresses is not blocked", and the useful signal is a change
  # over time, not the absolute result. Do not upgrade this to a pass/fail on that basis.
  if getent hosts host.docker.internal >/dev/null 2>&1; then
    fail "leg6: host.docker.internal RESOLVES — extra_hosts was added back (see docker-compose.yml)"
  else
    pass "leg6: host.docker.internal does not resolve (the name is absent; see the probe below)"
  fi
  local addr probe
  for addr in 0.250.250.254 192.168.65.254 "$(awk 'NR>1 && $2=="00000000" {print $3; exit}' /proc/net/route         | sed 's/../0x& /g' | awk '{printf "%d.%d.%d.%d", $4, $3, $2, $1}')"; do
    [[ -n "$addr" && "$addr" != "0.0.0.0" ]] || continue
    # Port 1 is chosen because nothing listens there: the useful signal is WHICH failure comes back.
    # "refused" proves the packet arrived and the address is routable; a timeout proves nothing either way.
    probe="$(timeout 2 bash -c "echo > /dev/tcp/${addr}/1" 2>&1)"
    if grep -qi 'refused' <<<"$probe"; then
      info "leg6: ${addr} ANSWERS (refused, not a timeout) — egress to it is not blocked"
    else
      info "leg6: ${addr} did not answer (proves nothing — a filtered route and an absent one look alike)"
    fi
  done
}

# ----------------------------------------------------------------------------------------------------------
# host-side legs
# ----------------------------------------------------------------------------------------------------------
on_host() {
  local repo_root="$1"
  echo "R9 (host-side legs)  repo=${repo_root}"
  local dir="${repo_root}/.devcontainer/${PROFILE_DIR_NAME}"

  # leg 1 — the profile carries no devcontainer.json, and no other profile references its service.
  # This is the load-bearing one: a devcontainer.json beside the compose file makes the service attachable,
  # and every other assertion here becomes a matter of habit rather than of configuration.
  if [[ -e "${dir}/devcontainer.json" ]]; then
    fail "leg1: ${PROFILE_DIR_NAME}/devcontainer.json EXISTS — the service is attachable, so legs 3 and 4 are voluntary"
  else
    pass "leg1: no devcontainer.json in the ${PROFILE_DIR_NAME} profile"
  fi
  local referrers=() f
  for f in "${repo_root}"/.devcontainer/*/devcontainer.json; do
    [[ -e "$f" ]] || continue
    if grep -qE "${PROFILE_DIR_NAME}" "$f"; then
      referrers+=("$f")
    fi
  done
  if ((${#referrers[@]})); then
    fail "leg1: another profile references this one: ${referrers[*]}"
  else
    pass "leg1: no .devcontainer/*/devcontainer.json references the profile"
  fi

  # The frozen mount sources must exist AND be declared read-only: a missing source is created empty by
  # create_host_path and mounts over nothing, and a source without `:ro` lets the agent rewrite the files
  # that define its own confinement — including these checks.
  local src
  for src in .git/hooks .vscode .devcontainer; do
    if [[ -e "${repo_root}/${src}" ]]; then
      pass "mounts: bind source exists — ${src}"
    else
      fail "mounts: bind source MISSING — ${src} would be created empty by create_host_path"
    fi
    if grep -Eq "^[[:space:]]*-[[:space:]]*\.\./\.\./${src//./\\.}:[^:]+:ro([[:space:]]|$)" \
         "${repo_root}/${COMPOSE_FILE}"; then
      pass "mounts: ${src} declared :ro"
    else
      fail "mounts: ${src} is NOT declared :ro in ${COMPOSE_FILE} — the agent can rewrite its own confinement"
    fi
  done

  # The pinned-version file, and the credential file the stack interpolates from.
  if [[ -f "${dir}/versions.env" ]]; then
    pass "pins: versions.env present ($(grep -c '^[A-Z]' "${dir}/versions.env") pinned values)"
  else
    fail "pins: versions.env MISSING — the build cannot resolve HERDR_VERSION and will refuse"
  fi
  if [[ -f "${repo_root}/.env" ]]; then
    pass "env: ${repo_root}/.env present (compose interpolates the environment block from it)"
  else
    fail "env: ${repo_root}/.env missing — every key in the environment block resolves empty"
  fi

  if ! command -v docker >/dev/null 2>&1; then
    info "docker CLI not on PATH here — the container-side legs were NOT ATTEMPTED (run this from a host shell)"
    skipped=$((skipped + 1))
    return
  fi
  # --env-file: Compose looks for `.env` in the compose file's own directory rather than the repository root.
  # Point it at the root file so this check runs standalone, not only through agent.sh. Shell environment
  # still takes precedence, which is how the pinned versions reach a `docker compose` invocation at all.
  # The compose file interpolates the pinned build args with `${…:?}`, so it cannot even be PARSED without
  # them — a bare `docker compose ps` aborts. agent.sh exports them; source the same file here so this script
  # also works when run directly, which is how it gets used while debugging a leg.
  local versions="${repo_root}/.devcontainer/${PROFILE_DIR_NAME}/versions.env"
  if [[ -f "$versions" ]]; then
    local key val
    while IFS='=' read -r key val; do
      [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
      [[ -n "${!key:-}" ]] || export "$key=$val"
    done < "$versions"
    case "$(uname -m)" in
      aarch64|arm64) export HERDR_SHA256="${HERDR_SHA256:-${HERDR_SHA256_LINUX_AARCH64:-}}" ;;
      *)             export HERDR_SHA256="${HERDR_SHA256:-${HERDR_SHA256_LINUX_X86_64:-}}" ;;
    esac
  fi
  local dc=(docker compose --env-file "${repo_root}/.env" -f "${repo_root}/${COMPOSE_FILE}")
  if ! "${dc[@]}" ps --status running --services 2>/dev/null | grep -qx "$SERVICE"; then
    info "service ${SERVICE} is not running, or compose could not resolve its variables."
    info "  start it with: .devcontainer/${PROFILE_DIR_NAME}/agent.sh"
    info "  container-side legs 2-6 NOT ATTEMPTED"
    skipped=$((skipped + 1))
    return
  fi
  echo
  # -e for the two overridable expectations: the legs run in the CONTAINER and `docker compose exec` forwards
  # no host environment, so without this a documented override would silently re-default inside and the
  # operator would read a permanent FAIL as a real finding.
  "${dc[@]}" exec -T -u "$CONTAINER_USER" -w "$WORKDIR" \
    -e "REPO=${REPO}" -e "BOT_LOGIN=${BOT_LOGIN}" "$SERVICE" \
    bash "${WORKDIR}/.devcontainer/${PROFILE_DIR_NAME}/checks/$(basename "$0")" --in-container
  local rc=$?
  ((rc != 0)) && fails=$((fails + rc))
}

main() {
  if [[ "${1:-}" == "--in-container" ]]; then
    in_container
  else
    local here repo_root
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    repo_root="$(cd "${here}/../../.." && pwd)"
    on_host "$repo_root"
  fi
  echo
  if ((fails > 0)); then
    echo "R9 FAIL — ${fails} leg(s)"
    return 1
  fi
  if ((skipped > 0)); then
    echo "R9 INCOMPLETE — the host-side legs held, but the container-side legs were not attempted."
    echo "This is NOT a pass: nothing here checked for docker.sock, sudo or a forwarded credential socket."
    return 2
  fi
  echo "R9 PASS"
  return 0
}

main "$@"
