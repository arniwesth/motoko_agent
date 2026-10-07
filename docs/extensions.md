# Writing an extension

Extensions are AILANG packages under `packages/`. The [README](../README.md#extensions) lists the ones in this repo and which are on by default.

Extensions are path dependencies of the root package, so a new one is added in this repo:

1. Copy `packages/motoko-ext-test-dummy/`, a minimal no-op extension, to `packages/motoko-ext-<name>/` and rename its package and module to `motoko_ext_<name>`.
2. Add it to `ailang.toml` twice: under `[dependencies]` (the path) and in `[extensions].packages` (name and version).
3. List `<name>` in your profile's `extensions.order`.
4. Regenerate the registry and build:

```bash
make registry_gen   # rewrites src/core/ext/registry_generated.ail from ailang.toml
make build          # syncs packages, type-checks, boot-probes the profile's extensions
```

Use `make registry_gen`, not the upstream `ailang generate-extension-registry`, which emits an older registry shape. The `ailang init motoko-extension` scaffolder has the same limitation: it targets extension ABI 2.x, while the packages here are on ABI 8.0 (`packages/motoko-ext-abi`). The ABI's design record is in `.agent/projects/017_extension_handling/`.

For publishing an extension to the AILANG package registry: [Publishing Your Package](https://ailang.sunholo.com/docs/guides/package-publishing).
