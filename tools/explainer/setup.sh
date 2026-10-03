#!/usr/bin/env bash
# Install what explainer needs, without root: Manim, ffmpeg and Kokoro in a conda-forge
# environment under the home directory (about 1.5 GB). Safe to run again; it skips what exists.
#
#   ./setup.sh                 manim, ffmpeg, the narration package and its model files
#   ./setup.sh --with-whisper  also faster-whisper, for `explainer render --transcribe`
#
# EXPLAINER_ROOT moves the install (default ~/.local/share/manim-env-root). If you move it,
# export EXPLAINER_ENV=$EXPLAINER_ROOT/env and KOKORO_MODELS=$EXPLAINER_ROOT/models/kokoro.
set -euo pipefail
root=${EXPLAINER_ROOT:-$HOME/.local/share/manim-env-root}
case "$(uname -m)" in
  aarch64|arm64) arch=linux-aarch64 ;;
  x86_64) arch=linux-64 ;;
  *) echo "setup.sh: no micromamba build named for $(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$root/bin"
if [ ! -x "$root/bin/micromamba" ]; then
  curl -sL -o "$root/bin/micromamba" \
    "https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-$arch"
  chmod +x "$root/bin/micromamba"
fi
if [ ! -x "$root/env/bin/manim" ]; then
  MAMBA_ROOT_PREFIX=$root "$root/bin/micromamba" create -y -q -p "$root/env" -c conda-forge \
    python=3.12 manim ffmpeg
  MAMBA_ROOT_PREFIX=$root "$root/bin/micromamba" clean -a -y -q
fi
"$root/env/bin/python" -c "import kokoro_onnx" 2>/dev/null ||
  "$root/env/bin/pip" install --quiet kokoro-onnx
if [ "${1:-}" = --with-whisper ]; then
  "$root/env/bin/python" -c "import faster_whisper" 2>/dev/null ||
    "$root/env/bin/pip" install --quiet faster-whisper
fi

models=$root/models/kokoro
base=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
mkdir -p "$models"
for f in kokoro-v1.0.onnx voices-v1.0.bin; do
  [ -s "$models/$f" ] || curl -sL -o "$models/$f" "$base/$f"
done
"$(cd "$(dirname "$0")" && pwd)/explainer" doctor
