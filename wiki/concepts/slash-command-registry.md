---
sources: [summaries/TUI_OM_Command_Patterns.md]
brief: Declarative registry pattern for slash commands with autocomplete in terminal UIs.
---

# Slash Command Registry

A **slash command registry** is a declarative, extensible pattern for managing slash-commands (e.g. `/model`, `/abort`) in a terminal user interface. Instead of encoding command behaviour in a hard-coded `switch` or `if/else` chain, each command is defined as an object in a central registry, enabling tab-completion, argument hints, and clean execution logic.

## Core Components

- **SlashCommand Interface**: Each command has a `name`, optional `description`, `subcommands`, an `execute(args, ctx)` method, optional `getArgumentCompletions(prefix)`, and optional `getInlineHint(argumentText)`.
- **Registry**: A typed array (e.g. `BUILTIN_SLASH_COMMANDS: SlashCommand[]`) holds all registered commands. This can be extended with plugin or system commands later.
- **Parser**: `parseSlashCommand(line)` splits an input line (starting with `/`) into a command name and arguments, then looks up the matching command in the registry.
- **Autocomplete Provider**: `createAutocompleteProvider(commands)` returns a function that, given a prefix, returns matching command names (if the cursor is before a space) or argument completions (if after a space and the command supports it).

## How It Works

1. When the user types `/`, the autocomplete provider filters the registry for commands starting with that prefix and shows labels/descriptions.
2. After selecting a command (e.g. `/model `), the provider delegates to the command’s `getArgumentCompletions` to show possible arguments like model names.
3. When the user submits the full line, `parseSlashCommand` resolves the command and arguments. The command’s `execute` method is called with the arguments and a `CommandContext` (which provides access to the UI and brain).
4. Commands can also supply an `inlineHint` to show a placeholder (e.g. `[provider/model]`).

## Benefits over Ad-Hoc Dispatch

- **Separation of Concerns**: Command logic lives with the command definition, not in a monolithic event handler.
- **Autocomplete Ready**: The registry directly powers tab-completion for command names and arguments, leveraging the `Editor` component’s `setAutocompleteProvider`.
- **Easily Extensible**: Adding a new slash command requires only a new entry in the array, not modifying dispatch logic.
- **Lightweight**: The pattern uses minimal abstraction, requiring only standard TypeScript interfaces and functions.

## Example from AILANG Agent TUI

In the AILANG TUI implementation (source document: [[summaries/TUI_OM_Command_Patterns]]), the registry is defined in `tui/src/commands.ts`. It provides two built-in commands:
- `/model` – opens a model picker or switches directly.
- `/abort` – stops the brain process.

The `Editor` component (from `@mariozechner/pi-tui`) is wired to an autocomplete provider built from this registry, enabling tab-completion of slash commands.

## Related Concepts

- [[concepts/terminal-autocomplete]] – The general problem of providing tab-completion in terminal UIs.
- [[concepts/pi-tui-editor-integration]] – Using the `Editor` widget from the `pi-tui` library to host the autocomplete-enabled command input.
- [[summaries/TUI_OM_Command_Patterns]] – The document describing the adoption of this pattern in the AILANG TUI.