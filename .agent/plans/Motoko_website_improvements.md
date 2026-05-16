# Improvement Plan: Motoko Website Polish

## Objective
Improve the Motoko promo site from a cool visual demo into a more convincing product experience while preserving the current C++/WASM + ImGui direction.

The current site already has:

* a branded visual background;
* randomized glitch effects;
* a draggable ImGui console;
* a real Motoko session log replay;
* responsive console sizing.

This plan lists additive improvements. Each item should be implemented independently and verified before moving to the next.

## Priority Ideas

### 1. Curated Replay Mode
Use a sharper replay instead of dumping one raw session end to end.

Options:

* Trim the current real log to the most interesting sections.
* Stitch together selected excerpts from multiple real `.motoko/logfile/*.md` sessions.
* Keep timestamps and authentic wording where possible.

Desired story arc:

1. user gives a task;
2. Motoko reasons;
3. Motoko calls tools/extensions;
4. a tool fails or returns a diagnostic;
5. Motoko recovers;
6. final state is successful or idle.

Implementation notes:

* Generate a new `web/assets/motoko.log` from curated source material.
* Keep it ASCII-only unless the ImGui font is upgraded.
* Keep the log compact enough to loop cleanly.

### 2. Log Speed Auto-Rhythm
Replace constant line speed with replay pacing based on line type.

Suggested pacing:

* user prompts: fast;
* short status lines: medium;
* reasoning lines: slightly slower;
* tool/result bursts: fast;
* blank lines and Markdown headings: tiny pause;
* failures: short pause after display;
* final/idle state: longer pause before loop restart.

Implementation notes:

* Add a `delay_for_line(line)` helper in `src/main.cpp`.
* Replace the current fixed `lines_per_second` timer with per-line accumulated delay.
* Keep the speed slider as a multiplier.

### 3. Event Pulses
Connect console activity to subtle visual feedback.

Examples:

* `[failed]` / `[FAIL]` / `[ERROR]`: brief red border pulse on the console.
* `[done]` / `[PASS]` / `[OK]`: brief green border pulse.
* user prompt lines: brief cyan pulse.
* major tool/result lines: minor scanline intensity bump.

Implementation notes:

* Store a `pulse_kind` and `pulse_timer` in the C++ app state.
* When a newly revealed line matches a category, trigger the pulse.
* Apply pulse colors through ImGui style colors or a thin custom overlay.
* Keep text stable; do not glitch the console contents.

### 4. Console Mode Switcher
Add small ImGui tabs to make the terminal feel deeper.

Potential tabs:

* `session`: current replay log.
* `tools`: static list of active tools/extensions.
* `extensions`: `context_mode`, `exa_search`, `omnigraph`, etc.
* `system`: model, runtime, profile, replay state.

Implementation notes:

* Use `ImGui::BeginTabBar` / `ImGui::BeginTabItem`.
* Keep `session` as the default active tab.
* Static tabs can be simple text tables at first.

### 5. Live Status Strip
Add a TUI-like status line at the bottom of the console.

Example:

```text
model=openrouter/deepseek-v4-flash | ext=context_mode, exa_search | replay=loop | state=streaming
```

Implementation notes:

* Render below the log child or as a fixed footer inside the ImGui window.
* Keep it dim gray with cyan highlights.
* Update `state=streaming`, `state=paused`, and `state=idle`.

### 6. Mobile Composition Pass
Improve the mobile hero beyond basic responsive sizing.

Goals:

* Motoko brand remains visible on first load.
* Console occupies the lower half cleanly.
* GitHub/repo link remains tappable.
* Decorative telemetry does not compete with the console.
* Glitch patches do not obscure the main subject too often on narrow screens.

Implementation notes:

* Tune CSS media queries in `web/index.html`.
* Tune ImGui phone layout in `src/main.cpp`.
* Test portrait and landscape mobile viewport sizes.

### 7. Native-Feeling Repo CTA
Replace or augment the current GitHub pill with a terminal-like command.

Example:

```text
git clone github.com/sunholo-data/motoko_agent
```

Implementation notes:

* Keep the element as a real HTML link.
* Style it as terminal text rather than a marketing button.
* Ensure it remains accessible and focus-visible.

### 8. Keyboard Shortcuts
Make the demo feel more tool-like.

Suggested shortcuts:

* `Space`: pause/resume replay.
* `r`: restart replay.
* `+`: increase replay speed.
* `-`: decrease replay speed.

Implementation notes:

* Handle shortcuts in the C++ event callback.
* Avoid stealing browser/system shortcuts.
* Keep shortcuts optional; do not add visible instruction text unless a compact tooltip/menu exists.

## Recommended Next Step
Start with:

1. **Log Speed Auto-Rhythm**
2. **Event Pulses**

These are high-impact because they make the console feel alive without changing the site architecture or adding new assets.

## Verification Checklist
For each improvement:

* Run `make web`.
* Run `make serve`.
* Verify the WASM runtime loads.
* Verify the console remains draggable.
* Verify mobile viewport layout.
* Verify reduced-motion mode still suppresses scheduled glitch bursts.
* Confirm console text remains readable and stable.
