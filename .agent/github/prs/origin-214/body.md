---
repo: arniwesth/motoko_agent
pr: 214
branch: docs/readme-running-motoko
ticket: null
title: "docs(readme): lead with the agent sandbox and the dev container"
---

## Summary

Brings `README.md` up to date. The Installation section becomes **Running Motoko** and opens with
the two easiest ways to run it, side by side: the `agent_confined` sandbox, driven from a host
shell with `agent.sh`, and the VS Code dev container. The native install stays as a third option.

The rest of the README is corrected where it no longer matched the tree, most of all the
instructions for adding an extension, which pointed at tooling that does not fit this repo.

## Changes

- docs(readme): lead with the agent sandbox and the dev container

1 file changed.

- **Running Motoko**: a comparison table of the two containers, one `.env` step shared by all
  three paths, then a section each. The sandbox section gives the first-run commands, the
  everyday `agent.sh` commands, what the container withholds, and the caveat that the boundary
  is around the container and not the shared working tree.
- **Usage**: `make motoko`, the `MODEL` and `PROFILE` overrides, the four TUI commands, and
  `--headless` / `--oneshot` through `scripts/run-agent.sh`.
- **Extensions**: the table lists every registered extension except the `test_dummy` fixture
  (18 of 19) and marks the nine the default profile enables.
- **Adding a new extension**: copy `packages/motoko-ext-test-dummy`, wire it into `ailang.toml`,
  run `make registry_gen`. The link to the upstream "Build Your First motoko Extension" tutorial
  is dropped along with the scaffolder it was written around; the tutorial itself was not read.
- **Highlights, Development, Project structure**: refreshed against the current targets and
  tracked directories.

Configuration and Model identifiers are unchanged apart from `compaction_ai.json` in the profile
listing.

## Governing docs

- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md`: the sandbox the
  README now documents as the first way to run Motoko.
- `.agent/projects/017_extension_handling/ADR-001-extension-abi-evolution.md`: the extension ABI
  behind the rewritten "Adding a new extension" steps.

## Predicted outcome

- Someone new to the repo can get Motoko running from the README through either container,
  without reading `.devcontainer/` first.
- Nobody is sent to `ailang init motoko-extension` or `ailang generate-extension-registry`,
  neither of which produces something this tree accepts.
- No effect on anything that runs: only `README.md` changes.

Checked by following the sandbox steps on a host with no `motoko_agent_confined/dev:1.0` image.
That has not been done; see below.

Two things for whoever merges:

- **The first-run order differs from the profile's own README.** This README says `agent.sh build`,
  then `bootstrap`, then `agent.sh`. `.devcontainer/agent_confined/README.md` and the `agent.sh`
  header say `bootstrap` builds the image, but `ensure_up` runs `docker image inspect "$IMAGE"`
  and exits before `compose up -d` when the image is absent. The same README also says Motoko
  reads `.env` directly, while the compose file masks it with `/dev/null`. Neither is fixed here:
  `.devcontainer/**` is read-only inside the agent container, so that is a host-side change.
- **#194 renames `.devcontainer/agent_confined/` to `.devcontainer/agent/`.** This README uses the
  path on `main` in five places. Whichever of the two lands second has to carry the rename.

## Test evidence

- [x] Every `make` target the README names exists in the `Makefile`: `run`, `motoko`, `build`,
  `check_core`, `test`, `test_integration`, `verify_core`, `dst`, `registry_gen`, `init-config`,
  `install`, `studio`.
- [x] Every relative link and every path named in the text exists, and all 13 in-page anchors
  match a heading.
- [x] The extension table against `src/core/ext/registry_generated.ail`: the only registered name
  not in the table is `test_dummy`.
- [x] `ailang init motoko-extension --name probe/motoko_ext_probe --tools "Tool1" --effects "FS"`
  in a scratch directory, AILANG v0.47.2: the scaffold depends on `sunholo/motoko_ext_abi = "2.2.0"`
  and its `register_with_config` returns `ExtensionHooks`. `packages/motoko-ext-abi` is `8.0` and
  the in-tree packages return `ExtRegistration`.
- [x] `.env` inside the running agent container is a character device (`1, 3`), matching the
  `/dev/null:/workspaces/motoko_agent/.env:ro` mount in the compose file.
- [x] TUI commands and launcher flags read from `src/tui/src/commands.ts` and
  `parseMotokoFlags` in `src/tui/src/index.ts`.
- [ ] The sandbox first run (`agent.sh build`, `bootstrap`, attach). Not run: `agent.sh` is
  host-only and refuses inside a container. The order comes from reading the script.
- [ ] The dev container and native install paths. Not run; the commands are unchanged from the
  previous README.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
