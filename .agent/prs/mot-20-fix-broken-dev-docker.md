# Fix Devcontainer Prerequisite Installer

Base branch: `origin/main`

## Summary

This branch fixes Docker/devcontainer builds that run
`./scripts/install-prerequisites.sh`.

The installer previously allowed Debian package installs to prompt through
`tzdata`, which blocks noninteractive Docker builds. It could also fail in the
DuckDB CLI install path because `DUCKDB_VERSION` was referenced without being
defined under `set -u`.

## Changes

- Set Debian installer defaults to `DEBIAN_FRONTEND=noninteractive` and
  `TZ=Etc/UTC` unless already provided.
- Run all apt update/install calls in the script with the noninteractive Debian
  environment.
- Add `DUCKDB_VERSION="1.1.3"`.
- Restore the DuckDB CLI installer for Linux and macOS.
- Add DuckDB to the main install flow and final installer summary.
- Add a session summary for this fix under `.agent/summaries/`.

## Verification

- `bash -n ./scripts/install-prerequisites.sh`
- Checked that the DuckDB `v1.1.3` Linux amd64 release URL resolves on GitHub.

Note: `shellcheck` was not installed in the environment, so it was not run.
