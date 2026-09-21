# P1.2d — stopped: herdr's captures cannot go through `config` under names-not-values

PLAN-001 (031) §3 P1.2, batch D. HEAD `eebc4d13`. AILANG v0.33.0. **No package file was changed and
nothing was committed.** This is the brief's "If the ADR turns out to be wrong" exit: *a capture that
cannot go through config — stop and report the artifact.*

## The finding

The brief requires herdr to disclose environment **names**, "never a pane id or path **value**, in
config". ADR D2 (`:372-374`) says the in-tree captures hold environment-variable names, not values.
**That is false for herdr.** Four of its six callbacks need, at call time, **values** that come only
from the environment, and their views give them no environment route:

| site (Q-1) | slot / view | registration values the body reads | other route on the view? |
|---|---|---|---|
| 26 `ExitIntent` | `{FS}` / `FsCtx` | `own_pane` (`HERDR_PANE_ID`), `session_ms` (`MOTOKO_SESSION_MS`), `dagr_dir` (`MOTOKO_DAGR_DIR` or `${MOTOKO_WORKDIR}/.dagr`), `bin` (`HERDR_BIN_PATH`, a guard), `reap_on_exit`, `settle_on_exit` | none: `FsCtx` has no `env_get`, and no view field carries a pane or session identity (`state_key` is a fixed core string) |
| 27 `WorkInFlight` | `{FS}` / `FsCtx` | `own_pane`, `session_ms`, `dagr_dir` | none |
| 23 `PromptShaper` | `{}` / `PureCtx` | `orch: OrchestratorMode`: `pane` (the pane id) and `run_paths` (run-file paths), which are also printed into the prompt text (`orchestrator.ail:307`) | none (no ports) |
| 24 `ToolPolicy` | `{}` / `PureCtx` | `orch` (`pane` and `run_paths` appear in the `Deny` text, `:634`) | none |

The render needs the pane id and session to build the run-file name (`dagr.run_file`,
`run-<pane-slug>-<session_ms>.json`) and the owner token it hands the host (`types.owner_token_value` =
`"<pane>:<session_ms>"`). Several panes share one workdir and one `.dagr/`. That is the case in this
checkout. So a render that lists the directory cannot pick out its own file.

Sites 22 (`DescribeTools`: `allowed_kinds` and `kind`, which are operator policy strings, not pane or
path values) and 25 (`ToolProvider`: `ProviderCtx` carries `env_get`, so names in config plus
`ctx.ports.env_get` per call would work) are **not** blocked.

## The artifact (`fs_view_probe/`, `RESULT.txt`)

`run.sh` checks three probes against the **committed** ABI 8.0 in a throwaway workspace. It exits 0:

1. `p_env_in_render`: a named `FsCtx` render reads `HERDR_PANE_ID` → **rejected**, `Missing effects: Env`.
2. `p_env_row_widened`: the same render declares `! {FS, Env}` → **rejected** at `ExitIntent`,
   `incompatible closed rows: … extra labels [Env]`.
3. `p_value_in_config`: registration puts the pane id and session **values** in `config`, and the render
   reads them from `ext_config` → **clean**. This is the only route that compiles, and the brief forbids it.

## Consequence the orchestrator should weigh

If values are permitted, herdr's `config` holds a pane id and a per-session `session_ms`. Its config
digest then changes with every pane and every session, and D2 says that change appends a policy
epoch on resume. This is likely why names-not-values was wanted. The options are the orchestrator's
(a numbered amendment):

- **(a)** permit non-credential environment values (pane id, session id, paths) in `config`, and record
  that herdr's digest is per-session by construction;
- **(b)** keep names-not-values and give the `{FS}` and `{}` views a host-stamped session or pane
  identity, which is an ABI change (a view field, so 9.0 under the 8.x rule, or an 8.x field behind the
  constructors);
- **(c)** accept that herdr's `ExitIntent`/`WorkInFlight`/orchestrator atoms stay unmigrated under a
  named exemption.

## Not blocked

compose (sites 10–13) captures `ComposeHostConfig` (models, integers, booleans, modes, snippet caps)
read from `compose.json`/`config.json`. It holds no environment value (the `MOTOKO_PROFILE_DIR` path is
used only to find the files). It could migrate under the brief as written. It was not started, because
the brief treats batch D as one commit.

## Count

The brief and the plan say **11** sites. The Q-1 ledger (rows 10–13 and 22–27) and HEAD both show
**10**: compose 4 and herdr 6. There are 6 captures: `runtime_cfg`, `snippet_caps` and
`composition_mode`; `cfg`, `tools` and `orch`.
