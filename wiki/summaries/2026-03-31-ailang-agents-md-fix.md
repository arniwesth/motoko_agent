---
doc_type: short
full_text: sources/2026-03-31-ailang-agents-md-fix.md
---

# AGENTS.md Loading Bug Fix Summary

## Overview
This document describes bug fixes in the `swe/agents_md.ail` module of the Ailang agent workspace. The bugs prevented proper discovery, loading, and formatting of AGENTS.md files, breaking the system prompt integration. The fixes address placeholder code, syntax errors, import conflicts, missing effect annotations, and type inference limitations.

## Problems Identified

### 1. Placeholder assignments
Non-functional placeholder code (`let last_slash = last_slash;`, etc.) was replaced with actual implementations that correctly compute directory traversal and file existence checks.

### 2. Incorrect function syntax
Multi‑statement function bodies used `=` instead of `{}`, leading to parse errors. All affected functions (`dirname`, `walk_agents`, `load_agents_recursive`, `with_agents_context`) were converted to block syntax.

### 3. Import conflict: `length`
`std/string.length` and `std/list.length` collided, shadowing the polymorphic list version. Resolution used import disambiguation (`length as str_length`) to preserve both.

### 4. Missing effect annotations
`with_agents_context` in both `swe/agents_md.ail` and `swe/prompts.ail` calls `load_agents_content`, which requires the `FS` effect. Declared `! {FS}` on these functions.

### 5. Type inference with `foldlE`
The original `foldlE` attempt caused persistent type unification issues. Replaced with a simple recursive function (`load_agents_recursive`) that iterates over the file list using pattern matching, eliminating the inference problem.

## Solutions Applied

- Implemented correct directory walking logic ([[concepts/ailang-directory-traversal]])
- Standardised function syntax using blocks ([[concepts/ailang-function-syntax]])
- Resolved import conflicts via explicit renaming ([[concepts/import-disambiguation]])
- Added needed effect annotations ([[concepts/effect-annotations]])
- Rewrote collection logic with a recursive helper instead of a higher‑order fold ([[concepts/recursive-alternative]])

## Files Modified
- `swe/agents_md.ail`: fixed all placeholder, syntax, import, effect, and recursion issues.
- `swe/prompts.ail`: added `! {FS}` effect declaration.

## Result
All modules now compile cleanly. The fixed AGENTS.md loader correctly walks up the directory tree from a working directory, collects files in root‑first order, reads and formats their contents, and injects them into the system prompt via `with_agents_context`.

## See Also
- [[concepts/ailang-module-system]] for imports and effect handling
- [[concepts/ailang-function-syntax]] for block vs expression‑only bodies
- [[concepts/import-disambiguation]] for alias techniques
- [[concepts/effect-annotations]] for explicit IO effects
- [[concepts/recursive-alternative]] for pattern‑matching recursion vs folds