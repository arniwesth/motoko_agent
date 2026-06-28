from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
TOOL_ROOT = REPO_ROOT / "tools" / "code-graph"
OUT_DIR = TOOL_ROOT / ".out"

GRAPH_SCHEMA = 1
SOURCE_SCHEMA = 1
SEED_GRANULARITY = "module"
IFACE_SCHEMA = "ailang.iface/v1"

DEFAULT_PROFILE = "core"
PROFILES = {
    "core": ("src/core",),
    "all": ("src", "scripts", "examples"),
    "smoke": ("scripts", "examples", "src/examples"),
}
ROOT_HOST_GLOBS = (
    "AGENTS.md",
    "ailang.toml",
    "config.json",
    "scripts/install-prerequisites.sh",
    "tools/code-graph/README.md",
    "tools/code-graph/**/*.py",
    "tools/code-graph/**/*.sh",
)
HOST_FILE_GLOBS = {
    "core": ROOT_HOST_GLOBS + (
        "src/tui/src/**/*.ts",
    ),
    "all": ROOT_HOST_GLOBS + (
        "src/tui/src/**/*.ts",
        "scripts/**/*.sh",
        "scripts/**/*.py",
        "examples/**/*.sh",
        "examples/**/*.py",
        "examples/**/*.md",
        "src/examples/**/*.ts",
    ),
    "smoke": ROOT_HOST_GLOBS + (
        "scripts/**/*.sh",
        "scripts/**/*.py",
        "examples/**/*.sh",
        "examples/**/*.py",
        "examples/**/*.md",
        "src/examples/**/*.ts",
    ),
}
STD_EFFECT_MODULES = {"std/ai", "std/clock", "std/cognition", "std/dom", "std/debug",
                      "std/env", "std/fs", "std/io", "std/net", "std/process",
                      "std/trace", "std/game", "std/gzip", "std/package",
                      "std/tar", "std/zip"}
