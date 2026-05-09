#!/usr/bin/env bash
# install-prerequisites.sh
#
# Installs all dependencies required to build and run Motoko:
#   - System packages (git, curl, build-essential)
#   - Go 1.22+
#   - Bun 1.x
#   - Node.js 18+ and npm
#   - context-mode CLI
#   - AILANG runtime (cloned from github.com/sunholo-data/ailang at pinned tag)
#   - bun dependencies for the TypeScript frontend (src/tui/)
#   - Optional: Omnigraph CLI/server (with --with-omnigraph)
# Usage:
#   ./scripts/install-prerequisites.sh
#
# Supported OS:
#   - Debian / Ubuntu (apt)
#   - macOS (Homebrew)
#
# Run as a user with sudo access. Do NOT run as root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GO_VERSION="1.22.5"
GO_MIN_MAJOR=1
GO_MIN_MINOR=22
BUN_MIN_MAJOR=1
NODE_MIN_MAJOR=18
OMNIGRAPH_MIN_VERSION="0.3.0"
AILANG_REF="v0.18.8"
AILANG_MIN_VERSION="0.18.8"
INSTALL_OMNIGRAPH=0

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()   { echo -e "${BLUE}  →${NC} $1"; }
log_ok()     { echo -e "${GREEN}  ✓${NC} $1"; }
log_warn()   { echo -e "${YELLOW}  ⚠${NC} $1"; }
log_error()  { echo -e "${RED}  ✗${NC} $1" >&2; }
log_header() { echo -e "\n${BOLD}$1${NC}"; }

die() { log_error "$1"; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./scripts/install-prerequisites.sh [--with-omnigraph] [--help]

Options:
  --with-omnigraph   Build and install Omnigraph CLI/server from source
  --help             Show this help text
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-omnigraph) INSTALL_OMNIGRAPH=1; shift ;;
      --help|-h) usage; exit 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
detect_os() {
  if [[ "$(uname)" == "Darwin" ]]; then
    OS="macos"
  elif [[ -f /etc/debian_version ]]; then
    OS="debian"
  else
    die "Unsupported OS. This script supports Debian/Ubuntu and macOS only."
  fi
}

# ---------------------------------------------------------------------------
# Detect CPU architecture (for Go tarball selection)
# ---------------------------------------------------------------------------
detect_arch() {
  local machine
  machine="$(uname -m)"
  case "$machine" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
    *)       die "Unsupported architecture: $machine" ;;
  esac
}

