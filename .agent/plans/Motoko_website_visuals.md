# Implementation Plan: Motoko Website Visual Glitch Pass

## Objective
Add a cinematic glitch treatment to the Motoko promo site without compromising readability, performance, or the usability of the WASM/ImGui terminal.

The target feel is corrupted AI runtime telemetry: signal instability, chromatic offsets, terminal interference, and short bursts of visual corruption. The direction may be inspired by cyberpunk interfaces, but it should not copy Cyberpunk 2077's exact yellow/black brand language or layout.

## Scope
First pass only:

* Keep the existing C++/WASM ImGui terminal unchanged unless a visual layering issue requires a small adjustment.
* Implement the effect in `web/index.html` using CSS and a small JavaScript scheduler.
* Reuse `web/assets/motoko.png` as the base visual asset.
* Avoid WebGL shaders, generated video, or large new binary assets in this pass.

## Visual System

### Layers
1. **Base Background**
   * Keep the current full-viewport Motoko image.
   * Preserve the dark gradient treatment so text and the ImGui window stay readable.

2. **RGB Split Layers**
   * Add duplicate pseudo-elements or absolutely positioned layers that reuse the background image.
   * Tint or blend them cyan/red.
   * During glitch bursts, offset them by a few pixels in opposite directions.

3. **Horizontal Slice Distortion**
   * Add 3-6 thin horizontal glitch bands.
   * Each band should briefly translate left/right during a burst.
   * Use `clip-path`, `transform`, and opacity rather than canvas drawing.

4. **Scanline / Noise Overlay**
   * Keep scanlines subtle in the normal state.
   * Intensify them only during glitch bursts.
   * Add very light grain/noise with CSS gradients if it remains cheap and readable.

5. **Telemetry Overlay**
   * Add small, sparse HUD text around the edges: model ID fragments, extension names, tick counters, checksum-like strings.
   * Keep this text decorative and non-essential.
   * Do not let it collide with the brand block, GitHub link, loading badge, or ImGui terminal.

6. **Brand Text Distortion**
   * Add a brief flicker/skew to the Motoko title during bursts.
   * Keep the title readable at all times.

## Motion Rules
* The default state should be mostly stable.
* Trigger a glitch burst every 2-5 seconds with randomized timing.
* Each burst should last about 120-300 ms.
* Bursts can contain 2-4 rapid substeps, but avoid constant jitter.
* Do not animate layout-affecting properties. Prefer `transform`, `opacity`, and CSS variables.
* Respect `prefers-reduced-motion: reduce` by disabling scheduled bursts and leaving only static overlays.

## Implementation Steps

### Phase 1: CSS Structure
1. Add a `.glitch-stage` layer behind the existing `.brand` and canvas.
2. Move background-image styling from `body::before` into named child layers if that makes animation easier.
3. Define CSS custom properties for offsets, opacity, slice positions, and burst intensity.
4. Ensure z-index order remains:
   * background and glitch layers;
   * canvas;
   * brand/link overlay;
   * loading/status badge.

### Phase 2: Burst Scheduler
1. Add a small script that toggles a `data-glitch="on"` attribute on `document.body`.
2. Randomize:
   * next burst delay;
   * burst duration;
   * RGB split offset;
   * slice offset values;
   * scanline intensity.
3. Use `setTimeout`, not a per-frame loop.
4. Disable the scheduler when `prefers-reduced-motion` is active.

### Phase 3: Telemetry
1. Add a few absolutely positioned decorative text groups.
2. Content examples:
   * `model.openai/google/gemma-4-26b-A4B-it`
   * `ext.context_mode // ext.exa_search // ext.omnigraph`
   * `runtime.step=0007`
   * `hash: 7f3a:motoko:self-verify`
3. Randomly pulse one telemetry group during a glitch burst.
4. Keep font sizes small and clamp them for mobile.

### Phase 4: Responsive Pass
1. Check desktop, tablet, and mobile widths.
2. Ensure the ImGui terminal remains visually dominant and draggable.
3. Ensure the GitHub link is still clickable.
4. Reduce or hide telemetry on narrow screens if it competes with the main content.

### Phase 5: Verification
1. Run `make web`.
2. Run `make serve`.
3. Verify in a Chromium-based browser:
   * page loads without console errors;
   * WASM terminal still initializes;
   * glitch bursts occur but do not run constantly;
   * text remains readable during and after bursts;
   * reduced-motion mode disables bursts;
   * mobile viewport does not overlap important UI.

## Non-Goals
* Do not add a full WebGL shader pipeline in this pass.
* Do not replace the ImGui terminal with HTML.
* Do not add audio.
* Do not introduce a large video background.
* Do not make the page visually dominated by a single neon color.

## Future Options
If the CSS/JS pass works but needs more depth, evaluate:

* a small WebGL background shader for displacement and chromatic aberration;
* a pre-rendered looping WebM derived from `motoko.png`;
* data-driven telemetry sourced from real `.motoko/logfile/` sessions;
* synchronized glitches when new log lines appear in the ImGui terminal.
