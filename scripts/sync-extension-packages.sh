#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sync_extension() {
  local ext_name="$1"
  local src_dir="$ROOT_DIR/src/core/ext/$ext_name"
  local pkg_dir="$ROOT_DIR/.packages/motoko_$ext_name"
  local pkg_ext_dir="$pkg_dir/src/core/ext/$ext_name"

  if [[ ! -d "$src_dir" ]]; then
    echo "skip: source extension directory missing: $src_dir" >&2
    return 0
  fi

  mkdir -p "$pkg_dir/src/core/ext"
  rm -rf "$pkg_ext_dir"
  mkdir -p "$pkg_ext_dir"
  rsync -a --delete \
    --exclude '.ailang/' \
    --exclude 'AGENT.md' \
    --exclude 'ailang.toml' \
    "$src_dir/" "$pkg_ext_dir/"

  if [[ -f "$src_dir/AGENT.md" ]]; then
    cp "$src_dir/AGENT.md" "$pkg_dir/AGENT.md"
  fi

  if [[ -f "$src_dir/ailang.toml" ]]; then
    cp "$src_dir/ailang.toml" "$pkg_dir/ailang.toml"
    sed -i \
      -e 's|path = "../.."|path = "../motoko_core"|g' \
      -e 's|path = "../../"|path = "../motoko_core"|g' \
      -e 's|path = "../mcp"|path = "../motoko_mcp"|g' \
      "$pkg_dir/ailang.toml"
  fi

  echo "synced: $ext_name -> .packages/motoko_$ext_name"
}

main() {
  sync_extension "compose"
  sync_extension "omnigraph"
  sync_extension "test_dummy"
  sync_extension "context_mode"
  sync_extension "exa_search"
  sync_extension "mcp"
}

main "$@"
