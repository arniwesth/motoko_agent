---
sources: [summaries/MOTOKO_PUBLIC_RELEASE.md]
brief: The process of selecting, sanitizing, and packaging internal code for a public open-source release.
---

# Open Source Release Preparation

Preparing an internal project for public release requires deliberate curation to ensure the repository contains only the essential, clean components — no internal tooling, private keys, or irrelevant artifacts. The goal is to make the project instantly usable, well‑documented, and self‑contained.

## Key Steps

### 1. Define a Publishable Manifest
Carefully select which files and directories to include. Exclude benchmarks, training data, logs, vendored forks that will become public separately, and any experimental or private tooling. In the [[summaries/MOTOKO_PUBLIC_RELEASE]] plan, only mature `src/core/` modules, the TUI, config templates, design archive, and curated papers were included; internal patches, benchmarks, and 52 MB of PDFs were left out.

### 2. Remove Private / Sensitive Data
Scrub configuration files of hardcoded internal URLs, private model strings, and proxy settings. Replace them with default public values or leave them empty for users to fill. The Motoko plan sanitized `.motoko/config/default/config.json` by removing `openai_base_url` and setting the model to a public Claude ID.

### 3. Automate Dependency Installation
Public users should not need to hunt for dependencies. Scripts like `install-prerequisites.sh` are updated to automatically clone and build necessary tools. The Motoko release added auto‑cloning of the public [[concepts/AILANG]] fork, eliminating manual Go builds.

### 4. Provide a Reproducible Dev Environment
A Dockerfile and compose file give new users a ready‑to‑run environment with all build tools. The Motoko `.devdocker/` setup includes Go, Bun, Node.js, and the AILANG runtime — everything needed to run the agent after a single `docker compose up --build`.

### 5. Rewrite Documentation for a Public Audience
Public READMEs should explain what the project does, how to get started, and how to contribute. Remove internal references, legacy notes, and irrelevant sections. The Motoko README overhaul focused on architecture, quick start via Docker, extension usage, and a clean project structure tree.

### 6. Trim Build System & Ignore Files
Remove outdated Makefile targets (codex, claude, prune). Update `.gitignore` to cover build caches and environment files. Keep only targets that make sense for the public build: `build`, `test`, `run`, etc.

### 7. Verify Every Deliverable
Before tagging a release, run the install script in a clean environment, build the Docker image, execute the test suite, and perform a smoke run. The Motoko plan checks all five deliverables — install script, Docker, core tests, TUI build, and config init.

## Motoko Agent as a Model

The planning document [[summaries/MOTOKO_PUBLIC_RELEASE]] is a concrete example of this preparation. It lays out seven phases that cover everything from file selection to final verification. The systematic approach ensures the resulting `motoko_agent` repository is not just a code dump but a ready‑to‑contribute open‑source project.