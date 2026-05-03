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
  # Transform local core imports to package imports for extension package resolution.
  # Modules exported by sunholo/motoko_core with module_prefix="src":
  #   src/core/compress, src/core/config, src/core/tool_contract,
  #   src/core/types, src/core/ext/types
  # These become: pkg/sunholo/motoko_core/core/<rest>
  find "$pkg_ext_dir" -name '*.ail' -print0 | while IFS= read -r -d '' f; do
    sed -i \
      -e 's|import src/core/compress (|import pkg/sunholo/motoko_core/core/compress (|g' \
      -e 's|import src/core/config (|import pkg/sunholo/motoko_core/core/config (|g' \
      -e 's|import src/core/tool_contract (|import pkg/sunholo/motoko_core/core/tool_contract (|g' \
      -e 's|import src/core/types (|import pkg/sunholo/motoko_core/core/types (|g' \
      -e 's|import src/core/ext/types (|import pkg/sunholo/motoko_core/core/ext/types (|g' \
      "$f"
  done
  # Generate lock file for the extension package so its dependencies resolve.
  (cd "$pkg_dir" && ailang lock)

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
sync_core() {
  local src_dir="$ROOT_DIR/src/core"
  local pkg_dir="$ROOT_DIR/.packages/motoko_core"
  local pkg_mod_dir="$pkg_dir/src/core"

  mkdir -p "$pkg_mod_dir/ext"
  rsync -a --delete \
    --exclude '.ailang/' \
    --exclude 'AGENT.md' \
    --exclude 'ailang.toml' \
    --exclude 'ext/compose/' \
    --exclude 'ext/context_mode/' \
    --exclude 'ext/exa_search/' \
    --exclude 'ext/mcp/' \
    --exclude 'ext/omnigraph/' \
    --exclude 'ext/test_dummy/' \
    "$src_dir/" "$pkg_mod_dir/"

  cp "$src_dir/ailang.toml" "$pkg_dir/ailang.toml"

  if [[ -f "$src_dir/AGENT.md" ]]; then
    cp "$src_dir/AGENT.md" "$pkg_dir/AGENT.md"
  fi

  echo "synced: motoko_core -> .packages/motoko_core"
}

main() {
  sync_core
  sync_extension "compose"
  sync_extension "omnigraph"
  sync_extension "test_dummy"
  sync_extension "context_mode"
  sync_extension "exa_search"
  sync_extension "mcp"
}

main "$@"
