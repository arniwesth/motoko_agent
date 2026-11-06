#!/usr/bin/env bash
# Installs Rocq 9.3.0 (rocq-prover: rocq-core and rocq-stdlib) under one directory, with no
# root and no system packages beyond a C toolchain: the devcontainer has neither sudo, nor
# pkg-config, nor GMP's headers, nor m4, and zarith (which rocq-runtime needs) needs all three.
# So m4, GMP and pkgconf are built from source first, and opam is told not to check system
# packages (--no-depexts). See README.md for what it took.
#
#   install_rocq.sh <dir>        then:  export OPAMROOT=<dir>/opamroot PATH=<dir>/pfx/bin:$PATH
#                                       eval "$(opam env --switch=rocq)"
#
# Needs network access to ftp.gnu.org, distfiles.ariadne.space, github.com and opam.ocaml.org.
set -euo pipefail

dir="$(mkdir -p "${1:?usage: install_rocq.sh <dir>}" && cd "$1" && pwd)"
pfx="$dir/pfx"; src="$dir/src"
mkdir -p "$pfx/bin" "$src"
export PATH="$pfx/bin:$PATH"

build() {  # build <name> <url>: an autotools tarball into $pfx
  local name="$1" url="$2"
  curl -sSLo "$src/$name.tar.xz" "$url"
  mkdir -p "$src/$name" && tar -xJf "$src/$name.tar.xz" -C "$src/$name" --strip-components=1
  (cd "$src/$name" && ./configure --prefix="$pfx" >/dev/null && make -j"$(nproc)" >/dev/null && make install >/dev/null)
}
[[ -x "$pfx/bin/m4" ]] || build m4 https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz
[[ -f "$pfx/include/gmp.h" ]] || build gmp https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
if [[ ! -x "$pfx/bin/pkg-config" ]]; then
  build pkgconf https://distfiles.ariadne.space/pkgconf/pkgconf-2.3.0.tar.xz
  ln -sf "$pfx/bin/pkgconf" "$pfx/bin/pkg-config"
fi
if [[ ! -x "$pfx/bin/opam" ]]; then
  case "$(uname -m)" in aarch64|arm64) arch=arm64 ;; x86_64) arch=x86_64 ;; *) echo "unsupported arch"; exit 2 ;; esac
  curl -sSLo "$pfx/bin/opam" "https://github.com/ocaml/opam/releases/download/2.6.1/opam-2.6.1-$arch-linux"
  chmod +x "$pfx/bin/opam"
fi

export OPAMROOT="$dir/opamroot" OPAMYES=1 OPAMJOBS="$(nproc)"
export C_INCLUDE_PATH="$pfx/include" LIBRARY_PATH="$pfx/lib" LD_LIBRARY_PATH="$pfx/lib"
export PKG_CONFIG_PATH="$pfx/lib/pkgconfig"
[[ -d "$OPAMROOT" ]] || opam init --bare --disable-sandboxing -n
opam switch list 2>/dev/null | grep -qw rocq || opam switch create rocq ocaml-base-compiler.4.14.2
opam install --switch=rocq --no-depexts rocq-core.9.3.0 rocq-stdlib.9.2.0
opam exec --switch=rocq -- rocq --version
