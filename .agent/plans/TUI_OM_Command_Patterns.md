# AILANG TUI: Adopt oh-my-pi Command Patterns

## Goal

Adopt two portable patterns from oh-my-pi into the AILANG Agent TypeScript frontend (tui/):
1. Replace `Input` with `Editor` component for slash-command autocomplete
2. Introduce a declarative slash-command registry to replace the ad-hoc `handleCommand` switch

This upgrades the om UX — tab-complete of `/model`, `/abort`, fuzzy matching — at near-zero integration cost and zero coupling to om's session/auth/provider stack.

## Non-goals

- Do NOT pull in any om package beyond what pi-tui already provides
- Do NOT integrate om's `AgentSession`, `ModelRegistry`, MCP, LSP, or auth infrastructure
- Do NOT implement om commands that don't apply to yolo-only mode (plan, mcp, ssh, browser, oauth, etc.)
- Do NOT change the JSONL protocol, brain modules, or env-server

## Constraints

- `@mariozechner/pi-tui@0.64.0` is already installed in tui/
- pi-tui exports `Editor` (with autocomplete), `SlashCommand`, `AutocompleteItem`, `AutocompleteProvider`
- The plan in `.agent/plans/AILANG_Agent.md` defines the current tui/ structure — this plan amends phases 2c only
- AILANG is always yolo — no confirm/reject, no plan mode, no human-in-the-loop

---

## Phase 1 — Slash-Command Registry (`tui/src/commands.ts`)

### What to add

A declarative command registry pattern lifted from om's architecture, simplified to AILANG's surface:

```typescript
// tui/src/commands.ts

import type { AutocompleteItem } from "@mariozechner/pi-tui";
import type { Brain } from "./brain.js";
import type { AgentUI } from "./ui.js";

/** Lightweight slash-command definition, modelled after om's pattern. */
export interface SlashCommand {
  name: string;
  description?: string;
  /** Subcommand names for dropdown completion, e.g. "on" / "off" for /fast. */
  subcommands?: string[];
  /** Called when user submits the command. Mutates UI / sends to brain. */
  execute(args: string, ctx: CommandContext): void | Promise<void>;
  /** Returns autocomplete items when user types past the command name. */
  getArgumentCompletions?: (prefix: string) => AutocompleteItem[] | null;
  /** Inline hint text shown after cursor, e.g. "[on|off]". */
  getInlineHint?: (argumentText: string) => string | null;
}

export interface CommandContext {
  ui: AgentUI;
  brain: Brain | undefined;  // undefined after brain exits
}

// --- builtin commands ------------------------------------------------

export const BUILTIN_SLASH_COMMANDS: SlashCommand[] = [
  {
    name: "model",
    description: "Switch model (opens picker; /model <name> skips picker)",
    getArgumentCompletions(prefix) {
      const known = getKnownModels();  // from models.ts
      const lower = prefix.toLowerCase();
      const matches = known.filter(m => m.toLowerCase().startsWith(lower));
      if (matches.length === 0) return null;
      return matches.map(m => ({ value: m + " ", label: m, description: m }));
    },
    getInlineHint(argText) {
      return argText.trim().length === 0 ? "[provider/model]" : null;
    },
    async execute(args, ctx) {
      if (args.trim()) {
        // Direct: /model anthropic/claude-sonnet-4-6
        (ctx.ui as any).switchModel(args.trim());
      } else {
        // Open picker overlay
        (ctx.ui as any).showModelPicker();
      }
    },
  },
  {
    name: "abort",
    aliases: ["quit"] as string[],  // handled by parse
    description: "Stop the brain (Ctrl+C equivalent)",
    execute(_args, ctx) {
      ctx.brain?.abort();
      ctx.ui.addStatusText("Aborted");
    },
  },
];

/** Parse a slash-command line: returns the matching command + args, or null. */
export function parseSlashCommand(line: string): { cmd: SlashCommand; args: string } | null {
  if (!line.startsWith("/")) return null;
  const trimmed = line.slice(1).trim();
  const spaceIdx = trimmed.search(/\s/);
  const name = spaceIdx === -1 ? trimmed : trimmed.slice(0, spaceIdx);
  const args = spaceIdx === -1 ? "" : trimmed.slice(spaceIdx).trim();
  const match = BUILTIN_SLASH_COMMANDS.find(c => c.name === name);
  if (!match) return null;
  return { cmd: match, args };
}

/** Autocomplete provider wired into Editor. */
export function createAutocompleteProvider(
  commands: SlashCommand[],
): (prefix: string) => AutocompleteItem[] | null {
  return (prefix: string) => {
    if (!prefix.startsWith("/")) return null;
    const body = prefix.slice(1);
    const spaceIdx = body.search(/\s/);

    if (spaceIdx === -1) {
      // Filtering command names
      const lower = body.toLowerCase();
      const matches = commands.filter(c => c.name.startsWith(lower));
      if (matches.length === 0) return null;
      return matches.map(c => ({
        value: "/" + c.name + " ",
        label: "/" + c.name,
        description: c.description,
      }));
    }

    // Filtering subcommand arguments
    const cmdName = body.slice(0, spaceIdx);
    const argPrefix = body.slice(spaceIdx + 1);
    const cmd = commands.find(c => c.name === cmdName);
    if (!cmd?.getArgumentCompletions) return null;
    return cmd.getArgumentCompletions(argPrefix);
  };
}
```

