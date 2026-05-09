---
doc_type: short
full_text: sources/MOTOKO_PUBLIC_RELEASE.md
---

# Summary: Motoko Agent Public Release Plan

This document details a phased plan to extract mature Motoko Agent components from the private `ailang_agent` repository into a clean, self-contained public repository (`motoko_agent`). The goal is to polish the codebase for an open-source release while preserving runtime behavior, the TUI, and the underlying [[concepts/AILANG]]-based architecture.

## Core Decisions

- **File Manifest:** A carefully selected set of files (system prompts, core `.ail` modules, TUI source, config templates, design archive, omnigraph, and curated papers) are included. Internal tooling, benchmarks, training code, experimental artifacts, and large binary files (e.g., PDFs) are explicitly excluded.
- **Installation Automation:** The `install-prerequisites.sh` script is updated to automatically clone and build the public AILANG fork (`github.com/sunholo-data/ailang`), eliminating manual steps.
- **Dockerization:** A lightweight `.devdocker/` setup provides a reproducible environment with Go, Bun, Node.js, `context-mode` CLI, and the AILANG runtime, enabling quick onboarding.
- **Documentation Rewrite:** `README.md` is rewritten for a public audience, featuring architecture, quick start (including Docker), configuration, extension usage, and in-session commands. All references to internal repos or private model strings are removed.
- **Config Sanitization:** The default config profile is cleaned: hardcoded model strings are updated to current public models, and unnecessary fields (e.g., `openai_base_url`) are removed.
- **Build Simplification:** The `Makefile` is trimmed of internal, experimental, and AILANG‑specific targets. Core commands (`build`, `test`, `run`) are preserved and updated to assume `ailang` is on PATH.

## Implementation Phases

1. **Define publishable manifest** – List of all included/excluded paths.
2. **Update install script** – Auto‑clone AILANG and integrate into PATH.
3. **Create `.devdocker/`** – Dockerfile and compose file for ready‑to‑use development.
4. **Rewrite README.md** – Public‑focused documentation.
5. **Sanitize config template** – Clean default configuration.
6. **Trim Makefile** – Remove internal targets, keep core ones.
7. **Verification** – Validate installation, Docker build, tests, and smoke run.

The successful execution of this plan will produce a transparent, buildable, and well‑documented public repository that reflects the mature state of the [[motoko_agent]]. The process also establishes a model for future [[concepts/open_source_release_process]] within the project.

## Related Concepts
- [[concepts/open-source-release-preparation]]
