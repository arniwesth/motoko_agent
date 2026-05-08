---
doc_type: short
full_text: sources/TUI_OM_Command_Patterns.md
---

# Adopt oh-my-pi Command Patterns for AILANG TUI

## Overview

This document outlines a lightweight integration of two patterns from oh-my-pi into the AILANG Agent TUI (`tui/`): replacing the `Input` component with `Editor` (which supports autocomplete) and introducing a declarative slash-command registry to replace the ad‑hoc `handleCommand` switch. The upgrade enables tab‑completion, fuzzy matching, and a maintainable command structure without introducing any coupling to oh-my-pi’s session, auth, or provider infrastructure.

## Key Changes

- **Command Registry**: A `SlashCommand` interface and `BUILTIN_SLASH_COMMANDS` array define commands (`/model`, `/abort`) with argument completions, inline hints, and execution logic. This pattern is inspired by om’s architecture but simplified for AILANG’s yolo‑only mode. See [[concepts/slash-command-registry]].
- **Editor Component**: Swapping `Input` for `Editor` (from `@mariozechner/pi-tui`) gives native autocomplete via `setAutocompleteProvider`, handling tab‑complete for command names and subcommand arguments. Related to [[concepts/terminal-autocomplete]] and [[concepts/pi-tui-editor-integration]].
- **Dispatch Wiring**: The `parseSlashCommand` function dispatches recognised commands to the registry; unknown commands result in an error message. The UI’s `brain` reference is set externally to enable `/abort` functionality.

## Phase Breakdown

1. **Slash-Command Registry** (`tui/src/commands.ts`): Defines the `SlashCommand` interface, built‑in commands, a parser, and an autocomplete provider factory. Provides completion for model names and subcommand arguments.
2. **Replace Input with Editor** (`tui/src/ui.ts`): Swaps the component, wires the autocomplete provider, and adjusts the submit handler.
3. **Wire Command Dispatch** (`tui/src/ui.ts` and `tui/src/index.ts`): Replaces the switch‑based `handleCommand` with a registry dispatch; adds a `brain` property for lifecycle management.
4. **Update Plan Document**: Amends the AILANG Agent plan to reflect the new file and component, updating structure and success criteria.

## Impact

- Tab‑complete works for `/model`, `/abort`, and subcommand arguments.
- The command system becomes declarative, making it easier to add future commands.
- No new external dependencies; uses only existing `pi-tui` exports.
- Effort is within the existing Phase 2c budget (~0.5 days).

## Related Concepts
- [[concepts/terminal-ui-testing]]
- [[concepts/yolo-execution-mode]]
- [[concepts/dynamic-model-discovery]]

- [[concepts/slash-command-registry]] – Declarative pattern for terminal command handling.
- [[concepts/terminal-autocomplete]] – Providing tab‑completion in TUIs.
- [[concepts/pi-tui-editor-integration]] – Using the Editor widget from the pi-tui library.
- [[summaries/AILANG_Agent.md]] – The overall AILANG Agent plan that this document amends.