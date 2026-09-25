# `context_usage`'s config reads block WI-A12's env-class poison probe

Filed: 2026-08-02, from WI-A12 (cluster 6), env class.
Status: open. Owner: the implementation plan — it needs a scope decision A12 does not own.

## What is true at HEAD

All six of the **driver's own** env reads are routed through `Ports.env_get` and the world.
`src/core/session.ail` contains **zero** `getEnvOr` calls. That half is done, and the evidence is
executable: `world_state_probe` seeds `MOTOKO_HEADLESS` in the world and asserts the driver acted on
the world's value rather than the process environment, with a control run proving the two branches
diverge into different terminal outcomes. Un-routing that single read type-checks clean and turns
the assertion red — verified by mutation, not assumed.

## What is not true, and why it was not fixed here

**A deterministic run still dies with `Env` withheld**, so the env class has no poison pair.

`src/core/context_usage.ail` reads `MOTOKO_MODELS_FILE`, `MOTOKO_REPO`, `MOTOKO_PROFILE_DIR` and
`MOTOKO_CONFIG` from `catalog_path` (`:24`) and `profile_dir_path` (`:70`), reached from
`resolve_context_limit` (`:104`), which the driver calls at **six sites** in `session.ail`.

These reads cannot be routed on their own. `resolve_context_limit` is `! {Env, FS}` and **every env
read in it exists to compute a file path that it then reads**. Threading the world through the env
half alone would hand the driver a world-supplied path to an ambient file: the run would pass an
`Env` poison probe while still depending on ambient state. That is a green check implying coverage
it does not have — cluster 4's C1b defect, restated — so it was deliberately not done.

Finishing it requires a **filesystem class**, which WI-A12's specified order (provider, clock,
approval, env, randomness, typed tool contract) does not contain. D1's request surface item 4 is
"environment/config reads performed during the established run", which covers these; D1 also
contemplates "an in-memory file map" as a profile-supplied resource, which is the shape the fix
wants. Neither is scheduled.

## Why this matters beyond A12

`driver_only` (P4) is meant to be a *conformant* profile. A profile whose runs cannot execute with
`Env` withheld has an un-routed effect surface, so the D5 routing audit has something real to catch
here. It does not block A13 (world_state threading is what A13 depends on, and that landed), but it
does bound what a conformance claim can honestly say.

## Options, for whoever picks this up

1. **Add a filesystem/config class to A12 or a successor item.** Route `resolve_context_limit`
   wholesale: the catalog contents come from the world, not from a path. Largest, and the only one
   that makes the poison pair pass honestly.
2. **Hoist config resolution above the driver.** Resolve the context limit once at the entry point
   and pass the integer in, so the loop performs no config read at all. Smaller, and it shrinks the
   driver's effect row, but it moves the read rather than routing it.
3. **Scope the profile.** Declare config reads out of `driver_only`'s reachable set with a stated
   condition, the way D3's fault classes are waived. Cheapest, and honest only if the condition is
   written down and the attribution table (WI-A5) records it.

Option 2 is the one worth costing first: six call sites, all of which pass the same `model`.
