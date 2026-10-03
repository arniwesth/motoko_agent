// TUI colour schemes, selected by the profile config's `theme` field (env
// MOTOKO_THEME). Unset means "pi": the ANSI-16 colours inherited from PI, which
// follow the terminal's own palette.
//
// pi-tui has no theme of its own — it takes styling callbacks and otherwise
// leaves text in the terminal's default colours. So a scheme is two things:
//   1. `theme`: the style for each colour role the UI uses, named after the
//      chalk colours the PI scheme uses for them so call sites read the same.
//   2. applyTerminalTheme(): for a truecolor scheme, sets the terminal's
//      default fg via OSC 10 for the session and restores it on exit, so
//      unstyled text matches too. The background stays the terminal's own.

import chalk, { type ChalkInstance } from "chalk";

export const THEME_NAMES = ["pi", "tokyo-night"] as const;
export type ThemeName = (typeof THEME_NAMES)[number];

type Role =
  | "dim" | "gray"
  | "red" | "redBright" | "green" | "greenBright" | "yellow" | "yellowBright"
  | "cyan" | "cyanBright" | "blueBright" | "magenta" | "magentaBright"
  | "diffAddBg" | "diffDelBg" | "errorBox";

type Scheme = {
  // Default foreground set on the terminal for the session; none keeps the user's.
  fg?: string;
  // Builders, not instances: chalk bakes its colour level into a builder when
  // it is created, so building at import time would freeze whatever level was
  // detected (or not yet set) at that moment.
  roles: Record<Role, () => ChalkInstance>;
};

const PI: Scheme = {
  roles: {
    dim: () => chalk.dim,
    gray: () => chalk.gray,
    red: () => chalk.red,
    redBright: () => chalk.redBright,
    green: () => chalk.green,
    greenBright: () => chalk.greenBright,
    yellow: () => chalk.yellow,
    yellowBright: () => chalk.yellowBright,
    cyan: () => chalk.cyan,
    cyanBright: () => chalk.cyanBright,
    blueBright: () => chalk.blueBright,
    magenta: () => chalk.magenta,
    magentaBright: () => chalk.magentaBright,
    diffAddBg: () => chalk.bgRgb(20, 64, 44),
    diffDelBg: () => chalk.bgRgb(72, 34, 34),
    errorBox: () => chalk.bgRgb(120, 0, 0).white,
  },
};

// Tokyo Night, "night" variant (https://github.com/folke/tokyonight.nvim).
export const TOKYO_NIGHT_PALETTE = {
  fg: "#c0caf5",
  muted: "#737aa2",
  comment: "#565f89",
  red: "#f7768e",
  brightRed: "#ff899d",
  orange: "#ff9e64",
  yellow: "#e0af68",
  green: "#9ece6a",
  brightGreen: "#b9f27c",
  teal: "#73daca",
  cyan: "#7dcfff",
  blue: "#7aa2f7",
  magenta: "#bb9af7",
  purple: "#9d7cd8",
  diffAddBg: "#20303b",
  diffDelBg: "#37222c",
  errorBg: "#5a1f2e",
} as const;

const TN = TOKYO_NIGHT_PALETTE;
const TOKYO_NIGHT: Scheme = {
  fg: TN.fg,
  roles: {
    // Secondary text. An explicit colour rather than the SGR "dim" attribute,
    // whose rendering varies widely between terminals.
    dim: () => chalk.hex(TN.muted),
    gray: () => chalk.hex(TN.comment),
    red: () => chalk.hex(TN.red),
    redBright: () => chalk.hex(TN.brightRed),
    green: () => chalk.hex(TN.green),
    greenBright: () => chalk.hex(TN.brightGreen),
    yellow: () => chalk.hex(TN.yellow),
    yellowBright: () => chalk.hex(TN.orange),
    cyan: () => chalk.hex(TN.teal),
    cyanBright: () => chalk.hex(TN.cyan),
    blueBright: () => chalk.hex(TN.blue),
    magenta: () => chalk.hex(TN.purple),
    magentaBright: () => chalk.hex(TN.magenta),
    diffAddBg: () => chalk.bgHex(TN.diffAddBg),
    diffDelBg: () => chalk.bgHex(TN.diffDelBg),
    errorBox: () => chalk.bgHex(TN.errorBg).hex(TN.fg),
  },
};

const SCHEMES: Record<ThemeName, Scheme> = { pi: PI, "tokyo-night": TOKYO_NIGHT };

let active: Scheme = PI;

function isThemeName(name: string): name is ThemeName {
  return (THEME_NAMES as readonly string[]).includes(name);
}

/**
 * Select the colour scheme. Unset or empty selects "pi". Returns false (and
 * keeps "pi") for an unknown name so the caller can warn.
 */
export function setTheme(name: string | undefined): boolean {
  const key = (name ?? "").trim().toLowerCase();
  if (key === "") {
    active = PI;
    return true;
  }
  if (!isThemeName(key)) {
    active = PI;
    return false;
  }
  active = SCHEMES[key];
  return true;
}

// Each value is a chalk instance, so `.bold` / `.dim` chaining still works.
export const theme = {
  get reset(): ChalkInstance { return chalk.reset; },
  get bold(): ChalkInstance { return chalk.bold; },
  get italic(): ChalkInstance { return chalk.italic; },
  get underline(): ChalkInstance { return chalk.underline; },
  get strikethrough(): ChalkInstance { return chalk.strikethrough; },

  get dim(): ChalkInstance { return active.roles.dim(); },
  get gray(): ChalkInstance { return active.roles.gray(); },
  get red(): ChalkInstance { return active.roles.red(); },
  get redBright(): ChalkInstance { return active.roles.redBright(); },
  get green(): ChalkInstance { return active.roles.green(); },
  get greenBright(): ChalkInstance { return active.roles.greenBright(); },
  get yellow(): ChalkInstance { return active.roles.yellow(); },
  get yellowBright(): ChalkInstance { return active.roles.yellowBright(); },
  get cyan(): ChalkInstance { return active.roles.cyan(); },
  get cyanBright(): ChalkInstance { return active.roles.cyanBright(); },
  get blueBright(): ChalkInstance { return active.roles.blueBright(); },
  get magenta(): ChalkInstance { return active.roles.magenta(); },
  get magentaBright(): ChalkInstance { return active.roles.magentaBright(); },
  get diffAddBg(): ChalkInstance { return active.roles.diffAddBg(); },
  get diffDelBg(): ChalkInstance { return active.roles.diffDelBg(); },
  get errorBox(): ChalkInstance { return active.roles.errorBox(); },
};

let terminalThemeApplied = false;

/**
 * Set the terminal's default foreground to the active scheme's for the
 * lifetime of the process (OSC 10), restoring the user's own on exit (OSC 110).
 * No-op for schemes without one ("pi"). Terminals without support ignore it.
 */
export function applyTerminalTheme(out: NodeJS.WriteStream = process.stdout): void {
  const fg = active.fg;
  if (!fg || terminalThemeApplied || !out.isTTY) return;
  terminalThemeApplied = true;
  out.write(`\x1b]10;${fg}\x1b\\`);
  process.on("exit", () => {
    out.write("\x1b]110\x1b\\");
  });
}