# ---------------------------------------------------------------------------
# Version comparison helpers
# ---------------------------------------------------------------------------
version_ge() {
  # Returns 0 (true) if $1 >= $2 (dot-separated version strings)
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

go_version_ok() {
  if ! command -v go &>/dev/null; then return 1; fi
  local ver major minor
  ver="$(go version | awk '{print $3}' | sed 's/go//')"
  major="$(echo "$ver" | cut -d. -f1)"
  minor="$(echo "$ver" | cut -d. -f2)"
  [[ "$major" -gt "$GO_MIN_MAJOR" ]] || \
    { [[ "$major" -eq "$GO_MIN_MAJOR" ]] && [[ "$minor" -ge "$GO_MIN_MINOR" ]]; }
}

bun_version_ok() {
  if ! command -v bun &>/dev/null; then return 1; fi
  local major
  major="$(bun --version | cut -d. -f1)"
  [[ "$major" -ge "$BUN_MIN_MAJOR" ]]
}

node_version_ok() {
  if ! command -v node &>/dev/null; then return 1; fi
  local major
  major="$(node --version | sed 's/^v//' | cut -d. -f1)"
  [[ "$major" -ge "$NODE_MIN_MAJOR" ]]
}

npm_ok() {
  command -v npm &>/dev/null
}

context_mode_ok() {
  if ! command -v context-mode &>/dev/null; then return 1; fi
  context-mode doctor &>/dev/null
}

omnigraph_version_ok() {
  if ! command -v omnigraph &>/dev/null; then return 1; fi
  local ver
  ver="$(omnigraph version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
  [[ -n "$ver" ]] && version_ge "$ver" "$OMNIGRAPH_MIN_VERSION"
}

ensure_user_local_bin_on_path() {
  mkdir -p "$HOME/.local/bin"
  if ! grep -qF '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi
  if ! grep -qF '.local/bin' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
  fi
  export PATH="$HOME/.local/bin:$PATH"
}

# ---------------------------------------------------------------------------
# Debian: system packages
# ---------------------------------------------------------------------------
install_apt_packages() {
  log_header "System packages (apt)"
  log_info "Updating package lists..."
  sudo apt-get update -qq

  local pkgs=(git curl build-essential ca-certificates)
  local missing=()
  for pkg in "${pkgs[@]}"; do
    dpkg -s "$pkg" &>/dev/null || missing+=("$pkg")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_ok "All system packages already installed"
  else
    log_info "Installing: ${missing[*]}"
    sudo apt-get install -y -qq "${missing[@]}"
    log_ok "System packages installed"
  fi
}

# ---------------------------------------------------------------------------
# macOS: Homebrew
# ---------------------------------------------------------------------------
install_brew_packages() {
  log_header "Homebrew packages"
  if ! command -v brew &>/dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  else
    log_ok "Homebrew already installed"
  fi

  for pkg in git curl; do
    if brew list "$pkg" &>/dev/null; then
      log_ok "$pkg already installed"
    else
      log_info "Installing $pkg..."
      brew install "$pkg"
      log_ok "$pkg installed"
    fi
  done
}

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------
install_go() {
  log_header "Go"
  if go_version_ok; then
    log_ok "Go $(go version | awk '{print $3}') already installed (>= ${GO_MIN_MAJOR}.${GO_MIN_MINOR})"
    return
  fi

  if [[ "$OS" == "macos" ]]; then
    log_info "Installing Go via Homebrew..."
    brew install go
    log_ok "Go installed via Homebrew"
    return
  fi

  # Debian: download official tarball
  local tarball="go${GO_VERSION}.linux-${ARCH}.tar.gz"
  local url="https://go.dev/dl/${tarball}"
  local tmp
  tmp="$(mktemp -d)"

  log_info "Downloading Go ${GO_VERSION} (linux/${ARCH})..."
  curl -fsSL "$url" -o "${tmp}/${tarball}"

  log_info "Installing to /usr/local/go..."
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "${tmp}/${tarball}"
  rm -rf "$tmp"

  # Persist PATH for future shells
  local profile_line='export PATH="$PATH:/usr/local/go/bin"'
  for rcfile in "$HOME/.bashrc" "$HOME/.profile"; do
    if [[ -f "$rcfile" ]] && ! grep -qF '/usr/local/go/bin' "$rcfile"; then
      echo "$profile_line" >> "$rcfile"
    fi
  done

  # Make available in this session
  export PATH="$PATH:/usr/local/go/bin"

  log_ok "Go ${GO_VERSION} installed"
}

# ---------------------------------------------------------------------------
# Bun
# ---------------------------------------------------------------------------
install_bun() {
  log_header "Bun"
  if bun_version_ok; then
    log_ok "Bun $(bun --version) already installed (>= ${BUN_MIN_MAJOR}.x)"
    return
  fi

  log_info "Installing Bun via official installer..."
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  if ! command -v bun &>/dev/null; then
    die "Bun install completed but bun is not on PATH. Add ~/.bun/bin to PATH and rerun."
  fi
  log_ok "Bun $(bun --version) installed"
}

# ---------------------------------------------------------------------------
# Node.js + npm
# ---------------------------------------------------------------------------
install_node() {
  log_header "Node.js"
  if node_version_ok && npm_ok; then
    log_ok "Node.js $(node --version) and npm $(npm --version) already installed"
    return
  fi

  if [[ "$OS" == "macos" ]]; then
    log_info "Installing Node.js via Homebrew..."
    brew install node
  else
    log_info "Installing Node.js 22.x via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
  fi

  if ! node_version_ok; then
    die "Node.js install completed but node >= ${NODE_MIN_MAJOR} is not on PATH."
  fi
  if ! npm_ok; then
    die "Node.js install completed but npm is not on PATH."
  fi
  log_ok "Node.js $(node --version) and npm $(npm --version) installed"
}

# ---------------------------------------------------------------------------
# context-mode CLI
# ---------------------------------------------------------------------------
install_context_mode() {
  log_header "context-mode CLI"
  ensure_user_local_bin_on_path

  if context_mode_ok; then
    log_ok "context-mode already installed at $(command -v context-mode)"
    return
  fi

  log_info "Installing context-mode from npm into ~/.local/bin..."
  npm_config_prefix="$HOME/.local" npm install -g context-mode

  if context_mode_ok; then
    log_ok "context-mode installed at $(command -v context-mode)"
  else
    die "context-mode install completed but 'context-mode doctor' failed. Check Node.js/npm output above."
  fi
}

# ---------------------------------------------------------------------------
# src/tui/ bun dependencies
# ---------------------------------------------------------------------------
install_bun_deps() {
  log_header "TypeScript frontend dependencies (src/tui/)"
  local tui_dir="${PROJECT_ROOT}/src/tui"

  if [[ ! -f "${tui_dir}/package.json" ]]; then
    die "src/tui/package.json not found. Run this script from the project root."
  fi

  log_info "Running bun install in src/tui/..."
  (cd "$tui_dir" && bun install)
  log_ok "bun dependencies installed"

  log_info "Building TypeScript frontend..."
  (cd "$tui_dir" && bun run build)
  log_ok "TypeScript build check completed"
}

# ---------------------------------------------------------------------------
# AILANG runtime — clone from public fork, build, install
# ---------------------------------------------------------------------------
ailang_version_ok() {
  if ! command -v ailang &>/dev/null; then return 1; fi
  local ver
  ver="$(ailang --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
  [[ -n "$ver" ]] && version_ge "$ver" "$AILANG_MIN_VERSION"
}

install_ailang() {
  log_header "AILANG runtime"
  if ailang_version_ok; then
    log_ok "ailang $(ailang --version 2>/dev/null | head -1) already installed (>= ${AILANG_MIN_VERSION})"
    return
  fi

  if command -v ailang &>/dev/null; then
    local cur_ver
    cur_ver="$(ailang --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")"
    log_warn "ailang ${cur_ver} found but < ${AILANG_MIN_VERSION} required — upgrading..."
  fi

  ensure_user_local_bin_on_path

  local ailang_src="$HOME/.local/share/ailang"
  log_info "Cloning AILANG ($AILANG_REF) from github.com/sunholo-data/ailang..."
  if [[ -d "$ailang_src/.git" ]]; then
    log_info "Updating existing clone at $ailang_src..."
    git -C "$ailang_src" fetch --tags --all
    git -C "$ailang_src" checkout "$AILANG_REF"
  else
    rm -rf "$ailang_src"
    git clone --branch "$AILANG_REF" https://github.com/sunholo-data/ailang "$ailang_src"
  fi

  log_info "Building ailang..."
  local _ver _commit _build_time _ldflags
  _ver="$(git -C "$ailang_src" describe --tags --always --dirty 2>/dev/null || echo "$AILANG_REF")"
  _commit="$(git -C "$ailang_src" rev-parse HEAD 2>/dev/null || echo "unknown")"
  _build_time="$(date -u '+%Y-%m-%d_%H:%M:%S')"
  _ldflags="-X github.com/sunholo-data/ailang/internal/version.Version=${_ver}"
  _ldflags="${_ldflags} -X github.com/sunholo-data/ailang/internal/version.Commit=${_commit}"
  _ldflags="${_ldflags} -X github.com/sunholo-data/ailang/internal/version.BuildTime=${_build_time}"
  (cd "$ailang_src" && go build -ldflags "$_ldflags" ./cmd/ailang)
  cp "$ailang_src/ailang" "$HOME/.local/bin/ailang"
  chmod +x "$HOME/.local/bin/ailang"

  if ailang_version_ok; then
    log_ok "ailang installed: $(ailang --version 2>/dev/null | head -1)"
  else
    die "ailang build completed but version check failed (need >= ${AILANG_MIN_VERSION})"
  fi
}

