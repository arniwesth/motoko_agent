#!/usr/bin/env python3
"""Run tools/code-graph against a private output directory.

    python3 .agent/projects/037_skills_system/evidence/g0_code_graph_private.py extract <out-dir>
    python3 .agent/projects/037_skills_system/evidence/g0_code_graph_private.py q <out-dir> <cgq args...>

Why this exists. At HEAD `tools/code-graph/extract.sh --profile=all` stops with

    GraphIntegrityError: duplicate unqualified import in
    src/eval/journal/candidate_checks: Interaction from src/core/dst_interaction
    and src/eval/journal/admission

so the shared cache in tools/code-graph/.out/ cannot be refreshed for the whole
repo, and what is there was built 2026-08-08 on AILANG v0.33.0.

This wrapper runs the SAME extractor and the SAME query engine, unmodified, with
two things changed at run time only:

  - the output directory, so the shared cache is not overwritten; and
  - the source set: `src/core`, `scripts` and `packages`, which are the trees
    ADR-001 cites. `src/eval` is left out, so the integrity check is respected,
    not bypassed. `examples` and `src/examples` are left out as not cited.

Nothing under tools/code-graph/ is edited. Run from the repo root.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TOOL = ROOT / "tools" / "code-graph"
PROFILE = "adr037"


def extract(out: Path) -> int:
    sys.path.insert(0, str(TOOL))
    from extractor import config          # patch before anything else imports it
    config.OUT_DIR = out
    config.PROFILES[PROFILE] = ("src/core", "scripts", "packages")
    config.HOST_FILE_GLOBS[PROFILE] = config.HOST_FILE_GLOBS["all"]
    from extractor import emit
    sys.argv = ["emit.py", "--profile", PROFILE]
    return emit.main()


def query(out: Path, args: list[str]) -> int:
    sys.path.insert(0, str(TOOL / "query"))
    import cgq
    cgq.OUT_DIR = out
    sys.argv = ["cgq.py"] + args
    return cgq.main()


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in ("extract", "q"):
        print(__doc__)
        return 2
    out = Path(sys.argv[2]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if sys.argv[1] == "extract":
        return extract(out)
    return query(out, sys.argv[3:])


if __name__ == "__main__":
    raise SystemExit(main())
