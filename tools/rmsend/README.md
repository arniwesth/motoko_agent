# rmsend

Publishes Markdown notes to a reMarkable 2 as PDF or EPUB.

```
md ──pandoc──> typst ──> pdf ──rmapi──> reMarkable Cloud ──sync──> tablet
```

It goes through the cloud rather than USB or SSH, so it needs no cable and no
network route to the tablet — it works unchanged from inside the dev container.

## Requirements

- [Bun](https://bun.sh)
- `rmapi`, `pandoc`, `typst` — installed by `rmsend install`
- A reMarkable account (cloud sync is on the free tier)

Optional, for `--converter md2pdf`: a TeX distribution providing `xelatex`, plus
`rsvg-convert` for mermaid diagrams. `rmsend install --with-latex` adds both.

## Setup

```sh
bun tools/rmsend/rmsend.ts install    # or: make remarkable_install
bun tools/rmsend/rmsend.ts login      # or: make remarkable_login
```

`login` prints a URL; open it, and paste the 8-character code it shows you.

### Global install

```sh
cd tools/rmsend
bun link
```

Registers `rmsend` at `~/.bun/bin/rmsend`.

## Usage

```sh
# One note to the default folder (/Motoko)
rmsend notes.md

# A whole directory tree, into a specific cloud folder, with a contents page
rmsend .agent/research --dir /Motoko/Research --toc

# EPUB instead — reflows, so the tablet controls the font size
rmsend notes.md --format epub

# Every markdown file this branch changes vs main
rmsend branch

# Convert without uploading, and keep the output to inspect
rmsend notes.md --dry-run --keep-out /tmp/out

# What is on the tablet already
rmsend ls /Motoko
```

Directory arguments expand to every `.md` file beneath them.

## Options

| Flag | Default | Description |
|---|---|---|
| `--dir <path>` | `$RM_DIR` or `/Motoko` | Target cloud folder; created if absent |
| `--format <fmt>` | `pdf` | `pdf` or `epub` |
| `--converter <name>` | `auto` (= `typst`) | `typst` or `md2pdf` |
| `--name <name>` | from the document | Name on the tablet (single input only) |
| `--toc` | false | Include a table of contents |
| `--replace` | false | Delete an existing doc of the same name first |
| `--keep-out <dir>` | — | Keep converted files in `<dir>` |
| `--dry-run` | false | Convert only; print what would be uploaded |
| `--max <n>` | `20` | `branch`: refuse to send more than n files |
| `--yes` | false | `branch`: send anyway, past `--max` |
| `--with-latex` | false | `install`: also install XeLaTeX + librsvg |
| `--force` | false | `install`: reinstall even if already present |

## Document names

The name shown on the tablet comes from the YAML front matter `title:`, else the
first `# H1`, else the file name. Headings make long names — pass `--name` for
something shorter.

## Choosing a converter

`typst` is the default. It needs no external toolchain, runs in well under a
second, and breaks long inline code across lines.

`md2pdf` is the sibling tool (`tools/md2pdf`): pandoc + XeLaTeX, which adds
rendered mermaid diagrams, `[cite: N]` links, and landscape rotation for wide
tables. Use it for documents that need those. It is much slower, wants a ~1GB
TeX install, and overflows the margin on long unbreakable inline code such as
repository paths.

Both produce A5 pages (148×210mm). The rM2 screen is 157×210mm, so A5 fills it
with no pinch-zooming; text is set at 11pt for e-ink legibility.

## Re-sending a document

`rmapi` has no in-place update, so `--replace` is a delete followed by a fresh
upload — **it discards any annotations made on the tablet**. That is why it is
off by default; without it, re-sending the same note leaves you with two copies.

## Auth

The device token lives at `$RMAPI_CONFIG`, defaulting to
`<repo>/.remarkable/rmapi.conf`. That path is inside the bind-mounted workspace,
so rebuilding the container does not force a re-pair, and it is gitignored.
Never commit it. `rmapi reset` forgets the pairing.

## Bundled pandoc filter

`strip-dead-anchors.lua` runs on every typst conversion. A stale
`[text](#renamed-heading)` link is a dead link in a browser, but typst refuses
to compile the document at all; the filter keeps the text and drops the jump.
