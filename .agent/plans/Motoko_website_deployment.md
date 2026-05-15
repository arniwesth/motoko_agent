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

### Job 1: `build`

Runs on `ubuntu-latest`.

1. **Checkout** the repo (`actions/checkout@v4`)
2. **Install Emscripten** using `mymindstorm/setup-emsdk@v14` (version `latest`, matching the Makefile's `EMSDK_VERSION`)
3. **Fetch dependencies** via `make deps` (downloads pinned Sokol and ImGui headers into `ext/`)
4. **Compile** the WASM build by running the `emcc` command directly (the action puts `emcc` in PATH, so the Makefile's `emsdk` env sourcing is unnecessary):
   ```
   mkdir -p web/dist
   emcc src/main.cpp \
     ext/imgui/imgui.cpp ext/imgui/imgui_draw.cpp \
     ext/imgui/imgui_tables.cpp ext/imgui/imgui_widgets.cpp \
     -Iext/sokol -Iext/imgui \
     -std=c++17 -O2 \
     -sUSE_WEBGL2=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 \
     -sALLOW_MEMORY_GROWTH=1 -sNO_EXIT_RUNTIME=1 \
     --preload-file web/assets@/assets \
     -o web/dist/motoko.js
   ```
5. **Configure Pages** (`actions/configure-pages@v5`) — sets base path metadata
6. **Upload artifact** (`actions/upload-pages-artifact@v3`) with `path: web/`

### Job 2: `deploy`

Depends on `build`. Runs in the `github-pages` environment.

1. **Deploy** (`actions/deploy-pages@v4`)

### Deployment artifact

The uploaded directory is `web/`, which contains:
- `index.html` at root
- `assets/motoko.png` and `assets/motoko.log`
- `dist/motoko.js`, `dist/motoko.wasm`, `dist/motoko.data` (built in job 1)

### Permissions and environment

- Top-level permissions: `pages: write` and `id-token: write`
- The `deploy` job uses the `github-pages` environment
- Concurrency group `pages` with `cancel-in-progress: false` prevents overlapping deployments

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
