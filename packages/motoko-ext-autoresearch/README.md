# sunholo/motoko_ext_autoresearch

A motoko_agent extension. Scaffolded with `ailang init motoko-extension`.

## Status

Experimental — generated from template. Replace the no-op hook implementations in [autoresearch.ail](autoresearch.ail) with your real logic.

## Develop

```bash
ailang lock                  # resolve registry deps
ailang check --package .     # type-check every module in this package
```

The package's `_smoke.ail` runs in the publish sandbox at `ailang publish` time and blocks publish on a panic. Edit it to assert anything that's load-bearing for your extension; drop the `-- optional` sections that don't apply.

### Path-dep dev loop (recommended for iterating against a host)

While iterating on this extension against `motoko_agent` (or any host that consumes it), use a path-dep in the host's `ailang.toml` so you don't have to publish for every change:

```toml
[dependencies]
"sunholo/motoko_ext_autoresearch" = { path = "../path/to/this/package" }

[extensions]
packages = [
  "sunholo/motoko_ext_autoresearch@0.1.0",   # version still matches [package].version above
]
```

Then from the host: `ailang lock && ailang generate-extension-registry && make verify_extensions` (or the host's equivalent). Once the loop closes, switch the host back to the published version pin and publish this package.

## Wire into a host (production, after publish)

In the host's `ailang.toml`:

```toml
[dependencies]
"sunholo/motoko_ext_autoresearch" = "0.1.0"   # registry version

[extensions]
packages = [
  # ... existing entries ...
  "sunholo/motoko_ext_autoresearch@0.1.0",
]
```

Then re-lock + regenerate the dispatch:

```bash
ailang lock
ailang generate-extension-registry
```

## Publish to the AILANG registry

When the extension is stable and you want others to consume it:

```bash
ailang publish --dry-run     # tarball + smoke test, no upload
ailang publish               # the real thing (requires AILANG_REGISTRY_API_KEY)
```

### Provider-safe tool naming

Tool names advertised via `provided_tools` (and the `name` field of `on_describe_tools`) MUST match `[A-Za-z0-9_]` — Anthropic Bedrock + Vertex AI reject names containing `.`, `-`, or other characters at the tool-name validator. Use `ctx_execute` or `CtxExecute`, never `ctx.execute`. `ailang publish` enforces this gate; the `--allow-dotted-tool-names` flag provides one-cycle migration grace if you're upgrading an older package.

### Publish checklist

- [ ] Bump `[package].version` in `ailang.toml` (semver: patch for fixes, minor for new tools, major for ExtensionHooks-breaking changes)
- [ ] `ailang check --package .` passes
- [ ] `ailang publish --dry-run` succeeds (smoke runs in sandbox)
- [ ] `ailang publish` (real upload — irreversible)
- [ ] Bump the host's pin: `"sunholo/motoko_ext_autoresearch" = "<new-version>"` + matching `[extensions].packages` entry
- [ ] Host: `ailang lock && ailang generate-extension-registry` + verify extensions boot

See: https://ailang.sunholo.com/docs/guides/package-publishing

## Documentation

- [Build Your First motoko Extension](https://ailang.sunholo.com/docs/guides/build-a-motoko-extension) (tutorial)
- [Motoko Extension Development workflow](https://ailang.sunholo.com/docs/guides/motoko-extension-development) (path-dep dev loop)
- [Extension Packages reference](https://ailang.sunholo.com/docs/guides/extension-packages)
- [Publishing Your Package](https://ailang.sunholo.com/docs/guides/package-publishing)