### Acceptance

- `parseSlashCommand` correctly splits `/model anthropic/claude-sonnet-4-6` → `{ name: "model", args: "anthropic/claude-sonnet-4-6" }`
- `createAutocompleteProvider` returns `[{ label: "/model", value: "/model ", description: "…" }, { label: "/abort", value: "/abort ", … }]` when prefix is `/`
- Unknown commands return `null` (falls through to passthrough)

---

## Phase 2 — Replace `Input` with `Editor` in `ui.ts`

### What changes

The current plan (`AILANG_Agent.md` §4.4) uses `Input` from pi-tui with a manual `onSubmit` handler. `Editor` supports autocomplete natively via `setAutocompleteProvider()`. The swap is surgical:

```diff
- import { TUI, Text, Markdown, Input, Box, SelectList } from "@mariozechner/pi-tui";
+ import { TUI, Text, Markdown, Editor, Box, SelectList } from "@mariozechner/pi-tui";

  // In AgentUI constructor:
- this.cmdInput  = new Input({ placeholder: "/model  /abort" });
+ this.editor = new Editor({ /* theme: minimal, single-line-ish */ });
+ this.editor.setAutocompleteProvider(createAutocompleteProvider(BUILTIN_SLASH_COMMANDS));
+ this.editor.onSubmit = (value: string) => { ... };
```

### Editor vs Input decision

| | Input | Editor |
|---|---|---|
| Autocomplete | No | Yes (setAutocompleteProvider) |
| Slash-complete | Manual | Native |
| Multi-line | No | Yes (acceptable — user can still enter single line) |
| History | No | Optional |
| Overhead | Light | Marginally heavier (negligible for single user) |

The plan document already budgets `1–2 days` for ui.ts. This change is a 2-hour swap within that budget.

### Acceptance

- Typing `/` in the input shows `/model` and `/abort` as completions
- Typing `/model ` filters to `anthropic/claude-sonnet-4-6`, etc.
- Tab selects a completion
- Enter submits the full line to `handleCommand`

---

## Phase 3 — Wire Command Dispatch in `ui.ts`

### What changes

Replace the ad-hoc `handleCommand(value: string)` switch with the registry:

```typescript
handleCommand(line: string) {
  const parsed = parseSlashCommand(line);
  if (parsed) {
    parsed.cmd.execute(parsed.args, { ui: this, brain: this.brain });
    this.tui.requestRender();
    return;
  }
  // Unknown slash command — passthrough as error
  this.history.addChild(new Text(`Unknown command: ${line}`, { dim: true, color: "red" }));
  this.tui.requestRender();
}
```

Additionally, `ui.ts` gains a `brain: Brain | undefined` property. `index.ts` sets it after spawning the brain, and clears it on exit.

### Acceptance

- `/model` → opens picker (existing behavior, now via registry)
- `/model openai/gpt-4o` → direct switch (existing behavior)
- `/abort` → calls `brain.abort()` (existing behavior)
- `/unknown` → renders error message

---

## Phase 4 — Update Plan Document

### What changes

Amend `.agent/plans/AILANG_Agent.md` to reflect the new file and component:

| Section | Old | New |
|---|---|---|
| §4.1 Project structure | `src/ui.ts` | `src/ui.ts`, `src/commands.ts` |
| §4.4 ui.ts | `Input` | `Editor` with `setAutocompleteProvider` |
| §4.6 index.ts | `ui.onModelChange` + `ui.onAbort` | `ui.brain = brain` + registry dispatch |
| §9 Success criteria | `/model` opens picker | `/model` shows autocomplete on `/`, tab-complete works |

---

## Impact Summary

| Area | Before | After |
|---|---|---|
| Command system | Ad-hoc switch in `handleCommand` | Declarative `SlashCommand[]` registry |
| Input component | `Input` | `Editor` with autocomplete |
| Tab-complete | Not available | `/model`, `/abort`, subcommand args |
| Coupling to om | Zero | Zero (uses only pi-tui types) |
| New files | None | `tui/src/commands.ts` (~80 lines) |
| Modified files | — | `tui/src/ui.ts`, `tui/src/index.ts` |
| Effort | — | ~0.5 days (within existing Phase 2c budget) |
