---
doc_type: short
full_text: sources/ailang_csp_implementation.md
---

**Source:** ailang_csp_implementation

This document collects practical rules discovered during Ailang development, organized as memorable principles.

### Namespace & Import Hierarchy
- **Rule: Discovery First.** Always use `ailang docs <module>` to confirm exact export paths for functions and associated ADTs. Types like `StreamEvent` may reside in sub-modules (`std/stream/events`) and are not imported via the primary module.
- See also: [[concepts/import_path_verification]]

### Module-to-Path Strictness
- **Rule: The Path-Identity Law.** The `module <path>` declaration must exactly mirror the file system path from the project root. For `src/examples/demo.ail`, the module is `src/examples/demo`.
- Error `MOD010` indicates mismatch; this rule eliminates it.
- See also: [[concepts/module_path_identity]]

### Syntax: Block vs Expression Style
- **Mnemonic:** See `{` → use `;`. See `=` → use `in`.
- Inside `{ }` blocks, sequence statements with semicolons; never use `in`.
- With `=` bodies, use `in` for binding.
- In complex blocks (e.g., `main`), ensure each step ends with `;` when part of a sequence.
- See also: [[concepts/syntax_rules_blocks]]

### Effect Verification
- **Rule: Exhaustive Effect Mapping.** When composing asynchronous sources (subprocesses) with I/O, the effect signature must include the union of all involved effects (e.g., `! {Stream, Process, IO}`).
- See also: [[concepts/effect_composition]]

These lessons promote a disciplined workflow: check imports, align module paths, obey block syntax, and verify effects to avoid common compilation errors.