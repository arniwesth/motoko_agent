# md2pdf

Converts a Markdown file to PDF via [pandoc](https://pandoc.org/) + XeLaTeX.

## Requirements

- [Bun](https://bun.sh)
- `pandoc`
- A TeX distribution providing `xelatex` (default engine)

```sh
# Debian/Ubuntu
sudo apt install pandoc texlive-xetex texlive-fonts-recommended

# macOS
brew install pandoc && brew install --cask mactex
```

## Setup

```sh
cd tools/md2pdf
bun install   # no npm deps; installs the bun shim only
```

### Global install

```sh
cd tools/md2pdf
bun link
```

Registers `md2pdf` at `~/.bun/bin/md2pdf`. Add that to `PATH` if needed:

```sh
export PATH="$HOME/.bun/bin:$PATH"
```

## Usage

```sh
# PDF written alongside the input file
md2pdf document.md

# Explicit output path
md2pdf document.md out/document.pdf

# Custom engine, margin, font size
md2pdf document.md --engine lualatex --margin 2cm --font-size 12

# System font (xelatex/lualatex only)
md2pdf document.md --mainfont "DejaVu Serif"

# Keep the intermediate .tex for inspection or manual tweaking
md2pdf document.md --keep-tex

# Open after conversion
md2pdf document.md --open
```

## Options

| Flag | Default | Description |
|---|---|---|
| `--engine <name>` | `xelatex` | TeX engine: `xelatex`, `lualatex`, `pdflatex` |
| `--margin <size>` | `1in` | Page margin; any LaTeX length (`2cm`, `15mm`…) |
| `--font-size <pt>` | `11` | Base font size in pt (6–72) |
| `--mainfont <name>` | — | System font via fontspec (xelatex/lualatex only) |
| `--template <file>` | — | Custom pandoc LaTeX template |
| `--keep-tex` | false | Preserve the intermediate `.tex` next to the PDF |
| `--open` | false | Open the PDF after writing |

## YAML front matter

Pandoc reads YAML front matter at the top of the Markdown file. Variables set
there override any conflicting CLI flags.

```markdown
---
title: "My Document"
author: "Name"
date: "2026-04-21"
geometry: margin=1in
fontsize: 12pt
mainfont: "DejaVu Serif"
---

# Introduction
...
```

Export the default template to customise the full LaTeX preamble:

```sh
pandoc -D latex > my-template.tex
# edit my-template.tex …
md2pdf document.md --template my-template.tex
```
