---
doc_type: short
full_text: sources/Motoko_Config_System.md
---

Summarizes design of the Motoko file-based configuration system, which organizes 49 environment variables into a discoverable, committable TOML hierarchy under `.motoko/`. Core concepts include explicit mapping tables, precedence (defaults < `.motoko/` < `.env` < shell env vars), extension-specific config files, and a TypeScript‑only loader that avoids AILANG runtime changes. Details the problem (organic, undiscoverable env vars), schema for `config.toml` and extension files, implementation plan (config loader, tests, `make init-config` scaffold), and rationale for TOML over JSON/YAML.

Key design ideas:
- [[concepts/config-precedence]]: strict ordering from file defaults to environment variables ensures backwards compatibility and per‑invocation overrides.
- [[concepts/toml-config-files]]: TOML chosen for human readability, comments, and nested table support, with `smol-toml` as zero‑dependency parser.
- [[concepts/explicit-mapping-table]]: each TOML key is explicitly mapped to its env var (e.g., `agent.max_steps` → `AI_MAX_STEPS`), avoiding convention‑based surprises.
- [[concepts/extension-config]]: each extension (compose, context_mode, exa_search, omnigraph) gets its own optional `.toml` file, loaded based on active extensions in `CORE_EXT_ORDER`.
- [[concepts/no-api-keys-in-config]]: secrets are intentionally excluded, kept in `.env` files or shell env vars.
- [[concepts/staggered-implementation]]: phased rollout (core config → extension config → scaffold command → docs) to minimize risk.

Implementation notes cover integration with existing `.env` loader, moving both loaders inside `main()` for correct `WORKDIR` resolution, empty string handling, and test cases for boolean/array serialization and precedence enforcement. Future considerations include home‑directory layering and live config reload. Full document available at `sources/Motoko_Config_System.md`.