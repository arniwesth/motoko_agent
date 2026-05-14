# Implementation Plan: Motoko Agent Promo Site

## Objective
Build an interactive, hacker-aesthetic promo website for `motoko_agent`. The site will run entirely in the browser via WebAssembly (WASM), featuring a full-screen branded background and a floating, draggable Dear ImGui terminal window. The window will replay a pre-recorded text log to simulate Motoko executing live.

The first implementation should be a polished static demo, not a live agent. Future native-agent integration should remain possible, but it must not complicate the initial build.

## Tech Stack
*   **Language:** C++
*   **Graphics & App Shell:** [Sokol](https://github.com/floooh/sokol) (`sokol_app.h`, `sokol_gfx.h`, `sokol_glue.h`, `sokol_time.h`)
*   **UI Framework:** [Dear ImGui](https://github.com/ocornut/imgui) + `sokol_imgui.h`
*   **Compiler:** [Emscripten](https://emscripten.org/) (`emcc`) to compile C++ to WebAssembly.

The site should use a CSS background image behind the canvas for the first version. This avoids a custom textured-quad shader pipeline and keeps the C++ side focused on the interactive ImGui layer. Add Sokol texture rendering only if the canvas must own the background later.

## Directory Structure
```text
.
├── Makefile                # Emscripten build commands
├── web/
│   ├── index.html          # Clean HTML shell to host the WASM canvas
│   └── assets/
│       ├── background.jpg  # Site-only background wallpaper
│       └── motoko.log      # Pre-recorded agent execution log
├── ext/                    # External dependencies
│   ├── sokol/              # Sokol headers
│   ├── imgui/              # Dear ImGui source files
│   └── versions.lock       # Exact dependency source URLs and commits/tags
└── src/
    └── main.cpp            # Core application logic
```

## Implementation Phases

### Phase 1: Environment & Dependencies
1.  Use the Emscripten SDK supplied by the development environment when available. Otherwise install `emsdk` locally and document the exact version in `ext/versions.lock`.
2.  Vendor Sokol and Dear ImGui into `ext/` at pinned commits/tags. Record each source URL and revision in `ext/versions.lock`.
3.  Add a repeatable dependency bootstrap path, either:
    *   `make deps`, which fetches the pinned dependencies into `ext/`; or
    *   checked-in vendored files plus `make verify_deps`, which confirms the expected files are present.
4.  Required vendored files:
    *   Sokol headers: `sokol_app.h`, `sokol_gfx.h`, `sokol_glue.h`, `sokol_imgui.h`, `sokol_time.h`
    *   Dear ImGui sources: `imgui.cpp`, `imgui_draw.cpp`, `imgui_tables.cpp`, `imgui_widgets.cpp`, `imgui_demo.cpp` only if the demo window is used during development.

### Phase 2: Core Application Skeleton (C++)
1.  **Sokol Setup:** Initialize `sokol_app` for window creation and a WebGL2 context.
2.  **Sokol GFX Setup:** Initialize `sokol_gfx` with `sokol_glue` environment data.
3.  **ImGui Setup:** Initialize `sokol_imgui` to route ImGui rendering through WebGL.
4.  **App Loop:** Create the `init`, `frame`, `event`, and `cleanup` callbacks required by `sokol_app`.
5.  **Timing:** Use `sokol_time.h` for frame delta timing instead of hand-rolled wall-clock logic.
6.  **Canvas Behavior:** Configure the canvas for high-DPI rendering, resize with the viewport, and clear with transparent or near-black alpha so the CSS background remains visible.

### Phase 3: Web Shell & Visual Base
1.  Create `web/index.html` with a full-screen `<canvas id="canvas"></canvas>` and the Emscripten module bootstrap.
2.  Style the page to remove margins, hide scrollbars, set a dark fallback color, and place `web/assets/background.jpg` as a full-viewport CSS background.
3.  Make the first viewport clearly identify Motoko. The visible composition should include:
    *   the Motoko name as the dominant brand signal;
    *   a short supporting line such as "self-verifying agent harness";
    *   an unobtrusive GitHub/repo link;
    *   the live-status ImGui window as the primary interactive object.
4.  Provide loading and failure states in HTML/CSS while the WASM module downloads or fails to initialize.

### Phase 4: The Agent Simulation (Log Replay)
1.  **File Loading:** In `init`, read `/assets/motoko.log` into memory from the Emscripten preload package.
2.  **Simulation State:** Track `current_line_index` and a `timer`.
3.  **ImGui Window:**
    *   Create an ImGui window (`ImGui::Begin("motoko_agent // live status");`).
    *   Set an initial size and position that works on desktop and mobile.
    *   Render only the currently visible portion of long logs using `ImGuiListClipper` when the log exceeds a small threshold.
    *   Add syntax highlighting / text coloring for specific keywords (e.g., `[INFO]`, `[ERROR]`, `> executing`).
    *   Implement auto-scroll only while the user is already near the bottom, so manual scrolling is not constantly overridden.
    *   Add compact controls for pause/resume, restart, and replay speed.
4.  **Time Progression:** Update the `timer` every frame using delta time. When the timer exceeds a threshold, increment `current_line_index` to "type out" the next log line.
5.  **Fallbacks:** If the log cannot be loaded, render a clear in-window error and keep the rest of the site usable.

### Phase 5: Build & Packaging
1.  Write a `Makefile` that compiles the C++ files using `emcc`.
2.  Output generated files under `web/dist/`:
    *   `web/dist/motoko.js`
    *   `web/dist/motoko.wasm`
    *   `web/dist/motoko.data` when preloaded files are emitted separately.
3.  Include all required C++ sources explicitly:
    *   `src/main.cpp`
    *   the required Dear ImGui `.cpp` files
4.  Use explicit Emscripten flags:
    *   `-std=c++17`
    *   `-O2` for release builds and `-gsource-map -O0` for debug builds
    *   `-sUSE_WEBGL2=1`
    *   `-sMIN_WEBGL_VERSION=2`
    *   `-sMAX_WEBGL_VERSION=2`
    *   `-sALLOW_MEMORY_GROWTH=1`
    *   `-sNO_EXIT_RUNTIME=1`
    *   `--preload-file web/assets@/assets`
5.  Add Make targets:
    *   `make deps` or `make verify_deps`
    *   `make web`
    *   `make web-debug`
    *   `make clean-web`
    *   `make serve`

### Phase 6: Serving & Verification
1.  Serve the site over HTTP; do not rely on opening `web/index.html` directly from disk. `make serve` should run a simple local static server from `web/` and print the URL.
2.  Verify in at least one Chromium-based browser:
    *   WASM and preload data load without console errors.
    *   the background image covers desktop and mobile viewport sizes without distortion;
    *   the ImGui window is visible, draggable, and usable;
    *   log replay, pause/resume, restart, speed control, and auto-scroll work;
    *   text remains readable and does not overflow controls on narrow screens.
3.  Keep a short manual QA note in the implementation summary with browser, viewport sizes, and any known limitations.

## Future Expansion
Because the architecture is already C++ compiled to WebAssembly, if/when the actual Motoko compiler or agent logic is ported to C/C++/Rust/Zig, it can replace the static log replay. Treat that as a separate phase with its own threat model, browser sandbox constraints, resource limits, and UX for long-running execution.
