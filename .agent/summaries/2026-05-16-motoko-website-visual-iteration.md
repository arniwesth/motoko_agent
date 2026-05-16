# Motoko Website Visual Iteration

Date: 2026-05-16

This session iterated on the Motoko website hero experience in `web/`, focusing on a cyberpunk-style animated background, a real TUI-like console overlay, and responsive layout behavior.

## Current State

- The website uses the new background asset `web/assets/motoko2.png`.
- The console is still positioned on the right/bottom area and remains draggable.
- The background image is shifted left without changing its scale by translating the background layers with `--bg-shift-x` in `web/index.html`.
- The current shift is `--bg-shift-x: -14vw`, after `-10vw` was judged to be the better approach but not far enough left.
- The previous zoom/background-size positioning attempt was reverted.
- No WASM rebuild is needed for this latest background-positioning change because it is CSS-only.

## Visual Effects

- Random rectangular glitch patches appear over parts of the background.
- Patch glitches flicker rapidly while active, jitter side to side, and use RGB channel offsets.
- A rarer full-screen glitch still appears roughly every 10 seconds.
- Glitch patches use `motoko2.png` and retain viewport-based sizing so their sampling stays aligned with the page effect.
- Reduced-motion mode disables the background shift and most animated glitch behavior.

## Console

- The console renders a real log replay from `web/assets/motoko.log`, derived from `.motoko/logfile/session_2026-05-13T20-46-36-617Z.md`.
- The log text loops after reaching the end.
- The console keeps a TUI-inspired look based on the reference screenshot `web/Screenshot 2026-05-14 at 19.15.05.png`.
- Text inside backticks is highlighted.
- Console sizing adapts to screen width for mobile.
- Console dragging was restored after an earlier positioning change accidentally made it feel fixed.

## Important Files

- `web/index.html`: background, glitch layers, telemetry/noise effects, loader, CSS tuning.
- `src/main.cpp`: Dear ImGui console rendering, responsive size and position, log replay, wrapping, highlighting, draggable window behavior.
- `web/assets/motoko2.png`: current background image.
- `web/assets/motoko.log`: replayed website console log.
- `.agent/plans/Motoko_website_visuals.md`: visual effects plan.
- `.agent/plans/Motoko_website_improvements.md`: follow-up improvement ideas.

## Notes For Next Iteration

- If the face still needs to move further left, tune only `--bg-shift-x` in `web/index.html`.
- More negative values move the background left; less negative values move it back right.
- Avoid changing `background-size` for this adjustment, because that caused the image to look zoomed.
- If exposed empty space appears at the right edge, the long-term fix is a wider/aligned background asset rather than scaling the image.
