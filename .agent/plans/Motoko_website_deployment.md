# Plan: Deploy Motoko Website to GitHub Pages

## Context

The Motoko promo site is a static C++/WASM app (Sokol + ImGui compiled with Emscripten) served from `web/`. The built artifacts (`web/dist/motoko.js`, `motoko.wasm`, `motoko.data`) are gitignored. We need a GitHub Actions workflow that builds the site and deploys it to GitHub Pages on the `arniwesth/motoko_agent` repo.

## Approach

Add a single GitHub Actions workflow file: `.github/workflows/deploy-website.yml`

### Triggers

- **push** to `main` and `motoko_website` branches, filtered to paths that affect the site:
  - `src/main.cpp`
  - `web/**`
  - `Makefile`
  - `.github/workflows/deploy-website.yml`
- **workflow_dispatch** for manual runs from any branch

### Build steps

1. **Checkout** the repo
2. **Install Emscripten** using `mymindstorm/setup-emsdk` action (version `latest`, matching the Makefile's `EMSDK_VERSION`)
3. **Fetch dependencies** via `make deps` (downloads pinned Sokol and ImGui headers)
4. **Compile** the WASM build by running the `emcc` command directly (the action already sets up Emscripten in PATH, so the Makefile's `emsdk` target is unnecessary)
5. **Upload** `web/` as a GitHub Pages artifact using `actions/upload-pages-artifact`
6. **Deploy** using `actions/deploy-pages`

### Deployment artifact

The uploaded directory is `web/`, which contains:
- `index.html` at root
- `assets/motoko.png` and `assets/motoko.log`
- `dist/motoko.js`, `dist/motoko.wasm`, `dist/motoko.data` (built during CI)

### Permissions and environment

- The workflow needs `pages: write` and `id-token: write` permissions
- The deploy job uses the `github-pages` environment
- Concurrency group prevents overlapping deployments

## Manual repo setup (one-time)

In the GitHub repo settings: **Settings > Pages > Source** must be set to **"GitHub Actions"** (not "Deploy from a branch").

## Files to create

| File | Action |
|------|--------|
| `.github/workflows/deploy-website.yml` | Create |

## Verification

1. Push the workflow to `motoko_website` branch
2. Trigger via `workflow_dispatch` or let the push trigger fire
3. Check the Actions tab for a successful build + deploy
4. Visit `https://arniwesth.github.io/motoko_agent/`
5. Verify: background image renders, WASM terminal initializes, glitch effects run, repo link opens in new tab
