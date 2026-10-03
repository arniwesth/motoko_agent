#!/usr/bin/env bash
# Install what explainer needs, without root: Manim, ffmpeg and Kokoro in a conda-forge
# environment under the home directory (about 1.5 GB). Safe to run again; it skips what exists.
#
#   ./setup.sh                 manim, ffmpeg, the narration package and its model files
#   ./setup.sh --with-whisper  also faster-whisper and its small.en model (about 0.5 GB more),
#                              for `explainer render --transcribe`
#
# Every download goes to a temporary name, is verified, and only then takes its place, so a
# failed or interrupted run leaves nothing a later run would mistake for the real thing.
#
# EXPLAINER_ROOT moves the install (default ~/.local/share/manim-env-root). If you move it,
# export EXPLAINER_ENV=$EXPLAINER_ROOT/env, KOKORO_MODELS=$EXPLAINER_ROOT/models/kokoro and
# WHISPER_MODELS=$EXPLAINER_ROOT/models/whisper.
#
# Sourced instead of run, it only defines its functions; selftest.sh tests them that way.
set -euo pipefail

# die MESSAGE [PARTIAL]: remove what was half-made and stop.
die() {
  [ -z "${2:-}" ] || rm -rf "$2"
  echo "setup.sh: $1" >&2
  exit 1
}

# fetch URL DEST: download to DEST.part, failing on an HTTP error instead of saving its page.
fetch() {
  rm -f "$2.part"
  curl -fsSL --retry 3 -o "$2.part" "$1" || die "could not download $1" "$2.part"
}

# matches SHA256 FILE: whether the file has that checksum.
matches() {
  echo "$1  $2" | sha256sum --check --status 2>/dev/null
}

# whisper_whole DIR: whether the model is all there. The same four files the tool requires
# before it transcribes: one missing, and faster-whisper would go and download it.
whisper_whole() {
  local f
  for f in model.bin config.json tokenizer.json vocabulary.txt; do
    [ -s "$1/$f" ] || return 1
  done
}

main() {
  local root=${EXPLAINER_ROOT:-$HOME/.local/share/manim-env-root} arch
  case "$(uname -m)" in
    aarch64|arm64) arch=linux-aarch64 ;;
    x86_64) arch=linux-64 ;;
    *) die "no micromamba build named for $(uname -m)" ;;
  esac

  mkdir -p "$root/bin"
  if ! "$root/bin/micromamba" --version >/dev/null 2>&1; then
    local releases=https://github.com/mamba-org/micromamba-releases/releases/latest/download
    fetch "$releases/micromamba-$arch" "$root/bin/micromamba"
    chmod +x "$root/bin/micromamba.part"
    "$root/bin/micromamba.part" --version >/dev/null ||
      die "the micromamba download does not run" "$root/bin/micromamba.part"
    mv "$root/bin/micromamba.part" "$root/bin/micromamba"
  fi
  if [ ! -x "$root/env/bin/manim" ]; then
    MAMBA_ROOT_PREFIX=$root "$root/bin/micromamba" create -y -q -p "$root/env" -c conda-forge \
      python=3.12 manim ffmpeg
    MAMBA_ROOT_PREFIX=$root "$root/bin/micromamba" clean -a -y -q
  fi
  "$root/env/bin/python" -c "import kokoro_onnx" 2>/dev/null ||
    "$root/env/bin/pip" install --quiet kokoro-onnx

  # The Kokoro model files, pinned by checksum: release model-files-v1.0.
  local models=$root/models/kokoro sum name
  local base=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
  mkdir -p "$models"
  while read -r sum name; do
    if ! matches "$sum" "$models/$name"; then
      fetch "$base/$name" "$models/$name"
      matches "$sum" "$models/$name.part" ||
        die "$name does not match its checksum" "$models/$name.part"
      mv "$models/$name.part" "$models/$name"
    fi
  done <<'SUMS'
7d5df8ecf7d4b1878015a32686053fd0eebe2bc377234608764cc0ef3636a6c5 kokoro-v1.0.onnx
bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d voices-v1.0.bin
SUMS

  if [ "${1:-}" = --with-whisper ]; then
    "$root/env/bin/python" -c "import faster_whisper" 2>/dev/null ||
      "$root/env/bin/pip" install --quiet faster-whisper
    # Provisioned here so that --transcribe never downloads anything at render time.
    local whisper=$root/models/whisper/small.en
    if ! whisper_whole "$whisper"; then
      rm -rf "$whisper.part"
      # The path goes in as an argument: written into the source, a quote in it would end
      # the string.
      "$root/env/bin/python" -c '
import sys
from faster_whisper import download_model
download_model("small.en", output_dir=sys.argv[1])' "$whisper.part" >/dev/null
      whisper_whole "$whisper.part" || die "the Whisper model came incomplete" "$whisper.part"
      mkdir -p "$(dirname "$whisper")"
      rm -rf "$whisper"
      mv "$whisper.part" "$whisper"
    fi
  fi
  "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/explainer" doctor
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
