# mmd2svg

Renders a [Mermaid](https://mermaid.js.org/) `.mmd` file to an SVG using [beautiful-mermaid](https://github.com/lukilabs/beautiful-mermaid).

## Requirements

[Bun](https://bun.sh) must be installed.

## Setup

```sh
cd tools/mmd2svg
bun install
```

### Global install

To use `mmd2svg` from any directory:

```sh
cd tools/mmd2svg
bun link
```

This registers the binary at `~/.bun/bin/mmd2svg`. Re-run after cloning on a new machine.
If `~/.bun/bin` is not on your `PATH`, add it to your shell profile:

```sh
export PATH="$HOME/.bun/bin:$PATH"
```

## Usage

```sh
# Write SVG to a file
mmd2svg <input.mmd> <output.svg>

# With a theme
mmd2svg <input.mmd> <output.svg> --theme tokyo-night

# Write SVG to stdout
mmd2svg <input.mmd>

## Themes

`--theme` defaults to `zinc-light`. Available options:

| Name                  | Type  |
|-----------------------|-------|
| `zinc-light`          | Light |
| `zinc-dark`           | Dark  |
| `tokyo-night`         | Dark  |
| `tokyo-night-storm`   | Dark  |
| `tokyo-night-light`   | Light |
| `catppuccin-mocha`    | Dark  |
| `catppuccin-latte`    | Light |
| `nord`                | Dark  |
| `nord-light`          | Light |
| `dracula`             | Dark  |
| `github-light`        | Light |
| `github-dark`         | Dark  |
| `solarized-light`     | Light |
| `solarized-dark`      | Dark  |
| `one-dark`            | Dark  |

### Custom themes

Custom themes are defined in `CUSTOM_THEMES` inside `cli.ts`. Each entry is a
`DiagramColors` object with `bg`, `fg`, and optional enrichment fields (`accent`,
`line`, `muted`, `surface`, `border`).

| Name                  | Type  |
|-----------------------|-------|
| `monokai-charcoal-hc` | Dark  |