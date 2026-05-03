// tui/src/commands.ts
//
// Declarative slash-command registry for the Motoko TUI.
//
// Modelled on oh-my-pi's pattern ({ name, description, handle }) but
// deliberately decoupled from om's AgentSession / ModelRegistry / MCP stack.
// The only dependency is pi-tui types, already listed in tui/package.json.
//
// Builtin commands: /model (pick or direct-switch) and /abort (stop runtime process).
// Additional commands can be appended to BUILTIN_SLASH_COMMANDS at runtime.

import type {
  AutocompleteItem,
  AutocompleteProvider,
  AutocompleteSuggestions,
  SlashCommand as PiCommand,
} from "@mariozechner/pi-tui";
import type { RuntimeProcess } from "./runtime-process.js";
import type { AgentUI } from "./ui.js";
import {
  fetchDynamicModelsFromEnv,
} from "./models.js";

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface SlashCommandHandlerCtx {
  /** Top-level AgentUI instance (for switchModel, addHistoryText, etc.). */
  ui: AgentUI;
  /** The AILANG runtime process, or undefined once it has exited. */
  runtimeProcess: RuntimeProcess | undefined;
}

/**
 * Lightweight command descriptor.
 *
 * Extends pi-tui's SlashCommand with an `execute` callback so the registry
 * can dispatch without requiring a switch statement in ui.ts.
 */
export interface SlashCommand extends PiCommand {
  /** Called when the user submits a line matching this command. */
  execute(args: string, ctx: SlashCommandHandlerCtx): void | Promise<void>;
}

// ---------------------------------------------------------------------------
// Command: /model
// ---------------------------------------------------------------------------

const modelCommand: SlashCommand = {
  name: "model",
  description: "Switch model (opens picker; /model <name> skips picker)",

  execute(args: string, ctx: SlashCommandHandlerCtx) {
    if (args.trim().length > 0) {
      ctx.ui.switchModel(args.trim());
    } else {
      ctx.ui.showModelPicker();
    }
  },
};

// ---------------------------------------------------------------------------
// Command: /abort
// ---------------------------------------------------------------------------

const abortCommand: SlashCommand = {
  name: "abort",
  description: "Stop the runtime process (Ctrl+C equivalent)",

  execute(_args: string, ctx: SlashCommandHandlerCtx) {
    ctx.runtimeProcess?.abort();
    ctx.ui.addHistoryText("Aborted", "dim");
  },
};

// ---------------------------------------------------------------------------
// Public registry
// ---------------------------------------------------------------------------

export const BUILTIN_SLASH_COMMANDS: SlashCommand[] = [modelCommand, abortCommand];

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

/**
 * Given a raw input line, return the matching builtin command + args or null.
 * Handles /name and /name <args...>.  Aliases are not supported yet; the plan
 * only lists /model and /abort so there is no ambiguity.
 */
export function parseSlashCommand(
  line: string,
): { cmd: SlashCommand; args: string } | null {
  if (!line.startsWith("/")) return null;
  const body = line.slice(1).trim();
  if (!body) return null;

  const spaceIdx = body.search(/\s/);
  const name = spaceIdx === -1 ? body : body.slice(0, spaceIdx);
  const args = spaceIdx === -1 ? "" : body.slice(spaceIdx).trim();

  const match = BUILTIN_SLASH_COMMANDS.find((c) => c.name === name);
  if (!match) return null;
  return { cmd: match, args };
}

// ---------------------------------------------------------------------------
// Autocomplete provider (wired into pi-tui Editor)
// ---------------------------------------------------------------------------

/**
 * Returns an AutocompleteProvider compatible with Editor.setAutocompleteProvider().
 *
 * Behaviour:
 *   - Line starts with "/" and no space yet → suggest command names from the registry
 *   - "/model <prefix>" → filter known + dynamically discovered models
 *   - Everything else → null (no autocomplete)
 */
export function createCommandAutocompleteProvider(): AutocompleteProvider {
  // Cached model list — resolved lazily when /model autocomplete fires.
  let cachedModels: string[] | null = null;
  let modelFetch: Promise<string[]> | null = null;

  const getAllModels = async (): Promise<string[]> => {
    if (cachedModels) return cachedModels;
    if (modelFetch) return modelFetch;

    modelFetch = (async () => {
      cachedModels = await fetchDynamicModelsFromEnv();
      return cachedModels!;
    })();
    return modelFetch;
  };

  return {
    async getSuggestions(
      lines: string[],
      cursorLine: number,
      cursorCol: number,
      options: { signal: AbortSignal; force?: boolean },
    ): Promise<AutocompleteSuggestions | null> {
      if (options.signal.aborted) return null;
      const line = lines[cursorLine] ?? "";
      const prefix = line.slice(0, cursorCol);
      if (!prefix.startsWith("/")) return null;

      const body = prefix.slice(1);
      const spaceIdx = body.search(/\s/);

      // Case 1: filtering command names — no space yet
      if (spaceIdx === -1) {
        const lower = body.toLowerCase();
        const matches = BUILTIN_SLASH_COMMANDS.filter((c) =>
          c.name.startsWith(lower),
        );
        if (matches.length === 0) return null;
        return {
          prefix: body,
          items: matches.map((c) => ({
            value: c.name,
            label: "/" + c.name,
            description: c.description,
          })),
        };
      }

      // Case 2: filtering arguments after a known subcommand
      const cmdName = body.slice(0, spaceIdx);
      if (cmdName === "model") {
        const argPrefix = body.slice(spaceIdx + 1);
        const allModels = await getAllModels();
        const lower = argPrefix.toLowerCase();
        const matches = allModels.filter((m) => m.toLowerCase().includes(lower));
        if (matches.length === 0) return null;
        return {
          prefix: argPrefix,
          items: matches.map((m) => ({
            value: m,
            label: m,
            description: m,
          })),
        };
      }

      // Case 3: unknown command or no argument completions
      return null;
    },

    /**
     * Insert the chosen item by replacing the current prefix segment.
     *
     * For command names: replace from the start of "/..." to cursor.
     * For /model subarguments: replace the last word-like segment after "/model ".
     */
    applyCompletion(
      lines: string[],
      cursorLine: number,
      cursorCol: number,
      item: AutocompleteItem,
      prefix: string,
    ): { lines: string[]; cursorLine: number; cursorCol: number } {
      const line = lines[cursorLine] ?? "";
      const before = line.slice(0, cursorCol - prefix.length);
      const after = line.slice(cursorCol);
      const newLine = before + item.value + after;
      const newLines = [...lines];
      newLines[cursorLine] = newLine;

      return {
        lines: newLines,
        cursorLine,
        cursorCol: cursorCol - prefix.length + item.value.length,
      };
    },
  };
}
