# AILANG Implementation Lessons Learned

## 1. Namespace & Import Hierarchy
**Problem:** Attempting to import types (like `StreamEvent`) directly from a primary module when they reside in a sub-module (e.g., `std/stream/events`).
**Rule:** **Discovery First.** Always use `ailang docs <module>` to verify the exact export path for both functions and their associated types/ADTs. Do not assume types are available via the primary module.

## 2. Module-to-Path Strictness
**Problem:** `Error MOD010`: The `module` declaration did not match the physical file path.
**Rule:** **The Path-Identity Law.** The `module <path>` declaration is a physical address. It **MUST** strictly mirror the file system path from the project root. If the file is at `src/examples/demo.ail`, the module **MUST** be `src/examples/demo`.

## 3. Syntax: The Grammar of Blocks
**Problem:** Confusion between "Block Style" and "Expression Style" leading to parse errors.
**Rule:** **See `{` $\to$ use `;`. See `=` $\to$ use `in`.**
- **Inside `{ }` blocks:** Use semicolons (`;`) to sequence statements. Never use `in` inside a curly brace block.
- **With `=` bodies:** Use `in` for binding.
- **In `main` or complex blocks:** Ensure every discrete step (like `let` bindings or function calls) is terminated with a semicolon if it is part of a sequence.

## 4. Effect Verification
**Problem:** Miscalculating the required effect set for complex compositions (e.g., combining `Stream`, `Process`, and `IO`).
**Rule:** **Exhaustive Effect Mapping.** When combining asynchronous sources (subprocesses) with standard I/O, the effect signature must include the union of all involved effects (e.g., `! {Stream, Process, IO}`).
