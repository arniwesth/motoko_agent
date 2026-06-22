# Devcontainer Installer Prerequisites Fix

Date: 2026-06-22

## Context

The devcontainer Docker build was breaking when running `./scripts/install-prerequisites.sh`.

Two failures were reported:

- `tzdata` prompted for geographic area and city during apt package installation, which blocks Docker builds.
- The installer reached the DuckDB CLI section and failed under `set -u` with `DUCKDB_VERSION: unbound variable`.

## Investigation

Checked:

- `scripts/install-prerequisites.sh`
- `.devcontainer/Dockerfile`
- historical commits touching the installer

Findings:

- Current `scripts/install-prerequisites.sh` did not contain a DuckDB installer block, but a prior commit (`9ac9e03`) had one and defined `DUCKDB_VERSION="1.1.3"`.
- The working tree already had `.devcontainer/Dockerfile` modified to comment out `RUN ./scripts/install-prerequisites.sh`; that existing local change was left untouched.
- Debian apt installs were not consistently forcing `DEBIAN_FRONTEND=noninteractive`, allowing `tzdata` to prompt.

## Changes Made

Updated `scripts/install-prerequisites.sh`:

- Added DuckDB to the dependency list.
- Added `DUCKDB_VERSION="1.1.3"`.
- Added `duckdb_ok`.
- Restored `install_duckdb` using the official DuckDB GitHub release ZIPs:
  - `amd64` maps to `duckdb_cli-linux-amd64.zip`
  - `arm64` maps to `duckdb_cli-linux-aarch64.zip`
- Added `install_duckdb` to the main install flow after Node.js.
- Added DuckDB to the final summary output.
- Exported Debian defaults in `configure_privilege`:
  - `DEBIAN_FRONTEND=noninteractive`
  - `TZ=Etc/UTC` unless already set
- Updated all apt install/update calls in the script to run through:
  - `env DEBIAN_FRONTEND=noninteractive TZ="${TZ:-Etc/UTC}"`

## Verification

Ran:

```bash
bash -n ./scripts/install-prerequisites.sh
```

Result: passed.

Also checked the DuckDB `v1.1.3` amd64 release URL with `curl -fsSIL`; GitHub returned a valid redirect to the release asset.

`shellcheck` was not installed in the environment, so it was not run.

## Remaining Notes

`.devcontainer/Dockerfile` still has the installer line commented out from a pre-existing local change:

```dockerfile
#RUN ./scripts/install-prerequisites.sh
```

The installer itself is now patched so that line can be restored when desired.