install_omnigraph() {
  log_header "Omnigraph (optional)"
  if [[ "$INSTALL_OMNIGRAPH" -ne 1 ]]; then
    log_info "Skipping Omnigraph build (pass --with-omnigraph to enable)"
    return
  fi

  if omnigraph_version_ok; then
    log_ok "omnigraph $(omnigraph version 2>/dev/null | tr '\n' ' ') already installed (>= ${OMNIGRAPH_MIN_VERSION})"
    return
  fi

  if [[ "$OS" == "debian" ]]; then
    local og_pkgs=(gcc protobuf-compiler)
    local og_missing=()
    for pkg in "${og_pkgs[@]}"; do
      dpkg -s "$pkg" &>/dev/null || og_missing+=("$pkg")
    done
    if [[ ${#og_missing[@]} -gt 0 ]]; then
      log_info "Installing Omnigraph apt prerequisites: ${og_missing[*]}"
      sudo apt-get install -y -qq "${og_missing[@]}"
    fi
  else
    for pkg in protobuf; do
      if brew list "$pkg" &>/dev/null; then
        log_ok "$pkg already installed"
      else
        log_info "Installing $pkg..."
        brew install "$pkg"
      fi
    done
  fi

  if ! command -v rustup &>/dev/null; then
    log_info "Installing rustup (stable toolchain)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
  if ! grep -qF '.cargo/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
  fi
  if ! grep -qF '.cargo/bin' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.profile"
  fi

  local src_dir="/opt/omnigraph-src"
  if [[ ! -d "$src_dir/.git" ]]; then
    log_info "Cloning Omnigraph source to $src_dir..."
    sudo rm -rf "$src_dir"
    sudo git clone https://github.com/ModernRelay/omnigraph "$src_dir"
  else
    log_info "Updating Omnigraph source at $src_dir..."
    sudo git -C "$src_dir" fetch --all --tags
    sudo git -C "$src_dir" pull --ff-only
  fi

  sudo chown -R "$USER":"$USER" "$src_dir"
  log_info "Building Omnigraph CLI/server (this may take several minutes on first run)..."
  (cd "$src_dir" && cargo build --release --locked -p omnigraph-cli -p omnigraph-server)

  ensure_user_local_bin_on_path
  cp "$src_dir/target/release/omnigraph" "$HOME/.local/bin/omnigraph"
  chmod +x "$HOME/.local/bin/omnigraph"

  if omnigraph_version_ok; then
    log_ok "omnigraph installed: $(omnigraph version 2>/dev/null | tr '\n' ' ')"
  else
    die "Omnigraph build completed but version check failed"
  fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD} Installation complete${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo ""
  echo "  Go:      $(go version 2>/dev/null | awk '{print $3}' || echo 'not found')"
  echo "  Bun:     $(bun --version 2>/dev/null || echo 'not found')"
  echo "  Node.js: $(node --version 2>/dev/null || echo 'not found')"
  echo "  npm:     $(npm --version 2>/dev/null || echo 'not found')"
  echo "  ailang:  $(command -v ailang &>/dev/null && echo 'found' || echo 'not found')"
  echo "  context-mode: $(command -v context-mode &>/dev/null && echo 'found' || echo 'not found')"
  echo "  omnigraph: $(command -v omnigraph &>/dev/null && echo 'found' || echo 'not found')"
  echo ""
  echo "  Next steps:"
  echo "    1. Set your API key (OPENROUTER_API_KEY)"
  echo "    2. Run:"
  echo "         MOTOKO_CONFIG=default ./scripts/run-agent.sh \"your task here\""
  echo ""
}
main() {
  echo -e "${BOLD}Motoko — prerequisite installer${NC}"

  parse_args "$@"

  detect_os
  detect_arch
  log_info "Detected OS: $OS  arch: $ARCH"

  case "$OS" in
    debian) install_apt_packages ;;
    macos)  install_brew_packages ;;
  esac

  install_go
  install_bun
  install_node
  install_context_mode
  install_bun_deps
  install_ailang
  install_omnigraph
  print_summary
}

main "$@"
