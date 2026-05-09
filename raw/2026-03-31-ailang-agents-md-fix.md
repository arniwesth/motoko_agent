# AGENTS.md Loading Bug Fix

## Overview
Fixed critical bugs in the `swe/agents_md.ail` module that prevented AGENTS.md file discovery and loading from working correctly.

## Problems Identified

### 1. Placeholder Assignments (Critical)
Lines 47-48 contained non-functional placeholder code:
```ailang
let last_slash = last_slash;  // Never computed
let has_agents = has_agents;  // Never computed
let parent = parent;          // Never computed
```
These were never replaced with actual implementations.

### 2. Incorrect Function Syntax
Multiple functions used `=` syntax for multi-statement bodies:
```ailang
// Wrong - cannot have multiple statements after =
func dirname(path: string) -> string =
  let clean = ...;
  let last_slash = ...;
  ...

// Correct - use {} blocks
func dirname(path: string) -> string {
  let clean = ...;
  let last_slash = ...;
  ...
}
```
Affected functions: `dirname`, `walk_agents`, `load_agents_recursive`, `with_agents_context`

### 3. Import Conflict: `length` Function
Both `std/string` and `std/list` export a `length` function:
- `std/string.length(s: string) -> int`
- `std/list.length[a](xs: [a]) -> int` (polymorphic)

Importing `length` from `std/string` shadowed the polymorphic list version, causing type errors when used on lists.

**Fix:** Import both with disambiguation:
```ailang
import std/string (..., length as str_length)
import std/list (..., length)
```

Then use `str_length` for strings and `length` for lists.

### 4. Missing Effect Annotations
Functions that call `load_agents_content` (which requires `FS` effect) were missing the effect declaration:
- `swe/agents_md.ail:with_agents_context` - added `! {FS}`
- `swe/prompts.ail:with_agents_context` - added `! {FS}`

### 5. Type Inference Issues with `foldlE`
The original implementation attempted to use `foldlE` for loading files:
```ailang
let formatted = foldlE(format_agent_file, "", agents_files);
```

This caused persistent type unification errors despite multiple attempts. Replaced with a simple recursive function:
```ailang
func load_agents_recursive(file_list: [string], acc: string) -> string ! {FS} {
  match file_list {
    [] => acc,
    [f, ...rest] => {
      let new_acc = acc ++ "\n## AGENTS.md: " ++ f ++ "\n" ++ readFile(f) ++ "\n```\n" ++ "\n";
      load_agents_recursive(rest, new_acc)
    }
  }
}
```

## Files Modified

### `/workspaces/ailang_agent/swe/agents_md.ail`
- Fixed all placeholder assignments with actual implementations
- Changed function syntax from `=` to `{}` for multi-statement bodies
- Fixed imports to disambiguate `length` functions
- Replaced `foldlE` with recursive `load_agents_recursive`
- Added `! {FS}` effect to `with_agents_context`

### `/workspaces/ailang_agent/swe/prompts.ail`
- Added `! {FS}` effect to `with_agents_context` function signature

## Verification

All modules now compile successfully:
```
✓ No errors found in swe/agents_md.ail
✓ No errors found in swe/prompts.ail
✓ No errors found in swe/rpc.ail
```

## Functionality

The fixed implementation:
1. **Discovers AGENTS.md files** by walking up the directory tree from a given working directory
2. **Collects files in root-first order** (root-most to closest to working directory)
3. **Loads and formats content** with headers showing file paths
4. **Integrates with system prompts** via `with_agents_context` in `swe/prompts.ail`
5. **Handles missing files gracefully** - returns empty string if no AGENTS.md found

## Usage

```ailang
import swe/prompts (base_system, with_agents_context)

let system = base_system("/path/to/workdir");
let system_with_agents = with_agents_context(system, "/path/to/workdir");
```

The `with_agents_context` function automatically discovers and loads all AGENTS.md files from the working directory upward, injecting their content into the system prompt.
