#!/usr/bin/env bash
# ADR-001 (010) D10's install script — a first-class deliverable, not a convenience.
#
# Run this ON THE HOST MACHINE from a checkout. The devcontainer has no GPU
# access and will not get it, so the interactive viewer is a host-side program
# reading the same tools/code-graph/.out/ tables through the shared workspace
# mount. There is no server and no sync step: the store is the interface.
#
# It (a) installs uv if absent, (b) builds the pinned venv from pyproject.toml +
# uv.lock, (c) runs a wgpu adapter probe that fails loudly with a diagnosis
# rather than letting the D7 spike discover a broken stack mid-measurement, and
# (d) prints the launch command. Idempotent: re-run after dependency bumps.
#
# Acceptance (ADR D10): on a fresh checkout, this script ALONE must produce an
# environment where the adapter probe passes and the spike launches. If you had
# to hand-install anything, that is a defect in this script — report it, do not
# work around it, because a D7 verdict from a hand-built env does not count.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VIEWER="$ROOT/tools/code-graph/viewer"
OUT="$ROOT/tools/code-graph/.out"
PROJECT_DIR="$ROOT/.agent/projects/010_simulation_visualization"
REPORT="$PROJECT_DIR/host-probe-report.json"

FORCE_CONTAINER=0
for arg in "$@"; do
  case "$arg" in
    --force-container) FORCE_CONTAINER=1 ;;
    -h|--help)
      sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      echo
      echo "Usage: tools/code-graph/viewer/install_host.sh [--force-container]"
      echo "  --force-container  proceed even though this looks like the devcontainer"
      echo "                     (only for the opportunistic lavapipe software-rendering extra)"
      exit 0
      ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33mWARN: %s\033[0m\n' "$*" >&2; }
die() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
say "0/5  Where am I?"
# --------------------------------------------------------------------------
if [[ -f /.dockerenv || -n "${REMOTE_CONTAINERS:-}" || -n "${CODESPACES:-}" ]]; then
  if [[ "$FORCE_CONTAINER" != "1" ]]; then
    die "this looks like the devcontainer, which per ADR D10 cannot run the viewer.
     Run this script on the HOST machine from the same checkout — the workspace
     mount is shared, so .out/ needs no copying. Use --force-container only if
     you are deliberately testing the opportunistic lavapipe software-rendering
     extra, which is never a gate."
  fi
  warn "proceeding inside a container at your request; a D7 verdict from here is NOT valid"
fi
echo "repo:     $ROOT"
echo "platform: $(uname -s) $(uname -m)"

# --------------------------------------------------------------------------
say "1/5  uv"
# --------------------------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  echo "uv not found — installing to ~/.local/bin"
  curl -LsSf https://astral.sh/uv/install.sh | sh || die "uv install failed (network?)"
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v uv >/dev/null 2>&1 || die "uv still not on PATH; add \$HOME/.local/bin to PATH and re-run"
echo "uv: $(uv --version)"

# --------------------------------------------------------------------------
say "2/5  pinned venv from pyproject.toml + uv.lock"
# --------------------------------------------------------------------------
cd "$VIEWER"
uv sync --frozen || die "uv sync failed. If it complains the lock is out of date, the pins in
     pyproject.toml changed without re-locking: run 'uv lock' in $VIEWER and commit the result."
echo "venv: $VIEWER/.venv"

# chdb is D8's shared access layer, but it is a heavyweight native wheel and the
# D7 gate is about rendering. Attempted, reported, never fatal.
if uv sync --frozen --extra query >/dev/null 2>&1; then
  echo "chdb (query extra): installed"
  CHDB_OK=true
else
  warn "chdb (query extra) failed to install — the spike does not need it; task 2.2's
       shared-access-layer requirement becomes a finding if this persists"
  uv sync --frozen >/dev/null
  CHDB_OK=false
fi

# --------------------------------------------------------------------------
say "3/5  wgpu adapter probe"
# --------------------------------------------------------------------------
mkdir -p "$PROJECT_DIR"
set +e
CHDB_OK="$CHDB_OK" REPORT_PATH="$REPORT" uv run --frozen python - <<'PY'
"""Adapter probe. Two stages, because they answer different questions:
  1. raw wgpu adapter enumeration  -> WHAT hardware/driver the host exposes
  2. a real offscreen fastplotlib frame -> whether the ACTUAL stack renders
Stage 2 is the verdict; stage 1 is the diagnosis when stage 2 fails."""
import json, os, platform, sys, traceback

report = {
    "stage": "adapter-probe",
    "python": sys.version.split()[0],
    "platform": f"{platform.system()} {platform.machine()} {platform.release()}",
    "chdb_installed": os.environ.get("CHDB_OK") == "true",
    "versions": {},
    "adapters": [],
    "offscreen_frame": None,
    "verdict": "fail",
    "diagnosis": None,
}

for mod in ("wgpu", "pygfx", "fastplotlib", "rendercanvas", "glfw", "numpy"):
    try:
        report["versions"][mod] = __import__(mod).__version__
    except Exception as exc:
        report["versions"][mod] = f"IMPORT FAILED: {exc}"

try:
    import wgpu
    adapters = wgpu.gpu.enumerate_adapters_sync()
    for ad in adapters:
        info = dict(ad.info) if hasattr(ad, "info") else {}
        report["adapters"].append({k: str(v) for k, v in info.items()})
except Exception:
    report["adapters"] = []
    report["diagnosis"] = "adapter enumeration raised:\n" + traceback.format_exc()

try:
    import numpy as np
    import fastplotlib as fpl

    fig = fpl.Figure(size=(320, 240), canvas="offscreen")
    fig[0, 0].add_scatter(np.array([[0.0, 0.0, 0.0], [1.0, 1.0, 0.0]], dtype=np.float32))
    fig.show()

    # `Figure.show()` does NOT render on an offscreen canvas — it only registers
    # `_render` as the draw function and then, unless RTD_BUILD=1 is set, returns
    # without drawing (fastplotlib/layouts/_figure.py:679-693). Snapshotting at
    # that point hits a renderer whose target texture is still None. So force a
    # real draw first: `canvas.draw()` calls `force_draw()` and returns the frame
    # (rendercanvas/offscreen.py:121), which is the end-to-end test we actually
    # want — pixels out of the Metal/Vulkan pipeline, not just a live adapter.
    frame = None
    attempts = []
    for label, call in (
        ("canvas.draw()", lambda: fig.canvas.draw()),
        ("_render() + export_numpy()", lambda: (fig._render(draw=False), fig.export_numpy())[-1]),
        ("export_numpy()", lambda: fig.export_numpy()),
    ):
        try:
            frame = np.asarray(call())
            attempts.append({"call": label, "ok": True})
            break
        except Exception as exc:
            attempts.append({"call": label, "ok": False, "error": f"{type(exc).__name__}: {exc}"})
    if frame is None:
        raise RuntimeError(f"no offscreen draw path succeeded: {attempts}")

    report["offscreen_frame"] = {
        "ok": True,
        "via": next(a["call"] for a in attempts if a["ok"]),
        "attempts": attempts,
        "shape": list(frame.shape),
        # A frame of pure zeros means the pipeline ran but drew nothing, which is
        # a different failure from an exception and must not read as success.
        "nonzero_pixels": int((frame > 0).sum()),
    }
    if int((frame > 0).sum()) == 0:
        raise RuntimeError("offscreen frame rendered but is entirely blank")
    report["verdict"] = "pass"
except Exception:
    report["offscreen_frame"] = report.get("offscreen_frame") or {"ok": False}
    report["offscreen_frame"]["ok"] = False
    report["diagnosis"] = (report["diagnosis"] or "") + \
        "\noffscreen fastplotlib frame raised:\n" + traceback.format_exc()

path = os.environ["REPORT_PATH"]
with open(path, "w") as fh:
    json.dump(report, fh, indent=2, sort_keys=True)

print(json.dumps({k: report[k] for k in ("verdict", "platform", "versions", "adapters")}, indent=2))
if report["verdict"] != "pass":
    print("\n--- diagnosis ---\n" + (report["diagnosis"] or "no diagnosis captured"), file=sys.stderr)
    sys.exit(1)
PY
PROBE_STATUS=$?
set -e

if [[ $PROBE_STATUS -ne 0 ]]; then
  die "wgpu adapter probe FAILED. Full report: $REPORT
     This is the detector doing its job — the D7 spike would otherwise have
     measured a broken stack. Common causes on macOS: an ancient OS without a
     usable Metal backend, or a Python built for the wrong architecture (check
     that 'platform' above says arm64 on Apple silicon).
     Paste $REPORT back to the agent; do not hand-install around it."
fi
echo "adapter probe: PASS  (report: $REPORT)"

# --------------------------------------------------------------------------
say "4/5  store tables"
# --------------------------------------------------------------------------
MISSING=()
for t in layout.csv edges_agg.csv modules.csv extraction_status.csv; do
  [[ -f "$OUT/$t" ]] || MISSING+=("$t")
done
if (( ${#MISSING[@]} )); then
  warn "missing from $OUT: ${MISSING[*]}"
  echo "     Generate them CONTAINER-side (they need the AILANG toolchain, not a GPU):"
  echo "       tools/code-graph/extract.sh --profile=all"
else
  echo "layout/edges_agg present: $(( $(wc -l < "$OUT/layout.csv") - 1 )) layout rows, $(( $(wc -l < "$OUT/edges_agg.csv") - 1 )) edge rows"
fi

# --------------------------------------------------------------------------
say "5/5  ready"
# --------------------------------------------------------------------------
cat <<EOF
Launch the D7 spike exactly as printed — a verdict obtained any other way does
not count (ADR D10). The gate spans two run SHAPES on purpose: the scripted sweep
grades throughput (a human's idle gaps would read as stalls that never happened),
and only an interactive session can grade the click/hover round trip.

  cd $VIEWER

  # 1. scripted sweep, real scene — grades criteria 1, 2, 4, 5, 6
  uv run --frozen python spike_l0l2.py --auto

  # 2. same sweep at the density criterion 2 actually names (~1k L2 nodes;
  #    this repo's all profile has ~225, so the extra copies are synthetic)
  uv run --frozen python spike_l0l2.py --auto --stress 1000

  # 3. interactive — CLICK AND HOVER a few module circles, then close the
  #    window. Criterion 3 cannot be graded without this; the scripted runs
  #    record a lower bound and deliberately refuse to call it a pass.
  uv run --frozen python spike_l0l2.py

  # 4. combine every run into one gate verdict (script-produced, not eyeballed)
  uv run --frozen python spike_l0l2.py --summarize

The gate has since PASSED (NOTE-d7-spike-verdict.md), so the map proper is what
you actually want day to day. The spike above is kept only to re-grade D7 after
a dependency bump:

  # the L0-L2 map: bundled edges, LOD, hover counts, double-click to editor
  uv run --frozen python map_view.py

  # straighten the edge bundling (1 hugs the hierarchy, 0 is straight lines)
  uv run --frozen python map_view.py --beta 0.5

Set EDITOR (e.g. 'code -g') or MOTOKO_MAP_EDITOR_URL to control click-through;
without either it falls back to a vscode:// URL.

One report per run shape lands in $PROJECT_DIR/,
plus host-spike-verdict.json from step 4. The workspace mount is shared, so the
agent can read them directly — nothing needs pasting.
EOF
