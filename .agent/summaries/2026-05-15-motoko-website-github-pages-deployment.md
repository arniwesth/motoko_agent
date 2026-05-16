# Motoko Website GitHub Pages Deployment

Date: 2026-05-15

Implemented `.github/workflows/deploy-website.yml` to build and deploy the static Motoko website from `web/` to GitHub Pages for `arniwesth/motoko_agent`.

## Workflow

- Triggers on pushes to `main` and `motoko_website` when relevant website/build files change.
- Supports manual `workflow_dispatch`.
- Uses `mymindstorm/setup-emsdk@v14` to install Emscripten on the GitHub-hosted runner.
- Fetches pinned Sokol and Dear ImGui dependency files directly with `curl`.
- Builds the WASM site with `emcc`, writing artifacts to `web/dist/`.
- Uploads `web/` as the Pages artifact.
- Deploys via `actions/deploy-pages@v4` to the `github-pages` environment.

## Important Details

The initial plan called `make deps`, but the `deps` target was only present in local dirty `Makefile` changes, not in the committed `HEAD` used by GitHub Actions. The workflow was changed to fetch dependencies directly so deployment does not depend on uncommitted Makefile state.

GitHub Pages had to be enabled manually in repo settings:

- `Settings > Pages > Build and deployment > Source`
- Set source to `GitHub Actions`

The first Pages API failure from `actions/configure-pages@v5` was caused by Pages not being enabled for the repository yet.

The later 404 was not an artifact-root issue. The build job succeeded, but the deploy job had failed under the `github-pages` environment/deployment gate. Once the deployment was allowed and rerun successfully, the site worked.

## Site URL

Expected GitHub Pages URL:

https://arniwesth.github.io/motoko_agent/

## Files Changed

- `.github/workflows/deploy-website.yml`

