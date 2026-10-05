#!/usr/bin/env bash
# 037 P1.3: the scratch HOME sessions run with. BashExec wraps a command in
# `bash -lc`; the real ~/.profile prepends ~/.local/bin, where the real `gh` is,
# so with the real HOME the stub is shadowed (seen in the first dry run). Here
# .profile puts ./stubs first again, and ~/.ailang is linked so the toolchain
# finds its registry cache and state.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="${1:-/tmp/motoko-037-p1.3/home}"
mkdir -p "$H"
ln -sfn "$HOME/.ailang" "$H/.ailang"
printf '%s\n' "export PATH=\"$HERE/stubs:\$PATH\"" > "$H/.profile"
echo "scratch home at $H"
